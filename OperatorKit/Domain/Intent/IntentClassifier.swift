import Foundation

// ============================================================================
// INTENT CLASSIFIER — Dual-Layer Classification with Risk Escalation
//
// Replaces direct IntentResolver.resolve() calls in UI with a two-layer
// pipeline that produces ClassifiedIntent with risk assessment.
//
// LAYER 1: IntentResolver (keyword matching) — fast, deterministic, offline.
//          This is the EXISTING resolver, kept as-is.
//
// LAYER 2: Rule-based risk escalation — pattern matching for high-risk
//          verbs, scope analysis, confidence gating. Produces risk tiers
//          and escalation flags.
//
// FUTURE LAYER 3: On-device model classification when Apple Foundation
//                 Models are available. Architecture supports it but does
//                 NOT depend on it.
//
// INVARIANT: Low confidence (< 0.65) blocks execution, forces draft-only.
// INVARIANT: High-risk verb detection escalates regardless of intent type.
// INVARIANT: Fail closed — classification failure → blocked.
// INVARIANT: IntentResolver is NOT replaced — it's wrapped.
//
// EVIDENCE TAGS:
//   intent_classified, intent_low_confidence_block, intent_risk_escalated
// ============================================================================

// MARK: - Classified Intent

/// Output of the dual-layer classification pipeline.
/// Contains the original intent resolution PLUS risk assessment and escalation data.
struct ClassifiedIntent {
    /// The original intent resolution from Layer 1 (IntentResolver).
    let resolution: IntentResolution

    /// Adjusted confidence after Layer 2 risk analysis.
    let adjustedConfidence: Double

    /// Risk tier assigned by the classifier.
    let riskTier: ClassifiedRiskTier

    /// Whether this intent requires escalation to a higher approval level.
    let requiresEscalation: Bool

    /// Reason for escalation (empty if no escalation needed).
    let escalationReason: String

    /// Whether execution is blocked (low confidence or high risk).
    let executionBlocked: Bool

    /// If blocked, the reason for blocking.
    let blockReason: String?

    /// High-risk verbs detected in the input.
    let detectedRiskVerbs: [String]

    /// Whether draft-only mode is forced.
    var forceDraftOnly: Bool {
        executionBlocked || riskTier == .critical
    }
}

// MARK: - Classified Risk Tier

enum ClassifiedRiskTier: String, CaseIterable {
    case safe = "SAFE"               // Read-only, no side effects
    case standard = "STANDARD"       // Normal operations, standard approval
    case elevated = "ELEVATED"       // High-risk verbs detected, extra scrutiny
    case critical = "CRITICAL"       // Destructive/irreversible patterns, draft-only enforced
}

// MARK: - Intent Classifier

/// Dual-layer intent classification pipeline.
/// Layer 1: IntentResolver (keyword matching)
/// Layer 2: Rule-based risk escalation
enum IntentClassifier {

    // MARK: - Configuration

    /// Minimum confidence threshold for execution. Below this → draft-only.
    static let executionConfidenceThreshold: Double = 0.65

    // MARK: - High-Risk Verb Patterns

    /// Verbs/phrases that trigger risk escalation regardless of intent type.
    private static let highRiskVerbs: [String] = [
        "delete", "remove all", "erase", "destroy", "wipe",
        "send all", "send everything", "forward all",
        "transfer", "authorize", "approve all",
        "revoke", "disable", "deactivate",
        "overwrite", "replace all", "drop",
        "execute immediately", "bypass", "skip approval",
        "bulk send", "mass email", "broadcast"
    ]

    /// Verbs/phrases that indicate elevated risk (not critical, but worth flagging).
    private static let elevatedRiskVerbs: [String] = [
        "send", "post", "publish", "share", "export",
        "modify", "update", "change", "edit",
        "create event", "schedule", "book",
        "submit", "file", "register"
    ]

    /// Phrases that indicate safe, read-only intent.
    private static let safePatterns: [String] = [
        "search", "find", "look up", "research", "analyze",
        "summarize", "review", "read", "check", "show",
        "list", "get", "fetch", "what is", "how does",
        "compare", "investigate", "explore"
    ]

    // MARK: - Classify

    /// Classify user input through the dual-layer pipeline.
    ///
    /// Returns a ClassifiedIntent with:
    /// - Original IntentResolution from Layer 1
    /// - Risk tier and escalation flags from Layer 2
    /// - Execution blocking if confidence < threshold
    static func classify(rawInput: String) -> ClassifiedIntent {
        // ════════════════════════════════════════════════════
        // LAYER 1: IntentResolver (keyword matching)
        // ════════════════════════════════════════════════════
        let resolution = IntentResolver.shared.resolve(rawInput: rawInput)

        // ════════════════════════════════════════════════════
        // LAYER 2: Rule-based risk escalation
        // ════════════════════════════════════════════════════
        let lowercased = rawInput.lowercased()

        // Detect high-risk verbs
        let detectedHighRisk = highRiskVerbs.filter { lowercased.contains($0) }
        let detectedElevated = elevatedRiskVerbs.filter { lowercased.contains($0) }
        let detectedSafe = safePatterns.filter { lowercased.contains($0) }

        // Determine risk tier
        let riskTier: ClassifiedRiskTier
        let requiresEscalation: Bool
        var escalationReason = ""

        if !detectedHighRisk.isEmpty {
            riskTier = .critical
            requiresEscalation = true
            escalationReason = "High-risk verbs detected: \(detectedHighRisk.joined(separator: ", "))"
        } else if !detectedElevated.isEmpty && detectedSafe.isEmpty {
            riskTier = .elevated
            requiresEscalation = detectedElevated.count >= 2
            if requiresEscalation {
                escalationReason = "Multiple elevated-risk verbs: \(detectedElevated.joined(separator: ", "))"
            }
        } else if !detectedSafe.isEmpty && detectedElevated.isEmpty {
            riskTier = .safe
            requiresEscalation = false
        } else {
            riskTier = .standard
            requiresEscalation = false
        }

        // Adjust confidence based on risk analysis
        var adjustedConfidence = resolution.confidence

        // Penalty for high-risk verbs with low base confidence
        if !detectedHighRisk.isEmpty && resolution.confidence < 0.9 {
            adjustedConfidence *= 0.8 // 20% penalty — force more scrutiny
        }

        // Bonus for safe patterns with matching intent
        if riskTier == .safe && resolution.request.intentType == .researchBrief {
            adjustedConfidence = min(1.0, adjustedConfidence * 1.05)
        }

        // ════════════════════════════════════════════════════
        // EXECUTION GATE: Low confidence blocks execution
        // ════════════════════════════════════════════════════
        let executionBlocked: Bool
        let blockReason: String?

        if adjustedConfidence < executionConfidenceThreshold {
            executionBlocked = true
            blockReason = "Confidence \(String(format: "%.2f", adjustedConfidence)) below threshold \(executionConfidenceThreshold) — draft-only mode enforced"
            logEvidence(
                type: "intent_low_confidence_block",
                detail: "input=\(rawInput.prefix(60)), confidence=\(adjustedConfidence), intent=\(resolution.request.intentType.rawValue)"
            )
        } else if riskTier == .critical {
            executionBlocked = true
            blockReason = "Critical risk tier — draft-only mode enforced. Detected: \(detectedHighRisk.joined(separator: ", "))"
        } else {
            executionBlocked = false
            blockReason = nil
        }

        // Log classification
        logEvidence(
            type: requiresEscalation ? "intent_risk_escalated" : "intent_classified",
            detail: "intent=\(resolution.request.intentType.rawValue), conf=\(String(format: "%.2f", adjustedConfidence)), risk=\(riskTier.rawValue), escalated=\(requiresEscalation), blocked=\(executionBlocked)"
        )

        return ClassifiedIntent(
            resolution: resolution,
            adjustedConfidence: adjustedConfidence,
            riskTier: riskTier,
            requiresEscalation: requiresEscalation,
            escalationReason: escalationReason,
            executionBlocked: executionBlocked,
            blockReason: blockReason,
            detectedRiskVerbs: detectedHighRisk + detectedElevated
        )
    }

    // MARK: - Evidence

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
