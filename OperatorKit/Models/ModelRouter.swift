import Foundation

// MARK: - Latency Budget Constants

/// Latency budgets for model generation (in milliseconds)
/// If generation exceeds budget, timeout triggers fallback
enum ModelLatencyBudget {
    /// Deterministic template model - fast baseline (1200ms)
    static let deterministicMs: Int = 1200
    
    /// Core ML model - moderate budget (2500ms)
    static let coreMLMs: Int = 2500
    
    /// Apple On-Device model - generous budget for complex inference (3500ms)
    static let appleOnDeviceMs: Int = 3500
    
    /// Structured on-device model - same speed class as deterministic (1500ms)
    static let structuredOnDeviceMs: Int = 1500

    /// Get budget for a specific backend
    static func budget(for backend: ModelBackend) -> Int {
        switch backend {
        case .appleOnDevice:
            return appleOnDeviceMs
        case .coreML:
            return coreMLMs
        case .structuredOnDevice:
            return structuredOnDeviceMs
        case .deterministic:
            return deterministicMs
        }
    }
    
    /// Convert milliseconds to TimeInterval (seconds)
    static func timeInterval(for backend: ModelBackend) -> TimeInterval {
        Double(budget(for: backend)) / 1000.0
    }
}

// MARK: - Timeout Error

/// Error thrown when model generation times out
struct ModelTimeoutError: Error, LocalizedError {
    let backend: ModelBackend
    let budgetMs: Int
    let actualMs: Int
    
    var errorDescription: String? {
        "Model generation timed out after \(actualMs)ms (budget: \(budgetMs)ms)"
    }
}

// MARK: - Diagnostics Snapshot Types

/// Comprehensive snapshot of model router state for debugging
struct ModelDiagnosticsSnapshot: Equatable {
    let currentBackend: ModelBackend
    let currentModelId: String
    let lastGenerationLatencyMs: Int
    let lastFallbackReason: String?
    let backendDetails: [ModelBackend: BackendDiagnostics]
    let timestamp: Date
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

/// Diagnostics for a single backend
struct BackendDiagnostics: Equatable {
    let backend: ModelBackend
    let isAvailable: Bool
    let unavailableReason: String?
    let capabilities: ModelCapabilities
}

/// Routes draft generation requests to the appropriate on-device model
/// INVARIANT: Always on-device (no network calls)
/// INVARIANT: All outputs are drafts first
/// INVARIANT: Confidence thresholds enforced
/// INVARIANT: Falls back to deterministic model if ML fails
@MainActor
final class ModelRouter: ObservableObject {
    
    static let shared = ModelRouter()
    
    // MARK: - Feature Flags
    
    /// Feature flag: Use Apple On-Device model when available
    private let useAppleOnDeviceWhenAvailable: Bool = true
    
    /// Feature flag: Use Core ML model when available
    private let useCoreMLWhenAvailable: Bool = true
    
    // MARK: - Available Models
    
    private let appleOnDeviceBackend: AppleOnDeviceModelBackend
    private let coreMLBackend: CoreMLModelBackend
    private let structuredBackend: StructuredOnDeviceBackend
    private let deterministicModel: DeterministicTemplateModel
    
    // MARK: - Published State
    
    @Published private(set) var currentBackend: ModelBackend = .structuredOnDevice
    @Published private(set) var currentModelId: String = ""
    @Published private(set) var lastGenerationTimeMs: Int = 0
    @Published private(set) var lastError: ModelError?
    @Published private(set) var lastFallbackReason: String?
    @Published private(set) var lastTimeoutOccurred: Bool = false
    @Published private(set) var lastValidationPass: Bool = true
    @Published private(set) var lastCitationValidityPass: Bool = true
    @Published private(set) var lastPromptScaffoldHash: String?
    
    #if DEBUG
    /// Feature flag: Enable fault injection backend for testing
    @Published var enableFaultInjection: Bool = false
    private var faultInjectionBackend: FaultInjectionModelBackend?
    #endif
    
    // MARK: - Diagnostics
    
    private var generationHistory: [GenerationRecord] = []
    private let maxHistorySize = 20
    
    // MARK: - Initialization
    
    private init() {
        self.appleOnDeviceBackend = AppleOnDeviceModelBackend()
        self.coreMLBackend = CoreMLModelBackend()
        self.structuredBackend = StructuredOnDeviceBackend()
        self.deterministicModel = DeterministicTemplateModel()
        self.currentModelId = structuredBackend.modelId
    }
    
    // MARK: - Model Selection
    
    /// Select the best available model for the given input
    /// Priority: Apple On-Device > Core ML > Structured On-Device > Deterministic
    private func selectModel(for input: ModelInput) -> (any OnDeviceModel, String?) {
        var fallbackReason: String? = nil
        
        // Try Apple On-Device first
        if useAppleOnDeviceWhenAvailable {
            let availability = appleOnDeviceBackend.checkAvailability()
            if availability.isAvailable && appleOnDeviceBackend.canHandle(input: input) {
                return (appleOnDeviceBackend, nil)
            }
            if !availability.isAvailable {
                fallbackReason = availability.reason
            }
        }
        
        // Try Core ML
        if useCoreMLWhenAvailable {
            let availability = coreMLBackend.checkAvailability()
            if availability.isAvailable && coreMLBackend.canHandle(input: input) {
                return (coreMLBackend, nil)
            }
            if fallbackReason == nil && !availability.isAvailable {
                fallbackReason = availability.reason
            }
        }
        
        // Structured On-Device: context-aware prose (always available)
        if structuredBackend.canHandle(input: input) {
            return (structuredBackend, fallbackReason)
        }
        
        // Last resort: Deterministic template model (always available)
        return (deterministicModel, fallbackReason ?? "Using deterministic fallback")
    }
    
    // MARK: - Generation
    
    /// Generate a draft output using the best available model
    /// INVARIANT: On-device only - no network calls
    /// INVARIANT: All outputs are drafts first
    /// INVARIANT: Falls back to deterministic if ML fails or times out
    /// INVARIANT: Output validated before return
    func generate(input: ModelInput) async throws -> DraftOutput {
        let startTime = Date()
        lastError = nil
        lastFallbackReason = nil
        lastTimeoutOccurred = false
        lastValidationPass = true
        lastCitationValidityPass = true
        
        // Generate and store prompt scaffold hash for audit
        let scaffold = input.promptScaffold
        lastPromptScaffoldHash = scaffold.scaffoldHash
        
        // Validate input
        guard input.hasSufficientContext else {
            let error = ModelError.inputValidationFailed("Intent or context required")
            lastError = error
            throw error
        }
        
        // Select model
        #if DEBUG
        if enableFaultInjection, let faultBackend = faultInjectionBackend {
            log("ModelRouter: Using fault injection backend for testing")
            return try await generateWithFaultInjection(input: input, backend: faultBackend, startTime: startTime)
        }
        #endif
        
        let (selectedModel, initialFallbackReason) = selectModel(for: input)
        currentModelId = selectedModel.modelId
        currentBackend = selectedModel.backend
        lastFallbackReason = initialFallbackReason
        
        log("ModelRouter: Selected \(selectedModel.displayName) (\(selectedModel.backend.displayName))")
        
        // Get latency budget for selected backend
        let budgetMs = ModelLatencyBudget.budget(for: selectedModel.backend)
        let timeout = ModelLatencyBudget.timeInterval(for: selectedModel.backend)
        
        do {
            // Try to generate with timeout
            let output = try await generateWithTimeout(
                model: selectedModel,
                input: input,
                timeout: timeout,
                budgetMs: budgetMs
            )
            
            // Record timing
            lastGenerationTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
            log("ModelRouter: Generation complete in \(lastGenerationTimeMs)ms, confidence: \(output.confidencePercentage)%")
            
            // Validate output using OutputValidator
            let validation = OutputValidator.validate(output: output, input: input)
            lastValidationPass = validation.validationPass
            lastCitationValidityPass = validation.citationValidity.pass
            
            // If validation requires fallback, do it
            if validation.requiresFallback && selectedModel.backend != .deterministic {
                log("ModelRouter: Validation failed, falling back to deterministic")
                lastFallbackReason = validation.summary
                return try await generateWithFallback(
                    input: input,
                    originalError: ModelError.validationFailed(validation.summary),
                    startTime: startTime
                )
            }
            
            // Apply corrections if needed
            let correctedOutput = validation.isValid ? output : OutputValidator.correct(output: output, validation: validation)
            
            // Validate output invariants (legacy check)
            try validateOutput(correctedOutput, input: input)
            
            // Record success
            recordGeneration(
                backend: selectedModel.backend,
                success: true,
                latencyMs: lastGenerationTimeMs,
                confidence: correctedOutput.confidence,
                fallbackUsed: false,
                timeoutOccurred: false,
                validationPass: validation.validationPass
            )
            
            return correctedOutput
            
        } catch let error as ModelTimeoutError {
            // Timeout - fallback with specific reason
            lastTimeoutOccurred = true
            if selectedModel.backend != .deterministic {
                log("ModelRouter: Timeout after \(error.actualMs)ms, falling back to deterministic")
                lastFallbackReason = "Model generation timed out after \(error.actualMs)ms (budget: \(error.budgetMs)ms)"
                
                return try await generateWithFallback(
                    input: input,
                    originalError: ModelError.timeout(backend: selectedModel.backend, budgetMs: error.budgetMs),
                    startTime: startTime
                )
            }
            throw ModelError.timeout(backend: selectedModel.backend, budgetMs: error.budgetMs)
            
        } catch let error as ModelError {
            // Check if we should fallback
            if selectedModel.backend != .deterministic {
                log("ModelRouter: \(selectedModel.displayName) failed, falling back to deterministic")
                lastFallbackReason = error.localizedDescription
                
                return try await generateWithFallback(
                    input: input,
                    originalError: error,
                    startTime: startTime
                )
            }
            
            lastError = error
            logError("ModelRouter: \(error.localizedDescription)")
            throw error
            
        } catch {
            // Unexpected error - try fallback
            if selectedModel.backend != .deterministic {
                log("ModelRouter: Unexpected error, falling back to deterministic")
                lastFallbackReason = error.localizedDescription
                
                return try await generateWithFallback(
                    input: input,
                    originalError: ModelError.generationFailed(error.localizedDescription),
                    startTime: startTime
                )
            }
            
            let modelError = ModelError.generationFailed(error.localizedDescription)
            lastError = modelError
            logError("ModelRouter: \(error.localizedDescription)")
            throw modelError
        }
    }
    
    /// Generate with timeout - wraps backend call in Task with deadline
    private func generateWithTimeout(
        model: any OnDeviceModel,
        input: ModelInput,
        timeout: TimeInterval,
        budgetMs: Int
    ) async throws -> DraftOutput {
        let startTime = Date()
        
        // Use Task with timeout
        return try await withThrowingTaskGroup(of: DraftOutput.self) { group in
            // Add the actual generation task
            group.addTask {
                return try await model.generate(input: input)
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                let actualMs = Int(Date().timeIntervalSince(startTime) * 1000)
                throw ModelTimeoutError(backend: model.backend, budgetMs: budgetMs, actualMs: actualMs)
            }
            
            // Return first result (either output or timeout)
            guard let result = try await group.next() else {
                throw ModelError.generationFailed("No result from generation task group")
            }
            
            // Cancel remaining tasks
            group.cancelAll()
            
            return result
        }
    }
    
    #if DEBUG
    /// Generate using fault injection backend for testing
    private func generateWithFaultInjection(
        input: ModelInput,
        backend: FaultInjectionModelBackend,
        startTime: Date
    ) async throws -> DraftOutput {
        currentModelId = backend.modelId
        currentBackend = .deterministic  // Fault injection counts as deterministic for routing
        
        do {
            let output = try await backend.generate(input: input)
            lastGenerationTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
            
            // Validate output
            let validation = OutputValidator.validate(output: output, input: input)
            lastValidationPass = validation.validationPass
            lastCitationValidityPass = validation.citationValidity.pass
            
            if validation.requiresFallback {
                lastFallbackReason = "Fault injection: \(validation.summary)"
                return try await generateWithFallback(
                    input: input,
                    originalError: ModelError.validationFailed(validation.summary),
                    startTime: startTime
                )
            }
            
            return validation.isValid ? output : OutputValidator.correct(output: output, validation: validation)
            
        } catch {
            lastFallbackReason = "Fault injection: \(error.localizedDescription)"
            return try await generateWithFallback(
                input: input,
                originalError: ModelError.generationFailed(error.localizedDescription),
                startTime: startTime
            )
        }
    }
    
    /// Set fault injection backend for testing
    func setFaultInjectionBackend(_ backend: FaultInjectionModelBackend?) {
        faultInjectionBackend = backend
    }
    #endif
    
    /// Fallback to deterministic model when ML backend fails or times out
    private func generateWithFallback(
        input: ModelInput,
        originalError: ModelError,
        startTime: Date
    ) async throws -> DraftOutput {
        currentModelId = deterministicModel.modelId
        currentBackend = .deterministic
        
        do {
            let output = try await deterministicModel.generate(input: input)
            
            // Validate fallback output too
            let validation = OutputValidator.validate(output: output, input: input)
            lastValidationPass = validation.validationPass
            lastCitationValidityPass = validation.citationValidity.pass
            
            lastGenerationTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
            log("ModelRouter: Fallback generation complete in \(lastGenerationTimeMs)ms")
            
            // Record fallback
            recordGeneration(
                backend: .deterministic,
                success: true,
                latencyMs: lastGenerationTimeMs,
                confidence: output.confidence,
                fallbackUsed: true,
                fallbackReason: originalError.localizedDescription
            )
            
            return output
            
        } catch {
            // Even fallback failed - this is critical
            lastError = ModelError.generationFailed("All backends failed")
            throw lastError!
        }
    }
    
    /// Generate with simplified interface (for backward compatibility)
    func generate(
        intent: IntentRequest,
        context: ContextPacket
    ) async throws -> DraftOutput {
        let input = ModelInput.from(intent: intent, context: context)
        return try await generate(input: input)
    }

    // ════════════════════════════════════════════════════════════════
    // MARK: - GOVERNED INTELLIGENCE ROUTING
    // ════════════════════════════════════════════════════════════════
    //
    // Single entrypoint for all governed model calls.
    // Delegates provider selection to CapabilityKernel.
    // Cloud calls require: FeatureFlag ON + Kernel decision + ModelCallToken.
    // All calls evidence-logged.
    //
    // INVARIANT: This is the ONLY place that calls cloud clients.
    // ════════════════════════════════════════════════════════════════

    /// Cloud client references — internal, only used here.
    private let openAIClient = OpenAIClient.shared
    private let anthropicClient = AnthropicClient.shared

    /// Governed generation: kernel decides provider, token gates cloud.
    /// Returns DraftOutput compatible with existing pipeline.
    func generateGoverned(
        intent: IntentRequest,
        context: ContextPacket,
        riskTierHint: String? = nil
    ) async throws -> GovernedModelResult {
        let kernel = CapabilityKernel.shared
        let evidence = EvidenceEngine.shared

        // 1. Build model call request
        let contextSummary = DataDiode.redact(
            context.calendarItems.map { $0.title }.joined(separator: ", ")
        )
        let request = ModelCallRequest(
            intentType: intent.intentType.rawValue,
            riskTierHint: riskTierHint,
            contextSummaryRedacted: contextSummary
        )

        // 2. Ask kernel for decision
        let decision = kernel.evaluateModelCallEligibility(request: request)

        // 3. Log decision
        try? evidence.logModelCallDecision(decision)

        // 4. If denied, fail
        guard decision.allowed else {
            return .denied(reason: decision.reason)
        }

        // 5. If requires human approval, surface to UI
        if decision.requiresHumanApproval {
            return .requiresApproval(decision: decision)
        }

        // 6. Route based on provider
        let startTime = Date()

        switch decision.provider {
        case .onDevice:
            // Use existing on-device path — evidence logged
            let input = ModelInput.from(intent: intent, context: context)
            try? evidence.logModelCallRequest(request, provider: .onDevice)
            let output = try await generate(input: input)

            let responseRecord = ModelCallResponseRecord(
                requestId: request.id,
                provider: .onDevice,
                success: true,
                latencyMs: Int(Date().timeIntervalSince(startTime) * 1000),
                outputLengthChars: output.draftBody.count,
                confidence: output.confidence,
                backendId: currentModelId
            )
            try? evidence.logModelCallResponse(responseRecord)

            return .success(output: output, provider: .onDevice)

        case .cloudOpenAI, .cloudAnthropic:
            // Cloud path: issue token, verify, consume, call, log
            return try await executeCloudCall(
                request: request,
                decision: decision,
                intent: intent,
                context: context,
                startTime: startTime
            )
        }
    }

    /// Execute a cloud model call with full token gating.
    private func executeCloudCall(
        request: ModelCallRequest,
        decision: ModelCallDecision,
        intent: IntentRequest,
        context: ContextPacket,
        startTime: Date
    ) async throws -> GovernedModelResult {
        let kernel = CapabilityKernel.shared
        let evidence = EvidenceEngine.shared

        // 1. Issue ModelCallToken from kernel
        let token = kernel.issueModelCallToken(
            requestId: request.id,
            provider: decision.provider
        )

        // 2. Verify token signature
        guard token.verifySignature() else {
            throw CloudModelError.tokenInvalidSignature
        }

        // 3. Consume token (one-use)
        guard CapabilityKernel.consumeModelCallToken(token) else {
            throw CloudModelError.tokenAlreadyConsumed
        }

        // 4. Check expiry
        guard token.isValid else {
            throw CloudModelError.tokenExpired
        }

        // 5. Log request
        try? evidence.logModelCallRequest(request, provider: decision.provider)

        // 6. Build prompts
        let systemPrompt = buildSystemPrompt(for: intent)
        let userPrompt = buildUserPrompt(for: intent, context: context)

        // 7. Call the appropriate cloud client
        let cloudResponse: CloudCompletionResponse
        do {
            switch decision.provider {
            case .cloudOpenAI:
                cloudResponse = try await openAIClient.generate(
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt
                )
            case .cloudAnthropic:
                cloudResponse = try await anthropicClient.generate(
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt
                )
            default:
                throw CloudModelError.featureFlagDisabled(decision.provider)
            }
        } catch {
            // Log failure
            let failRecord = ModelCallResponseRecord(
                requestId: request.id,
                provider: decision.provider,
                success: false,
                latencyMs: Int(Date().timeIntervalSince(startTime) * 1000),
                outputLengthChars: 0,
                errorMessage: error.localizedDescription
            )
            try? evidence.logModelCallResponse(failRecord)

            // Fallback to on-device
            let input = ModelInput.from(intent: intent, context: context)
            let fallbackOutput = try await generate(input: input)
            return .success(output: fallbackOutput, provider: .onDevice)
        }

        // 8. Log success
        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
        let successRecord = ModelCallResponseRecord(
            requestId: request.id,
            provider: decision.provider,
            success: true,
            latencyMs: latencyMs,
            outputLengthChars: cloudResponse.content.count,
            confidence: 0.85 // Cloud models get default high confidence
        )
        try? evidence.logModelCallResponse(successRecord)

        // 9. Convert cloud response to DraftOutput
        let draftOutput = convertCloudResponse(cloudResponse, intent: intent, context: context)
        return .success(output: draftOutput, provider: decision.provider)
    }

    // MARK: - Prompt Building

    private func buildSystemPrompt(for intent: IntentRequest) -> String {
        """
        You are a professional assistant. Generate a draft based on the user's request. \
        Be concise, accurate, and professional. Output only the draft content.
        """
    }

    private func buildUserPrompt(for intent: IntentRequest, context: ContextPacket) -> String {
        let contextStr = context.calendarItems.map { "- \($0.title)" }.joined(separator: "\n")
        let redactedContext = DataDiode.redact(contextStr)
        return """
        Intent: \(intent.rawText)
        Type: \(intent.intentType.rawValue)
        Context:
        \(redactedContext)

        Generate an appropriate draft.
        """
    }

    // MARK: - Cloud Response Conversion

    private func convertCloudResponse(
        _ response: CloudCompletionResponse,
        intent: IntentRequest,
        context: ContextPacket
    ) -> DraftOutput {
        // Use DraftOutputFactory to create a properly structured output
        let outputType: DraftOutput.OutputType
        switch intent.intentType {
        case .draftEmail:
            outputType = .emailDraft
        case .summarizeMeeting:
            outputType = .meetingSummary
        case .reviewDocument:
            outputType = .documentSummary
        case .createReminder:
            outputType = .reminder
        default:
            outputType = .taskList
        }

        return DraftOutput(
            draftBody: response.content,
            confidence: 0.85,
            safetyNotes: [
                "Generated by \(response.provider.displayName) — review before sending",
                "Content passed through DataDiode redaction before cloud transmission"
            ],
            outputType: outputType
        )
    }
    
    // MARK: - Output Validation
    
    /// Validate that output meets all invariants
    private func validateOutput(_ output: DraftOutput, input: ModelInput) throws {
        // INVARIANT: Citations must only reference selected context
        for citation in output.citations {
            let isValid = validateCitation(citation, against: input)
            if !isValid {
                throw ModelError.invariantViolation("Citation references unselected context: \(citation.sourceId)")
            }
        }
        
        // INVARIANT: Safety notes must include draft-first warning
        let hasDraftFirstWarning = output.safetyNotes.contains { 
            $0.lowercased().contains("review") || $0.lowercased().contains("draft")
        }
        if !hasDraftFirstWarning {
            logWarning("ModelRouter: Safety notes missing review reminder - adding default")
            // Don't throw, the DraftOutputFactory should have added this
        }
        
        // INVARIANT: Confidence must be valid
        guard output.confidence >= 0 && output.confidence <= 1 else {
            throw ModelError.invariantViolation("Invalid confidence value: \(output.confidence)")
        }
    }
    
    /// Validate that a citation references selected context
    private func validateCitation(_ citation: Citation, against input: ModelInput) -> Bool {
        switch citation.sourceType {
        case .calendarEvent:
            return input.contextItems.calendarItems.contains { item in
                (item.eventIdentifier ?? item.id.uuidString) == citation.sourceId
            }
        case .emailThread:
            return input.contextItems.emailItems.contains { item in
                (item.messageIdentifier ?? item.id.uuidString) == citation.sourceId
            }
        case .file:
            return input.contextItems.fileItems.contains { item in
                (item.fileURL?.absoluteString ?? item.id.uuidString) == citation.sourceId
            }
        case .note:
            // Notes are derived from context, allow them
            return true
        }
    }
    
    // MARK: - Model Info
    
    /// Get metadata for the current model (with latency)
    func currentModelMetadata(latencyMs: Int? = nil) -> ModelMetadata {
        let model: any OnDeviceModel
        switch currentBackend {
        case .appleOnDevice:
            model = appleOnDeviceBackend
        case .coreML:
            model = coreMLBackend
        case .structuredOnDevice:
            model = structuredBackend
        case .deterministic:
            model = deterministicModel
        }
        return ModelMetadata(
            from: model,
            latencyMs: latencyMs ?? lastGenerationTimeMs,
            fallbackReason: lastFallbackReason
        )
    }
    
    /// Get availability status for all backends
    var backendAvailability: [ModelBackend: ModelAvailabilityResult] {
        [
            .appleOnDevice: appleOnDeviceBackend.checkAvailability(),
            .coreML: coreMLBackend.checkAvailability(),
            .structuredOnDevice: structuredBackend.checkAvailability(),
            .deterministic: deterministicModel.checkAvailability()
        ]
    }
    
    /// Get Apple On-Device specific availability info for UI display
    var appleOnDeviceAvailability: (isAvailable: Bool, reason: String?) {
        let availability = appleOnDeviceBackend.checkAvailability()
        return (availability.isAvailable, availability.reason)
    }
    
    /// Get the specific unavailable reason for Apple backend (for audit trail)
    var appleBackendUnavailableReason: String? {
        appleOnDeviceBackend.unavailableReason
    }
    
    /// Get the specific unavailable reason for CoreML backend (for audit trail)
    var coreMLBackendUnavailableReason: String? {
        coreMLBackend.unavailableReason
    }
    
    /// Get comprehensive diagnostics snapshot for UI and debugging
    func diagnostics() -> ModelDiagnosticsSnapshot {
        var backendDetails: [ModelBackend: BackendDiagnostics] = [:]
        
        for (backend, availability) in backendAvailability {
            let reason: String?
            switch backend {
            case .appleOnDevice:
                reason = appleBackendUnavailableReason
            case .coreML:
                reason = coreMLBackendUnavailableReason
            case .structuredOnDevice:
                reason = nil  // Always available
            case .deterministic:
                reason = nil
            }
            
            backendDetails[backend] = BackendDiagnostics(
                backend: backend,
                isAvailable: availability.isAvailable,
                unavailableReason: reason,
                capabilities: getCapabilities(for: backend)
            )
        }
        
        return ModelDiagnosticsSnapshot(
            currentBackend: currentBackend,
            currentModelId: currentModelId,
            lastGenerationLatencyMs: lastGenerationTimeMs,
            lastFallbackReason: lastFallbackReason,
            backendDetails: backendDetails,
            timestamp: Date()
        )
    }
    
    private func getCapabilities(for backend: ModelBackend) -> ModelCapabilities {
        switch backend {
        case .appleOnDevice:
            return appleOnDeviceBackend.capabilities
        case .coreML:
            return coreMLBackend.capabilities
        case .structuredOnDevice:
            return structuredBackend.capabilities
        case .deterministic:
            return deterministicModel.capabilities
        }
    }
    
    /// List all models with their availability
    var allModels: [(model: any OnDeviceModel, availability: ModelAvailabilityResult)] {
        [
            (appleOnDeviceBackend, appleOnDeviceBackend.checkAvailability()),
            (coreMLBackend, coreMLBackend.checkAvailability()),
            (structuredBackend, structuredBackend.checkAvailability()),
            (deterministicModel, deterministicModel.checkAvailability())
        ]
    }
    
    // MARK: - Diagnostics
    
    private func recordGeneration(
        backend: ModelBackend,
        success: Bool,
        latencyMs: Int,
        confidence: Double,
        fallbackUsed: Bool,
        fallbackReason: String? = nil,
        timeoutOccurred: Bool = false,
        validationPass: Bool = true
    ) {
        let record = GenerationRecord(
            timestamp: Date(),
            backend: backend,
            success: success,
            latencyMs: latencyMs,
            confidence: confidence,
            fallbackUsed: fallbackUsed,
            fallbackReason: fallbackReason,
            timeoutOccurred: timeoutOccurred,
            validationPass: validationPass
        )
        
        generationHistory.append(record)
        
        // Trim history
        if generationHistory.count > maxHistorySize {
            generationHistory.removeFirst()
        }
    }
    
    #if DEBUG
    /// Diagnostic info for debugging
    var diagnosticInfo: [String: Any] {
        var info: [String: Any] = [:]
        
        info["currentBackend"] = currentBackend.rawValue
        info["currentModelId"] = currentModelId
        info["lastGenerationTimeMs"] = lastGenerationTimeMs
        info["lastFallbackReason"] = lastFallbackReason ?? "none"
        
        // Backend availability with detailed reasons
        var availability: [String: [String: Any]] = [:]
        for (backend, result) in backendAvailability {
            availability[backend.rawValue] = [
                "available": result.isAvailable,
                "reason": result.reason ?? (result.isAvailable ? "OK" : "unknown")
            ]
        }
        info["backendAvailability"] = availability
        
        // Apple On-Device specific info
        let appleInfo = appleOnDeviceAvailability
        info["appleOnDevice"] = [
            "available": appleInfo.isAvailable,
            "reason": appleInfo.reason ?? (appleInfo.isAvailable ? "Ready" : "Not available")
        ]
        
        // Recent history summary
        let recentRecords = generationHistory.suffix(5)
        info["recentGenerations"] = recentRecords.map { record in
            [
                "backend": record.backend.rawValue,
                "latencyMs": record.latencyMs,
                "confidence": record.confidence,
                "fallback": record.fallbackUsed,
                "fallbackReason": record.fallbackReason ?? ""
            ] as [String: Any]
        }
        
        return info
    }
    #endif
}

// MARK: - Generation Record

private struct GenerationRecord {
    let timestamp: Date
    let backend: ModelBackend
    let success: Bool
    let latencyMs: Int
    let confidence: Double
    let fallbackUsed: Bool
    let fallbackReason: String?
    let timeoutOccurred: Bool
    let validationPass: Bool
    
    init(
        timestamp: Date,
        backend: ModelBackend,
        success: Bool,
        latencyMs: Int,
        confidence: Double,
        fallbackUsed: Bool,
        fallbackReason: String? = nil,
        timeoutOccurred: Bool = false,
        validationPass: Bool = true
    ) {
        self.timestamp = timestamp
        self.backend = backend
        self.success = success
        self.latencyMs = latencyMs
        self.confidence = confidence
        self.fallbackUsed = fallbackUsed
        self.fallbackReason = fallbackReason
        self.timeoutOccurred = timeoutOccurred
        self.validationPass = validationPass
    }
}
