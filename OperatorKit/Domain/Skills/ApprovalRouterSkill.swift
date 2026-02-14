import Foundation

// ============================================================================
// APPROVAL ROUTER SKILL — CRITICAL INFRASTRUCTURE MICRO-OPERATOR
//
// Purpose: Automatically prepare approval packets by determining required
//          approvers based on risk tier, blast radius, and reversibility.
//          Routes proposals to ApprovalSession pipeline.
//
// INVARIANT: Produces ProposalPacks ONLY. Zero execution.
// INVARIANT: MUST NOT reference ExecutionEngine, ServiceAccessToken,
//            CalendarService, ReminderService, MailComposerService.
// INVARIANT: MUST NOT mint tokens or call CapabilityKernel.issueToken.
// INVARIANT: Routes to existing ApprovalSession pipeline (does not execute).
// ============================================================================

@MainActor
public final class ApprovalRouterSkill: OperatorSkill {

    public let skillId = "approval_router"
    public let displayName = "Approval Router"
    public let riskTier: RiskTier = .medium
    public let allowedScopes: [PermissionDomain] = [.mail, .calendar, .reminders, .files]
    public let requiredSigners: Int = 1
    public let producesProposalPack: Bool = true
    public let executionOptional: Bool = false

    public init() {}

    // MARK: - Observe

    /// The ApprovalRouter observes ProposalPacks from other skills.
    /// Input type should be .proposalPack with the upstream proposal JSON in textContent.
    public func observe(input: SkillInput) async -> SkillObservation {
        var signals: [Signal] = []
        let text = input.textContent.lowercased()

        // Detect risk tier from proposal content
        if text.contains("\"critical\"") || text.contains("risk_score") {
            signals.append(Signal(label: "Proposal contains risk assessment", confidence: 0.95,
                                  category: .approval))
        }

        // Financial signals requiring finance approval
        let financeKeywords = ["pricing", "cost", "budget", "revenue", "spend", "investment",
                               "refund", "credit", "chargeback", "vendor", "invoice"]
        for kw in financeKeywords {
            if text.contains(kw) {
                signals.append(Signal(label: "Financial approval needed", confidence: 0.85,
                                      category: .financial, excerpt: kw))
                break
            }
        }

        // Legal signals
        let legalKeywords = ["contract", "legal", "liability", "compliance", "regulation",
                             "NDA", "agreement", "terms"]
        for kw in legalKeywords {
            if text.contains(kw.lowercased()) {
                signals.append(Signal(label: "Legal review needed", confidence: 0.85,
                                      category: .legal, excerpt: kw))
                break
            }
        }

        // Multi-party blast radius
        if text.contains("multi_recipient") || text.contains("organizational") {
            signals.append(Signal(label: "High blast radius — multi-signer required", confidence: 0.90,
                                  category: .escalation))
        }

        // Irreversible actions
        if text.contains("irreversible") {
            signals.append(Signal(label: "Irreversible action — elevated approval needed", confidence: 0.92,
                                  category: .risk))
        }

        if signals.isEmpty {
            signals.append(Signal(label: "Standard approval routing", confidence: 0.70,
                                  category: .approval))
        }

        return SkillObservation(skillId: skillId, signals: signals)
    }

    // MARK: - Analyze

    public func analyze(observation: SkillObservation) async -> SkillAnalysis {
        var items: [AnalysisItem] = []
        var overallRisk: RiskTier = .low
        var signerCount = 1
        var approverRoles: [String] = ["Device Operator"]

        for signal in observation.signals {
            let itemRisk = riskForSignal(signal)
            if itemRisk > overallRisk { overallRisk = itemRisk }

            switch signal.category {
            case .financial:
                approverRoles.append("Finance")
                signerCount = max(signerCount, 2)
                items.append(AnalysisItem(
                    title: "Finance approval required",
                    detail: "Proposal has financial implications. Finance sign-off needed before execution.",
                    riskTier: .high,
                    actionRequired: true,
                    suggestedAction: "Route to finance approver"
                ))

            case .legal:
                approverRoles.append("Legal")
                signerCount = max(signerCount, 2)
                items.append(AnalysisItem(
                    title: "Legal review required",
                    detail: "Proposal has legal implications. Legal counsel review needed.",
                    riskTier: .high,
                    actionRequired: true,
                    suggestedAction: "Route to legal approver"
                ))

            case .escalation:
                signerCount = max(signerCount, 3)
                approverRoles.append("Organization Authority")
                items.append(AnalysisItem(
                    title: "Multi-signer quorum required",
                    detail: "High blast radius detected. Multiple signers needed for authorization.",
                    riskTier: .critical,
                    actionRequired: true,
                    suggestedAction: "Escalate to quorum approval"
                ))

            case .risk:
                signerCount = max(signerCount, 2)
                items.append(AnalysisItem(
                    title: "Irreversible action — elevated approval",
                    detail: "Action cannot be undone. Elevated approval chain required.",
                    riskTier: .critical,
                    actionRequired: true,
                    suggestedAction: "Require biometric + secondary approval"
                ))

            default:
                items.append(AnalysisItem(
                    title: signal.label,
                    detail: "Standard approval routing applies.",
                    riskTier: .low,
                    actionRequired: true,
                    suggestedAction: "Route to device operator for approval"
                ))
            }
        }

        let uniqueRoles = Array(Set(approverRoles))
        let summary = "Approval routing: \(uniqueRoles.count) approver(s) required " +
            "[\(uniqueRoles.joined(separator: ", "))]. " +
            "Risk: \(overallRisk.rawValue). Signers: \(signerCount)."

        return SkillAnalysis(skillId: skillId, riskTier: overallRisk, items: items, summary: summary)
    }

    // MARK: - Generate Proposal

    public func generateProposal(analysis: SkillAnalysis) async -> ProposalPack {
        let signerCount = computeSignerCount(from: analysis)

        let steps = analysis.items.enumerated().map { idx, item in
            ExecutionStepDefinition(
                order: idx + 1,
                action: item.suggestedAction ?? "Route for approval",
                description: item.title + ": " + item.detail.prefix(100),
                isMutation: false,  // Routing is not mutation
                rollbackAction: nil
            )
        }

        let toolPlan = ToolPlan(
            intent: ToolPlanIntent(
                type: .createDraft,
                summary: analysis.summary,
                targetDescription: "Approval routing decision"
            ),
            originatingAction: "approval_router_skill",
            riskScore: analysis.riskTier.scoreEstimate,
            riskTier: analysis.riskTier,
            riskReasons: analysis.items.map { $0.title },
            reversibility: .reversible,
            reversibilityReason: "Approval routing can be revised before execution",
            requiredApprovals: ApprovalRequirement(
                approvalsNeeded: signerCount,
                requiresBiometric: analysis.riskTier >= .high,
                cooldownSeconds: analysis.riskTier >= .critical ? 30 : 0,
                multiSignerCount: signerCount,
                requiresPreview: true
            ),
            probes: [],
            executionSteps: steps
        )

        let riskAnalysis = RiskConsequenceAnalysis(
            riskScore: analysis.riskTier.scoreEstimate,
            consequenceTier: analysis.riskTier,
            reversibilityClass: .reversible,
            blastRadius: blastRadiusForRisk(analysis.riskTier),
            reasons: analysis.items.map { $0.title }
        )

        return ProposalPack(
            source: .user,
            toolPlan: toolPlan,
            permissionManifest: PermissionManifest(scopes: []),
            riskAnalysis: riskAnalysis,
            costEstimate: .onDevice,
            evidenceCitations: [],
            humanSummary: analysis.summary
        )
    }

    // MARK: - Private Helpers

    private func riskForSignal(_ signal: Signal) -> RiskTier {
        switch signal.category {
        case .financial:    return .high
        case .legal:        return .high
        case .escalation:   return .critical
        case .risk:         return .critical
        case .approval:     return .medium
        default:            return .low
        }
    }

    private func computeSignerCount(from analysis: SkillAnalysis) -> Int {
        // Policy: LOW→1, MEDIUM→1, HIGH→2, CRITICAL→3
        switch analysis.riskTier {
        case .low:      return 1
        case .medium:   return 1
        case .high:     return 2
        case .critical: return 3
        }
    }

    private func blastRadiusForRisk(_ risk: RiskTier) -> BlastRadius {
        switch risk {
        case .low:      return .selfOnly
        case .medium:   return .selfOnly
        case .high:     return .singleRecipient
        case .critical: return .multiRecipient
        }
    }
}
