import Foundation

// ============================================================================
// CLOUD MODEL TYPES — GOVERNED INTELLIGENCE ROUTING
//
// These types define the contract between CapabilityKernel and ModelRouter
// for governed model call decisions.
//
// INVARIANT: ModelProvider selection is Kernel-owned.
// INVARIANT: Cloud calls require ModelCallToken (kernel-issued).
// INVARIANT: All decisions and calls are evidence-logged.
// ============================================================================

// MARK: - Model Provider

/// Identifies the intelligence provider tier.
/// Kernel decides which provider is allowed based on risk + policy + flags.
public enum ModelProvider: String, Codable, Sendable {
    case onDevice       = "on_device"
    case cloudOpenAI    = "cloud_openai"
    case cloudAnthropic = "cloud_anthropic"

    public var isCloud: Bool {
        self == .cloudOpenAI || self == .cloudAnthropic
    }

    public var displayName: String {
        switch self {
        case .onDevice:       return "On-Device"
        case .cloudOpenAI:    return "OpenAI"
        case .cloudAnthropic: return "Anthropic"
        }
    }
}

// MARK: - Model Call Request

/// A request to call a model, submitted to CapabilityKernel for evaluation.
public struct ModelCallRequest: Codable, Sendable {
    public let id: UUID
    public let intentType: String
    public let riskTierHint: String?
    public let requestedProvider: ModelProvider?
    public let contextSummaryRedacted: String
    public let timestamp: Date

    public init(
        intentType: String,
        riskTierHint: String? = nil,
        requestedProvider: ModelProvider? = nil,
        contextSummaryRedacted: String
    ) {
        self.id = UUID()
        self.intentType = intentType
        self.riskTierHint = riskTierHint
        self.requestedProvider = requestedProvider
        self.contextSummaryRedacted = contextSummaryRedacted
        self.timestamp = Date()
    }
}

// MARK: - Model Call Decision

/// Kernel's policy decision for a model call.
/// Returned by CapabilityKernel.evaluateModelCallEligibility().
public struct ModelCallDecision: Codable, Sendable {
    public let allowed: Bool
    public let provider: ModelProvider
    public let requiresHumanApproval: Bool
    public let riskTier: String
    public let reason: String
    public let requestId: UUID

    public init(
        allowed: Bool,
        provider: ModelProvider,
        requiresHumanApproval: Bool,
        riskTier: String,
        reason: String,
        requestId: UUID
    ) {
        self.allowed = allowed
        self.provider = provider
        self.requiresHumanApproval = requiresHumanApproval
        self.riskTier = riskTier
        self.reason = reason
        self.requestId = requestId
    }

    /// Decision that denies cloud and routes to on-device.
    public static func onDeviceOnly(requestId: UUID, reason: String) -> ModelCallDecision {
        ModelCallDecision(
            allowed: true,
            provider: .onDevice,
            requiresHumanApproval: false,
            riskTier: "low",
            reason: reason,
            requestId: requestId
        )
    }

    /// Decision that denies all model calls.
    public static func denied(requestId: UUID, reason: String) -> ModelCallDecision {
        ModelCallDecision(
            allowed: false,
            provider: .onDevice,
            requiresHumanApproval: false,
            riskTier: "critical",
            reason: reason,
            requestId: requestId
        )
    }
}

// MARK: - Model Call Response (for evidence)

/// Redacted record of a model call response, stored in evidence.
public struct ModelCallResponseRecord: Codable, Sendable {
    public let requestId: UUID
    public let provider: ModelProvider
    public let success: Bool
    public let latencyMs: Int
    public let outputLengthChars: Int
    public let confidence: Double?
    public let errorMessage: String?
    /// Which on-device backend was used (e.g. "structured_on_device_v1")
    public let backendId: String?
    public let timestamp: Date

    public init(
        requestId: UUID,
        provider: ModelProvider,
        success: Bool,
        latencyMs: Int,
        outputLengthChars: Int,
        confidence: Double? = nil,
        errorMessage: String? = nil,
        backendId: String? = nil
    ) {
        self.requestId = requestId
        self.provider = provider
        self.success = success
        self.latencyMs = latencyMs
        self.outputLengthChars = outputLengthChars
        self.confidence = confidence
        self.errorMessage = errorMessage
        self.backendId = backendId
        self.timestamp = Date()
    }
}

// MARK: - Governed Model Result

/// Result of a governed model generation call.
/// Surfaces routing decisions to the UI layer.
enum GovernedModelResult {
    /// Generation succeeded. Output ready for pipeline.
    case success(output: DraftOutput, provider: ModelProvider)
    /// Kernel denied the call entirely.
    case denied(reason: String)
    /// Human approval required before proceeding with cloud call.
    case requiresApproval(decision: ModelCallDecision)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var output: DraftOutput? {
        if case .success(let output, _) = self { return output }
        return nil
    }

    var provider: ModelProvider? {
        if case .success(_, let provider) = self { return provider }
        return nil
    }
}

// MARK: - Cloud Model Error

public enum CloudModelError: Error, LocalizedError {
    case featureFlagDisabled(ModelProvider)
    case noModelCallToken
    case tokenExpired
    case tokenInvalidSignature
    case tokenAlreadyConsumed
    case apiKeyMissing(ModelProvider)
    case domainNotAllowed(String)
    case requestFailed(String)
    case responseParseFailed(String)
    case requiresHumanApproval
    case redactionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .featureFlagDisabled(let p): return "Cloud provider \(p.displayName) is disabled"
        case .noModelCallToken:           return "No ModelCallToken issued for cloud call"
        case .tokenExpired:               return "ModelCallToken has expired"
        case .tokenInvalidSignature:      return "ModelCallToken signature verification failed"
        case .tokenAlreadyConsumed:       return "ModelCallToken already consumed (one-use)"
        case .apiKeyMissing(let p):       return "API key not configured for \(p.displayName)"
        case .domainNotAllowed(let d):    return "Domain not in allowlist: \(d)"
        case .requestFailed(let r):       return "Cloud request failed: \(r)"
        case .responseParseFailed(let r): return "Failed to parse cloud response: \(r)"
        case .requiresHumanApproval:      return "Human approval required before cloud model call"
        case .redactionFailed(let r):     return "Data redaction failed: \(r)"
        }
    }
}
