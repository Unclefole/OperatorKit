import Foundation

// ============================================================================
// SUBMISSION COPY (Phase 10J)
//
// Templates for App Store submission: Review Notes, What's New, disclosures.
// Single source of truth for all submission copy.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No hype language
// ❌ No anthropomorphic AI language
// ❌ No unproven security claims
// ❌ No "tracks", "monitors", "automatic sending"
// ✅ Factual, plain language
// ✅ Length-validated for App Store limits
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Submission Copy

public enum SubmissionCopy {
    
    // MARK: - Review Notes Template
    
    /// Template for App Store review notes
    public static func reviewNotesTemplate(version: String, build: String) -> String {
        """
        OperatorKit \(version) (\(build))
        
        WHAT THIS APP DOES
        OperatorKit helps users draft emails, create calendar events, and set reminders using on-device processing. All requests are processed locally using Apple's Foundation Models API.
        
        KEY BEHAVIORS
        - Draft-first: Every action is prepared as a draft for user review
        - Approval required: Users must approve each draft before execution
        - No autonomous actions: The app never acts without explicit user approval
        - On-device processing: No user content is sent to external servers
        
        SUBSCRIPTION TIERS
        - Free: 25 drafted outcomes/week, 10 saved items, fully functional
        - Pro: Unlimited drafted outcomes, optional cloud sync (metadata only)
        - Team: Procedure sharing and team governance
        
        DATA HANDLING
        - All processing happens on-device
        - Optional cloud sync transmits metadata only, never user content
        - Local conversion counters track upgrade taps (no identifiers)
        - No analytics SDKs are used
        
        HOW TO TEST
        1. Type any request (e.g., "Draft an email to schedule a meeting")
        2. Review the generated draft
        3. Approve or edit before execution
        4. Check Settings for privacy controls and subscription options
        
        RESTORE PURCHASES
        Settings → Subscription → Restore Purchases
        
        CONTACT
        support@operatorkit.app
        """
    }
    
    // MARK: - What's New Template
    
    /// Template for What's New section
    public static func whatsNewTemplate(version: String, highlights: [String]) -> String {
        var result = "Version \(version)\n\n"
        
        for highlight in highlights {
            result += "• \(highlight)\n"
        }
        
        result += "\nThank you for using OperatorKit."
        return result
    }
    
    /// Default highlights for initial release
    public static let defaultHighlights: [String] = [
        "On-device productivity assistant",
        "Draft emails, calendar events, and reminders",
        "Approval required for all actions",
        "No data sent to external servers",
        "Free tier with full functionality"
    ]
    
    // MARK: - Privacy Disclosure
    
    /// Privacy disclosure blurb
    public static let privacyDisclosureBlurb = """
        OperatorKit processes all requests on your device using Apple's Foundation Models API. \
        Your content never leaves your device unless you explicitly enable optional cloud sync, \
        which transmits metadata only (not content). We do not use analytics SDKs or tracking. \
        Local counters track upgrade taps for conversion measurement without identifying you.
        """
    
    // MARK: - Monetization Disclosure
    
    /// Monetization disclosure blurb
    public static let monetizationDisclosureBlurb = """
        OperatorKit offers three subscription tiers:
        
        FREE: 25 drafted outcomes per week, 10 saved items. Fully functional with no feature restrictions \
        beyond usage limits. No payment required.
        
        PRO: Unlimited drafted outcomes and saved items. Optional cloud sync (metadata only). \
        Billed monthly or annually through your Apple ID.
        
        TEAM: Everything in Pro plus procedure sharing, team governance, and \
        team diagnostics. Billed monthly or annually through your Apple ID.
        
        All tiers include the same privacy and safety guarantees. Restore purchases is available \
        in Settings. Subscriptions auto-renew unless cancelled 24 hours before the period ends.
        """
    
    // MARK: - Export Compliance
    
    /// Export compliance statement
    public static let exportComplianceStatement = """
        OperatorKit uses only standard Apple frameworks and does not implement custom encryption. \
        The app uses Apple's Foundation Models API for on-device processing and standard Apple \
        frameworks for data storage. No custom cryptographic algorithms are used.
        """
    
    // MARK: - Validation
    
    /// Banned words that must never appear
    public static let bannedWords: [String] = [
        "secure",           // Unless proven
        "encrypted",        // Unless proven
        "learns",           // AI anthropomorphism
        "thinks",           // AI anthropomorphism
        "decides",          // AI anthropomorphism
        "understands",      // AI anthropomorphism
        "tracks",           // Privacy concern
        "monitors",         // Privacy concern
        "automatic sending",// Must be user-initiated
        "automatically sends",
        "guaranteed",       // No guarantees
        "100%",            // No absolutes
        "best",            // No superlatives
        "revolutionary",   // No hype
        "amazing",         // No hype
        "smart AI",        // AI anthropomorphism
        "intelligent AI"   // AI anthropomorphism
    ]
    
    /// App Store length limits
    public static let maxReviewNotesLength = 4000
    public static let maxWhatsNewLength = 4000
    public static let maxDescriptionLength = 4000
    
    /// Validates text for banned words
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
    
    /// Validates text length
    public static func validateLength(_ text: String, limit: Int) -> Bool {
        text.count <= limit
    }
    
    /// Full validation
    public static func fullValidation(
        reviewNotes: String,
        whatsNew: String
    ) -> SubmissionCopyValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Validate review notes
        let reviewViolations = validate(reviewNotes)
        errors.append(contentsOf: reviewViolations.map { "Review Notes: \($0)" })
        
        if !validateLength(reviewNotes, limit: maxReviewNotesLength) {
            errors.append("Review Notes exceeds \(maxReviewNotesLength) characters")
        }
        
        // Validate what's new
        let whatsNewViolations = validate(whatsNew)
        errors.append(contentsOf: whatsNewViolations.map { "What's New: \($0)" })
        
        if !validateLength(whatsNew, limit: maxWhatsNewLength) {
            errors.append("What's New exceeds \(maxWhatsNewLength) characters")
        }
        
        // Validate disclosures
        let privacyViolations = validate(privacyDisclosureBlurb)
        errors.append(contentsOf: privacyViolations.map { "Privacy Disclosure: \($0)" })
        
        let monetizationViolations = validate(monetizationDisclosureBlurb)
        errors.append(contentsOf: monetizationViolations.map { "Monetization Disclosure: \($0)" })
        
        return SubmissionCopyValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
}

// MARK: - Validation Result

public struct SubmissionCopyValidationResult {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
}

// MARK: - Copy Pack Export

public struct SubmissionCopyPack: Codable {
    public let version: String
    public let build: String
    public let exportedAt: String
    public let reviewNotes: String
    public let whatsNew: String
    public let privacyDisclosure: String
    public let monetizationDisclosure: String
    public let exportCompliance: String
    
    public init(version: String, build: String, highlights: [String] = SubmissionCopy.defaultHighlights) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        self.version = version
        self.build = build
        self.exportedAt = formatter.string(from: Date())
        self.reviewNotes = SubmissionCopy.reviewNotesTemplate(version: version, build: build)
        self.whatsNew = SubmissionCopy.whatsNewTemplate(version: version, highlights: highlights)
        self.privacyDisclosure = SubmissionCopy.privacyDisclosureBlurb
        self.monetizationDisclosure = SubmissionCopy.monetizationDisclosureBlurb
        self.exportCompliance = SubmissionCopy.exportComplianceStatement
    }
    
    /// Export as plain text
    public func exportText() -> String {
        """
        ============================================================
        OPERATORKIT APP STORE SUBMISSION COPY PACK
        Version: \(version) (\(build))
        Exported: \(exportedAt)
        ============================================================
        
        ============================================================
        REVIEW NOTES
        ============================================================
        
        \(reviewNotes)
        
        ============================================================
        WHAT'S NEW
        ============================================================
        
        \(whatsNew)
        
        ============================================================
        PRIVACY DISCLOSURE
        ============================================================
        
        \(privacyDisclosure)
        
        ============================================================
        MONETIZATION DISCLOSURE
        ============================================================
        
        \(monetizationDisclosure)
        
        ============================================================
        EXPORT COMPLIANCE
        ============================================================
        
        \(exportCompliance)
        
        ============================================================
        END OF COPY PACK
        ============================================================
        """
    }
    
    /// Export filename
    public var exportFilename: String {
        "OperatorKit_CopyPack_\(version)_\(build).txt"
    }
}
