import Foundation

// ============================================================================
// ACTIVATION PLAYBOOK (Phase 10N)
//
// Static "first 3 wins" steps to help new subscribers get value.
// Content-free, no user identifiers.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No user identifiers
// ❌ No networking
// ❌ No auto-execution
// ✅ Static sample intents
// ✅ User selects context
// ✅ Always skippable
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Activation Step

public struct ActivationStep: Identifiable, Codable {
    public let id: String
    public let stepNumber: Int
    public let title: String
    public let stepDescription: String
    public let sampleIntent: String
    public let icon: String
    
    public init(
        id: String,
        stepNumber: Int,
        title: String,
        stepDescription: String,
        sampleIntent: String,
        icon: String
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.title = title
        self.stepDescription = stepDescription
        self.sampleIntent = sampleIntent
        self.icon = icon
    }
}

// MARK: - Activation Playbook

public enum ActivationPlaybook {
    
    /// Schema version
    public static let schemaVersion = 1
    
    /// The "First 3 Wins" steps
    public static let steps: [ActivationStep] = [
        ActivationStep(
            id: "activation-step-1",
            stepNumber: 1,
            title: "Draft a Quick Email",
            stepDescription: "Try drafting an email. OperatorKit creates the draft, you review and send from your Mail app.",
            sampleIntent: "Draft a friendly follow-up email about our meeting",
            icon: "envelope"
        ),
        ActivationStep(
            id: "activation-step-2",
            stepNumber: 2,
            title: "Create a Reminder",
            stepDescription: "Set a reminder for yourself. You'll see it in your Reminders app after confirming.",
            sampleIntent: "Remind me to review the project proposal tomorrow at 10am",
            icon: "bell"
        ),
        ActivationStep(
            id: "activation-step-3",
            stepNumber: 3,
            title: "Schedule an Event",
            stepDescription: "Create a calendar event. You'll review all details before it's added to your calendar.",
            sampleIntent: "Schedule a team sync meeting for next Monday at 2pm",
            icon: "calendar"
        )
    ]
    
    /// Gets a step by ID
    public static func step(byId id: String) -> ActivationStep? {
        steps.first { $0.id == id }
    }
}

// MARK: - Activation State Store

@MainActor
public final class ActivationStateStore: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = ActivationStateStore()
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let playbackShownKey = "com.operatorkit.activation.playbook_shown"
    private let completedStepsKey = "com.operatorkit.activation.completed_steps"
    private let schemaVersionKey = "com.operatorkit.activation.schema_version"
    
    // MARK: - State
    
    @Published public private(set) var hasShownPlaybook: Bool
    @Published public private(set) var completedStepIds: Set<String>
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasShownPlaybook = defaults.bool(forKey: playbackShownKey)
        
        if let data = defaults.data(forKey: completedStepsKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.completedStepIds = ids
        } else {
            self.completedStepIds = []
        }
    }
    
    // MARK: - Public API
    
    /// Marks playbook as shown
    public func markPlaybookShown() {
        hasShownPlaybook = true
        defaults.set(true, forKey: playbackShownKey)
        defaults.set(ActivationPlaybook.schemaVersion, forKey: schemaVersionKey)
    }
    
    /// Marks a step as completed
    public func markStepCompleted(_ stepId: String) {
        completedStepIds.insert(stepId)
        saveCompletedSteps()
    }
    
    /// Checks if step is completed
    public func isStepCompleted(_ stepId: String) -> Bool {
        completedStepIds.contains(stepId)
    }
    
    /// Checks if playbook is fully completed
    public var isPlaybookCompleted: Bool {
        let allStepIds = Set(ActivationPlaybook.steps.map { $0.id })
        return allStepIds.isSubset(of: completedStepIds)
    }
    
    /// Progress (0.0 - 1.0)
    public var progress: Double {
        let total = ActivationPlaybook.steps.count
        guard total > 0 else { return 0 }
        let completed = ActivationPlaybook.steps.filter { completedStepIds.contains($0.id) }.count
        return Double(completed) / Double(total)
    }
    
    /// Resets playbook state
    public func reset() {
        hasShownPlaybook = false
        completedStepIds = []
        defaults.removeObject(forKey: playbackShownKey)
        defaults.removeObject(forKey: completedStepsKey)
    }
    
    // MARK: - Private
    
    private func saveCompletedSteps() {
        if let data = try? JSONEncoder().encode(completedStepIds) {
            defaults.set(data, forKey: completedStepsKey)
        }
    }
}

// MARK: - Forbidden Keys Validation

extension ActivationPlaybook {
    
    /// Forbidden keys that must never appear
    public static let forbiddenKeys: [String] = [
        "body", "subject", "content", "draft", "prompt",
        "context", "note", "email", "attendees", "title",
        "description", "message", "text", "recipient", "sender",
        "userId", "deviceId"
    ]
    
    /// Validates steps contain no forbidden keys
    public static func validateNoForbiddenKeys() throws -> [String] {
        var violations: [String] = []
        
        let encoder = JSONEncoder()
        for step in steps {
            let data = try encoder.encode(step)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            
            for key in json.keys {
                if forbiddenKeys.contains(key.lowercased()) {
                    violations.append("Step \(step.id) has forbidden key: \(key)")
                }
            }
        }
        
        return violations
    }
}
