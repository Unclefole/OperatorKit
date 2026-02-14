import Foundation
import os.log

// ============================================================================
// GOVERNED MODEL CLIENT — UNIFIED PROVIDER ADAPTER PROTOCOL
//
// All model providers (local + cloud) implement this protocol.
// ModelRouter calls adapters ONLY through this interface.
//
// INVARIANT: Adapters MUST NOT call ExecutionEngine or mint tokens.
// INVARIANT: Cloud adapters MUST route through NetworkPolicyEnforcer.
// INVARIANT: All calls are evidence-logged by the router (not the adapter).
// ============================================================================

// MARK: - Model Request / Response

public struct GovernedModelRequest: Sendable {
    public let id: UUID
    public let taskType: ModelTaskType
    public let systemPrompt: String
    public let userPrompt: String
    public let maxOutputTokens: Int
    public let requiresJSON: Bool
    public let temperature: Double

    public init(
        taskType: ModelTaskType,
        systemPrompt: String,
        userPrompt: String,
        maxOutputTokens: Int? = nil,
        requiresJSON: Bool? = nil,
        temperature: Double = 0.3
    ) {
        self.id = UUID()
        self.taskType = taskType
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.maxOutputTokens = maxOutputTokens ?? taskType.maxTokensSoft
        self.requiresJSON = requiresJSON ?? taskType.requiresJSON
        self.temperature = temperature
    }
}

public struct GovernedModelResponse: Sendable {
    public let text: String
    public let modelId: String
    public let provider: ModelProvider
    public let inputTokens: Int
    public let outputTokens: Int
    public let latencyMs: Int
    public let costCents: Double     // 0 for on-device

    public init(
        text: String,
        modelId: String,
        provider: ModelProvider,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        latencyMs: Int = 0,
        costCents: Double = 0
    ) {
        self.text = text
        self.modelId = modelId
        self.provider = provider
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.latencyMs = latencyMs
        self.costCents = costCents
    }
}

// MARK: - Protocol

public protocol GovernedModelClient: Sendable {
    var providerId: ModelProvider { get }
    var modelId: String { get }
    var isAvailable: Bool { get }

    /// Execute a governed model request.
    /// Cloud clients MUST verify ModelCallToken, use DataDiode, and route via NetworkPolicyEnforcer.
    func execute(request: GovernedModelRequest) async throws -> GovernedModelResponse
}

// MARK: - Local Model Adapter

/// Adapter wrapping the existing on-device backend for the governed protocol.
/// Never touches the network. Always free.
public final class LocalModelClientAdapter: GovernedModelClient, @unchecked Sendable {
    public let providerId: ModelProvider = .onDevice
    public let modelId: String

    public init() {
        self.modelId = ModelBackend.structuredOnDevice.rawValue
    }

    init(backend: ModelBackend) {
        self.modelId = backend.rawValue
    }

    public var isAvailable: Bool { true }

    public func execute(request: GovernedModelRequest) async throws -> GovernedModelResponse {
        let start = Date()
        let outputType = Self.mapTaskTypeToOutput(request.taskType)

        // Build ModelInput for the existing on-device pipeline
        let input = ModelInput(
            intentText: request.userPrompt,
            contextSummary: request.systemPrompt,
            outputType: outputType,
            contextItems: ModelInput.ContextItems(
                calendarItems: [],
                emailItems: [],
                fileItems: []
            )
        )

        let router = await ModelRouter.shared
        let output = try await router.generate(input: input)
        let latency = Int(Date().timeIntervalSince(start) * 1000)

        return GovernedModelResponse(
            text: output.draftBody,
            modelId: await router.currentModelId,
            provider: .onDevice,
            inputTokens: request.userPrompt.count / 4,
            outputTokens: output.draftBody.count / 4,
            latencyMs: latency,
            costCents: 0
        )
    }

    static func mapTaskTypeToOutput(_ taskType: ModelTaskType) -> DraftOutput.OutputType {
        switch taskType {
        case .draftEmail, .supportReply, .marketingCampaignCopy, .complianceRewrite:
            return .emailDraft
        case .summarizeMeeting, .scoutAnalysis:
            return .meetingSummary
        case .extractActionItems, .intentClassification, .planSynthesis, .proposalGeneration:
            return .taskList
        case .extractInformation, .webDocumentAnalysis:
            return .documentSummary
        case .researchBrief:
            return .researchBrief
        }
    }
}

// MARK: - OpenAI Adapter

/// Adapter wrapping the existing OpenAIClient for the governed protocol.
/// Requires ModelCallToken gating (handled by the router, not this adapter).
public final class OpenAIClientAdapter: GovernedModelClient, @unchecked Sendable {
    public let providerId: ModelProvider = .cloudOpenAI
    public let modelId: String

    private let capability: RegisteredModelCapability

    public init(capability: RegisteredModelCapability = ModelCapabilityRegistry.openAIMini) {
        self.capability = capability
        self.modelId = capability.modelId
    }

    public var isAvailable: Bool {
        IntelligenceFeatureFlags.openAIEnabled
    }

    public func execute(request: GovernedModelRequest) async throws -> GovernedModelResponse {
        let start = Date()
        let client = await OpenAIClient.shared

        // DataDiode redaction
        let (redactedUser, _) = DataDiode.tokenize(request.userPrompt)
        let (redactedSystem, _) = DataDiode.tokenize(request.systemPrompt)

        let response = try await client.generate(
            systemPrompt: redactedSystem,
            userPrompt: redactedUser
        )

        let latency = Int(Date().timeIntervalSince(start) * 1000)
        let inputTokens = (request.systemPrompt.count + request.userPrompt.count) / 4
        let outputTokens = response.content.count / 4
        let costCents = capability.estimateCostCents(inputTokens: inputTokens, outputTokens: outputTokens)

        return GovernedModelResponse(
            text: response.content,
            modelId: modelId,
            provider: .cloudOpenAI,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            latencyMs: latency,
            costCents: costCents
        )
    }
}

// MARK: - Anthropic Adapter

/// Adapter wrapping the existing AnthropicClient for the governed protocol.
public final class AnthropicClientAdapter: GovernedModelClient, @unchecked Sendable {
    public let providerId: ModelProvider = .cloudAnthropic
    public let modelId: String

    private let capability: RegisteredModelCapability

    public init(capability: RegisteredModelCapability = ModelCapabilityRegistry.anthropicHaiku) {
        self.capability = capability
        self.modelId = capability.modelId
    }

    public var isAvailable: Bool {
        IntelligenceFeatureFlags.anthropicEnabled
    }

    public func execute(request: GovernedModelRequest) async throws -> GovernedModelResponse {
        let start = Date()
        let client = await AnthropicClient.shared

        // DataDiode redaction
        let (redactedUser, _) = DataDiode.tokenize(request.userPrompt)
        let (redactedSystem, _) = DataDiode.tokenize(request.systemPrompt)

        let response = try await client.generate(
            systemPrompt: redactedSystem,
            userPrompt: redactedUser
        )

        let latency = Int(Date().timeIntervalSince(start) * 1000)
        let inputTokens = (request.systemPrompt.count + request.userPrompt.count) / 4
        let outputTokens = response.content.count / 4
        let costCents = capability.estimateCostCents(inputTokens: inputTokens, outputTokens: outputTokens)

        return GovernedModelResponse(
            text: response.content,
            modelId: modelId,
            provider: .cloudAnthropic,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            latencyMs: latency,
            costCents: costCents
        )
    }
}

// MARK: - Gemini Adapter

/// Adapter wrapping GeminiClient for the governed protocol.
public final class GeminiClientAdapter: GovernedModelClient, @unchecked Sendable {
    public let providerId: ModelProvider = .cloudGemini
    public let modelId: String

    public init(modelId: String = "gemini-2.0-flash") {
        self.modelId = modelId
    }

    public var isAvailable: Bool {
        IntelligenceFeatureFlags.geminiEnabled
    }

    public func execute(request: GovernedModelRequest) async throws -> GovernedModelResponse {
        let start = Date()
        let client = GeminiClient.shared

        // DataDiode redaction
        let (redactedUser, _) = DataDiode.tokenize(request.userPrompt)
        let (redactedSystem, _) = DataDiode.tokenize(request.systemPrompt)

        let response = try await client.generate(
            systemPrompt: redactedSystem,
            userPrompt: redactedUser,
            model: modelId
        )

        let latency = Int(Date().timeIntervalSince(start) * 1000)
        let inputTokens = response.promptTokens ?? ((request.systemPrompt.count + request.userPrompt.count) / 4)
        let outputTokens = response.completionTokens ?? (response.content.count / 4)
        // Gemini Flash pricing: ~$0.0375 per 1M input, ~$0.15 per 1M output
        let costCents = (Double(inputTokens) * 0.00000375 + Double(outputTokens) * 0.000015) * 100

        return GovernedModelResponse(
            text: response.content,
            modelId: modelId,
            provider: .cloudGemini,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            latencyMs: latency,
            costCents: costCents
        )
    }
}

// MARK: - Groq Adapter

/// Adapter wrapping GroqClient for the governed protocol.
/// Provides ultra-fast inference via Groq's LPU hardware.
public final class GroqClientAdapter: GovernedModelClient, @unchecked Sendable {
    public let providerId: ModelProvider = .cloudGroq
    public let modelId: String

    public init(modelId: String = "llama-3.3-70b-versatile") {
        self.modelId = modelId
    }

    public var isAvailable: Bool {
        IntelligenceFeatureFlags.groqEnabled
    }

    public func execute(request: GovernedModelRequest) async throws -> GovernedModelResponse {
        let start = Date()
        let client = GroqClient.shared

        // DataDiode redaction
        let (redactedUser, _) = DataDiode.tokenize(request.userPrompt)
        let (redactedSystem, _) = DataDiode.tokenize(request.systemPrompt)

        let response = try await client.generate(
            systemPrompt: redactedSystem,
            userPrompt: redactedUser,
            model: modelId
        )

        let latency = Int(Date().timeIntervalSince(start) * 1000)
        let inputTokens = response.promptTokens ?? ((request.systemPrompt.count + request.userPrompt.count) / 4)
        let outputTokens = response.completionTokens ?? (response.content.count / 4)
        // Groq Llama 3.3 70B pricing: ~$0.59 per 1M input, ~$0.79 per 1M output
        let costCents = (Double(inputTokens) * 0.00000059 + Double(outputTokens) * 0.00000079) * 100

        return GovernedModelResponse(
            text: response.content,
            modelId: modelId,
            provider: .cloudGroq,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            latencyMs: latency,
            costCents: costCents
        )
    }
}

// MARK: - Meta Llama Adapter (via Together AI)

/// Adapter wrapping TogetherLlamaClient for the governed protocol.
/// Provides access to Meta's Llama models through Together AI.
public final class LlamaClientAdapter: GovernedModelClient, @unchecked Sendable {
    public let providerId: ModelProvider = .cloudLlama
    public let modelId: String

    public init(modelId: String = "meta-llama/Llama-3.3-70B-Instruct-Turbo") {
        self.modelId = modelId
    }

    public var isAvailable: Bool {
        IntelligenceFeatureFlags.llamaEnabled
    }

    public func execute(request: GovernedModelRequest) async throws -> GovernedModelResponse {
        let start = Date()
        let client = TogetherLlamaClient.shared

        // DataDiode redaction
        let (redactedUser, _) = DataDiode.tokenize(request.userPrompt)
        let (redactedSystem, _) = DataDiode.tokenize(request.systemPrompt)

        let response = try await client.generate(
            systemPrompt: redactedSystem,
            userPrompt: redactedUser,
            model: modelId
        )

        let latency = Int(Date().timeIntervalSince(start) * 1000)
        let inputTokens = response.promptTokens ?? ((request.systemPrompt.count + request.userPrompt.count) / 4)
        let outputTokens = response.completionTokens ?? (response.content.count / 4)
        // Together AI Llama 3.3 70B pricing: ~$0.88 per 1M input, ~$0.88 per 1M output
        let costCents = (Double(inputTokens) * 0.00000088 + Double(outputTokens) * 0.00000088) * 100

        return GovernedModelResponse(
            text: response.content,
            modelId: modelId,
            provider: .cloudLlama,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            latencyMs: latency,
            costCents: costCents
        )
    }
}
