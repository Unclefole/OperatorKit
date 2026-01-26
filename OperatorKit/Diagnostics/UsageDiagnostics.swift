import Foundation

// ============================================================================
// USAGE DIAGNOSTICS (Phase 10B)
//
// Provides operator-visible snapshot of usage limits and subscription status.
// On-device, read-only, user-visible.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking, analytics, or telemetry
// ❌ No user content
// ❌ No duplicate counters (derives from existing sources)
// ✅ Snapshot-based only
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

// MARK: - Usage Diagnostics Snapshot

/// Snapshot of usage and limit diagnostics (content-free)
public struct UsageDiagnosticsSnapshot: Codable, Equatable {
    
    /// When this snapshot was captured
    public let capturedAt: Date
    
    /// Current subscription tier
    public let subscriptionTier: SubscriptionTier
    
    /// Weekly execution limit (nil if unlimited)
    public let weeklyExecutionLimit: Int?
    
    /// Executions remaining this window (nil if unlimited)
    public let executionsRemainingThisWindow: Int?
    
    /// Current memory item count
    public let memoryItemCount: Int
    
    /// Memory item limit (nil if unlimited)
    public let memoryLimit: Int?
    
    /// When the weekly window resets
    public let windowResetsAt: Date?
    
    /// Schema version for migration
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Initialization
    
    public init(
        capturedAt: Date = Date(),
        subscriptionTier: SubscriptionTier,
        weeklyExecutionLimit: Int?,
        executionsRemainingThisWindow: Int?,
        memoryItemCount: Int,
        memoryLimit: Int?,
        windowResetsAt: Date?
    ) {
        self.capturedAt = capturedAt
        self.subscriptionTier = subscriptionTier
        self.weeklyExecutionLimit = weeklyExecutionLimit
        self.executionsRemainingThisWindow = executionsRemainingThisWindow
        self.memoryItemCount = memoryItemCount
        self.memoryLimit = memoryLimit
        self.windowResetsAt = windowResetsAt
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    /// Create an empty/default snapshot
    public static var empty: UsageDiagnosticsSnapshot {
        UsageDiagnosticsSnapshot(
            subscriptionTier: .free,
            weeklyExecutionLimit: UsageQuota.freeExecutionsPerWeek,
            executionsRemainingThisWindow: UsageQuota.freeExecutionsPerWeek,
            memoryItemCount: 0,
            memoryLimit: UsageQuota.freeMemoryItemsMax,
            windowResetsAt: nil
        )
    }
    
    // MARK: - Display Helpers
    
    /// Formatted reset time
    public var formattedResetTime: String? {
        guard let date = windowResetsAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Execution usage summary
    public var executionUsageSummary: String {
        if let remaining = executionsRemainingThisWindow, let limit = weeklyExecutionLimit {
            let used = limit - remaining
            return "\(used)/\(limit) used this week"
        }
        return "Unlimited"
    }
    
    /// Memory usage summary
    public var memoryUsageSummary: String {
        if let limit = memoryLimit {
            return "\(memoryItemCount)/\(limit) items saved"
        }
        return "\(memoryItemCount) items saved"
    }
    
    /// Whether execution limit is approaching
    public var isExecutionLimitApproaching: Bool {
        guard let remaining = executionsRemainingThisWindow, let limit = weeklyExecutionLimit else {
            return false
        }
        return remaining <= 2 && remaining > 0
    }
    
    /// Whether execution limit is reached
    public var isExecutionLimitReached: Bool {
        guard let remaining = executionsRemainingThisWindow else { return false }
        return remaining == 0
    }
    
    /// Whether memory limit is approaching
    public var isMemoryLimitApproaching: Bool {
        guard let limit = memoryLimit else { return false }
        return memoryItemCount >= limit - 2 && memoryItemCount < limit
    }
    
    /// Whether memory limit is reached
    public var isMemoryLimitReached: Bool {
        guard let limit = memoryLimit else { return false }
        return memoryItemCount >= limit
    }
}

// MARK: - Usage Diagnostics Collector

/// Collects usage diagnostics from various sources
/// INVARIANT: Does NOT modify any counters or state
public final class UsageDiagnosticsCollector {
    
    // MARK: - Dependencies
    
    private let usageLedger: UsageLedger
    private let entitlementManager: EntitlementManager
    private let memoryStore: MemoryStore
    
    // MARK: - Initialization
    
    public init(
        usageLedger: UsageLedger = .shared,
        entitlementManager: EntitlementManager = .shared,
        memoryStore: MemoryStore = .shared
    ) {
        self.usageLedger = usageLedger
        self.entitlementManager = entitlementManager
        self.memoryStore = memoryStore
    }
    
    // MARK: - Snapshot Collection
    
    /// Captures current usage diagnostics
    /// INVARIANT: Read-only, does not modify any state
    @MainActor
    public func captureSnapshot() -> UsageDiagnosticsSnapshot {
        let tier = entitlementManager.currentTier
        let isPro = tier == .pro
        
        // Get execution limits
        let weeklyLimit: Int? = isPro ? nil : UsageQuota.freeExecutionsPerWeek
        let executionsUsed = usageLedger.data.executionsThisWindow
        let remaining: Int? = isPro ? nil : max(0, UsageQuota.freeExecutionsPerWeek - executionsUsed)
        
        // Get memory stats
        let memoryCount = memoryStore.items.count
        let memoryLimit: Int? = isPro ? nil : UsageQuota.freeMemoryItemsMax
        
        // Get reset time
        let windowResetsAt: Date? = isPro ? nil : usageLedger.windowResetDate
        
        return UsageDiagnosticsSnapshot(
            subscriptionTier: tier,
            weeklyExecutionLimit: weeklyLimit,
            executionsRemainingThisWindow: remaining,
            memoryItemCount: memoryCount,
            memoryLimit: memoryLimit,
            windowResetsAt: windowResetsAt
        )
    }
}
