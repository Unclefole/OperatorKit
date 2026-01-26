import Foundation

// ============================================================================
// CUSTOMER AUDIT TRAIL STORE (Phase 10P)
//
// UserDefaults-backed ring buffer for customer audit events.
// Max 500 events, with purge controls.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No networking
// ❌ No background tasks
// ✅ Ring buffer with cap
// ✅ Purge controls in UI
// ✅ Content-free invariants
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

@MainActor
public final class CustomerAuditTrailStore: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = CustomerAuditTrailStore()
    
    // MARK: - Constants
    
    /// Maximum number of events to store
    public static let maxEvents = 500
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let storageKey = "com.operatorkit.customer.audit.trail"
    private let schemaVersionKey = "com.operatorkit.customer.audit.schema_version"
    
    // MARK: - State
    
    @Published public private(set) var events: [CustomerAuditEvent]
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.events = []
        loadEvents()
    }
    
    // MARK: - Recording
    
    /// Records an audit event
    public func recordEvent(_ event: CustomerAuditEvent) {
        events.append(event)
        
        // Enforce ring buffer cap
        while events.count > Self.maxEvents {
            events.removeFirst()
        }
        
        saveEvents()
        
        logDebug("Customer audit event recorded: \(event.kind.rawValue)", category: .diagnostics)
    }
    
    /// Records an event with parameters
    public func record(
        kind: CustomerAuditEventKind,
        intentType: String,
        outputType: String,
        result: CustomerAuditEventResult,
        failureCategory: FailureCategory? = nil,
        backendUsed: String,
        policyDecision: CustomerAuditPolicyDecision? = nil,
        tierAtTime: String
    ) {
        let event = CustomerAuditEvent(
            kind: kind,
            intentType: intentType,
            outputType: outputType,
            result: result,
            failureCategory: failureCategory,
            backendUsed: backendUsed,
            policyDecision: policyDecision,
            tierAtTime: tierAtTime
        )
        recordEvent(event)
    }
    
    // MARK: - Summary
    
    /// Gets current summary for export
    public func currentSummary() -> CustomerAuditTrailSummary {
        let today = dayRoundedNow()
        let sevenDaysAgo = dayRoundedDate(daysAgo: 7)
        
        // Count events in last 7 days
        let recentEvents = events.filter { $0.createdAtDayRounded >= sevenDaysAgo }
        
        // Count by kind
        var countByKind: [String: Int] = [:]
        for event in events {
            countByKind[event.kind.rawValue, default: 0] += 1
        }
        
        // Count by result
        var countByResult: [String: Int] = [:]
        for event in events {
            countByResult[event.result.rawValue, default: 0] += 1
        }
        
        // Success rate
        let successCount = countByResult[CustomerAuditEventResult.success.rawValue] ?? 0
        let totalWithOutcome = (countByResult[CustomerAuditEventResult.success.rawValue] ?? 0) +
                               (countByResult[CustomerAuditEventResult.failure.rawValue] ?? 0)
        let successRate: Double? = totalWithOutcome > 0 ? Double(successCount) / Double(totalWithOutcome) : nil
        
        // Most recent 20 events
        let mostRecent = Array(events.suffix(20))
        
        return CustomerAuditTrailSummary(
            totalEvents: events.count,
            eventsLast7Days: recentEvents.count,
            countByKind: countByKind,
            countByResult: countByResult,
            successRate: successRate,
            recentEvents: mostRecent,
            schemaVersion: CustomerAuditTrailSummary.currentSchemaVersion,
            capturedAt: today
        )
    }
    
    // MARK: - Query
    
    /// Events from last N days
    public func eventsFromLastDays(_ days: Int) -> [CustomerAuditEvent] {
        let cutoff = dayRoundedDate(daysAgo: days)
        return events.filter { $0.createdAtDayRounded >= cutoff }
    }
    
    /// Events of a specific kind
    public func events(ofKind kind: CustomerAuditEventKind) -> [CustomerAuditEvent] {
        events.filter { $0.kind == kind }
    }
    
    /// Count of events today
    public var countToday: Int {
        let today = dayRoundedNow()
        return events.filter { $0.createdAtDayRounded == today }.count
    }
    
    // MARK: - Purge
    
    /// Purges all audit events (user-initiated only)
    public func purgeAll() {
        events = []
        defaults.removeObject(forKey: storageKey)
        
        logDebug("Customer audit trail purged", category: .diagnostics)
    }
    
    /// Purges events older than N days
    public func purgeOlderThan(days: Int) {
        let cutoff = dayRoundedDate(daysAgo: days)
        events = events.filter { $0.createdAtDayRounded >= cutoff }
        saveEvents()
        
        logDebug("Customer audit trail purged events older than \(days) days", category: .diagnostics)
    }
    
    // MARK: - Reset (for testing)
    
    public func reset() {
        events = []
        defaults.removeObject(forKey: storageKey)
    }
    
    // MARK: - Private
    
    private func loadEvents() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CustomerAuditEvent].self, from: data) else {
            return
        }
        events = decoded
    }
    
    private func saveEvents() {
        if let encoded = try? JSONEncoder().encode(events) {
            defaults.set(encoded, forKey: storageKey)
            defaults.set(CustomerAuditEvent.currentSchemaVersion, forKey: schemaVersionKey)
        }
    }
    
    private func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
    
    private func dayRoundedDate(daysAgo: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Convenience Recording Methods

extension CustomerAuditTrailStore {
    
    /// Records an approval granted event
    public func recordApprovalGranted(
        intentType: String,
        outputType: String,
        backendUsed: String,
        tier: String
    ) {
        record(
            kind: .approvalGranted,
            intentType: intentType,
            outputType: outputType,
            result: .success,
            backendUsed: backendUsed,
            policyDecision: .allowed,
            tierAtTime: tier
        )
    }
    
    /// Records an execution succeeded event
    public func recordExecutionSucceeded(
        intentType: String,
        outputType: String,
        backendUsed: String,
        tier: String
    ) {
        record(
            kind: .executionSucceeded,
            intentType: intentType,
            outputType: outputType,
            result: .success,
            backendUsed: backendUsed,
            tierAtTime: tier
        )
    }
    
    /// Records an execution failed event
    public func recordExecutionFailed(
        intentType: String,
        outputType: String,
        backendUsed: String,
        tier: String,
        failureCategory: FailureCategory
    ) {
        record(
            kind: .executionFailed,
            intentType: intentType,
            outputType: outputType,
            result: .failure,
            failureCategory: failureCategory,
            backendUsed: backendUsed,
            tierAtTime: tier
        )
    }
    
    /// Records a template used event
    public func recordTemplateUsed(
        templateId: String,
        tier: String
    ) {
        record(
            kind: .templateUsed,
            intentType: "template",
            outputType: templateId,
            result: .success,
            backendUsed: "local",
            tierAtTime: tier
        )
    }
    
    /// Records a template completed event
    public func recordTemplateCompleted(
        templateId: String,
        tier: String
    ) {
        record(
            kind: .templateCompleted,
            intentType: "template",
            outputType: templateId,
            result: .success,
            backendUsed: "local",
            tierAtTime: tier
        )
    }
    
    /// Records a policy denied event
    public func recordPolicyDenied(
        intentType: String,
        outputType: String,
        tier: String,
        reason: CustomerAuditPolicyDecision
    ) {
        record(
            kind: .policyDenied,
            intentType: intentType,
            outputType: outputType,
            result: .denied,
            backendUsed: "policy",
            policyDecision: reason,
            tierAtTime: tier
        )
    }
}
