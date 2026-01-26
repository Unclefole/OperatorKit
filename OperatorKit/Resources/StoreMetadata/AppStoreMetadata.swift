import Foundation

// MARK: - App Store Metadata (Phase 7B)
//
// Single source of truth for all App Store Connect metadata.
// This file ensures consistency between the app and store listing.
//
// NOTE: This is TEXT ONLY for reference. Actual submission is via App Store Connect.

/// App Store metadata constants
public enum AppStoreMetadata {
    
    // MARK: - App Identity
    
    /// App name as it appears on the App Store
    public static let appName = "OperatorKit"
    
    /// Subtitle (30 characters max)
    public static let subtitle = "On-Device Task Assistant"
    
    /// Bundle identifier
    public static let bundleIdentifier = "com.operatorkit.app"
    
    // MARK: - Categories
    
    /// Primary category
    public static let primaryCategory = "Productivity"
    
    /// Secondary category (optional)
    public static let secondaryCategory = "Utilities"
    
    // MARK: - Age Rating
    
    /// Content rating
    public static let ageRating = "4+"
    
    /// Rating rationale
    public static let ageRatingRationale = "No objectionable content. No user-generated content. No in-app purchases."
    
    // MARK: - Descriptions
    
    /// Promotional text (170 characters max, can be updated without review)
    public static let promotionalText = """
    Draft emails, create reminders, and manage calendar events with complete control. All processing happens on your device—no data leaves your phone.
    """
    
    /// Full description
    public static let fullDescription = """
    OperatorKit is an on-device task assistant that helps you draft emails, create reminders, and manage calendar events—all with your explicit approval.

    PRIVACY-FIRST DESIGN
    • All processing happens on your device
    • No data is sent to external servers
    • No analytics or tracking
    • You control every action

    DRAFT-FIRST WORKFLOW
    • Every action produces a draft for your review
    • Edit and approve before anything happens
    • Two-step confirmation for write operations

    SIRI INTEGRATION
    • Start requests with your voice
    • Siri opens the app—you decide what happens next
    • Full approval flow still required

    CALENDAR & REMINDERS
    • Select specific events to use as context
    • Create reminders with your confirmation
    • Update calendar events you've selected

    COMPLETE TRANSPARENCY
    • See exactly what data is used
    • Review all actions before execution
    • Memory shows your complete history

    OperatorKit never acts without your approval. Every email draft, reminder, and calendar update requires your explicit confirmation before anything happens.
    """
    
    /// Keywords (100 characters max total, comma-separated)
    public static let keywords = "productivity,email,draft,reminder,calendar,privacy,on-device,assistant,task,planner"
    
    // MARK: - What's New
    
    /// Version release notes template
    public static func whatsNew(version: String) -> String {
        """
        Version \(version)
        
        • On-device text generation for email drafts
        • Calendar event selection as context
        • Reminder creation with two-step confirmation
        • Complete audit trail in Memory
        • Privacy-first design: all processing on-device
        """
    }
    
    // MARK: - Support Information
    
    /// Support URL
    public static let supportURL = "https://operatorkit.app/support"
    
    /// Marketing URL
    public static let marketingURL = "https://operatorkit.app"
    
    /// Privacy policy URL
    public static let privacyPolicyURL = "https://operatorkit.app/privacy"
    
    // MARK: - Review Notes
    
    /// Notes for App Review
    public static let reviewNotes = """
    OperatorKit is a privacy-focused task assistant that generates drafts for email, reminders, and calendar events. All processing is on-device.

    KEY POINTS FOR REVIEW:

    1. SIRI INTEGRATION
    Siri opens the app and pre-fills text but CANNOT execute actions. Users must complete the in-app approval flow. Test: "Hey Siri, ask OperatorKit to draft an email"

    2. CALENDAR ACCESS
    Calendar events are only read when the user opens the Context Picker and selects specific events. No background access. Limited to ±7 days, max 50 events.

    3. REMINDER CREATION
    Creating reminders requires TWO confirmations: first in the Approval screen, then in a dedicated confirmation modal showing exact details.

    4. EMAIL DRAFTS
    The app opens the system Mail composer. It cannot send emails automatically—users must tap Send in Mail.

    5. ON-DEVICE PROCESSING
    All text generation uses on-device models or deterministic templates. No data is transmitted externally.

    TEST ACCOUNT: Not required. The app uses the device's calendar and reminders with permission.

    ADDITIONAL INFORMATION: See in-app "Reviewer Help" (Privacy Controls → Reviewer Help) for a 2-minute test plan.
    """
    
    // MARK: - Privacy Labels
    
    /// Data not collected declaration
    public static let dataNotCollected = true
    
    /// Data types accessed (for transparency, not collection)
    public static let dataTypesAccessed = """
    Calendar Events: Used for app functionality only, not linked to identity, not used for tracking
    Reminders: Created on user request only, not linked to identity
    """
    
    /// Tracking declaration
    public static let usesTracking = false
    
    // MARK: - Export Compliance
    
    /// Uses encryption?
    public static let usesEncryption = true  // Standard iOS encryption
    
    /// Encryption type
    public static let encryptionType = "Standard iOS data protection (Apple frameworks only)"
    
    /// Export compliance exempt
    public static let exportComplianceExempt = true  // Standard encryption, no custom algorithms
    
    // MARK: - Screenshots
    
    /// Screenshot descriptions for each required screenshot
    public static let screenshotDescriptions = [
        "1_home": "Home screen showing the main input card and recent operations",
        "2_context": "Context Picker showing calendar events available for selection",
        "3_draft": "Draft Output showing generated email with confidence indicator",
        "4_approval": "Approval screen with side effects clearly displayed",
        "5_confirm": "Two-key confirmation modal for reminder creation",
        "6_complete": "Execution Complete screen with success confirmation",
        "7_memory": "Memory view showing audit trail of completed actions",
        "8_privacy": "Privacy Controls showing permission status and data disclosure"
    ]
}

// MARK: - Validation

extension AppStoreMetadata {
    
    /// Validates that metadata meets App Store requirements
    public static func validate() -> [String] {
        var issues: [String] = []
        
        // Subtitle length
        if subtitle.count > 30 {
            issues.append("Subtitle exceeds 30 characters (\(subtitle.count))")
        }
        
        // Promotional text length
        if promotionalText.count > 170 {
            issues.append("Promotional text exceeds 170 characters (\(promotionalText.count))")
        }
        
        // Keywords length
        if keywords.count > 100 {
            issues.append("Keywords exceed 100 characters (\(keywords.count))")
        }
        
        // Description length (4000 characters max)
        if fullDescription.count > 4000 {
            issues.append("Description exceeds 4000 characters (\(fullDescription.count))")
        }
        
        return issues
    }
    
    /// Summary for debugging
    public static var summary: String {
        """
        App Store Metadata Summary
        ==========================
        App Name: \(appName)
        Subtitle: \(subtitle) (\(subtitle.count)/30 chars)
        Category: \(primaryCategory)
        Age Rating: \(ageRating)
        
        Promotional Text: \(promotionalText.count)/170 chars
        Description: \(fullDescription.count)/4000 chars
        Keywords: \(keywords.count)/100 chars
        
        Privacy:
        - Data Not Collected: \(dataNotCollected)
        - Uses Tracking: \(usesTracking)
        
        Export Compliance:
        - Uses Encryption: \(usesEncryption)
        - Exempt: \(exportComplianceExempt)
        
        Validation: \(validate().isEmpty ? "✓ All checks passed" : "⚠️ \(validate().count) issues")
        """
    }
}
