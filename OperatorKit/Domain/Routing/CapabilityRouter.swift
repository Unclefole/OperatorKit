import Foundation

// ============================================================================
// CAPABILITY ROUTER — EXECUTE > DRAFT DECISION AUTHORITY
//
// Sits between IntentResolver and navigation.
// Consults SkillRegistry + FeatureFlags + ConnectorManifest BEFORE routing.
//
// INVARIANT 1: If executable capability exists + requirements met → MUST route to execution.
// INVARIANT 2: If capability exists but requirements NOT met → FAIL CLOSED + Evidence.
// INVARIANT 3: Draft path is reachable ONLY when NO executable capability exists.
// INVARIANT 4: No connector may bypass ConnectorGate + NetworkPolicyEnforcer.
// INVARIANT 5: No model gains execution authority through this router.
//
// Evidence events:
//   capability_router_execute     — routed to execution pipeline
//   capability_router_blocked     — capability exists, requirements not met (FAIL CLOSED)
//   capability_router_draft       — no capability, fell through to draft
// ============================================================================

// MARK: - Routing Decision

/// The singular output of the Capability Router.
/// Navigation code switches on this — no other signal.
public enum RoutingDecision: Equatable {
    /// Executable capability matched. Route to governed execution pipeline.
    case execute(skillId: String, reason: String)

    /// No executable capability exists. Fall through to draft pipeline.
    case draft(reason: String)

    /// Capability exists but requirements not satisfied. FAIL CLOSED.
    case blocked(reason: String)
}

// MARK: - Capability Match

/// Describes a matched executable capability.
public struct CapabilityMatch: Equatable {
    public let skillId: String
    public let displayName: String
    public let requiredFlags: [String]       // Feature flag keys that must be ON
    public let requiredConnectors: [String]  // Connector IDs that must be registered
    public let riskTier: RiskTier

    public init(
        skillId: String,
        displayName: String,
        requiredFlags: [String],
        requiredConnectors: [String],
        riskTier: RiskTier
    ) {
        self.skillId = skillId
        self.displayName = displayName
        self.requiredFlags = requiredFlags
        self.requiredConnectors = requiredConnectors
        self.riskTier = riskTier
    }
}

// MARK: - Capability Router

@MainActor
public final class CapabilityRouter {

    public static let shared = CapabilityRouter()

    // MARK: - Capability Manifest

    /// Static mapping from IntentRequest.IntentType to executable capabilities.
    /// If an intent type is NOT in this map, it is draft-only.
    /// Adding a new executable capability = adding one entry here.
    private static let capabilityManifest: [IntentRequest.IntentType: CapabilityMatch] = [
        .researchBrief: CapabilityMatch(
            skillId: "web_research",
            displayName: "Governed Web Research",
            requiredFlags: ["webResearchEnabled", "researchHostAllowlistEnabled"],
            requiredConnectors: ["web_fetcher", "brave_search"],
            riskTier: .medium
        )
        // Future: .inboxTriage, .meetingActions, etc.
    ]

    // MARK: - Decide

    /// The SOLE routing decision function.
    /// Called BEFORE navigation. Returns .execute, .draft, or .blocked.
    ///
    /// - Parameters:
    ///   - resolution: The intent resolution from IntentResolver
    /// - Returns: A RoutingDecision that navigation code must honor
    func decide(resolution: IntentResolution) -> RoutingDecision {
        let intentType = resolution.request.intentType

        // 1. Check if an executable capability is registered for this intent type
        guard let match = Self.capabilityManifest[intentType] else {
            let reason = "No executable capability for intent '\(intentType.rawValue)'. Draft path."
            logEvidence(type: "capability_router_draft", detail: reason)
            return .draft(reason: reason)
        }

        // 2. Verify skill is registered in SkillRegistry
        let registry = SkillRegistry.shared
        guard registry.skill(for: match.skillId) != nil else {
            let reason = "Capability '\(match.skillId)' declared but not registered in SkillRegistry. BLOCKED."
            logEvidence(type: "capability_router_blocked", detail: reason)
            return .blocked(reason: reason)
        }

        // 3. Verify required feature flags
        for flagKey in match.requiredFlags {
            if !checkFlag(flagKey) {
                let reason = "Capability '\(match.displayName)' requires flag '\(flagKey)' = ON. Currently OFF. BLOCKED."
                logEvidence(type: "capability_router_blocked", detail: reason)
                return .blocked(reason: reason)
            }
        }

        // 4. Verify required connectors are registered in manifest registry
        for connectorId in match.requiredConnectors {
            if ConnectorManifestRegistry.manifest(for: connectorId) == nil {
                let reason = "Capability '\(match.displayName)' requires connector '\(connectorId)'. Not registered. BLOCKED."
                logEvidence(type: "capability_router_blocked", detail: reason)
                return .blocked(reason: reason)
            }
        }

        // 5. All checks passed — route to execution
        let reason = "Capability '\(match.displayName)' matched for intent '\(intentType.rawValue)'. " +
            "Skill=\(match.skillId), flags=OK, connectors=OK. Routing to execution."
        logEvidence(type: "capability_router_execute", detail: reason)
        return .execute(skillId: match.skillId, reason: reason)
    }

    // MARK: - Flag Checking

    private func checkFlag(_ key: String) -> Bool {
        switch key {
        case "webResearchEnabled":
            return EnterpriseFeatureFlags.webResearchEnabled
        case "researchHostAllowlistEnabled":
            return EnterpriseFeatureFlags.researchHostAllowlistEnabled
        default:
            // Unknown flag → fail closed
            return false
        }
    }

    // MARK: - Evidence

    private func logEvidence(type: String, detail: String) {
        try? EvidenceEngine.shared.logGenericArtifact(
            type: type,
            planId: UUID(),
            jsonString: """
            {"detail":"\(detail)","timestamp":"\(Date().ISO8601Format())"}
            """
        )
    }
}

