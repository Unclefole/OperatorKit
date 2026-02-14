import Foundation

// ============================================================================
// SENTINEL PROPOSAL ENGINE — AUTONOMOUS REASONING, ZERO EXECUTION
//
// Sentinel watches, reasons, prepares, and warns.
// Sentinel NEVER pulls the trigger.
//
// ARCHITECTURAL LAW:
//   Sentinel proposes. Humans authorize. OperatorKit executes.
//
// MODULE BOUNDARY (COMPILER-ENFORCED):
//   ❌ CANNOT import ExecutionEngine
//   ❌ CANNOT call write-capable Services
//   ❌ CANNOT access ServiceAccessToken
//   ❌ CANNOT mint ExecutionTokens
//   ❌ CANNOT dispatch side effects
//
// WHAT SENTINEL MAY DO:
//   ✅ Think — classify intents, assess risk
//   ✅ Plan — generate ToolPlans with execution steps
//   ✅ Simulate — estimate consequences without executing
//   ✅ Estimate cost — predict token usage and cost
//   ✅ Request permissions — declare required scopes
//
// INPUT:  Intent + Context
// OUTPUT: ProposalPack (read-only structured artifact)
// ============================================================================

@MainActor
public final class SentinelProposalEngine: ObservableObject {

    public static let shared = SentinelProposalEngine()

    // Read-only dependencies — NONE are write-capable
    // Use shared singletons (no direct instantiation — inits are private)
    private var riskEngine: RiskEngine { RiskEngine.shared }
    private var verificationEngine: VerificationEngine { VerificationEngine.shared }
    private var policyEngine: PolicyEngine { PolicyEngine.shared }

    @Published public private(set) var lastProposal: ProposalPack?
    @Published public private(set) var isGenerating: Bool = false

    private init() {}

    // MARK: - Generate Proposal

    /// Generate a ProposalPack from intent and context.
    /// This is the PRIMARY entry point for the Sentinel system.
    ///
    /// INVARIANT: This method NEVER executes side effects.
    /// INVARIANT: Output is a read-only ProposalPack.
    func generateProposal(
        intent: IntentRequest,
        context: ContextPacket?,
        source: ProposalSource = .user
    ) async -> ProposalPack {
        isGenerating = true
        defer { isGenerating = false }

        log("[SENTINEL] Generating proposal for intent: \(intent.intentType.rawValue)")

        // STEP 1: Classify intent
        let classification = classifyIntent(intent)

        // STEP 2: Build risk context + assess
        let riskContext = buildRiskContext(intent: intent, classification: classification)
        let riskAssessment = riskEngine.assess(context: riskContext)

        // STEP 3: Reversibility analysis
        let reversibility = verificationEngine.classifyReversibility(
            for: classification.toolPlanIntentType,
            context: ReversibilityContext()
        )

        // STEP 4: Build ToolPlan (describes — never executes)
        let toolPlan = buildToolPlan(
            intent: intent,
            classification: classification,
            riskAssessment: riskAssessment,
            reversibility: reversibility
        )

        // STEP 5: Permission manifest
        let permissionManifest = buildPermissionManifest(for: classification)

        // STEP 6: Risk + consequence analysis
        let riskAnalysis = RiskConsequenceAnalysis(
            riskScore: riskAssessment.score,
            consequenceTier: riskAssessment.tier,
            reversibilityClass: reversibility.reversibilityClass,
            blastRadius: estimateBlastRadius(for: classification),
            reasons: riskAssessment.reasons.map { $0.description }
        )

        // STEP 7: Cost estimate
        let costEstimate = estimateCost(for: classification, context: context)

        // STEP 8: Evidence citations (redacted via DataDiode)
        let citations = buildEvidenceCitations(from: context)

        // STEP 9: Human summary
        let summary = buildHumanSummary(
            intent: intent,
            classification: classification,
            riskTier: riskAssessment.tier
        )

        let proposal = ProposalPack(
            source: source,
            toolPlan: toolPlan,
            permissionManifest: permissionManifest,
            riskAnalysis: riskAnalysis,
            costEstimate: costEstimate,
            evidenceCitations: citations,
            humanSummary: summary
        )

        lastProposal = proposal

        // Log to evidence
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "sentinel_proposal",
            planId: proposal.id,
            jsonString: """
            {"proposalId":"\(proposal.id)","source":"\(source.rawValue)","intentType":"\(intent.intentType.rawValue)","riskScore":\(riskAnalysis.riskScore),"riskTier":"\(riskAnalysis.consequenceTier.rawValue)","costUSD":\(costEstimate.estimatedCostUSD),"requiresCloud":\(costEstimate.requiresCloudCall),"scopeCount":\(permissionManifest.scopes.count)}
            """
        )

        log("[SENTINEL] Proposal \(proposal.id) generated — risk: \(riskAnalysis.consequenceTier.rawValue), cost: $\(String(format: "%.4f", costEstimate.estimatedCostUSD))")
        return proposal
    }

    // MARK: - Intent Classification

    private struct IntentClassification {
        let intentRequestType: IntentRequest.IntentType
        let toolPlanIntentType: IntentType       // ToolPlan's IntentType
        let expectedSideEffects: [SideEffect.SideEffectType]
        let requiresNetwork: Bool
        let requiresCloudModel: Bool
    }

    private func classifyIntent(_ intent: IntentRequest) -> IntentClassification {
        switch intent.intentType {
        case .draftEmail:
            return IntentClassification(
                intentRequestType: .draftEmail,
                toolPlanIntentType: .sendEmail,
                expectedSideEffects: [.presentEmailDraft, .saveDraft],
                requiresNetwork: false,
                requiresCloudModel: IntelligenceFeatureFlags.cloudModelsEnabled
            )
        case .createReminder:
            return IntentClassification(
                intentRequestType: .createReminder,
                toolPlanIntentType: .createReminder,
                expectedSideEffects: [.createReminder],
                requiresNetwork: false,
                requiresCloudModel: false
            )
        case .summarizeMeeting:
            return IntentClassification(
                intentRequestType: .summarizeMeeting,
                toolPlanIntentType: .createDraft,
                expectedSideEffects: [.saveToMemory],
                requiresNetwork: false,
                requiresCloudModel: IntelligenceFeatureFlags.cloudModelsEnabled
            )
        case .reviewDocument:
            return IntentClassification(
                intentRequestType: .reviewDocument,
                toolPlanIntentType: .createDraft,
                expectedSideEffects: [.saveToMemory],
                requiresNetwork: false,
                requiresCloudModel: IntelligenceFeatureFlags.cloudModelsEnabled
            )
        case .extractActionItems:
            return IntentClassification(
                intentRequestType: .extractActionItems,
                toolPlanIntentType: .createDraft,
                expectedSideEffects: [.saveToMemory],
                requiresNetwork: false,
                requiresCloudModel: false
            )
        case .researchBrief:
            return IntentClassification(
                intentRequestType: .researchBrief,
                toolPlanIntentType: .createDraft,
                expectedSideEffects: [.saveDraft, .saveToMemory],
                requiresNetwork: false,  // Uses model's training data, not live web
                requiresCloudModel: true // Research briefs require cloud quality
            )
        case .unknown:
            return IntentClassification(
                intentRequestType: .unknown,
                toolPlanIntentType: .unknown,
                expectedSideEffects: [.saveDraft],
                requiresNetwork: false,
                requiresCloudModel: false
            )
        }
    }

    // MARK: - Risk Context

    private func buildRiskContext(intent: IntentRequest, classification: IntentClassification) -> RiskContext {
        let sendsExternal = classification.expectedSideEffects.contains(.sendEmail) ||
                            classification.expectedSideEffects.contains(.presentEmailDraft)

        return RiskContext(
            sendsExternalCommunication: sendsExternal,
            externalRecipientCount: sendsExternal ? 1 : 0,
            involvesThirdPartyAPI: classification.requiresNetwork,
            writeToDatabase: classification.expectedSideEffects.contains(.saveToMemory),
            reversibility: classification.expectedSideEffects.contains(.sendEmail) ? .irreversible : .reversible,
            affectedEntityCount: classification.expectedSideEffects.count
        )
    }

    // MARK: - ToolPlan Builder

    private func buildToolPlan(
        intent: IntentRequest,
        classification: IntentClassification,
        riskAssessment: RiskAssessment,
        reversibility: ReversibilityAssessment
    ) -> ToolPlan {
        let steps: [ExecutionStepDefinition] = classification.expectedSideEffects.enumerated().map { index, effectType in
            ExecutionStepDefinition(
                order: index + 1,
                action: effectType.rawValue,
                description: describeStep(effectType),
                isMutation: effectType.requiresTwoKeyConfirmation
            )
        }

        let approvalReq = ApprovalRequirement(
            approvalsNeeded: riskAssessment.tier == .critical ? 2 : 1,
            requiresBiometric: riskAssessment.tier == .high || riskAssessment.tier == .critical,
            cooldownSeconds: riskAssessment.tier == .critical ? 30 : 0,
            requiresPreview: true
        )

        return ToolPlan(
            intent: ToolPlanIntent(
                type: classification.toolPlanIntentType,
                summary: intent.rawText,
                targetDescription: describeTarget(for: classification)
            ),
            originatingAction: "sentinel_proposal",
            riskScore: riskAssessment.score,
            riskTier: riskAssessment.tier,
            riskReasons: riskAssessment.reasons.map { $0.description },
            reversibility: reversibility.reversibilityClass,
            reversibilityReason: reversibility.reason,
            requiredApprovals: approvalReq,
            probes: [],
            executionSteps: steps
        )
    }

    // MARK: - Permission Manifest

    private func buildPermissionManifest(for classification: IntentClassification) -> PermissionManifest {
        var scopes: [PermissionScope] = []

        for effect in classification.expectedSideEffects {
            switch effect {
            case .sendEmail, .presentEmailDraft:
                scopes.append(PermissionScope(domain: .mail, access: .compose, detail: "draft_only"))
            case .createReminder, .previewReminder:
                scopes.append(PermissionScope(domain: .reminders, access: .write, detail: "reminder_create"))
            case .createCalendarEvent, .updateCalendarEvent, .previewCalendarEvent:
                scopes.append(PermissionScope(domain: .calendar, access: .write, detail: "event_create"))
            case .saveDraft, .saveToMemory:
                scopes.append(PermissionScope(domain: .memory, access: .write, detail: "save_draft"))
            }
        }

        if classification.requiresNetwork {
            scopes.append(PermissionScope(domain: .network, access: .read, detail: "cloud_model_call"))
        }

        return PermissionManifest(scopes: scopes)
    }

    // MARK: - Blast Radius

    private func estimateBlastRadius(for classification: IntentClassification) -> BlastRadius {
        if classification.expectedSideEffects.contains(.sendEmail) ||
           classification.expectedSideEffects.contains(.presentEmailDraft) {
            return .singleRecipient
        }
        if classification.expectedSideEffects.contains(.createCalendarEvent) ||
           classification.expectedSideEffects.contains(.updateCalendarEvent) {
            return .singleRecipient
        }
        return .selfOnly
    }

    // MARK: - Cost Estimation

    private func estimateCost(for classification: IntentClassification, context: ContextPacket?) -> CostEstimate {
        guard classification.requiresCloudModel else {
            return .onDevice
        }

        // Estimate based on context size
        let contextChars = context?.allContextItems.reduce(0) { $0 + ($1.displayText.count) } ?? 500
        let estimatedInputTokens = max(200, contextChars / 4) // rough chars-to-tokens
        let estimatedOutputTokens = min(estimatedInputTokens, 1000)

        // GPT-4 class pricing: ~$0.03/1K input, ~$0.06/1K output
        let inputCost = Double(estimatedInputTokens) / 1000.0 * 0.03
        let outputCost = Double(estimatedOutputTokens) / 1000.0 * 0.06
        let totalCost = inputCost + outputCost

        return CostEstimate(
            predictedInputTokens: estimatedInputTokens,
            predictedOutputTokens: estimatedOutputTokens,
            estimatedCostUSD: totalCost,
            confidenceBand: contextChars > 100 ? .medium : .low,
            modelProvider: IntelligenceFeatureFlags.openAIEnabled ? "openai" : "anthropic",
            requiresCloudCall: true
        )
    }

    // MARK: - Evidence Citations

    private func buildEvidenceCitations(from context: ContextPacket?) -> [EvidenceCitation] {
        guard let context = context else { return [] }
        var citations: [EvidenceCitation] = []

        for item in context.allContextItems {
            let sourceType: CitationSourceType
            switch item {
            case is CalendarContextItem: sourceType = .calendarEvent
            case is EmailContextItem:    sourceType = .email
            case is FileContextItem:     sourceType = .document
            default:                     sourceType = .memoryItem
            }

            citations.append(EvidenceCitation(
                sourceType: sourceType,
                reference: item.id.uuidString,
                redactedSummary: DataDiode.redact(item.displayText)
            ))
        }

        return citations
    }

    // MARK: - Helpers

    private func describeStep(_ effect: SideEffect.SideEffectType) -> String {
        switch effect {
        case .sendEmail:            return "Send email to recipient"
        case .presentEmailDraft:    return "Open email composer with draft"
        case .saveDraft:            return "Save draft to local memory"
        case .createReminder:       return "Create reminder in Reminders app"
        case .previewReminder:      return "Preview reminder (no write)"
        case .createCalendarEvent:  return "Create calendar event"
        case .updateCalendarEvent:  return "Update existing calendar event"
        case .previewCalendarEvent: return "Preview calendar event (no write)"
        case .saveToMemory:         return "Save result to local memory"
        }
    }

    private func describeTarget(for classification: IntentClassification) -> String {
        switch classification.toolPlanIntentType {
        case .sendEmail:            return "Email recipient"
        case .createReminder:       return "Reminders app"
        case .createDraft:          return "OperatorKit workspace"
        case .createCalendarEvent:  return "Calendar"
        default:                    return "OperatorKit workspace"
        }
    }

    private func buildHumanSummary(
        intent: IntentRequest,
        classification: IntentClassification,
        riskTier: RiskTier
    ) -> String {
        let actionCount = classification.expectedSideEffects.count
        let risk = riskTier.rawValue
        return "Proposal: \(intent.rawText.prefix(80)) — \(actionCount) action(s), \(risk) risk"
    }

    // MARK: - Convenience (for Autopilot)

    /// Generate a ProposalPack from raw text and an intent type.
    /// Used by AutopilotOrchestrator as a convenience wrapper.
    /// INVARIANT: No side effects. Same guarantees as the primary method.
    func generateProposal(
        rawText: String,
        intentType: IntentRequest.IntentType
    ) async -> ProposalPack {
        let intent = IntentRequest(
            rawText: rawText,
            intentType: intentType
        )
        return await generateProposal(intent: intent, context: nil, source: .user)
    }
}
