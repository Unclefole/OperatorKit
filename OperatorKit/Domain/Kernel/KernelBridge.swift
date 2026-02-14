import Foundation

// ============================================================================
// KERNEL BRIDGE — PHASE 1 CAPABILITY KERNEL
//
// Bridges the new Capability Kernel with the existing execution pipeline.
// 
// Integration Strategy:
// - KernelBridge wraps execution requests
// - All executions flow through Kernel for risk assessment and approval
// - Existing ExecutionEngine remains the actual executor
// - Evidence is logged for all operations
//
// This maintains backward compatibility while adding Kernel governance.
// ============================================================================

// MARK: - Kernel Bridge

/// Bridges Capability Kernel with existing OperatorKit execution flow.
/// All execution requests should flow through this bridge.
@MainActor
public final class KernelBridge: ObservableObject {
    
    public static let shared = KernelBridge()
    
    // MARK: - Dependencies
    
    private let kernel: CapabilityKernel
    private let evidenceEngine: EvidenceEngine
    
    // MARK: - State
    
    @Published private(set) var lastKernelResult: KernelExecutionResult?
    @Published private(set) var pendingApprovalRequired: Bool = false
    @Published private(set) var currentRiskAssessment: RiskAssessment?
    
    private init() {
        self.kernel = CapabilityKernel.shared
        self.evidenceEngine = EvidenceEngine.shared
    }
    
    // MARK: - Public API
    
    /// Pre-check an intent before presenting to user
    /// Returns risk assessment and approval requirements
    public func preCheck(action: String, target: String?) async -> PreCheckResult {
        let intent = ExecutionIntent(action: action, target: target)
        
        // Run kernel execution to get assessment
        let result = await kernel.execute(intent: intent)
        
        lastKernelResult = result
        currentRiskAssessment = result.riskAssessment
        pendingApprovalRequired = result.status == .pendingApproval
        
        return PreCheckResult(
            planId: result.planId,
            riskTier: result.riskAssessment?.tier ?? .medium,
            riskScore: result.riskAssessment?.score ?? 50,
            riskReasons: result.riskAssessment?.reasons.map { $0.description } ?? [],
            approvalRequirement: result.policyDecision?.approvalRequirement ?? .previewRequired,
            reversibility: result.toolPlan?.reversibility ?? .partiallyReversible,
            requiresKernelApproval: result.status == .pendingApproval,
            canAutoApprove: result.status == .completed && result.toolPlan?.riskTier == .low,
            verificationPassed: result.verificationResult?.overallPassed ?? true,
            confidence: result.verificationResult?.confidence ?? 1.0
        )
    }
    
    /// Authorize a pending kernel execution
    public func authorize(planId: UUID, approvalType: ApprovalType, reason: String?) async -> KernelExecutionResult {
        let approval = ApprovalRecord(
            planId: planId,
            approved: true,
            approvalType: approvalType,
            approverIdentifier: "USER",
            reason: reason
        )
        
        let result = await kernel.authorize(planId: planId, approval: approval)
        
        lastKernelResult = result
        pendingApprovalRequired = false
        
        return result
    }
    
    /// Deny a pending kernel execution
    public func deny(planId: UUID, reason: String) -> KernelExecutionResult {
        let result = kernel.deny(planId: planId, reason: reason)
        
        lastKernelResult = result
        pendingApprovalRequired = false
        
        return result
    }
    
    /// Get current kernel phase
    public var currentPhase: KernelPhase {
        kernel.currentPhase
    }
    
    /// Get pending plans
    public func getPendingPlans() -> [PendingPlanContext] {
        kernel.getPendingPlans()
    }
    
    // MARK: - Token Issuance
    
    /// Issue a KernelAuthorizationToken for execution.
    /// This is the ONLY production path to obtain a valid token.
    /// Called AFTER approval is granted, BEFORE ExecutionEngine.execute().
    func issueExecutionToken(
        for draft: Draft,
        sideEffects: [SideEffect],
        approvalType: ApprovalType
    ) async -> KernelAuthorizationToken {
        // Build risk context from draft + side effects
        let riskContext = buildRiskContext(from: draft, sideEffects: sideEffects)
        let riskAssessment = RiskEngine.shared.assess(context: riskContext)
        
        // Log the token issuance to evidence
        let planId = lastKernelResult?.planId ?? UUID()
        
        let token = kernel.issueToken(
            planId: planId,
            riskTier: riskAssessment.tier,
            approvalType: approvalType
        )
        
        // Log token issuance to EvidenceEngine (unified audit)
        try? evidenceEngine.logTokenIssuance(token, draft: draft)
        
        return token
    }
    
    // MARK: - Risk Assessment Helpers
    
    /// Build risk context from draft and side effects
    func buildRiskContext(from draft: Draft, sideEffects: [SideEffect]) -> RiskContext {
        var sendsExternal = false
        var isDelete = false
        var writesFile = false
        var writesDb = false
        
        for effect in sideEffects where effect.isEnabled {
            switch effect.type {
            case .sendEmail, .presentEmailDraft:
                sendsExternal = true
            case .createReminder, .createCalendarEvent, .updateCalendarEvent:
                writesDb = true
            case .saveDraft, .saveToMemory:
                writesFile = true
            case .previewReminder, .previewCalendarEvent:
                break
            }
        }
        
        let recipientCount = draft.content.recipient != nil ? 1 : 0
        
        return RiskContextBuilder()
            .setExternalExposure(
                sends: sendsExternal,
                recipientCount: recipientCount,
                public_: false,
                thirdParty: false
            )
            .setMutation(
                database: writesDb,
                fileSystem: writesFile,
                delete: isDelete,
                config: false
            )
            .setDataSensitivity(
                pii: recipientCount > 0,  // Has recipient = has PII
                credentials: false,
                health: false,
                financial: false
            )
            .setReversibility(
                sendsExternal ? .irreversible : .reversible,
                hasRollback: !sendsExternal
            )
            .build()
    }
    
    /// Map draft type to intent type
    func mapToIntentType(draftType: Draft.DraftType) -> IntentType {
        switch draftType {
        case .email:
            return .sendEmail
        case .reminder:
            return .createReminder
        case .summary, .actionItems, .documentReview, .researchBrief:
            return .createDraft
        }
    }
    
    /// Map side effect type to intent type
    func mapToIntentType(sideEffectType: SideEffect.SideEffectType) -> IntentType {
        switch sideEffectType {
        case .sendEmail, .presentEmailDraft:
            return .sendEmail
        case .createReminder:
            return .createReminder
        case .createCalendarEvent:
            return .createCalendarEvent
        case .updateCalendarEvent:
            return .updateCalendarEvent
        case .saveDraft, .saveToMemory:
            return .createDraft
        case .previewReminder:
            return .createReminder
        case .previewCalendarEvent:
            return .createCalendarEvent
        }
    }
}

// MARK: - Pre-Check Result

public struct PreCheckResult {
    public let planId: UUID?
    public let riskTier: RiskTier
    public let riskScore: Int
    public let riskReasons: [String]
    public let approvalRequirement: ApprovalRequirement
    public let reversibility: ReversibilityClass
    public let requiresKernelApproval: Bool
    public let canAutoApprove: Bool
    public let verificationPassed: Bool
    public let confidence: Double
    
    /// Human-readable risk summary
    public var riskSummary: String {
        var parts: [String] = ["Risk: \(riskTier.rawValue) (\(riskScore)/100)"]
        
        if !riskReasons.isEmpty {
            parts.append(contentsOf: riskReasons.prefix(3))
        }
        
        if reversibility == .irreversible {
            parts.append("⚠️ Irreversible action")
        }
        
        return parts.joined(separator: "\n")
    }
    
    /// Approval requirement summary
    public var approvalSummary: String {
        var requirements: [String] = []
        
        if approvalRequirement.requiresPreview {
            requirements.append("Preview required")
        }
        if approvalRequirement.requiresBiometric {
            requirements.append("Biometric confirmation required")
        }
        if approvalRequirement.cooldownSeconds > 0 {
            requirements.append("Cooldown: \(approvalRequirement.cooldownSeconds)s")
        }
        if approvalRequirement.multiSignerCount > 1 {
            requirements.append("Multi-signature: \(approvalRequirement.multiSignerCount)")
        }
        
        if requirements.isEmpty {
            return "Auto-approved"
        }
        
        return requirements.joined(separator: " • ")
    }
}

// MARK: - Draft Extension for Kernel Integration

extension Draft {
    /// Convert draft to execution intent
    func toExecutionIntent() -> ExecutionIntent {
        let action: String
        switch type {
        case .email:
            action = "send email"
        case .reminder:
            action = "create reminder"
        case .summary:
            action = "create summary"
        case .actionItems:
            action = "extract action items"
        case .documentReview:
            action = "review document"
        case .researchBrief:
            action = "generate research brief"
        }
        
        return ExecutionIntent(
            action: action,
            target: content.recipient,
            parameters: [
                "draftId": id.uuidString,
                "draftType": type.rawValue,
                "confidence": confidence
            ]
        )
    }
}

// MARK: - Side Effect Extensions

extension SideEffect.SideEffectType {
    /// Check if this side effect type requires Kernel approval
    var requiresKernelApproval: Bool {
        switch self {
        case .sendEmail, .presentEmailDraft:
            return true
        case .createReminder, .createCalendarEvent, .updateCalendarEvent:
            return true
        case .saveDraft, .saveToMemory:
            return false  // Low risk, can auto-approve
        case .previewReminder, .previewCalendarEvent:
            return false  // Preview only
        }
    }
    
    /// Risk multiplier for this side effect type
    var riskMultiplier: Double {
        switch self {
        case .sendEmail, .presentEmailDraft:
            return 1.5  // High - external communication
        case .createReminder:
            return 0.8
        case .createCalendarEvent, .updateCalendarEvent:
            return 1.0
        case .saveDraft, .saveToMemory:
            return 0.3
        case .previewReminder, .previewCalendarEvent:
            return 0.1
        }
    }
}

// MARK: - Draft Type Extension

extension Draft.DraftType {
    /// Whether this draft type requires Kernel oversight
    var requiresKernelOversight: Bool {
        switch self {
        case .email:
            return true  // External communication
        case .reminder:
            return true  // System write
        case .summary, .actionItems, .documentReview, .researchBrief:
            return false  // Internal processing
        }
    }
}
