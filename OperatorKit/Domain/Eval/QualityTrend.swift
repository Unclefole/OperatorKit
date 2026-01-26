import Foundation

// ============================================================================
// QUALITY TREND (Phase 9A)
//
// Computes trend analysis from quality history data.
// All computations are content-free and based on aggregate metrics.
//
// INVARIANT: No user content access
// INVARIANT: Pure computation from existing aggregates
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Direction of quality trend
public enum TrendDirection: String, Codable {
    case improving = "Improving"
    case stable = "Stable"
    case degrading = "Degrading"
    case insufficient = "Insufficient Data"
    
    public var systemImage: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "minus"
        case .degrading: return "arrow.down.right"
        case .insufficient: return "questionmark"
        }
    }
    
    public var colorName: String {
        switch self {
        case .improving: return "green"
        case .stable: return "blue"
        case .degrading: return "red"
        case .insufficient: return "gray"
        }
    }
}

/// Quality trend analysis result
public struct QualityTrend: Codable {
    
    // MARK: - Direction
    
    /// Overall pass rate trend
    public let passRateDirection: TrendDirection
    
    /// Drift level trend
    public let driftDirection: TrendDirection
    
    /// Fallback drift trend
    public let fallbackDriftDirection: TrendDirection
    
    // MARK: - Streak
    
    /// Consecutive runs with pass rate >= threshold
    public let passingStreak: Int
    
    /// Consecutive runs with pass rate < threshold
    public let failingStreak: Int
    
    /// Consecutive days with eval runs
    public let evalStreak: Int
    
    // MARK: - Freshness
    
    /// Days since last eval
    public let daysSinceLastEval: Int?
    
    /// Whether data is considered fresh (< 7 days)
    public let isFresh: Bool
    
    // MARK: - Averages
    
    /// Average pass rate over period
    public let averagePassRate: Double
    
    /// Average cases per run
    public let averageCasesPerRun: Double
    
    // MARK: - Metadata
    
    /// Analysis period (days)
    public let periodDays: Int
    
    /// Number of data points
    public let dataPoints: Int
    
    /// When this trend was computed
    public let computedAt: Date
}

/// Computes quality trends from history data
public final class QualityTrendComputer {
    
    private let historyStore: QualityHistoryStore
    
    /// Minimum data points for meaningful trend
    public let minimumDataPoints = 3
    
    /// Pass rate threshold for "passing"
    public let passRateThreshold = 0.80
    
    /// Freshness threshold (days)
    public let freshnessThresholdDays = 7
    
    public init(historyStore: QualityHistoryStore = .shared) {
        self.historyStore = historyStore
    }
    
    /// Computes trend for the last N days
    public func computeTrend(days: Int = 30) -> QualityTrend {
        let summaries = historyStore.summariesForLast(days: days)
        let sortedSummaries = summaries.sorted { $0.date < $1.date }
        
        // Freshness
        let daysSinceLastEval: Int?
        if let mostRecent = sortedSummaries.last {
            daysSinceLastEval = Calendar.current.dateComponents([.day], from: mostRecent.date, to: Date()).day
        } else {
            daysSinceLastEval = nil
        }
        let isFresh = daysSinceLastEval.map { $0 <= freshnessThresholdDays } ?? false
        
        // Check if we have enough data
        guard sortedSummaries.count >= minimumDataPoints else {
            return QualityTrend(
                passRateDirection: .insufficient,
                driftDirection: .insufficient,
                fallbackDriftDirection: .insufficient,
                passingStreak: 0,
                failingStreak: 0,
                evalStreak: 0,
                daysSinceLastEval: daysSinceLastEval,
                isFresh: isFresh,
                averagePassRate: 0,
                averageCasesPerRun: 0,
                periodDays: days,
                dataPoints: sortedSummaries.count,
                computedAt: Date()
            )
        }
        
        // Compute directions
        let passRates = sortedSummaries.map { $0.passRate }
        let passRateDirection = computeDirection(values: passRates)
        
        let driftLevels = sortedSummaries.compactMap { driftLevelToScore($0.driftLevel) }
        let driftDirection = computeDirection(values: driftLevels, invertedIsGood: true)
        
        let fallbackCounts = sortedSummaries.map { Double($0.fallbackDriftCount) }
        let fallbackDriftDirection = computeDirection(values: fallbackCounts, invertedIsGood: true)
        
        // Compute streaks
        let passingStreak = computeStreak(summaries: sortedSummaries.reversed()) { $0.passRate >= passRateThreshold }
        let failingStreak = computeStreak(summaries: sortedSummaries.reversed()) { $0.passRate < passRateThreshold }
        let evalStreak = computeEvalStreak(summaries: sortedSummaries)
        
        // Compute averages
        let avgPassRate = passRates.reduce(0, +) / Double(passRates.count)
        let avgCases = sortedSummaries.map { Double($0.totalCasesEvaluated) }.reduce(0, +) / Double(sortedSummaries.count)
        
        return QualityTrend(
            passRateDirection: passRateDirection,
            driftDirection: driftDirection,
            fallbackDriftDirection: fallbackDriftDirection,
            passingStreak: passingStreak,
            failingStreak: failingStreak,
            evalStreak: evalStreak,
            daysSinceLastEval: daysSinceLastEval,
            isFresh: isFresh,
            averagePassRate: avgPassRate,
            averageCasesPerRun: avgCases,
            periodDays: days,
            dataPoints: sortedSummaries.count,
            computedAt: Date()
        )
    }
    
    // MARK: - Helpers
    
    private func computeDirection(values: [Double], invertedIsGood: Bool = false) -> TrendDirection {
        guard values.count >= 2 else { return .insufficient }
        
        // Simple linear regression slope
        let n = Double(values.count)
        let indices = (0..<values.count).map { Double($0) }
        
        let sumX = indices.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(indices, values).map { $0 * $1 }.reduce(0, +)
        let sumX2 = indices.map { $0 * $0 }.reduce(0, +)
        
        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return .stable }
        
        let slope = (n * sumXY - sumX * sumY) / denominator
        
        // Determine direction based on slope magnitude
        let significanceThreshold = 0.01 // Adjust as needed
        
        if abs(slope) < significanceThreshold {
            return .stable
        } else if slope > 0 {
            return invertedIsGood ? .degrading : .improving
        } else {
            return invertedIsGood ? .improving : .degrading
        }
    }
    
    private func driftLevelToScore(_ level: String?) -> Double? {
        guard let level = level else { return nil }
        switch level.lowercased() {
        case "none": return 0
        case "low": return 1
        case "moderate": return 2
        case "high": return 3
        default: return nil
        }
    }
    
    private func computeStreak<T>(
        summaries: ReversedCollection<[T]>,
        matching: (T) -> Bool
    ) -> Int {
        var streak = 0
        for summary in summaries {
            if matching(summary) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
    
    private func computeEvalStreak(summaries: [DailyQualitySummary]) -> Int {
        guard !summaries.isEmpty else { return 0 }
        
        let sortedDates = summaries.map { $0.normalizedDate }.sorted().reversed()
        var streak = 0
        var expectedDate = Calendar.current.startOfDay(for: Date())
        
        for date in sortedDates {
            if Calendar.current.isDate(date, inSameDayAs: expectedDate) {
                streak += 1
                expectedDate = Calendar.current.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            } else if date < expectedDate {
                break
            }
        }
        
        return streak
    }
}
