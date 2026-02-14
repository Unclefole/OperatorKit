import Foundation

// ============================================================================
// MODEL CAPABILITY REGISTRY — STRUCTURED PROVIDER CATALOG
//
// Defines what each model can do, its cost, quality, and constraints.
// Used by ModelRoutingPolicy to select the cheapest sufficient provider.
//
// INVARIANT: supportsTools is always FALSE (tools imply action risk).
// INVARIANT: Registry is read-only at runtime; models are statically declared.
// ============================================================================

// MARK: - Model Capability

public struct RegisteredModelCapability: Identifiable, Sendable {
    public let id: String                  // e.g. "gpt-4o-mini", "on-device-structured"
    public let provider: ModelProvider
    public let modelId: String             // API model ID or backend ID
    public let displayName: String
    public let qualityTier: ModelQualityTier
    public let costTier: ModelCostTier
    public let supportsJSON: Bool
    public let supportsTools: Bool         // MUST be false for safety
    public let maxContextTokens: Int
    public let estimatedCostPerInputToken: Double   // USD
    public let estimatedCostPerOutputToken: Double  // USD

    /// Estimate cost in cents for a given input/output token count
    public func estimateCostCents(inputTokens: Int, outputTokens: Int) -> Double {
        let costUSD = (Double(inputTokens) * estimatedCostPerInputToken)
                    + (Double(outputTokens) * estimatedCostPerOutputToken)
        return costUSD * 100.0 // convert to cents
    }

    /// Whether this model can handle a given task type
    public func canHandle(taskType: ModelTaskType) -> Bool {
        // Quality must meet minimum
        guard qualityTier >= taskType.minQualityTier else { return false }
        // JSON support if required
        if taskType.requiresJSON && !supportsJSON { return false }
        return true
    }
}

// MARK: - Registry

public enum ModelCapabilityRegistry {

    // ── On-Device Models ─────────────────────────────────────────

    public static let onDeviceDeterministic = RegisteredModelCapability(
        id: "on-device-deterministic",
        provider: .onDevice,
        modelId: "deterministic_template_v2",
        displayName: "Deterministic Templates",
        qualityTier: .low,
        costTier: .free,
        supportsJSON: true,
        supportsTools: false,
        maxContextTokens: 4096,
        estimatedCostPerInputToken: 0,
        estimatedCostPerOutputToken: 0
    )

    public static let onDeviceStructured = RegisteredModelCapability(
        id: "on-device-structured",
        provider: .onDevice,
        modelId: "structured_on_device_v1",
        displayName: "Structured On-Device",
        qualityTier: .medium,
        costTier: .free,
        supportsJSON: true,
        supportsTools: false,
        maxContextTokens: 8192,
        estimatedCostPerInputToken: 0,
        estimatedCostPerOutputToken: 0
    )

    public static let onDeviceCoreML = RegisteredModelCapability(
        id: "on-device-coreml",
        provider: .onDevice,
        modelId: "core_ml",
        displayName: "CoreML Backend",
        qualityTier: .medium,
        costTier: .free,
        supportsJSON: false,
        supportsTools: false,
        maxContextTokens: 2048,
        estimatedCostPerInputToken: 0,
        estimatedCostPerOutputToken: 0
    )

    public static let onDeviceApple = RegisteredModelCapability(
        id: "on-device-apple",
        provider: .onDevice,
        modelId: "apple_on_device",
        displayName: "Apple On-Device",
        qualityTier: .medium,
        costTier: .free,
        supportsJSON: false,
        supportsTools: false,
        maxContextTokens: 4096,
        estimatedCostPerInputToken: 0,
        estimatedCostPerOutputToken: 0
    )

    // ── Cloud Models — Cheap ─────────────────────────────────────

    public static let openAIMini = RegisteredModelCapability(
        id: "openai-gpt4o-mini",
        provider: .cloudOpenAI,
        modelId: "gpt-4o-mini",
        displayName: "GPT-4o Mini",
        qualityTier: .medium,
        costTier: .cheap,
        supportsJSON: true,
        supportsTools: false,
        maxContextTokens: 128000,
        estimatedCostPerInputToken: 0.00000015,   // $0.15/1M
        estimatedCostPerOutputToken: 0.0000006     // $0.60/1M
    )

    public static let anthropicHaiku = RegisteredModelCapability(
        id: "anthropic-haiku",
        provider: .cloudAnthropic,
        modelId: "claude-3-5-haiku-20241022",
        displayName: "Claude Haiku",
        qualityTier: .medium,
        costTier: .cheap,
        supportsJSON: true,
        supportsTools: false,
        maxContextTokens: 200000,
        estimatedCostPerInputToken: 0.0000008,    // $0.80/1M
        estimatedCostPerOutputToken: 0.000004      // $4.00/1M
    )

    // ── Cloud Models — Standard ──────────────────────────────────

    public static let openAI4o = RegisteredModelCapability(
        id: "openai-gpt4o",
        provider: .cloudOpenAI,
        modelId: "gpt-4o",
        displayName: "GPT-4o",
        qualityTier: .high,
        costTier: .standard,
        supportsJSON: true,
        supportsTools: false,
        maxContextTokens: 128000,
        estimatedCostPerInputToken: 0.0000025,    // $2.50/1M
        estimatedCostPerOutputToken: 0.00001       // $10/1M
    )

    public static let anthropicSonnet = RegisteredModelCapability(
        id: "anthropic-sonnet",
        provider: .cloudAnthropic,
        modelId: "claude-sonnet-4-20250514",
        displayName: "Claude Sonnet",
        qualityTier: .high,
        costTier: .standard,
        supportsJSON: true,
        supportsTools: false,
        maxContextTokens: 200000,
        estimatedCostPerInputToken: 0.000003,     // $3.00/1M
        estimatedCostPerOutputToken: 0.000015      // $15/1M
    )

    // ── Cloud Models — Gemini ────────────────────────────────────

    public static let geminiFlash = RegisteredModelCapability(
        id: "gemini-flash",
        provider: .cloudGemini,
        modelId: "gemini-2.0-flash",
        displayName: "Gemini 2.0 Flash",
        qualityTier: .medium,
        costTier: .cheap,
        supportsJSON: true,
        supportsTools: false,
        maxContextTokens: 1048576,                 // 1M context window
        estimatedCostPerInputToken: 0.0000000375,  // $0.0375/1M
        estimatedCostPerOutputToken: 0.00000015     // $0.15/1M
    )

    public static let geminiPro = RegisteredModelCapability(
        id: "gemini-pro",
        provider: .cloudGemini,
        modelId: "gemini-2.5-pro-preview-05-06",
        displayName: "Gemini 2.5 Pro",
        qualityTier: .high,
        costTier: .standard,
        supportsJSON: true,
        supportsTools: false,
        maxContextTokens: 1048576,
        estimatedCostPerInputToken: 0.00000125,    // $1.25/1M
        estimatedCostPerOutputToken: 0.00001        // $10/1M
    )

    // ── Cloud Models — Groq (Llama) ─────────────────────────────

    public static let groqLlama = RegisteredModelCapability(
        id: "groq-llama-70b",
        provider: .cloudGroq,
        modelId: "llama-3.3-70b-versatile",
        displayName: "Llama 3.3 70B (Groq)",
        qualityTier: .medium,
        costTier: .cheap,
        supportsJSON: true,
        supportsTools: false,
        maxContextTokens: 128000,
        estimatedCostPerInputToken: 0.00000059,    // $0.59/1M
        estimatedCostPerOutputToken: 0.00000079     // $0.79/1M
    )

    public static let groqMixtral = RegisteredModelCapability(
        id: "groq-mixtral",
        provider: .cloudGroq,
        modelId: "mixtral-8x7b-32768",
        displayName: "Mixtral 8x7B (Groq)",
        qualityTier: .medium,
        costTier: .cheap,
        supportsJSON: true,
        supportsTools: false,
        maxContextTokens: 32768,
        estimatedCostPerInputToken: 0.00000024,    // $0.24/1M
        estimatedCostPerOutputToken: 0.00000024     // $0.24/1M
    )

    // ── Cloud Models — Meta Llama (via Together AI) ─────────────

    public static let llamaTurbo = RegisteredModelCapability(
        id: "llama-3.3-70b-turbo",
        provider: .cloudLlama,
        modelId: "meta-llama/Llama-3.3-70B-Instruct-Turbo",
        displayName: "Llama 3.3 70B Turbo",
        qualityTier: .high,
        costTier: .cheap,
        supportsJSON: true,
        supportsTools: false,
        maxContextTokens: 131072,
        estimatedCostPerInputToken: 0.00000088,    // $0.88/1M
        estimatedCostPerOutputToken: 0.00000088     // $0.88/1M
    )

    public static let llama8b = RegisteredModelCapability(
        id: "llama-3.1-8b",
        provider: .cloudLlama,
        modelId: "meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo",
        displayName: "Llama 3.1 8B",
        qualityTier: .medium,
        costTier: .cheap,
        supportsJSON: true,
        supportsTools: false,
        maxContextTokens: 131072,
        estimatedCostPerInputToken: 0.00000018,    // $0.18/1M
        estimatedCostPerOutputToken: 0.00000018     // $0.18/1M
    )

    // ── All Models ───────────────────────────────────────────────

    public static let allModels: [RegisteredModelCapability] = [
        onDeviceDeterministic,
        onDeviceStructured,
        onDeviceCoreML,
        onDeviceApple,
        openAIMini,
        anthropicHaiku,
        openAI4o,
        anthropicSonnet,
        geminiFlash,
        geminiPro,
        groqLlama,
        groqMixtral,
        llamaTurbo,
        llama8b
    ]

    /// Find all models that can handle a given task type, sorted cheapest-first.
    public static func candidates(for taskType: ModelTaskType) -> [RegisteredModelCapability] {
        allModels
            .filter { $0.canHandle(taskType: taskType) }
            .sorted { $0.costTier < $1.costTier }
    }

    /// Find model by ID.
    public static func model(id: String) -> RegisteredModelCapability? {
        allModels.first { $0.id == id }
    }
}
