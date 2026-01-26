import Foundation

// ============================================================================
// TIER MATRIX (Phase 10G)
//
// Single source of truth for subscription tier capabilities.
// Used for UI display and quota enforcement.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ Does NOT affect execution modules
// ❌ No content storage
// ✅ UI-only enforcement
// ✅ Metadata-only
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Tier Matrix

/// Single source of truth for tier capabilities
public enum TierMatrix {
    
    // MARK: - Execution
    
    /// Weekly execution limit (nil = unlimited)
    public static func weeklyExecutionLimit(for tier: SubscriptionTier) -> Int? {
        switch tier {
        case .free: return 25
        case .pro: return nil
        case .team: return nil
        }
    }
    
    /// Daily execution limit (nil = unlimited)
    public static func dailyExecutionLimit(for tier: SubscriptionTier) -> Int? {
        switch tier {
        case .free: return 10
        case .pro: return nil
        case .team: return nil
        }
    }
    
    // MARK: - Memory
    
    /// Memory item limit (nil = unlimited)
    public static func memoryItemLimit(for tier: SubscriptionTier) -> Int? {
        switch tier {
        case .free: return 10
        case .pro: return nil
        case .team: return nil
        }
    }
    
    // MARK: - Sync
    
    /// Whether tier can use cloud sync
    public static func canSync(tier: SubscriptionTier) -> Bool {
        switch tier {
        case .free: return false
        case .pro: return true
        case .team: return true
        }
    }
    
    // MARK: - Team
    
    /// Whether tier can use team features
    public static func canUseTeam(tier: SubscriptionTier) -> Bool {
        tier == .team
    }
    
    /// Team seat limit
    public static let teamSeatLimit = 100
    
    /// Team artifacts per day limit
    public static let teamArtifactsPerDay = 50
    
    // MARK: - Features
    
    /// Whether tier has a specific feature
    public static func hasFeature(_ feature: TierFeature, for tier: SubscriptionTier) -> Bool {
        switch feature {
        case .localExecution:
            return true  // All tiers
            
        case .approvalRequired:
            return true  // All tiers (safety guarantee)
            
        case .basicDiagnostics:
            return true  // All tiers
            
        case .policyControls:
            return true  // All tiers
            
        case .unlimitedExecutions:
            return tier == .pro || tier == .team
            
        case .unlimitedMemory:
            return tier == .pro || tier == .team
            
        case .cloudSync:
            return tier == .pro || tier == .team
            
        case .qualityExports:
            return tier == .pro || tier == .team
            
        case .advancedDiagnostics:
            return tier == .pro || tier == .team
            
        case .teamGovernance:
            return tier == .team
            
        case .sharedPolicyTemplates:
            return tier == .team
            
        case .sharedDiagnostics:
            return tier == .team
            
        case .teamReleaseSignoff:
            return tier == .team
        }
    }
    
    // MARK: - Pricing Display
    
    /// Price display (for UI, actual price from StoreKit)
    public static func priceDisplay(for tier: SubscriptionTier) -> String {
        switch tier {
        case .free: return "Free"
        case .pro: return "Pro"
        case .team: return "Team"
        }
    }
    
    /// Short description
    public static func shortDescription(for tier: SubscriptionTier) -> String {
        switch tier {
        case .free: return "Limited but functional"
        case .pro: return "Unlimited personal use"
        case .team: return "Governance for teams"
        }
    }
}

// MARK: - Tier Feature

/// Features that can be enabled per tier
public enum TierFeature: String, CaseIterable {
    // Free tier features
    case localExecution = "local_execution"
    case approvalRequired = "approval_required"
    case basicDiagnostics = "basic_diagnostics"
    case policyControls = "policy_controls"
    
    // Pro tier features
    case unlimitedExecutions = "unlimited_executions"
    case unlimitedMemory = "unlimited_memory"
    case cloudSync = "cloud_sync"
    case qualityExports = "quality_exports"
    case advancedDiagnostics = "advanced_diagnostics"
    
    // Team tier features
    case teamGovernance = "team_governance"
    case sharedPolicyTemplates = "shared_policy_templates"
    case sharedDiagnostics = "shared_diagnostics"
    case teamReleaseSignoff = "team_release_signoff"
    
    public var displayName: String {
        switch self {
        case .localExecution: return "On-device execution"
        case .approvalRequired: return "Approval required"
        case .basicDiagnostics: return "Basic diagnostics"
        case .policyControls: return "Policy controls"
        case .unlimitedExecutions: return "Unlimited executions"
        case .unlimitedMemory: return "Unlimited memory"
        case .cloudSync: return "Cloud sync"
        case .qualityExports: return "Quality exports"
        case .advancedDiagnostics: return "Advanced diagnostics"
        case .teamGovernance: return "Team governance"
        case .sharedPolicyTemplates: return "Shared policy templates"
        case .sharedDiagnostics: return "Shared diagnostics"
        case .teamReleaseSignoff: return "Team release sign-off"
        }
    }
    
    public var icon: String {
        switch self {
        case .localExecution: return "iphone"
        case .approvalRequired: return "checkmark.shield"
        case .basicDiagnostics: return "chart.bar"
        case .policyControls: return "slider.horizontal.3"
        case .unlimitedExecutions: return "infinity"
        case .unlimitedMemory: return "brain.head.profile"
        case .cloudSync: return "icloud"
        case .qualityExports: return "square.and.arrow.up"
        case .advancedDiagnostics: return "chart.bar.doc.horizontal"
        case .teamGovernance: return "person.3"
        case .sharedPolicyTemplates: return "doc.on.doc"
        case .sharedDiagnostics: return "chart.bar.xaxis"
        case .teamReleaseSignoff: return "checkmark.seal"
        }
    }
}

// MARK: - Tier Summary

/// Summary of a tier for display
public struct TierSummary {
    public let tier: SubscriptionTier
    public let displayName: String
    public let shortDescription: String
    public let weeklyExecutionLimit: String
    public let memoryLimit: String
    public let features: [TierFeature]
    public let notIncluded: [TierFeature]
    
    public init(tier: SubscriptionTier) {
        self.tier = tier
        self.displayName = tier.displayName
        self.shortDescription = TierMatrix.shortDescription(for: tier)
        
        if let limit = TierMatrix.weeklyExecutionLimit(for: tier) {
            self.weeklyExecutionLimit = "\(limit)/week"
        } else {
            self.weeklyExecutionLimit = "Unlimited"
        }
        
        if let limit = TierMatrix.memoryItemLimit(for: tier) {
            self.memoryLimit = "\(limit) items"
        } else {
            self.memoryLimit = "Unlimited"
        }
        
        self.features = TierFeature.allCases.filter {
            TierMatrix.hasFeature($0, for: tier)
        }
        
        self.notIncluded = TierFeature.allCases.filter {
            !TierMatrix.hasFeature($0, for: tier)
        }
    }
}

// MARK: - Tier Upgrade Prompt

/// Determines which tier to recommend for upgrade
public struct TierUpgradePrompt {
    
    /// Gets recommended tier based on blocked feature
    public static func recommendedTier(for blockedFeature: TierFeature) -> SubscriptionTier {
        switch blockedFeature {
        case .unlimitedExecutions, .unlimitedMemory, .cloudSync, .qualityExports, .advancedDiagnostics:
            return .pro
            
        case .teamGovernance, .sharedPolicyTemplates, .sharedDiagnostics, .teamReleaseSignoff:
            return .team
            
        default:
            return .pro  // Default to Pro
        }
    }
    
    /// Gets recommended tier based on quota type
    public static func recommendedTier(for quotaType: QuotaType) -> SubscriptionTier {
        switch quotaType {
        case .weeklyExecutions, .memoryItems:
            return .pro
            
        case .teamSeats, .teamArtifacts:
            return .team
        }
    }
}
