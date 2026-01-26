import Foundation

// ============================================================================
// DISCLAIMERS REGISTRY (Phase 9D)
//
// Predefined, App Store-safe disclaimers that appear in:
// - External Review Readiness view
// - Evidence packet exports
//
// CONSTRAINTS:
// ❌ No new claims beyond CLAIM_REGISTRY.md
// ❌ No security language
// ✅ Concise, accurate, reviewer-friendly
// ✅ App Store-safe language
//
// See: docs/CLAIM_REGISTRY.md
// ============================================================================

/// Registry of predefined review disclaimers
public enum DisclaimersRegistry {
    
    // MARK: - Export Disclaimers
    
    /// Disclaimers included in evidence packet exports
    public static let exportDisclaimers: [String] = [
        "This export contains metadata only. It does not include draft text, calendar titles, email content, or any user-generated content.",
        "Integrity indicators are tamper-evident signals for consistency verification, not security guarantees.",
        "All exports are user-initiated and manual. No automatic or background exports occur.",
        "Quality metrics are computed locally on-device. No data is transmitted externally.",
        "This evidence packet is for review and audit purposes only."
    ]
    
    // MARK: - UI Disclaimers
    
    /// Disclaimers shown in External Review Readiness view
    public static let uiDisclaimers: [String] = [
        "All processing happens on your device.",
        "Data is not transmitted externally.",
        "Actions require your explicit approval.",
        "Exports contain metadata only, never personal content."
    ]
    
    // MARK: - Data Access Disclaimers
    
    /// Disclaimers about data access patterns
    public static let dataAccessDisclaimers: [String] = [
        "Calendar: Read only when you select events in Context Picker",
        "Reminders: Created only after two-step confirmation",
        "Email: Drafts opened in Mail app; you control sending",
        "Siri: Routes to app only; cannot execute actions"
    ]
    
    // MARK: - Guarantee Disclaimers
    
    /// Short-form immutable guarantees
    public static let guaranteeDisclaimers: [String] = [
        "No autonomous actions",
        "No network transmission",
        "No background data access",
        "Draft-first execution",
        "Two-key confirmation for writes",
        "Siri routes only, never executes",
        "User-selected context only"
    ]
    
    // MARK: - Integrity Disclaimers
    
    /// Disclaimers about integrity features
    public static let integrityDisclaimers: [String] = [
        "Integrity checks verify record consistency, not security.",
        "Hash values are computed locally using SHA-256.",
        "Integrity status is informational and advisory only.",
        "No blocking or enforcement based on integrity checks."
    ]
    
    // MARK: - Full Disclaimer Set
    
    /// All disclaimers for comprehensive export
    public static var allDisclaimers: [String] {
        exportDisclaimers + integrityDisclaimers.prefix(2)
    }
    
    // MARK: - Formatted Output
    
    /// Returns disclaimers formatted for UI display
    public static func formattedForUI() -> String {
        uiDisclaimers.map { "• \($0)" }.joined(separator: "\n")
    }
    
    /// Returns guarantees formatted for UI display
    public static func guaranteesForUI() -> String {
        guaranteeDisclaimers.enumerated().map { index, text in
            "\(index + 1). \(text)"
        }.joined(separator: "\n")
    }
}

// MARK: - Reviewer FAQ

/// Predefined FAQ items for reviewers
public enum ReviewerFAQ {
    
    /// All FAQ items for export
    public static let items: [ReviewerFAQItemExport] = [
        ReviewerFAQItemExport(
            question: "Does the app send email automatically?",
            answer: "No. The app opens the system Mail composer with pre-filled content. The user must manually tap Send in the Mail app."
        ),
        ReviewerFAQItemExport(
            question: "Does the app read calendar events in the background?",
            answer: "No. Calendar access only occurs when the user opens the Context Picker and explicitly selects events. No background modes are enabled."
        ),
        ReviewerFAQItemExport(
            question: "Does the app upload data to servers?",
            answer: "No. All processing happens on-device. The app does not import networking frameworks and does not make HTTP requests."
        ),
        ReviewerFAQItemExport(
            question: "Does the app auto-create reminders or events?",
            answer: "No. Creating or modifying reminders and calendar events requires user approval plus a second confirmation step."
        ),
        ReviewerFAQItemExport(
            question: "Is Siri used to execute actions?",
            answer: "No. Siri only opens the app and pre-fills request text. Siri cannot bypass approvals, access data, or execute any actions."
        ),
        ReviewerFAQItemExport(
            question: "What happens if the on-device model is unavailable?",
            answer: "The app falls back to a deterministic template system that runs entirely on-device. All safety gates remain in effect."
        ),
        ReviewerFAQItemExport(
            question: "Does the app work offline?",
            answer: "Yes. The app is fully functional offline because all processing is on-device."
        ),
        ReviewerFAQItemExport(
            question: "What data does the evidence export contain?",
            answer: "The export contains metadata only: version numbers, check results, hashes, and status indicators. It never contains user content."
        )
    ]
}

// MARK: - Reviewer Test Plan

/// Predefined test plan for reviewers
public enum ReviewerTestPlan {
    
    /// 2-minute test plan for reviewers
    public static let twoMinutePlan = ReviewerTestPlanExport(
        title: "2-Minute Reviewer Test Plan",
        estimatedMinutes: 2,
        steps: [
            ReviewerTestStepExport(
                stepNumber: 1,
                title: "Siri Route",
                action: "Say 'Hey Siri, ask OperatorKit to draft a follow-up email'",
                expectedResult: "App opens with text pre-filled and banner saying 'Siri Started This Request'. No action taken until user taps Continue.",
                duration: "30 seconds"
            ),
            ReviewerTestStepExport(
                stepNumber: 2,
                title: "Calendar Read",
                action: "Open app → Enter 'Summarize my meetings' → Continue → Allow calendar permission → Select 1-2 events → Continue",
                expectedResult: "Only selected events appear in plan/draft. Events from ±7 days shown.",
                duration: "30 seconds"
            ),
            ReviewerTestStepExport(
                stepNumber: 3,
                title: "Reminder Write",
                action: "Complete flow to Approval with reminder → Enable 'Create Reminder' → Approve → Confirm in modal",
                expectedResult: "Two distinct confirmation steps required. Reminder appears in Reminders app.",
                duration: "30 seconds"
            ),
            ReviewerTestStepExport(
                stepNumber: 4,
                title: "Email Draft",
                action: "Complete flow → Tap 'Open Email Composer'",
                expectedResult: "Mail composer opens with pre-filled content. User must manually tap Send.",
                duration: "20 seconds"
            ),
            ReviewerTestStepExport(
                stepNumber: 5,
                title: "Memory Audit",
                action: "Go to Memory tab → Select completed operation",
                expectedResult: "Trust Summary shows approval status, model used, timestamps.",
                duration: "10 seconds"
            )
        ]
    )
    
    /// Formatted test plan for UI display
    public static func formattedForUI() -> String {
        var lines: [String] = []
        lines.append(twoMinutePlan.title)
        lines.append("Estimated time: \(twoMinutePlan.estimatedMinutes) minutes")
        lines.append("")
        
        for step in twoMinutePlan.steps {
            lines.append("Step \(step.stepNumber): \(step.title) (\(step.duration))")
            lines.append("  Action: \(step.action)")
            lines.append("  Expected: \(step.expectedResult)")
            lines.append("")
        }
        
        return lines.joined(separator: "\n")
    }
}
