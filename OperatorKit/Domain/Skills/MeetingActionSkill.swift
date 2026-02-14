import Foundation

// ============================================================================
// MEETING ACTION SKILL — MEETING → ACTION EXTRACTOR
//
// Purpose: Eliminate post-meeting chaos by extracting commitments,
//          owners, deadlines, risks, and follow-ups from transcripts.
//
// INVARIANT: Produces ProposalPacks ONLY. Zero execution.
// INVARIANT: MUST NOT reference ExecutionEngine, ServiceAccessToken,
//            CalendarService, ReminderService, MailComposerService.
// INVARIANT: MUST NOT mint tokens or call CapabilityKernel.issueToken.
// ============================================================================

@MainActor
public final class MeetingActionSkill: OperatorSkill {

    public let skillId = "meeting_actions"
    public let displayName = "Meeting Actions"
    public let riskTier: RiskTier = .low
    public let allowedScopes: [PermissionDomain] = [.calendar, .reminders]
    public let requiredSigners: Int = 1
    public let producesProposalPack: Bool = true
    public let executionOptional: Bool = false

    public init() {}

    // MARK: - Observe

    public func observe(input: SkillInput) async -> SkillObservation {
        let text = input.textContent
        let lower = text.lowercased()
        var signals: [Signal] = []
        var excerpts: [String] = []

        // Commitment patterns
        let commitmentPatterns = [
            "i will", "i'll", "we will", "we'll", "i'm going to",
            "will take care of", "i can handle", "i'll own", "action item",
            "let me", "i'll follow up", "i'll send", "i'll schedule",
            "i'll draft", "i'll prepare", "i'll review"
        ]
        for pattern in commitmentPatterns {
            if let range = lower.range(of: pattern) {
                let ctx = extractContext(from: text, around: range)
                signals.append(Signal(label: "Commitment detected", confidence: 0.82,
                                      category: .commitment, excerpt: ctx))
                excerpts.append(ctx)
            }
        }

        // Owner assignment
        let ownerPatterns = [
            "assigned to", "owner:", "responsible:", "lead:",
            "you'll handle", "can you take", "please own"
        ]
        for pattern in ownerPatterns {
            if let range = lower.range(of: pattern) {
                let ctx = extractContext(from: text, around: range)
                signals.append(Signal(label: "Owner assignment", confidence: 0.85,
                                      category: .owner, excerpt: ctx))
                excerpts.append(ctx)
            }
        }

        // Deadline patterns
        let deadlinePatterns = [
            "by friday", "by monday", "by end of week", "by EOD",
            "due date", "deadline", "before next", "by tomorrow",
            "within 24 hours", "by end of month", "next week",
            "by Q1", "by Q2", "by Q3", "by Q4"
        ]
        for pattern in deadlinePatterns {
            if let range = lower.range(of: pattern) {
                let ctx = extractContext(from: text, around: range)
                signals.append(Signal(label: "Deadline mentioned", confidence: 0.88,
                                      category: .deadline, excerpt: ctx))
                excerpts.append(ctx)
            }
        }

        // Risk / blocker patterns
        let riskPatterns = [
            "risk", "blocker", "blocked", "concern", "issue",
            "problem", "delay", "dependency", "bottleneck",
            "single point of failure", "at risk"
        ]
        for pattern in riskPatterns {
            if let range = lower.range(of: pattern) {
                let ctx = extractContext(from: text, around: range)
                signals.append(Signal(label: "Risk/blocker identified", confidence: 0.78,
                                      category: .risk, excerpt: ctx))
                excerpts.append(ctx)
            }
        }

        // Follow-up patterns
        let followUpPatterns = [
            "follow up", "followup", "follow-up", "circle back",
            "revisit", "check in", "touch base", "reconnect",
            "let's discuss", "schedule a call", "next meeting"
        ]
        for pattern in followUpPatterns {
            if let range = lower.range(of: pattern) {
                let ctx = extractContext(from: text, around: range)
                signals.append(Signal(label: "Follow-up required", confidence: 0.80,
                                      category: .followUp, excerpt: ctx))
                excerpts.append(ctx)
            }
        }

        // Unresolved items (questions / TBDs)
        let unresolvedPatterns = [
            "TBD", "to be determined", "open question", "need to decide",
            "parking lot", "offline discussion", "unresolved"
        ]
        for pattern in unresolvedPatterns {
            if let range = lower.range(of: pattern.lowercased()) {
                let ctx = extractContext(from: text, around: range)
                signals.append(Signal(label: "Unresolved item", confidence: 0.75,
                                      category: .risk, excerpt: ctx))
                excerpts.append(ctx)
            }
        }

        // Financial exposure
        let financialPatterns = [
            "budget", "cost", "spend", "investment", "revenue impact",
            "ROI", "margin", "P&L"
        ]
        for pattern in financialPatterns {
            if let range = lower.range(of: pattern.lowercased()) {
                let ctx = extractContext(from: text, around: range)
                signals.append(Signal(label: "Financial exposure", confidence: 0.80,
                                      category: .financial, excerpt: ctx))
                excerpts.append(ctx)
            }
        }

        if signals.isEmpty {
            signals.append(Signal(label: "No actionable items detected", confidence: 0.50,
                                  category: .informational))
        }

        // De-duplicate by label
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

            items.append(AnalysisItem(
                title: signal.label,
                detail: signal.excerpt ?? "Detected in meeting transcript",
                riskTier: itemRisk,
                actionRequired: signal.category != .informational,
                suggestedAction: suggestedActionFor(signal.category),
                owner: extractOwnerHint(from: signal.excerpt),
                deadline: extractDeadlineHint(from: signal.excerpt),
                evidenceExcerpt: signal.excerpt
            ))
        }

        let actionCount = items.filter { $0.actionRequired }.count
        let summary = "Meeting extract: \(items.count) items, \(actionCount) actionable. " +
            (overallRisk >= .medium ? "Contains \(overallRisk.rawValue) risk items." : "No elevated risks.")

        return SkillAnalysis(skillId: skillId, riskTier: overallRisk, items: items, summary: summary)
    }

    // MARK: - Generate Proposal

    public func generateProposal(analysis: SkillAnalysis) async -> ProposalPack {
        let steps = analysis.items.filter { $0.actionRequired }.enumerated().map { idx, item in
            ExecutionStepDefinition(
                order: idx + 1,
                action: item.suggestedAction ?? "Review action item",
                description: "\(item.title)" + (item.owner != nil ? " [Owner: \(item.owner!)]" : "") +
                    (item.deadline != nil ? " [Due: \(item.deadline!)]" : ""),
                isMutation: item.suggestedAction?.contains("Schedule") == true ||
                            item.suggestedAction?.contains("Create") == true,
                rollbackAction: "Cancel created item"
            )
        }

        var scopes: [PermissionScope] = []
        if analysis.items.contains(where: { $0.suggestedAction?.contains("Schedule") == true }) {
            scopes.append(PermissionScope(domain: .calendar, access: .write, detail: "event_create"))
        }
        if analysis.items.contains(where: { $0.suggestedAction?.contains("Create reminder") == true }) {
            scopes.append(PermissionScope(domain: .reminders, access: .write, detail: "reminder_create"))
        }
        // Always read calendar for context
        scopes.append(PermissionScope(domain: .calendar, access: .read, detail: "context_check"))

        let toolPlan = ToolPlan(
            intent: ToolPlanIntent(
                type: .createDraft,
                summary: analysis.summary,
                targetDescription: "Meeting action extraction"
            ),
            originatingAction: "meeting_action_skill",
            riskScore: analysis.riskTier.scoreEstimate,
            riskTier: analysis.riskTier,
            riskReasons: analysis.items.filter { $0.riskTier >= .medium }.map { $0.title },
            reversibility: .reversible,
            reversibilityReason: "All actions are drafts requiring approval",
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
            blastRadius: .selfOnly,
            reasons: analysis.items.map { $0.title }
        )

        let citations = analysis.items.compactMap { item -> EvidenceCitation? in
            guard let excerpt = item.evidenceExcerpt else { return nil }
            return EvidenceCitation(
                sourceType: .document,
                reference: "meeting_transcript_\(item.id.uuidString.prefix(8))",
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
        let start = text.index(range.lowerBound, offsetBy: -50, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 50, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func riskForCategory(_ cat: SignalCategory) -> RiskTier {
        switch cat {
        case .financial, .legal:        return .high
        case .risk, .deadline:          return .medium
        case .escalation:               return .medium
        case .commitment, .owner:       return .low
        case .followUp:                 return .low
        default:                        return .low
        }
    }

    private func suggestedActionFor(_ cat: SignalCategory) -> String {
        switch cat {
        case .commitment:   return "Record commitment and assign owner"
        case .owner:        return "Confirm owner assignment"
        case .deadline:     return "Schedule deadline reminder"
        case .risk:         return "Escalate risk for review"
        case .followUp:     return "Schedule follow-up meeting"
        case .financial:    return "Route to finance for review"
        case .legal:        return "Route to legal for review"
        case .escalation:   return "Flag for immediate attention"
        default:            return "Review item"
        }
    }

    private func extractOwnerHint(from excerpt: String?) -> String? {
        // Simple heuristic: look for names after ownership keywords
        guard let text = excerpt?.lowercased() else { return nil }
        let ownerKeywords = ["assigned to", "owner:", "responsible:"]
        for kw in ownerKeywords {
            if let range = text.range(of: kw) {
                let after = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                let words = after.split(separator: " ").prefix(2)
                if !words.isEmpty {
                    return words.joined(separator: " ").capitalized
                }
            }
        }
        return nil
    }

    private func extractDeadlineHint(from excerpt: String?) -> String? {
        guard let text = excerpt?.lowercased() else { return nil }
        let deadlineKeywords = ["by friday", "by monday", "by eod", "by end of week",
                                "by tomorrow", "next week", "by end of month"]
        for kw in deadlineKeywords {
            if text.contains(kw) {
                return kw.capitalized
            }
        }
        return nil
    }
}
