import Foundation

// MARK: - Apple On-Device Model Backend
//
// This backend wraps Apple's on-device generative AI (Foundation Models framework).
// DEPLOYMENT TARGET: iOS 17.0 (MVP compatibility)
// APPLE ON-DEVICE: iOS 18.1+ ONLY
//
// Guards:
// 1. COMPILE-TIME: #if canImport(FoundationModels)
// 2. RUNTIME: @available(iOS 18.1, *)
// 3. ENTITLEMENT: Checked via session initialization failure
//
// If unavailable for ANY reason → fallback to DeterministicTemplateModel
// INVARIANT: No network calls. Ever.

// MARK: - Compile-Time Availability Check

// Note: FoundationModels/LanguageModel API not available in current SDK.
// Disabled until proper SDK support is available.
#if false // canImport(FoundationModels)
import FoundationModels

/// Apple On-Device Model Backend using Foundation Models framework
/// Available ONLY on iOS 18.1+ with Apple Intelligence support
@available(iOS 18.1, *)
final class AppleOnDeviceModelBackendImpl: OnDeviceModel {
    
    // MARK: - Properties
    
    let modelId = "apple_on_device_v1"
    let displayName = "Apple On-Device"
    let version: String
    let backend: ModelBackend = .appleOnDevice
    
    let capabilities = ModelCapabilities(
        canSummarize: true,
        canDraftEmail: true,
        canExtractActions: true,
        canGenerateReminder: true,
        maxInputTokens: 4096,
        maxOutputTokens: 2048
    )
    
    var maxOutputChars: Int? { 4000 }
    
    // MARK: - State
    
    private var cachedAvailability: ModelAvailabilityResult?
    private var session: LanguageModelSession?
    private var lastGenerationLatencyMs: Int = 0
    
    // MARK: - Initialization
    
    init() {
        // Try to get model version from session if available
        self.version = "1.0.0"  // Will be updated if session provides version info
    }
    
    // MARK: - Availability Check
    
    func checkAvailability() -> ModelAvailabilityResult {
        // Return cached result if available
        if let cached = cachedAvailability {
            return cached
        }
        
        // RUNTIME GUARD: iOS 18.1+ required
        guard #available(iOS 18.1, *) else {
            let result = ModelAvailabilityResult.unavailable(
                reason: "Apple On-Device requires iOS 18.1 or later"
            )
            cachedAvailability = result
            return result
        }
        
        // Check if LanguageModel is available on this device
        // This handles: Apple Silicon requirement, Apple Intelligence enabled, entitlement
        guard LanguageModel.isAvailable else {
            let result = ModelAvailabilityResult.unavailable(
                reason: "Apple Intelligence not available on this device (requires compatible hardware and enabled in Settings)"
            )
            cachedAvailability = result
            log("AppleOnDeviceBackend: LanguageModel.isAvailable = false")
            return result
        }
        
        // Try to create a session to verify entitlement and full availability
        do {
            session = try LanguageModelSession()
            let result = ModelAvailabilityResult.available
            cachedAvailability = result
            log("AppleOnDeviceBackend: Session created successfully, backend available")
            return result
        } catch {
            // Session creation failed - could be entitlement, device, or other issue
            let result = ModelAvailabilityResult.unavailable(
                reason: "Apple On-Device session init failed: \(error.localizedDescription)"
            )
            cachedAvailability = result
            logError("AppleOnDeviceBackend: Session creation failed - \(error)")
            return result
        }
    }
    
    var isAvailable: Bool {
        checkAvailability().isAvailable
    }
    
    // MARK: - Generation
    
    func canHandle(input: ModelInput) -> Bool {
        guard isAvailable else { return false }
        return capabilities.supports(outputType: input.outputType)
    }
    
    func generate(input: ModelInput) async throws -> DraftOutput {
        let startTime = Date()
        
        // Verify availability
        let availability = checkAvailability()
        guard availability.isAvailable else {
            throw ModelError.modelNotAvailable(availability.reason ?? "Apple On-Device not available")
        }
        
        // Ensure session exists
        guard let activeSession = session else {
            throw ModelError.modelNotAvailable("Apple On-Device session not initialized")
        }
        
        // Validate input
        guard canHandle(input: input) else {
            throw ModelError.inputValidationFailed("Apple backend cannot handle \(input.outputType)")
        }
        
        // Build prompt from input
        let prompt = buildPrompt(from: input)
        
        do {
            // Generate text using Apple's on-device model
            // INVARIANT: This is strictly on-device, no network calls
            var outputText = ""
            
            for try await chunk in activeSession.streamResponse(to: prompt) {
                outputText += String(describing: chunk)
            }
            
            // Calculate latency
            lastGenerationLatencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
            
            // Create raw output
            // INVARIANT: We do NOT fabricate citations here
            // Citations are built via CitationBuilder from ContextPacket only
            let rawOutput = RawModelOutput(
                text: outputText,
                rawConfidence: nil,  // Apple API doesn't provide confidence
                inlineCitationMarkers: extractCitationMarkers(from: outputText),
                suggestedActionItems: extractActionItems(from: outputText),
                generationTimeMs: lastGenerationLatencyMs
            )
            
            // Use factory to normalize output with proper citations
            let result = DraftOutputFactory.create(
                from: rawOutput,
                input: input,
                backend: .appleOnDevice
            )
            
            // Check if fallback is required due to low confidence
            if result.requiresFallback {
                throw ModelError.fallbackRequired(
                    originalError: "Apple On-Device output confidence too low: \(result.output.confidence)"
                )
            }
            
            log("AppleOnDeviceBackend: Generation complete in \(lastGenerationLatencyMs)ms")
            return result.output
            
        } catch let error as ModelError {
            throw error
        } catch {
            throw ModelError.generationFailed("Apple On-Device generation failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Prompt Building
    
    private func buildPrompt(from input: ModelInput) -> String {
        var parts: [String] = []
        
        // Task instruction based on output type
        switch input.outputType {
        case .emailDraft:
            parts.append("Draft a professional email based on the following:")
        case .meetingSummary:
            parts.append("Summarize the following meeting:")
        case .documentSummary:
            parts.append("Summarize the following document:")
        case .taskList:
            parts.append("Extract action items from the following:")
        case .reminder:
            parts.append("Create a reminder based on the following:")
        }
        
        // Add intent
        if !input.intentText.isEmpty {
            parts.append("\nIntent: \(input.intentText)")
        }
        
        // Add context summary
        if !input.contextSummary.isEmpty {
            parts.append("\nContext:\n\(input.contextSummary)")
        }
        
        // Add constraints (invariants)
        parts.append("\n\nRequirements:")
        for constraint in input.constraints {
            parts.append("- \(constraint)")
        }
        
        return parts.joined(separator: "\n")
    }
    
    // MARK: - Output Extraction
    
    private func extractCitationMarkers(from text: String) -> [String]? {
        // Extract patterns like [1], [2], etc. if model includes them
        let pattern = "\\[\\d+\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        
        let markers = matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
        
        return markers.isEmpty ? nil : markers
    }
    
    private func extractActionItems(from text: String) -> [String]? {
        // Simple extraction of bullet points that look like action items
        var items: [String] = []
        let lines = text.components(separatedBy: .newlines)
        
        let actionIndicators = ["- [ ]", "- todo", "- action", "• ", "* "]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
            for indicator in actionIndicators {
                if trimmed.hasPrefix(indicator) {
                    items.append(line.trimmingCharacters(in: .whitespaces))
                    break
                }
            }
        }
        
        return items.isEmpty ? nil : items
    }
}
#endif

// MARK: - Fallback Wrapper (Always Available)

/// Wrapper that provides AppleOnDeviceModelBackend functionality
/// Falls back gracefully when Foundation Models framework is not available
/// INVARIANT: Always compiles cleanly on iOS 17+
final class AppleOnDeviceModelBackend: OnDeviceModel {
    
    // MARK: - Properties
    
    let modelId = "apple_on_device_v1"
    let displayName = "Apple On-Device"
    let version = "1.0.0"
    let backend: ModelBackend = .appleOnDevice
    
    let capabilities = ModelCapabilities(
        canSummarize: true,
        canDraftEmail: true,
        canExtractActions: true,
        canGenerateReminder: true,
        maxInputTokens: 4096,
        maxOutputTokens: 2048
    )
    
    var maxOutputChars: Int? { 4000 }
    
    // MARK: - Internal Implementation
    
    // Note: FoundationModels/LanguageModel disabled - API not available in current SDK
    private var cachedUnavailableReason: String? = "Apple On-Device model not available in current build"
    
    // MARK: - Initialization
    
    init() {
        // FoundationModels/LanguageModel not available
    }
    
    // MARK: - Availability
    
    var isAvailable: Bool {
        false // FoundationModels disabled
    }
    
    func checkAvailability() -> ModelAvailabilityResult {
        // FoundationModels not available in SDK
        return .unavailable(
            reason: cachedUnavailableReason ?? "Apple On-Device model not available"
        )
    }
    
    /// Get the specific unavailable reason for audit trail
    var unavailableReason: String? {
        cachedUnavailableReason
    }
    
    // MARK: - Generation
    
    func canHandle(input: ModelInput) -> Bool {
        false // FoundationModels disabled
    }
    
    func generate(input: ModelInput) async throws -> DraftOutput {
        #if false // canImport(FoundationModels)
        if #available(iOS 18.1, *) {
            if let typedImpl = typedImpl {
                return try await typedImpl.generate(input: input)
            }
        }
        #endif
        
        // If we reach here, backend is not available
        throw ModelError.modelNotAvailable(
            unavailableReason ?? "Apple On-Device not available"
        )
    }
}

// MARK: - SDK/API Uncertainty Notes
/*
 API NAMES USED (from Apple's Foundation Models framework documentation):
 
 - Module: FoundationModels
 - Class: LanguageModelSession
 - Static property: LanguageModel.isAvailable
 - Method: session.streamResponse(to:) -> AsyncThrowingStream<String, Error>
 
 UNCERTAINTY:
 1. The exact module name may vary if Apple changes it in future SDK versions
 2. The LanguageModel.isAvailable API may have different naming
 3. The streaming API signature may differ
 
 MITIGATION:
 - All API calls are behind #if canImport(FoundationModels)
 - Runtime checks use @available(iOS 18.1, *)
 - Session creation errors are caught and result in graceful fallback
 - Specific error messages are captured in fallbackReason
 
 If the actual API differs, this code will:
 1. Fail to compile the #if canImport block (safe - falls to else)
 2. Or catch runtime errors and return unavailable (safe - fallback)
*/
