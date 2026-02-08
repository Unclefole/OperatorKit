import Foundation

// ============================================================================
// RELEASE COMPARISON (Phase 9A)
//
// Compares quality metrics across release channels (Debug vs TestFlight).
// All comparisons are metadata-only, content-free.
//
// INVARIANT: No user content access
// INVARIANT: Comparison based on signatures and aggregates only
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Comparison between two release channels
public struct ReleaseComparison {
    
    /// Channel being compared
    public let channelA: ReleaseChannelSummary
    public let channelB: ReleaseChannelSummary
    
    /// Differences between channels
    public let signatureDiffs: [SignatureDiff]
    
    /// Metric comparisons
    public let metricComparisons: [MetricComparison]
    
    /// Overall verdict
    public let verdict: ComparisonVerdict
    
    /// When this comparison was computed
    public let computedAt: Date
}

/// Summary of a release channel
public struct ReleaseChannelSummary: Codable {
    public let releaseMode: String
    public let runCount: Int
    public let totalCases: Int
    public let averagePassRate: Double
    public let latestDriftLevel: String?
    public let latestSignature: QualitySignature?
    public let dateRange: DateRange?
    
    public struct DateRange: Codable {
        public let earliest: Date
        public let latest: Date
    }
}

/// Comparison of a specific metric
public struct MetricComparison: Codable, Identifiable {
    public let id: UUID
    public let metricName: String
    public let channelAValue: String
    public let channelBValue: String
    public let delta: String
    public let status: ComparisonStatus
    
    public enum ComparisonStatus: String, Codable {
        case better = "Better"
        case same = "Same"
        case worse = "Worse"
        case inconclusive = "Inconclusive"
        
        public var systemImage: String {
            switch self {
            case .better: return "arrow.up.circle.fill"
            case .same: return "equal.circle.fill"
            case .worse: return "arrow.down.circle.fill"
            case .inconclusive: return "questionmark.circle.fill"
            }
        }
        
        public var colorName: String {
            switch self {
            case .better: return "green"
            case .same: return "blue"
            case .worse: return "red"
            case .inconclusive: return "gray"
            }
        }
    }
    
    public init(metricName: String, channelAValue: String, channelBValue: String, delta: String, status: ComparisonStatus) {
        self.id = UUID()
        self.metricName = metricName
        self.channelAValue = channelAValue
        self.channelBValue = channelBValue
        self.delta = delta
        self.status = status
    }
}

/// Overall comparison verdict
public enum ComparisonVerdict: String, Codable {
    case channelABetter = "Channel A Better"
    case channelBBetter = "Channel B Better"
    case equivalent = "Equivalent"
    case inconclusive = "Inconclusive"
    case insufficientData = "Insufficient Data"
    
    public var displayName: String { rawValue }
    
    public var systemImage: String {
        switch self {
        case .channelABetter: return "a.circle.fill"
        case .channelBBetter: return "b.circle.fill"
        case .equivalent: return "equal.circle.fill"
        case .inconclusive, .insufficientData: return "questionmark.circle.fill"
        }
    }
}

/// Computes release channel comparisons
public final class ReleaseComparisonComputer {
    
    private let evalRunner: LocalEvalRunner
    private let historyStore: QualityHistoryStore
    
    public init(
        evalRunner: LocalEvalRunner = .shared,
        historyStore: QualityHistoryStore = .shared
    ) {
        self.evalRunner = evalRunner
        self.historyStore = historyStore
    }
    
    /// Compares Debug vs TestFlight channels
    public func compareDebugVsTestFlight() -> ReleaseComparison {
        return compare(channelA: "debug", channelB: "testflight")
    }
    
    /// Compares two release channels
    public func compare(channelA: String, channelB: String) -> ReleaseComparison {
        let summaryA = buildChannelSummary(releaseMode: channelA)
        let summaryB = buildChannelSummary(releaseMode: channelB)
        
        // Compute signature diffs if both have signatures
        var signatureDiffs: [SignatureDiff] = []
        if let sigA = summaryA.latestSignature, let sigB = summaryB.latestSignature {
            signatureDiffs = sigA.diff(from: sigB)
        }
        
        // Compute metric comparisons
        let metricComparisons = buildMetricComparisons(summaryA: summaryA, summaryB: summaryB)
        
        // Determine verdict
        let verdict = determineVerdict(comparisons: metricComparisons, summaryA: summaryA, summaryB: summaryB)
        
        return ReleaseComparison(
            channelA: summaryA,
            channelB: summaryB,
            signatureDiffs: signatureDiffs,
            metricComparisons: metricComparisons,
            verdict: verdict,
            computedAt: Date()
        )
    }
    
    // MARK: - Helpers
    
    private func buildChannelSummary(releaseMode: String) -> ReleaseChannelSummary {
        // Get runs for this channel
        let channelRuns = evalRunner.runs.filter {
            $0.qualitySignature?.releaseMode.lowercased() == releaseMode.lowercased()
        }
        
        // Get history for this channel
        let channelHistory = historyStore.summaries(forReleaseMode: releaseMode)
        
        // Compute aggregates
        let totalCases = channelRuns.flatMap { $0.results }.count
        let passRates = channelRuns.map { $0.passRate }
        let averagePassRate = passRates.isEmpty ? 0.0 : passRates.reduce(0, +) / Double(passRates.count)
        
        // Latest signature
        let latestSignature = channelRuns.sorted { $0.startedAt > $1.startedAt }.first?.qualitySignature
        
        // Latest drift level
        let latestDriftLevel = channelHistory.sorted { $0.date > $1.date }.first?.driftLevel
        
        // Date range
        var dateRange: ReleaseChannelSummary.DateRange? = nil
        if let earliest = channelRuns.sorted(by: { $0.startedAt < $1.startedAt }).first?.startedAt,
           let latest = channelRuns.sorted(by: { $0.startedAt > $1.startedAt }).first?.startedAt {
            dateRange = ReleaseChannelSummary.DateRange(earliest: earliest, latest: latest)
        }
        
        return ReleaseChannelSummary(
            releaseMode: releaseMode,
            runCount: channelRuns.count,
            totalCases: totalCases,
            averagePassRate: averagePassRate,
            latestDriftLevel: latestDriftLevel,
            latestSignature: latestSignature,
            dateRange: dateRange
        )
    }
    
    private func buildMetricComparisons(
        summaryA: ReleaseChannelSummary,
        summaryB: ReleaseChannelSummary
    ) -> [MetricComparison] {
        var comparisons: [MetricComparison] = []
        
        // Pass rate comparison
        let passRateDelta = summaryB.averagePassRate - summaryA.averagePassRate
        let passRateStatus: MetricComparison.ComparisonStatus
        if abs(passRateDelta) < 0.05 {
            passRateStatus = .same
        } else if passRateDelta > 0 {
            passRateStatus = .better
        } else {
            passRateStatus = .worse
        }
        
        comparisons.append(MetricComparison(
            metricName: "Pass Rate",
            channelAValue: String(format: "%.0f%%", summaryA.averagePassRate * 100),
            channelBValue: String(format: "%.0f%%", summaryB.averagePassRate * 100),
            delta: String(format: "%+.0f%%", passRateDelta * 100),
            status: passRateStatus
        ))
        
        // Run count comparison
        comparisons.append(MetricComparison(
            metricName: "Eval Runs",
            channelAValue: "\(summaryA.runCount)",
            channelBValue: "\(summaryB.runCount)",
            delta: "\(summaryB.runCount - summaryA.runCount)",
            status: summaryA.runCount >= 3 && summaryB.runCount >= 3 ? .same : .inconclusive
        ))
        
        // Cases evaluated
        comparisons.append(MetricComparison(
            metricName: "Total Cases",
            channelAValue: "\(summaryA.totalCases)",
            channelBValue: "\(summaryB.totalCases)",
            delta: "\(summaryB.totalCases - summaryA.totalCases)",
            status: .same
        ))
        
        // Drift level comparison
        let driftA = summaryA.latestDriftLevel ?? "Unknown"
        let driftB = summaryB.latestDriftLevel ?? "Unknown"
        let driftStatus = compareDriftLevels(a: driftA, b: driftB)
        
        comparisons.append(MetricComparison(
            metricName: "Drift Level",
            channelAValue: driftA,
            channelBValue: driftB,
            delta: driftStatus == .same ? "Equal" : (driftStatus == .better ? "Improved" : "Degraded"),
            status: driftStatus
        ))
        
        return comparisons
    }
    
    private func compareDriftLevels(a: String, b: String) -> MetricComparison.ComparisonStatus {
        let order = ["none": 0, "low": 1, "moderate": 2, "high": 3, "unknown": 4]
        let scoreA = order[a.lowercased()] ?? 4
        let scoreB = order[b.lowercased()] ?? 4
        
        if scoreA == scoreB { return .same }
        if scoreB < scoreA { return .better }
        return .worse
    }
    
    private func determineVerdict(
        comparisons: [MetricComparison],
        summaryA: ReleaseChannelSummary,
        summaryB: ReleaseChannelSummary
    ) -> ComparisonVerdict {
        // Need minimum data
        guard summaryA.runCount >= 1 && summaryB.runCount >= 1 else {
            return .insufficientData
        }
        
        // Count wins
        var aWins = 0
        var bWins = 0
        
        for comparison in comparisons {
            switch comparison.status {
            case .better: bWins += 1
            case .worse: aWins += 1
            case .same, .inconclusive: break
            }
        }
        
        if aWins > bWins {
            return .channelABetter
        } else if bWins > aWins {
            return .channelBBetter
        } else if aWins == 0 && bWins == 0 {
            return .equivalent
        } else {
            return .inconclusive
        }
    }
}
