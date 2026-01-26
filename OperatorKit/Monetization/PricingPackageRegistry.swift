import Foundation

// ============================================================================
// PRICING PACKAGE REGISTRY (Phase 11B, Updated Phase 11C)
//
// Single source of truth for pricing packages.
// App Store-safe copy. No hype, no anthropomorphic language.
//
// Phase 11C Updates:
// - Free: "25 Drafted Outcomes / week" language
// - Pro: $19/mo, $149/yr, Lifetime Sovereign $249 one-time
// - Team: $49/user/mo, min 3 seats, Procedure Sharing focus
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No hype
// ❌ No "secure/encrypted" claims
// ❌ No anthropomorphic AI language
// ❌ No promises
// ✅ Factual only
// ✅ Generic bullets
// ✅ Feature flags
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Pricing Tier

public enum PricingTier: String, Codable, CaseIterable {
    case free = "free"
    case pro = "pro"
    case team = "team"
    
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .team: return "Team"
        }
    }
    
    public var storeProductId: String {
        switch self {
        case .free: return ""  // No product
        case .pro: return "com.operatorkit.pro.monthly"
        case .team: return "com.operatorkit.team.monthly"
        }
    }
}

// MARK: - Purchase Type (Phase 11C)

public enum PurchaseType: String, Codable {
    case subscription = "subscription"
    case lifetime = "lifetime"
    
    public var displayName: String {
        switch self {
        case .subscription: return "Subscription"
        case .lifetime: return "One-Time"
        }
    }
}

// MARK: - Pricing Package

public struct PricingPackage: Codable, Identifiable {
    public let id: String
    public let tier: PricingTier
    public let headline: String
    public let bullets: [String]
    public let includedFeatures: [String]
    public let excludedFeatures: [String]
    public let storeKitDisclosure: String
    public let schemaVersion: Int
    
    // Phase 11C additions
    public let weeklyLimitLabel: String?
    public let monthlyPrice: String?
    public let annualPrice: String?
    public let lifetimePrice: String?
    public let minimumSeats: Int?
    public let pricePerUserPerMonth: String?
    
    public static let currentSchemaVersion = 2  // Bumped for Phase 11C
    
    public init(
        id: String,
        tier: PricingTier,
        headline: String,
        bullets: [String],
        includedFeatures: [String],
        excludedFeatures: [String],
        storeKitDisclosure: String,
        weeklyLimitLabel: String? = nil,
        monthlyPrice: String? = nil,
        annualPrice: String? = nil,
        lifetimePrice: String? = nil,
        minimumSeats: Int? = nil,
        pricePerUserPerMonth: String? = nil,
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.id = id
        self.tier = tier
        self.headline = headline
        self.bullets = bullets
        self.includedFeatures = includedFeatures
        self.excludedFeatures = excludedFeatures
        self.storeKitDisclosure = storeKitDisclosure
        self.weeklyLimitLabel = weeklyLimitLabel
        self.monthlyPrice = monthlyPrice
        self.annualPrice = annualPrice
        self.lifetimePrice = lifetimePrice
        self.minimumSeats = minimumSeats
        self.pricePerUserPerMonth = pricePerUserPerMonth
        self.schemaVersion = schemaVersion
    }
}

// MARK: - Pricing Package Registry

public enum PricingPackageRegistry {
    
    public static let schemaVersion = 2  // Bumped for Phase 11C
    
    // MARK: - Pricing Constants (Phase 11C)
    
    public static let freeWeeklyLimit = 25
    public static let freeWeeklyLimitLabel = "25 Drafted Outcomes / week"
    
    public static let proMonthlyPrice = "$19"
    public static let proAnnualPrice = "$149"
    public static let lifetimeSovereignPrice = "$249"
    
    public static let teamPricePerUserPerMonth = "$49"
    public static let teamMinimumSeats = 3
    
    // MARK: - Packages
    
    public static let free = PricingPackage(
        id: "package-free",
        tier: .free,
        headline: "Get started with draft-first assistance",
        bullets: [
            "Draft emails, tasks, and calendar events",
            "Review and approve before execution",
            "Local on-device processing",
            "25 Drafted Outcomes per week"
        ],
        includedFeatures: [
            "draft_generation",
            "approval_flow",
            "on_device_processing",
            "audit_trail",
            "quality_metrics"
        ],
        excludedFeatures: [
            "unlimited_outcomes",
            "optional_sync",
            "team_governance",
            "priority_support"
        ],
        storeKitDisclosure: "Free to download and use with weekly limits.",
        weeklyLimitLabel: freeWeeklyLimitLabel
    )
    
    public static let pro = PricingPackage(
        id: "package-pro",
        tier: .pro,
        headline: "Unlimited outcomes for individuals",
        bullets: [
            "Everything in Free",
            "Unlimited Drafted Outcomes",
            "Optional cloud sync",
            "Export all data anytime",
            "Lifetime Sovereign option available"
        ],
        includedFeatures: [
            "draft_generation",
            "approval_flow",
            "on_device_processing",
            "audit_trail",
            "quality_metrics",
            "unlimited_outcomes",
            "optional_sync",
            "full_export"
        ],
        excludedFeatures: [
            "team_governance",
            "shared_procedures",
            "team_diagnostics"
        ],
        storeKitDisclosure: "Subscription auto-renews monthly unless cancelled. One-time Lifetime Sovereign option also available. Manage in Settings > Subscriptions.",
        monthlyPrice: proMonthlyPrice,
        annualPrice: proAnnualPrice,
        lifetimePrice: lifetimeSovereignPrice
    )
    
    public static let team = PricingPackage(
        id: "package-team",
        tier: .team,
        headline: "Procedure sharing for teams",
        bullets: [
            "Everything in Pro",
            "Procedure sharing (templates and policies)",
            "Monthly audit export",
            "Shared diagnostics snapshots",
            "Enterprise readiness exports",
            "No shared drafts or user data"
        ],
        includedFeatures: [
            "draft_generation",
            "approval_flow",
            "on_device_processing",
            "audit_trail",
            "quality_metrics",
            "unlimited_outcomes",
            "optional_sync",
            "full_export",
            "team_governance",
            "shared_procedures",
            "team_diagnostics",
            "enterprise_exports",
            "monthly_audit_export"
        ],
        excludedFeatures: [],
        storeKitDisclosure: "Subscription auto-renews monthly unless cancelled. Minimum 3 seats required. Manage in Settings > Subscriptions.",
        pricePerUserPerMonth: teamPricePerUserPerMonth,
        minimumSeats: teamMinimumSeats
    )
    
    // MARK: - Lifetime Sovereign Option (Phase 11C)
    
    public static let lifetimeSovereign = PricingPackage(
        id: "package-lifetime-sovereign",
        tier: .pro,
        headline: "Own your workflow forever",
        bullets: [
            "Everything in Pro",
            "One-time purchase",
            "No recurring subscription",
            "Full local control"
        ],
        includedFeatures: [
            "draft_generation",
            "approval_flow",
            "on_device_processing",
            "audit_trail",
            "quality_metrics",
            "unlimited_outcomes",
            "optional_sync",
            "full_export"
        ],
        excludedFeatures: [
            "team_governance",
            "shared_procedures",
            "team_diagnostics"
        ],
        storeKitDisclosure: "One-time purchase. No subscription required.",
        lifetimePrice: lifetimeSovereignPrice
    )
    
    // MARK: - All Packages
    
    public static let all: [PricingPackage] = [free, pro, team, lifetimeSovereign]
    
    /// Subscription packages only (excludes lifetime)
    public static let subscriptionPackages: [PricingPackage] = [free, pro, team]
    
    public static func package(for tier: PricingTier) -> PricingPackage {
        switch tier {
        case .free: return free
        case .pro: return pro
        case .team: return team
        }
    }
    
    /// Check if lifetime option is available
    public static var hasLifetimeOption: Bool {
        lifetimeSovereign.lifetimePrice != nil
    }
    
    // MARK: - Validation
    
    /// Banned words that should not appear in pricing copy
    public static let bannedWords: [String] = [
        "secure", "encrypted", "protected", "safe",
        "AI thinks", "AI learns", "AI decides", "AI understands",
        "guaranteed", "promise", "ensure", "always will",
        "never fails", "perfect", "100%",
        "automatically sends", "monitors", "tracks you",
        "replaces", "autonomous"
    ]
    
    /// Validates all packages contain no banned words
    public static func validateNoBannedWords() -> [String] {
        var violations: [String] = []
        
        for package in all {
            let combined = ([package.headline] + package.bullets).joined(separator: " ").lowercased()
            
            for word in bannedWords {
                if combined.contains(word.lowercased()) {
                    violations.append("Package '\(package.id)' contains banned word: \(word)")
                }
            }
        }
        
        return violations
    }
    
    /// Validates no anthropomorphic language
    public static func validateNoAnthropomorphicLanguage() -> [String] {
        let anthropomorphicPatterns = [
            "AI thinks", "AI knows", "AI understands", "AI learns",
            "assistant thinks", "assistant knows", "decides for you"
        ]
        
        var violations: [String] = []
        
        for package in all {
            let combined = ([package.headline] + package.bullets).joined(separator: " ").lowercased()
            
            for pattern in anthropomorphicPatterns {
                if combined.contains(pattern.lowercased()) {
                    violations.append("Package '\(package.id)' contains anthropomorphic language: \(pattern)")
                }
            }
        }
        
        return violations
    }
    
    // MARK: - Phase 11C Validation
    
    /// Validates Free tier uses "Drafted Outcomes" language
    public static func validateFreeUsesDraftedOutcomesLanguage() -> Bool {
        let freeBullets = free.bullets.joined(separator: " ").lowercased()
        let freeLimit = free.weeklyLimitLabel?.lowercased() ?? ""
        return freeBullets.contains("drafted outcomes") || freeLimit.contains("drafted outcomes")
    }
    
    /// Validates Team minimum seats is 3
    public static func validateTeamMinimumSeats() -> Bool {
        team.minimumSeats == 3
    }
    
    /// Validates Lifetime price is set and matches constant
    public static func validateLifetimePriceConsistent() -> Bool {
        lifetimeSovereign.lifetimePrice == lifetimeSovereignPrice
    }
    
    /// Full validation
    public static func validateAll() -> (isValid: Bool, violations: [String]) {
        var allViolations: [String] = []
        
        allViolations.append(contentsOf: validateNoBannedWords())
        allViolations.append(contentsOf: validateNoAnthropomorphicLanguage())
        
        // Phase 11C checks
        if !validateFreeUsesDraftedOutcomesLanguage() {
            allViolations.append("Free tier should use 'Drafted Outcomes' language")
        }
        if !validateTeamMinimumSeats() {
            allViolations.append("Team minimum seats should be 3")
        }
        if !validateLifetimePriceConsistent() {
            allViolations.append("Lifetime price should match constant")
        }
        
        return (allViolations.isEmpty, allViolations)
    }
}

// MARK: - Registry Snapshot (for export)

public struct PricingPackageRegistrySnapshot: Codable {
    public let schemaVersion: Int
    public let packages: [PricingPackageSnapshot]
    public let capturedAtDayRounded: String
    
    // Phase 11C additions
    public let hasLifetimeOption: Bool
    public let teamMinimumSeats: Int
    public let freeWeeklyLimit: Int
    
    public struct PricingPackageSnapshot: Codable {
        public let id: String
        public let tier: String
        public let includedFeaturesCount: Int
        public let excludedFeaturesCount: Int
        public let hasLifetimePrice: Bool
        public let minimumSeats: Int?
    }
    
    public init() {
        self.schemaVersion = PricingPackageRegistry.schemaVersion
        self.capturedAtDayRounded = Self.dayRoundedNow()
        self.hasLifetimeOption = PricingPackageRegistry.hasLifetimeOption
        self.teamMinimumSeats = PricingPackageRegistry.teamMinimumSeats
        self.freeWeeklyLimit = PricingPackageRegistry.freeWeeklyLimit
        self.packages = PricingPackageRegistry.all.map { pkg in
            PricingPackageSnapshot(
                id: pkg.id,
                tier: pkg.tier.rawValue,
                includedFeaturesCount: pkg.includedFeatures.count,
                excludedFeaturesCount: pkg.excludedFeatures.count,
                hasLifetimePrice: pkg.lifetimePrice != nil,
                minimumSeats: pkg.minimumSeats
            )
        }
    }
    
    private static func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
