import Foundation

// ============================================================================
// LOCAL EVAL RUNNER (Phase 8B)
//
// On-device evaluation runner for golden cases.
// INVARIANT: No user content exfiltration
// INVARIANT: Manual trigger only (no scheduled runs)
// INVARIANT: No network transmission
// INVARIANT: Metadata-only comparison (audit-based drift watch)
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

// MARK: - Eval Run Type

public enum EvalRunType: String, Codable {
    case goldenCases = "golden_cases"
    case auditDriftWatch = "audit_drift_watch"
    
    public var displayName: String {
        switch self {
        case .goldenCases: return "Golden Cases Eval"
        case .auditDriftWatch: return "Audit Drift Watch"
        }
    }
}

// MARK: - Eval Run

/// A single evaluation run
public struct EvalRun: Identifiable, Codable {
    public let id: UUID
    public let startedAt: Date
    public var completedAt: Date?
    public let runType: EvalRunType
    public let caseCount: Int
    public var results: [EvalCaseResult]
    public let appVersion: String?
    public let schemaVersion: Int
    
    /// Quality signature capturing system state at eval time (Phase 9A)
    public let qualitySignature: QualitySignature?
    
    /// Lineage metadata for chronological linking (Phase 9C)
    /// Allows chronological linking without branching logic, enforcement, or execution reference
    public let lineage: EvalRunLineage?
    
    public static let currentSchemaVersion = 3  // Bumped for Phase 9C
    
    public var isComplete: Bool {
        completedAt != nil
    }
    
    public var passCount: Int {
        results.filter { $0.pass }.count
    }
    
    public var failCount: Int {
        results.filter { !$0.pass }.count
    }
    
    public var passRate: Double {
        guard !results.isEmpty else { return 0.0 }
        return Double(passCount) / Double(results.count)
    }
    
    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        runType: EvalRunType,
        caseCount: Int,
        results: [EvalCaseResult] = [],
        appVersion: String? = nil,
        qualitySignature: QualitySignature? = nil,
        lineage: EvalRunLineage? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.runType = runType
        self.caseCount = caseCount
        self.results = results
        self.appVersion = appVersion ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        self.schemaVersion = Self.currentSchemaVersion
        self.qualitySignature = qualitySignature ?? QualitySignature.capture()
        self.lineage = lineage
    }
    
    public mutating func complete() {
        self.completedAt = Date()
    }
    
    public mutating func addResult(_ result: EvalCaseResult) {
        self.results.append(result)
    }
}

// MARK: - Eval Case Result

/// Result of evaluating a single golden case
public struct EvalCaseResult: Identifiable, Codable {
    public let id: UUID
    public let goldenCaseId: UUID
    public let memoryItemId: UUID
    public let pass: Bool
    public let metrics: EvalMetrics
    public let notes: [String]
    public let failureReasons: [FailureReason]
    
    public enum FailureReason: String, Codable, CaseIterable {
        case timeout = "timeout"
        case validationFailed = "validation_failed"
        case citationValidityFailed = "citation_validity_failed"
        case fallbackDrift = "fallback_drift"
        case latencyExceeded = "latency_exceeded"
        case backendChanged = "backend_changed"
        case promptHashMismatch = "prompt_hash_mismatch"
        
        public var displayName: String {
            switch self {
            case .timeout: return "Timeout occurred"
            case .validationFailed: return "Validation failed"
            case .citationValidityFailed: return "Citation validity failed"
            case .fallbackDrift: return "Fallback drift detected"
            case .latencyExceeded: return "Latency exceeded threshold"
            case .backendChanged: return "Backend changed"
            case .promptHashMismatch: return "Prompt scaffold hash mismatch"
            }
        }
    }
    
    public init(
        id: UUID = UUID(),
        goldenCaseId: UUID,
        memoryItemId: UUID,
        pass: Bool,
        metrics: EvalMetrics,
        notes: [String] = [],
        failureReasons: [FailureReason] = []
    ) {
        self.id = id
        self.goldenCaseId = goldenCaseId
        self.memoryItemId = memoryItemId
        self.pass = pass
        self.metrics = metrics
        self.notes = notes
        self.failureReasons = failureReasons
    }
}

// MARK: - Eval Metrics

/// Metrics from an evaluation (all numeric/boolean, no raw content)
public struct EvalMetrics: Codable {
    public let confidenceDelta: Double?
    public let latencyDeltaMs: Int?
    public let usedFallback: Bool
    public let timeoutOccurred: Bool
    public let validationPass: Bool?
    public let citationValidityPass: Bool?
    public let citationsCountDelta: Int?
    public let backendUsed: String
    public let promptScaffoldHashMatch: Bool?
    
    public init(
        confidenceDelta: Double? = nil,
        latencyDeltaMs: Int? = nil,
        usedFallback: Bool,
        timeoutOccurred: Bool,
        validationPass: Bool?,
        citationValidityPass: Bool?,
        citationsCountDelta: Int? = nil,
        backendUsed: String,
        promptScaffoldHashMatch: Bool? = nil
    ) {
        self.confidenceDelta = confidenceDelta
        self.latencyDeltaMs = latencyDeltaMs
        self.usedFallback = usedFallback
        self.timeoutOccurred = timeoutOccurred
        self.validationPass = validationPass
        self.citationValidityPass = citationValidityPass
        self.citationsCountDelta = citationsCountDelta
        self.backendUsed = backendUsed
        self.promptScaffoldHashMatch = promptScaffoldHashMatch
    }
}

// MARK: - Local Eval Runner

/// Runs local-only evaluations against golden cases
/// INVARIANT: Manual trigger only
/// INVARIANT: No content storage or transmission
public final class LocalEvalRunner: ObservableObject {
    
    public static let shared = LocalEvalRunner()
    
    private let storageKey = "com.operatorkit.evalRuns"
    private let defaults: UserDefaults
    
    @Published public private(set) var runs: [EvalRun] = []
    @Published public private(set) var isRunning: Bool = false
    
    /// Latency threshold for failure (ms)
    public let latencyThresholdMs: Int = 1500
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadRuns()
    }
    
    // MARK: - Run Evaluation
    
    /// Runs an audit-based drift watch evaluation against golden cases
    /// INVARIANT: No content retrieval - metadata comparison only
    /// INVARIANT: Manual trigger only
    @MainActor
    func runGoldenCaseEval(
        goldenCases: [GoldenCase],
        memoryStore: MemoryStore
    ) async -> EvalRun {
        isRunning = true
        
        // Create lineage from previous run (Phase 9C)
        let previousRunId = runs.sorted { $0.startedAt > $1.startedAt }.first?.id
        let signature = QualitySignature.capture()
        let lineage = EvalRunLineage.create(previousRunId: previousRunId, signature: signature)
        
        var run = EvalRun(
            runType: .auditDriftWatch,
            caseCount: goldenCases.count,
            qualitySignature: signature,
            lineage: lineage
        )
        
        for goldenCase in goldenCases {
            let result = evaluateGoldenCase(goldenCase, memoryStore: memoryStore)
            run.addResult(result)
        }
        
        run.complete()
        
        // Save run
        runs.append(run)
        saveRuns()
        
        isRunning = false
        
        logDebug("Completed eval run \(run.id) with \(run.passCount)/\(run.caseCount) passed", category: .audit)
        
        return run
    }
    
    /// Evaluates a single golden case using audit-based drift watch
    /// INVARIANT: No content retrieval - compares metadata only
    @MainActor
    private func evaluateGoldenCase(
        _ goldenCase: GoldenCase,
        memoryStore: MemoryStore
    ) -> EvalCaseResult {
        let snapshot = goldenCase.snapshot
        var notes: [String] = []
        var failureReasons: [EvalCaseResult.FailureReason] = []
        
        // Get current system state for comparison
        let currentBackend = getCurrentBackend()
        let baselineLatency = snapshot.latencyMs ?? 0
        
        // Build metrics from snapshot (no content access)
        let metrics = EvalMetrics(
            confidenceDelta: nil,  // Would need re-generation to compute
            latencyDeltaMs: nil,   // Would need re-generation to compute
            usedFallback: snapshot.usedFallback,
            timeoutOccurred: snapshot.timeoutOccurred,
            validationPass: snapshot.validationPass,
            citationValidityPass: snapshot.citationValidityPass,
            citationsCountDelta: nil,
            backendUsed: currentBackend,
            promptScaffoldHashMatch: nil  // Would need re-generation to compute
        )
        
        // Apply pass/fail rules (deterministic)
        var pass = true
        
        // Rule 1: Fail if timeout occurred in baseline
        if snapshot.timeoutOccurred {
            pass = false
            failureReasons.append(.timeout)
            notes.append("Baseline had timeout")
        }
        
        // Rule 2: Fail if validation failed in baseline
        if snapshot.validationPass == false {
            pass = false
            failureReasons.append(.validationFailed)
            notes.append("Baseline validation failed")
        }
        
        // Rule 3: Fail if citation validity failed in baseline
        if snapshot.citationValidityPass == false {
            pass = false
            failureReasons.append(.citationValidityFailed)
            notes.append("Baseline citation validity failed")
        }
        
        // Rule 4: Detect fallback drift (baseline was non-fallback but now would use fallback)
        if !snapshot.usedFallback && currentBackend == "DeterministicTemplateModel" && snapshot.backendUsed != "DeterministicTemplateModel" {
            pass = false
            failureReasons.append(.fallbackDrift)
            notes.append("Backend drift: \(snapshot.backendUsed) → \(currentBackend)")
        }
        
        // Rule 5: Flag if latency exceeded threshold in baseline
        if let latency = snapshot.latencyMs, latency > latencyThresholdMs {
            pass = false
            failureReasons.append(.latencyExceeded)
            notes.append("Baseline latency \(latency)ms exceeded threshold \(latencyThresholdMs)ms")
        }
        
        // Rule 6: Flag backend changes
        if snapshot.backendUsed != currentBackend {
            // Not necessarily a failure, but note it
            notes.append("Backend changed: \(snapshot.backendUsed) → \(currentBackend)")
        }
        
        return EvalCaseResult(
            goldenCaseId: goldenCase.id,
            memoryItemId: goldenCase.memoryItemId,
            pass: pass,
            metrics: metrics,
            notes: notes,
            failureReasons: failureReasons
        )
    }
    
    /// Gets the current available backend
    @MainActor
    private func getCurrentBackend() -> String {
        // Check what backend would be used now
        let router = ModelRouter.shared
        let availability = router.backendAvailability
        
        // Return the name of the first available backend
        if availability[ModelBackend.appleOnDevice]?.isAvailable == true {
            return "AppleOnDeviceModelBackend"
        } else if availability[ModelBackend.coreML]?.isAvailable == true {
            return "CoreMLModelBackend"
        } else {
            return "DeterministicTemplateModel"
        }
    }
    
    // MARK: - Run Management
    
    /// Gets a run by ID
    public func getRun(id: UUID) -> EvalRun? {
        runs.first { $0.id == id }
    }
    
    /// Deletes a single run
    public func deleteRun(id: UUID) -> Result<Void, EvalRunnerError> {
        guard let index = runs.firstIndex(where: { $0.id == id }) else {
            return .failure(.runNotFound)
        }
        
        runs.remove(at: index)
        saveRuns()
        
        logDebug("Deleted eval run \(id)", category: .audit)
        
        return .success(())
    }
    
    /// Deletes all runs
    public func deleteAllRuns() {
        runs.removeAll()
        saveRuns()
        
        logDebug("Deleted all eval runs", category: .audit)
    }
    
    // MARK: - Export
    
    /// Exports all runs as JSON
    public func exportAsJSON() throws -> Data {
        let export = EvalRunExport(runs: runs)
        return try export.toJSON()
    }
    
    /// Exports as a file URL for sharing
    public func exportToFile() throws -> URL {
        let data = try exportAsJSON()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: Date())
        
        let fileName = "operatorkit-eval-runs-\(timestamp).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try data.write(to: tempURL)
        return tempURL
    }
    
    // MARK: - Persistence
    
    private func loadRuns() {
        guard let data = defaults.data(forKey: storageKey) else {
            runs = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            runs = try decoder.decode([EvalRun].self, from: data)
        } catch {
            logError("Failed to load eval runs: \(error)", category: .audit)
            runs = []
        }
    }
    
    private func saveRuns() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(runs)
            defaults.set(data, forKey: storageKey)
        } catch {
            logError("Failed to save eval runs: \(error)", category: .audit)
        }
    }
    
    // MARK: - Error Types
    
    public enum EvalRunnerError: Error, LocalizedError {
        case runNotFound
        case exportFailed
        
        public var errorDescription: String? {
            switch self {
            case .runNotFound: return "Eval run not found"
            case .exportFailed: return "Failed to export eval runs"
            }
        }
    }
}

// MARK: - Export Format

public struct EvalRunExport: Codable {
    public let schemaVersion: Int
    public let appVersion: String?
    public let exportedAt: Date
    public let totalRuns: Int
    public let runs: [EvalRun]
    
    public init(runs: [EvalRun]) {
        self.schemaVersion = EvalRun.currentSchemaVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        self.exportedAt = Date()
        self.totalRuns = runs.count
        self.runs = runs
    }
    
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
