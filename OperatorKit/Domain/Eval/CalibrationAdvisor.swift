import Foundation

// ============================================================================
// CALIBRATION ADVISOR (Phase 9B)
//
// Advisory-only recommendations derived from metadata and aggregates.
// Does NOT affect runtime behavior in any way.
//
// INVARIANT: Inputs are metadata-only (no user content)
// INVARIANT: Outputs are generic recommendations (no specific content)
// INVARIANT: Pure advisory - does not gate or block any action
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Severity of a calibration recommendation
public enum RecommendationSeverity: String, Codable, CaseIterable {
    case info = "Info"
    case caution = "Caution"
    case action = "Action"
    
    public var systemImage: String {
        switch self {
        case .info: return "info.circle"
        case .caution: return "exclamationmark.triangle"
        case .action: return "exclamationmark.circle"
        }
    }
    
    public var colorName: String {
        switch self {
        case .info: return "blue"
        case .caution: return "orange"
        case .action: return "red"
        }
    }
    
    public var sortOrder: Int {
        switch self {
        case .action: return 0
        case .caution: return 1
        case .info: return 2
        }
    }
}

/// A single calibration recommendation
public struct CalibrationRecommendation: Identifiable, Codable, Equatable {
    public let id: String
    public let severity: RecommendationSeverity
    public let title: String
    public let message: String
    public let suggestedNextSteps: [String]
    public let category: RecommendationCategory
    
    public enum RecommendationCategory: String, Codable {
        case coverage = "Coverage"
        case freshness = "Freshness"
        case drift = "Drift"
        case trend = "Trend"
        case quality = "Quality"
        case release = "Release"
    }
    
    public init(
        id: String,
        severity: RecommendationSeverity,
        title: String,
        message: String,
        suggestedNextSteps: [String],
        category: RecommendationCategory
    ) {
        self.id = id
        self.severity = severity
        self.title = title
        self.message = message
        self.suggestedNextSteps = suggestedNextSteps
        self.category = category
    }
}

/// Generates advisory calibration recommendations
/// IMPORTANT: This is advisory only and does NOT affect runtime behavior
public final class CalibrationAdvisor {
    
    // MARK: - Thresholds
    
    private let coverageThreshold = 70
    private let freshnessThresholdDays = 7
    private let passRateThreshold = 0.80
    private let fallbackDriftThresholdPercent = 0.20
    private let minimumGoldenCasesForRelease = 5
    
    // MARK: - Dependencies
    
    private let goldenCaseStore: GoldenCaseStore
    private let evalRunner: LocalEvalRunner
    private let historyStore: QualityHistoryStore
    
    public init(
        goldenCaseStore: GoldenCaseStore = .shared,
        evalRunner: LocalEvalRunner = .shared,
        historyStore: QualityHistoryStore = .shared
    ) {
        self.goldenCaseStore = goldenCaseStore
        self.evalRunner = evalRunner
        self.historyStore = historyStore
    }
    
    // MARK: - Generate Recommendations
    
    /// Generates all applicable recommendations based on current state
    /// Returns: Array of advisory recommendations (does not affect behavior)
    public func generateRecommendations() -> [CalibrationRecommendation] {
        var recommendations: [CalibrationRecommendation] = []
        
        // Get current metrics (metadata only)
        let coverage = GoldenCaseCoverageComputer(goldenCaseStore: goldenCaseStore).computeCoverage()
        let trend = QualityTrendComputer(historyStore: historyStore).computeTrend(days: 30)
        let gateResult = QualityGateEvaluator(goldenCaseStore: goldenCaseStore, evalRunner: evalRunner).evaluate()
        let driftSummary = DriftSummaryComputer(evalRunner: evalRunner).computeSummary()
        
        // Coverage recommendations
        recommendations.append(contentsOf: coverageRecommendations(coverage: coverage))
        
        // Freshness recommendations
        recommendations.append(contentsOf: freshnessRecommendations(trend: trend))
        
        // Drift recommendations
        recommendations.append(contentsOf: driftRecommendations(driftSummary: driftSummary, gateResult: gateResult))
        
        // Trend recommendations
        recommendations.append(contentsOf: trendRecommendations(trend: trend))
        
        // Quality gate recommendations
        recommendations.append(contentsOf: qualityGateRecommendations(gateResult: gateResult))
        
        // Release readiness recommendations
        recommendations.append(contentsOf: releaseRecommendations(
            coverage: coverage,
            trend: trend,
            gateResult: gateResult
        ))
        
        // Sort by severity
        return recommendations.sorted { $0.severity.sortOrder < $1.severity.sortOrder }
    }
    
    // MARK: - Coverage Recommendations
    
    private func coverageRecommendations(coverage: GoldenCaseCoverage) -> [CalibrationRecommendation] {
        var recs: [CalibrationRecommendation] = []
        
        if coverage.overallScore < coverageThreshold {
            recs.append(CalibrationRecommendation(
                id: "coverage-low",
                severity: .caution,
                title: "Coverage Below Target",
                message: "Golden case coverage is \(coverage.overallScore)% (target: \(coverageThreshold)%).",
                suggestedNextSteps: [
                    "Pin 1-2 golden cases in missing confidence bands",
                    "Add cases for uncovered intent types",
                    "Review Memory items for representative examples"
                ],
                category: .coverage
            ))
        }
        
        // Specific dimension recommendations
        if !coverage.confidenceBandCoverage.isFullyCovered {
            let missing = coverage.confidenceBandCoverage.missingCategories.joined(separator: ", ")
            recs.append(CalibrationRecommendation(
                id: "coverage-confidence-bands",
                severity: .info,
                title: "Missing Confidence Band Coverage",
                message: "No golden cases for: \(missing)",
                suggestedNextSteps: [
                    "Pin Memory items with different confidence levels",
                    "Low confidence cases help test fallback behavior"
                ],
                category: .coverage
            ))
        }
        
        return recs
    }
    
    // MARK: - Freshness Recommendations
    
    private func freshnessRecommendations(trend: QualityTrend) -> [CalibrationRecommendation] {
        var recs: [CalibrationRecommendation] = []
        
        if let days = trend.daysSinceLastEval, days > freshnessThresholdDays {
            recs.append(CalibrationRecommendation(
                id: "freshness-stale",
                severity: .caution,
                title: "Evaluation Data is Stale",
                message: "Last evaluation was \(days) days ago.",
                suggestedNextSteps: [
                    "Run golden case evaluation before release",
                    "Update eval data weekly for best results"
                ],
                category: .freshness
            ))
        }
        
        if trend.dataPoints < 3 {
            recs.append(CalibrationRecommendation(
                id: "freshness-insufficient-data",
                severity: .info,
                title: "Insufficient Trend Data",
                message: "Run more evaluations to see meaningful trends.",
                suggestedNextSteps: [
                    "Run at least 3 golden case evaluations",
                    "Evaluations can be run from Quality & Trust screen"
                ],
                category: .freshness
            ))
        }
        
        return recs
    }
    
    // MARK: - Drift Recommendations
    
    private func driftRecommendations(
        driftSummary: DriftSummary,
        gateResult: QualityGateResult
    ) -> [CalibrationRecommendation] {
        var recs: [CalibrationRecommendation] = []
        
        if driftSummary.driftLevel == .high {
            recs.append(CalibrationRecommendation(
                id: "drift-high",
                severity: .action,
                title: "High Drift Detected",
                message: "Significant quality regression detected across evaluations.",
                suggestedNextSteps: [
                    "Review recent golden case results",
                    "Check backend availability changes",
                    "Consider updating baseline golden cases"
                ],
                category: .drift
            ))
        }
        
        // Fallback drift
        let fallbackPercent = gateResult.metrics.fallbackDriftPercentage ?? 0.0
        if fallbackPercent > fallbackDriftThresholdPercent {
            recs.append(CalibrationRecommendation(
                id: "drift-fallback",
                severity: .caution,
                title: "Fallback Drift Detected",
                message: "Backend availability may have changed. \(Int(fallbackPercent * 100))% of cases show fallback drift.",
                suggestedNextSteps: [
                    "Check Model Diagnostics in Privacy Controls",
                    "Verify expected backend is still available",
                    "This may be normal if device configuration changed"
                ],
                category: .drift
            ))
        }
        
        return recs
    }
    
    // MARK: - Trend Recommendations
    
    private func trendRecommendations(trend: QualityTrend) -> [CalibrationRecommendation] {
        var recs: [CalibrationRecommendation] = []
        
        if trend.passRateDirection == .degrading {
            recs.append(CalibrationRecommendation(
                id: "trend-degrading",
                severity: .caution,
                title: "Pass Rate Trending Down",
                message: "Quality metrics are declining over recent evaluations.",
                suggestedNextSteps: [
                    "Pin more representative golden cases",
                    "Review recent evaluation failures",
                    "Check if golden cases are still representative"
                ],
                category: .trend
            ))
        }
        
        if trend.passingStreak >= 5 {
            recs.append(CalibrationRecommendation(
                id: "trend-healthy",
                severity: .info,
                title: "Quality is Stable",
                message: "\(trend.passingStreak) consecutive passing evaluations.",
                suggestedNextSteps: [
                    "Continue regular evaluation cadence",
                    "Consider expanding coverage to new scenarios"
                ],
                category: .trend
            ))
        }
        
        return recs
    }
    
    // MARK: - Quality Gate Recommendations
    
    private func qualityGateRecommendations(gateResult: QualityGateResult) -> [CalibrationRecommendation] {
        var recs: [CalibrationRecommendation] = []
        
        if gateResult.status == .fail {
            recs.append(CalibrationRecommendation(
                id: "gate-fail",
                severity: .action,
                title: "Quality Gate Failed",
                message: "Address blocking issues before release.",
                suggestedNextSteps: gateResult.reasons,
                category: .quality
            ))
        }
        
        if gateResult.status == .skipped {
            recs.append(CalibrationRecommendation(
                id: "gate-skipped",
                severity: .caution,
                title: "Quality Gate Skipped",
                message: "Insufficient data to evaluate quality gate.",
                suggestedNextSteps: [
                    "Pin at least \(minimumGoldenCasesForRelease) golden cases",
                    "Run at least one evaluation"
                ],
                category: .quality
            ))
        }
        
        return recs
    }
    
    // MARK: - Release Recommendations
    
    private func releaseRecommendations(
        coverage: GoldenCaseCoverage,
        trend: QualityTrend,
        gateResult: QualityGateResult
    ) -> [CalibrationRecommendation] {
        var recs: [CalibrationRecommendation] = []
        
        // Check release readiness
        if gateResult.metrics.goldenCaseCount < minimumGoldenCasesForRelease {
            recs.append(CalibrationRecommendation(
                id: "release-golden-cases",
                severity: .caution,
                title: "More Golden Cases Needed for Release",
                message: "Have \(gateResult.metrics.goldenCaseCount) golden cases, recommend at least \(minimumGoldenCasesForRelease).",
                suggestedNextSteps: [
                    "Pin additional Memory items as golden cases",
                    "Focus on diverse confidence bands"
                ],
                category: .release
            ))
        }
        
        // Release is looking good
        if gateResult.status == .pass &&
           coverage.overallScore >= coverageThreshold &&
           trend.isFresh {
            recs.append(CalibrationRecommendation(
                id: "release-ready",
                severity: .info,
                title: "Ready for Release",
                message: "Quality gate passed, coverage is good, and data is fresh.",
                suggestedNextSteps: [
                    "Review Release Readiness dashboard",
                    "Record release acknowledgement"
                ],
                category: .release
            ))
        }
        
        return recs
    }
}
