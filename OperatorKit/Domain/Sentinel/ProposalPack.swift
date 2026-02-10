import Foundation

// ============================================================================
// PROPOSAL PACK — STRUCTURED ARTIFACT FROM SENTINEL PROPOSAL ENGINE
//
// A ProposalPack is the COMPLETE description of a proposed action.
// It is produced by SentinelProposalEngine and consumed by CapabilityKernel.
//
// A ProposalPack is READ-ONLY. It DESCRIBES actions — it NEVER executes them.
//
// CONTENTS:
//   1. ToolPlan — step-by-step intended actions
//   2. PermissionManifest — explicit scopes required
//   3. RiskConsequenceAnalysis — risk + blast radius + reversibility
//   4. CostEstimate — token/cost prediction for cloud calls
//   5. EvidenceCitations — context artifacts used (redacted)
//
// INVARIANT: ProposalPack cannot import ExecutionEngine.
// INVARIANT: ProposalPack cannot construct ServiceAccessToken.
// INVARIANT: ProposalPack is immutable after creation.
// ============================================================================

public struct ProposalPack: Identifiable, Codable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public let source: ProposalSource

    // 1. Tool Plan
    public let toolPlan: ToolPlan

    // 2. Permission Manifest
    public let permissionManifest: PermissionManifest

    // 3. Risk + Consequence Analysis
    public let riskAnalysis: RiskConsequenceAnalysis

    // 4. Cost Estimate
    public let costEstimate: CostEstimate

    // 5. Evidence Citations
    public let evidenceCitations: [EvidenceCitation]

    // Summary for display
    public let humanSummary: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        source: ProposalSource,
        toolPlan: ToolPlan,
        permissionManifest: PermissionManifest,
        riskAnalysis: RiskConsequenceAnalysis,
        costEstimate: CostEstimate,
        evidenceCitations: [EvidenceCitation],
        humanSummary: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.toolPlan = toolPlan
        self.permissionManifest = permissionManifest
        self.riskAnalysis = riskAnalysis
        self.costEstimate = costEstimate
        self.evidenceCitations = evidenceCitations
        self.humanSummary = humanSummary
    }
}

// MARK: - Proposal Source

public enum ProposalSource: String, Codable, Equatable {
    case user           = "user"
    case siri           = "siri"
    case operatorChannel = "operator_channel"
    case draftAutonomy  = "draft_autonomy"
}

// MARK: - Permission Manifest

/// Explicit scopes the proposed action requires.
/// Kernel translates these into constrained execution permissions.
public struct PermissionManifest: Codable, Equatable {
    public let scopes: [PermissionScope]

    public init(scopes: [PermissionScope]) {
        self.scopes = scopes
    }

    public var requiresCalendarWrite: Bool {
        scopes.contains { $0.domain == .calendar && $0.access == .write }
    }

    public var requiresMailCompose: Bool {
        scopes.contains { $0.domain == .mail && ($0.access == .write || $0.access == .compose) }
    }

    public var requiresReminderWrite: Bool {
        scopes.contains { $0.domain == .reminders && $0.access == .write }
    }
}

public struct PermissionScope: Codable, Equatable, Identifiable {
    public let id: UUID
    public let domain: PermissionDomain
    public let access: AccessLevel
    public let detail: String   // e.g. "event_create", "draft_only"

    public init(id: UUID = UUID(), domain: PermissionDomain, access: AccessLevel, detail: String) {
        self.id = id
        self.domain = domain
        self.access = access
        self.detail = detail
    }
}

public enum PermissionDomain: String, Codable, Equatable {
    case calendar   = "Calendar"
    case mail       = "Mail"
    case reminders  = "Reminders"
    case files      = "Files"
    case network    = "Network"
    case memory     = "Memory"
}

public enum AccessLevel: String, Codable, Equatable {
    case read       = "read"
    case write      = "write"
    case compose    = "compose"   // e.g. Mail.compose(draft_only)
    case delete     = "delete"
}

// MARK: - Risk + Consequence Analysis

public struct RiskConsequenceAnalysis: Codable, Equatable {
    public let riskScore: Int           // 0-100
    public let consequenceTier: RiskTier
    public let reversibilityClass: ReversibilityClass
    public let blastRadius: BlastRadius
    public let reasons: [String]

    public init(
        riskScore: Int,
        consequenceTier: RiskTier,
        reversibilityClass: ReversibilityClass,
        blastRadius: BlastRadius,
        reasons: [String]
    ) {
        self.riskScore = riskScore
        self.consequenceTier = consequenceTier
        self.reversibilityClass = reversibilityClass
        self.blastRadius = blastRadius
        self.reasons = reasons
    }
}

public enum BlastRadius: String, Codable, Equatable {
    case selfOnly       = "SELF_ONLY"       // affects only operator
    case singleRecipient = "SINGLE_RECIPIENT" // one external party
    case multiRecipient = "MULTI_RECIPIENT"  // multiple parties
    case organizational = "ORGANIZATIONAL"   // org-wide impact
}

// MARK: - Cost Estimate

/// Economic prediction for cloud model calls.
/// Used by EconomicGovernor to gate expensive operations.
public struct CostEstimate: Codable, Equatable {
    public let predictedInputTokens: Int
    public let predictedOutputTokens: Int
    public let estimatedCostUSD: Double
    public let confidenceBand: ConfidenceBand
    public let modelProvider: String        // "on_device", "openai", "anthropic"
    public let requiresCloudCall: Bool

    public init(
        predictedInputTokens: Int,
        predictedOutputTokens: Int,
        estimatedCostUSD: Double,
        confidenceBand: ConfidenceBand,
        modelProvider: String,
        requiresCloudCall: Bool
    ) {
        self.predictedInputTokens = predictedInputTokens
        self.predictedOutputTokens = predictedOutputTokens
        self.estimatedCostUSD = estimatedCostUSD
        self.confidenceBand = confidenceBand
        self.modelProvider = modelProvider
        self.requiresCloudCall = requiresCloudCall
    }

    /// Zero-cost estimate for on-device operations
    public static let onDevice = CostEstimate(
        predictedInputTokens: 0,
        predictedOutputTokens: 0,
        estimatedCostUSD: 0,
        confidenceBand: .high,
        modelProvider: "on_device",
        requiresCloudCall: false
    )
}

public enum ConfidenceBand: String, Codable, Equatable {
    case high   = "HIGH"    // ±10%
    case medium = "MEDIUM"  // ±30%
    case low    = "LOW"     // ±50%+
}

// MARK: - Evidence Citation

/// References to context artifacts used in proposal generation.
/// Raw content is NEVER included — only references and redacted summaries.
public struct EvidenceCitation: Codable, Equatable, Identifiable {
    public let id: UUID
    public let sourceType: CitationSourceType
    public let reference: String          // e.g. "email_from_jane_2024-01-15"
    public let redactedSummary: String    // DataDiode-processed summary
    public let usedAt: Date

    public init(
        id: UUID = UUID(),
        sourceType: CitationSourceType,
        reference: String,
        redactedSummary: String,
        usedAt: Date = Date()
    ) {
        self.id = id
        self.sourceType = sourceType
        self.reference = reference
        self.redactedSummary = redactedSummary
        self.usedAt = usedAt
    }
}

public enum CitationSourceType: String, Codable, Equatable {
    case email          = "email"
    case calendarEvent  = "calendar_event"
    case document       = "document"
    case reminder       = "reminder"
    case memoryItem     = "memory_item"
    case userInput      = "user_input"
}
