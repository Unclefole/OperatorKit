import XCTest
@testable import OperatorKit

// ============================================================================
// SYNTHETIC DATA INVARIANT TESTS (Phase 13I)
//
// Tests proving synthetic data quality, privacy safety, and distribution match.
//
// CONSTRAINTS:
// ❌ No runtime modifications
// ❌ No networking
// ❌ No user content
// ✅ Deterministic results
// ✅ Privacy validation
// ============================================================================

final class SyntheticDataInvariantTests: XCTestCase {
    
    // MARK: - Constants
    
    /// Minimum distribution match threshold (configurable)
    static let distributionMatchThreshold: Double = 0.85
    
    /// Minimum routing accuracy threshold
    static let routingAccuracyThreshold: Double = 0.999
    
    // MARK: - Schema Validation Tests
    
    /// Test that seed set contains no forbidden keys
    func testSeedSet_ContainsNoForbiddenKeys() throws {
        let seedSetJSON = loadTestFixture(named: "SyntheticSeedSet")
        
        // Decode corpus
        let corpus = try JSONDecoder().decode(SyntheticCorpus.self, from: seedSetJSON)
        
        // Validate each example
        var allViolations: [String: [String]] = [:]
        
        for example in corpus.examples {
            let violations = example.validate()
            if !violations.isEmpty {
                allViolations[example.exampleId] = violations
            }
        }
        
        XCTAssertTrue(
            allViolations.isEmpty,
            "Seed set contains forbidden keys: \(allViolations)"
        )
    }
    
    /// Test that generated corpus contains no forbidden keys
    func testGeneratedCorpus_ContainsNoForbiddenKeys() throws {
        let corpusJSON = loadTestFixture(named: "SyntheticCorpusSmall")
        
        let corpus = try JSONDecoder().decode(SyntheticCorpus.self, from: corpusJSON)
        
        var allViolations: [String: [String]] = [:]
        
        for example in corpus.examples {
            let violations = example.validate()
            if !violations.isEmpty {
                allViolations[example.exampleId] = violations
            }
        }
        
        XCTAssertTrue(
            allViolations.isEmpty,
            "Generated corpus contains forbidden keys: \(allViolations)"
        )
    }
    
    /// Test that negative examples contain no forbidden keys
    func testNegativeExamples_ContainsNoForbiddenKeys() throws {
        let negativeJSON = loadTestFixture(named: "NegativeExamples")
        
        let corpus = try JSONDecoder().decode(SyntheticCorpus.self, from: negativeJSON)
        
        var allViolations: [String: [String]] = [:]
        
        for example in corpus.examples {
            let violations = example.validate()
            if !violations.isEmpty {
                allViolations[example.exampleId] = violations
            }
        }
        
        XCTAssertTrue(
            allViolations.isEmpty,
            "Negative examples contain forbidden keys: \(allViolations)"
        )
    }
    
    // MARK: - PII Pattern Detection Tests
    
    /// Test that fixtures contain no PII patterns
    func testFixtures_ContainNoPIIPatterns() throws {
        let fixtures = [
            loadTestFixture(named: "SyntheticSeedSet"),
            loadTestFixture(named: "SyntheticCorpusSmall"),
            loadTestFixture(named: "NegativeExamples")
        ]
        
        let piiPatterns: [(String, String)] = [
            // Real email addresses (not from allowed domains)
            ("[a-zA-Z0-9._%+-]+@(?!example\\.com|test\\.com|synthetic\\.local|placeholder\\.dev)[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", "Real email"),
            // US Phone numbers
            ("\\b\\d{3}[-.]\\d{3}[-.]\\d{4}\\b", "Phone number"),
            // SSN pattern
            ("\\b\\d{3}-\\d{2}-\\d{4}\\b", "SSN"),
            // Credit card basic pattern
            ("\\b(?:\\d{4}[-\\s]?){3}\\d{4}\\b", "Credit card")
        ]
        
        var piiFound: [String] = []
        
        for (index, fixture) in fixtures.enumerated() {
            let content = String(data: fixture, encoding: .utf8) ?? ""
            
            for (pattern, name) in piiPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(content.startIndex..., in: content)
                    if regex.firstMatch(in: content, options: [], range: range) != nil {
                        piiFound.append("Fixture \(index): \(name)")
                    }
                }
            }
        }
        
        XCTAssertTrue(
            piiFound.isEmpty,
            "PII patterns detected in fixtures: \(piiFound)"
        )
    }
    
    /// Test that no firm names appear in fixtures
    func testFixtures_ContainNoForbiddenFirmNames() throws {
        let fixtures = [
            loadTestFixture(named: "SyntheticSeedSet"),
            loadTestFixture(named: "SyntheticCorpusSmall"),
            loadTestFixture(named: "NegativeExamples")
        ]
        
        var firmNamesFound: [String] = []
        
        for fixture in fixtures {
            let content = (String(data: fixture, encoding: .utf8) ?? "").lowercased()
            
            for firm in SyntheticForbiddenKeys.forbiddenFirmNames {
                if content.contains(firm) {
                    firmNamesFound.append(firm)
                }
            }
        }
        
        XCTAssertTrue(
            firmNamesFound.isEmpty,
            "Forbidden firm names detected: \(Set(firmNamesFound))"
        )
    }
    
    // MARK: - Distribution Match Tests
    
    /// Test that generated corpus matches seed set distribution
    func testDistributionMatch_MeetsThreshold() throws {
        // Skip if embedding not available
        guard EmbeddingAuditor.isEmbeddingAvailable else {
            throw XCTSkip("NLEmbedding not available on this platform")
        }
        
        let seedSetJSON = loadTestFixture(named: "SyntheticSeedSet")
        let corpusJSON = loadTestFixture(named: "SyntheticCorpusSmall")
        
        let seedSet = try JSONDecoder().decode(SyntheticCorpus.self, from: seedSetJSON)
        let corpus = try JSONDecoder().decode(SyntheticCorpus.self, from: corpusJSON)
        
        let seedIntents = seedSet.examples.map { $0.userIntent }
        let corpusIntents = corpus.examples.map { $0.userIntent }
        
        let result = EmbeddingAuditor.runDistributionMatch(
            syntheticIntents: corpusIntents,
            seedIntents: seedIntents,
            overlapThreshold: Self.distributionMatchThreshold
        )
        
        XCTAssertTrue(
            result.passed,
            """
            Distribution match failed:
            - Overlap: \(String(format: "%.1f%%", result.overlapPercentage * 100))
            - Threshold: \(String(format: "%.1f%%", Self.distributionMatchThreshold * 100))
            - Mean similarity: \(String(format: "%.3f", result.meanSimilarity))
            - Unmatched: \(result.unmatchedIntents.count) intents
            - Reasons: \(result.failureReasons)
            """
        )
    }
    
    /// Test distribution match is deterministic
    func testDistributionMatch_IsDeterministic() throws {
        guard EmbeddingAuditor.isEmbeddingAvailable else {
            throw XCTSkip("NLEmbedding not available on this platform")
        }
        
        let seedSetJSON = loadTestFixture(named: "SyntheticSeedSet")
        let corpusJSON = loadTestFixture(named: "SyntheticCorpusSmall")
        
        let seedSet = try JSONDecoder().decode(SyntheticCorpus.self, from: seedSetJSON)
        let corpus = try JSONDecoder().decode(SyntheticCorpus.self, from: corpusJSON)
        
        let seedIntents = seedSet.examples.map { $0.userIntent }
        let corpusIntents = corpus.examples.map { $0.userIntent }
        
        // Run twice
        let result1 = EmbeddingAuditor.runDistributionMatch(
            syntheticIntents: corpusIntents,
            seedIntents: seedIntents
        )
        
        let result2 = EmbeddingAuditor.runDistributionMatch(
            syntheticIntents: corpusIntents,
            seedIntents: seedIntents
        )
        
        // Results should be identical
        XCTAssertEqual(result1.overlapPercentage, result2.overlapPercentage, "Overlap percentage not deterministic")
        XCTAssertEqual(result1.meanSimilarity, result2.meanSimilarity, "Mean similarity not deterministic")
        XCTAssertEqual(result1.unmatchedIntents.sorted(), result2.unmatchedIntents.sorted(), "Unmatched intents not deterministic")
    }
    
    // MARK: - Schema Version Tests
    
    /// Test all fixtures have correct schema version
    func testFixtures_HaveCorrectSchemaVersion() throws {
        let fixtures: [(String, Data)] = [
            ("SyntheticSeedSet", loadTestFixture(named: "SyntheticSeedSet")),
            ("SyntheticCorpusSmall", loadTestFixture(named: "SyntheticCorpusSmall")),
            ("NegativeExamples", loadTestFixture(named: "NegativeExamples"))
        ]
        
        for (name, data) in fixtures {
            let corpus = try JSONDecoder().decode(SyntheticCorpus.self, from: data)
            
            XCTAssertEqual(
                corpus.schemaVersion,
                SyntheticDataSchemaVersion.current,
                "\(name) has incorrect schema version"
            )
            
            for example in corpus.examples {
                XCTAssertEqual(
                    example.schemaVersion,
                    SyntheticDataSchemaVersion.current,
                    "\(name) example \(example.exampleId) has incorrect schema version"
                )
            }
        }
    }
    
    // MARK: - Domain Coverage Tests
    
    /// Test seed set covers all domains
    func testSeedSet_CoversAllDomains() throws {
        let seedSetJSON = loadTestFixture(named: "SyntheticSeedSet")
        let corpus = try JSONDecoder().decode(SyntheticCorpus.self, from: seedSetJSON)
        
        let coveredDomains = Set(corpus.examples.map { $0.domain })
        let allDomains = Set(SyntheticDomain.allCases)
        
        XCTAssertEqual(
            coveredDomains,
            allDomains,
            "Seed set missing domains: \(allDomains.subtracting(coveredDomains))"
        )
    }
    
    // MARK: - Negative Examples Tests
    
    /// Test all negative examples are marked as such
    func testNegativeExamples_AllMarkedCorrectly() throws {
        let negativeJSON = loadTestFixture(named: "NegativeExamples")
        let corpus = try JSONDecoder().decode(SyntheticCorpus.self, from: negativeJSON)
        
        for example in corpus.examples {
            XCTAssertTrue(
                example.metadata?.isNegativeExample == true,
                "Negative example \(example.exampleId) not marked as negative"
            )
            
            XCTAssertEqual(
                example.expectedNativeOutcome.actionId,
                "insufficient_context",
                "Negative example \(example.exampleId) should have 'insufficient_context' action"
            )
        }
    }
    
    // MARK: - Serialization Tests
    
    /// Test fixtures round-trip serialize correctly
    func testFixtures_RoundTripSerialization() throws {
        let seedSetJSON = loadTestFixture(named: "SyntheticSeedSet")
        
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        
        // Decode
        let corpus = try decoder.decode(SyntheticCorpus.self, from: seedSetJSON)
        
        // Encode
        let reencoded = try encoder.encode(corpus)
        
        // Decode again
        let decoded2 = try decoder.decode(SyntheticCorpus.self, from: reencoded)
        
        // Compare
        XCTAssertEqual(corpus.corpusId, decoded2.corpusId)
        XCTAssertEqual(corpus.examples.count, decoded2.examples.count)
        
        for (original, roundTripped) in zip(corpus.examples, decoded2.examples) {
            XCTAssertEqual(original.exampleId, roundTripped.exampleId)
            XCTAssertEqual(original.userIntent, roundTripped.userIntent)
            XCTAssertEqual(original.expectedNativeOutcome.actionId, roundTripped.expectedNativeOutcome.actionId)
        }
    }
    
    // MARK: - Email Domain Tests
    
    /// Test all email addresses use allowed domains
    func testFixtures_OnlyAllowedEmailDomains() throws {
        let fixtures = [
            loadTestFixture(named: "SyntheticSeedSet"),
            loadTestFixture(named: "SyntheticCorpusSmall"),
            loadTestFixture(named: "NegativeExamples")
        ]
        
        // Extract email pattern
        let emailPattern = "[a-zA-Z0-9._%+-]+@([a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})"
        guard let regex = try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive) else {
            XCTFail("Invalid email regex")
            return
        }
        
        var invalidDomains: Set<String> = []
        
        for fixture in fixtures {
            let content = String(data: fixture, encoding: .utf8) ?? ""
            let range = NSRange(content.startIndex..., in: content)
            
            let matches = regex.matches(in: content, options: [], range: range)
            
            for match in matches {
                if let domainRange = Range(match.range(at: 1), in: content) {
                    let domain = String(content[domainRange])
                    
                    if !SyntheticForbiddenKeys.allowedDomains.contains(domain) {
                        invalidDomains.insert(domain)
                    }
                }
            }
        }
        
        XCTAssertTrue(
            invalidDomains.isEmpty,
            "Invalid email domains found: \(invalidDomains)"
        )
    }
    
    // MARK: - Statistics Tests
    
    /// Test fixture statistics are computed correctly
    func testFixtureStatistics_ComputedCorrectly() throws {
        let seedSetJSON = loadTestFixture(named: "SyntheticSeedSet")
        let corpus = try JSONDecoder().decode(SyntheticCorpus.self, from: seedSetJSON)
        
        let stats = SyntheticFixtureStatistics(from: corpus.examples)
        
        XCTAssertEqual(stats.totalExamples, corpus.examples.count)
        XCTAssertEqual(stats.schemaVersions, [SyntheticDataSchemaVersion.current])
        XCTAssertTrue(stats.domainDistribution.values.reduce(0, +) == stats.totalExamples)
    }
    
    // MARK: - Helpers
    
    private func loadTestFixture(named name: String) -> Data {
        // Try to load from test bundle
        let testBundle = Bundle(for: type(of: self))
        
        if let url = testBundle.url(forResource: name, withExtension: "json") {
            return (try? Data(contentsOf: url)) ?? Data()
        }
        
        // Fallback: try to load from Fixtures directory relative to test file
        let testFilePath = URL(fileURLWithPath: #file)
        let fixturesPath = testFilePath
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("\(name).json")
        
        return (try? Data(contentsOf: fixturesPath)) ?? Data()
    }
}
