import Foundation

// ============================================================================
// OPERATOR CHANNEL — HIGH-AUTHORITY INTENT HANDOFF SYSTEM
//
// OperatorChannel is NOT chat. It is a structured proposal surface.
//
// When an intent arrives (from Siri, user, or automation):
//   1. Capture natural language
//   2. Route into SentinelProposalEngine
//   3. Sentinel generates ProposalPack
//   4. Kernel validates policy
//   5. Open Proposal Review with a Proposal Card
//
// INVARIANT: OperatorChannel NEVER executes side effects.
// INVARIANT: OperatorChannel NEVER bypasses approval — even for low-risk.
// INVARIANT: Every action surfaces a decision boundary in the audit chain.
//
// HIERARCHY:
//   Siri triggers → OperatorKit decides → Humans authorize → System executes
// ============================================================================

@MainActor
public final class OperatorChannel: ObservableObject {

    public static let shared = OperatorChannel()

    private let sentinel = SentinelProposalEngine.shared

    // MARK: - Published State

    @Published public private(set) var pendingProposal: ProposalPack?
    @Published public private(set) var activeSession: ApprovalSession?
    @Published public private(set) var channelState: ChannelState = .idle
    @Published public private(set) var history: [ChannelEntry] = []

    private init() {}

    // MARK: - Channel State

    public enum ChannelState: String {
        case idle               = "idle"
        case generatingProposal = "generating_proposal"
        case awaitingApproval   = "awaiting_approval"
        case approved           = "approved"
        case rejected           = "rejected"
    }

    // MARK: - Channel Entry (Audit)

    public struct ChannelEntry: Identifiable {
        public let id: UUID
        public let timestamp: Date
        public let proposalId: UUID
        public let source: ProposalSource
        public let summary: String
        public let decision: ApprovalSession.Decision?
    }

    // MARK: - Submit Intent

    /// Primary entry point. Accepts an intent from any source,
    /// runs it through Sentinel, and produces a ProposalPack
    /// for human review.
    ///
    /// INVARIANT: Returns a ProposalPack. NEVER executes.
    func submitIntent(
        _ intent: IntentRequest,
        context: ContextPacket?,
        source: ProposalSource
    ) async -> ProposalPack {
        channelState = .generatingProposal
        log("[OPERATOR_CHANNEL] Intent received from \(source.rawValue): \(intent.intentType.rawValue)")

        // Generate proposal via Sentinel (read-only)
        let proposal = await sentinel.generateProposal(
            intent: intent,
            context: context,
            source: source
        )

        // Create approval session
        let session = ApprovalSession(proposal: proposal)
        activeSession = session
        pendingProposal = proposal
        channelState = .awaitingApproval

        // Log to evidence
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "operator_channel_proposal",
            planId: proposal.id,
            jsonString: """
            {"proposalId":"\(proposal.id)","source":"\(source.rawValue)","intent":"\(intent.intentType.rawValue)","channelState":"awaiting_approval","sessionId":"\(session.id)"}
            """
        )

        log("[OPERATOR_CHANNEL] Proposal \(proposal.id) ready for approval — session \(session.id)")
        return proposal
    }

    // MARK: - Siri Handoff

    /// Called when Siri routes an intent into OperatorKit.
    /// Siri NEVER executes — only routes.
    func handleSiriHandoff(
        rawText: String,
        intentType: IntentRequest.IntentType
    ) async -> ProposalPack {
        let intent = IntentRequest(
            rawText: rawText,
            intentType: intentType
        )
        return await submitIntent(intent, context: nil, source: .siri)
    }

    // MARK: - Decision Handling

    /// Record a human decision on the active proposal.
    /// Only .approve mints an execution path.
    public func recordDecision(_ decision: ApprovalSession.Decision) {
        guard var session = activeSession else {
            logError("[OPERATOR_CHANNEL] No active session for decision")
            return
        }

        session.decision = decision
        session.decidedAt = Date()
        activeSession = session

        // Record in history
        if let proposal = pendingProposal {
            let entry = ChannelEntry(
                id: UUID(),
                timestamp: Date(),
                proposalId: proposal.id,
                source: proposal.source,
                summary: proposal.humanSummary,
                decision: decision
            )
            history.append(entry)
            if history.count > 50 { history.removeFirst() }
        }

        switch decision {
        case .approve, .approvePartial:
            channelState = .approved
            log("[OPERATOR_CHANNEL] Proposal APPROVED — forwarding to kernel pipeline")
        case .requestRevision:
            channelState = .idle
            log("[OPERATOR_CHANNEL] Revision requested — proposal returned to user")
        case .escalate:
            channelState = .awaitingApproval
            log("[OPERATOR_CHANNEL] Proposal ESCALATED for higher review")
        case .reject:
            channelState = .rejected
            log("[OPERATOR_CHANNEL] Proposal REJECTED")
        }

        // Log decision to evidence
        if let proposal = pendingProposal {
            try? EvidenceEngine.shared.logGenericArtifact(
                type: "operator_channel_decision",
                planId: proposal.id,
                jsonString: """
                {"proposalId":"\(proposal.id)","decision":"\(decision.rawValue)","sessionId":"\(activeSession?.id.uuidString ?? "nil")","decidedAt":"\(Date())"}
                """
            )
        }

        // Clear pending if terminal
        if decision == .reject {
            pendingProposal = nil
            activeSession = nil
        }
    }

    /// Reset channel to idle (after execution completes or user dismisses)
    public func reset() {
        pendingProposal = nil
        activeSession = nil
        channelState = .idle
    }
}
