import Foundation

// MARK: - Evaluation Runner
//
// Runs evaluation cases against model backends and collects metrics.
// INVARIANT: On-device only - no network calls
// INVARIANT: Uses SYNTHETIC context only - no user data
// INVARIANT: Deterministic and reproducible

/// Runs evaluation cases against model backends
@MainActor
final class EvalRunner: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var currentCase: EvalCase?
    @Published private(set) var progress: Double = 0
    @Published private(set) var lastReport: EvalSuiteReport?
    @Published private(set) var caseReports: [EvalCaseReport] = []
    
    // MARK: - Configuration
    
    struct Configuration {
        let backends: Set<ModelBackend>
        let runCount: Int  // How many times to run each case (for latency averaging)
        
        static let `default` = Configuration(
            backends: [.deterministic],  // Default to deterministic only
            runCount: 1
        )
        
        static let full = Configuration(
            backends: [.appleOnDevice, .coreML, .deterministic],
            runCount: 1
        )
    }
    
    // MARK: - Dependencies
    
    private let modelRouter: ModelRouter
    
    // MARK: - Initialization
    
    init(modelRouter: ModelRouter = .shared) {
        self.modelRouter = modelRouter
    }
    
    // MARK: - Running Evaluations
    
    /// Run all built-in evaluation cases
    func runBuiltInCases(config: Configuration = .default) async -> EvalSuiteReport {
        return await runCases(EvalCase.builtInCases, config: config)
    }
    
    /// Run specific evaluation cases
    func runCases(_ cases: [EvalCase], config: Configuration = .default) async -> EvalSuiteReport {
        isRunning = true
        caseReports = []
        progress = 0
        
        let startTime = Date()
        var reports: [EvalCaseReport] = []
        
        for (index, evalCase) in cases.enumerated() {
            currentCase = evalCase
            progress = Double(index) / Double(cases.count)
            
            let report = await runSingleCase(evalCase, config: config)
            reports.append(report)
            caseReports.append(report)
            
            log("EvalRunner: Completed \(evalCase.name) - \(report.result.shortText)")
        }
        
        let endTime = Date()
        progress = 1.0
        currentCase = nil
        isRunning = false
        
        let suiteReport = EvalSuiteReport(
            reports: reports,
            startTime: startTime,
            endTime: endTime
        )
        
        lastReport = suiteReport
        log("EvalRunner: Suite complete - \(suiteReport.passCount)/\(suiteReport.totalCount) passed")
        
        return suiteReport
    }
    
    /// Run a single evaluation case
    private func runSingleCase(_ evalCase: EvalCase, config: Configuration) async -> EvalCaseReport {
        let startTime = Date()
        
        // Build model input from eval case
        let input = buildModelInput(from: evalCase)
        
        // Track state before generation
        let initialBackend = modelRouter.currentBackend
        
        var output: DraftOutput?
        var error: Error?
        var fallbackUsed = false
        var fallbackReason: String?
        
        do {
            // Run generation
            output = try await modelRouter.generate(input: input)
            
            // Check if fallback was used (backend changed during generation)
            fallbackUsed = modelRouter.currentBackend == .deterministic && initialBackend != .deterministic
            fallbackReason = modelRouter.lastFallbackReason
            
        } catch let modelError as ModelError {
            error = modelError
            fallbackReason = modelError.localizedDescription
            
            // Check if this was a fallback error
            if case .fallbackRequired = modelError {
                fallbackUsed = true
            }
            
        } catch {
            // Unexpected error
            fallbackReason = error.localizedDescription
        }
        
        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
        let backendUsed = modelRouter.currentBackend
        
        // Evaluate result against expected behavior
        return EvalCaseReport.evaluate(
            evalCase: evalCase,
            output: output,
            error: error,
            backendUsed: backendUsed,
            latencyMs: latencyMs,
            fallbackUsed: fallbackUsed || modelRouter.lastFallbackReason != nil,
            fallbackReason: fallbackReason ?? modelRouter.lastFallbackReason,
            validationPass: modelRouter.lastValidationPass,
            timeoutOccurred: modelRouter.lastTimeoutOccurred,
            citationValidityPass: modelRouter.lastCitationValidityPass
        )
    }
    
    #if DEBUG
    /// Run fault injection test cases
    func runFaultInjectionCases() async -> EvalSuiteReport {
        isRunning = true
        caseReports = []
        progress = 0
        
        let startTime = Date()
        var reports: [EvalCaseReport] = []
        
        let faultCases = EvalCase.faultInjectionCases
        
        for (index, evalCase) in faultCases.enumerated() {
            currentCase = evalCase
            progress = Double(index) / Double(faultCases.count)
            
            // Determine which fault injection mode to use
            let faultMode: FaultInjectionMode
            switch evalCase.id {
            case "eval_fault_malformed_1":
                faultMode = .malformedOutput
            case "eval_fault_citations_1":
                faultMode = .invalidCitations
            case "eval_fault_timeout_1":
                faultMode = .slowResponse
            case "eval_fault_safety_1":
                faultMode = .missingSafetyNotes
            default:
                faultMode = .malformedOutput
            }
            
            let report = await runFaultInjectionCase(evalCase, mode: faultMode)
            reports.append(report)
            caseReports.append(report)
            
            log("EvalRunner: Fault injection \(evalCase.name) - \(report.result.shortText)")
        }
        
        let endTime = Date()
        progress = 1.0
        currentCase = nil
        isRunning = false
        
        let suiteReport = EvalSuiteReport(
            reports: reports,
            startTime: startTime,
            endTime: endTime
        )
        
        lastReport = suiteReport
        return suiteReport
    }
    
    /// Run a fault injection case with specific mode
    private func runFaultInjectionCase(_ evalCase: EvalCase, mode: FaultInjectionMode) async -> EvalCaseReport {
        let startTime = Date()
        
        // Create and set fault injection backend
        let faultBackend = FaultInjectionModelBackend(mode: mode)
        modelRouter.setFaultInjectionBackend(faultBackend)
        modelRouter.enableFaultInjection = true
        
        defer {
            // Always clean up
            modelRouter.enableFaultInjection = false
            modelRouter.setFaultInjectionBackend(nil)
        }
        
        let input = buildModelInput(from: evalCase)
        
        var output: DraftOutput?
        var error: Error?
        var fallbackUsed = false
        var fallbackReason: String?
        
        do {
            output = try await modelRouter.generate(input: input)
            fallbackUsed = modelRouter.lastFallbackReason != nil
            fallbackReason = modelRouter.lastFallbackReason
        } catch let modelError as ModelError {
            error = modelError
            fallbackReason = modelError.localizedDescription
            
            if case .fallbackRequired = modelError {
                fallbackUsed = true
            }
        } catch {
            fallbackReason = error.localizedDescription
        }
        
        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
        let backendUsed = modelRouter.currentBackend
        
        return EvalCaseReport.evaluate(
            evalCase: evalCase,
            output: output,
            error: error,
            backendUsed: backendUsed,
            latencyMs: latencyMs,
            fallbackUsed: fallbackUsed || modelRouter.lastFallbackReason != nil,
            fallbackReason: fallbackReason ?? modelRouter.lastFallbackReason,
            validationPass: modelRouter.lastValidationPass,
            timeoutOccurred: modelRouter.lastTimeoutOccurred,
            citationValidityPass: modelRouter.lastCitationValidityPass
        )
    }
    #endif
    
    // MARK: - Input Building
    
    private func buildModelInput(from evalCase: EvalCase) -> ModelInput {
        // Build context items from synthetic data, separated by type
        let calendarItems = evalCase.contextItems.compactMap { $0.asCalendarContextItem() }
        let emailItems = evalCase.contextItems.compactMap { $0.asEmailContextItem() }
        let fileItems = evalCase.contextItems.compactMap { $0.asFileContextItem() }

        let contextItems = ModelInput.ContextItems(
            calendarItems: calendarItems,
            emailItems: emailItems,
            fileItems: fileItems
        )

        // Build context summary from synthetic items
        let contextSummary = buildContextSummary(from: evalCase.contextItems)

        return ModelInput(
            intentText: evalCase.intentText,
            contextSummary: contextSummary,
            constraints: ModelInput.defaultConstraints,
            outputType: evalCase.expectedOutputType,
            contextItems: contextItems
        )
    }
    
    private func buildContextSummary(from items: [SyntheticContextItem]) -> String {
        guard !items.isEmpty else { return "" }
        
        var parts: [String] = []
        
        for item in items {
            switch item.type {
            case .calendarEvent:
                parts.append("Meeting: \(item.title)")
                if !item.snippet.isEmpty {
                    parts.append("  Details: \(item.snippet)")
                }
                
            case .email:
                parts.append("Email: \(item.title)")
                parts.append("  Content: \(item.snippet)")
                
            case .document:
                parts.append("Document: \(item.title)")
                parts.append("  Excerpt: \(item.snippet)")
                
            case .reminder:
                parts.append("Reminder: \(item.title)")
            }
        }
        
        return parts.joined(separator: "\n")
    }
    
    // MARK: - Reset
    
    func reset() {
        isRunning = false
        currentCase = nil
        progress = 0
        caseReports = []
        // Keep lastReport for reference
    }
}

// MARK: - Quick Eval for DEBUG UI

extension EvalRunner {
    
    /// Quick evaluation with just the deterministic backend
    /// Returns a simplified result for display
    func runQuickEval() async -> QuickEvalResult {
        let report = await runBuiltInCases(config: .default)
        
        return QuickEvalResult(
            totalCases: report.totalCount,
            passed: report.passCount,
            failed: report.failCount,
            averageLatencyMs: report.averageLatencyMs,
            averageConfidence: report.averageConfidence,
            fallbackRate: report.fallbackRate,
            reports: report.reports
        )
    }
}

/// Simplified result for DEBUG UI display
struct QuickEvalResult: Equatable {
    let totalCases: Int
    let passed: Int
    let failed: Int
    let averageLatencyMs: Int
    let averageConfidence: Double
    let fallbackRate: Double
    let reports: [EvalCaseReport]
    
    var passRate: Double {
        guard totalCases > 0 else { return 0 }
        return Double(passed) / Double(totalCases)
    }
    
    var summaryText: String {
        "\(passed)/\(totalCases) passed • Avg \(averageLatencyMs)ms • \(Int(averageConfidence * 100))% conf"
    }
}
