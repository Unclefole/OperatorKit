import Foundation

// ============================================================================
// OPERATOR SKILL — GOVERNED MICRO-OPERATOR PROTOCOL
//
// INVARIANT: Skills produce ProposalPacks ONLY. Zero execution.
// INVARIANT: Skills MUST NOT reference ExecutionEngine, ServiceAccessToken,
//            or any write-capable service.
// INVARIANT: Skills MUST NOT mint tokens or call CapabilityKernel.issueToken.
// INVARIANT: Proposal-only intelligence. Humans authorize. System executes.
// ============================================================================

/// Protocol for all Micro-Operators in OperatorKit.
/// Skills observe, analyze, and generate ProposalPacks.
/// They NEVER execute side effects.
public protocol OperatorSkill: AnyObject, Identifiable {

    /// Unique skill identifier (e.g. "inbox_triage", "meeting_actions")
    var skillId: String { get }

    /// Human-readable display name
    var displayName: String { get }

    /// Default risk tier for this skill's output
    var riskTier: RiskTier { get }

    /// Scopes this skill's proposals may request (read-only observation scopes)
    var allowedScopes: [PermissionDomain] { get }

    /// Number of signers required for proposals from this skill
    var requiredSigners: Int { get }

    /// Always true for Day-One skills — they produce proposals, not executions
    var producesProposalPack: Bool { get }

    /// Whether execution is optional (false = proposals always require approval)
    var executionOptional: Bool { get }

    /// Observe inputs and collect signals (read-only)
    func observe(input: SkillInput) async -> SkillObservation

    /// Analyze observations and classify findings
    func analyze(observation: SkillObservation) async -> SkillAnalysis

    /// Generate a ProposalPack from analysis (NEVER execute)
    func generateProposal(analysis: SkillAnalysis) async -> ProposalPack
}

extension OperatorSkill {
    public var id: String { skillId }
}

// MARK: - Skill Input

/// Input fed to a skill's observe phase.
/// May contain text, transcripts, message exports, or pasted content.
public struct SkillInput: Codable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let inputType: SkillInputType
    public let textContent: String
    public let metadata: [String: String]

    public init(
        inputType: SkillInputType,
        textContent: String,
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.inputType = inputType
        self.textContent = textContent
        self.metadata = metadata
    }
}

public enum SkillInputType: String, Codable {
    case emailThread = "email_thread"
    case meetingTranscript = "meeting_transcript"
    case pastedText = "pasted_text"
    case proposalPack = "proposal_pack"         // For ApprovalRouter
    case sharedInboxExport = "shared_inbox"
    case documentText = "document_text"
    case webResearchQuery = "web_research_query" // URL + research query
}

// MARK: - Skill Observation

/// Output of the observe phase — detected signals before classification.
public struct SkillObservation: Codable, Identifiable {
    public let id: UUID
    public let skillId: String
    public let signals: [Signal]
    public let rawExcerpts: [String]
    public let observedAt: Date

    public init(skillId: String, signals: [Signal], rawExcerpts: [String] = []) {
        self.id = UUID()
        self.skillId = skillId
        self.signals = signals
        self.rawExcerpts = rawExcerpts
        self.observedAt = Date()
    }
}

public struct Signal: Codable, Identifiable {
    public let id: UUID
    public let label: String
    public let confidence: Double       // 0.0–1.0
    public let category: SignalCategory
    public let excerpt: String?

    public init(label: String, confidence: Double, category: SignalCategory, excerpt: String? = nil) {
        self.id = UUID()
        self.label = label
        self.confidence = min(1.0, max(0.0, confidence))
        self.category = category
        self.excerpt = excerpt
    }
}

public enum SignalCategory: String, Codable, CaseIterable {
    case pricing = "pricing"
    case contract = "contract"
    case escalation = "escalation"
    case refund = "refund"
    case timeline = "timeline"
    case commitment = "commitment"
    case owner = "owner"
    case deadline = "deadline"
    case risk = "risk"
    case followUp = "follow_up"
    case approval = "approval"
    case financial = "financial"
    case legal = "legal"
    case informational = "informational"
}

// MARK: - Skill Analysis

/// Output of the analyze phase — classified findings ready for proposal generation.
public struct SkillAnalysis: Codable, Identifiable {
    public let id: UUID
    public let skillId: String
    public let riskTier: RiskTier
    public let items: [AnalysisItem]
    public let summary: String
    public let analyzedAt: Date

    public init(skillId: String, riskTier: RiskTier, items: [AnalysisItem], summary: String) {
        self.id = UUID()
        self.skillId = skillId
        self.riskTier = riskTier
        self.items = items
        self.summary = summary
        self.analyzedAt = Date()
    }
}

public struct AnalysisItem: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let detail: String
    public let riskTier: RiskTier
    public let actionRequired: Bool
    public let suggestedAction: String?
    public let owner: String?
    public let deadline: String?
    public let evidenceExcerpt: String?

    public init(
        title: String,
        detail: String,
        riskTier: RiskTier,
        actionRequired: Bool = true,
        suggestedAction: String? = nil,
        owner: String? = nil,
        deadline: String? = nil,
        evidenceExcerpt: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.riskTier = riskTier
        self.actionRequired = actionRequired
        self.suggestedAction = suggestedAction
        self.owner = owner
        self.deadline = deadline
        self.evidenceExcerpt = evidenceExcerpt
    }
}
