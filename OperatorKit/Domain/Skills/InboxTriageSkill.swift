import Foundation

// ============================================================================
// INBOX TRIAGE SKILL — FLAGSHIP MICRO-OPERATOR
//
// Purpose: Prepare decisions from inbound communication.
//
// INVARIANT: Produces ProposalPacks ONLY. Zero execution.
// INVARIANT: MUST NOT reference ExecutionEngine, ServiceAccessToken,
//            CalendarService, ReminderService, MailComposerService.
// INVARIANT: MUST NOT mint tokens or call CapabilityKernel.issueToken.
// ============================================================================

@MainActor
public final class InboxTriageSkill: OperatorSkill {

    public let skillId = "inbox_triage"
    public let displayName = "Inbox Triage"
    public let riskTier: RiskTier = .medium
    public let allowedScopes: [PermissionDomain] = [.mail, .files]
    public let requiredSigners: Int = 1
    public let producesProposalPack: Bool = true
    public let executionOptional: Bool = false

    public init() {}

    // MARK: - Observe

    public func observe(input: SkillInput) async -> SkillObservation {
        let text = input.textContent.lowercased()
        var signals: [Signal] = []
        var excerpts: [String] = []

        // Pricing signals
        let pricingKeywords = ["price increase", "pricing change", "rate increase", "cost increase",
                               "new pricing", "revised pricing", "price adjustment", "fee increase"]
        for kw in pricingKeywords {
            if let range = text.range(of: kw) {
                let context = extractContext(from: input.textContent, around: range)
                signals.append(Signal(label: "Pricing change detected", confidence: 0.85,
                                      category: .pricing, excerpt: context))
                excerpts.append(context)
            }
        }

        // Contract signals
        let contractKeywords = ["contract", "agreement", "terms and conditions", "renewal",
                                "termination clause", "amendment", "NDA", "MSA"]
        for kw in contractKeywords {
            if let range = text.range(of: kw.lowercased()) {
                let context = extractContext(from: input.textContent, around: range)
                signals.append(Signal(label: "Contract reference", confidence: 0.80,
                                      category: .contract, excerpt: context))
                excerpts.append(context)
            }
        }

        // Escalation signals
        let escalationKeywords = ["urgent", "escalate", "immediate attention", "critical",
                                  "ASAP", "deadline missed", "overdue", "blocking"]
        for kw in escalationKeywords {
            if let range = text.range(of: kw.lowercased()) {
                let context = extractContext(from: input.textContent, around: range)
                signals.append(Signal(label: "Escalation detected", confidence: 0.90,
                                      category: .escalation, excerpt: context))
                excerpts.append(context)
            }
        }

        // Refund signals
        let refundKeywords = ["refund", "credit", "chargeback", "reimbursement", "money back"]
        for kw in refundKeywords {
            if let range = text.range(of: kw.lowercased()) {
                let context = extractContext(from: input.textContent, around: range)
                signals.append(Signal(label: "Refund/credit request", confidence: 0.88,
                                      category: .refund, excerpt: context))
                excerpts.append(context)
            }
        }

        // Vendor request signals
        let vendorKeywords = ["vendor", "supplier", "procurement", "purchase order", "invoice"]
        for kw in vendorKeywords {
            if let range = text.range(of: kw.lowercased()) {
                let context = extractContext(from: input.textContent, around: range)
                signals.append(Signal(label: "Vendor interaction", confidence: 0.75,
                                      category: .financial, excerpt: context))
                excerpts.append(context)
            }
        }

        // Timeline risk signals
        let timelineKeywords = ["deadline", "due date", "by end of", "before EOD",
                                "time-sensitive", "expires", "expiring"]
        for kw in timelineKeywords {
            if let range = text.range(of: kw.lowercased()) {
                let context = extractContext(from: input.textContent, around: range)
                signals.append(Signal(label: "Timeline risk", confidence: 0.82,
                                      category: .timeline, excerpt: context))
                excerpts.append(context)
            }
        }

        // Legal signals
        let legalKeywords = ["legal", "liability", "compliance", "regulation", "penalty",
                             "attorney", "lawsuit", "indemnity"]
        for kw in legalKeywords {
            if let range = text.range(of: kw.lowercased()) {
                let context = extractContext(from: input.textContent, around: range)
                signals.append(Signal(label: "Legal implication", confidence: 0.85,
                                      category: .legal, excerpt: context))
                excerpts.append(context)
            }
        }

        // Fallback: informational
        if signals.isEmpty {
            signals.append(Signal(label: "Informational message", confidence: 0.60,
                                  category: .informational))
        }

        // De-duplicate
        let unique = Dictionary(grouping: signals, by: { $0.label }).compactMap { $0.value.first }

        return SkillObservation(skillId: skillId, signals: unique, rawExcerpts: excerpts)
    }

    // MARK: - Analyze

    public func analyze(observation: SkillObservation) async -> SkillAnalysis {
        var items: [AnalysisItem] = []
        var overallRisk: RiskTier = .low

        for signal in observation.signals {
            let itemRisk = riskForCategory(signal.category)
            if itemRisk > overallRisk { overallRisk = itemRisk }

            let item = AnalysisItem(
                title: signal.label,
                detail: signal.excerpt ?? "Signal detected in message content",
                riskTier: itemRisk,
                actionRequired: itemRisk != .low,
                suggestedAction: suggestedActionFor(signal.category),
                evidenceExcerpt: signal.excerpt
            )
            items.append(item)
        }

        let summary = buildSummary(items: items, overallRisk: overallRisk)

        return SkillAnalysis(skillId: skillId, riskTier: overallRisk, items: items, summary: summary)
    }

    // MARK: - Generate Proposal

    public func generateProposal(analysis: SkillAnalysis) async -> ProposalPack {
        let steps = analysis.items.enumerated().map { idx, item in
            ExecutionStepDefinition(
                order: idx + 1,
                action: item.suggestedAction ?? "Review and respond",
                description: item.title + ": " + item.detail.prefix(100),
                isMutation: item.actionRequired,
                rollbackAction: item.riskTier == .low ? nil : "Recall draft"
            )
        }

        let scopes = buildPermissionScopes(from: analysis)

        let toolPlan = ToolPlan(
            intent: ToolPlanIntent(
                type: .createDraft,
                summary: analysis.summary,
                targetDescription: "Inbox triage decision"
            ),
            originatingAction: "inbox_triage_skill",
            riskScore: analysis.riskTier.scoreEstimate,
            riskTier: analysis.riskTier,
            riskReasons: analysis.items.map { $0.title },
            reversibility: .reversible,
            reversibilityReason: "Draft only — no sent messages",
            requiredApprovals: ApprovalRequirement(
                approvalsNeeded: requiredSigners,
                requiresBiometric: analysis.riskTier >= .high,
                requiresPreview: true
            ),
            probes: [],
            executionSteps: steps
        )

        let riskAnalysis = RiskConsequenceAnalysis(
            riskScore: analysis.riskTier.scoreEstimate,
            consequenceTier: analysis.riskTier,
            reversibilityClass: .reversible,
            blastRadius: analysis.riskTier >= .high ? .singleRecipient : .selfOnly,
            reasons: analysis.items.map { $0.title }
        )

        let citations = analysis.items.compactMap { item -> EvidenceCitation? in
            guard let excerpt = item.evidenceExcerpt else { return nil }
            return EvidenceCitation(
                sourceType: .email,
                reference: "inbox_signal_\(item.id.uuidString.prefix(8))",
                redactedSummary: String(excerpt.prefix(120))
            )
        }

        return ProposalPack(
            source: .user,
            toolPlan: toolPlan,
            permissionManifest: PermissionManifest(scopes: scopes),
            riskAnalysis: riskAnalysis,
            costEstimate: .onDevice,
            evidenceCitations: citations,
            humanSummary: analysis.summary
        )
    }

    // MARK: - Private Helpers

    private func extractContext(from text: String, around range: Range<String.Index>) -> String {
        let start = text.index(range.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 40, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func riskForCategory(_ cat: SignalCategory) -> RiskTier {
        switch cat {
        case .pricing, .financial:  return .high
        case .contract, .legal:     return .high
        case .escalation:           return .medium
        case .refund:               return .medium
        case .timeline:             return .medium
        case .commitment, .owner:   return .low
        case .deadline:             return .medium
        case .risk:                 return .high
        case .followUp:             return .low
        case .approval:             return .medium
        case .informational:        return .low
        }
    }

    private func suggestedActionFor(_ cat: SignalCategory) -> String {
        switch cat {
        case .pricing:          return "Draft counter-proposal"
        case .contract:         return "Flag for legal review"
        case .escalation:       return "Route to appropriate owner"
        case .refund:           return "Draft refund response"
        case .timeline:         return "Flag deadline risk"
        case .financial:        return "Route to finance"
        case .legal:            return "Route to legal"
        case .commitment:       return "Record commitment"
        case .owner:            return "Assign owner"
        case .deadline:         return "Flag deadline"
        case .risk:             return "Escalate risk"
        case .followUp:         return "Schedule follow-up"
        case .approval:         return "Route for approval"
        case .informational:    return "No action required"
        }
    }

    private func buildSummary(items: [AnalysisItem], overallRisk: RiskTier) -> String {
        let actionCount = items.filter { $0.actionRequired }.count
        let riskLabels = Set(items.filter { $0.riskTier >= .medium }.map { $0.title })
        var summary = "Inbox triage: \(items.count) signals detected, \(actionCount) require action."
        if !riskLabels.isEmpty {
            summary += " Key risks: \(riskLabels.joined(separator: ", "))."
        }
        summary += " Overall risk: \(overallRisk.rawValue)."
        return summary
    }

    private func buildPermissionScopes(from analysis: SkillAnalysis) -> [PermissionScope] {
        var scopes: [PermissionScope] = [
            PermissionScope(domain: .mail, access: .read, detail: "read_inbox")
        ]
        if analysis.items.contains(where: { $0.actionRequired }) {
            scopes.append(PermissionScope(domain: .mail, access: .compose, detail: "draft_reply"))
        }
        return scopes
    }
}

// MARK: - RiskTier Comparable + Score

extension RiskTier: @retroactive Comparable {
    private var order: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .critical: return 3
        }
    }

    public static func < (lhs: RiskTier, rhs: RiskTier) -> Bool {
        lhs.order < rhs.order
    }

    public var scoreEstimate: Int {
        switch self {
        case .low: return 10
        case .medium: return 35
        case .high: return 65
        case .critical: return 90
        }
    }
}
