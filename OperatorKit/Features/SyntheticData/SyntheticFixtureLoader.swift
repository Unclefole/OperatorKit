import Foundation

// ============================================================================
// SYNTHETIC FIXTURE LOADER (Phase 13I)
//
// Loads synthetic fixtures from bundle/test resources.
// Read-only operations only — no FileManager writes.
//
// CONSTRAINTS:
// ❌ No networking
// ❌ No file writes
// ❌ No user content
// ✅ Bundle resource loading only
// ✅ Schema validation
// ✅ Forbidden keys validation
// ============================================================================

// MARK: - Loader Errors

public enum SyntheticFixtureLoaderError: Error, CustomStringConvertible {
    case resourceNotFound(name: String)
    case invalidJSON(underlying: Error)
    case schemaValidationFailed(violations: [String])
    case unsupportedSchemaVersion(found: Int, expected: Int)
    case emptyCorpus
    
    public var description: String {
        switch self {
        case .resourceNotFound(let name):
            return "Resource not found: \(name)"
        case .invalidJSON(let error):
            return "Invalid JSON: \(error.localizedDescription)"
        case .schemaValidationFailed(let violations):
            return "Schema validation failed: \(violations.joined(separator: ", "))"
        case .unsupportedSchemaVersion(let found, let expected):
            return "Unsupported schema version: found \(found), expected \(expected)"
        case .emptyCorpus:
            return "Corpus contains no examples"
        }
    }
}

// MARK: - Loader Result

public struct SyntheticFixtureLoadResult {
    public let corpus: SyntheticCorpus
    public let validationResult: SyntheticCorpusValidationResult
    public let loadTime: TimeInterval
    
    public var isFullyValid: Bool {
        validationResult.isValid
    }
    
    public init(corpus: SyntheticCorpus, validationResult: SyntheticCorpusValidationResult, loadTime: TimeInterval) {
        self.corpus = corpus
        self.validationResult = validationResult
        self.loadTime = loadTime
    }
}

// MARK: - Fixture Loader

public enum SyntheticFixtureLoader {
    
    /// Current expected schema version
    public static let expectedSchemaVersion = SyntheticDataSchemaVersion.current
    
    /// Load a corpus from bundle resource
    public static func loadCorpus(
        named resourceName: String,
        bundle: Bundle = .main,
        validateSchema: Bool = true,
        validateForbiddenKeys: Bool = true
    ) throws -> SyntheticFixtureLoadResult {
        let startTime = Date()
        
        // Find resource in bundle
        guard let resourceURL = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw SyntheticFixtureLoaderError.resourceNotFound(name: "\(resourceName).json")
        }
        
        // Load data (read-only)
        let data: Data
        do {
            data = try Data(contentsOf: resourceURL)
        } catch {
            throw SyntheticFixtureLoaderError.invalidJSON(underlying: error)
        }
        
        // Decode corpus
        let corpus: SyntheticCorpus
        do {
            let decoder = JSONDecoder()
            corpus = try decoder.decode(SyntheticCorpus.self, from: data)
        } catch {
            throw SyntheticFixtureLoaderError.invalidJSON(underlying: error)
        }
        
        // Validate schema version
        if validateSchema && corpus.schemaVersion != expectedSchemaVersion {
            throw SyntheticFixtureLoaderError.unsupportedSchemaVersion(
                found: corpus.schemaVersion,
                expected: expectedSchemaVersion
            )
        }
        
        // Validate non-empty
        if corpus.examples.isEmpty {
            throw SyntheticFixtureLoaderError.emptyCorpus
        }
        
        // Validate forbidden keys
        var validationResult = SyntheticCorpusValidationResult(
            isValid: true,
            totalExamples: corpus.examples.count,
            validExamples: corpus.examples.count,
            totalViolations: 0,
            violationsByExample: [:]
        )
        
        if validateForbiddenKeys {
            validationResult = corpus.validate()
            
            // Throw if critical violations found
            if !validationResult.isValid {
                let allViolations = validationResult.violationsByExample.flatMap { $0.value }
                throw SyntheticFixtureLoaderError.schemaValidationFailed(violations: allViolations)
            }
        }
        
        let loadTime = Date().timeIntervalSince(startTime)
        
        return SyntheticFixtureLoadResult(
            corpus: corpus,
            validationResult: validationResult,
            loadTime: loadTime
        )
    }
    
    /// Load multiple corpora from bundle
    public static func loadCorpora(
        named resourceNames: [String],
        bundle: Bundle = .main
    ) throws -> [SyntheticFixtureLoadResult] {
        try resourceNames.map { try loadCorpus(named: $0, bundle: bundle) }
    }
    
    /// Load examples directly from JSON data (for testing)
    public static func loadExamples(from jsonData: Data) throws -> [SyntheticExample] {
        let decoder = JSONDecoder()
        
        // Try decoding as corpus first
        if let corpus = try? decoder.decode(SyntheticCorpus.self, from: jsonData) {
            return corpus.examples
        }
        
        // Try decoding as array of examples
        if let examples = try? decoder.decode([SyntheticExample].self, from: jsonData) {
            return examples
        }
        
        // Try decoding as single example
        if let example = try? decoder.decode(SyntheticExample.self, from: jsonData) {
            return [example]
        }
        
        throw SyntheticFixtureLoaderError.invalidJSON(
            underlying: NSError(domain: "SyntheticFixtureLoader", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Could not decode JSON as corpus, array, or single example"
            ])
        )
    }
    
    /// Get available fixture names in bundle
    public static func availableFixtures(in bundle: Bundle = .main) -> [String] {
        guard let resourcePath = bundle.resourcePath else { return [] }
        
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: resourcePath) else {
            return []
        }
        
        return contents
            .filter { $0.hasSuffix(".json") }
            .filter { $0.contains("Synthetic") || $0.contains("synthetic") }
            .map { $0.replacingOccurrences(of: ".json", with: "") }
            .sorted()
    }
}

// MARK: - Seed Set Loader

/// Specialized loader for seed sets (hand-verified examples)
public enum SyntheticSeedSetLoader {
    
    /// Load the canonical seed set
    public static func loadSeedSet(bundle: Bundle = .main) throws -> [SyntheticExample] {
        let result = try SyntheticFixtureLoader.loadCorpus(
            named: "SyntheticSeedSet",
            bundle: bundle
        )
        return result.corpus.examples
    }
    
    /// Load negative examples set
    public static func loadNegativeExamples(bundle: Bundle = .main) throws -> [SyntheticExample] {
        let result = try SyntheticFixtureLoader.loadCorpus(
            named: "NegativeExamples",
            bundle: bundle
        )
        return result.corpus.examples
    }
    
    /// Extract user intents from examples (for embedding audit)
    public static func extractIntents(from examples: [SyntheticExample]) -> [String] {
        examples.map { $0.userIntent }.sorted()
    }
    
    /// Extract action IDs from examples (for routing audit)
    public static func extractExpectedActions(from examples: [SyntheticExample]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: examples.map {
            ($0.exampleId, $0.expectedNativeOutcome.actionId)
        })
    }
}

// MARK: - Fixture Statistics

/// Statistics about loaded fixtures
public struct SyntheticFixtureStatistics: Equatable {
    public let totalExamples: Int
    public let domainDistribution: [SyntheticDomain: Int]
    public let actionDistribution: [String: Int]
    public let negativeExampleCount: Int
    public let averageContextCount: Double
    public let schemaVersions: Set<Int>
    
    public init(from examples: [SyntheticExample]) {
        self.totalExamples = examples.count
        
        var domains: [SyntheticDomain: Int] = [:]
        var actions: [String: Int] = [:]
        var negatives = 0
        var totalContexts = 0
        var versions: Set<Int> = []
        
        for example in examples {
            domains[example.domain, default: 0] += 1
            actions[example.expectedNativeOutcome.actionId, default: 0] += 1
            totalContexts += example.selectedContext.count
            versions.insert(example.schemaVersion)
            
            if example.metadata?.isNegativeExample == true {
                negatives += 1
            }
        }
        
        self.domainDistribution = domains
        self.actionDistribution = actions
        self.negativeExampleCount = negatives
        self.averageContextCount = examples.isEmpty ? 0 : Double(totalContexts) / Double(examples.count)
        self.schemaVersions = versions
    }
}
