import Foundation

// MARK: - Evaluation Report
//
// Results from running evaluation cases against model backends.
// INVARIANT: All metrics are from local-only evaluation
// INVARIANT: No user data involved

/// Report from a single evaluation case run
struct EvalCaseReport: Identifiable, Equatable {
    let id: String
    let caseId: String
    let caseName: String
    let backendUsed: ModelBackend
    let latencyMs: Int
    let confidence: Double
    let citationsCount: Int
    let fallbackUsed: Bool
    let fallbackReason: String?
    let safetyNotes: [String]
    let result: EvalResult
    let timestamp: Date
    
    // Phase 4C additions
    let validationPass: Bool
    let timeoutOccurred: Bool
    let citationValidityPass: Bool
    
    enum EvalResult: Equatable {
        case pass(reason: String)
        case fail(reason: String)
        case skipped(reason: String)
        
        var isPassing: Bool {
            if case .pass = self { return true }
            return false
        }
        
        var displayText: String {
            switch self {
            case .pass(let reason): return "✅ Pass: \(reason)"
            case .fail(let reason): return "❌ Fail: \(reason)"
            case .skipped(let reason): return "⏭️ Skipped: \(reason)"
            }
        }
        
        var shortText: String {
            switch self {
            case .pass: return "Pass"
            case .fail: return "Fail"
            case .skipped: return "Skipped"
            }
        }
    }
    
    var formattedLatency: String {
        if latencyMs < 1000 {
            return "\(latencyMs)ms"
        } else {
            return String(format: "%.1fs", Double(latencyMs) / 1000.0)
        }
    }
    
    var confidencePercentage: Int {
        Int(confidence * 100)
    }
}

/// Aggregate report from running multiple evaluation cases
struct EvalSuiteReport: Equatable {
    let reports: [EvalCaseReport]
    let startTime: Date
    let endTime: Date
    
    var totalDurationMs: Int {
        Int(endTime.timeIntervalSince(startTime) * 1000)
    }
    
    var passCount: Int {
        reports.filter { $0.result.isPassing }.count
    }
    
    var failCount: Int {
        reports.filter {
            if case .fail = $0.result { return true }
            return false
        }.count
    }
    
    var skippedCount: Int {
        reports.filter {
            if case .skipped = $0.result { return true }
            return false
        }.count
    }
    
    var totalCount: Int {
        reports.count
    }
    
    var averageLatencyMs: Int {
        guard !reports.isEmpty else { return 0 }
        let totalLatency = reports.reduce(0) { $0 + $1.latencyMs }
        return totalLatency / reports.count
    }
    
    var averageConfidence: Double {
        guard !reports.isEmpty else { return 0 }
        let totalConfidence = reports.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Double(reports.count)
    }
    
    var uniqueBackendsUsed: Set<ModelBackend> {
        Set(reports.map { $0.backendUsed })
    }
    
    var fallbackRate: Double {
        guard !reports.isEmpty else { return 0 }
        let fallbackCount = reports.filter { $0.fallbackUsed }.count
        return Double(fallbackCount) / Double(reports.count)
    }
    
    var summary: String {
        """
        Eval Suite Report
        ─────────────────
        Total Cases: \(totalCount)
        Passed: \(passCount)
        Failed: \(failCount)
        Skipped: \(skippedCount)
        
        Average Latency: \(averageLatencyMs)ms
        Average Confidence: \(Int(averageConfidence * 100))%
        Fallback Rate: \(Int(fallbackRate * 100))%
        
        Backends Used: \(uniqueBackendsUsed.map { $0.displayName }.joined(separator: ", "))
        """
    }
}

// MARK: - Expected Behavior Validation

extension EvalCaseReport {
    
    /// Create a report by evaluating actual output against expected behavior
    static func evaluate(
        evalCase: EvalCase,
        output: DraftOutput?,
        error: Error?,
        backendUsed: ModelBackend,
        latencyMs: Int,
        fallbackUsed: Bool,
        fallbackReason: String?,
        validationPass: Bool = true,
        timeoutOccurred: Bool = false,
        citationValidityPass: Bool = true
    ) -> EvalCaseReport {
        let result = determineResult(
            evalCase: evalCase,
            output: output,
            error: error,
            fallbackUsed: fallbackUsed,
            timeoutOccurred: timeoutOccurred
        )
        
        return EvalCaseReport(
            id: UUID().uuidString,
            caseId: evalCase.id,
            caseName: evalCase.name,
            backendUsed: backendUsed,
            latencyMs: latencyMs,
            confidence: output?.confidence ?? 0,
            citationsCount: output?.citations.count ?? 0,
            fallbackUsed: fallbackUsed,
            fallbackReason: fallbackReason,
            safetyNotes: output?.safetyNotes ?? [],
            result: result,
            timestamp: Date(),
            validationPass: validationPass,
            timeoutOccurred: timeoutOccurred,
            citationValidityPass: citationValidityPass
        )
    }
    
    private static func determineResult(
        evalCase: EvalCase,
        output: DraftOutput?,
        error: Error?,
        fallbackUsed: Bool,
        timeoutOccurred: Bool = false
    ) -> EvalResult {
        let confidence = output?.confidence ?? 0
        
        // Special handling for timeout test cases
        if evalCase.expectedBehavior == .routeToFallback && timeoutOccurred && fallbackUsed {
            return .pass(reason: "Correctly timed out and routed to fallback")
        }
        
        switch evalCase.expectedBehavior {
        case .generateDraft:
            // Expected: successful generation with decent confidence
            if let output = output, output.confidence >= 0.65 {
                return .pass(reason: "Generated draft with \(Int(output.confidence * 100))% confidence")
            } else if let output = output {
                return .fail(reason: "Confidence too low: \(Int(output.confidence * 100))% (expected ≥65%)")
            } else if let error = error {
                return .fail(reason: "Generation failed: \(error.localizedDescription)")
            }
            return .fail(reason: "No output generated")
            
        case .routeToFallback:
            // Expected: fallback should be triggered
            if fallbackUsed {
                return .pass(reason: "Correctly routed to fallback")
            }
            return .fail(reason: "Expected fallback but none occurred")
            
        case .requireProceedAnyway:
            // Expected: confidence between 0.35 and 0.65
            if confidence >= 0.35 && confidence < 0.65 {
                return .pass(reason: "Confidence \(Int(confidence * 100))% correctly requires 'Proceed Anyway'")
            } else if confidence >= 0.65 {
                return .fail(reason: "Confidence \(Int(confidence * 100))% too high - should require 'Proceed Anyway'")
            } else {
                return .fail(reason: "Confidence \(Int(confidence * 100))% too low - should block entirely")
            }
            
        case .blockExecution:
            // Expected: confidence below 0.35
            if confidence < 0.35 {
                return .pass(reason: "Correctly blocked with \(Int(confidence * 100))% confidence")
            }
            return .fail(reason: "Confidence \(Int(confidence * 100))% should have blocked execution")
        }
    }
}
