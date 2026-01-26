import Foundation

// ============================================================================
// DRIFT SUMMARY (Phase 8B)
//
// Local-only drift analysis computed from eval runs.
// INVARIANT: No network transmission
// INVARIANT: Read-only analysis
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Summary of drift across all eval runs
public struct DriftSummary {
    public let totalRuns: Int
    public let totalCases: Int
    public let passCount: Int
    public let failCount: Int
    public let passRate: Double
    
    public let failuresByCategory: [FailureCategory: Int]
    public let backendShiftOccurrences: Int
    public let promptHashMismatches: Int
    
    public let latestRunDate: Date?
    public let oldestRunDate: Date?
    
    public enum FailureCategory: String, CaseIterable {
        case timeout = "Timeout"
        case validation = "Validation"
        case citations = "Citations"
        case fallback = "Fallback Drift"
        case latency = "Latency"
        case backend = "Backend Change"
        case promptHash = "Prompt Hash"
        
        public var systemImage: String {
            switch self {
            case .timeout: return "clock.badge.exclamationmark"
            case .validation: return "exclamationmark.triangle"
            case .citations: return "quote.bubble"
            case .fallback: return "arrow.triangle.branch"
            case .latency: return "gauge.with.needle"
            case .backend: return "cpu"
            case .promptHash: return "number.square"
            }
        }
    }
    
    public var hasDrift: Bool {
        failCount > 0 || backendShiftOccurrences > 0 || promptHashMismatches > 0
    }
    
    public var driftLevel: DriftLevel {
        guard totalCases > 0 else { return .none }
        
        let failRate = 1.0 - passRate
        if failRate == 0 && backendShiftOccurrences == 0 {
            return .none
        } else if failRate < 0.1 {
            return .low
        } else if failRate < 0.3 {
            return .moderate
        } else {
            return .high
        }
    }
    
    public enum DriftLevel: String {
        case none = "None"
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        
        public var systemImage: String {
            switch self {
            case .none: return "checkmark.shield"
            case .low: return "exclamationmark.shield"
            case .moderate: return "exclamationmark.triangle"
            case .high: return "xmark.shield"
            }
        }
        
        public var color: String {
            switch self {
            case .none: return "green"
            case .low: return "yellow"
            case .moderate: return "orange"
            case .high: return "red"
            }
        }
    }
}

// MARK: - Drift Summary Computer

/// Computes drift summary from eval runs
public final class DriftSummaryComputer {
    
    private let evalRunner: LocalEvalRunner
    
    public init(evalRunner: LocalEvalRunner = .shared) {
        self.evalRunner = evalRunner
    }
    
    /// Computes current drift summary
    public func computeSummary() -> DriftSummary {
        let runs = evalRunner.runs
        
        let totalRuns = runs.count
        let allResults = runs.flatMap { $0.results }
        let totalCases = allResults.count
        let passCount = allResults.filter { $0.pass }.count
        let failCount = allResults.filter { !$0.pass }.count
        let passRate = totalCases > 0 ? Double(passCount) / Double(totalCases) : 0.0
        
        // Count failures by category
        var failuresByCategory: [DriftSummary.FailureCategory: Int] = [:]
        for category in DriftSummary.FailureCategory.allCases {
            failuresByCategory[category] = 0
        }
        
        var backendShiftOccurrences = 0
        var promptHashMismatches = 0
        
        for result in allResults {
            for reason in result.failureReasons {
                switch reason {
                case .timeout:
                    failuresByCategory[.timeout, default: 0] += 1
                case .validationFailed:
                    failuresByCategory[.validation, default: 0] += 1
                case .citationValidityFailed:
                    failuresByCategory[.citations, default: 0] += 1
                case .fallbackDrift:
                    failuresByCategory[.fallback, default: 0] += 1
                case .latencyExceeded:
                    failuresByCategory[.latency, default: 0] += 1
                case .backendChanged:
                    failuresByCategory[.backend, default: 0] += 1
                    backendShiftOccurrences += 1
                case .promptHashMismatch:
                    failuresByCategory[.promptHash, default: 0] += 1
                    promptHashMismatches += 1
                }
            }
        }
        
        // Get date range
        let sortedRuns = runs.sorted { $0.startedAt < $1.startedAt }
        let oldestRunDate = sortedRuns.first?.startedAt
        let latestRunDate = sortedRuns.last?.startedAt
        
        return DriftSummary(
            totalRuns: totalRuns,
            totalCases: totalCases,
            passCount: passCount,
            failCount: failCount,
            passRate: passRate,
            failuresByCategory: failuresByCategory,
            backendShiftOccurrences: backendShiftOccurrences,
            promptHashMismatches: promptHashMismatches,
            latestRunDate: latestRunDate,
            oldestRunDate: oldestRunDate
        )
    }
}
