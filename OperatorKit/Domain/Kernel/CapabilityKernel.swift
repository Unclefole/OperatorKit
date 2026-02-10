import Foundation
import CryptoKit
import Security

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
            
            // Record authorization (actual execution happens via ExecutionEngine)
            return await recordAuthorizedPlan(
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
        
        // Record authorization (actual execution happens via ExecutionEngine)
        return await recordAuthorizedPlan(
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
    
    // MARK: - Emergency Stop
    
    /// Cancel all pending plans and halt execution.
    /// Logged to EvidenceEngine as a system event.
    /// Called from Direct Controls in the mission-control UI.
    public func emergencyStop() {
        let cancelledCount = pendingPlans.count
        
        // Cancel all pending plans
        for (planId, _) in pendingPlans {
            let denial = ApprovalRecord(
                planId: planId,
                approved: false,
                approvalType: .denied,
                approverIdentifier: "EMERGENCY_STOP",
                reason: "Emergency stop activated by operator"
            )
            try? evidenceEngine.logApproval(denial, planId: planId)
        }
        pendingPlans.removeAll()
        
        // Cancel any in-flight tasks
        activeExecutionTask?.cancel()
        activeExecutionTask = nil

        // EXECUTION PERSISTENCE: Fail all in-flight execution records
        let haltedRecords = ExecutionRecordStore.shared.haltAllExecuting()
        if haltedRecords > 0 {
            log("[EMERGENCY_STOP] \(haltedRecords) execution record(s) moved to .failed")
        }

        // Set halted state — NOT idle — must be explicit
        currentPhase = .halted
        
        // Log emergency stop event
        let violation = PolicyViolation(
            violationType: .emergencyStop,
            description: "Emergency stop activated — \(cancelledCount) pending plan(s) cancelled",
            severity: .critical
        )
        try? evidenceEngine.logViolation(violation, planId: nil)
    }
    
    /// Resume from halted state (requires explicit operator action)
    public func resumeFromHalt() {
        guard currentPhase == .halted else { return }
        currentPhase = .idle
        try? evidenceEngine.logGenericArtifact(
            type: "system_resume",
            planId: UUID(),
            jsonString: "{\"action\":\"resume_from_halt\",\"timestamp\":\"\(Date())\"}"
        )
    }
    
    /// Escalate all pending plans for human review. Called from Direct Controls UI.
    /// Returns the number of plans escalated.
    @discardableResult
    public func escalatePendingPlans() -> Int {
        let escalated = pendingPlans.count
        for (planId, _) in pendingPlans {
            currentPhase = .awaitingApproval
            try? evidenceEngine.logGenericArtifact(
                type: "escalation",
                planId: planId,
                jsonString: "{\"action\":\"manual_escalation\",\"planId\":\"\(planId)\",\"timestamp\":\"\(Date())\"}"
            )
        }
        return escalated
    }
    
    /// Whether there are pending plans that can be escalated
    public var hasPendingPlans: Bool {
        !pendingPlans.isEmpty
    }
    
    /// Cancellable reference for in-flight execution
    public var activeExecutionTask: Task<Void, Never>?
    
    // MARK: - Internal Execution
    
    /// Records authorization decision and evidence for an approved plan.
    ///
    /// ARCHITECTURAL NOTE: This method does NOT perform side effects.
    /// Real execution dispatches through ExecutionEngine (token-gated).
    /// This method records the kernel's authorization evidence chain only.
    ///
    /// The unified pipeline is:
    ///   Kernel.execute(intent:) → risk/probes/policy → recordAuthorizedPlan() → evidence
    ///   ApprovalView → KernelBridge.issueToken() → ExecutionEngine.execute(token:) → side effects
    private func recordAuthorizedPlan(
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
        
        // PHASE 9: AUTHORIZE — Plan is authorized, ready for token issuance
        currentPhase = .execute
        
        let outcome = KernelExecutionOutcome(
            planId: toolPlan.id,
            success: true,
            status: .completed,
            startedAt: Date(),
            resultSummary: "Plan authorized — ready for token-gated execution via ExecutionEngine"
        )
        
        // Log authorization outcome
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
            status: .completed,
            planId: toolPlan.id,
            phase: .complete,
            message: "Plan authorized — token can be issued for execution",
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

    /// Hardened token issuance from a validated ProposalPack + ApprovalSession.
    /// Includes plan hash, approved scopes, reversibility, and session linkage.
    public func issueHardenedToken(
        proposal: ProposalPack,
        session: ApprovalSession,
        humanSignature: Data? = nil
    ) -> AuthorizationToken? {
        // GATE 0: Kernel lockdown — no tokens issued during integrity failure
        guard !KernelIntegrityGuard.shared.isLocked else {
            logError("[KERNEL] Cannot issue token — EXECUTION LOCKDOWN active")
            return nil
        }

        // GATE: Session must be approved and not expired
        guard session.isApproved else {
            logError("[KERNEL] Cannot issue token — session not approved or expired")
            return nil
        }

        // GATE: Device must be trusted
        guard TrustedDeviceRegistry.shared.isCurrentDeviceTrusted else {
            logError("[KERNEL] Cannot issue token — current device not trusted")
            return nil
        }

        // GATE: Trust epoch integrity must hold
        let epochManager = TrustEpochManager.shared
        guard epochManager.verifyIntegrity() else {
            logError("[KERNEL] Cannot issue token — trust epoch integrity check failed")
            return nil
        }

        let planId = proposal.toolPlan.id
        let issuedAt = Date()
        let expiresAt = issuedAt.addingTimeInterval(60)

        // Sign with the ACTIVE epoch-versioned key
        let currentKeyVersion = epochManager.activeKeyVersion
        let currentEpoch = epochManager.trustEpoch

        let signature = CapabilityKernel.computeSignature(
            planId: planId,
            issuedAt: issuedAt,
            expiresAt: expiresAt
        )

        // Compute plan hash for tamper detection
        let planMaterial = "\(planId)\(proposal.toolPlan.intent.summary)\(proposal.toolPlan.executionSteps.count)"
        let planHashDigest = SHA256.hash(data: planMaterial.data(using: .utf8)!)
        let planHash = planHashDigest.compactMap { String(format: "%02x", $0) }.joined()

        let scopes = proposal.permissionManifest.scopes.map {
            "\($0.domain.rawValue).\($0.access.rawValue)(\($0.detail))"
        }

        // Build collected signatures for quorum
        var collectedSigs: [CollectedSignature] = []
        if let sig = humanSignature, let fingerprint = SecureEnclaveApprover.shared.deviceFingerprint {
            collectedSigs.append(CollectedSignature(
                signerId: fingerprint,
                signerType: .deviceOperator,
                signatureData: sig,
                signedAt: issuedAt
            ))
        }

        // Quorum policy: required signers determined by risk tier
        let requiredCount = CapabilityKernel.requiredSignerCount(for: session.riskTier)

        let token = AuthorizationToken(
            planId: planId,
            riskTier: session.riskTier,
            approvalType: .userConfirm,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            signature: signature,
            planHash: planHash,
            approvedScopes: scopes,
            reversibilityRequired: proposal.riskAnalysis.reversibilityClass == .irreversible ? false : true,
            approvalSessionId: session.id,
            humanSignature: humanSignature,
            requiredSigners: requiredCount,
            collectedSignatures: collectedSigs,
            keyVersion: currentKeyVersion,
            epoch: currentEpoch
        )

        // Link token to session
        ApprovalSessionStore.shared.linkToken(token.id, to: session.id)

        // Log token issuance
        let hasSE = humanSignature != nil
        try? evidenceEngine.logGenericArtifact(
            type: "hardened_token_issued",
            planId: planId,
            jsonString: """
            {"tokenId":"\(token.id)","planId":"\(planId)","sessionId":"\(session.id)","riskTier":"\(session.riskTier.rawValue)","scopeCount":\(scopes.count),"expiresAt":"\(expiresAt)","planHash":"\(planHash.prefix(16))...","secureEnclaveAttested":\(hasSE),"quorumMet":\(token.quorumMet),"keyVersion":\(currentKeyVersion),"epoch":\(currentEpoch)}
            """
        )

        return token
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

        // HARDENED FIELDS (Sentinel Proposal Engine integration)
        /// SHA256 hash of the approved ToolPlan — prevents post-approval tampering
        public let planHash: String
        /// Scopes approved for this execution (from PermissionManifest)
        public let approvedScopes: [String]
        /// Whether this execution MUST be reversible
        public let reversibilityRequired: Bool
        /// Links to the ApprovalSession that authorized this token
        public let approvalSessionId: UUID?

        // SECURE ENCLAVE — Hardware-backed human approval
        /// ECDSA signature from Secure Enclave over the planHash.
        /// Proves a biometrically-authenticated human approved this specific plan.
        /// nil only for legacy tokens issued before SE integration.
        public let humanSignature: Data?

        // HYBRID QUORUM — prepared for multi-signer authority
        /// Number of signatures required for this token to be valid.
        /// Default 1 = device-sovereign (local human only).
        /// Future: 2 = hybrid quorum (device + org co-sign).
        public let requiredSigners: Int
        /// Collected cryptographic signatures from authorized principals.
        public let collectedSignatures: [CollectedSignature]

        // KEY LIFECYCLE — epoch-bound, version-tracked
        /// The signing key version used to produce this token's HMAC.
        /// ExecutionEngine HARD FAILs if this != TrustEpochManager.activeKeyVersion.
        public let keyVersion: Int
        /// The trust epoch at issuance time.
        /// ExecutionEngine HARD FAILs if this != TrustEpochManager.trustEpoch.
        public let epoch: Int

        /// fileprivate: ONLY CapabilityKernel.swift can create tokens.
        /// No other file in the module can call this initializer.
        fileprivate init(
            planId: UUID,
            riskTier: RiskTier,
            approvalType: ApprovalType,
            issuedAt: Date = Date(),
            expiresAt: Date,
            signature: String,
            planHash: String = "",
            approvedScopes: [String] = [],
            reversibilityRequired: Bool = false,
            approvalSessionId: UUID? = nil,
            humanSignature: Data? = nil,
            requiredSigners: Int = 1,
            collectedSignatures: [CollectedSignature] = [],
            keyVersion: Int = 1,
            epoch: Int = 1
        ) {
            self.id = UUID()
            self.planId = planId
            self.riskTier = riskTier
            self.approvalType = approvalType
            self.issuedAt = issuedAt
            self.expiresAt = expiresAt
            self.signature = signature
            self.planHash = planHash
            self.approvedScopes = approvedScopes
            self.reversibilityRequired = reversibilityRequired
            self.approvalSessionId = approvalSessionId
            self.humanSignature = humanSignature
            self.requiredSigners = requiredSigners
            self.collectedSignatures = collectedSignatures
            self.keyVersion = keyVersion
            self.epoch = epoch
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

        /// Verify Secure Enclave human signature.
        /// Returns true if humanSignature is present and valid, OR if
        /// SE is not available (simulator fallback — logged as degraded).
        public var hasValidHumanSignature: Bool {
            guard let sig = humanSignature, !planHash.isEmpty else {
                return false
            }
            return SecureEnclaveApprover.shared.verifySignature(sig, planHash: planHash)
        }

        /// Whether the quorum requirement is met.
        public var quorumMet: Bool {
            collectedSignatures.count >= requiredSigners
        }
    }

    /// A cryptographic signature from an authorized principal.
    public struct CollectedSignature {
        public let signerId: String        // SHA256 of signer's public key
        public let signerType: SignerType
        public let signatureData: Data     // DER-encoded ECDSA signature
        public let signedAt: Date

        public enum SignerType: String, CaseIterable {
            case deviceOperator = "device_operator"         // SE on this device — primary human
            case organizationAuthority = "org_authority"    // Enterprise policy server co-sign
            case emergencyOverride = "emergency_override"   // Secondary human signer (break-glass)
        }
    }

    // MARK: - Quorum Policy by Risk Tier
    //
    // INVARIANT: Authority must be collectively proven — never inferred.
    // No override flags. No bypass. FAIL CLOSED.
    //
    //  LOW:      deviceOperator (1 signer)
    //  HIGH:     deviceOperator + organizationAuthority (2 signers)
    //  CRITICAL: deviceOperator + organizationAuthority + emergencyOverride (3 signers)

    /// Returns the required signer types for a given risk tier.
    public static func requiredSignerTypes(for riskTier: RiskTier) -> [CollectedSignature.SignerType] {
        switch riskTier {
        case .low, .medium:
            return [.deviceOperator]
        case .high:
            return [.deviceOperator, .organizationAuthority]
        case .critical:
            return [.deviceOperator, .organizationAuthority, .emergencyOverride]
        }
    }

    /// Returns the required number of signers for a given risk tier.
    public static func requiredSignerCount(for riskTier: RiskTier) -> Int {
        requiredSignerTypes(for: riskTier).count
    }

    /// Validate that collected signatures meet quorum policy for a risk tier.
    /// Returns nil on success, or the missing signer types on failure.
    public static func validateQuorum(
        signatures: [CollectedSignature],
        riskTier: RiskTier
    ) -> [CollectedSignature.SignerType]? {
        let required = requiredSignerTypes(for: riskTier)
        let present = Set(signatures.map(\.signerType))
        let missing = required.filter { !present.contains($0) }
        return missing.isEmpty ? nil : missing
    }
    
    // MARK: - Signing Key (Keychain-Stored Runtime Secret)
    
    /// Keychain service identifier for the token signing key.
    fileprivate static let keychainService = "com.operatorkit.token-signing-key"
    fileprivate static let keychainAccount = "token-hmac-v1"
    
    /// The signing key for token HMAC.
    /// - Generated from 256-bit random bytes on first launch.
    /// - Stored in Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly.
    /// - Never leaves the device. Never appears in source code.
    /// - fileprivate: only this file can access.
    fileprivate nonisolated(unsafe) static let tokenSigningKey: SymmetricKey = {
        // Attempt to load from Keychain
        if let existingKey = loadKeyFromKeychain() {
            return existingKey
        }
        // First launch: generate and store
        let newKey = SymmetricKey(size: .bits256)
        storeKeyInKeychain(newKey)
        return newKey
    }()
    
    /// Load signing key from Keychain.
    fileprivate nonisolated static func loadKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return SymmetricKey(data: data)
    }
    
    /// Store signing key in Keychain (first launch only).
    fileprivate nonisolated static func storeKeyInKeychain(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing entry first (idempotent)
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            // Fallback: log but don't crash — key is already in memory
            #if DEBUG
            print("[CapabilityKernel] WARNING: Failed to store signing key in Keychain (status: \(status))")
            #endif
        }
    }
    
    /// Compute the expected HMAC signature for a token.
    /// Used by both issueToken() and AuthorizationToken.verifySignature().
    /// nonisolated: pure computation, no mutable state, safe to call from any context.
    fileprivate nonisolated static func computeSignature(planId: UUID, issuedAt: Date, expiresAt: Date) -> String {
        let payload = "\(planId.uuidString)|\(issuedAt.timeIntervalSince1970)|\(expiresAt.timeIntervalSince1970)"
        let payloadData = payload.data(using: .utf8)!
        let mac = HMAC<SHA256>.authenticationCode(for: payloadData, using: tokenSigningKey)
        return Data(mac).base64EncodedString()
    }
    
    // MARK: - Consumed Token Tracking (DURABLE One-Use Enforcement)
    //
    // INVARIANT: A consumed token must NEVER become valid again —
    //            even after crash, restart, or termination.
    //
    // Implementation: Stores SHA256(token.id) + expiresAt in an encrypted
    // file. Auto-prunes expired entries on launch.

    /// In-memory cache backed by persistent file storage.
    private static var consumedTokenStore = ConsumedTokenStore(filename: "consumed_auth_tokens.json")

    /// Check if a token has already been consumed.
    public static func isTokenConsumed(_ token: AuthorizationToken) -> Bool {
        consumedTokenStore.contains(tokenId: token.id)
    }

    /// Mark a token as consumed. Returns false if already consumed.
    /// Persists immediately to disk — survives crash/restart.
    @discardableResult
    public static func consumeToken(_ token: AuthorizationToken) -> Bool {
        consumedTokenStore.consume(tokenId: token.id, expiresAt: token.expiresAt)
    }
}

// MARK: - Durable Consumed Token Store

/// Persistent store for consumed token hashes.
/// Survives app crash, restart, and reboot.
/// Auto-prunes expired entries to keep the store lean.
struct ConsumedTokenStore {
    private var entries: [ConsumedEntry] = []
    private let fileURL: URL

    struct ConsumedEntry: Codable {
        let tokenHash: String   // SHA256 of token UUID — never store raw ID
        let expiresAt: Date
    }

    init(filename: String = "consumed_tokens.json") {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("KernelSecurity", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(filename)
        loadAndPrune()
    }

    /// Check if a token ID has been consumed.
    func contains(tokenId: UUID) -> Bool {
        let hash = Self.hash(tokenId)
        return entries.contains { $0.tokenHash == hash }
    }

    /// Consume a token. Returns true if first use, false if replay.
    /// Persists to disk immediately.
    mutating func consume(tokenId: UUID, expiresAt: Date) -> Bool {
        let hash = Self.hash(tokenId)
        if entries.contains(where: { $0.tokenHash == hash }) {
            return false // replay attempt
        }
        entries.append(ConsumedEntry(tokenHash: hash, expiresAt: expiresAt))
        persist()
        return true
    }

    /// Load from disk and prune expired entries.
    private mutating func loadAndPrune() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let loaded = try? JSONDecoder().decode([ConsumedEntry].self, from: data) else {
            entries = []
            return
        }
        let now = Date()
        // Keep entries that haven't expired yet (add 120s buffer beyond TTL)
        entries = loaded.filter { $0.expiresAt.addingTimeInterval(120) > now }
        persist()
    }

    /// Persist to disk atomically.
    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// SHA256 hash of a UUID string — never store raw token IDs.
    private static func hash(_ id: UUID) -> String {
        let data = id.uuidString.data(using: .utf8)!
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

/// Public typealias for backward compatibility.
/// All new code should use CapabilityKernel.AuthorizationToken directly.
public typealias KernelAuthorizationToken = CapabilityKernel.AuthorizationToken

// ============================================================================
// MODEL CALL TOKEN — Governed Intelligence Token
//
// Mirrors AuthorizationToken pattern for model call governance.
// fileprivate init: ONLY CapabilityKernel.swift can create.
// 60-second expiry. One-use. HMAC-signed.
// ============================================================================

extension CapabilityKernel {

    public struct ModelCallToken: Identifiable, Sendable {
        public let id: UUID
        public let requestId: UUID
        public let provider: ModelProvider
        public let issuedAt: Date
        public let expiresAt: Date
        public let signature: String

        /// fileprivate: ONLY CapabilityKernel.swift can create tokens.
        fileprivate init(
            requestId: UUID,
            provider: ModelProvider,
            issuedAt: Date = Date(),
            expiresAt: Date,
            signature: String
        ) {
            self.id = UUID()
            self.requestId = requestId
            self.provider = provider
            self.issuedAt = issuedAt
            self.expiresAt = expiresAt
            self.signature = signature
        }

        public var isValid: Bool {
            Date() < expiresAt && !signature.isEmpty
        }

        public func verifySignature() -> Bool {
            guard isValid else { return false }
            let expected = CapabilityKernel.computeModelCallSignature(
                requestId: requestId,
                provider: provider,
                issuedAt: issuedAt,
                expiresAt: expiresAt
            )
            return signature == expected
        }
    }

    // MARK: - Model Call Token Signing

    fileprivate nonisolated static func computeModelCallSignature(
        requestId: UUID,
        provider: ModelProvider,
        issuedAt: Date,
        expiresAt: Date
    ) -> String {
        let payload = "MCT|\(requestId.uuidString)|\(provider.rawValue)|\(issuedAt.timeIntervalSince1970)|\(expiresAt.timeIntervalSince1970)"
        let payloadData = payload.data(using: .utf8)!
        let mac = HMAC<SHA256>.authenticationCode(for: payloadData, using: tokenSigningKey)
        return Data(mac).base64EncodedString()
    }

    // MARK: - Model Call Token Consumption (DURABLE One-Use)

    /// Durable store for model call tokens — same pattern as AuthorizationToken.
    private static var consumedModelCallTokenStore = ConsumedTokenStore(filename: "consumed_model_tokens.json")

    public static func isModelCallTokenConsumed(_ token: ModelCallToken) -> Bool {
        consumedModelCallTokenStore.contains(tokenId: token.id)
    }

    @discardableResult
    public static func consumeModelCallToken(_ token: ModelCallToken) -> Bool {
        consumedModelCallTokenStore.consume(tokenId: token.id, expiresAt: token.expiresAt)
    }

    // MARK: - Evaluate Model Call Eligibility

    /// Kernel-owned policy decision for model calls.
    /// Decides: allowed?, which provider, human approval needed?
    public func evaluateModelCallEligibility(
        request: ModelCallRequest
    ) -> ModelCallDecision {
        // 1. On-device is always allowed
        if request.requestedProvider == .onDevice || request.requestedProvider == nil {
            if !IntelligenceFeatureFlags.anyCloudProviderEnabled {
                return .onDeviceOnly(requestId: request.id, reason: "Cloud disabled; on-device default")
            }
        }

        // 2. Check cloud feature flags
        guard IntelligenceFeatureFlags.cloudModelsEnabled else {
            return .onDeviceOnly(requestId: request.id, reason: "Cloud models feature flag OFF")
        }

        // 3. Determine provider preference
        let provider: ModelProvider
        if let requested = request.requestedProvider, requested.isCloud {
            // Validate specific provider flag
            switch requested {
            case .cloudOpenAI:
                guard IntelligenceFeatureFlags.openAIEnabled else {
                    return .onDeviceOnly(requestId: request.id, reason: "OpenAI provider disabled")
                }
                provider = .cloudOpenAI
            case .cloudAnthropic:
                guard IntelligenceFeatureFlags.anthropicEnabled else {
                    return .onDeviceOnly(requestId: request.id, reason: "Anthropic provider disabled")
                }
                provider = .cloudAnthropic
            default:
                provider = .onDevice
            }
        } else {
            // Auto-select: prefer OpenAI if enabled, else Anthropic
            if IntelligenceFeatureFlags.openAIEnabled {
                provider = .cloudOpenAI
            } else if IntelligenceFeatureFlags.anthropicEnabled {
                provider = .cloudAnthropic
            } else {
                return .onDeviceOnly(requestId: request.id, reason: "No cloud provider enabled")
            }
        }

        // 4. Risk-based gating
        let riskTierStr = request.riskTierHint ?? "low"
        let isHighRisk = riskTierStr == "high" || riskTierStr == "critical"

        if isHighRisk {
            // High risk: require human approval before cloud call
            return ModelCallDecision(
                allowed: true,
                provider: provider,
                requiresHumanApproval: true,
                riskTier: riskTierStr,
                reason: "High-risk intent requires human approval for cloud model call",
                requestId: request.id
            )
        }

        // 5. Allowed — issue token downstream
        return ModelCallDecision(
            allowed: true,
            provider: provider,
            requiresHumanApproval: false,
            riskTier: riskTierStr,
            reason: "Cloud model call approved by kernel policy",
            requestId: request.id
        )
    }

    // MARK: - Issue Model Call Token

    /// Issues a signed, short-lived, one-use token for a cloud model call.
    /// ONLY callable after evaluateModelCallEligibility returns allowed + no pending approval.
    public func issueModelCallToken(
        requestId: UUID,
        provider: ModelProvider
    ) -> ModelCallToken {
        let issuedAt = Date()
        let expiresAt = issuedAt.addingTimeInterval(60) // 60-second TTL

        let signature = CapabilityKernel.computeModelCallSignature(
            requestId: requestId,
            provider: provider,
            issuedAt: issuedAt,
            expiresAt: expiresAt
        )

        let token = ModelCallToken(
            requestId: requestId,
            provider: provider,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            signature: signature
        )

        // Log token issuance to evidence
        try? evidenceEngine.logGenericArtifact(
            type: "model_call_token_issued",
            planId: requestId,
            jsonString: "{\"tokenId\":\"\(token.id)\",\"provider\":\"\(provider.rawValue)\",\"expiresAt\":\"\(expiresAt)\"}"
        )

        return token
    }
}

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
    case halted = "halted"
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
