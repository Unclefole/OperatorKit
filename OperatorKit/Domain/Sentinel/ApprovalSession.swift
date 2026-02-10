import Foundation

// ============================================================================
// APPROVAL SESSION — HUMAN AUTHORITY CHECKPOINT
//
// An ApprovalSession is created for every ProposalPack before execution.
// The session tracks the human decision and links to the execution token.
//
// EXECUTION PATH:
//   ProposalPack generated
//   → Kernel validates policy
//   → ApprovalSession created
//   → Human reviews
//   → Human chooses: Approve / Approve Partial / Request Revision / Escalate / Reject
//   → ONLY "Approve" mints an ExecutionToken
//   → No approval → no execution
//
// INVARIANT: Every execution MUST reference an ApprovalSession.
// INVARIANT: An ApprovalSession without a decision CANNOT produce a token.
// INVARIANT: Session expiry prevents stale approvals from executing.
// ============================================================================

public struct ApprovalSession: Identifiable, Equatable {

    // MARK: - Identity

    public let id: UUID
    public let createdAt: Date
    public let proposalId: UUID
    public let proposalSource: ProposalSource

    // MARK: - Proposal Context (snapshot)

    public let riskTier: RiskTier
    public let riskScore: Int
    public let reversibilityClass: ReversibilityClass
    public let permissionScopes: [PermissionScope]
    public let estimatedCostUSD: Double
    public let humanSummary: String
    public let toolPlanStepCount: Int

    // MARK: - Decision

    public var decision: Decision?
    public var decidedAt: Date?
    public var partialApprovalSteps: [Int]?  // step indices approved (for .approvePartial)
    public var revisionNotes: String?

    // MARK: - Token Link

    /// Set when execution token is minted (only after .approve)
    public var mintedTokenId: UUID?

    // MARK: - Expiry

    /// Sessions expire after 5 minutes to prevent stale approvals
    public let expiresAt: Date

    public var isExpired: Bool {
        Date() > expiresAt
    }

    public var isApproved: Bool {
        guard let decision = decision else { return false }
        return (decision == .approve || decision == .approvePartial) && !isExpired
    }

    // MARK: - Init

    public init(proposal: ProposalPack) {
        self.id = UUID()
        self.createdAt = Date()
        self.proposalId = proposal.id
        self.proposalSource = proposal.source
        self.riskTier = proposal.riskAnalysis.consequenceTier
        self.riskScore = proposal.riskAnalysis.riskScore
        self.reversibilityClass = proposal.riskAnalysis.reversibilityClass
        self.permissionScopes = proposal.permissionManifest.scopes
        self.estimatedCostUSD = proposal.costEstimate.estimatedCostUSD
        self.humanSummary = proposal.humanSummary
        self.toolPlanStepCount = proposal.toolPlan.executionSteps.count
        self.expiresAt = Date().addingTimeInterval(300) // 5 minutes
    }

    // MARK: - Decision Enum

    public enum Decision: String, Codable, Equatable {
        case approve         = "approve"
        case approvePartial  = "approve_partial"
        case requestRevision = "request_revision"
        case escalate        = "escalate"
        case reject          = "reject"

        public var isTerminal: Bool {
            switch self {
            case .approve, .approvePartial, .reject: return true
            case .requestRevision, .escalate: return false
            }
        }

        /// Only these decisions allow execution to proceed
        public var allowsExecution: Bool {
            self == .approve || self == .approvePartial
        }
    }

    // MARK: - Equatable

    public static func == (lhs: ApprovalSession, rhs: ApprovalSession) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Approval Session Store

/// Manages active and historical approval sessions.
@MainActor
public final class ApprovalSessionStore: ObservableObject {

    public static let shared = ApprovalSessionStore()

    @Published public private(set) var activeSessions: [ApprovalSession] = []
    @Published public private(set) var recentSessions: [ApprovalSession] = []

    private let maxHistory = 50

    private init() {}

    /// Register a new session for tracking.
    public func register(_ session: ApprovalSession) {
        activeSessions.append(session)

        try? EvidenceEngine.shared.logGenericArtifact(
            type: "approval_session_created",
            planId: session.proposalId,
            jsonString: """
            {"sessionId":"\(session.id)","proposalId":"\(session.proposalId)","riskTier":"\(session.riskTier.rawValue)","riskScore":\(session.riskScore),"expiresAt":"\(session.expiresAt)"}
            """
        )
    }

    /// Record a decision for a session.
    public func recordDecision(_ sessionId: UUID, decision: ApprovalSession.Decision) {
        guard let index = activeSessions.firstIndex(where: { $0.id == sessionId }) else {
            logError("[ApprovalSessionStore] Session \(sessionId) not found")
            return
        }

        activeSessions[index].decision = decision
        activeSessions[index].decidedAt = Date()

        let session = activeSessions[index]

        try? EvidenceEngine.shared.logGenericArtifact(
            type: "approval_session_decision",
            planId: session.proposalId,
            jsonString: """
            {"sessionId":"\(session.id)","decision":"\(decision.rawValue)","proposalId":"\(session.proposalId)","decidedAt":"\(Date())"}
            """
        )

        // Move to history if terminal
        if decision.isTerminal {
            let completed = activeSessions.remove(at: index)
            recentSessions.insert(completed, at: 0)
            if recentSessions.count > maxHistory {
                recentSessions.removeLast()
            }
        }
    }

    /// Link a minted token to a session.
    public func linkToken(_ tokenId: UUID, to sessionId: UUID) {
        if let index = activeSessions.firstIndex(where: { $0.id == sessionId }) {
            activeSessions[index].mintedTokenId = tokenId
        } else if let index = recentSessions.firstIndex(where: { $0.id == sessionId }) {
            recentSessions[index].mintedTokenId = tokenId
        }
    }

    /// Expire stale sessions.
    public func expireStaleSessions() {
        let now = Date()
        let expired = activeSessions.filter { $0.isExpired && $0.decision == nil }
        for session in expired {
            try? EvidenceEngine.shared.logGenericArtifact(
                type: "approval_session_expired",
                planId: session.proposalId,
                jsonString: """
                {"sessionId":"\(session.id)","proposalId":"\(session.proposalId)","expiredAt":"\(now)"}
                """
            )
        }
        activeSessions.removeAll { $0.isExpired && $0.decision == nil }
    }

    /// Validate that an approved session exists for a given proposal.
    /// Returns nil if no valid approved session exists.
    public func validateApproval(for proposalId: UUID) -> ApprovalSession? {
        let all = activeSessions + recentSessions
        return all.first { $0.proposalId == proposalId && $0.isApproved }
    }
}
