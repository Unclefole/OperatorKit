import Foundation

// ============================================================================
// STORE LISTING COPY (Phase 10K)
//
// Single source of truth for App Store listing copy.
// Hash-locked to prevent accidental drift.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No hype language
// ❌ No anthropomorphic AI
// ❌ No unproven security claims
// ❌ No background/tracking implications
// ✅ Factual, plain language
// ✅ Consistent with Claim Registry
// ✅ Hash-locked for drift detection
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Store Listing Copy

public enum StoreListingCopy {
    
    // MARK: - Primary Fields
    
    /// App title (max 30 characters)
    public static let title = "OperatorKit"
    
    /// App subtitle (max 30 characters)
    public static let subtitle = "On-device productivity"
    
    /// App description (max 4000 characters)
    public static let description = """
        OperatorKit helps you draft emails, create calendar events, and set reminders using on-device processing.
        
        HOW IT WORKS
        Type any request in plain language. OperatorKit creates a draft for you to review. You approve each action before it runs. Nothing happens without your explicit OK.
        
        DRAFT-FIRST DESIGN
        • Every action starts as a draft
        • You review before execution
        • Edit or cancel at any time
        • No autonomous actions
        
        ON-DEVICE PROCESSING
        • Uses Apple's on-device models
        • Your requests stay on your device
        • Works offline
        • No data sent to external servers
        
        WHAT YOU CAN DO
        • Draft emails and messages
        • Create calendar events
        • Set reminders and tasks
        • Save preferences locally
        
        PRIVACY BY DEFAULT
        • No ads
        • No tracking
        • No analytics
        • Your data stays yours
        
        SUBSCRIPTION OPTIONS
        Free: 25 drafted outcomes per week, 10 saved items
        Pro: Unlimited drafted outcomes, optional cloud sync
        Team: Procedure sharing and team governance
        
        All tiers include the same privacy guarantees.
        """
    
    /// Keywords (comma-separated, max 100 characters total)
    public static let keywords = "productivity,email,calendar,tasks,reminders,on-device,privacy,local,draft"
    
    // MARK: - Promotional Text
    
    /// Promotional text (max 170 characters, can be updated without review)
    public static let promotionalText = "Draft emails, create events, and set reminders. All processed on your device."
    
    // MARK: - What's New (Version 1.0)
    
    /// What's New text for initial release
    public static let whatsNewV1 = """
        Welcome to OperatorKit!
        
        • On-device productivity assistant
        • Draft emails, calendar events, and reminders
        • Approval required for all actions
        • No data sent to external servers
        • Free tier with full functionality
        """
    
    // MARK: - Validation
    
    /// Maximum lengths per Apple guidelines
    public static let maxTitleLength = 30
    public static let maxSubtitleLength = 30
    public static let maxDescriptionLength = 4000
    public static let maxKeywordsLength = 100
    public static let maxPromotionalLength = 170
    
    /// Validates all fields
    public static func validate() -> [String] {
        var errors: [String] = []
        
        if title.count > maxTitleLength {
            errors.append("Title exceeds \(maxTitleLength) characters")
        }
        
        if subtitle.count > maxSubtitleLength {
            errors.append("Subtitle exceeds \(maxSubtitleLength) characters")
        }
        
        if description.count > maxDescriptionLength {
            errors.append("Description exceeds \(maxDescriptionLength) characters")
        }
        
        if keywords.count > maxKeywordsLength {
            errors.append("Keywords exceed \(maxKeywordsLength) characters")
        }
        
        if promotionalText.count > maxPromotionalLength {
            errors.append("Promotional text exceeds \(maxPromotionalLength) characters")
        }
        
        // Check for banned words using PricingCopy validator
        let allText = [title, subtitle, description, keywords, promotionalText]
        for text in allText {
            let violations = PricingCopy.validate(text)
            errors.append(contentsOf: violations)
        }
        
        return errors
    }
    
    /// Concatenated content for hashing (deterministic order)
    public static var concatenatedContent: String {
        [
            "TITLE:\(title)",
            "SUBTITLE:\(subtitle)",
            "DESCRIPTION:\(description)",
            "KEYWORDS:\(keywords)",
            "PROMOTIONAL:\(promotionalText)"
        ].joined(separator: "\n---\n")
    }
}
