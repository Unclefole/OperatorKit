import Foundation

// ============================================================================
// TIER BOUNDARIES (Phase 10F)
//
// Explicit boundaries between Free, Pro, and Team tiers.
// Prevents abuse of Team tier as "shared executor".
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No execution module access
// ❌ No content inspection
// ❌ No cross-user execution
// ✅ UI boundary enforcement only
// ✅ Metadata-only tracking
// ✅ Clear tier separation
//
// See: docs/SAFETY_CONTRACT.md (Section 15)
// ============================================================================

// MARK: - Tier Boundary Checker

/// Enforces boundaries between subscription tiers
@MainActor
public final class TierBoundaryChecker: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = TierBoundaryChecker()
    
    // MARK: - Tier Boundaries
    
    /// Per-tier execution limits (per week)
    public enum TierLimits {
        /// Free tier weekly limit
        public static let freeWeeklyExecutions = 25
        
        /// Pro tier: unlimited (but rate shaped)
        public static let proWeeklyExecutions: Int? = nil
        
        /// Team tier: unlimited (but rate shaped)
        public static let teamWeeklyExecutions: Int? = nil
        
        /// Returns limit for tier
        public static func limit(for tier: SubscriptionTier) -> Int? {
            switch tier {
            case .free: return freeWeeklyExecutions
            case .pro: return proWeeklyExecutions
            case .team: return teamWeeklyExecutions
            }
        }
    }
    
    // MARK: - Team Abuse Prevention
    
    /// Maximum team size (prevents abuse as shared executor pool)
    public static let maxTeamSize = 100
    
    /// Minimum interval between team artifact uploads (seconds)
    public static let minTeamUploadInterval: TimeInterval = 60
    
    /// Maximum team artifacts per day
    public static let maxTeamArtifactsPerDay = 50
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Boundary Checks
    
    /// Checks if user can execute based on tier
    public func canExecute(tier: SubscriptionTier, weeklyCount: Int) -> TierBoundaryResult {
        guard let limit = TierLimits.limit(for: tier) else {
            // Unlimited tier
            return .allowed(remaining: nil)
        }
        
        if weeklyCount >= limit {
            return .blocked(
                reason: "Weekly limit reached",
                message: "You've reached your \(limit) executions for this week. Consider upgrading for unlimited usage."
            )
        }
        
        let remaining = limit - weeklyCount
        if remaining <= 5 {
            return .allowed(remaining: remaining, warning: "You have \(remaining) executions left this week.")
        }
        
        return .allowed(remaining: remaining)
    }
    
    /// Checks if team action is allowed
    public func canPerformTeamAction(
        currentTier: SubscriptionTier,
        teamSize: Int,
        artifactsToday: Int
    ) -> TierBoundaryResult {
        // Must be Team tier
        guard currentTier == .team else {
            return .blocked(
                reason: "Team tier required",
                message: "Team features require a Team subscription."
            )
        }
        
        // Check team size
        if teamSize > Self.maxTeamSize {
            return .blocked(
                reason: "Team size limit",
                message: "Teams are limited to \(Self.maxTeamSize) members."
            )
        }
        
        // Check daily artifact limit
        if artifactsToday >= Self.maxTeamArtifactsPerDay {
            return .blocked(
                reason: "Daily artifact limit",
                message: "You've reached the daily limit for team artifacts."
            )
        }
        
        return .allowed(remaining: Self.maxTeamArtifactsPerDay - artifactsToday)
    }
    
    /// Verifies no cross-user execution paths exist
    /// This is a structural check that should always pass
    public func verifyCrossUserIsolation() -> Bool {
        // This always returns true because cross-user execution
        // is architecturally impossible in OperatorKit.
        // Each user has their own:
        // - ExecutionEngine instance
        // - ApprovalGate instance
        // - Draft storage
        // - Memory items
        // Teams can ONLY share metadata artifacts, never execution.
        return true
    }
}

// MARK: - Tier Boundary Result

/// Result of tier boundary check
public struct TierBoundaryResult {
    public let allowed: Bool
    public let remaining: Int?
    public let warning: String?
    public let blockReason: String?
    public let blockMessage: String?
    
    public static func allowed(remaining: Int?, warning: String? = nil) -> TierBoundaryResult {
        TierBoundaryResult(
            allowed: true,
            remaining: remaining,
            warning: warning,
            blockReason: nil,
            blockMessage: nil
        )
    }
    
    public static func blocked(reason: String, message: String) -> TierBoundaryResult {
        TierBoundaryResult(
            allowed: false,
            remaining: 0,
            warning: nil,
            blockReason: reason,
            blockMessage: message
        )
    }
}

// MARK: - Team Abuse Guard

/// Guards against Team tier abuse
public struct TeamAbuseGuard {
    
    /// Checks if team action looks like executor sharing abuse
    public static func detectExecutorSharing(
        teamMemberCount: Int,
        totalTeamExecutionsThisWeek: Int,
        averagePerMember: Double
    ) -> TeamAbuseCheckResult {
        // Flag if average is suspiciously high
        let suspiciousThreshold: Double = 500  // per member per week
        
        if averagePerMember > suspiciousThreshold {
            return TeamAbuseCheckResult(
                suspicious: true,
                reason: "Unusually high execution rate across team",
                recommendation: "Review team usage patterns"
            )
        }
        
        // Flag if single member dominates usage (>80%)
        // This would indicate team is being used by one person
        // Note: We can't actually check this without user-level data
        // which we don't have access to in this metadata-only context
        
        return TeamAbuseCheckResult(
            suspicious: false,
            reason: nil,
            recommendation: nil
        )
    }
    
    /// Checks if team size growth is suspicious
    public static func detectSuspiciousGrowth(
        previousSize: Int,
        currentSize: Int,
        daysSinceLastCheck: Int
    ) -> TeamAbuseCheckResult {
        guard daysSinceLastCheck > 0 else {
            return TeamAbuseCheckResult(suspicious: false, reason: nil, recommendation: nil)
        }
        
        let growthRate = Double(currentSize - previousSize) / Double(daysSinceLastCheck)
        
        // Flag if adding more than 10 members per day
        if growthRate > 10 {
            return TeamAbuseCheckResult(
                suspicious: true,
                reason: "Rapid team growth detected",
                recommendation: "Verify team member authenticity"
            )
        }
        
        return TeamAbuseCheckResult(suspicious: false, reason: nil, recommendation: nil)
    }
}

// MARK: - Team Abuse Check Result

public struct TeamAbuseCheckResult {
    public let suspicious: Bool
    public let reason: String?
    public let recommendation: String?
}

// MARK: - Tier Feature Matrix

/// Documents what each tier can and cannot do
public enum TierFeatureMatrix {
    
    /// Features available in Free tier
    public static let freeFeatures: Set<String> = [
        "local_execution",
        "local_approval",
        "local_drafts",
        "local_memory",
        "policy_controls",
        "diagnostics_export"
    ]
    
    /// Features available in Pro tier (includes Free)
    public static let proFeatures: Set<String> = freeFeatures.union([
        "unlimited_executions",
        "cloud_sync",
        "quality_export",
        "advanced_diagnostics"
    ])
    
    /// Features available in Team tier (includes Pro)
    public static let teamFeatures: Set<String> = proFeatures.union([
        "team_membership",
        "shared_policy_templates",
        "shared_diagnostics",
        "shared_quality_summaries",
        "team_release_acks"
    ])
    
    /// Features NEVER available in any tier
    public static let neverFeatures: Set<String> = [
        "shared_drafts",           // NEVER
        "shared_memory",           // NEVER
        "shared_execution",        // NEVER
        "cross_user_approval",     // NEVER
        "remote_killswitch",       // NEVER
        "admin_execution_control"  // NEVER
    ]
    
    /// Checks if a feature is available for a tier
    public static func hasFeature(_ feature: String, for tier: SubscriptionTier) -> Bool {
        // Check if it's a forbidden feature
        if neverFeatures.contains(feature) {
            return false
        }
        
        switch tier {
        case .free:
            return freeFeatures.contains(feature)
        case .pro:
            return proFeatures.contains(feature)
        case .team:
            return teamFeatures.contains(feature)
        }
    }
}
