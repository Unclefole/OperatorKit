import Foundation
import os.log

// ============================================================================
// MODEL ROUTING POLICY — CHEAP-FIRST + ESCALATION
//
// Selects the cheapest model that meets task requirements.
// Escalates to stronger models only when output validation fails.
//
// INVARIANT: Local first when quality tier allows.
// INVARIANT: Cloud calls require budget clearance + kernel decision.
// INVARIANT: No execution authority granted by any routing decision.
// ============================================================================

// MARK: - Routing Request

public struct ModelRoutingRequest: Sendable {
    public let taskType: ModelTaskType
    public let riskTier: RiskTier
    public let sensitivity: ModelSensitivityLevel
    public let requiresJSON: Bool
    public let contextTokenEstimate: Int
    public let outputTokenEstimate: Int

    public init(
        taskType: ModelTaskType,
        riskTier: RiskTier = .low,
        sensitivity: ModelSensitivityLevel? = nil,
        requiresJSON: Bool? = nil,
        contextTokenEstimate: Int = 500,
        outputTokenEstimate: Int? = nil
    ) {
        self.taskType = taskType
        self.riskTier = riskTier
        self.sensitivity = sensitivity ?? taskType.defaultSensitivity
        self.requiresJSON = requiresJSON ?? taskType.requiresJSON
        self.contextTokenEstimate = contextTokenEstimate
        self.outputTokenEstimate = outputTokenEstimate ?? taskType.maxTokensSoft
    }
}

// MARK: - Routing Decision

public struct ModelRoutingDecision: Sendable {
    public let candidateChain: [RegisteredModelCapability]  // ordered cheapest→expensive
    public let reason: String
    public let estimatedCostCents: Double
    public let budgetAllowed: Bool
    public let budgetReason: String

    /// The first candidate to try
    public var primaryCandidate: RegisteredModelCapability? { candidateChain.first }

    /// The escalation candidates (tried if primary fails validation)
    public var escalationCandidates: [RegisteredModelCapability] {
        Array(candidateChain.dropFirst())
    }
}

// MARK: - Output Validation Result

public struct ModelOutputValidation: Sendable {
    public let passed: Bool
    public let issues: [String]
    public let confidenceAdjustment: Double  // negative = penalty
    public let shouldEscalate: Bool          // true = try a stronger model

    public static let pass = ModelOutputValidation(
        passed: true, issues: [], confidenceAdjustment: 0, shouldEscalate: false
    )
}

// MARK: - Routing Policy

public enum ModelRoutingPolicy {

    private static let logger = Logger(subsystem: "com.operatorkit", category: "RoutingPolicy")

    /// Select candidate models for a routing request, cheapest first.
    /// Budget check is included — if budget denies, returns on-device only.
    @MainActor
    public static func resolve(
        _ request: ModelRoutingRequest
    ) -> ModelRoutingDecision {
        let budget = ModelBudgetGovernor.shared

        // 1. Get all candidates sorted cheapest-first
        var candidates = ModelCapabilityRegistry.candidates(for: request.taskType)

        // 2. Filter by sensitivity
        switch request.sensitivity {
        case .localOnly:
            candidates = candidates.filter { $0.provider == .onDevice }
        case .cloudAllowed:
            break // all candidates OK
        case .cloudPreferred:
            // Move cloud to front but keep local as fallback
            let cloud = candidates.filter { $0.provider != .onDevice }
            let local = candidates.filter { $0.provider == .onDevice }
            candidates = cloud + local
        }

        // 3. Filter by context size
        candidates = candidates.filter { $0.maxContextTokens >= request.contextTokenEstimate }

        // 4. Ensure at least deterministic fallback
        if candidates.isEmpty {
            candidates = [ModelCapabilityRegistry.onDeviceDeterministic]
        }

        // 5. Estimate cost for primary candidate
        let primary = candidates[0]
        let estimatedCost = primary.estimateCostCents(
            inputTokens: request.contextTokenEstimate,
            outputTokens: request.outputTokenEstimate
        )

        // 6. Budget check
        let budgetDecision = budget.requestAllowance(
            taskType: request.taskType,
            estimatedCostCents: estimatedCost
        )

        if !budgetDecision.allowed && primary.costTier != .free {
            // Budget denied for cloud — fall back to on-device only
            let onDeviceOnly = candidates.filter { $0.costTier == .free }
            let fallbackCandidates = onDeviceOnly.isEmpty
                ? [ModelCapabilityRegistry.onDeviceDeterministic]
                : onDeviceOnly

            logger.warning("Budget denied: \(budgetDecision.reason). Falling back to on-device.")
            return ModelRoutingDecision(
                candidateChain: fallbackCandidates,
                reason: "Budget denied: \(budgetDecision.reason). On-device fallback.",
                estimatedCostCents: 0,
                budgetAllowed: false,
                budgetReason: budgetDecision.reason
            )
        }

        logger.info("Routing \(request.taskType.rawValue): \(candidates.count) candidates, primary=\(primary.id), est=\(self.fmt(estimatedCost))¢")

        return ModelRoutingDecision(
            candidateChain: candidates,
            reason: "Cheapest-first: \(primary.displayName) (\(primary.costTier.rawValue))",
            estimatedCostCents: estimatedCost,
            budgetAllowed: budgetDecision.allowed,
            budgetReason: budgetDecision.reason
        )
    }

    // MARK: - Output Validators

    /// Validate model output against task requirements.
    /// Returns whether output is acceptable or escalation is needed.
    public static func validateOutput(
        _ text: String,
        taskType: ModelTaskType,
        context: String? = nil
    ) -> ModelOutputValidation {
        var issues: [String] = []
        var penalty: Double = 0

        // 1. Non-empty check
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ModelOutputValidation(
                passed: false,
                issues: ["Output is empty"],
                confidenceAdjustment: -1.0,
                shouldEscalate: true
            )
        }

        // 2. Length check
        let charCount = text.count
        let minChars = taskType.requiresJSON ? 10 : 50
        if charCount < minChars {
            issues.append("Output too short (\(charCount) chars, min \(minChars))")
            penalty -= 0.2
        }

        // 3. JSON validity (if required)
        if taskType.requiresJSON {
            if !isValidJSON(text) {
                issues.append("Required JSON output is not valid JSON")
                penalty -= 0.3
                // Escalate — JSON failures are structural
                return ModelOutputValidation(
                    passed: false,
                    issues: issues,
                    confidenceAdjustment: penalty,
                    shouldEscalate: true
                )
            }
        }

        // 4. Email-specific: must have subject + body structure
        if taskType == .draftEmail {
            let hasSubject = text.lowercased().contains("subject:")
                          || text.lowercased().contains("re:")
                          || text.contains("\n\n")
            if !hasSubject {
                issues.append("Email draft missing subject/body structure")
                penalty -= 0.15
            }
        }

        // 5. Hallucination guard: summaries with context should reference it
        if let ctx = context, !ctx.isEmpty,
           (taskType == .summarizeMeeting || taskType == .extractActionItems) {
            // Check that output references at least one keyword from context
            let contextWords = Set(ctx.lowercased().split(separator: " ").map(String.init).filter { $0.count > 4 })
            let outputWords = Set(text.lowercased().split(separator: " ").map(String.init))
            let overlap = contextWords.intersection(outputWords)
            if overlap.count < 2 && contextWords.count > 5 {
                issues.append("Output may not reference provided context (hallucination risk)")
                penalty -= 0.2
            }
        }

        let shouldEscalate = penalty <= -0.3
        return ModelOutputValidation(
            passed: !shouldEscalate,
            issues: issues,
            confidenceAdjustment: penalty,
            shouldEscalate: shouldEscalate
        )
    }

    // MARK: - Helpers

    private static func isValidJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private static func fmt(_ v: Double) -> String { String(format: "%.2f", v) }
}
