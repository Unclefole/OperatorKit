import Foundation

// ============================================================================
// QUOTA ENFORCER (Phase 10G)
//
// Enforces subscription quotas at UI boundaries ONLY.
// Does NOT modify ExecutionEngine, ApprovalGate, or ModelRouter.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ Does NOT import/modify execution modules
// ❌ No background enforcement
// ❌ No content storage (counters + metadata only)
// ✅ UI boundary enforcement only
// ✅ Shows paywall, does not block silently
// ✅ Never blocks reviewing existing drafts
//
// See: docs/SAFETY_CONTRACT.md (Section 16)
// ============================================================================

// MARK: - Quota Check Result

/// Result of a quota check
public struct QuotaCheckResult {
    
    /// Whether the action is allowed
    public let allowed: Bool
    
    /// Quota type that was checked
    public let quotaType: QuotaType
    
    /// Current usage count
    public let currentUsage: Int
    
    /// Limit (nil = unlimited)
    public let limit: Int?
    
    /// Remaining (nil = unlimited)
    public var remaining: Int? {
        guard let limit = limit else { return nil }
        return max(0, limit - currentUsage)
    }
    
    /// User-facing message
    public let message: String?
    
    /// Whether to show paywall
    public let showPaywall: Bool
    
    /// Creates an allowed result
    public static func allowed(
        quotaType: QuotaType,
        currentUsage: Int,
        limit: Int?
    ) -> QuotaCheckResult {
        QuotaCheckResult(
            allowed: true,
            quotaType: quotaType,
            currentUsage: currentUsage,
            limit: limit,
            message: nil,
            showPaywall: false
        )
    }
    
    /// Creates a blocked result
    public static func blocked(
        quotaType: QuotaType,
        currentUsage: Int,
        limit: Int,
        message: String
    ) -> QuotaCheckResult {
        QuotaCheckResult(
            allowed: false,
            quotaType: quotaType,
            currentUsage: currentUsage,
            limit: limit,
            message: message,
            showPaywall: true
        )
    }
    
    /// Creates an approaching limit result (allowed but with warning)
    public static func approaching(
        quotaType: QuotaType,
        currentUsage: Int,
        limit: Int,
        remaining: Int
    ) -> QuotaCheckResult {
        QuotaCheckResult(
            allowed: true,
            quotaType: quotaType,
            currentUsage: currentUsage,
            limit: limit,
            message: "You have \(remaining) \(quotaType.unitName) remaining this week.",
            showPaywall: false
        )
    }
}

// MARK: - Quota Type

/// Types of quotas enforced
public enum QuotaType: String, Codable {
    case weeklyExecutions = "weekly_executions"
    case memoryItems = "memory_items"
    case teamSeats = "team_seats"
    case teamArtifacts = "team_artifacts"
    
    public var displayName: String {
        switch self {
        case .weeklyExecutions: return "Weekly Executions"
        case .memoryItems: return "Memory Items"
        case .teamSeats: return "Team Seats"
        case .teamArtifacts: return "Team Artifacts"
        }
    }
    
    public var unitName: String {
        switch self {
        case .weeklyExecutions: return "executions"
        case .memoryItems: return "memory items"
        case .teamSeats: return "seats"
        case .teamArtifacts: return "artifacts"
        }
    }
}

// MARK: - Quota Enforcer

/// Enforces quotas at UI boundaries
@MainActor
public final class QuotaEnforcer: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = QuotaEnforcer()
    
    // MARK: - Dependencies
    
    private var entitlementManager: EntitlementManager { EntitlementManager.shared }
    private var usageLedger: UsageLedger { UsageLedger.shared }
    
    // MARK: - Published State
    
    @Published public private(set) var lastQuotaCheck: QuotaCheckResult?
    @Published public private(set) var showingPaywall: Bool = false
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Execution Quota Check
    
    /// Checks if user can start a new execution
    /// Call this BEFORE processing intent at UI layer
    public func canStartExecution() -> QuotaCheckResult {
        let tier = entitlementManager.currentTier
        let weeklyCount = usageLedger.executionsThisWeek
        
        // Get limit for tier
        guard let limit = TierQuotas.weeklyExecutionLimit(for: tier) else {
            // Unlimited
            let result = QuotaCheckResult.allowed(
                quotaType: .weeklyExecutions,
                currentUsage: weeklyCount,
                limit: nil
            )
            lastQuotaCheck = result
            return result
        }
        
        // Check if at or over limit
        if weeklyCount >= limit {
            let result = QuotaCheckResult.blocked(
                quotaType: .weeklyExecutions,
                currentUsage: weeklyCount,
                limit: limit,
                message: QuotaMessages.executionLimitReached(limit: limit)
            )
            lastQuotaCheck = result
            return result
        }
        
        // Check if approaching limit
        let remaining = limit - weeklyCount
        if remaining <= 5 {
            let result = QuotaCheckResult.approaching(
                quotaType: .weeklyExecutions,
                currentUsage: weeklyCount,
                limit: limit,
                remaining: remaining
            )
            lastQuotaCheck = result
            return result
        }
        
        let result = QuotaCheckResult.allowed(
            quotaType: .weeklyExecutions,
            currentUsage: weeklyCount,
            limit: limit
        )
        lastQuotaCheck = result
        return result
    }
    
    // MARK: - Memory Quota Check
    
    /// Checks if user can save a new memory item
    /// Call this BEFORE saving memory at UI layer
    public func canSaveMemoryItem(currentCount: Int) -> QuotaCheckResult {
        let tier = entitlementManager.currentTier
        
        guard let limit = TierQuotas.memoryItemLimit(for: tier) else {
            // Unlimited
            return QuotaCheckResult.allowed(
                quotaType: .memoryItems,
                currentUsage: currentCount,
                limit: nil
            )
        }
        
        if currentCount >= limit {
            return QuotaCheckResult.blocked(
                quotaType: .memoryItems,
                currentUsage: currentCount,
                limit: limit,
                message: QuotaMessages.memoryLimitReached(limit: limit)
            )
        }
        
        let remaining = limit - currentCount
        if remaining <= 3 {
            return QuotaCheckResult.approaching(
                quotaType: .memoryItems,
                currentUsage: currentCount,
                limit: limit,
                remaining: remaining
            )
        }
        
        return QuotaCheckResult.allowed(
            quotaType: .memoryItems,
            currentUsage: currentCount,
            limit: limit
        )
    }
    
    // MARK: - Team Quota Checks
    
    /// Checks if team can add a member
    public func canAddTeamMember(currentCount: Int) -> QuotaCheckResult {
        let tier = entitlementManager.currentTier
        
        // Must be Team tier
        guard tier == .team else {
            return QuotaCheckResult.blocked(
                quotaType: .teamSeats,
                currentUsage: currentCount,
                limit: 0,
                message: QuotaMessages.teamTierRequired
            )
        }
        
        let limit = TierQuotas.teamSeatLimit
        
        if currentCount >= limit {
            return QuotaCheckResult.blocked(
                quotaType: .teamSeats,
                currentUsage: currentCount,
                limit: limit,
                message: QuotaMessages.teamSeatLimitReached(limit: limit)
            )
        }
        
        return QuotaCheckResult.allowed(
            quotaType: .teamSeats,
            currentUsage: currentCount,
            limit: limit
        )
    }
    
    /// Checks if team can upload an artifact today
    public func canUploadTeamArtifact(todayCount: Int) -> QuotaCheckResult {
        let tier = entitlementManager.currentTier
        
        guard tier == .team else {
            return QuotaCheckResult.blocked(
                quotaType: .teamArtifacts,
                currentUsage: todayCount,
                limit: 0,
                message: QuotaMessages.teamTierRequired
            )
        }
        
        let limit = TierQuotas.teamArtifactsPerDay
        
        if todayCount >= limit {
            return QuotaCheckResult.blocked(
                quotaType: .teamArtifacts,
                currentUsage: todayCount,
                limit: limit,
                message: QuotaMessages.teamArtifactLimitReached(limit: limit)
            )
        }
        
        return QuotaCheckResult.allowed(
            quotaType: .teamArtifacts,
            currentUsage: todayCount,
            limit: limit
        )
    }
    
    // MARK: - Sync Access Check
    
    /// Checks if user has sync access
    public func hasSyncAccess() -> Bool {
        let tier = entitlementManager.currentTier
        return TierQuotas.hasSyncAccess(for: tier)
    }
    
    /// Checks if user has team access
    public func hasTeamAccess() -> Bool {
        let tier = entitlementManager.currentTier
        return TierQuotas.hasTeamAccess(for: tier)
    }
    
    // MARK: - Paywall Control
    
    /// Triggers showing the paywall
    public func triggerPaywall() {
        showingPaywall = true
    }
    
    /// Dismisses the paywall
    public func dismissPaywall() {
        showingPaywall = false
    }
}

// MARK: - Tier Quotas (Single Source of Truth)

/// Defines quotas for each tier
public enum TierQuotas {
    
    // MARK: - Execution Limits
    
    /// Weekly execution limit by tier
    public static func weeklyExecutionLimit(for tier: SubscriptionTier) -> Int? {
        switch tier {
        case .free: return 25
        case .pro: return nil  // Unlimited
        case .team: return nil // Unlimited
        }
    }
    
    // MARK: - Memory Limits
    
    /// Memory item limit by tier
    public static func memoryItemLimit(for tier: SubscriptionTier) -> Int? {
        switch tier {
        case .free: return 10
        case .pro: return nil  // Unlimited
        case .team: return nil // Unlimited
        }
    }
    
    // MARK: - Team Limits
    
    /// Team seat limit (for Team tier)
    public static let teamSeatLimit = 100
    
    /// Team artifacts per day limit
    public static let teamArtifactsPerDay = 50
    
    // MARK: - Feature Access
    
    /// Whether tier has sync access
    public static func hasSyncAccess(for tier: SubscriptionTier) -> Bool {
        switch tier {
        case .free: return false
        case .pro: return true
        case .team: return true
        }
    }
    
    /// Whether tier has team access
    public static func hasTeamAccess(for tier: SubscriptionTier) -> Bool {
        switch tier {
        case .free: return false
        case .pro: return false
        case .team: return true
        }
    }
}

// MARK: - Quota Messages

/// User-facing quota messages
public enum QuotaMessages {
    
    public static func executionLimitReached(limit: Int) -> String {
        "You've reached your limit of \(limit) executions this week. Upgrade to Pro for unlimited executions."
    }
    
    public static func memoryLimitReached(limit: Int) -> String {
        "You've reached your limit of \(limit) memory items. Upgrade to Pro for unlimited memory."
    }
    
    public static let teamTierRequired = "Team features require a Team subscription."
    
    public static func teamSeatLimitReached(limit: Int) -> String {
        "Your team has reached the limit of \(limit) members."
    }
    
    public static func teamArtifactLimitReached(limit: Int) -> String {
        "You've reached the daily limit of \(limit) team artifacts. Try again tomorrow."
    }
    
    public static let syncRequiresPro = "Cloud sync requires Pro or Team subscription."
}
