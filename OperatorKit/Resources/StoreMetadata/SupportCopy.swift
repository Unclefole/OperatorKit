import Foundation
#if os(iOS)
import UIKit
#endif

// ============================================================================
// SUPPORT COPY (Phase 10I)
//
// Single source of truth for all support-related copy.
// App Store-safe language, no hype, no promises.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No hype language
// ❌ No guarantee/promise language
// ❌ No AI anthropomorphism
// ✅ Plain, factual language
// ✅ Clear instructions
// ✅ Apple-compliant refund guidance
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Support Copy

public enum SupportCopy {
    
    // MARK: - Contact Info
    
    public static let supportEmail = "support@operatorkit.app"
    public static let documentationURL = "https://operatorkit.app/docs"
    
    // MARK: - Email Templates
    
    public static let emailSubjectTemplate = "OperatorKit Support Request"
    
    public static let emailBodyTemplate = """
        Please describe your issue below:

        ---

        • App Version: {{APP_VERSION}}
        • iOS Version: {{IOS_VERSION}}
        • Device: {{DEVICE}}

        Issue Description:


        """

    /// Returns email body with device info auto-filled
    public static func emailBodyWithDeviceInfo() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        #if os(iOS)
        let iosVersion = UIDevice.current.systemVersion
        let device = UIDevice.current.model
        #else
        let iosVersion = "Unknown"
        let device = "Unknown"
        #endif

        return emailBodyTemplate
            .replacingOccurrences(of: "{{APP_VERSION}}", with: "\(appVersion) (\(buildNumber))")
            .replacingOccurrences(of: "{{IOS_VERSION}}", with: iosVersion)
            .replacingOccurrences(of: "{{DEVICE}}", with: device)
    }
    
    // MARK: - FAQ
    
    public static let faqItems: [FAQItem] = [
        FAQItem(
            question: "Does OperatorKit send my data to servers?",
            answer: "No. All processing happens on your device using Apple's on-device models. Your requests and content never leave your device unless you explicitly enable optional cloud sync."
        ),
        FAQItem(
            question: "Why does OperatorKit need approval for each action?",
            answer: "OperatorKit creates drafts of actions (like emails or calendar events) but never executes them automatically. You must approve each draft before it runs. This keeps you in control."
        ),
        FAQItem(
            question: "What's the difference between Free and Pro?",
            answer: "Free includes 25 executions per week and 10 saved items. Pro offers unlimited usage and optional cloud sync. Both tiers have identical privacy and safety guarantees."
        ),
        FAQItem(
            question: "Can I use OperatorKit offline?",
            answer: "Yes. All core features work offline since processing happens on your device. Cloud sync (Pro feature) requires internet when enabled."
        ),
        FAQItem(
            question: "How do I cancel my subscription?",
            answer: "Go to Settings > [Your Name] > Subscriptions > OperatorKit > Cancel Subscription. You'll retain access until the end of your billing period."
        ),
        FAQItem(
            question: "Is my data backed up?",
            answer: "Your local data is included in your device backup (iCloud or local). If you enable optional cloud sync (Pro), your metadata (not content) syncs across devices."
        )
    ]
    
    // MARK: - Troubleshooting
    
    public static let troubleshootingPermissions: [String] = [
        "Open the Settings app on your device",
        "Scroll down and tap OperatorKit",
        "Toggle on the permissions you want to grant (Calendar, Reminders, etc.)",
        "Return to OperatorKit and try your request again",
        "If prompted again, tap \"Allow\" when asked"
    ]
    
    public static let troubleshootingSiri: [String] = [
        "Open the Settings app",
        "Tap Siri & Search",
        "Scroll down and tap OperatorKit",
        "Enable \"Use with Siri\" and \"Show in Shortcuts\"",
        "Open the Shortcuts app to create custom shortcuts",
        "Say \"Hey Siri\" followed by your shortcut name"
    ]
    
    public static let troubleshootingRestore: [String] = [
        "Make sure you're signed in with the Apple ID used for the original purchase",
        "Open OperatorKit and go to Settings > Subscription",
        "Tap \"Restore Purchases\"",
        "Wait for the confirmation message",
        "If unsuccessful, check your purchase history in Settings > [Your Name] > Media & Purchases"
    ]
    
    public static let troubleshootingSync: [String] = [
        "Ensure you have an active internet connection",
        "Check that sync is enabled in Settings > Cloud Sync",
        "Try toggling sync off and on again",
        "Check your Supabase account connection status",
        "If sync was recently enabled, wait a few minutes for initial sync"
    ]
    
    // MARK: - Refund
    
    public static let refundInstructions = """
        Refunds for App Store purchases are handled by Apple, not by OperatorKit directly.
        
        To request a refund:
        
        1. Go to reportaproblem.apple.com
        2. Sign in with your Apple ID
        3. Find your OperatorKit purchase
        4. Tap "Request a refund"
        5. Select your reason and submit
        
        Apple reviews all refund requests. We cannot guarantee or influence refund decisions.
        """
    
    // MARK: - Review Notes
    
    public static let reviewNotesSupport = """
        OperatorKit includes a Help Center with:
        - FAQ (common questions answered)
        - Troubleshooting guides (permissions, Siri, restore, sync)
        - Contact Support (opens Mail composer, no auto-send)
        - Refund instructions (links to Apple's Report a Problem page)
        
        All support interactions are user-initiated. No automatic emails or data collection.
        """
    
    // MARK: - Validation
    
    public static let bannedSupportPhrases: [String] = [
        "guaranteed refund",
        "instant refund",
        "we will refund",
        "100% money back",
        "no questions asked",
        "AI assistant",
        "smart AI",
        "learns your preferences"
    ]
    
    public static func validate(_ text: String) -> [String] {
        var violations: [String] = []
        let lowercased = text.lowercased()
        
        for banned in bannedSupportPhrases {
            if lowercased.contains(banned.lowercased()) {
                violations.append("Contains banned phrase: '\(banned)'")
            }
        }
        
        return violations
    }
}

// MARK: - FAQ Item

public struct FAQItem {
    public let question: String
    public let answer: String
    
    public init(question: String, answer: String) {
        self.question = question
        self.answer = answer
    }
}
