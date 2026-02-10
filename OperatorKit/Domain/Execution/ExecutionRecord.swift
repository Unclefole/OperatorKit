import Foundation
import SwiftData

// ============================================================================
// EXECUTION RECORD — DURABLE EXECUTION LIFECYCLE SOURCE OF TRUTH
//
// Every authorized action gets a persistent ExecutionRecord BEFORE execution
// begins. Status transitions are atomic and survive app termination.
//
// LIFECYCLE:
//   .planned → .approved → .executing → .completed | .failed
//                                        .completed → .reversed (undo)
//
// INVARIANTS:
// - Record MUST be written BEFORE side effects execute.
// - Status transitions are forward-only (no skipping states).
// - Records persist across app launches via SwiftData.
// - Crash recovery: any record left in .executing on launch → .failed.
// - Emergency stop: all .executing records → .failed atomically.
//
// This is NOT optional logging. This is the execution source of truth.
// ============================================================================

@Model
final class ExecutionRecord {

    // MARK: - Identity

    @Attribute(.unique) var id: UUID
    var intentTypeRaw: String
    var sideEffectTypeRaw: String

    // MARK: - Status

    var statusRaw: String

    // MARK: - Lifecycle timestamps

    var createdAt: Date
    var updatedAt: Date

    // MARK: - Reversibility

    var reversible: Bool
    var rollbackAvailable: Bool

    // MARK: - Evidence chain

    /// Comma-separated UUID strings linking to EvidenceEngine entries
    var evidenceIDsRaw: String

    // MARK: - Context

    var tokenPlanId: String
    var summary: String

    // MARK: - Failure info

    var failureReason: String?

    // MARK: - Init

    init(
        id: UUID = UUID(),
        intentType: String,
        sideEffectType: String,
        status: ExecutionRecordStatus = .planned,
        reversible: Bool = false,
        rollbackAvailable: Bool = false,
        evidenceIDs: [UUID] = [],
        tokenPlanId: UUID,
        summary: String,
        failureReason: String? = nil
    ) {
        self.id = id
        self.intentTypeRaw = intentType
        self.sideEffectTypeRaw = sideEffectType
        self.statusRaw = status.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
        self.reversible = reversible
        self.rollbackAvailable = rollbackAvailable
        self.evidenceIDsRaw = evidenceIDs.map { $0.uuidString }.joined(separator: ",")
        self.tokenPlanId = tokenPlanId.uuidString
        self.summary = summary
        self.failureReason = failureReason
    }

    // MARK: - Computed

    var status: ExecutionRecordStatus {
        get { ExecutionRecordStatus(rawValue: statusRaw) ?? .failed }
        set {
            statusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var evidenceIDs: [UUID] {
        get {
            guard !evidenceIDsRaw.isEmpty else { return [] }
            return evidenceIDsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
        }
        set {
            evidenceIDsRaw = newValue.map { $0.uuidString }.joined(separator: ",")
            updatedAt = Date()
        }
    }

    func appendEvidence(_ evidenceId: UUID) {
        var ids = evidenceIDs
        ids.append(evidenceId)
        evidenceIDs = ids
    }
}

// MARK: - Status Enum

enum ExecutionRecordStatus: String, Codable, CaseIterable {
    case planned    = "planned"
    case approved   = "approved"
    case executing  = "executing"
    case completed  = "completed"
    case failed     = "failed"
    case reversed   = "reversed"

    /// Whether this is a terminal state (no further transitions)
    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .reversed: return true
        case .planned, .approved, .executing: return false
        }
    }
}
