import Foundation

// ============================================================================
// FINDING PACK — Read-Only Scout Artifact
//
// INVARIANT: FindingPack is strictly informational. No side effects.
// INVARIANT: No permissions, no tokens, no execution references.
// INVARIANT: Produced by ScoutEngine from read-only data sources.
// ============================================================================

public struct FindingPack: Codable, Identifiable, Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    public static func == (lhs: FindingPack, rhs: FindingPack) -> Bool {
        lhs.id == rhs.id
    }
    public let id: UUID
    public let createdAt: Date
    public let scoutRunId: UUID
    public let scope: ScoutScope
    public let severity: FindingSeverity
    public let summary: String
    public let findings: [Finding]
    public let evidenceRefs: [EvidenceRef]
    public let recommendedActions: [RecommendedAction]
    public let proposalRef: UUID?       // Optional link to a generated ProposalPack

    public init(
        scoutRunId: UUID,
        scope: ScoutScope,
        severity: FindingSeverity,
        summary: String,
        findings: [Finding],
        evidenceRefs: [EvidenceRef],
        recommendedActions: [RecommendedAction],
        proposalRef: UUID? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.scoutRunId = scoutRunId
        self.scope = scope
        self.severity = severity
        self.summary = summary
        self.findings = findings
        self.evidenceRefs = evidenceRefs
        self.recommendedActions = recommendedActions
        self.proposalRef = proposalRef
    }
}

// MARK: - Finding

public struct Finding: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let detail: String
    public let category: FindingCategory
    public let confidence: Double       // 0.0–1.0
    public let impactedAssets: [String]
    public let signals: [String]

    public init(title: String, detail: String, category: FindingCategory, confidence: Double, impactedAssets: [String] = [], signals: [String] = []) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.category = category
        self.confidence = min(1.0, max(0.0, confidence))
        self.impactedAssets = impactedAssets
        self.signals = signals
    }
}

public enum FindingCategory: String, Codable, CaseIterable {
    case policyDenialSpike = "policy_denial_spike"
    case integrityWarning = "integrity_warning"
    case keyLifecycle = "key_lifecycle"
    case deviceTrust = "device_trust"
    case budgetThrottling = "budget_throttling"
    case executionAnomaly = "execution_anomaly"
    case auditDivergence = "audit_divergence"
    case systemHealth = "system_health"
}

// MARK: - Evidence Reference

public struct EvidenceRef: Codable, Identifiable {
    public let id: UUID
    public let type: String             // e.g. "evidence_entry", "execution_record", "attestation"
    public let refId: String            // The ID of the referenced artifact
    public let hash: String?            // Optional hash for verification
    public let timestamp: Date

    public init(type: String, refId: String, hash: String? = nil, timestamp: Date = Date()) {
        self.id = UUID()
        self.type = type
        self.refId = refId
        self.hash = hash
        self.timestamp = timestamp
    }
}

// MARK: - Recommended Action

public struct RecommendedAction: Codable, Identifiable {
    public let id: UUID
    public let label: String
    public let nextStep: String
    public let requiresHumanApproval: Bool
    public let deepLinks: [ScoutDeepLink]

    public init(label: String, nextStep: String, requiresHumanApproval: Bool = true, deepLinks: [ScoutDeepLink] = []) {
        self.id = UUID()
        self.label = label
        self.nextStep = nextStep
        self.requiresHumanApproval = requiresHumanApproval
        self.deepLinks = deepLinks
    }
}

public struct ScoutDeepLink: Codable {
    public let label: String
    public let route: String            // AppRouter route string e.g. "operatorkit://operator-channel"

    public init(label: String, route: String) {
        self.label = label
        self.route = route
    }
}

// MARK: - Enums

public enum ScoutScope: String, Codable, CaseIterable {
    case full = "full"                  // All heuristics
    case security = "security"          // Integrity + trust + key
    case operations = "operations"      // Execution patterns + denials
    case compliance = "compliance"      // Audit chain + mirror
}

public enum FindingSeverity: String, Codable, CaseIterable, Comparable {
    case nominal = "nominal"
    case info = "info"
    case warning = "warning"
    case critical = "critical"

    public static func < (lhs: FindingSeverity, rhs: FindingSeverity) -> Bool {
        let order: [FindingSeverity] = [.nominal, .info, .warning, .critical]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}
