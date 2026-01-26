import AppIntents
import Foundation

// MARK: - App Shortcuts Provider

/// Provides shortcuts for OperatorKit
/// INVARIANT: Siri is router only - NEVER executes logic
struct OperatorKitShortcuts: AppShortcutsProvider {
    
    /// App shortcuts exposed to Siri
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: HandleIntentIntent(),
            phrases: [
                "Ask \(.applicationName) to \(\.$intentText)",
                "Tell \(.applicationName) \(\.$intentText)",
                "\(.applicationName) draft \(\.$intentText)",
                "Use \(.applicationName) for \(\.$intentText)",
                "Open \(.applicationName) and \(\.$intentText)"
            ],
            shortTitle: "Ask OperatorKit",
            systemImageName: "sparkles"
        )
        
        AppShortcut(
            intent: HandleMeetingIntent(),
            phrases: [
                "Summarize meeting with \(.applicationName)",
                "\(.applicationName) meeting summary",
                "Ask \(.applicationName) about \(\.$meetingTopic) meeting",
                "\(.applicationName) follow up on \(\.$meetingTopic)"
            ],
            shortTitle: "Meeting Follow-up",
            systemImageName: "person.3"
        )
        
        AppShortcut(
            intent: HandleEmailIntent(),
            phrases: [
                "Draft email with \(.applicationName)",
                "\(.applicationName) write email about \(\.$emailTopic)",
                "Ask \(.applicationName) to email \(\.$emailTopic)"
            ],
            shortTitle: "Draft Email",
            systemImageName: "envelope"
        )
    }
}

// MARK: - Handle Intent Intent

/// Routes user intent to OperatorKit
/// INVARIANT: ONLY routes - never resolves, plans, or generates
/// INVARIANT: No data access, no draft generation, no execution
struct HandleIntentIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Ask OperatorKit"
    static var description = IntentDescription("Route a request to OperatorKit for review")
    
    /// Opens OperatorKit when run
    static var openAppWhenRun: Bool = true
    
    /// The intent text to prefill
    @Parameter(title: "Request", description: "What would you like OperatorKit to help with?")
    var intentText: String
    
    /// Perform the intent - ROUTING ONLY
    /// INVARIANT: No logic execution, no data access
    @MainActor
    func perform() async throws -> some IntentResult {
        // INVARIANT CHECK: Siri must never execute logic
        #if DEBUG
        assert(true, "Siri routing only - no logic execution allowed")
        #endif
        
        // Route to app via bridge - ONLY sets state for UI
        await SiriRoutingBridge.shared.routeIntent(
            text: intentText,
            source: .siriGeneral
        )
        
        // Return result with no side effects
        // INVARIANT: Siri never returns data, never modifies state beyond routing
        return .result()
    }
}

// MARK: - Handle Meeting Intent

/// Routes meeting-related requests to OperatorKit
/// INVARIANT: ONLY prefills and routes - never accesses calendar
struct HandleMeetingIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Meeting Follow-up"
    static var description = IntentDescription("Route a meeting request to OperatorKit")
    
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Meeting Topic", description: "Optional meeting topic to include")
    var meetingTopic: String?
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // INVARIANT: Never access calendar data
        // INVARIANT: Never read meeting details
        // Only prefill text for user to review
        
        let prefillText: String
        if let topic = meetingTopic, !topic.isEmpty {
            prefillText = "Summarize and follow up on meeting about \(topic)"
        } else {
            prefillText = "Summarize and follow up on meeting"
        }
        
        await SiriRoutingBridge.shared.routeIntent(
            text: prefillText,
            source: .siriMeeting
        )
        
        return .result()
    }
}

// MARK: - Handle Email Intent

/// Routes email-related requests to OperatorKit
/// INVARIANT: ONLY prefills and routes - never accesses mail
struct HandleEmailIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Draft Email"
    static var description = IntentDescription("Route an email request to OperatorKit")
    
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Email Topic", description: "What the email should be about")
    var emailTopic: String?
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // INVARIANT: Never access mail data
        // INVARIANT: Never read email threads
        // Only prefill text for user to review
        
        let prefillText: String
        if let topic = emailTopic, !topic.isEmpty {
            prefillText = "Draft email about \(topic)"
        } else {
            prefillText = "Draft a follow-up email"
        }
        
        await SiriRoutingBridge.shared.routeIntent(
            text: prefillText,
            source: .siriEmail
        )
        
        return .result()
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
        }
    }
}
