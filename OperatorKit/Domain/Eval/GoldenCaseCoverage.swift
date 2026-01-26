import Foundation

// ============================================================================
// GOLDEN CASE COVERAGE (Phase 9A)
//
// Computes coverage analysis across scenario dimensions.
// All computations are content-free, based on metadata only.
//
// INVARIANT: No user content access
// INVARIANT: Categories are generic, not content-derived
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Coverage categories for golden cases
public struct GoldenCaseCoverage {
    
    // MARK: - Dimensions
    
    /// Intent type coverage (email / summary / action_items / plan)
    public let intentTypeCoverage: CoverageDimension
    
    /// Confidence band coverage (low / medium / high)
    public let confidenceBandCoverage: CoverageDimension
    
    /// Backend type coverage (deterministic / coreml / apple-on-device)
    public let backendTypeCoverage: CoverageDimension
    
    // MARK: - Overall
    
    /// Overall coverage score (0-100)
    public let overallScore: Int
    
    /// Missing coverage suggestions
    public let missingCoverage: [CoverageSuggestion]
    
    /// Total golden cases analyzed
    public let totalCases: Int
    
    /// When this coverage was computed
    public let computedAt: Date
}

/// Coverage for a single dimension
public struct CoverageDimension: Codable {
    /// Name of this dimension
    public let name: String
    
    /// Categories in this dimension
    public let categories: [String]
    
    /// Covered categories
    public let coveredCategories: [String]
    
    /// Count per category
    public let categoryCounts: [String: Int]
    
    /// Coverage percentage (0-100)
    public var coveragePercent: Int {
        guard !categories.isEmpty else { return 0 }
        return Int(Double(coveredCategories.count) / Double(categories.count) * 100)
    }
    
    /// Missing categories
    public var missingCategories: [String] {
        categories.filter { !coveredCategories.contains($0) }
    }
    
    /// Whether fully covered
    public var isFullyCovered: Bool {
        missingCategories.isEmpty
    }
}

/// Suggestion for improving coverage
public struct CoverageSuggestion: Identifiable, Codable {
    public let id: UUID
    public let dimension: String
    public let category: String
    public let suggestion: String
    public let priority: Priority
    
    public enum Priority: String, Codable {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        
        public var sortOrder: Int {
            switch self {
            case .high: return 0
            case .medium: return 1
            case .low: return 2
            }
        }
    }
    
    public init(dimension: String, category: String, suggestion: String, priority: Priority) {
        self.id = UUID()
        self.dimension = dimension
        self.category = category
        self.suggestion = suggestion
        self.priority = priority
    }
}

/// Computes golden case coverage
public final class GoldenCaseCoverageComputer {
    
    private let goldenCaseStore: GoldenCaseStore
    
    // MARK: - Expected Categories
    
    /// Expected intent types
    public static let expectedIntentTypes = ["email", "summary", "action_items", "plan", "unknown"]
    
    /// Expected confidence bands
    public static let expectedConfidenceBands = ["low", "medium", "high", "unknown"]
    
    /// Expected backend types
    public static let expectedBackendTypes = ["DeterministicTemplateModel", "CoreMLModelBackend", "AppleOnDeviceModelBackend"]
    
    public init(goldenCaseStore: GoldenCaseStore = .shared) {
        self.goldenCaseStore = goldenCaseStore
    }
    
    /// Computes current coverage
    public func computeCoverage() -> GoldenCaseCoverage {
        let cases = goldenCaseStore.cases
        
        // Intent type coverage
        let intentTypeCoverage = computeIntentTypeCoverage(cases: cases)
        
        // Confidence band coverage
        let confidenceBandCoverage = computeConfidenceBandCoverage(cases: cases)
        
        // Backend type coverage
        let backendTypeCoverage = computeBackendTypeCoverage(cases: cases)
        
        // Overall score (weighted average)
        let overallScore = computeOverallScore(
            intentTypeCoverage: intentTypeCoverage,
            confidenceBandCoverage: confidenceBandCoverage,
            backendTypeCoverage: backendTypeCoverage
        )
        
        // Generate suggestions
        let suggestions = generateSuggestions(
            intentTypeCoverage: intentTypeCoverage,
            confidenceBandCoverage: confidenceBandCoverage,
            backendTypeCoverage: backendTypeCoverage
        )
        
        return GoldenCaseCoverage(
            intentTypeCoverage: intentTypeCoverage,
            confidenceBandCoverage: confidenceBandCoverage,
            backendTypeCoverage: backendTypeCoverage,
            overallScore: overallScore,
            missingCoverage: suggestions,
            totalCases: cases.count,
            computedAt: Date()
        )
    }
    
    // MARK: - Dimension Computation
    
    private func computeIntentTypeCoverage(cases: [GoldenCase]) -> CoverageDimension {
        var counts: [String: Int] = [:]
        for intentType in Self.expectedIntentTypes {
            counts[intentType] = 0
        }
        
        for goldenCase in cases {
            let intentType = goldenCase.snapshot.intentType.lowercased()
            // Normalize to expected categories
            let normalized = Self.expectedIntentTypes.contains(intentType) ? intentType : "unknown"
            counts[normalized, default: 0] += 1
        }
        
        let covered = counts.filter { $0.value > 0 }.map { $0.key }
        
        return CoverageDimension(
            name: "Intent Types",
            categories: Self.expectedIntentTypes,
            coveredCategories: covered,
            categoryCounts: counts
        )
    }
    
    private func computeConfidenceBandCoverage(cases: [GoldenCase]) -> CoverageDimension {
        var counts: [String: Int] = [:]
        for band in Self.expectedConfidenceBands {
            counts[band] = 0
        }
        
        for goldenCase in cases {
            let band = goldenCase.snapshot.confidenceBand.lowercased()
            let normalized = Self.expectedConfidenceBands.contains(band) ? band : "unknown"
            counts[normalized, default: 0] += 1
        }
        
        let covered = counts.filter { $0.value > 0 }.map { $0.key }
        
        return CoverageDimension(
            name: "Confidence Bands",
            categories: Self.expectedConfidenceBands,
            coveredCategories: covered,
            categoryCounts: counts
        )
    }
    
    private func computeBackendTypeCoverage(cases: [GoldenCase]) -> CoverageDimension {
        var counts: [String: Int] = [:]
        for backend in Self.expectedBackendTypes {
            counts[backend] = 0
        }
        
        for goldenCase in cases {
            let backend = goldenCase.snapshot.backendUsed
            if Self.expectedBackendTypes.contains(backend) {
                counts[backend, default: 0] += 1
            }
        }
        
        let covered = counts.filter { $0.value > 0 }.map { $0.key }
        
        return CoverageDimension(
            name: "Backend Types",
            categories: Self.expectedBackendTypes,
            coveredCategories: covered,
            categoryCounts: counts
        )
    }
    
    // MARK: - Overall Score
    
    private func computeOverallScore(
        intentTypeCoverage: CoverageDimension,
        confidenceBandCoverage: CoverageDimension,
        backendTypeCoverage: CoverageDimension
    ) -> Int {
        // Weighted average: confidence bands matter most (40%), intent types (35%), backends (25%)
        let weighted = Double(intentTypeCoverage.coveragePercent) * 0.35 +
                       Double(confidenceBandCoverage.coveragePercent) * 0.40 +
                       Double(backendTypeCoverage.coveragePercent) * 0.25
        return Int(weighted)
    }
    
    // MARK: - Suggestions
    
    private func generateSuggestions(
        intentTypeCoverage: CoverageDimension,
        confidenceBandCoverage: CoverageDimension,
        backendTypeCoverage: CoverageDimension
    ) -> [CoverageSuggestion] {
        var suggestions: [CoverageSuggestion] = []
        
        // Confidence band suggestions (highest priority)
        for missing in confidenceBandCoverage.missingCategories {
            let priority: CoverageSuggestion.Priority = missing == "low" ? .high : .medium
            let suggestion = suggestionText(forConfidenceBand: missing)
            suggestions.append(CoverageSuggestion(
                dimension: "Confidence Band",
                category: missing,
                suggestion: suggestion,
                priority: priority
            ))
        }
        
        // Intent type suggestions
        for missing in intentTypeCoverage.missingCategories {
            let suggestion = suggestionText(forIntentType: missing)
            suggestions.append(CoverageSuggestion(
                dimension: "Intent Type",
                category: missing,
                suggestion: suggestion,
                priority: .medium
            ))
        }
        
        // Backend suggestions (lowest priority - depends on device capabilities)
        for missing in backendTypeCoverage.missingCategories where missing != "AppleOnDeviceModelBackend" {
            let suggestion = suggestionText(forBackend: missing)
            suggestions.append(CoverageSuggestion(
                dimension: "Backend",
                category: missing,
                suggestion: suggestion,
                priority: .low
            ))
        }
        
        return suggestions.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }
    
    private func suggestionText(forConfidenceBand band: String) -> String {
        switch band.lowercased() {
        case "low":
            return "Pin a memory item with low confidence (<0.35) to test edge cases"
        case "medium":
            return "Pin a memory item with medium confidence (0.35-0.65) to test warning flows"
        case "high":
            return "Pin a memory item with high confidence (>0.65) to verify normal operation"
        default:
            return "Pin a memory item in this confidence range"
        }
    }
    
    private func suggestionText(forIntentType type: String) -> String {
        switch type.lowercased() {
        case "email":
            return "Pin an email draft memory item"
        case "summary":
            return "Pin a summary/meeting notes memory item"
        case "action_items":
            return "Pin a memory item with action items"
        case "plan":
            return "Pin a planning/reminder memory item"
        default:
            return "Pin a memory item of this type"
        }
    }
    
    private func suggestionText(forBackend backend: String) -> String {
        switch backend {
        case "DeterministicTemplateModel":
            return "Ensure deterministic fallback coverage"
        case "CoreMLModelBackend":
            return "Pin items generated with Core ML (if model available)"
        case "AppleOnDeviceModelBackend":
            return "Pin items generated with Apple on-device model (if available)"
        default:
            return "Expand backend coverage"
        }
    }
}
