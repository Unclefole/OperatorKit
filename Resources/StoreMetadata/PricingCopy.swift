import Foundation

// ============================================================================
// PRICING COPY (Phase 10H)
//
// Single source of truth for all pricing-related copy.
// App Store-safe language with no hype or banned terms.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No "AI learns/decides"
// ❌ No anthropomorphic language
// ❌ No unproven security claims
// ❌ No hype words ("amazing", "revolutionary")
// ✅ Plain, factual language
// ✅ Clear feature descriptions
// ✅ Honest limitations
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Pricing Copy

/// Single source of truth for pricing language
public enum PricingCopy {
    
    // MARK: - Taglines
    
    /// Main tagline for pricing screen
    public static let tagline = "Productivity on your device, on your terms."
    
    /// Short tagline for App Store
    public static let shortTagline = "On-device productivity assistant"
    
    // MARK: - Value Props
    
    /// What users get (factual, no hype)
    public static let valueProps: [String] = [
        "Runs entirely on your device",
        "No ads or tracking",
        "Your data stays yours",
        "Works offline",
        "Regular updates included"
    ]
    
    // MARK: - Tier Bullets
    
    /// Feature bullets for each tier
    public static func tierBullets(for tier: SubscriptionTier) -> [String] {
        switch tier {
        case .free:
            return [
                "25 executions per week",
                "10 saved items",
                "Local processing",
                "Approval required"
            ]
            
        case .pro:
            return [
                "Unlimited executions",
                "Unlimited saved items",
                "Optional cloud sync",
                "Quality exports"
            ]
            
        case .team:
            return [
                "Everything in Pro",
                "Team governance",
                "Shared policy templates",
                "Team diagnostics"
            ]
        }
    }
    
    // MARK: - Subscription Disclosure
    
    /// Required subscription disclosure
    public static let subscriptionDisclosure = """
        Payment will be charged to your Apple ID account at confirmation of purchase. \
        Subscription automatically renews unless it is cancelled at least 24 hours before the \
        end of the current period. Your account will be charged for renewal within 24 hours \
        prior to the end of the current period. You can manage and cancel your subscriptions \
        by going to your account settings on the App Store after purchase.
        """
    
    // MARK: - Why We Charge
    
    /// Explanation of why we charge
    public static let whyWeCharge = """
        OperatorKit runs entirely on your device. There are no ads, no tracking, and no data \
        collection. Your subscription directly supports ongoing development.
        """
    
    // MARK: - Error Messages
    
    /// Purchase failed message
    public static let purchaseFailed = "Purchase could not be completed. Please try again or restore your purchases."
    
    /// Restore failed message
    public static let restoreFailed = "Could not restore purchases. Please check your Apple ID and try again."
    
    /// Network error message
    public static let networkError = "Could not connect to the App Store. Please check your connection and try again."
    
    // MARK: - Review Notes
    
    /// Notes for App Store review team
    public static let reviewNotes = """
        OperatorKit is a productivity app that processes user requests on-device using Apple's \
        Foundation Models API. All processing happens locally - no user content is transmitted \
        to external servers.
        
        Subscription unlocks:
        - Pro: Unlimited usage, optional cloud sync (metadata only)
        - Team: Team governance features for organizations
        
        Free tier is fully functional with usage limits. All tiers have identical privacy guarantees.
        """
    
    // MARK: - Validation
    
    /// Maximum length for tagline (App Store limit)
    public static let maxTaglineLength = 30
    
    /// Maximum length for short description
    public static let maxShortDescriptionLength = 170
    
    /// Banned words that should never appear
    public static let bannedWords: [String] = [
        "amazing",
        "revolutionary",
        "AI decides",
        "AI learns",
        "AI thinks",
        "smart AI",
        "intelligent AI",
        "secure",       // Unless proven
        "encrypted",    // Unless proven
        "guaranteed",
        "100%",
        "best",
        "fastest",
        "most powerful"
    ]
    
    /// Validates copy for banned words
    public static func validate(_ text: String) -> [String] {
        var violations: [String] = []
        let lowercased = text.lowercased()
        
        for banned in bannedWords {
            if lowercased.contains(banned.lowercased()) {
                violations.append("Contains banned word: '\(banned)'")
            }
        }
        
        return violations
    }
}

// MARK: - App Store Metadata

/// App Store submission metadata
public enum AppStoreMetadata {
    
    /// App name
    public static let appName = "OperatorKit"
    
    /// Subtitle
    public static let subtitle = "On-device productivity"
    
    /// Promotional text
    public static let promotionalText = """
        Draft emails, create tasks, and manage your calendar - all processed locally on your device.
        """
    
    /// Description
    public static let description = """
        OperatorKit helps you draft emails, create calendar events, and manage tasks using on-device \
        processing. Your requests are processed locally - no data is sent to external servers.
        
        FEATURES
        • Draft emails and messages
        • Create calendar events
        • Set reminders and tasks
        • Save preferences locally
        
        PRIVACY
        • On-device processing
        • No ads or tracking
        • Your data stays on your device
        • No account required for basic features
        
        SUBSCRIPTION
        • Free: 25 executions/week, 10 saved items
        • Pro: Unlimited usage, optional cloud sync
        • Team: Team governance and shared policies
        """
    
    /// Keywords (comma-separated)
    public static let keywords = "productivity,email,calendar,tasks,reminders,on-device,privacy"
    
    /// Primary category
    public static let primaryCategory = "Productivity"
    
    /// Secondary category
    public static let secondaryCategory = "Utilities"
}

// MARK: - Intro Offer Scaffolding

/// Scaffolding for intro offers (not enabled in v1)
public struct IntroOfferConfig {
    
    /// Whether intro offers are enabled
    public static let isEnabled = false
    
    /// Offer type
    public enum OfferType: String {
        case freeTrial = "free_trial"
        case payAsYouGo = "pay_as_you_go"
        case payUpFront = "pay_up_front"
    }
    
    /// Offer duration (days)
    public let durationDays: Int
    
    /// Offer type
    public let type: OfferType
    
    /// Display text
    public var displayText: String {
        switch type {
        case .freeTrial:
            return "\(durationDays)-day free trial"
        case .payAsYouGo:
            return "Intro pricing available"
        case .payUpFront:
            return "Discounted first period"
        }
    }
    
    // Note: Actual offers are configured in App Store Connect,
    // not hardcoded here. This is just for UI display scaffolding.
}
