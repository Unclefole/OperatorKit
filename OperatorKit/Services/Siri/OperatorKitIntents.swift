import AppIntents
import Foundation

// ============================================================================
// OPERATORKIT APP INTENTS — AUTOMATION LAYER
//
// ARCHITECTURAL INVARIANT:
// ─────────────────────────
// OperatorKit automates PREPARATION.
// Humans authorize EXECUTION.
//
// Shortcuts/Automations may:
// ✅ Trigger draft preparation
// ✅ Pass parameters
// ✅ Queue for approval
//
// Shortcuts/Automations may NEVER:
// ❌ Execute without approval
// ❌ Send emails
// ❌ Modify calendars
// ❌ Write to disk
//
// Flow: Automation → Draft → ApprovalGate → Execute
//
// ─────────────────────────────────────────────────────────────────────────────
// SIRI PHRASE INVARIANT:
// ─────────────────────────────────────────────────────────────────────────────
// Every App Shortcut utterance MUST contain exactly one \(.applicationName)
// Never hardcode the app name.
// Never ship a phrase without the token.
// Violations cause Siri registration failure.
// ============================================================================

// MARK: - App Shortcuts Provider

/// Provides shortcuts for OperatorKit
/// INVARIANT: Shortcuts prepare drafts - NEVER execute
struct OperatorKitShortcuts: AppShortcutsProvider {

    /// App shortcuts exposed to Siri and Shortcuts app
    static var appShortcuts: [AppShortcut] {
        // OPEN APP INTENT - Foregrounds the app (PRIMARY SIRI ENTRY)
        AppShortcut(
            intent: OpenOperatorKitIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Launch \(.applicationName)",
                "Start \(.applicationName) app"
            ],
            shortTitle: "Open OperatorKit",
            systemImageName: "app.badge"
        )

        // SAFETY TEST INTENT - Primary smoke test
        AppShortcut(
            intent: OperatorTestIntent(),
            phrases: [
                "Ask \(.applicationName) to run a safety test",
                "\(.applicationName) safety test",
                "Test \(.applicationName)"
            ],
            shortTitle: "Safety Test",
            systemImageName: "checkmark.shield"
        )

        // GENERAL INTENT - Opens app, Shortcuts can pass intentText parameter
        // When invoked via Shortcuts app, user can provide text to prefill
        AppShortcut(
            intent: HandleIntentIntent(),
            phrases: [
                "Ask \(.applicationName) for help",
                "Use \(.applicationName)",
                "Prepare request with \(.applicationName)"
            ],
            shortTitle: "Ask OperatorKit",
            systemImageName: "sparkles"
        )

        // MEETING INTENT - Automation-ready
        // INVARIANT: Every phrase MUST contain exactly one \(.applicationName)
        AppShortcut(
            intent: HandleMeetingIntent(),
            phrases: [
                "Summarize meeting with \(.applicationName)",
                "\(.applicationName) meeting summary",
                "Draft follow-up after my meetings with \(.applicationName)",
                "Summarize meetings automatically with \(.applicationName)"
            ],
            shortTitle: "Meeting Follow-up",
            systemImageName: "person.3"
        )

        // EMAIL INTENT - Automation-ready
        // INVARIANT: Every phrase MUST contain exactly one \(.applicationName)
        AppShortcut(
            intent: HandleEmailIntent(),
            phrases: [
                "Draft email with \(.applicationName)",
                "\(.applicationName) write an email",
                "Prepare client emails with \(.applicationName)",
                "Draft follow-up email with \(.applicationName)"
            ],
            shortTitle: "Draft Email",
            systemImageName: "envelope"
        )
    }
}

// MARK: - Urgency Level (for Automation)

/// Urgency level for automated requests
enum IntentUrgency: String, AppEnum {
    case low = "low"
    case normal = "normal"
    case high = "high"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Urgency")

    static var caseDisplayRepresentations: [IntentUrgency: DisplayRepresentation] = [
        .low: "Low",
        .normal: "Normal",
        .high: "High"
    ]
}

// MARK: - Summary Style (for Meeting Automation)

/// Summary style for meeting intents
enum SummaryStyle: String, AppEnum {
    case brief = "brief"
    case detailed = "detailed"
    case actionItemsOnly = "action_items_only"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Summary Style")

    static var caseDisplayRepresentations: [SummaryStyle: DisplayRepresentation] = [
        .brief: "Brief",
        .detailed: "Detailed",
        .actionItemsOnly: "Action Items Only"
    ]
}

// MARK: - Handle Intent Intent (Automation-Ready)

/// Routes user intent to OperatorKit - Automation compatible
/// INVARIANT: ONLY routes - never resolves, plans, or generates
/// INVARIANT: No data access, no draft generation, no execution
struct HandleIntentIntent: AppIntent {

    static var title: LocalizedStringResource = "Ask OperatorKit"
    static var description = IntentDescription("Prepare a request for OperatorKit review")

    /// OPENS the app and prefills the request
    /// User MUST review and approve before any action
    static var openAppWhenRun: Bool = true

    // INVARIANT: suggestedInvocationPhrase removed - use AppShortcut phrases instead
    // AppShortcut phrases in OperatorKitShortcuts contain the required \(.applicationName) token

    /// Spotlight searchable
    static var isDiscoverable: Bool = true

    // MARK: - Parameters (Automation-Exposed)

    @Parameter(title: "Request", description: "What would you like OperatorKit to help with?", default: "")
    var intentText: String

    @Parameter(title: "Urgency", default: .normal)
    var urgency: IntentUrgency

    @Parameter(title: "Context", description: "Additional context for the request")
    var additionalContext: String?

    // MARK: - Perform

    /// Perform the intent - ROUTING ONLY
    /// INVARIANT: No logic execution, no data access
    /// INVARIANT: Automation prepares, never executes
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // SAFETY CHECK: Validate input before routing
        let trimmed = intentText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .result(
                dialog: IntentDialog("OperatorKit needs a request to prepare. Please provide what you'd like help with.")
            )
        }

        // Build request text with context
        var fullRequest = trimmed
        if let context = additionalContext, !context.isEmpty {
            fullRequest += " (Context: \(context))"
        }

        // Route to app via bridge - ONLY sets state for UI
        await SiriRoutingBridge.shared.routeIntent(
            text: fullRequest,
            source: .shortcut
        )

        // Return confirmation - app opens with prefilled request
        return .result(
            dialog: IntentDialog("Opening OperatorKit with your request. Review and approve to continue.")
        )
    }
}

// MARK: - Handle Meeting Intent (Automation-Ready)

/// Routes meeting-related requests to OperatorKit - Automation compatible
/// INVARIANT: ONLY prefills and routes - never accesses calendar
struct HandleMeetingIntent: AppIntent {

    static var title: LocalizedStringResource = "Meeting Follow-up"
    static var description = IntentDescription("Prepare a meeting summary or follow-up")

    /// OPENS the app with meeting request prefilled
    static var openAppWhenRun: Bool = true

    // INVARIANT: suggestedInvocationPhrase removed - use AppShortcut phrases instead
    // AppShortcut phrases in OperatorKitShortcuts contain the required \(.applicationName) token

    /// Spotlight searchable
    static var isDiscoverable: Bool = true

    // MARK: - Parameters (Automation-Exposed)

    @Parameter(title: "Meeting Topic", description: "Topic or name of the meeting")
    var meetingTopic: String?

    @Parameter(title: "Summary Style", default: .detailed)
    var summaryStyle: SummaryStyle

    @Parameter(title: "Include Action Items", default: true)
    var includeActionItems: Bool

    @Parameter(title: "Meeting Reference", description: "Calendar event ID or meeting link")
    var meetingReference: String?

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // INVARIANT: Never access calendar data directly
        // INVARIANT: Never read meeting details from system
        // Only prefill text for user to review

        var prefillText: String

        // Build request based on parameters
        switch summaryStyle {
        case .brief:
            prefillText = "Create a brief summary"
        case .detailed:
            prefillText = "Create a detailed summary"
        case .actionItemsOnly:
            prefillText = "Extract action items"
        }

        if let topic = meetingTopic, !topic.isEmpty {
            prefillText += " for meeting about \(topic)"
        } else {
            prefillText += " for my recent meeting"
        }

        if includeActionItems && summaryStyle != .actionItemsOnly {
            prefillText += " and extract action items"
        }

        if let reference = meetingReference, !reference.isEmpty {
            prefillText += " (ref: \(reference))"
        }

        await SiriRoutingBridge.shared.routeIntent(
            text: prefillText,
            source: .siriMeeting
        )

        return .result(
            dialog: IntentDialog("Opening OperatorKit with your meeting request. Review and approve to continue.")
        )
    }
}

// MARK: - Handle Email Intent (Automation-Ready)

/// Routes email-related requests to OperatorKit - Automation compatible
/// INVARIANT: ONLY prefills and routes - never accesses mail
struct HandleEmailIntent: AppIntent {

    static var title: LocalizedStringResource = "Draft Email"
    static var description = IntentDescription("Prepare an email draft for review")

    /// OPENS the app with email request prefilled
    static var openAppWhenRun: Bool = true

    // INVARIANT: suggestedInvocationPhrase removed - use AppShortcut phrases instead
    // AppShortcut phrases in OperatorKitShortcuts contain the required \(.applicationName) token

    /// Spotlight searchable
    static var isDiscoverable: Bool = true

    // MARK: - Parameters (Automation-Exposed)

    @Parameter(title: "Recipient", description: "Who to send the email to")
    var recipient: String?

    @Parameter(title: "Subject", description: "Email subject line")
    var subject: String?

    @Parameter(title: "Email Topic", description: "What the email should be about")
    var emailTopic: String?

    @Parameter(title: "Context", description: "Meeting or conversation to reference")
    var emailContext: String?

    @Parameter(title: "Urgency", default: .normal)
    var urgency: IntentUrgency

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // INVARIANT: Never access mail data directly
        // INVARIANT: Never read email threads from system
        // Only prefill text for user to review

        var prefillText = "Draft"

        // Add urgency if high
        if urgency == .high {
            prefillText += " urgent"
        }

        prefillText += " email"

        // Add recipient
        if let to = recipient, !to.isEmpty {
            prefillText += " to \(to)"
        }

        // Add subject
        if let subj = subject, !subj.isEmpty {
            prefillText += " about \"\(subj)\""
        } else if let topic = emailTopic, !topic.isEmpty {
            prefillText += " about \(topic)"
        } else {
            prefillText += " (follow-up)"
        }

        // Add context reference
        if let context = emailContext, !context.isEmpty {
            prefillText += " referencing \(context)"
        }

        await SiriRoutingBridge.shared.routeIntent(
            text: prefillText,
            source: .siriEmail
        )

        return .result(
            dialog: IntentDialog("Opening OperatorKit with your email request. Review and approve to continue.")
        )
    }
}

// MARK: - Open OperatorKit Intent (Foregrounds App)

/// Opens the OperatorKit app via Siri
/// INVARIANT: Opens app, no side effects, no execution
struct OpenOperatorKitIntent: AppIntent {

    static var title: LocalizedStringResource = "Open OperatorKit"
    static var description = IntentDescription("Open OperatorKit to start a new request")

    /// OPENS the app when run via Siri
    static var openAppWhenRun: Bool = true

    /// Spotlight searchable
    static var isDiscoverable: Bool = true

    /// Perform the intent - OPENS APP ONLY
    /// INVARIANT: Zero side effects beyond opening the app
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        return .result(
            dialog: IntentDialog("OperatorKit is open. All actions require your approval.")
        )
    }
}

// MARK: - Operator Test Intent (Siri Smoke Test)

/// Deterministic safety test intent for Siri validation
/// INVARIANT: No network, no writes, no execution - ONLY returns confirmation
struct OperatorTestIntent: AppIntent {

    static var title: LocalizedStringResource = "Run Safety Test"
    static var description = IntentDescription("Verify OperatorKit is ready and safe")

    /// Does NOT open app - returns spoken confirmation only
    static var openAppWhenRun: Bool = false

    // INVARIANT: suggestedInvocationPhrase removed - use AppShortcut phrases instead
    // AppShortcut phrases in OperatorKitShortcuts contain the required \(.applicationName) token

    /// Spotlight searchable
    static var isDiscoverable: Bool = true

    /// Perform the intent - CONFIRMATION ONLY
    /// INVARIANT: Zero side effects
    /// INVARIANT: No network calls
    /// INVARIANT: No disk writes
    /// INVARIANT: No state mutation
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // SAFETY: This intent does NOTHING except return a confirmation
        // No network, no writes, no reads, no state changes

        return .result(
            dialog: IntentDialog("OperatorKit is ready. All actions require your approval.")
        )
    }
}

// MARK: - Siri Source Type

/// Identifies the source of Siri routing for UI display
enum SiriRouteSource: String, Codable {
    case siriGeneral = "Siri"
    case siriMeeting = "Siri (Meeting)"
    case siriEmail = "Siri (Email)"
    case shortcut = "Shortcut"
    case widget = "Widget"
    case automation = "Automation"

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .siriGeneral: return "mic.fill"
        case .siriMeeting: return "person.3.fill"
        case .siriEmail: return "envelope.fill"
        case .shortcut: return "square.stack.3d.up.fill"
        case .widget: return "rectangle.3.group.fill"
        case .automation: return "gearshape.2.fill"
        }
    }
}
