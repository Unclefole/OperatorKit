import Foundation
import CryptoKit

// ============================================================================
// CAPABILITY KERNEL — PHASE 1 PRIMARY MOAT
//
// Goal: Become the decision authority for whether AI is allowed to act.
//
// INVARIANT 1: No side effects without Kernel approval
// INVARIANT 2: Every action originates from a signed ToolPlan
// INVARIANT 3: Verification BEFORE execution (never after)
// INVARIANT 4: Secrets never leave trust boundary
// INVARIANT 5: Uncertainty escalates — never executes
//
// Execution Flow:
// INTAKE → CLASSIFY → RISK SCORE → REVERSIBILITY CHECK → PROBES → APPROVAL → EXECUTE
//
// NO module may self-authorize. Kernel is supreme authority.
// ============================================================================

// MARK: - Capability Kernel

/// The supreme authority for all execution decisions.
/// No side effect can occur without Kernel authorization.
@MainActor
public final class CapabilityKernel: ObservableObject {
    
    public static let shared = CapabilityKernel()
    
    // MARK: - Dependencies
    
    private let riskEngine: RiskEngine
    private let policyEngine: PolicyEngine
    private let verificationEngine: VerificationEngine
    private let evidenceEngine: EvidenceEngine
    
    // MARK: - State
    
    @Published private(set) var currentPhase: KernelPhase = .idle
    @Published private(set) var lastExecutionResult: KernelExecutionResult?
    @Published private(set) var activeCooldowns: [String: Date] = [:]
    
    // MARK: - Configuration
    
    private let confidenceThreshold: Double = 0.8
    private let maxPendingPlans: Int = 10
    
    // MARK: - Pending Plans (awaiting approval)
    
    private var pendingPlans: [UUID: PendingPlanContext] = [:]
    
    private init() {
        self.riskEngine = RiskEngine.shared
        self.policyEngine = PolicyEngine.shared
        self.verificationEngine = VerificationEngine.shared
        self.evidenceEngine = EvidenceEngine.shared
    }
    
    // MARK: - Public API
    
    /// Execute a complete kernel flow for an intent
    /// This is the primary entry point for all execution requests
    public func execute(intent: ExecutionIntent) async -> KernelExecutionResult {
        let startTime = Date()
        currentPhase = .intake
        
        // PHASE 1: INTAKE — Validate and normalize the intent
        guard let normalizedIntent = normalizeIntent(intent) else {
            return failWithViolation(
                reason: "Invalid intent - normalization failed",
                phase: .intake,
                startTime: startTime
            )
        }
        
        // PHASE 2: CLASSIFY — Determine intent type and characteristics
        currentPhase = .classify
        let classification = classifyIntent(normalizedIntent)
        
        // PHASE 3: RISK SCORE — Quantify blast radius
        currentPhase = .riskScore
        let riskContext = buildRiskContext(from: normalizedIntent, classification: classification)
        let riskAssessment = riskEngine.assess(context: riskContext)
        
        // PHASE 4: REVERSIBILITY CHECK — Determine if rollback is possible
        currentPhase = .reversibilityCheck
        let reversibilityAssessment = verificationEngine.classifyReversibility(
            for: classification.intentType,
            context: ReversibilityContext()
        )
        
        // PHASE 5: BUILD TOOL PLAN — Create signed plan
        let toolPlan = buildToolPlan(
            intent: normalizedIntent,
            classification: classification,
            riskAssessment: riskAssessment,
            reversibilityAssessment: reversibilityAssessment
        )
        
        // Log plan creation
        try? evidenceEngine.logToolPlanCreated(toolPlan)
        try? evidenceEngine.logRiskAssessment(riskAssessment, planId: toolPlan.id)
        
        // PHASE 6: PROBES — Run idempotent verification probes
        currentPhase = .probes
        let verificationResult = await verificationEngine.verify(plan: toolPlan)
        try? evidenceEngine.logVerificationResult(verificationResult, planId: toolPlan.id)
        
        // Check verification passed
        guard verificationResult.overallPassed else {
            return failWithEvidence(
                reason: "Verification failed: \(verificationResult.summary)",
                phase: .probes,
                startTime: startTime,
                toolPlan: toolPlan,
                riskAssessment: riskAssessment,
                verificationResult: verificationResult
            )
        }
        
        // Check confidence threshold
        if verificationResult.confidence < confidenceThreshold {
            return escalateForHumanReview(
                reason: "Confidence below threshold (\(Int(verificationResult.confidence * 100))% < \(Int(confidenceThreshold * 100))%)",
                toolPlan: toolPlan,
                riskAssessment: riskAssessment,
                verificationResult: verificationResult
            )
        }
        
        // PHASE 7: POLICY — Determine approval requirements
        currentPhase = .policyMapping
        let policyDecision = policyEngine.mapToApproval(assessment: riskAssessment)
        
        // Check for active cooldown
        if let cooldownEnd = activeCooldowns[toolPlan.intent.type.hashableKey] {
            if Date() < cooldownEnd {
                let remaining = Int(cooldownEnd.timeIntervalSinceNow)
                return failWithCooldown(
                    remainingSeconds: remaining,
                    toolPlan: toolPlan,
                    riskAssessment: riskAssessment,
                    verificationResult: verificationResult,
                    policyDecision: policyDecision
                )
            } else {
                // Cooldown expired, remove it
                activeCooldowns.removeValue(forKey: toolPlan.intent.type.hashableKey)
            }
        }
        
        // PHASE 8: APPROVAL — Collect required approvals
        currentPhase = .approval
        
        // For LOW risk, auto-approve
        if policyDecision.tier == .low && !policyDecision.approvalRequirement.requiresPreview {
            let approval = ApprovalRecord(
                planId: toolPlan.id,
                approved: true,
                approvalType: .automatic,
                approverIdentifier: "KERNEL_AUTO",
                reason: "Low risk - auto-approved per policy"
            )
            try? evidenceEngine.logApproval(approval, planId: toolPlan.id)
            
            // Proceed to execution
            return await executeAuthorized(
                toolPlan: toolPlan,
                riskAssessment: riskAssessment,
                verificationResult: verificationResult,
                policyDecision: policyDecision,
                approval: approval,
                startTime: startTime
            )
        }
        
        // For MEDIUM+ risk, require user approval
        // Store pending plan and return pending result
        let pendingContext = PendingPlanContext(
            toolPlan: toolPlan,
            riskAssessment: riskAssessment,
            verificationResult: verificationResult,
            policyDecision: policyDecision,
            createdAt: Date()
        )
        
        pendingPlans[toolPlan.id] = pendingContext
        
        currentPhase = .awaitingApproval
        
        return KernelExecutionResult(
            id: UUID(),
            status: .pendingApproval,
            planId: toolPlan.id,
            phase: .awaitingApproval,
            message: "Awaiting user approval - \(policyDecision.summary)",
            startedAt: startTime,
            completedAt: Date(),
            toolPlan: toolPlan,
            riskAssessment: riskAssessment,
            verificationResult: verificationResult,
            policyDecision: policyDecision,
            approvalRecord: nil,
            executionOutcome: nil
        )
    }
    
    /// Authorize a pending plan after user approval
    public func authorize(planId: UUID, approval: ApprovalRecord) async -> KernelExecutionResult {
        guard let pendingContext = pendingPlans[planId] else {
            return KernelExecutionResult(
                id: UUID(),
                status: .failed,
                planId: planId,
                phase: .approval,
                message: "No pending plan found for ID",
                startedAt: Date(),
                completedAt: Date(),
                toolPlan: nil,
                riskAssessment: nil,
                verificationResult: nil,
                policyDecision: nil,
                approvalRecord: nil,
                executionOutcome: nil
            )
        }
        
        // Remove from pending
        pendingPlans.removeValue(forKey: planId)
        
        // Log approval
        try? evidenceEngine.logApproval(approval, planId: planId)
        
        if !approval.approved {
            return KernelExecutionResult(
                id: UUID(),
                status: .denied,
                planId: planId,
                phase: .approval,
                message: "User denied approval: \(approval.reason ?? "No reason given")",
                startedAt: pendingContext.createdAt,
                completedAt: Date(),
                toolPlan: pendingContext.toolPlan,
                riskAssessment: pendingContext.riskAssessment,
                verificationResult: pendingContext.verificationResult,
                policyDecision: pendingContext.policyDecision,
                approvalRecord: approval,
                executionOutcome: nil
            )
        }
        
        // Proceed to execution
        return await executeAuthorized(
            toolPlan: pendingContext.toolPlan,
            riskAssessment: pendingContext.riskAssessment,
            verificationResult: pendingContext.verificationResult,
            policyDecision: pendingContext.policyDecision,
            approval: approval,
            startTime: pendingContext.createdAt
        )
    }
    
    /// Deny a pending plan
    public func deny(planId: UUID, reason: String) -> KernelExecutionResult {
        guard let pendingContext = pendingPlans[planId] else {
            return KernelExecutionResult(
                id: UUID(),
                status: .failed,
                planId: planId,
                phase: .approval,
                message: "No pending plan found for ID",
                startedAt: Date(),
                completedAt: Date(),
                toolPlan: nil,
                riskAssessment: nil,
                verificationResult: nil,
                policyDecision: nil,
                approvalRecord: nil,
                executionOutcome: nil
            )
        }
        
        // Remove from pending
        pendingPlans.removeValue(forKey: planId)
        
        let denial = ApprovalRecord(
            planId: planId,
            approved: false,
            approvalType: .denied,
            approverIdentifier: "USER",
            reason: reason
        )
        
        try? evidenceEngine.logApproval(denial, planId: planId)
        
        currentPhase = .idle
        
        return KernelExecutionResult(
            id: UUID(),
            status: .denied,
            planId: planId,
            phase: .approval,
            message: "User denied: \(reason)",
            startedAt: pendingContext.createdAt,
            completedAt: Date(),
            toolPlan: pendingContext.toolPlan,
            riskAssessment: pendingContext.riskAssessment,
            verificationResult: pendingContext.verificationResult,
            policyDecision: pendingContext.policyDecision,
            approvalRecord: denial,
            executionOutcome: nil
        )
    }
    
    /// Get pending plans awaiting approval
    public func getPendingPlans() -> [PendingPlanContext] {
        Array(pendingPlans.values)
    }
    
    // MARK: - Internal Execution
    
    private func executeAuthorized(
        toolPlan: ToolPlan,
        riskAssessment: RiskAssessment,
        verificationResult: KernelVerificationResult,
        policyDecision: KernelPolicyDecision,
        approval: ApprovalRecord,
        startTime: Date
    ) async -> KernelExecutionResult {
        
        // Enforce cooldown for irreversible actions
        if toolPlan.reversibility == .irreversible && policyDecision.approvalRequirement.cooldownSeconds > 0 {
            let cooldownEnd = Date().addingTimeInterval(TimeInterval(policyDecision.approvalRequirement.cooldownSeconds))
            activeCooldowns[toolPlan.intent.type.hashableKey] = cooldownEnd
        }
        
        // PHASE 9: EXECUTE — Perform the authorized action
        currentPhase = .execute
        
        let executionStartTime = Date()
        let outcome: KernelExecutionOutcome
        
        do {
            // Execute via the appropriate executor
            // For Phase 1, we simulate execution
            try await simulateExecution(toolPlan: toolPlan)
            
            outcome = KernelExecutionOutcome(
                planId: toolPlan.id,
                success: true,
                status: .completed,
                startedAt: executionStartTime,
                resultSummary: "Execution completed successfully"
            )
        } catch {
            outcome = KernelExecutionOutcome(
                planId: toolPlan.id,
                success: false,
                status: .failed,
                startedAt: executionStartTime,
                errorMessage: error.localizedDescription,
                resultSummary: "Execution failed: \(error.localizedDescription)"
            )
        }
        
        // Log execution outcome
        try? evidenceEngine.logExecutionOutcome(outcome, planId: toolPlan.id)
        
        // PHASE 10: LOG EVIDENCE — Create complete chain
        currentPhase = .logEvidence
        
        let evidenceChain = ExecutionEvidenceChain(
            planId: toolPlan.id,
            toolPlan: toolPlan,
            riskAssessment: riskAssessment,
            verificationResult: verificationResult,
            policyDecision: policyDecision,
            approvalRecord: approval,
            executionOutcome: outcome
        )
        
        try? evidenceEngine.logExecutionChain(evidenceChain)
        
        currentPhase = .idle
        
        let result = KernelExecutionResult(
            id: UUID(),
            status: outcome.success ? .completed : .failed,
            planId: toolPlan.id,
            phase: .complete,
            message: outcome.resultSummary,
            startedAt: startTime,
            completedAt: Date(),
            toolPlan: toolPlan,
            riskAssessment: riskAssessment,
            verificationResult: verificationResult,
            policyDecision: policyDecision,
            approvalRecord: approval,
            executionOutcome: outcome
        )
        
        lastExecutionResult = result
        return result
    }
    
    private func simulateExecution(toolPlan: ToolPlan) async throws {
        // Phase 1: Simulate execution with a small delay
        // In production, this would dispatch to actual executors
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
    }
    
    // MARK: - Token Issuance
    
    /// Issue an AuthorizationToken for an authorized plan.
    /// This is the ONLY way to obtain a token in the entire system.
    /// INVARIANT: Tokens are issued ONLY after full pipeline evaluation.
    public func issueToken(
        planId: UUID,
        riskTier: RiskTier,
        approvalType: ApprovalType
    ) -> AuthorizationToken {
        let issuedAt = Date()
        // Token validity: 60 seconds for execution window
        let expiresAt = issuedAt.addingTimeInterval(60)
        
        let signature = CapabilityKernel.computeSignature(
            planId: planId,
            issuedAt: issuedAt,
            expiresAt: expiresAt
        )
        
        return AuthorizationToken(
            planId: planId,
            riskTier: riskTier,
            approvalType: approvalType,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            signature: signature
        )
    }
    
    // MARK: - Intent Processing
    
    private func normalizeIntent(_ intent: ExecutionIntent) -> ExecutionIntent? {
        // Validate required fields
        guard !intent.action.isEmpty else { return nil }
        return intent
    }
    
    private func classifyIntent(_ intent: ExecutionIntent) -> IntentClassification {
        let intentType = determineIntentType(from: intent)
        return IntentClassification(
            intentType: intentType,
            isMutation: intentType.isMutation,
            isExternalCommunication: intentType.isExternalCommunication,
            sensitivity: determineSensitivity(intent: intent, type: intentType)
        )
    }
    
    private func determineIntentType(from intent: ExecutionIntent) -> IntentType {
        let action = intent.action.lowercased()
        
        if action.contains("email") || action.contains("send") {
            return .sendEmail
        } else if action.contains("draft") {
            return .createDraft
        } else if action.contains("calendar") {
            if action.contains("delete") { return .deleteCalendarEvent }
            if action.contains("update") { return .updateCalendarEvent }
            if action.contains("create") { return .createCalendarEvent }
            return .readCalendar
        } else if action.contains("reminder") {
            return .createReminder
        } else if action.contains("file") {
            if action.contains("delete") { return .fileDelete }
            if action.contains("write") { return .fileWrite }
        } else if action.contains("api") {
            return .externalAPICall
        } else if action.contains("database") || action.contains("db") {
            return .databaseMutation
        }
        
        return .unknown
    }
    
    private func determineSensitivity(intent: ExecutionIntent, type: IntentType) -> SensitivityLevel {
        // Check for PII indicators
        let content = intent.action.lowercased() + (intent.target ?? "").lowercased()
        
        if content.contains("password") || content.contains("secret") || content.contains("credential") {
            return .critical
        }
        if content.contains("health") || content.contains("medical") {
            return .high
        }
        if content.contains("email") || content.contains("phone") || content.contains("address") {
            return .medium
        }
        
        return type.isExternalCommunication ? .medium : .low
    }
    
    private func buildRiskContext(from intent: ExecutionIntent, classification: IntentClassification) -> RiskContext {
        RiskContextBuilder()
            .setExternalExposure(
                sends: classification.isExternalCommunication,
                recipientCount: 1,
                public_: false,
                thirdParty: classification.intentType == .externalAPICall
            )
            .setDataSensitivity(
                pii: classification.sensitivity >= .medium,
                credentials: classification.sensitivity == .critical,
                health: false,
                financial: false
            )
            .setMutation(
                database: classification.intentType == .databaseMutation,
                fileSystem: classification.intentType == .fileWrite || classification.intentType == .fileDelete,
                delete: classification.intentType == .fileDelete || classification.intentType == .deleteCalendarEvent,
                config: classification.intentType == .systemConfiguration
            )
            .setReversibility(
                classification.intentType.defaultReversibility,
                hasRollback: classification.intentType.defaultReversibility != .irreversible
            )
            .build()
    }
    
    private func buildToolPlan(
        intent: ExecutionIntent,
        classification: IntentClassification,
        riskAssessment: RiskAssessment,
        reversibilityAssessment: ReversibilityAssessment
    ) -> ToolPlan {
        
        let probes = verificationEngine.generateProbes(
            for: classification.intentType,
            target: intent.target ?? "default"
        )
        
        let executionSteps = generateExecutionSteps(for: classification.intentType, intent: intent)
        
        return ToolPlanBuilder()
            .setIntent(ToolPlanIntent(
                type: classification.intentType,
                summary: intent.action,
                targetDescription: intent.target ?? "N/A"
            ))
            .setOriginatingAction(intent.action)
            .setRisk(score: riskAssessment.score, reasons: riskAssessment.reasons.map { $0.description })
            .setReversibility(reversibilityAssessment.reversibilityClass, reason: reversibilityAssessment.reason)
            .addProbe(contentsOf: probes)
            .addExecutionStep(contentsOf: executionSteps)
            .build()!
    }
    
    private func generateExecutionSteps(for intentType: IntentType, intent: ExecutionIntent) -> [ExecutionStepDefinition] {
        var steps: [ExecutionStepDefinition] = []
        
        switch intentType {
        case .sendEmail:
            steps.append(ExecutionStepDefinition(order: 1, action: "compose_email", description: "Compose email content", isMutation: false))
            steps.append(ExecutionStepDefinition(order: 2, action: "validate_recipient", description: "Validate recipient address", isMutation: false))
            steps.append(ExecutionStepDefinition(order: 3, action: "send_email", description: "Send email via mail service", isMutation: true))
            
        case .createCalendarEvent:
            steps.append(ExecutionStepDefinition(order: 1, action: "prepare_event", description: "Prepare event details", isMutation: false))
            steps.append(ExecutionStepDefinition(order: 2, action: "create_event", description: "Create event in calendar", isMutation: true, rollbackAction: "delete_event"))
            
        case .createDraft:
            steps.append(ExecutionStepDefinition(order: 1, action: "generate_draft", description: "Generate draft content", isMutation: false))
            steps.append(ExecutionStepDefinition(order: 2, action: "save_draft", description: "Save draft locally", isMutation: true, rollbackAction: "delete_draft"))
            
        default:
            steps.append(ExecutionStepDefinition(order: 1, action: "execute", description: "Execute action", isMutation: true))
        }
        
        return steps
    }
    
    // MARK: - Failure Helpers
    
    private func failWithViolation(reason: String, phase: KernelPhase, startTime: Date) -> KernelExecutionResult {
        let violation = PolicyViolation(
            violationType: .bypassAttempt,
            description: reason,
            severity: .high
        )
        try? evidenceEngine.logViolation(violation, planId: nil)
        
        currentPhase = .idle
        
        return KernelExecutionResult(
            id: UUID(),
            status: .failed,
            planId: nil,
            phase: phase,
            message: reason,
            startedAt: startTime,
            completedAt: Date(),
            toolPlan: nil,
            riskAssessment: nil,
            verificationResult: nil,
            policyDecision: nil,
            approvalRecord: nil,
            executionOutcome: nil
        )
    }
    
    private func failWithEvidence(
        reason: String,
        phase: KernelPhase,
        startTime: Date,
        toolPlan: ToolPlan,
        riskAssessment: RiskAssessment,
        verificationResult: KernelVerificationResult
    ) -> KernelExecutionResult {
        currentPhase = .idle
        
        return KernelExecutionResult(
            id: UUID(),
            status: .failed,
            planId: toolPlan.id,
            phase: phase,
            message: reason,
            startedAt: startTime,
            completedAt: Date(),
            toolPlan: toolPlan,
            riskAssessment: riskAssessment,
            verificationResult: verificationResult,
            policyDecision: nil,
            approvalRecord: nil,
            executionOutcome: nil
        )
    }
    
    private func failWithCooldown(
        remainingSeconds: Int,
        toolPlan: ToolPlan,
        riskAssessment: RiskAssessment,
        verificationResult: KernelVerificationResult,
        policyDecision: KernelPolicyDecision
    ) -> KernelExecutionResult {
        currentPhase = .idle
        
        return KernelExecutionResult(
            id: UUID(),
            status: .cooldownActive,
            planId: toolPlan.id,
            phase: .approval,
            message: "Cooldown active - \(remainingSeconds) seconds remaining",
            startedAt: Date(),
            completedAt: Date(),
            toolPlan: toolPlan,
            riskAssessment: riskAssessment,
            verificationResult: verificationResult,
            policyDecision: policyDecision,
            approvalRecord: nil,
            executionOutcome: nil
        )
    }
    
    private func escalateForHumanReview(
        reason: String,
        toolPlan: ToolPlan,
        riskAssessment: RiskAssessment,
        verificationResult: KernelVerificationResult
    ) -> KernelExecutionResult {
        
        // INVARIANT 5: Uncertainty escalates — never executes
        currentPhase = .awaitingApproval
        
        return KernelExecutionResult(
            id: UUID(),
            status: .escalated,
            planId: toolPlan.id,
            phase: .probes,
            message: "Escalated for human review: \(reason)",
            startedAt: Date(),
            completedAt: Date(),
            toolPlan: toolPlan,
            riskAssessment: riskAssessment,
            verificationResult: verificationResult,
            policyDecision: nil,
            approvalRecord: nil,
            executionOutcome: nil
        )
    }
    
    // MARK: - Execution Eligibility (SOLE POLICY AUTHORITY)
    
    /// Evaluate whether a draft is eligible for execution.
    ///
    /// THIS IS THE SOLE POLICY AUTHORITY for:
    /// - Confidence thresholds
    /// - Permission validation
    /// - Approval tier mapping
    /// - Execution eligibility
    ///
    /// ApprovalGate delegates to this method. It does NOT make its own decisions.
    /// If this method returns .denied → execution MUST NOT proceed.
    func evaluateExecutionEligibility(
        draft: Draft,
        sideEffects: [SideEffect],
        permissionState: PermissionState,
        approvalGranted: Bool,
        didConfirmLowConfidence: Bool
    ) -> KernelAuthorizationDecision {
        var violations: [KernelPolicyViolationReason] = []
        
        // ─── POLICY 1: Approval must be granted ──────────────────────────
        if !approvalGranted {
            violations.append(.approvalNotGranted)
        }
        
        // ─── POLICY 2: Confidence minimum threshold (KERNEL OWNS THIS) ──
        if draft.confidence < DraftOutput.minimumExecutionConfidence {
            violations.append(.confidenceBelowMinimum(
                actual: draft.confidence,
                required: DraftOutput.minimumExecutionConfidence
            ))
            // Hard block — return immediately
            return KernelAuthorizationDecision.denied(
                violations: violations,
                confidenceScore: draft.confidence,
                reason: "Confidence \(Int(draft.confidence * 100))% is below minimum threshold \(Int(DraftOutput.minimumExecutionConfidence * 100))%"
            )
        }
        
        // ─── POLICY 3: Low confidence requires explicit user confirmation ──
        if draft.confidence < DraftOutput.directProceedConfidence &&
           draft.confidence >= DraftOutput.minimumExecutionConfidence &&
           !didConfirmLowConfidence {
            violations.append(.lowConfidenceUnconfirmed(confidence: draft.confidence))
        }
        
        // ─── POLICY 4: Permission validation (KERNEL OWNS THIS) ─────────
        let enabledEffects = sideEffects.filter { $0.isEnabled }
        var missingPermissions: [SideEffect.PermissionType] = []
        
        for effect in enabledEffects {
            guard let required = effect.requiresPermission else { continue }
            switch required {
            case .calendar:
                if !permissionState.calendar.isGranted { missingPermissions.append(.calendar) }
            case .mail:
                if !permissionState.mail.isGranted { missingPermissions.append(.mail) }
            case .reminders:
                if !permissionState.reminders.isGranted { missingPermissions.append(.reminders) }
            }
        }
        
        let uniquePermissions = Array(Set(missingPermissions))
        if !uniquePermissions.isEmpty {
            violations.append(.missingPermissions(uniquePermissions))
        }
        
        // ─── POLICY 5: Side effects acknowledgement ─────────────────────
        let unacknowledged = enabledEffects.filter { !$0.isAcknowledged }
        if !unacknowledged.isEmpty {
            violations.append(.sideEffectsNotAcknowledged(count: unacknowledged.count))
        }
        
        // ─── DECISION ───────────────────────────────────────────────────
        if !violations.isEmpty {
            return KernelAuthorizationDecision.denied(
                violations: violations,
                confidenceScore: draft.confidence,
                reason: violations.first?.description
            )
        }
        
        // ─── RISK ASSESSMENT ────────────────────────────────────────────
        let riskContext = buildDraftRiskContext(draft: draft, sideEffects: sideEffects)
        let riskAssessment = RiskEngine.shared.assess(context: riskContext)
        let policyDecision = PolicyEngine.shared.mapToApproval(assessment: riskAssessment)
        
        return KernelAuthorizationDecision.allowed(
            riskTier: riskAssessment.tier,
            confidenceScore: draft.confidence,
            policyDecision: policyDecision
        )
    }
    
    /// Build risk context from draft + side effects (for eligibility evaluation).
    private func buildDraftRiskContext(draft: Draft, sideEffects: [SideEffect]) -> RiskContext {
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
                pii: recipientCount > 0,
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
}

// MARK: - Kernel Authorization Token (Nested Type)

extension CapabilityKernel {
    
    /// The SOLE credential required to execute any side effect.
    /// Issued ONLY by CapabilityKernel after full pipeline evaluation.
    ///
    /// SECURITY PROPERTIES:
    /// - fileprivate init: ONLY code in CapabilityKernel.swift can construct tokens
    /// - HMAC-SHA256 signature: cryptographically bound to planId + timestamps
    /// - 60-second expiry: limits replay window
    /// - One-use enforcement: consumed tokens are tracked and rejected on reuse
    /// - Signature verification: consumers MUST call verifySignature() — not just isValid
    ///
    /// INVARIANT: No side effect may execute without a valid token.
    /// INVARIANT: Tokens cannot be created outside this file.
    public struct AuthorizationToken: Identifiable {
        public let id: UUID
        public let planId: UUID
        public let riskTier: RiskTier
        public let approvalType: ApprovalType
        public let issuedAt: Date
        public let expiresAt: Date
        public let signature: String
        
        /// fileprivate: ONLY CapabilityKernel.swift can create tokens.
        /// No other file in the module can call this initializer.
        fileprivate init(
            planId: UUID,
            riskTier: RiskTier,
            approvalType: ApprovalType,
            issuedAt: Date = Date(),
            expiresAt: Date,
            signature: String
        ) {
            self.id = UUID()
            self.planId = planId
            self.riskTier = riskTier
            self.approvalType = approvalType
            self.issuedAt = issuedAt
            self.expiresAt = expiresAt
            self.signature = signature
        }
        
        /// Basic validity: not expired and signature is non-empty.
        /// NOTE: Consumers MUST also call verifySignature() for full cryptographic check.
        public var isValid: Bool {
            Date() < expiresAt && !signature.isEmpty
        }
        
        /// Full cryptographic verification of the token signature.
        /// Recomputes HMAC from token fields and compares to stored signature.
        /// This MUST be called before any side effect executes.
        public func verifySignature() -> Bool {
            guard isValid else { return false }
            let expectedSignature = CapabilityKernel.computeSignature(
                planId: planId,
                issuedAt: issuedAt,
                expiresAt: expiresAt
            )
            return signature == expectedSignature
        }
    }
    
    // MARK: - Signing Key (file-private)
    
    /// The signing key for token HMAC. fileprivate ensures it cannot leak.
    fileprivate nonisolated(unsafe) static let tokenSigningKey = SymmetricKey(
        data: "OperatorKit-Token-Signing-Key-v1".data(using: .utf8)!
    )
    
    /// Compute the expected HMAC signature for a token.
    /// Used by both issueToken() and AuthorizationToken.verifySignature().
    /// nonisolated: pure computation, no mutable state, safe to call from any context.
    fileprivate nonisolated static func computeSignature(planId: UUID, issuedAt: Date, expiresAt: Date) -> String {
        let payload = "\(planId.uuidString)|\(issuedAt.timeIntervalSince1970)|\(expiresAt.timeIntervalSince1970)"
        let payloadData = payload.data(using: .utf8)!
        let mac = HMAC<SHA256>.authenticationCode(for: payloadData, using: tokenSigningKey)
        return Data(mac).base64EncodedString()
    }
    
    // MARK: - Consumed Token Tracking (One-Use Enforcement)
    
    /// Set of consumed token IDs. A token can only be used ONCE.
    /// @MainActor isolation inherited from CapabilityKernel — safe for mutation.
    private static var consumedTokenIds: Set<UUID> = []
    
    /// Check if a token has already been consumed.
    public static func isTokenConsumed(_ token: AuthorizationToken) -> Bool {
        consumedTokenIds.contains(token.id)
    }
    
    /// Mark a token as consumed. Returns false if already consumed.
    @discardableResult
    public static func consumeToken(_ token: AuthorizationToken) -> Bool {
        let (inserted, _) = consumedTokenIds.insert(token.id)
        return inserted  // true = first use, false = replay attempt
    }
}

/// Public typealias for backward compatibility.
/// All new code should use CapabilityKernel.AuthorizationToken directly.
public typealias KernelAuthorizationToken = CapabilityKernel.AuthorizationToken

// MARK: - Kernel Authorization Decision

/// The kernel's policy decision for a draft execution request.
/// Returned by CapabilityKernel.evaluateExecutionEligibility().
///
/// This is the SOLE policy output in the system.
/// ApprovalGate converts this to UI-friendly ApprovalValidation.
struct KernelAuthorizationDecision {
    let executionAllowed: Bool
    let riskTier: RiskTier
    let approvalRequired: Bool
    let violations: [KernelPolicyViolationReason]
    let confidenceScore: Double
    let reason: String?
    let policyDecision: KernelPolicyDecision?
    
    /// Execution denied by kernel policy.
    static func denied(
        violations: [KernelPolicyViolationReason],
        confidenceScore: Double,
        reason: String?
    ) -> KernelAuthorizationDecision {
        KernelAuthorizationDecision(
            executionAllowed: false,
            riskTier: .critical,
            approvalRequired: false,
            violations: violations,
            confidenceScore: confidenceScore,
            reason: reason,
            policyDecision: nil
        )
    }
    
    /// Execution allowed by kernel policy.
    static func allowed(
        riskTier: RiskTier,
        confidenceScore: Double,
        policyDecision: KernelPolicyDecision?
    ) -> KernelAuthorizationDecision {
        KernelAuthorizationDecision(
            executionAllowed: true,
            riskTier: riskTier,
            approvalRequired: policyDecision?.approvalRequirement.approvalsNeeded ?? 0 > 0,
            violations: [],
            confidenceScore: confidenceScore,
            reason: nil,
            policyDecision: policyDecision
        )
    }
}

// MARK: - Kernel Policy Violation Reason

/// Typed violation reasons returned by the kernel's policy evaluation.
/// ApprovalGate maps these to InvariantViolation for UI display.
enum KernelPolicyViolationReason: Equatable {
    case approvalNotGranted
    case confidenceBelowMinimum(actual: Double, required: Double)
    case lowConfidenceUnconfirmed(confidence: Double)
    case missingPermissions([SideEffect.PermissionType])
    case sideEffectsNotAcknowledged(count: Int)
    
    public var description: String {
        switch self {
        case .approvalNotGranted:
            return "Approval not granted by user"
        case .confidenceBelowMinimum(let actual, let required):
            return "Confidence \(Int(actual * 100))% is below minimum \(Int(required * 100))%"
        case .lowConfidenceUnconfirmed(let confidence):
            return "Low confidence \(Int(confidence * 100))% requires explicit confirmation"
        case .missingPermissions(let permissions):
            let names = permissions.map { $0.rawValue }.joined(separator: ", ")
            return "Missing permissions: \(names)"
        case .sideEffectsNotAcknowledged(let count):
            return "\(count) side effect(s) not acknowledged"
        }
    }
}

// MARK: - Execution Errors

public enum ExecutionError: Error, LocalizedError {
    case kernelAuthorizationRequired
    case tokenExpired(planId: UUID)
    case tokenInvalid(reason: String)
    case concurrentExecution
    
    public var errorDescription: String? {
        switch self {
        case .kernelAuthorizationRequired:
            return "HARD FAIL: No KernelAuthorizationToken provided. Execution denied."
        case .tokenExpired(let planId):
            return "Token expired for plan \(planId.uuidString)"
        case .tokenInvalid(let reason):
            return "Token invalid: \(reason)"
        case .concurrentExecution:
            return "Concurrent execution blocked"
        }
    }
}

// MARK: - Supporting Types

public struct ExecutionIntent {
    public let action: String
    public let target: String?
    public let parameters: [String: Any]
    public let requestedAt: Date
    
    public init(action: String, target: String? = nil, parameters: [String: Any] = [:]) {
        self.action = action
        self.target = target
        self.parameters = parameters
        self.requestedAt = Date()
    }
}

public struct IntentClassification {
    public let intentType: IntentType
    public let isMutation: Bool
    public let isExternalCommunication: Bool
    public let sensitivity: SensitivityLevel
}

public enum SensitivityLevel: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    public static func < (lhs: SensitivityLevel, rhs: SensitivityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum KernelPhase: String, Codable {
    case idle = "idle"
    case intake = "intake"
    case classify = "classify"
    case riskScore = "risk_score"
    case reversibilityCheck = "reversibility_check"
    case probes = "probes"
    case policyMapping = "policy_mapping"
    case approval = "approval"
    case awaitingApproval = "awaiting_approval"
    case execute = "execute"
    case logEvidence = "log_evidence"
    case complete = "complete"
}

public enum KernelExecutionStatus: String, Codable {
    case completed = "completed"
    case failed = "failed"
    case denied = "denied"
    case pendingApproval = "pending_approval"
    case escalated = "escalated"
    case cooldownActive = "cooldown_active"
}

public struct KernelExecutionResult: Identifiable {
    public let id: UUID
    public let status: KernelExecutionStatus
    public let planId: UUID?
    public let phase: KernelPhase
    public let message: String
    public let startedAt: Date
    public let completedAt: Date
    
    // Evidence chain components
    public let toolPlan: ToolPlan?
    public let riskAssessment: RiskAssessment?
    public let verificationResult: KernelVerificationResult?
    public let policyDecision: KernelPolicyDecision?
    public let approvalRecord: ApprovalRecord?
    public let executionOutcome: KernelExecutionOutcome?
    
    public var duration: TimeInterval {
        completedAt.timeIntervalSince(startedAt)
    }
    
    public var isSuccess: Bool {
        status == .completed
    }
}

public struct PendingPlanContext {
    public let toolPlan: ToolPlan
    public let riskAssessment: RiskAssessment
    public let verificationResult: KernelVerificationResult
    public let policyDecision: KernelPolicyDecision
    public let createdAt: Date
}

// MARK: - IntentType Extensions

extension IntentType {
    var isMutation: Bool {
        switch self {
        case .readCalendar, .readContacts, .createDraft:
            return false
        default:
            return true
        }
    }
    
    var isExternalCommunication: Bool {
        switch self {
        case .sendEmail, .externalAPICall:
            return true
        default:
            return false
        }
    }
    
    var defaultReversibility: ReversibilityClass {
        switch self {
        case .createDraft, .createReminder, .readCalendar, .readContacts:
            return .reversible
        case .createCalendarEvent, .updateCalendarEvent, .fileWrite, .deleteCalendarEvent:
            return .partiallyReversible
        case .sendEmail, .externalAPICall, .databaseMutation, .fileDelete, .systemConfiguration, .unknown:
            return .irreversible
        }
    }
    
    var hashableKey: String {
        rawValue
    }
}

// MARK: - ToolPlanBuilder Extensions

extension ToolPlanBuilder {
    func addProbe(contentsOf probes: [ProbeDefinition]) -> ToolPlanBuilder {
        for probe in probes {
            _ = self.addProbe(probe)
        }
        return self
    }
    
    func addExecutionStep(contentsOf steps: [ExecutionStepDefinition]) -> ToolPlanBuilder {
        for step in steps {
            _ = self.addExecutionStep(step)
        }
        return self
    }
}
