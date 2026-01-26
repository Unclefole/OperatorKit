import Foundation

// ============================================================================
// OUTCOME TEMPLATES (Phase 10O)
//
// Static outcome template library for activation and retention.
// Templates are content-free, generic, and user-approved.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No auto-execution
// ❌ No banned words / anthropomorphic language
// ❌ No security claims
// ✅ Static sample intents
// ✅ User selects context
// ✅ User approves execution
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Outcome Category

public enum OutcomeCategory: String, Codable, CaseIterable {
    case email = "email"
    case tasks = "tasks"
    case calendar = "calendar"
    case summary = "summary"
    case planning = "planning"
    case communication = "communication"
    
    public var displayName: String {
        switch self {
        case .email: return "Email"
        case .tasks: return "Tasks & Reminders"
        case .calendar: return "Calendar"
        case .summary: return "Summarize"
        case .planning: return "Planning"
        case .communication: return "Communication"
        }
    }
    
    public var icon: String {
        switch self {
        case .email: return "envelope"
        case .tasks: return "checklist"
        case .calendar: return "calendar"
        case .summary: return "doc.text"
        case .planning: return "list.bullet.clipboard"
        case .communication: return "bubble.left.and.bubble.right"
        }
    }
}

// MARK: - Outcome Template

public struct OutcomeTemplate: Identifiable, Codable, Equatable {
    public let id: String
    public let templateTitle: String
    public let category: OutcomeCategory
    public let sampleIntent: String
    public let suggestedContextTypeIds: [String]
    public let schemaVersion: Int
    
    public init(
        id: String,
        templateTitle: String,
        category: OutcomeCategory,
        sampleIntent: String,
        suggestedContextTypeIds: [String] = [],
        schemaVersion: Int = OutcomeTemplates.schemaVersion
    ) {
        self.id = id
        self.templateTitle = templateTitle
        self.category = category
        self.sampleIntent = sampleIntent
        self.suggestedContextTypeIds = suggestedContextTypeIds
        self.schemaVersion = schemaVersion
    }
}

// MARK: - Outcome Templates Library

public enum OutcomeTemplates {
    
    /// Schema version
    public static let schemaVersion = 1
    
    /// All available templates
    public static let all: [OutcomeTemplate] = [
        // Email Templates
        OutcomeTemplate(
            id: "outcome-email-followup",
            templateTitle: "Meeting Follow-Up",
            category: .email,
            sampleIntent: "Draft a follow-up email summarizing action items from our meeting",
            suggestedContextTypeIds: ["calendar_event", "note"]
        ),
        OutcomeTemplate(
            id: "outcome-email-intro",
            templateTitle: "Professional Introduction",
            category: .email,
            sampleIntent: "Draft a professional introduction email for a new contact",
            suggestedContextTypeIds: ["contact"]
        ),
        
        // Task Templates
        OutcomeTemplate(
            id: "outcome-task-deadline",
            templateTitle: "Deadline Reminder",
            category: .tasks,
            sampleIntent: "Create a reminder for an upcoming deadline",
            suggestedContextTypeIds: ["calendar_event"]
        ),
        OutcomeTemplate(
            id: "outcome-task-project",
            templateTitle: "Project Tasks",
            category: .tasks,
            sampleIntent: "Create task reminders for project milestones",
            suggestedContextTypeIds: ["note"]
        ),
        
        // Calendar Templates
        OutcomeTemplate(
            id: "outcome-calendar-recurring",
            templateTitle: "Recurring Meeting",
            category: .calendar,
            sampleIntent: "Schedule a recurring team sync meeting",
            suggestedContextTypeIds: []
        ),
        OutcomeTemplate(
            id: "outcome-calendar-block",
            templateTitle: "Focus Time Block",
            category: .calendar,
            sampleIntent: "Block focus time on my calendar for deep work",
            suggestedContextTypeIds: []
        ),
        
        // Summary Templates
        OutcomeTemplate(
            id: "outcome-summary-notes",
            templateTitle: "Meeting Notes Summary",
            category: .summary,
            sampleIntent: "Summarize the key points from my meeting notes",
            suggestedContextTypeIds: ["note"]
        ),
        OutcomeTemplate(
            id: "outcome-summary-weekly",
            templateTitle: "Weekly Review",
            category: .summary,
            sampleIntent: "Summarize my calendar events and tasks for this week",
            suggestedContextTypeIds: ["calendar_event", "reminder"]
        ),
        
        // Planning Templates
        OutcomeTemplate(
            id: "outcome-plan-day",
            templateTitle: "Daily Plan",
            category: .planning,
            sampleIntent: "Help me plan my priorities for today",
            suggestedContextTypeIds: ["calendar_event", "reminder"]
        ),
        OutcomeTemplate(
            id: "outcome-plan-project",
            templateTitle: "Project Outline",
            category: .planning,
            sampleIntent: "Create an outline for a new project",
            suggestedContextTypeIds: ["note"]
        ),
        
        // Communication Templates
        OutcomeTemplate(
            id: "outcome-comm-update",
            templateTitle: "Status Update",
            category: .communication,
            sampleIntent: "Draft a status update email for my team",
            suggestedContextTypeIds: ["note", "reminder"]
        ),
        OutcomeTemplate(
            id: "outcome-comm-request",
            templateTitle: "Polite Request",
            category: .communication,
            sampleIntent: "Draft a polite request email asking for information",
            suggestedContextTypeIds: []
        )
    ]
    
    /// Templates grouped by category
    public static var byCategory: [OutcomeCategory: [OutcomeTemplate]] {
        Dictionary(grouping: all, by: { $0.category })
    }
    
    /// Gets templates for a category
    public static func templates(for category: OutcomeCategory) -> [OutcomeTemplate] {
        all.filter { $0.category == category }
    }
    
    /// Gets a template by ID
    public static func template(byId id: String) -> OutcomeTemplate? {
        all.first { $0.id == id }
    }
    
    // MARK: - Validation
    
    /// Banned words that must not appear in templates
    public static let bannedWords: [String] = [
        "ai thinks", "ai learns", "ai decides", "ai understands",
        "intelligent", "smart assistant",
        "secure", "encrypted", "protected", "safe",
        "monitors", "tracks", "watches", "surveils",
        "automatically sends", "auto-send"
    ]
    
    /// Forbidden keys for export validation
    public static let forbiddenKeys: [String] = [
        "body", "subject", "content", "draft", "prompt",
        "context", "note", "email", "attendees", "title",
        "description", "message", "text", "recipient", "sender",
        "userId", "deviceId"
    ]
    
    /// Validates templates have no banned words
    public static func validateNoBannedWords() -> [String] {
        var violations: [String] = []
        
        for template in all {
            let content = "\(template.templateTitle) \(template.sampleIntent)".lowercased()
            for banned in bannedWords {
                if content.contains(banned) {
                    violations.append("Template \(template.id) contains banned word: '\(banned)'")
                }
            }
        }
        
        return violations
    }
    
    /// Validates templates contain no forbidden keys in JSON
    public static func validateNoForbiddenKeys() throws -> [String] {
        var violations: [String] = []
        
        let encoder = JSONEncoder()
        for template in all {
            let data = try encoder.encode(template)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            
            for key in json.keys {
                if forbiddenKeys.contains(key.lowercased()) {
                    violations.append("Template \(template.id) has forbidden key: \(key)")
                }
            }
        }
        
        return violations
    }
}
