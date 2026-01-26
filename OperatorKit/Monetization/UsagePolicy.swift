import Foundation

// ============================================================================
// USAGE POLICY (Phase 10A)
//
// Defines usage quotas for Free tier.
// These limits affect availability only, never correctness or safety.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ Does not change how a single execution behaves
// ❌ Does not gate approval or execution engine
// ✅ Limits enforced at UI boundary only
// ✅ Pro tier = unlimited
// ✅ Easy to adjust quotas
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

// MARK: - Usage Quotas

/// Usage quota constants — easy to adjust
public enum UsageQuota {
    
    /// Maximum executions per week for Free tier
    public static let freeExecutionsPerWeek: Int = 5
    
    /// Maximum saved memory items for Free tier
    public static let freeMemoryItemsMax: Int = 10
    
    /// Duration of weekly window in seconds (7 days)
    public static let weeklyWindowDuration: TimeInterval = 7 * 24 * 60 * 60
}

// MARK: - Limit Type

/// Types of usage limits
public enum LimitType: String, Codable {
    /// Weekly execution limit
    case executionsWeekly = "executions_weekly"
    
    /// Memory items storage limit
    case memoryItems = "memory_items"
    
    /// Display name for the limit type
    public var displayName: String {
        switch self {
        case .executionsWeekly:
            return "Weekly Executions"
        case .memoryItems:
            return "Saved Items"
        }
    }
}

// MARK: - Limit Decision

/// Result of a limit check
public struct LimitDecision: Equatable {
    
    /// Whether the action is allowed
    public let allowed: Bool
    
    /// Human-readable reason if blocked (plain, no hype)
    public let reason: String?
    
    /// Which limit was checked
    public let limitType: LimitType
    
    /// Remaining quota (nil if unlimited)
    public let remaining: Int?
    
    /// When the limit resets (for weekly limits)
    public let resetsAt: Date?
    
    // MARK: - Factory Methods
    
    /// Create an "allowed" decision
    public static func allow(limitType: LimitType, remaining: Int?) -> LimitDecision {
        LimitDecision(
            allowed: true,
            reason: nil,
            limitType: limitType,
            remaining: remaining,
            resetsAt: nil
        )
    }
    
    /// Create an "allowed" decision for unlimited (Pro)
    public static func unlimited(limitType: LimitType) -> LimitDecision {
        LimitDecision(
            allowed: true,
            reason: nil,
            limitType: limitType,
            remaining: nil,
            resetsAt: nil
        )
    }
    
    /// Create a "blocked" decision for execution limit
    public static func executionLimitReached(resetsAt: Date) -> LimitDecision {
        LimitDecision(
            allowed: false,
            reason: "You've used all \(UsageQuota.freeExecutionsPerWeek) free executions this week. Upgrade to Pro for unlimited use.",
            limitType: .executionsWeekly,
            remaining: 0,
            resetsAt: resetsAt
        )
    }
    
    /// Create a "blocked" decision for memory limit
    public static func memoryLimitReached(currentCount: Int) -> LimitDecision {
        LimitDecision(
            allowed: false,
            reason: "You've reached the \(UsageQuota.freeMemoryItemsMax) saved item limit. Upgrade to Pro for unlimited storage.",
            limitType: .memoryItems,
            remaining: 0,
            resetsAt: nil
        )
    }
    
    // MARK: - Display Helpers
    
    /// Formatted reset time for display
    public var formattedResetTime: String? {
        guard let date = resetsAt else { return nil }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Short formatted reset time (e.g., "in 3 days")
    public var shortResetTime: String? {
        guard let date = resetsAt else { return nil }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
