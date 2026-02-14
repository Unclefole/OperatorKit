import Foundation
import os.log

// ============================================================================
// AUTOPILOT ORCHESTRATOR — DETERMINISTIC STATE MACHINE TO APPROVAL
//
// Drives the pipeline: intent → context → proposal → draft → approval.
// STOPS at readyForApproval. NEVER executes. NEVER mints tokens.
//
// FORBIDDEN IMPORTS (enforced by firewall tests):
//   - ExecutionEngine
//   - CapabilityKernel.issueToken / issueHardenedToken
//   - ServiceAccessToken
//   - CalendarService / ReminderService / MailComposerService (write paths)
//
// EVIDENCE TAGS:
//   autopilot_started, autopilot_context_gathered,
//   autopilot_proposal_ready, autopilot_draft_ready,
//   autopilot_approval_session_created, autopilot_failed
// ============================================================================

// MARK: - State

public enum AutopilotState: String, Equatable {
    case idle
    case receivedIntent
    case gatheringContext
    case generatingProposal
    case generatingDraft
    case readyForApproval
    case halted
}

// MARK: - Input

public struct AutopilotInput: Hashable {
    public let rawIntentText: String
    public let skillId: String?
    public let skillInputText: String?
    public let skillInputType: SkillInputType?
    public let source: AutopilotSource

    public init(
        rawIntentText: String,
        skillId: String? = nil,
        skillInput: SkillInput? = nil,
        source: AutopilotSource = .manual
    ) {
        self.rawIntentText = rawIntentText
        self.skillId = skillId
        self.skillInputText = skillInput?.textContent
        self.skillInputType = skillInput?.inputType
        self.source = source
    }

    /// Reconstruct SkillInput if available.
    var skillInput: SkillInput? {
        guard let text = skillInputText, let type = skillInputType else { return nil }
        return SkillInput(inputType: type, textContent: text)
    }
}

public enum AutopilotSource: String, Codable {
    case siri
    case skill
    case manual
    case workspace
}

// MARK: - Result

public struct AutopilotResult {
    public let proposal: ProposalPack?
    public let session: ApprovalSession?
    public let error: String?
    public let durationMs: Int
}

// MARK: - Orchestrator

@MainActor
public final class AutopilotOrchestrator: ObservableObject {

    public static let shared = AutopilotOrchestrator()

    // Published state for UI binding
    @Published public private(set) var state: AutopilotState = .idle
    @Published public private(set) var statusMessage: String = ""
    @Published public private(set) var proposal: ProposalPack?
    @Published public private(set) var session: ApprovalSession?
    @Published public private(set) var errorReason: String?
    @Published public private(set) var progress: Double = 0.0 // 0..1
    @Published public private(set) var enrichedDraftBody: String?

    private static let logger = Logger(subsystem: "com.operatorkit", category: "Autopilot")
    private var runTask: Task<Void, Never>?
    private var startTime: Date?

    private init() {}

    // MARK: - Public API

    /// Start the autopilot pipeline. Runs to readyForApproval then stops.
    public func start(input: AutopilotInput) {
        guard state == .idle || state == .halted else {
            Self.logger.warning("Autopilot already running (state=\(self.state.rawValue))")
            return
        }

        // Reset
        proposal = nil
        session = nil
        errorReason = nil
        progress = 0.0
        startTime = Date()

        runTask = Task { [weak self] in
            await self?.execute(input: input)
        }
    }

    /// Abort the current autopilot run.
    public func abort() {
        runTask?.cancel()
        runTask = nil
        transition(to: .halted)
        statusMessage = "Autopilot aborted by user."
        logEvidence(type: "autopilot_aborted", detail: statusMessage)
    }

    /// Reset to idle (after approval completes or user dismisses).
    public func reset() {
        runTask?.cancel()
        runTask = nil
        state = .idle
        statusMessage = ""
        proposal = nil
        session = nil
        errorReason = nil
        progress = 0.0
    }

    // MARK: - Pipeline

    private func execute(input: AutopilotInput) async {
        // ── STEP 1: Received Intent ──────────────────────────
        transition(to: .receivedIntent)
        statusMessage = "Parsing intent..."
        progress = 0.1
        logEvidence(type: "autopilot_started", detail: "source=\(input.source.rawValue), text=\(String(input.rawIntentText.prefix(80)))")

        guard !Task.isCancelled else { return failClosed("Cancelled during intent parse.") }

        // Small delay for visual feedback
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

        // ── STEP 2: Gather Context ───────────────────────────
        transition(to: .gatheringContext)
        statusMessage = "Gathering context..."
        progress = 0.25

        guard !Task.isCancelled else { return failClosed("Cancelled during context gather.") }

        // If we have a skill input, context is already provided.
        // Otherwise, use the raw text as-is (auto-context from local sources only).
        let resolvedInput: SkillInput
        if let si = input.skillInput {
            resolvedInput = si
        } else {
            resolvedInput = SkillInput(
                inputType: classifyInputType(input.rawIntentText),
                textContent: input.rawIntentText
            )
        }

        logEvidence(type: "autopilot_context_gathered", detail: "inputType=\(resolvedInput.inputType.rawValue)")
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s

        // ── STEP 3: Generate Proposal ────────────────────────
        transition(to: .generatingProposal)
        statusMessage = "Generating proposal..."
        progress = 0.5

        guard !Task.isCancelled else { return failClosed("Cancelled during proposal generation.") }

        let generatedProposal: ProposalPack?

        if let skillId = input.skillId {
            // Use skill pipeline
            let registry = SkillRegistry.shared
            registry.registerDayOneSkills()
            generatedProposal = await registry.runSkill(skillId, input: resolvedInput)
        } else if resolvedInput.inputType == .webResearchQuery {
            // Auto-route to WebResearchSkill for web research queries
            let registry = SkillRegistry.shared
            registry.registerDayOneSkills()
            generatedProposal = await registry.runSkill("web_research", input: resolvedInput)
        } else {
            // Use SentinelProposalEngine for general intents
            generatedProposal = await SentinelProposalEngine.shared.generateProposal(
                rawText: input.rawIntentText,
                intentType: classifyIntentType(input.rawIntentText)
            )
        }

        guard let pack = generatedProposal else {
            return failClosed("Proposal generation returned nil.")
        }

        self.proposal = pack
        logEvidence(type: "autopilot_proposal_ready", detail: "proposalId=\(pack.id), risk=\(pack.riskAnalysis.consequenceTier.rawValue)")

        // ── STEP 4: Generate Draft (optional enrichment via governed router) ─
        transition(to: .generatingDraft)
        statusMessage = "Preparing draft..."
        progress = 0.75

        guard !Task.isCancelled else { return failClosed("Cancelled during draft generation.") }

        // Use governed V2 router for draft enrichment (cheap-first, budget-gated)
        let taskType = classifyModelTaskType(input.rawIntentText)
        do {
            // For research briefs, pass the full user query as the prompt
            // so the cloud model gets the complete research request
            let draftPrompt: String
            if taskType == .researchBrief {
                draftPrompt = input.rawIntentText
            } else {
                draftPrompt = pack.humanSummary
            }
            let draftResponse = try await ModelRouter.shared.generateGovernedV2(
                taskType: taskType,
                prompt: draftPrompt,
                context: input.rawIntentText
            )

            // Store the enriched draft body for display
            if taskType == .researchBrief {
                enrichedDraftBody = draftResponse.text
            }

            logEvidence(type: "autopilot_draft_ready", detail: "proposalId=\(pack.id), model=\(draftResponse.modelId), cost=\(draftResponse.costCents)¢")
        } catch {
            // Draft enrichment is optional — log but do not fail
            logEvidence(type: "autopilot_draft_enrichment_skipped", detail: "proposalId=\(pack.id), reason=\(error.localizedDescription)")
        }

        // ── STEP 5: Create ApprovalSession ───────────────────
        let approvalSession = ApprovalSession(proposal: pack)
        ApprovalSessionStore.shared.register(approvalSession)
        self.session = approvalSession

        logEvidence(type: "autopilot_approval_session_created", detail: "sessionId=\(approvalSession.id), proposalId=\(pack.id)")

        // ── DONE: Ready for human approval ───────────────────
        transition(to: .readyForApproval)
        statusMessage = "Proposal ready — approval required."
        progress = 1.0

        let elapsed = Int((Date().timeIntervalSince(startTime ?? Date())) * 1000)
        Self.logger.info("Autopilot pipeline complete in \(elapsed)ms. Awaiting human approval.")
    }

    // MARK: - Helpers

    private func transition(to newState: AutopilotState) {
        state = newState
        Self.logger.info("Autopilot → \(newState.rawValue)")
    }

    private func failClosed(_ reason: String) {
        errorReason = reason
        statusMessage = reason
        transition(to: .halted)
        logEvidence(type: "autopilot_failed", detail: reason)
        Self.logger.error("Autopilot FAIL CLOSED: \(reason)")
    }

    private func logEvidence(type: String, detail: String) {
        try? EvidenceEngine.shared.logGenericArtifact(
            type: type,
            planId: proposal?.id ?? UUID(),
            jsonString: """
            {"detail":"\(detail)","timestamp":"\(Date().ISO8601Format())"}
            """
        )
    }

    private func classifyInputType(_ text: String) -> SkillInputType {
        let lower = text.lowercased()
        // Research briefs use cloud AI directly — not web research skill
        if isResearchQuery(lower) {
            return .pastedText  // Route through Sentinel → cloud AI pipeline
        }
        if lower.contains("http://") || lower.contains("https://") ||
           lower.contains(".gov") || lower.contains("website") {
            return .webResearchQuery
        } else if lower.contains("email") || lower.contains("mail") || lower.contains("send") {
            return .emailThread
        } else if lower.contains("meeting") || lower.contains("standup") || lower.contains("sync") {
            return .meetingTranscript
        } else if lower.contains("approve") || lower.contains("approval") || lower.contains("sign") {
            return .proposalPack
        }
        return .pastedText
    }

    private func classifyModelTaskType(_ text: String) -> ModelTaskType {
        let lower = text.lowercased()
        // Research briefs get their own high-quality task type
        if isResearchQuery(lower) {
            return .researchBrief
        }
        if lower.contains("http://") || lower.contains("https://") ||
           lower.contains(".gov") || lower.contains("website") ||
           lower.contains("document") || lower.contains("find information") {
            return .extractInformation
        } else if lower.contains("email") || lower.contains("mail") || lower.contains("draft") {
            return .draftEmail
        } else if lower.contains("meeting") || lower.contains("summarize") || lower.contains("standup") {
            return .summarizeMeeting
        } else if lower.contains("action") || lower.contains("extract") {
            return .extractActionItems
        } else if lower.contains("plan") || lower.contains("proposal") {
            return .planSynthesis
        }
        return .proposalGeneration
    }

    private func classifyIntentType(_ text: String) -> IntentRequest.IntentType {
        let lower = text.lowercased()
        // Research briefs route to dedicated intent
        if isResearchQuery(lower) {
            return .researchBrief
        }
        if lower.contains("http://") || lower.contains("https://") ||
           lower.contains(".gov") || lower.contains("website") ||
           lower.contains("find information") || lower.contains("look up") {
            return .reviewDocument
        } else if lower.contains("email") || lower.contains("mail") || lower.contains("draft") {
            return .draftEmail
        } else if lower.contains("meeting") || lower.contains("summarize") || lower.contains("standup") {
            return .summarizeMeeting
        } else if lower.contains("action") || lower.contains("extract") {
            return .extractActionItems
        } else if lower.contains("remind") {
            return .createReminder
        } else if lower.contains("review") || lower.contains("document") {
            return .reviewDocument
        }
        return .draftEmail // safe default
    }

    /// Detects research/analysis queries — requires 2+ keyword hits for confidence
    private func isResearchQuery(_ text: String) -> Bool {
        let keywords = [
            "search", "research", "find", "identify", "investigate",
            "market", "consumer", "spending", "trends", "analysis",
            "data", "report", "brief", "insight", "segment",
            "landscape", "competitive", "industry", "demographic",
            "emerging", "growth", "strategic", "recommendation"
        ]
        return keywords.filter { text.contains($0) }.count >= 2
    }
}
