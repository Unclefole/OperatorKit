import Foundation

// MARK: - Model Backend Enum

/// Identifies which backend is being used for draft generation
/// INVARIANT: All backends must be strictly on-device (no network)
enum ModelBackend: String, Codable, CaseIterable {
    case appleOnDevice = "apple_on_device"  // Apple Foundation Models (iOS 18.1+)
    case coreML = "core_ml"                  // Bundled Core ML model
    case deterministic = "deterministic"     // Template-based (always available fallback)
    
    var displayName: String {
        switch self {
        case .appleOnDevice: return "Apple On-Device"
        case .coreML: return "Core ML"
        case .deterministic: return "Deterministic Templates"
        }
    }
    
    var isMLBased: Bool {
        self == .appleOnDevice || self == .coreML
    }
    
    /// Priority for selection (lower = higher priority)
    var selectionPriority: Int {
        switch self {
        case .appleOnDevice: return 0
        case .coreML: return 1
        case .deterministic: return 99  // Fallback
        }
    }
}

// MARK: - Model Capabilities

/// Describes what tasks a model backend can handle
struct ModelCapabilities: Equatable, Codable {
    let canSummarize: Bool
    let canDraftEmail: Bool
    let canExtractActions: Bool
    let canGenerateReminder: Bool
    let maxInputTokens: Int?
    let maxOutputTokens: Int?
    
    /// Default capabilities for deterministic model
    static let deterministic = ModelCapabilities(
        canSummarize: true,
        canDraftEmail: true,
        canExtractActions: true,
        canGenerateReminder: true,
        maxInputTokens: nil,
        maxOutputTokens: nil
    )
    
    /// Check if capabilities match the required output type
    func supports(outputType: ModelInput.OutputType) -> Bool {
        switch outputType {
        case .emailDraft:
            return canDraftEmail
        case .meetingSummary, .docSummary:
            return canSummarize
        case .taskList:
            return canExtractActions
        }
    }
}

// MARK: - Model Metadata (Extended)

/// Metadata about a model for audit trail
/// Extended in Phase 4A to include more runtime info
struct ModelMetadata: Equatable, Codable {
    let modelId: String
    let displayName: String
    let version: String
    let backend: ModelBackend
    let generatedAt: Date
    
    // Extended fields (Phase 4A)
    let deviceInfo: String?
    let maxOutputChars: Int?
    let latencyMs: Int?
    let capabilities: ModelCapabilities?
    let fallbackReason: String?
    
    init(from model: any OnDeviceModel, latencyMs: Int? = nil, fallbackReason: String? = nil) {
        self.modelId = model.modelId
        self.displayName = model.displayName
        self.version = model.version
        self.backend = model.backend
        self.generatedAt = Date()
        self.deviceInfo = ModelMetadata.currentDeviceInfo()
        self.maxOutputChars = model.maxOutputChars
        self.latencyMs = latencyMs
        self.capabilities = model.capabilities
        self.fallbackReason = fallbackReason
    }
    
    init(
        modelId: String,
        displayName: String,
        version: String,
        backend: ModelBackend = .deterministic,
        generatedAt: Date = Date(),
        deviceInfo: String? = nil,
        maxOutputChars: Int? = nil,
        latencyMs: Int? = nil,
        capabilities: ModelCapabilities? = nil,
        fallbackReason: String? = nil
    ) {
        self.modelId = modelId
        self.displayName = displayName
        self.version = version
        self.backend = backend
        self.generatedAt = generatedAt
        self.deviceInfo = deviceInfo
        self.maxOutputChars = maxOutputChars
        self.latencyMs = latencyMs
        self.capabilities = capabilities
        self.fallbackReason = fallbackReason
    }
    
    private static func currentDeviceInfo() -> String {
        #if os(iOS)
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        return "Unknown"
        #endif
    }
}

// MARK: - On-Device Model Protocol

/// Protocol for on-device draft generation models
/// INVARIANT: All implementations must be on-device only (no network calls)
/// INVARIANT: All outputs are drafts first - never auto-send
/// INVARIANT: Citations must only reference selected context
protocol OnDeviceModel {
    /// Unique identifier for this model backend
    var modelId: String { get }
    
    /// Human-readable name for audit trail
    var displayName: String { get }
    
    /// Version string for tracking
    var version: String { get }
    
    /// Which backend type this model uses
    var backend: ModelBackend { get }
    
    /// Model capabilities
    var capabilities: ModelCapabilities { get }
    
    /// Maximum output characters (nil = unlimited)
    var maxOutputChars: Int? { get }
    
    /// Whether this model is available and ready
    var isAvailable: Bool { get }
    
    /// Detailed availability check with reason if unavailable
    func checkAvailability() -> ModelAvailabilityResult
    
    /// Generate a draft output from the given input
    /// - Parameter input: The model input containing intent, context, and constraints
    /// - Returns: A DraftOutput with confidence, citations, and safety notes
    /// - Throws: ModelError if generation fails
    func generate(input: ModelInput) async throws -> DraftOutput
    
    /// Validate that this model can handle the given input
    func canHandle(input: ModelInput) -> Bool
}

// MARK: - Default Implementations

extension OnDeviceModel {
    /// Default availability check
    var isAvailable: Bool { 
        checkAvailability().isAvailable 
    }
    
    /// Default max output chars
    var maxOutputChars: Int? { nil }
    
    /// Default can handle (checks capabilities)
    func canHandle(input: ModelInput) -> Bool {
        capabilities.supports(outputType: input.outputType)
    }
    
    /// Default availability result
    func checkAvailability() -> ModelAvailabilityResult {
        .available
    }
}

// MARK: - Model Availability Result

/// Result of checking model availability
enum ModelAvailabilityResult {
    case available
    case unavailable(reason: String)
    case degraded(reason: String)  // Available but with limitations
    
    var isAvailable: Bool {
        switch self {
        case .available, .degraded: return true
        case .unavailable: return false
        }
    }
    
    var reason: String? {
        switch self {
        case .available: return nil
        case .unavailable(let reason), .degraded(let reason): return reason
        }
    }
}

// MARK: - Model Error

enum ModelError: Error, LocalizedError {
    case modelNotAvailable(String)
    case inputValidationFailed(String)
    case generationFailed(String)
    case confidenceTooLow(Double)
    case citationGenerationFailed(String)
    case outputFormattingFailed(String)
    case invariantViolation(String)
    case fallbackRequired(originalError: String)
    case timeout(backend: ModelBackend, budgetMs: Int)
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotAvailable(let model):
            return "Model not available: \(model)"
        case .inputValidationFailed(let reason):
            return "Input validation failed: \(reason)"
        case .generationFailed(let reason):
            return "Draft generation failed: \(reason)"
        case .confidenceTooLow(let confidence):
            return "Confidence too low (\(Int(confidence * 100))%) to proceed"
        case .citationGenerationFailed(let reason):
            return "Citation generation failed: \(reason)"
        case .outputFormattingFailed(let reason):
            return "Output formatting failed: \(reason)"
        case .invariantViolation(let invariant):
            return "INVARIANT VIOLATION: \(invariant)"
        case .fallbackRequired(let originalError):
            return "Fallback required: \(originalError)"
        case .timeout(let backend, let budgetMs):
            return "Model generation timed out (\(backend.displayName), budget: \(budgetMs)ms)"
        case .validationFailed(let reason):
            return "Output validation failed: \(reason)"
        }
    }
}

// MARK: - Generation Result (Internal)

/// Internal result type for model generation before normalization
struct RawModelOutput {
    let text: String
    let rawConfidence: Double?
    let inlineCitationMarkers: [String]?  // e.g., "[1]", "[ref:meeting]"
    let suggestedActionItems: [String]?
    let generationTimeMs: Int
    
    init(
        text: String,
        rawConfidence: Double? = nil,
        inlineCitationMarkers: [String]? = nil,
        suggestedActionItems: [String]? = nil,
        generationTimeMs: Int = 0
    ) {
        self.text = text
        self.rawConfidence = rawConfidence
        self.inlineCitationMarkers = inlineCitationMarkers
        self.suggestedActionItems = suggestedActionItems
        self.generationTimeMs = generationTimeMs
    }
}

#if os(iOS)
import UIKit
#endif
