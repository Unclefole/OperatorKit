import Foundation

// ============================================================================
// QUALITY CALIBRATION (Phase 8A)
//
// Local-only calibration based on user feedback.
// INVARIANT: Does NOT change execution rules or model behavior
// INVARIANT: Can only adjust copy, recommendations, and UI suggestions
// INVARIANT: No network transmission
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Summary statistics computed from local feedback
public struct CalibrationSummary {
    
    public let totalEntries: Int
    public let helpfulCount: Int
    public let notHelpfulCount: Int
    public let mixedCount: Int
    
    public let helpfulRateOverall: Double
    public let helpfulRateByBackend: [String: Double]
    public let helpfulRateByConfidenceBand: [ConfidenceBand: Double]
    
    public let topIssueTags: [(tag: QualityIssueTag, count: Int)]
    public let fallbackFeedbackCount: Int
    public let timeoutFeedbackCount: Int
    
    public let lastUpdated: Date
    
    // MARK: - Confidence Bands
    
    public enum ConfidenceBand: String, CaseIterable {
        case low = "<0.35"
        case medium = "0.35-0.65"
        case high = ">=0.65"
        
        public var range: ClosedRange<Double> {
            switch self {
            case .low: return 0.0...0.349
            case .medium: return 0.35...0.649
            case .high: return 0.65...1.0
            }
        }
        
        public var displayName: String {
            switch self {
            case .low: return "Low (under 35%)"
            case .medium: return "Medium (35-65%)"
            case .high: return "High (65%+)"
            }
        }
    }
    
    // MARK: - Computed Properties
    
    public var hasEnoughData: Bool {
        totalEntries >= 5
    }
    
    public var overallTrustLevel: TrustLevel {
        guard hasEnoughData else { return .insufficient }
        
        if helpfulRateOverall >= 0.8 {
            return .high
        } else if helpfulRateOverall >= 0.5 {
            return .moderate
        } else {
            return .needsImprovement
        }
    }
    
    public enum TrustLevel: String {
        case insufficient = "Not enough data"
        case needsImprovement = "Needs improvement"
        case moderate = "Moderate"
        case high = "High"
        
        public var systemImage: String {
            switch self {
            case .insufficient: return "questionmark.circle"
            case .needsImprovement: return "exclamationmark.triangle"
            case .moderate: return "checkmark.circle"
            case .high: return "checkmark.seal.fill"
            }
        }
        
        public var color: String {
            switch self {
            case .insufficient: return "gray"
            case .needsImprovement: return "orange"
            case .moderate: return "blue"
            case .high: return "green"
            }
        }
    }
}

// MARK: - Calibration Computer

/// Computes calibration summary from feedback data
/// INVARIANT: Read-only analysis, no side effects
public final class QualityCalibrationComputer {
    
    private let feedbackStore: QualityFeedbackStore
    
    public init(feedbackStore: QualityFeedbackStore = .shared) {
        self.feedbackStore = feedbackStore
    }
    
    /// Computes current calibration summary
    public func computeSummary() -> CalibrationSummary {
        let entries = feedbackStore.entries
        
        let totalEntries = entries.count
        let helpfulCount = entries.filter { $0.rating == .helpful }.count
        let notHelpfulCount = entries.filter { $0.rating == .notHelpful }.count
        let mixedCount = entries.filter { $0.rating == .mixed }.count
        
        // Overall helpful rate
        let helpfulRateOverall = totalEntries > 0 
            ? Double(helpfulCount) / Double(totalEntries) 
            : 0.0
        
        // By backend
        let helpfulRateByBackend = computeHelpfulRateByBackend(entries)
        
        // By confidence band
        let helpfulRateByConfidenceBand = computeHelpfulRateByConfidenceBand(entries)
        
        // Top issue tags
        let topIssueTags = computeTopIssueTags(entries)
        
        // Fallback and timeout counts
        let fallbackFeedbackCount = entries.filter { $0.usedFallback }.count
        let timeoutFeedbackCount = entries.filter { $0.timeoutOccurred }.count
        
        return CalibrationSummary(
            totalEntries: totalEntries,
            helpfulCount: helpfulCount,
            notHelpfulCount: notHelpfulCount,
            mixedCount: mixedCount,
            helpfulRateOverall: helpfulRateOverall,
            helpfulRateByBackend: helpfulRateByBackend,
            helpfulRateByConfidenceBand: helpfulRateByConfidenceBand,
            topIssueTags: topIssueTags,
            fallbackFeedbackCount: fallbackFeedbackCount,
            timeoutFeedbackCount: timeoutFeedbackCount,
            lastUpdated: Date()
        )
    }
    
    private func computeHelpfulRateByBackend(_ entries: [QualityFeedbackEntry]) -> [String: Double] {
        var result: [String: Double] = [:]
        
        let backends = Set(entries.compactMap { $0.modelBackend })
        
        for backend in backends {
            let backendEntries = entries.filter { $0.modelBackend == backend }
            let helpfulCount = backendEntries.filter { $0.rating == .helpful }.count
            result[backend] = backendEntries.isEmpty 
                ? 0.0 
                : Double(helpfulCount) / Double(backendEntries.count)
        }
        
        return result
    }
    
    private func computeHelpfulRateByConfidenceBand(_ entries: [QualityFeedbackEntry]) -> [CalibrationSummary.ConfidenceBand: Double] {
        var result: [CalibrationSummary.ConfidenceBand: Double] = [:]
        
        for band in CalibrationSummary.ConfidenceBand.allCases {
            let bandEntries = entries.filter { entry in
                guard let confidence = entry.confidence else { return false }
                return band.range.contains(confidence)
            }
            let helpfulCount = bandEntries.filter { $0.rating == .helpful }.count
            result[band] = bandEntries.isEmpty 
                ? 0.0 
                : Double(helpfulCount) / Double(bandEntries.count)
        }
        
        return result
    }
    
    private func computeTopIssueTags(_ entries: [QualityFeedbackEntry]) -> [(tag: QualityIssueTag, count: Int)] {
        var tagCounts: [QualityIssueTag: Int] = [:]
        
        for entry in entries {
            for tag in entry.issueTags {
                tagCounts[tag, default: 0] += 1
            }
        }
        
        return tagCounts
            .map { (tag: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }
}

// MARK: - Calibration Recommendations

/// Generates user-facing recommendations based on calibration
/// INVARIANT: Does NOT change execution behavior
/// INVARIANT: Only affects copy and suggestions
public struct CalibrationRecommendations {
    
    public let contextRecommendation: String?
    public let confidenceRecommendation: String?
    public let generalTip: String?
    
    public static func generate(from summary: CalibrationSummary) -> CalibrationRecommendations {
        var contextRec: String? = nil
        var confidenceRec: String? = nil
        var generalTip: String? = nil
        
        // Check if missing context is a top issue
        if let topTag = summary.topIssueTags.first?.tag, topTag == .missingContext {
            contextRec = "Consider selecting more context items for better results."
        }
        
        // Check low confidence band performance
        if let lowRate = summary.helpfulRateByConfidenceBand[.low], lowRate < 0.3 {
            confidenceRec = "Drafts with low confidence may need more review or additional context."
        }
        
        // General tip based on overall trust
        switch summary.overallTrustLevel {
        case .needsImprovement:
            generalTip = "Your feedback helps calibrate OperatorKit. Consider adding more context when possible."
        case .moderate:
            generalTip = "OperatorKit is working well for you. Keep providing feedback to improve further."
        case .high:
            generalTip = "OperatorKit is well-calibrated for your use. Thank you for your feedback."
        case .insufficient:
            generalTip = "Rate a few more drafts to see personalized recommendations."
        }
        
        return CalibrationRecommendations(
            contextRecommendation: contextRec,
            confidenceRecommendation: confidenceRec,
            generalTip: generalTip
        )
    }
}
