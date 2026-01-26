import Foundation

/// Single source of truth for all privacy-related strings (Phase 6A)
/// These strings are used for:
/// - iOS permission dialogs (Info.plist)
/// - PrivacyControlsView
/// - DataUseDisclosureView
/// - App Store listing copy
///
/// All strings must:
/// - Match Apple's Human Interface Guidelines
/// - Match actual app behavior exactly
/// - Avoid overclaiming or future intent
/// - Use factual, non-marketing language
enum PrivacyStrings {
    
    // MARK: - Calendar
    
    enum Calendar {
        /// Usage description for NSCalendarsUsageDescription (Info.plist)
        static let usageDescription = "OperatorKit uses calendar access to show your events so you can select which ones to include as context for your requests. Events are only read when you explicitly select them."
        
        /// Short description for UI
        static let shortDescription = "View and select calendar events as context"
        
        /// Detailed explanation for disclosure view
        static let detailedExplanation = "When you grant calendar access, OperatorKit can display your upcoming and recent calendar events. You choose which events to include as context for your request. OperatorKit only reads events you explicitly select. If you enable calendar write access, OperatorKit can create or update events, but only after you review and confirm the exact details."
        
        /// What happens with permission
        static let withPermission = "You can select calendar events to include as context for your requests."
        
        /// What happens without permission
        static let withoutPermission = "Calendar events cannot be used as context. Grant access in Settings to enable this feature."
        
        /// Write access explanation
        static let writeExplanation = "Creating or updating calendar events requires your explicit confirmation. You will see the exact event details before any changes are made."
    }
    
    // MARK: - Reminders
    
    enum Reminders {
        /// Usage description for NSRemindersUsageDescription (Info.plist)
        static let usageDescription = "OperatorKit uses reminders access to create reminders on your behalf when you explicitly request and confirm them. Reminders are only created after you review and approve the details."
        
        /// Short description for UI
        static let shortDescription = "Create reminders that you approve"
        
        /// Detailed explanation for disclosure view
        static let detailedExplanation = "When you grant reminders access, OperatorKit can create reminders in your Reminders app. Reminders are only created after you review the title, notes, and due date, and explicitly confirm the creation. OperatorKit never modifies or deletes existing reminders."
        
        /// What happens with permission
        static let withPermission = "You can create reminders after reviewing and confirming the details."
        
        /// What happens without permission
        static let withoutPermission = "Reminders cannot be created. Grant access in Settings to enable this feature."
        
        /// Write confirmation explanation
        static let writeConfirmation = "Every reminder creation requires you to confirm the exact title, notes, and due date before it is saved."
    }
    
    // MARK: - Mail
    
    enum Mail {
        /// Short description for UI (no Info.plist key needed for Mail composer)
        static let shortDescription = "Open email drafts for your review"
        
        /// Detailed explanation for disclosure view
        static let detailedExplanation = "OperatorKit uses the system email composer to present draft emails. The email is pre-filled with content you have reviewed and approved. You control when and whether to send the email. OperatorKit cannot send emails automatically and cannot read your existing emails."
        
        /// What happens with capability
        static let withCapability = "You can open draft emails in the system composer, then choose whether to send them."
        
        /// What happens without capability
        static let withoutCapability = "Email drafts cannot be opened. Ensure Mail is configured on this device."
        
        /// Sending explanation
        static let sendingExplanation = "OperatorKit never sends emails automatically. You must tap Send in the email composer to send any email."
    }
    
    // MARK: - Siri
    
    enum Siri {
        /// Usage description for NSSiriUsageDescription (Info.plist)
        static let usageDescription = "OperatorKit uses Siri to let you start requests by voice. Siri only opens the app and pre-fills your request—it cannot execute actions or access your data. You always review and approve before anything happens."
        
        /// Short description for UI
        static let shortDescription = "Start requests using Siri voice commands"
        
        /// Detailed explanation for disclosure view
        static let detailedExplanation = "When you use Siri with OperatorKit, Siri opens the app and pre-fills your spoken request. Siri does not execute any actions, access any data, or make any decisions. After Siri opens the app, you review the pre-filled request and decide whether to continue. All subsequent actions require your explicit approval."
        
        /// What Siri can do
        static let capabilities = "Siri can open OperatorKit and pre-fill your spoken request."
        
        /// What Siri cannot do
        static let limitations = "Siri cannot access your data, execute actions, or bypass the approval process. Siri is a voice entry point only."
        
        /// Siri routing explanation
        static let routingExplanation = "Siri acts as a router to OperatorKit. After Siri opens the app, you are in full control of what happens next."
    }
    
    // MARK: - General Privacy
    
    enum General {
        /// Main privacy statement
        static let mainStatement = "OperatorKit is designed to keep your data private and give you control over every action."
        
        /// On-device processing statement
        static let onDeviceStatement = "All processing happens on your device. No data is sent to external servers."
        
        /// No network statement
        static let noNetworkStatement = "OperatorKit does not make network requests and does not transmit your data."
        
        /// No background access statement
        static let noBackgroundStatement = "OperatorKit does not access data in the background. All data access happens only when you are actively using the app."
        
        /// User control statement
        static let userControlStatement = "You control which data is accessed, what actions are taken, and when they occur. Nothing happens without your explicit approval."
        
        /// Audit trail statement
        static let auditTrailStatement = "OperatorKit maintains a local audit trail of your requests and executions. This information stays on your device and is viewable in the Memory section."
    }
    
    // MARK: - App Store Privacy Labels
    
    /// Information for App Store Privacy Labels
    /// These describe what data is collected and how it is used
    enum AppStoreLabels {
        /// Data types that may be collected
        static let dataTypesCollected = """
        OperatorKit may access the following data types, only when you grant permission and explicitly select items:
        - Calendar events (titles, times, participants)
        - Reminders (for creation only)
        
        This data is:
        - Used only for app functionality
        - Not linked to your identity
        - Not used for tracking
        - Processed entirely on-device
        - Never transmitted to servers
        """
        
        /// Data not collected
        static let dataNotCollected = """
        OperatorKit does not collect:
        - Contact information
        - Health data
        - Financial data
        - Location data
        - Browsing history
        - Usage analytics
        - Crash reports sent externally
        - Any data for advertising
        """
        
        /// Purpose descriptions
        static let purposeDescription = """
        Data accessed by OperatorKit is used solely to:
        - Provide context for your requests
        - Generate drafts for your review
        - Execute actions you explicitly approve
        
        No data is used for advertising, analytics, or any other purpose.
        """
    }
}

// MARK: - String Extensions for Localization Preparation

extension PrivacyStrings {
    /// Returns all strings that should be localized for international releases
    /// Currently returns English; ready for localization
    static var allLocalizableStrings: [String: String] {
        [
            "calendar.usage": Calendar.usageDescription,
            "calendar.short": Calendar.shortDescription,
            "reminders.usage": Reminders.usageDescription,
            "reminders.short": Reminders.shortDescription,
            "mail.short": Mail.shortDescription,
            "siri.usage": Siri.usageDescription,
            "siri.short": Siri.shortDescription,
            "general.main": General.mainStatement,
            "general.onDevice": General.onDeviceStatement,
            "general.noNetwork": General.noNetworkStatement
        ]
    }
}
