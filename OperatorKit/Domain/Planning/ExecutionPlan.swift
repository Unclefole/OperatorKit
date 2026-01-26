import Foundation

/// A complete execution plan derived from intent + context
/// INVARIANT: Plan must explicitly declare all side effects before approval
struct ExecutionPlan: Identifiable, Equatable {
    let id: UUID
    let intent: IntentRequest
    let context: ContextPacket
    let steps: [PlanStep]
    let declaredSideEffects: [SideEffect]
    let requiredPermissions: [PlanStep.PermissionType]
    let overallConfidence: Double
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        intent: IntentRequest,
        context: ContextPacket,
        steps: [PlanStep],
        declaredSideEffects: [SideEffect]? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.intent = intent
        self.context = context
        self.steps = steps
        self.requiredPermissions = Array(Set(steps.compactMap { $0.requiresPermission }))
        self.overallConfidence = steps.isEmpty ? 0 : steps.map { $0.estimatedConfidence }.reduce(0, +) / Double(steps.count)
        self.createdAt = createdAt
        
        // Auto-generate side effects if not provided
        if let effects = declaredSideEffects {
            self.declaredSideEffects = effects
        } else {
            self.declaredSideEffects = Self.deriveSideEffects(from: steps, intent: intent)
        }
    }
    
    var isHighConfidence: Bool {
        overallConfidence >= 0.8
    }
    
    var requiresAdditionalPermissions: Bool {
        !requiredPermissions.isEmpty
    }
    
    /// Returns side effects that require permissions
    var sideEffectsRequiringPermission: [SideEffect] {
        declaredSideEffects.filter { $0.requiresPermission != nil }
    }
    
    /// Returns permissions required by side effects
    var permissionsRequiredBySideEffects: [SideEffect.PermissionType] {
        Array(Set(declaredSideEffects.compactMap { $0.requiresPermission }))
    }
    
    static func == (lhs: ExecutionPlan, rhs: ExecutionPlan) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Side Effect Derivation
    
    private static func deriveSideEffects(from steps: [PlanStep], intent: IntentRequest) -> [SideEffect] {
        var effects: [SideEffect] = []
        
        // Derive from intent type
        switch intent.intentType {
        case .draftEmail:
            effects.append(SideEffect(
                type: .sendEmail,
                description: "Send follow-up email",
                requiresPermission: .mail,
                isEnabled: true,
                isAcknowledged: false
            ))
            effects.append(SideEffect(
                type: .saveDraft,
                description: "Save email draft only",
                requiresPermission: nil,
                isEnabled: false,
                isAcknowledged: true
            ))
            
        case .createReminder:
            effects.append(SideEffect(
                type: .createReminder,
                description: "Create reminder",
                requiresPermission: .reminders,
                isEnabled: true,
                isAcknowledged: false
            ))
            
        case .summarizeMeeting, .extractActionItems, .reviewDocument:
            // These are read-only, only save to memory
            effects.append(SideEffect(
                type: .saveToMemory,
                description: "Save result to memory",
                requiresPermission: nil,
                isEnabled: true,
                isAcknowledged: true
            ))
            
        case .unknown:
            effects.append(SideEffect(
                type: .saveToMemory,
                description: "Save result to memory",
                requiresPermission: nil,
                isEnabled: true,
                isAcknowledged: true
            ))
        }
        
        // Add reminder suggestion if steps mention follow-up
        let hasFollowUp = steps.contains { $0.title.lowercased().contains("remind") || $0.title.lowercased().contains("follow") }
        if hasFollowUp && !effects.contains(where: { $0.type == .createReminder }) {
            effects.append(SideEffect(
                type: .createReminder,
                description: "Create follow-up reminder",
                requiresPermission: .reminders,
                isEnabled: false, // Disabled by default
                isAcknowledged: true
            ))
        }
        
        return effects
    }
}
