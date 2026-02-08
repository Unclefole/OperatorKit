import Foundation
import CoreML

// MARK: - Core ML Model Backend
//
// REAL implementation that loads a bundled .mlmodelc if present.
// DEPLOYMENT TARGET: iOS 17.0
// 
// Rules:
// - If no model bundled → unavailable(reason: "Model not found in bundle")
// - If model requires unsupported tokenizer → unavailable(reason: "Tokenizer not implemented")
// - If inference fails → catch, fallback to deterministic, capture fallbackReason
// - INVARIANT: No network calls. Ever.
// - INVARIANT: Citations via CitationBuilder only (never from model output).

/// Core ML model backend for on-device inference
/// INVARIANT: Strictly on-device - no network calls
/// INVARIANT: If no bundled model, returns unavailable with precise reason
final class CoreMLModelBackend: OnDeviceModel {
    
    // MARK: - Configuration
    
    /// Expected model names to look for in bundle (in priority order)
    private static let expectedModelNames = [
        "OperatorKitDraftModel",
        "OperatorKitSummarizer",
        "TextClassifier"
    ]
    
    /// Supported model types for safe inference
    private enum SupportedModelType {
        case textClassifier      // Simple classification (can infer without tokenizer)
        case featureExtractor    // Feature-based models
        case unsupported(reason: String)
    }
    
    // MARK: - Properties
    
    let modelId: String
    let displayName: String
    let version: String
    let backend: ModelBackend = .coreML
    
    var capabilities: ModelCapabilities {
        // Capabilities depend on loaded model type
        guard let modelType = detectedModelType else {
            return ModelCapabilities(
                canSummarize: false,
                canDraftEmail: false,
                canExtractActions: false,
                canGenerateReminder: false,
                maxInputTokens: nil,
                maxOutputTokens: nil
            )
        }
        
        switch modelType {
        case .textClassifier:
            return ModelCapabilities(
                canSummarize: true,
                canDraftEmail: false,
                canExtractActions: true,
                canGenerateReminder: false,
                maxInputTokens: 512,
                maxOutputTokens: 128
            )
        case .featureExtractor:
            return ModelCapabilities(
                canSummarize: true,
                canDraftEmail: false,
                canExtractActions: false,
                canGenerateReminder: false,
                maxInputTokens: 256,
                maxOutputTokens: 64
            )
        case .unsupported:
            return ModelCapabilities(
                canSummarize: false,
                canDraftEmail: false,
                canExtractActions: false,
                canGenerateReminder: false,
                maxInputTokens: nil,
                maxOutputTokens: nil
            )
        }
    }
    
    var maxOutputChars: Int? { 2000 }
    
    // MARK: - State
    
    private var compiledModel: MLModel?
    private var modelURL: URL?
    private var cachedAvailability: ModelAvailabilityResult?
    private var detectedModelType: SupportedModelType?
    private var lastError: String?
    private var loadedModelName: String?
    
    // MARK: - Initialization
    
    init() {
        self.modelId = "coreml_backend_v1"
        self.displayName = "Core ML"
        self.version = "1.0.0"
        
        // Don't load model on init - lazy load on first availability check
    }
    
    // MARK: - OnDeviceModel Protocol
    
    var isAvailable: Bool {
        checkAvailability().isAvailable
    }
    
    /// Get the specific unavailable reason for audit trail
    var unavailableReason: String? {
        let availability = checkAvailability()
        if case .unavailable(let reason) = availability {
            return reason
        }
        return nil
    }
    
    func checkAvailability() -> ModelAvailabilityResult {
        // Return cached result if available
        if let cached = cachedAvailability {
            return cached
        }
        
        // Step 1: Look for model in bundle
        let searchResult = findModelInBundle()
        
        switch searchResult {
        case .notFound:
            let result = ModelAvailabilityResult.unavailable(
                reason: "Core ML model not found in bundle. Expected one of: \(Self.expectedModelNames.joined(separator: ", ")).mlmodelc"
            )
            cachedAvailability = result
            log("CoreMLBackend: No model found in bundle")
            return result
            
        case .found(let url, let name):
            modelURL = url
            loadedModelName = name
            
            // Step 2: Try to load the model
            let loadResult = loadModel(from: url)
            
            switch loadResult {
            case .success(let model, let type):
                compiledModel = model
                detectedModelType = type
                
                // Step 3: Check if model type is supported
                if case .unsupported(let reason) = type {
                    let result = ModelAvailabilityResult.unavailable(reason: reason)
                    cachedAvailability = result
                    log("CoreMLBackend: Model loaded but unsupported - \(reason)")
                    return result
                }
                
                let result = ModelAvailabilityResult.available
                cachedAvailability = result
                log("CoreMLBackend: Model '\(name)' loaded successfully, type: \(type)")
                return result
                
            case .failure(let error):
                let result = ModelAvailabilityResult.unavailable(
                    reason: "Failed to load Core ML model '\(name)': \(error)"
                )
                cachedAvailability = result
                lastError = error
                logError("CoreMLBackend: Failed to load model - \(error)")
                return result
            }
        }
    }
    
    func canHandle(input: ModelInput) -> Bool {
        guard isAvailable else { return false }
        return capabilities.supports(outputType: input.outputType)
    }
    
    func generate(input: ModelInput) async throws -> DraftOutput {
        let startTime = Date()
        
        // Verify availability
        let availability = checkAvailability()
        guard availability.isAvailable else {
            throw ModelError.modelNotAvailable(availability.reason ?? "Core ML not available")
        }
        
        guard let model = compiledModel else {
            throw ModelError.modelNotAvailable("Core ML model not loaded")
        }
        
        guard let modelType = detectedModelType else {
            throw ModelError.modelNotAvailable("Core ML model type not determined")
        }
        
        // Validate input
        guard canHandle(input: input) else {
            throw ModelError.inputValidationFailed("Core ML backend cannot handle \(input.outputType)")
        }
        
        do {
            // Run inference based on model type
            let inferenceResult: InferenceResult
            
            switch modelType {
            case .textClassifier:
                inferenceResult = try await runTextClassifierInference(model: model, input: input)
                
            case .featureExtractor:
                inferenceResult = try await runFeatureExtractorInference(model: model, input: input)
                
            case .unsupported(let reason):
                throw ModelError.modelNotAvailable("Model type unsupported: \(reason)")
            }
            
            let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
            
            // Create raw output
            // INVARIANT: We do NOT fabricate citations here
            // Citations are built via CitationBuilder from ContextPacket only
            let rawOutput = RawModelOutput(
                text: inferenceResult.text,
                rawConfidence: inferenceResult.confidence,
                inlineCitationMarkers: nil,  // Core ML doesn't produce citation markers
                suggestedActionItems: inferenceResult.actionItems,
                generationTimeMs: latencyMs
            )
            
            // Use factory to normalize output with proper citations
            let result = DraftOutputFactory.create(
                from: rawOutput,
                input: input,
                backend: .coreML
            )
            
            // Check if fallback is required due to low confidence
            if result.requiresFallback {
                throw ModelError.fallbackRequired(
                    originalError: "Core ML output confidence too low: \(result.output.confidence)"
                )
            }
            
            log("CoreMLBackend: Generation complete in \(latencyMs)ms, confidence: \(result.output.confidencePercentage)%")
            return result.output
            
        } catch let error as ModelError {
            throw error
        } catch {
            throw ModelError.generationFailed("Core ML inference failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Model Discovery
    
    private enum ModelSearchResult {
        case notFound
        case found(url: URL, name: String)
    }
    
    private func findModelInBundle() -> ModelSearchResult {
        // Look for compiled model (.mlmodelc) in main bundle
        for modelName in Self.expectedModelNames {
            // Try compiled model first
            if let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
                return .found(url: url, name: modelName)
            }
            
            // Try compiled model in Models subdirectory
            if let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc", subdirectory: "Models") {
                return .found(url: url, name: modelName)
            }
            
            // Try uncompiled model (.mlmodel) - Xcode should compile it
            if let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodel") {
                return .found(url: url, name: modelName)
            }
        }
        
        return .notFound
    }
    
    // MARK: - Model Loading
    
    private enum LoadResult {
        case success(model: MLModel, type: SupportedModelType)
        case failure(reason: String)
    }
    
    private func loadModel(from url: URL) -> LoadResult {
        do {
            // Configure model for optimal on-device performance
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine  // Prefer Neural Engine
            
            let model = try MLModel(contentsOf: url, configuration: config)
            
            // Detect model type from its description
            let modelType = detectModelType(model)
            
            return .success(model: model, type: modelType)
            
        } catch {
            return .failure(reason: error.localizedDescription)
        }
    }
    
    private func detectModelType(_ model: MLModel) -> SupportedModelType {
        let description = model.modelDescription
        
        // Check input features to determine model type
        // DETERMINISM FIX: Sort keys to ensure consistent iteration order
        let inputNames = description.inputDescriptionsByName.keys.sorted().map { $0.lowercased() }
        let outputNames = description.outputDescriptionsByName.keys.sorted().map { $0.lowercased() }
        
        // Text classifier: typically has "text" input and "label"/"class" output
        if inputNames.contains(where: { $0.contains("text") || $0.contains("input") }) &&
           outputNames.contains(where: { $0.contains("label") || $0.contains("class") || $0.contains("output") }) {
            
            // Check if it requires tokenization we can't provide
            if let inputDesc = description.inputDescriptionsByName.values.first {
                switch inputDesc.type {
                case .multiArray:
                    // Requires tokenized input - check if we can handle it
                    if let constraint = inputDesc.multiArrayConstraint {
                        // If shape is fixed and reasonable, we might handle it
                        if constraint.shape.count <= 2 {
                            return .textClassifier
                        }
                    }
                    return .unsupported(reason: "Model requires tokenized multi-array input. Tokenizer not implemented for safety.")
                    
                case .string:
                    // Direct string input - we can handle this
                    return .textClassifier
                    
                default:
                    return .unsupported(reason: "Unsupported input type: \(inputDesc.type)")
                }
            }
        }
        
        // Feature extractor: has numeric inputs/outputs
        if inputNames.contains(where: { $0.contains("feature") || $0.contains("embedding") }) {
            return .featureExtractor
        }
        
        // Sequence-to-sequence / generative models require tokenizers
        if inputNames.contains(where: { $0.contains("token") || $0.contains("ids") }) ||
           outputNames.contains(where: { $0.contains("token") || $0.contains("sequence") }) {
            return .unsupported(reason: "Model requires tokenizer for sequence processing. Tokenizer not implemented for safety.")
        }
        
        // Default: unsupported if we can't determine type
        return .unsupported(reason: "Unable to determine model type. Manual configuration required.")
    }
    
    // MARK: - Inference Implementation
    
    private struct InferenceResult {
        let text: String
        let confidence: Double?
        let actionItems: [String]?
    }
    
    private func runTextClassifierInference(model: MLModel, input: ModelInput) async throws -> InferenceResult {
        let inputDescription = model.modelDescription.inputDescriptionsByName
        
        // Prepare input text
        let inputText = prepareInputText(from: input)
        
        // Try to find the text input feature
        guard let (inputName, inputDesc) = inputDescription.first(where: { 
            $0.key.lowercased().contains("text") || $0.key.lowercased().contains("input")
        }) else {
            throw ModelError.generationFailed("Cannot find text input feature in model")
        }
        
        // Create feature provider based on input type
        let featureProvider: MLFeatureProvider
        
        switch inputDesc.type {
        case .string:
            featureProvider = try MLDictionaryFeatureProvider(dictionary: [
                inputName: MLFeatureValue(string: inputText)
            ])
            
        case .multiArray:
            // For multi-array input, we need basic tokenization
            // This is a SAFE STUB - returns template if we can't properly tokenize
            throw ModelError.fallbackRequired(originalError: "Multi-array input requires tokenizer - using fallback")
            
        default:
            throw ModelError.generationFailed("Unsupported input type: \(inputDesc.type)")
        }
        
        // Run prediction
        let prediction = try await model.prediction(from: featureProvider)
        
        // Extract output
        let (outputText, confidence) = extractTextClassifierOutput(from: prediction, input: input)
        
        return InferenceResult(
            text: outputText,
            confidence: confidence,
            actionItems: extractActionItemsFromOutput(outputText)
        )
    }
    
    private func runFeatureExtractorInference(model: MLModel, input: ModelInput) async throws -> InferenceResult {
        // Feature extractors typically need embedding input
        // For now, return a safe fallback
        throw ModelError.fallbackRequired(originalError: "Feature extractor inference requires embedding pipeline - using fallback")
    }
    
    private func prepareInputText(from input: ModelInput) -> String {
        var parts: [String] = []
        
        // Add intent
        if !input.intentText.isEmpty {
            parts.append("Intent: \(input.intentText)")
        }
        
        // Add context summary
        if !input.contextSummary.isEmpty {
            parts.append("Context: \(input.contextSummary)")
        }
        
        return parts.joined(separator: "\n")
    }
    
    private func extractTextClassifierOutput(from prediction: MLFeatureProvider, input: ModelInput) -> (String, Double?) {
        // Try to find output features
        var outputText = ""
        var confidence: Double? = nil
        
        for featureName in prediction.featureNames {
            if let value = prediction.featureValue(for: featureName) {
                switch value.type {
                case .string:
                    let text = value.stringValue
                    if !text.isEmpty {
                        outputText = text
                    }
                    
                case .dictionary:
                    // Classification probabilities
                    if let dict = value.dictionaryValue as? [String: Double] {
                        // Get highest confidence class
                        if let (label, prob) = dict.max(by: { $0.value < $1.value }) {
                            if outputText.isEmpty {
                                outputText = label
                            }
                            confidence = prob
                        }
                    }
                    
                case .double:
                    confidence = value.doubleValue
                    
                default:
                    break
                }
            }
        }
        
        // If we got a class label, expand it to a useful output
        if !outputText.isEmpty {
            outputText = expandClassLabelToOutput(label: outputText, input: input)
        } else {
            // Fallback: generate template based on input
            outputText = generateTemplateOutput(for: input)
        }
        
        return (outputText, confidence)
    }
    
    private func expandClassLabelToOutput(label: String, input: ModelInput) -> String {
        // Convert a class label to a useful draft
        let normalizedLabel = label.lowercased()
        
        switch input.outputType {
        case .meetingSummary:
            if normalizedLabel.contains("action") || normalizedLabel.contains("task") {
                return "# Meeting Summary\n\nBased on the meeting context, the following action items were identified:\n\n- [Review meeting notes]\n- [Follow up with attendees]\n\n*Please review and add specific details.*"
            }
            return "# Meeting Summary\n\n[Add meeting discussion points]\n\n## Action Items\n- [Add action items]\n\n*Please review and complete.*"
            
        case .emailDraft:
            return "Hi,\n\nThank you for your message. Based on the context:\n\n[Add your response here]\n\nBest regards"
            
        case .taskList:
            return "# Action Items\n\n- [ ] \(label.capitalized)\n- [ ] [Add more items]\n\n*Review and prioritize.*"
            
        case .documentSummary:
            return "# Document Summary\n\nClassification: \(label.capitalized)\n\n[Add summary details]\n\n*Please review for accuracy.*"
            
        case .reminder:
            return "Reminder: \(input.intentText)\n\n[Add reminder details]"
        }
    }
    
    private func generateTemplateOutput(for input: ModelInput) -> String {
        // Fallback template generation when model output is unclear
        switch input.outputType {
        case .meetingSummary:
            return "# Meeting Summary\n\n## Key Points\n- [Add discussion points]\n\n## Action Items\n- [ ] [Add action items]\n\n*Generated via Core ML - please review.*"
            
        case .emailDraft:
            return "Hi,\n\nRegarding: \(input.intentText)\n\n[Your response here]\n\nBest regards"
            
        case .taskList:
            return "# Tasks from Context\n\n- [ ] Review and complete\n- [ ] [Add specific tasks]\n\n*Please verify and prioritize.*"
            
        case .documentSummary:
            return "# Summary\n\n[Document overview]\n\n## Key Points\n- [Add key points]\n\n*Please review for accuracy.*"
            
        case .reminder:
            return "Reminder: \(input.intentText)"
        }
    }
    
    private func extractActionItemsFromOutput(_ text: String) -> [String]? {
        var items: [String] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") {
                let item = trimmed.replacingOccurrences(of: "- [ ] ", with: "")
                    .replacingOccurrences(of: "- [x] ", with: "")
                if !item.isEmpty {
                    items.append(item)
                }
            }
        }
        
        return items.isEmpty ? nil : items
    }
}

// MARK: - Fallback Reasons (Documented)
/*
 EXACT FALLBACK REASONS USED:
 
 1. "Core ML model not found in bundle. Expected one of: OperatorKitDraftModel, OperatorKitSummarizer, TextClassifier.mlmodelc"
    → No .mlmodelc file found in app bundle
 
 2. "Failed to load Core ML model '<name>': <error>"
    → MLModel(contentsOf:) threw an error
 
 3. "Model requires tokenized multi-array input. Tokenizer not implemented for safety."
    → Model expects tokenized int arrays but we don't have a safe tokenizer
 
 4. "Model requires tokenizer for sequence processing. Tokenizer not implemented for safety."
    → Model is seq2seq/generative and needs tokenization
 
 5. "Unable to determine model type. Manual configuration required."
    → Model structure doesn't match known patterns
 
 6. "Multi-array input requires tokenizer - using fallback"
    → Runtime inference hit multi-array input without tokenizer
 
 7. "Feature extractor inference requires embedding pipeline - using fallback"
    → Feature extractor model needs embedding support
 
 8. "Core ML output confidence too low: <value>"
    → Model produced valid output but confidence below threshold
*/
