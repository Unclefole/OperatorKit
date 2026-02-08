import Foundation

// ============================================================================
// EXECUTION DIAGNOSTICS (Phase 10B)
//
// Provides operator-visible snapshot of execution behavior.
// On-device, read-only, user-visible.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking, analytics, or telemetry
// ❌ No user content (drafts, text, recipients, context)
// ❌ No stack traces or raw error messages
// ❌ No execution behavior changes
// ✅ Snapshot-based only (no background monitoring)
// ✅ Enum-based outcomes only
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

// MARK: - Execution Outcome

/// Outcome of an execution (enum only, no content)
public enum ExecutionOutcome: String, Codable, Equatable {
    case success = "success"
    case cancelled = "cancelled"
    case failed = "failed"
    case partialSuccess = "partial_success"
    case savedDraftOnly = "saved_draft_only"
    case unknown = "unknown"
    
    /// Display text for the outcome
    public var displayText: String {
        switch self {
        case .success: return "Success"
        case .cancelled: return "Cancelled"
        case .failed: return "Failed"
        case .partialSuccess: return "Partial Success"
        case .savedDraftOnly: return "Draft Saved"
        case .unknown: return "Unknown"
        }
    }
    
    /// SF Symbol for the outcome
    public var systemImage: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        case .failed: return "exclamationmark.triangle.fill"
        case .partialSuccess: return "checkmark.circle.badge.questionmark"
        case .savedDraftOnly: return "doc.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    /// Color name for the outcome
    public var colorName: String {
        switch self {
        case .success, .savedDraftOnly: return "green"
        case .cancelled: return "gray"
        case .failed: return "red"
        case .partialSuccess: return "orange"
        case .unknown: return "gray"
        }
    }
}

// MARK: - Failure Category

/// Categories of failures (no raw messages, enum only)
public enum FailureCategory: String, Codable, Equatable {
    case approvalNotGranted = "approval_not_granted"
    case permissionDenied = "permission_denied"
    case confidenceTooLow = "confidence_too_low"
    case timeout = "timeout"
    case validationFailed = "validation_failed"
    case serviceUnavailable = "service_unavailable"
    case userCancelled = "user_cancelled"
    case unknown = "unknown"
    
    /// Display text for the category
    public var displayText: String {
        switch self {
        case .approvalNotGranted: return "Approval Not Granted"
        case .permissionDenied: return "Permission Denied"
        case .confidenceTooLow: return "Low Confidence"
        case .timeout: return "Timeout"
        case .validationFailed: return "Validation Failed"
        case .serviceUnavailable: return "Service Unavailable"
        case .userCancelled: return "User Cancelled"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Execution Diagnostics Snapshot

/// Snapshot of execution diagnostics (content-free)
public struct ExecutionDiagnosticsSnapshot: Codable, Equatable {
    
    /// When this snapshot was captured
    public let capturedAt: Date
    
    /// Number of executions in the last 7 days
    public let executionsLast7Days: Int
    
    /// Number of executions today
    public let executionsToday: Int
    
    /// When the last execution occurred
    public let lastExecutionAt: Date?
    
    /// Outcome of the last execution
    public let lastExecutionOutcome: ExecutionOutcome
    
    /// Category of last failure (if any)
    public let lastFailureCategory: FailureCategory?
    
    /// Whether fallback was used in recent executions
    public let fallbackUsedRecently: Bool
    
    /// Schema version for migration
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Initialization
    
    public init(
        capturedAt: Date = Date(),
        executionsLast7Days: Int,
        executionsToday: Int,
        lastExecutionAt: Date?,
        lastExecutionOutcome: ExecutionOutcome,
        lastFailureCategory: FailureCategory?,
        fallbackUsedRecently: Bool
    ) {
        self.capturedAt = capturedAt
        self.executionsLast7Days = executionsLast7Days
        self.executionsToday = executionsToday
        self.lastExecutionAt = lastExecutionAt
        self.lastExecutionOutcome = lastExecutionOutcome
        self.lastFailureCategory = lastFailureCategory
        self.fallbackUsedRecently = fallbackUsedRecently
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    /// Create an empty/default snapshot
    public static var empty: ExecutionDiagnosticsSnapshot {
        ExecutionDiagnosticsSnapshot(
            executionsLast7Days: 0,
            executionsToday: 0,
            lastExecutionAt: nil,
            lastExecutionOutcome: .unknown,
            lastFailureCategory: nil,
            fallbackUsedRecently: false
        )
    }
    
    // MARK: - Display Helpers
    
    /// Formatted last execution time
    public var formattedLastExecution: String {
        guard let date = lastExecutionAt else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Summary status for display
    public var summaryStatus: String {
        if executionsLast7Days == 0 {
            return "No recent activity"
        }
        return "\(executionsLast7Days) execution\(executionsLast7Days == 1 ? "" : "s") this week"
    }
}

// MARK: - Execution Diagnostics (Singleton)

/// Main interface for execution diagnostics
/// Provides a singleton for convenient access
@MainActor
public final class ExecutionDiagnostics: ObservableObject {

    // MARK: - Singleton

    public static let shared = ExecutionDiagnostics()

    // MARK: - Dependencies

    private let collector: ExecutionDiagnosticsCollector

    // MARK: - Published State

    @Published public private(set) var totalExecutions: Int = 0
    @Published public private(set) var successCount: Int = 0
    @Published public private(set) var failureCount: Int = 0

    // MARK: - Initialization

    private init() {
        self.collector = ExecutionDiagnosticsCollector()
    }

    // MARK: - Public Methods

    /// Get current snapshot of execution diagnostics
    public func currentSnapshot() -> ExecutionDiagnosticsSnapshot {
        return collector.captureSnapshot()
    }

    /// Reset diagnostics (for testing)
    public func reset() {
        totalExecutions = 0
        successCount = 0
        failureCount = 0
    }

    /// Record an execution result
    public func recordExecution(success: Bool) {
        totalExecutions += 1
        if success {
            successCount += 1
        } else {
            failureCount += 1
        }
    }
}

// MARK: - Execution Diagnostics Collector

/// Collects execution diagnostics from various sources
/// INVARIANT: Does NOT increment any counters or modify state
public final class ExecutionDiagnosticsCollector {
    
    // MARK: - Dependencies
    
    private let usageLedger: UsageLedger
    private let memoryStore: MemoryStore
    
    // MARK: - Initialization
    
    init(
        usageLedger: UsageLedger = .shared,
        memoryStore: MemoryStore = .shared
    ) {
        self.usageLedger = usageLedger
        self.memoryStore = memoryStore
    }
    
    // MARK: - Snapshot Collection
    
    /// Captures current execution diagnostics
    /// INVARIANT: Read-only, does not modify any state
    @MainActor
    public func captureSnapshot() -> ExecutionDiagnosticsSnapshot {
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        
        // Get executions from ledger
        let executionsThisWindow = usageLedger.data.executionsThisWindow
        
        // Calculate today's executions from memory items
        let todayItems = memoryStore.items.filter { item in
            item.executionTimestamp.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        }
        let executionsToday = todayItems.count
        
        // Find last execution
        let lastItem = memoryStore.items.first // Already sorted by date descending
        let lastExecutionAt = lastItem?.executionTimestamp
        
        // Determine last outcome
        let lastOutcome = lastItem.map { mapExecutionStatus($0.executionStatus) } ?? .unknown
        
        // Determine last failure category
        let lastFailure: FailureCategory? = {
            guard lastOutcome == .failed else { return nil }
            // We can't know the exact failure without content, so use unknown
            return .unknown
        }()
        
        // Check if fallback was used recently (in last 5 items)
        let recentItems = Array(memoryStore.items.prefix(5))
        let fallbackUsed = recentItems.contains { $0.usedFallback }
        
        return ExecutionDiagnosticsSnapshot(
            capturedAt: now,
            executionsLast7Days: executionsThisWindow,
            executionsToday: executionsToday,
            lastExecutionAt: lastExecutionAt,
            lastExecutionOutcome: lastOutcome,
            lastFailureCategory: lastFailure,
            fallbackUsedRecently: fallbackUsed
        )
    }
    
    // MARK: - Helpers
    
    private func mapExecutionStatus(_ status: PersistedMemoryItem.ExecutionStatus?) -> ExecutionOutcome {
        guard let status = status else { return .unknown }
        switch status {
        case .success: return .success
        case .partialSuccess: return .partialSuccess
        case .failed: return .failed
        case .savedDraftOnly: return .savedDraftOnly
        }
    }
}
