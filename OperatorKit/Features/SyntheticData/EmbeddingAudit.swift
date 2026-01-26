import Foundation
import NaturalLanguage

// ============================================================================
// EMBEDDING AUDIT (Phase 13I)
//
// Distribution Match using NaturalLanguage framework.
// Computes cosine similarity between synthetic intents and seed intents.
//
// CONSTRAINTS:
// ❌ No networking
// ❌ No user content
// ❌ No file writes
// ✅ On-device NLEmbedding only
// ✅ Deterministic results (sorted outputs)
// ============================================================================

// MARK: - Configuration Constants

public enum EmbeddingAuditConstants {
    /// Minimum overlap percentage to pass distribution match (85%)
    public static let minimumOverlapThreshold: Double = 0.85
    
    /// Minimum mean similarity to pass (0.70)
    public static let minimumMeanSimilarity: Double = 0.70
    
    /// Maximum p95 deviation allowed (0.40)
    public static let maximumP95Deviation: Double = 0.40
    
    /// Similarity threshold for "overlap" classification (0.75)
    public static let overlapSimilarityThreshold: Double = 0.75
    
    /// Language for embedding model
    public static let embeddingLanguage: NLLanguage = .english
    
    /// Revision for embedding model (nil = latest)
    public static let embeddingRevision: Int? = nil
}

// MARK: - Audit Results

/// Result of embedding distribution match audit
public struct EmbeddingAuditResult: Equatable {
    /// Whether the audit passed all thresholds
    public let passed: Bool
    
    /// Overlap percentage (synthetic intents covered by seed set)
    public let overlapPercentage: Double
    
    /// Mean cosine similarity
    public let meanSimilarity: Double
    
    /// 95th percentile similarity
    public let p95Similarity: Double
    
    /// Minimum similarity observed
    public let minSimilarity: Double
    
    /// Maximum similarity observed
    public let maxSimilarity: Double
    
    /// Number of synthetic intents analyzed
    public let syntheticIntentCount: Int
    
    /// Number of seed intents used
    public let seedIntentCount: Int
    
    /// Intents that did not meet overlap threshold
    public let unmatchedIntents: [String]
    
    /// Embedding model availability
    public let embeddingAvailable: Bool
    
    /// Audit duration
    public let auditDuration: TimeInterval
    
    /// Failure reasons (if any)
    public let failureReasons: [String]
    
    public init(
        passed: Bool,
        overlapPercentage: Double,
        meanSimilarity: Double,
        p95Similarity: Double,
        minSimilarity: Double,
        maxSimilarity: Double,
        syntheticIntentCount: Int,
        seedIntentCount: Int,
        unmatchedIntents: [String],
        embeddingAvailable: Bool,
        auditDuration: TimeInterval,
        failureReasons: [String]
    ) {
        self.passed = passed
        self.overlapPercentage = overlapPercentage
        self.meanSimilarity = meanSimilarity
        self.p95Similarity = p95Similarity
        self.minSimilarity = minSimilarity
        self.maxSimilarity = maxSimilarity
        self.syntheticIntentCount = syntheticIntentCount
        self.seedIntentCount = seedIntentCount
        self.unmatchedIntents = unmatchedIntents
        self.embeddingAvailable = embeddingAvailable
        self.auditDuration = auditDuration
        self.failureReasons = failureReasons
    }
}

// MARK: - Similarity Pair

/// A similarity measurement between two intents
public struct IntentSimilarityPair: Equatable, Comparable {
    public let syntheticIntent: String
    public let closestSeedIntent: String
    public let similarity: Double
    
    public static func < (lhs: IntentSimilarityPair, rhs: IntentSimilarityPair) -> Bool {
        lhs.similarity < rhs.similarity
    }
}

// MARK: - Embedding Auditor

public enum EmbeddingAuditor {
    
    /// Check if sentence embedding is available
    public static var isEmbeddingAvailable: Bool {
        NLEmbedding.sentenceEmbedding(for: EmbeddingAuditConstants.embeddingLanguage) != nil
    }
    
    /// Run distribution match audit
    /// - Parameters:
    ///   - syntheticIntents: Intents from synthetic corpus to verify
    ///   - seedIntents: Hand-verified seed intents
    ///   - overlapThreshold: Minimum overlap percentage (default: 85%)
    /// - Returns: Audit result with metrics
    public static func runDistributionMatch(
        syntheticIntents: [String],
        seedIntents: [String],
        overlapThreshold: Double = EmbeddingAuditConstants.minimumOverlapThreshold
    ) -> EmbeddingAuditResult {
        let startTime = Date()
        
        // Check embedding availability
        guard let embedding = NLEmbedding.sentenceEmbedding(for: EmbeddingAuditConstants.embeddingLanguage) else {
            return EmbeddingAuditResult(
                passed: false,
                overlapPercentage: 0,
                meanSimilarity: 0,
                p95Similarity: 0,
                minSimilarity: 0,
                maxSimilarity: 0,
                syntheticIntentCount: syntheticIntents.count,
                seedIntentCount: seedIntents.count,
                unmatchedIntents: [],
                embeddingAvailable: false,
                auditDuration: Date().timeIntervalSince(startTime),
                failureReasons: ["NLEmbedding not available for language: \(EmbeddingAuditConstants.embeddingLanguage.rawValue)"]
            )
        }
        
        // Deduplicate and sort for determinism
        let uniqueSynthetic = Array(Set(syntheticIntents)).sorted()
        let uniqueSeed = Array(Set(seedIntents)).sorted()
        
        guard !uniqueSynthetic.isEmpty && !uniqueSeed.isEmpty else {
            return EmbeddingAuditResult(
                passed: false,
                overlapPercentage: 0,
                meanSimilarity: 0,
                p95Similarity: 0,
                minSimilarity: 0,
                maxSimilarity: 0,
                syntheticIntentCount: uniqueSynthetic.count,
                seedIntentCount: uniqueSeed.count,
                unmatchedIntents: [],
                embeddingAvailable: true,
                auditDuration: Date().timeIntervalSince(startTime),
                failureReasons: ["Empty intent sets"]
            )
        }
        
        // Compute similarities
        var similarities: [IntentSimilarityPair] = []
        var unmatchedIntents: [String] = []
        
        for syntheticIntent in uniqueSynthetic {
            var maxSimilarity: Double = -1
            var closestSeed = ""
            
            for seedIntent in uniqueSeed {
                let similarity = computeCosineSimilarity(
                    embedding: embedding,
                    text1: syntheticIntent,
                    text2: seedIntent
                )
                
                if similarity > maxSimilarity {
                    maxSimilarity = similarity
                    closestSeed = seedIntent
                }
            }
            
            similarities.append(IntentSimilarityPair(
                syntheticIntent: syntheticIntent,
                closestSeedIntent: closestSeed,
                similarity: maxSimilarity
            ))
            
            if maxSimilarity < EmbeddingAuditConstants.overlapSimilarityThreshold {
                unmatchedIntents.append(syntheticIntent)
            }
        }
        
        // Sort similarities for determinism
        let sortedSimilarities = similarities.sorted()
        
        // Calculate metrics
        let allSimilarityValues = sortedSimilarities.map { $0.similarity }
        let matchedCount = sortedSimilarities.filter { $0.similarity >= EmbeddingAuditConstants.overlapSimilarityThreshold }.count
        
        let overlapPercentage = Double(matchedCount) / Double(uniqueSynthetic.count)
        let meanSimilarity = allSimilarityValues.reduce(0, +) / Double(allSimilarityValues.count)
        let p95Similarity = percentile(allSimilarityValues, p: 0.95)
        let minSimilarity = allSimilarityValues.min() ?? 0
        let maxSimilarity = allSimilarityValues.max() ?? 0
        
        // Determine pass/fail
        var failureReasons: [String] = []
        
        if overlapPercentage < overlapThreshold {
            failureReasons.append("Overlap \(String(format: "%.1f%%", overlapPercentage * 100)) below threshold \(String(format: "%.1f%%", overlapThreshold * 100))")
        }
        
        if meanSimilarity < EmbeddingAuditConstants.minimumMeanSimilarity {
            failureReasons.append("Mean similarity \(String(format: "%.3f", meanSimilarity)) below threshold \(EmbeddingAuditConstants.minimumMeanSimilarity)")
        }
        
        let passed = failureReasons.isEmpty
        
        return EmbeddingAuditResult(
            passed: passed,
            overlapPercentage: overlapPercentage,
            meanSimilarity: meanSimilarity,
            p95Similarity: p95Similarity,
            minSimilarity: minSimilarity,
            maxSimilarity: maxSimilarity,
            syntheticIntentCount: uniqueSynthetic.count,
            seedIntentCount: uniqueSeed.count,
            unmatchedIntents: unmatchedIntents.sorted(), // Sorted for determinism
            embeddingAvailable: true,
            auditDuration: Date().timeIntervalSince(startTime),
            failureReasons: failureReasons
        )
    }
    
    /// Compute cosine similarity between two texts using NLEmbedding
    private static func computeCosineSimilarity(
        embedding: NLEmbedding,
        text1: String,
        text2: String
    ) -> Double {
        // NLEmbedding.distance returns a distance metric (0 = identical, 2 = opposite)
        // Convert to similarity: similarity = 1 - (distance / 2)
        let distance = embedding.distance(between: text1, and: text2)
        
        // Handle NaN or invalid distances
        guard distance.isFinite else {
            return 0
        }
        
        // Convert distance to similarity (distance is in range [0, 2])
        let similarity = 1.0 - (distance / 2.0)
        return max(0, min(1, similarity)) // Clamp to [0, 1]
    }
    
    /// Calculate percentile of sorted array
    private static func percentile(_ values: [Double], p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        
        let sorted = values.sorted()
        let index = Int(Double(sorted.count - 1) * p)
        return sorted[min(index, sorted.count - 1)]
    }
}

// MARK: - Batch Embedding Audit

/// Batch audit for multiple corpus comparisons
public struct BatchEmbeddingAuditResult: Equatable {
    public let corpusResults: [String: EmbeddingAuditResult]
    public let overallPassed: Bool
    public let totalSyntheticIntents: Int
    public let totalSeedIntents: Int
    public let aggregateMeanSimilarity: Double
    public let totalDuration: TimeInterval
    
    public init(
        corpusResults: [String: EmbeddingAuditResult],
        overallPassed: Bool,
        totalSyntheticIntents: Int,
        totalSeedIntents: Int,
        aggregateMeanSimilarity: Double,
        totalDuration: TimeInterval
    ) {
        self.corpusResults = corpusResults
        self.overallPassed = overallPassed
        self.totalSyntheticIntents = totalSyntheticIntents
        self.totalSeedIntents = totalSeedIntents
        self.aggregateMeanSimilarity = aggregateMeanSimilarity
        self.totalDuration = totalDuration
    }
}

extension EmbeddingAuditor {
    
    /// Run batch audit on multiple corpora
    public static func runBatchAudit(
        corpora: [String: [SyntheticExample]],
        seedExamples: [SyntheticExample]
    ) -> BatchEmbeddingAuditResult {
        let startTime = Date()
        let seedIntents = seedExamples.map { $0.userIntent }
        
        var results: [String: EmbeddingAuditResult] = [:]
        var totalSynthetic = 0
        var allMeans: [Double] = []
        
        for (corpusName, examples) in corpora.sorted(by: { $0.key < $1.key }) {
            let syntheticIntents = examples.map { $0.userIntent }
            let result = runDistributionMatch(syntheticIntents: syntheticIntents, seedIntents: seedIntents)
            
            results[corpusName] = result
            totalSynthetic += result.syntheticIntentCount
            allMeans.append(result.meanSimilarity)
        }
        
        let overallPassed = results.values.allSatisfy { $0.passed }
        let aggregateMean = allMeans.isEmpty ? 0 : allMeans.reduce(0, +) / Double(allMeans.count)
        
        return BatchEmbeddingAuditResult(
            corpusResults: results,
            overallPassed: overallPassed,
            totalSyntheticIntents: totalSynthetic,
            totalSeedIntents: seedIntents.count,
            aggregateMeanSimilarity: aggregateMean,
            totalDuration: Date().timeIntervalSince(startTime)
        )
    }
}

// MARK: - Quick Check

extension EmbeddingAuditor {
    
    /// Quick check if a single intent is covered by seed set
    public static func isIntentCovered(
        intent: String,
        seedIntents: [String],
        threshold: Double = EmbeddingAuditConstants.overlapSimilarityThreshold
    ) -> Bool {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: EmbeddingAuditConstants.embeddingLanguage) else {
            return false
        }
        
        for seedIntent in seedIntents {
            let distance = embedding.distance(between: intent, and: seedIntent)
            let similarity = 1.0 - (distance / 2.0)
            
            if similarity >= threshold {
                return true
            }
        }
        
        return false
    }
}
