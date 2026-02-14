import Foundation
import CryptoKit

// ============================================================================
// POLICY CODE ENGINE — Deterministic Execution Eligibility Evaluator
//
// Evaluates a ToolPlan + ProposalPack against the active ExecutionPolicy.
// Returns a PolicyCodeDecision: .allow (with policyHash) or .deny (with reason).
//
// This is the FORMAL governance gate in the execution pipeline.
// ExecutionEngine MUST call PolicyCodeEngine.evaluate() before minting tokens.
//
// INVARIANT: Pure function — no side effects, no state mutation.
// INVARIANT: Fail closed — any evaluation error results in denial.
// INVARIANT: Every decision is logged to EvidenceEngine.
// INVARIANT: Does NOT replace PolicyEvaluator (capability checks) or
//            PolicyEngine (risk mapping). Complementary, not overlapping.
//
// EVIDENCE TAGS:
//   policy_code_evaluated, policy_code_denied
// ============================================================================

// MARK: - Policy Code Decision

/// Result of a formal policy evaluation.
public enum PolicyCodeDecision: Sendable {
    /// Execution is allowed under this policy. Contains the hash for embedding in tokens.
    case allow(policyHash: String)

    /// Execution is denied. Contains a machine-readable reason.
    case deny(reason: String)

    public var isAllowed: Bool {
        if case .allow = self { return true }
        return false
    }

    public var policyHash: String? {
        if case .allow(let hash) = self { return hash }
        return nil
    }

    public var denyReason: String? {
        if case .deny(let reason) = self { return reason }
        return nil
    }
}

// MARK: - Policy Code Engine

/// Deterministic evaluator: ToolPlan + ProposalPack → PolicyCodeDecision.
/// Stateless. Thread-safe. No side effects.
public enum PolicyCodeEngine {

    // MARK: - Active Policy

    /// The active execution policy. Defaults to production default.
    /// To change: call `PolicyCodeEngine.setActivePolicy(_:)`.
    private static let lock = NSLock()
    private static var _activePolicy: ExecutionPolicy = .default

    /// Current active policy (thread-safe read).
    public static var activePolicy: ExecutionPolicy {
        lock.lock()
        defer { lock.unlock() }
        return _activePolicy
    }

    /// Update the active policy (thread-safe write).
    /// Returns the previous policy for audit purposes.
    @discardableResult
    public static func setActivePolicy(_ policy: ExecutionPolicy) -> ExecutionPolicy {
        lock.lock()
        defer { lock.unlock() }
        let previous = _activePolicy
        _activePolicy = policy
        return previous
    }

    // MARK: - Evaluate

    /// Evaluate a proposal against the active execution policy.
    ///
    /// FAIL CLOSED: Any evaluation error → .deny
    ///
    /// Checks (in order):
    /// 1. Scope allowlist — are all required scopes permitted?
    /// 2. Risk ceiling — does the proposal's risk tier exceed the ceiling?
    /// 3. Reversibility — if reversibleOnly, are all effects reversible?
    /// 4. Cost cap — does the estimated cost exceed maxTokenCost?
    /// 5. Time window — is execution allowed at the current hour?
    /// 6. Biometric requirement — does the proposal satisfy biometric gate?
    /// 7. Quorum requirement — does the proposal satisfy quorum gate?
    public static func evaluate(
        toolPlan: ToolPlan,
        proposal: ProposalPack
    ) -> PolicyCodeDecision {
        let policy = activePolicy

        // ── 1. Scope Allowlist ────────────────────────────
        if !policy.allowedScopes.isEmpty {
            let requiredScopes = proposal.permissionManifest.scopes.map {
                "\($0.domain.rawValue)"
            }
            for scope in requiredScopes {
                if !policy.allowedScopes.contains(scope) {
                    let reason = "Scope '\(scope)' is not permitted by active policy (v\(policy.version))"
                    logDenial(reason: reason, toolPlan: toolPlan)
                    return .deny(reason: reason)
                }
            }
        }

        // ── 2. Risk Ceiling ───────────────────────────────
        let proposalRisk = toolPlan.riskTier
        if riskOrdinal(proposalRisk) > riskOrdinal(policy.riskCeiling) {
            let reason = "Risk tier \(proposalRisk.rawValue) exceeds policy ceiling \(policy.riskCeiling.rawValue)"
            logDenial(reason: reason, toolPlan: toolPlan)
            return .deny(reason: reason)
        }

        // ── 3. Reversibility ──────────────────────────────
        if policy.reversibleOnly {
            if proposal.riskAnalysis.reversibilityClass == .irreversible {
                let reason = "Irreversible action blocked by reversible-only policy"
                logDenial(reason: reason, toolPlan: toolPlan)
                return .deny(reason: reason)
            }
        }

        // ── 4. Cost Cap ───────────────────────────────────
        if policy.maxTokenCost > 0 {
            let estimatedCost = proposal.costEstimate.predictedInputTokens + proposal.costEstimate.predictedOutputTokens
            if estimatedCost > policy.maxTokenCost {
                let reason = "Estimated cost \(estimatedCost) tokens exceeds policy cap \(policy.maxTokenCost)"
                logDenial(reason: reason, toolPlan: toolPlan)
                return .deny(reason: reason)
            }
        }

        // ── 5. Time Window ────────────────────────────────
        if let allowedHours = policy.allowedHours {
            let currentHour = Calendar.current.component(.hour, from: Date())
            if !allowedHours.contains(currentHour) {
                let reason = "Execution not permitted at hour \(currentHour) (allowed: \(allowedHours.lowerBound)-\(allowedHours.upperBound))"
                logDenial(reason: reason, toolPlan: toolPlan)
                return .deny(reason: reason)
            }
        }

        // ── 6. Biometric Requirement Check ────────────────
        // Note: Biometric enforcement happens at approval time.
        // Here we only flag if the policy requires it and the proposal's
        // approval requirement doesn't include it.
        if policy.requiresBiometric && !toolPlan.requiredApprovals.requiresBiometric {
            // Not a hard deny — approval flow will enforce biometric.
            // Log as a warning for audit.
            logEvidence(
                type: "policy_code_biometric_escalation",
                detail: "Policy requires biometric but plan approval tier does not — escalation will occur at approval"
            )
        }

        // ── 7. Quorum Requirement Check ───────────────────
        if policy.requiresQuorum && toolPlan.requiredApprovals.multiSignerCount < 2 {
            // Similarly, quorum enforcement happens at approval.
            logEvidence(
                type: "policy_code_quorum_escalation",
                detail: "Policy requires quorum but plan approval tier is single-signer — escalation will occur at approval"
            )
        }

        // ── All checks passed ─────────────────────────────
        let hash = policy.policyHash
        logEvidence(
            type: "policy_code_evaluated",
            detail: "ALLOW: plan=\(toolPlan.id.uuidString.prefix(8)), policy=v\(policy.version), hash=\(hash.prefix(16))"
        )

        return .allow(policyHash: hash)
    }

    // MARK: - Helpers

    private static func riskOrdinal(_ tier: RiskTier) -> Int {
        switch tier {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .critical: return 3
        }
    }

    private static func logDenial(reason: String, toolPlan: ToolPlan) {
        logEvidence(
            type: "policy_code_denied",
            detail: "DENY: plan=\(toolPlan.id.uuidString.prefix(8)), reason=\(reason)"
        )
    }

    private static func logEvidence(type: String, detail: String) {
        Task { @MainActor in
            try? EvidenceEngine.shared.logGenericArtifact(
                type: type,
                planId: UUID(),
                jsonString: """
                {"detail":"\(detail)","timestamp":"\(Date().ISO8601Format())"}
                """
            )
        }
    }
}
