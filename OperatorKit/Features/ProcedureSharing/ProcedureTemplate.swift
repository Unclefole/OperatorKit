import Foundation

// ============================================================================
// PROCEDURE TEMPLATE (Phase 13B)
//
// A named workflow template containing logic only, never data.
//
// A Procedure is:
// - A named workflow template
// - Intent structure + prompt scaffolding + policy constraints + output type
//
// A Procedure contains NO:
// - User text, context, memory, drafts, outputs, identifiers
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No personal data
// ❌ No identifiers
// ❌ No free-text user fields
// ✅ Logic-only
// ✅ Deterministic serialization
// ✅ Inspectable
// ============================================================================

// MARK: - Procedure Template

public struct ProcedureTemplate: Codable, Identifiable, Equatable {
    
    // MARK: - Fields (Strictly Limited)
    
    /// Unique identifier (deterministic UUID)
    public let id: UUID
    
    /// Display name (validated against forbidden patterns)
    public let name: String
    
    /// Category for organization
    public let category: ProcedureCategory
    
    /// Intent skeleton (structure only, no user content)
    public let intentSkeleton: IntentSkeleton
    
    /// Policy constraints
    public let constraints: ProcedureConstraints
    
    /// Output type identifier
    public let outputType: ProcedureOutputType
    
    /// Creation date (day-rounded only)
    public let createdAtDayRounded: String
    
    /// Schema version
    public let schemaVersion: Int
    
    // MARK: - Schema
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Init
    
    public init(
        id: UUID = UUID(),
        name: String,
        category: ProcedureCategory,
        intentSkeleton: IntentSkeleton,
        constraints: ProcedureConstraints,
        outputType: ProcedureOutputType,
        createdAtDayRounded: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.intentSkeleton = intentSkeleton
        self.constraints = constraints
        self.outputType = outputType
        self.createdAtDayRounded = createdAtDayRounded ?? Self.currentDayRounded()
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    // MARK: - Day Rounding
    
    private static func currentDayRounded() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
    
    // MARK: - Deterministic Hash
    
    public var deterministicHash: String {
        let components = [
            "name:\(name)",
            "category:\(category.rawValue)",
            "intentType:\(intentSkeleton.intentType)",
            "outputType:\(outputType.rawValue)",
            "schemaVersion:\(schemaVersion)"
        ]
        return components.joined(separator: "|")
    }
}

// MARK: - Procedure Category

public enum ProcedureCategory: String, Codable, CaseIterable {
    case email = "email"
    case calendar = "calendar"
    case reminder = "reminder"
    case summary = "summary"
    case general = "general"
    
    public var displayName: String {
        switch self {
        case .email: return "Email"
        case .calendar: return "Calendar"
        case .reminder: return "Reminder"
        case .summary: return "Summary"
        case .general: return "General"
        }
    }
    
    public var icon: String {
        switch self {
        case .email: return "envelope"
        case .calendar: return "calendar"
        case .reminder: return "checklist"
        case .summary: return "doc.text"
        case .general: return "gearshape"
        }
    }
}

// MARK: - Intent Skeleton

public struct IntentSkeleton: Codable, Equatable {
    
    /// Intent type identifier (enum-like, no user content)
    public let intentType: String
    
    /// Required context types (enum identifiers only)
    public let requiredContextTypes: [String]
    
    /// Prompt scaffold (template with placeholders, no user text)
    public let promptScaffold: String
    
    // MARK: - Forbidden Content Assertion
    
    /// Runtime assertion that skeleton contains no user data
    public func assertNoUserContent() {
        assert(!promptScaffold.contains("@"), "Prompt scaffold must not contain user mentions")
        assert(!promptScaffold.contains("Dear "), "Prompt scaffold must not contain salutations")
        assert(!promptScaffold.contains("Hi "), "Prompt scaffold must not contain salutations")
        assert(promptScaffold.allSatisfy { !$0.isNumber || promptScaffold.contains("{") }, 
               "Prompt scaffold should use placeholders, not literals")
    }
}

// MARK: - Procedure Constraints

public struct ProcedureConstraints: Codable, Equatable {
    
    /// Maximum output length (optional)
    public let maxOutputLength: Int?
    
    /// Required approval level
    public let requiresApproval: Bool
    
    /// Allowed days of week (nil = any)
    public let allowedDaysOfWeek: [Int]?
    
    /// Maximum executions per day (optional)
    public let maxExecutionsPerDay: Int?
    
    public init(
        maxOutputLength: Int? = nil,
        requiresApproval: Bool = true,
        allowedDaysOfWeek: [Int]? = nil,
        maxExecutionsPerDay: Int? = nil
    ) {
        self.maxOutputLength = maxOutputLength
        self.requiresApproval = requiresApproval
        self.allowedDaysOfWeek = allowedDaysOfWeek
        self.maxExecutionsPerDay = maxExecutionsPerDay
    }
    
    public static let `default` = ProcedureConstraints(requiresApproval: true)
}

// MARK: - Procedure Output Type

public enum ProcedureOutputType: String, Codable, CaseIterable {
    case emailDraft = "email_draft"
    case calendarEvent = "calendar_event"
    case reminder = "reminder"
    case textSummary = "text_summary"
    case taskList = "task_list"
    
    public var displayName: String {
        switch self {
        case .emailDraft: return "Email Draft"
        case .calendarEvent: return "Calendar Event"
        case .reminder: return "Reminder"
        case .textSummary: return "Text Summary"
        case .taskList: return "Task List"
        }
    }
}

// MARK: - Validation

public enum ProcedureTemplateValidator {
    
    /// Forbidden keys that must never appear in procedure data
    public static let forbiddenKeys: Set<String> = [
        "body", "subject", "content", "draft", "prompt", "context",
        "email", "recipient", "attendees", "title", "description",
        "message", "text", "name", "address", "company", "domain",
        "phone", "note", "notes", "memory", "output", "result",
        "userText", "userInput", "userData", "personalData"
    ]
    
    /// Forbidden patterns in string values
    public static let forbiddenPatterns: [String] = [
        "@gmail.com", "@yahoo.com", "@outlook.com", "@icloud.com",
        "Dear ", "Hi ", "Hello ", "Meeting with",
        "555-", "(555)", "+1",
        "Street", "Avenue", "Road"
    ]
    
    /// Validate a procedure template
    public static func validate(_ procedure: ProcedureTemplate) -> ValidationResult {
        var errors: [String] = []
        
        // Validate name
        if procedure.name.isEmpty {
            errors.append("Procedure name cannot be empty")
        }
        
        if procedure.name.count > 100 {
            errors.append("Procedure name exceeds maximum length")
        }
        
        // Check for forbidden patterns in name
        for pattern in forbiddenPatterns {
            if procedure.name.lowercased().contains(pattern.lowercased()) {
                errors.append("Procedure name contains forbidden pattern: \(pattern)")
            }
        }
        
        // Validate prompt scaffold
        for pattern in forbiddenPatterns {
            if procedure.intentSkeleton.promptScaffold.lowercased().contains(pattern.lowercased()) {
                errors.append("Prompt scaffold contains forbidden pattern: \(pattern)")
            }
        }
        
        // Validate context types are enum-like
        for contextType in procedure.intentSkeleton.requiredContextTypes {
            if contextType.contains(" ") || contextType.contains("@") {
                errors.append("Context type '\(contextType)' appears to contain user data")
            }
        }
        
        // Validate serialization contains no forbidden keys
        if let jsonData = try? JSONEncoder().encode(procedure),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let lowercased = jsonString.lowercased()
            for key in forbiddenKeys {
                // Check for key as JSON field name
                if lowercased.contains("\"\(key)\"") {
                    errors.append("Serialization contains forbidden key: \(key)")
                }
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    public struct ValidationResult {
        public let isValid: Bool
        public let errors: [String]
    }
}
