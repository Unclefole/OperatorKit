import Foundation

// ============================================================================
// QUALITY GATE EVALUATOR (Phase 8C)
//
// Pre-release quality gate for TestFlight / App Store readiness.
//
// CRITICAL: This gate:
//   ❌ does NOT block execution
//   ❌ does NOT block user flows
//   ✅ is used for release readiness only
//   ✅ is advisory for pre-release decisions
//
// The gate is computed from Phase 8B evaluation data (golden cases, drift).
//
// See: docs/SAFETY_CONTRACT.md, docs/RELEASE_APPROVAL.md
// ============================================================================

/// Quality gate status for release readiness
public enum GateStatus: String, Codable {
    case pass = "PASS"
    case warn = "WARN"
    case fail = "FAIL"
    case skipped = "SKIPPED"
    
    public var displayName: String { rawValue }
    
    public var systemImage: String {
        switch self {
        case .pass: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        }
    }
    
    public var colorName: String {
        switch self {
        case .pass: return "green"
        case .warn: return "orange"
        case .fail: return "red"
        case .skipped: return "gray"
        }
    }
}

/// Result of quality gate evaluation
public struct QualityGateResult: Codable {
    public let status: GateStatus
    public let reasons: [String]
    public let metrics: QualityGateMetrics
    public let evaluatedAt: Date
    public let thresholds: QualityGateThresholds
    
    public init(
        status: GateStatus,
        reasons: [String],
        metrics: QualityGateMetrics,
        thresholds: QualityGateThresholds
    ) {
        self.status = status
        self.reasons = reasons
        self.metrics = metrics
        self.evaluatedAt = Date()
        self.thresholds = thresholds
    }
    
    /// Human-readable summary
    public var summary: String {
        switch status {
        case .pass:
            return "Quality gate passed. Ready for release."
        case .warn:
            return "Quality gate passed with warnings. Review before release."
        case .fail:
            return "Quality gate failed. Address issues before release."
        case .skipped:
            return "Quality gate skipped. Insufficient data for evaluation."
        }
    }
}

/// Metrics used in quality gate evaluation
public struct QualityGateMetrics: Codable {
    public let goldenCaseCount: Int
    public let totalEvalRuns: Int
    public let latestPassRate: Double?
    public let overallPassRate: Double?
    public let driftLevel: String?
    public let fallbackDriftPercentage: Double?
    public let hasRecentEvalRun: Bool
    public let daysSinceLastEval: Int?
    
    public init(
        goldenCaseCount: Int,
        totalEvalRuns: Int,
        latestPassRate: Double?,
        overallPassRate: Double?,
        driftLevel: String?,
        fallbackDriftPercentage: Double?,
        hasRecentEvalRun: Bool,
        daysSinceLastEval: Int?
    ) {
        self.goldenCaseCount = goldenCaseCount
        self.totalEvalRuns = totalEvalRuns
        self.latestPassRate = latestPassRate
        self.overallPassRate = overallPassRate
        self.driftLevel = driftLevel
        self.fallbackDriftPercentage = fallbackDriftPercentage
        self.hasRecentEvalRun = hasRecentEvalRun
        self.daysSinceLastEval = daysSinceLastEval
    }
}

/// Configurable thresholds for quality gate
public struct QualityGateThresholds: Codable {
    public let minimumGoldenCases: Int
    public let minimumPassRate: Double
    public let maximumFallbackDriftPercentage: Double
    public let maximumDaysWithoutEval: Int
    
    public static let `default` = QualityGateThresholds(
        minimumGoldenCases: 5,
        minimumPassRate: 0.80,
        maximumFallbackDriftPercentage: 0.20,
        maximumDaysWithoutEval: 7
    )
    
    public init(
        minimumGoldenCases: Int = 5,
        minimumPassRate: Double = 0.80,
        maximumFallbackDriftPercentage: Double = 0.20,
        maximumDaysWithoutEval: Int = 7
    ) {
        self.minimumGoldenCases = minimumGoldenCases
        self.minimumPassRate = minimumPassRate
        self.maximumFallbackDriftPercentage = maximumFallbackDriftPercentage
        self.maximumDaysWithoutEval = maximumDaysWithoutEval
    }
}

// MARK: - Quality Gate Singleton

/// Main singleton for quality gate access
/// Provides a cached result and convenient interface
@MainActor
public final class QualityGate: ObservableObject {

    // MARK: - Singleton

    public static let shared = QualityGate()

    // MARK: - Published State

    @Published public private(set) var currentResult: QualityGateResultInfo?

    // MARK: - Dependencies

    private let evaluator: QualityGateEvaluator

    // MARK: - Initialization

    private init() {
        self.evaluator = QualityGateEvaluator()
    }

    // MARK: - Public Methods

    /// Evaluate the quality gate and cache the result
    public func evaluate() -> QualityGateResultInfo {
        let result = evaluator.evaluate()
        let info = QualityGateResultInfo(from: result)
        currentResult = info
        return info
    }
}

/// Simplified quality gate result info for UI
public struct QualityGateResultInfo {
    public let status: GateStatus
    public let coverageScore: Int?
    public let invariantsPassing: Bool
    public let evaluatedAtDayRounded: String?
    public let trend: SafetyQualityTrend?

    public init(from result: QualityGateResult) {
        self.status = result.status
        self.coverageScore = result.metrics.latestPassRate.map { Int($0 * 100) }
        self.invariantsPassing = result.status == .pass || result.status == .warn
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        self.evaluatedAtDayRounded = formatter.string(from: result.evaluatedAt)
        self.trend = nil // Could derive from drift level
    }
}

/// Trend direction for quality metrics (Safety layer)
public enum SafetyQualityTrend: String, Codable {
    case improving = "improving"
    case stable = "stable"
    case degrading = "degrading"
}

/// Evaluates quality gates for release readiness
///
/// IMPORTANT: This evaluator is ADVISORY ONLY.
/// It does NOT block user actions or execution flows.
/// It is used for pre-release decision making.
public final class QualityGateEvaluator {
    
    private let goldenCaseStore: GoldenCaseStore
    private let evalRunner: LocalEvalRunner
    private let thresholds: QualityGateThresholds
    
    public init(
        goldenCaseStore: GoldenCaseStore = .shared,
        evalRunner: LocalEvalRunner = .shared,
        thresholds: QualityGateThresholds = .default
    ) {
        self.goldenCaseStore = goldenCaseStore
        self.evalRunner = evalRunner
        self.thresholds = thresholds
    }
    
    /// Evaluates the quality gate
    /// - Returns: QualityGateResult with status, reasons, and metrics
    public func evaluate() -> QualityGateResult {
        var reasons: [String] = []
        var status: GateStatus = .pass
        
        // Gather metrics
        let goldenCaseCount = goldenCaseStore.totalCount
        let evalRuns = evalRunner.runs
        let totalEvalRuns = evalRuns.count
        
        // Check minimum golden cases
        if goldenCaseCount < thresholds.minimumGoldenCases {
            reasons.append("Insufficient golden cases (\(goldenCaseCount)/\(thresholds.minimumGoldenCases) required)")
            return QualityGateResult(
                status: .skipped,
                reasons: reasons,
                metrics: buildMetrics(
                    goldenCaseCount: goldenCaseCount,
                    evalRuns: evalRuns
                ),
                thresholds: thresholds
            )
        }
        
        // Check if any eval runs exist
        if evalRuns.isEmpty {
            reasons.append("No evaluation runs found")
            return QualityGateResult(
                status: .skipped,
                reasons: reasons,
                metrics: buildMetrics(
                    goldenCaseCount: goldenCaseCount,
                    evalRuns: evalRuns
                ),
                thresholds: thresholds
            )
        }
        
        // Get latest run and drift summary
        let sortedRuns = evalRuns.sorted { $0.startedAt > $1.startedAt }
        let latestRun = sortedRuns.first!
        let driftSummary = DriftSummaryComputer(evalRunner: evalRunner).computeSummary()
        
        // Check days since last eval
        let daysSinceLastEval = Calendar.current.dateComponents(
            [.day],
            from: latestRun.startedAt,
            to: Date()
        ).day ?? 0
        
        if daysSinceLastEval > thresholds.maximumDaysWithoutEval {
            reasons.append("Evaluation data is stale (\(daysSinceLastEval) days old, max \(thresholds.maximumDaysWithoutEval))")
            status = .warn
        }
        
        // Check drift level
        if driftSummary.driftLevel == .high {
            reasons.append("High drift level detected")
            status = .fail
        } else if driftSummary.driftLevel == .moderate {
            reasons.append("Moderate drift level detected")
            if status != .fail { status = .warn }
        }
        
        // Check pass rate
        let latestPassRate = latestRun.passRate
        if latestPassRate < thresholds.minimumPassRate {
            reasons.append("Pass rate below threshold (\(Int(latestPassRate * 100))% < \(Int(thresholds.minimumPassRate * 100))%)")
            status = .fail
        }
        
        // Check fallback drift percentage
        let fallbackDriftCount = driftSummary.failuresByCategory[.fallback] ?? 0
        let fallbackDriftPercentage = driftSummary.totalCases > 0
            ? Double(fallbackDriftCount) / Double(driftSummary.totalCases)
            : 0.0
        
        if fallbackDriftPercentage > thresholds.maximumFallbackDriftPercentage {
            reasons.append("Fallback drift exceeds threshold (\(Int(fallbackDriftPercentage * 100))% > \(Int(thresholds.maximumFallbackDriftPercentage * 100))%)")
            status = .fail
        }
        
        // If no issues found
        if reasons.isEmpty {
            reasons.append("All quality checks passed")
        }
        
        return QualityGateResult(
            status: status,
            reasons: reasons,
            metrics: buildMetrics(
                goldenCaseCount: goldenCaseCount,
                evalRuns: evalRuns,
                driftSummary: driftSummary,
                latestRun: latestRun,
                daysSinceLastEval: daysSinceLastEval
            ),
            thresholds: thresholds
        )
    }
    
    // MARK: - Helpers
    
    private func buildMetrics(
        goldenCaseCount: Int,
        evalRuns: [EvalRun],
        driftSummary: DriftSummary? = nil,
        latestRun: EvalRun? = nil,
        daysSinceLastEval: Int? = nil
    ) -> QualityGateMetrics {
        let fallbackDriftCount = driftSummary?.failuresByCategory[.fallback] ?? 0
        let totalCases = driftSummary?.totalCases ?? 0
        let fallbackDriftPercentage = totalCases > 0
            ? Double(fallbackDriftCount) / Double(totalCases)
            : nil
        
        return QualityGateMetrics(
            goldenCaseCount: goldenCaseCount,
            totalEvalRuns: evalRuns.count,
            latestPassRate: latestRun?.passRate,
            overallPassRate: driftSummary?.passRate,
            driftLevel: driftSummary?.driftLevel.rawValue,
            fallbackDriftPercentage: fallbackDriftPercentage,
            hasRecentEvalRun: daysSinceLastEval.map { $0 <= 7 } ?? false,
            daysSinceLastEval: daysSinceLastEval
        )
    }
}

// MARK: - Export Format

extension QualityGateResult {
    
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
