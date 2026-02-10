import Foundation
import SwiftData

// ============================================================================
// EXECUTION RECORD STORE — PERSISTENT EXECUTION LIFECYCLE MANAGER
//
// Owns all reads/writes to ExecutionRecord via SwiftData.
// Provides atomic status transitions, crash recovery, and halt safety.
//
// INVARIANTS:
// - All writes go through this store (no direct ModelContext manipulation).
// - Status transitions are validated (no backwards moves).
// - Crash recovery runs ONCE on app launch before any new execution.
// - Emergency stop transitions ALL .executing → .failed atomically.
// ============================================================================

@MainActor
final class ExecutionRecordStore: ObservableObject {

    static let shared = ExecutionRecordStore()

    private var modelContext: ModelContext?
    private let evidenceEngine = EvidenceEngine.shared

    private init() {}

    // MARK: - Configuration

    /// Must be called once at app launch with the shared ModelContainer.
    func configure(with container: ModelContainer) {
        self.modelContext = ModelContext(container)
        self.modelContext?.autosaveEnabled = true
    }

    // MARK: - Create

    /// Create a new ExecutionRecord in .planned status.
    /// Called when approval is granted, BEFORE execution begins.
    @discardableResult
    func createRecord(
        intentType: String,
        sideEffectType: String,
        tokenPlanId: UUID,
        summary: String,
        reversible: Bool = false
    ) -> ExecutionRecord? {
        guard let ctx = modelContext else {
            logError("[ExecutionRecordStore] No ModelContext — cannot persist record")
            return nil
        }

        let record = ExecutionRecord(
            intentType: intentType,
            sideEffectType: sideEffectType,
            status: .planned,
            reversible: reversible,
            tokenPlanId: tokenPlanId,
            summary: summary
        )

        ctx.insert(record)
        saveContext("createRecord")
        log("[ExecutionRecordStore] Created record \(record.id) — status: planned")
        return record
    }

    // MARK: - Status Transitions

    /// Transition a record's status. Validates forward-only movement.
    /// Returns true if transition succeeded.
    @discardableResult
    func transition(_ recordId: UUID, to newStatus: ExecutionRecordStatus, reason: String? = nil) -> Bool {
        guard let record = fetch(by: recordId) else {
            logError("[ExecutionRecordStore] Record \(recordId) not found for transition")
            return false
        }

        let oldStatus = record.status

        // Validate forward-only transitions
        guard isValidTransition(from: oldStatus, to: newStatus) else {
            logError("[ExecutionRecordStore] Invalid transition: \(oldStatus.rawValue) → \(newStatus.rawValue) for \(recordId)")
            return false
        }

        record.status = newStatus

        if let reason = reason {
            record.failureReason = reason
        }

        // Enable rollback for completed reversible actions
        if newStatus == .completed && record.reversible {
            record.rollbackAvailable = true
        }

        // Disable rollback on reversal or failure
        if newStatus == .reversed || newStatus == .failed {
            record.rollbackAvailable = false
        }

        saveContext("transition \(oldStatus.rawValue)→\(newStatus.rawValue)")
        log("[ExecutionRecordStore] Transitioned \(recordId): \(oldStatus.rawValue) → \(newStatus.rawValue)")
        return true
    }

    /// Mark a record as reversed (undo succeeded).
    @discardableResult
    func markReversed(_ recordId: UUID) -> Bool {
        return transition(recordId, to: .reversed, reason: "Undo executed by operator")
    }

    /// Append an evidence ID to a record.
    func appendEvidence(_ evidenceId: UUID, to recordId: UUID) {
        guard let record = fetch(by: recordId) else { return }
        record.appendEvidence(evidenceId)
        saveContext("appendEvidence")
    }

    // MARK: - Queries

    /// Fetch a single record by ID.
    func fetch(by id: UUID) -> ExecutionRecord? {
        guard let ctx = modelContext else { return nil }
        let predicate = #Predicate<ExecutionRecord> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? ctx.fetch(descriptor).first
    }

    /// Fetch all records in a given status.
    func fetchByStatus(_ status: ExecutionRecordStatus) -> [ExecutionRecord] {
        guard let ctx = modelContext else { return [] }
        let rawValue = status.rawValue
        let predicate = #Predicate<ExecutionRecord> { $0.statusRaw == rawValue }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return (try? ctx.fetch(descriptor)) ?? []
    }

    /// Fetch recent records (last 24h).
    func fetchRecent(limit: Int = 50) -> [ExecutionRecord] {
        guard let ctx = modelContext else { return [] }
        let cutoff = Date().addingTimeInterval(-86400)
        let predicate = #Predicate<ExecutionRecord> { $0.createdAt > cutoff }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return (try? ctx.fetch(descriptor)) ?? []
    }

    /// Count of records currently in .executing status.
    var executingCount: Int {
        fetchByStatus(.executing).count
    }

    // MARK: - Crash Recovery (PHASE 4)

    /// Called ONCE at app launch. Any record left in .executing means the app
    /// terminated during execution (crash, kill, reboot).
    /// These records are moved to .failed with evidence logged.
    ///
    /// ENTERPRISE INVARIANT: No execution can be "lost" — every interrupted
    /// execution is accounted for.
    @discardableResult
    func recoverFromCrash() -> Int {
        let stranded = fetchByStatus(.executing)
        guard !stranded.isEmpty else {
            log("[ExecutionRecordStore] Crash recovery: no stranded executions found")
            return 0
        }

        log("[ExecutionRecordStore] CRASH RECOVERY: Found \(stranded.count) stranded execution(s)")

        for record in stranded {
            record.status = .failed
            record.failureReason = "Execution interrupted — possible crash or termination"
            record.rollbackAvailable = false

            // Log evidence for the crash recovery
            try? evidenceEngine.logGenericArtifact(
                type: "crash_recovery",
                planId: record.id,
                jsonString: """
                {"recordId":"\(record.id)","intentType":"\(record.intentTypeRaw)","sideEffectType":"\(record.sideEffectTypeRaw)","originalStatus":"executing","recoveredTo":"failed","recoveredAt":"\(Date())","reason":"Execution interrupted — possible crash or termination"}
                """
            )
        }

        saveContext("crashRecovery")
        logError("[ExecutionRecordStore] CRASH RECOVERY COMPLETE: \(stranded.count) record(s) moved to .failed")
        return stranded.count
    }

    // MARK: - Halt Safety (PHASE 5)

    /// Called by CapabilityKernel.emergencyStop().
    /// Transitions ALL .executing records to .failed atomically.
    @discardableResult
    func haltAllExecuting() -> Int {
        let executing = fetchByStatus(.executing)
        guard !executing.isEmpty else { return 0 }

        log("[ExecutionRecordStore] HALT: Failing \(executing.count) executing record(s)")

        for record in executing {
            record.status = .failed
            record.failureReason = "Emergency stop activated by operator"
            record.rollbackAvailable = false

            try? evidenceEngine.logGenericArtifact(
                type: "emergency_halt_record",
                planId: record.id,
                jsonString: """
                {"recordId":"\(record.id)","intentType":"\(record.intentTypeRaw)","haltedAt":"\(Date())","reason":"Emergency stop"}
                """
            )
        }

        // Also fail any .approved records that haven't started executing
        let approved = fetchByStatus(.approved)
        for record in approved {
            record.status = .failed
            record.failureReason = "Emergency stop — execution never started"
            record.rollbackAvailable = false
        }

        saveContext("haltAllExecuting")
        log("[ExecutionRecordStore] HALT COMPLETE: \(executing.count) executing + \(approved.count) approved → .failed")
        return executing.count + approved.count
    }

    // MARK: - Transition Validation

    private func isValidTransition(from: ExecutionRecordStatus, to: ExecutionRecordStatus) -> Bool {
        switch (from, to) {
        case (.planned, .approved):    return true
        case (.planned, .failed):      return true  // pre-execution failure
        case (.approved, .executing):  return true
        case (.approved, .failed):     return true  // cancelled before start
        case (.executing, .completed): return true
        case (.executing, .failed):    return true  // error or halt
        case (.completed, .reversed):  return true  // undo
        default:                       return false
        }
    }

    // MARK: - Persistence

    private func saveContext(_ caller: String) {
        guard let ctx = modelContext else { return }
        do {
            try ctx.save()
        } catch {
            logError("[ExecutionRecordStore] Save failed in \(caller): \(error)")
        }
    }
}
