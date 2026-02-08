import Foundation

// MARK: - Case Study Runner
// ============================================================================
// Executes security case studies in DEBUG builds only.
// Results are logged to console and written to SecurityEvidence/Logs/.
//
// USAGE (from test target or debug entry point):
//   CaseStudyRunner.shared.runAll()
//   CaseStudyRunner.shared.run(caseStudyId: "CS-NET-001")
//
// IMPORTANT: This class is a no-op in RELEASE builds.
// ============================================================================

/// Singleton runner for security case studies.
/// All execution is gated behind DEBUG compilation flag.
public final class CaseStudyRunner {
    
    // MARK: - Singleton
    
    public static let shared = CaseStudyRunner()
    
    private init() {
        #if DEBUG
        registerBuiltInCaseStudies()
        #endif
    }
    
    // MARK: - Registry
    
    private var registry: [String: CaseStudyProtocol] = [:]
    
    /// Register a case study for execution.
    /// - Parameter caseStudy: The case study to register.
    public func register(_ caseStudy: CaseStudyProtocol) {
        #if DEBUG
        registry[caseStudy.id] = caseStudy
        log("Registered case study: \(caseStudy.id) - \(caseStudy.name)")
        #endif
    }
    
    /// Get all registered case study IDs.
    public var registeredIds: [String] {
        #if DEBUG
        return Array(registry.keys).sorted()
        #else
        return []
        #endif
    }
    
    // MARK: - Execution
    
    /// Run all registered case studies.
    /// - Returns: Array of results (empty in RELEASE builds).
    @discardableResult
    public func runAll() -> [CaseStudyResult] {
        #if DEBUG
        log("═══════════════════════════════════════════════════════════════")
        log("  SECURITY CASE STUDY RUNNER - Starting Full Suite")
        log("═══════════════════════════════════════════════════════════════")
        log("Registered case studies: \(registry.count)")
        log("")
        
        var results: [CaseStudyResult] = []
        
        for id in registeredIds {
            if let result = run(caseStudyId: id) {
                results.append(result)
            }
        }
        
        // Summary
        log("")
        log("═══════════════════════════════════════════════════════════════")
        log("  EXECUTION SUMMARY")
        log("═══════════════════════════════════════════════════════════════")
        
        let passed = results.filter { $0.outcome == .passed }.count
        let failed = results.filter { $0.outcome == .failed }.count
        let inconclusive = results.filter { $0.outcome == .inconclusive }.count
        let skipped = results.filter { $0.outcome == .skipped }.count
        
        log("PASSED:       \(passed)")
        log("FAILED:       \(failed)")
        log("INCONCLUSIVE: \(inconclusive)")
        log("SKIPPED:      \(skipped)")
        log("───────────────────────────────────────────────────────────────")
        log("TOTAL:        \(results.count)")
        
        if failed > 0 {
            log("")
            log("⚠️  FAILURES DETECTED - Review findings above")
        }
        
        // Write combined results to file
        writeResultsToFile(results)
        
        return results
        #else
        // RELEASE: No-op
        return []
        #endif
    }
    
    /// Run a specific case study by ID.
    /// - Parameter caseStudyId: The ID of the case study to run.
    /// - Returns: The result, or nil if not found or in RELEASE build.
    @discardableResult
    public func run(caseStudyId: String) -> CaseStudyResult? {
        #if DEBUG
        guard let caseStudy = registry[caseStudyId] else {
            log("Case study not found: \(caseStudyId)")
            return nil
        }
        
        return execute(caseStudy)
        #else
        // RELEASE: No-op
        return nil
        #endif
    }
    
    /// Run all case studies in a specific category.
    /// - Parameter category: The category to filter by.
    /// - Returns: Array of results.
    @discardableResult
    public func run(category: CaseStudyCategory) -> [CaseStudyResult] {
        #if DEBUG
        let matching = registry.values.filter { $0.category == category }
        return matching.map { execute($0) }
        #else
        return []
        #endif
    }
    
    // MARK: - Private Execution
    
    #if DEBUG
    private func execute(_ caseStudy: CaseStudyProtocol) -> CaseStudyResult {
        log("")
        log("───────────────────────────────────────────────────────────────")
        log("CASE STUDY: \(caseStudy.id)")
        log("NAME:       \(caseStudy.name)")
        log("CATEGORY:   \(caseStudy.category.rawValue)")
        log("SEVERITY:   \(caseStudy.severity.rawValue)")
        log("───────────────────────────────────────────────────────────────")
        log("")
        log("CLAIM TESTED:")
        log("  \(caseStudy.claimTested)")
        log("")
        log("HYPOTHESIS:")
        log("  \(caseStudy.hypothesis)")
        log("")
        log("EXECUTION STEPS:")
        for (index, step) in caseStudy.executionSteps.enumerated() {
            log("  \(index + 1). \(step)")
        }
        log("")
        log("EXPECTED RESULT:")
        log("  \(caseStudy.expectedResult)")
        log("")
        log("VALIDATION METHOD:")
        log("  \(caseStudy.validationMethod)")
        log("")
        
        // Check prerequisites
        if !caseStudy.checkPrerequisites() {
            log("⏭️  SKIPPED: Prerequisites not satisfied")
            for prereq in caseStudy.prerequisites {
                log("   - \(prereq)")
            }
            return CaseStudyResult(
                caseStudyId: caseStudy.id,
                outcome: .skipped,
                findings: ["Prerequisites not satisfied"],
                durationSeconds: 0,
                environment: caseStudy.captureEnvironment()
            )
        }
        
        log("Executing...")
        let startTime = Date()
        
        // Execute
        let result = caseStudy.execute()
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Log outcome
        log("")
        switch result.outcome {
        case .passed:
            log("✅ PASSED (Duration: \(String(format: "%.3f", duration))s)")
        case .failed:
            log("❌ FAILED (Duration: \(String(format: "%.3f", duration))s)")
        case .inconclusive:
            log("⚠️  INCONCLUSIVE (Duration: \(String(format: "%.3f", duration))s)")
        case .skipped:
            log("⏭️  SKIPPED")
        }
        
        if !result.findings.isEmpty {
            log("")
            log("FINDINGS:")
            for finding in result.findings {
                log("  • \(finding)")
            }
        }
        
        // Write individual result to file
        writeResultToFile(result, caseStudy: caseStudy)
        
        return result
    }
    #endif
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        #if DEBUG
        print("[CaseStudyRunner] \(message)")
        #endif
    }
    
    // MARK: - File Output
    
    #if DEBUG
    private func writeResultToFile(_ result: CaseStudyResult, caseStudy: CaseStudyProtocol) {
        let fileManager = FileManager.default
        
        // Get SecurityEvidence/Logs path
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            log("Warning: Could not access documents directory for logging")
            return
        }
        
        let logsPath = documentsPath.appendingPathComponent("SecurityEvidence/Logs")
        
        // Create directory if needed
        try? fileManager.createDirectory(at: logsPath, withIntermediateDirectories: true)
        
        // Create filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: result.executedAt)
        let filename = "casestudy_\(caseStudy.id)_\(timestamp).json"
        
        let filePath = logsPath.appendingPathComponent(filename)
        
        // Build output structure
        let output: [String: Any] = [
            "caseStudyId": result.caseStudyId,
            "name": caseStudy.name,
            "category": caseStudy.category.rawValue,
            "severity": caseStudy.severity.rawValue,
            "claimTested": caseStudy.claimTested,
            "hypothesis": caseStudy.hypothesis,
            "executionSteps": caseStudy.executionSteps,
            "expectedResult": caseStudy.expectedResult,
            "validationMethod": caseStudy.validationMethod,
            "outcome": result.outcome.rawValue,
            "findings": result.findings,
            "durationSeconds": result.durationSeconds,
            "executedAt": ISO8601DateFormatter().string(from: result.executedAt),
            "environment": result.environment
        ]
        
        // Write JSON
        if let jsonData = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]) {
            try? jsonData.write(to: filePath)
            log("Result written to: \(filePath.path)")
        }
    }
    
    private func writeResultsToFile(_ results: [CaseStudyResult]) {
        let fileManager = FileManager.default
        
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let logsPath = documentsPath.appendingPathComponent("SecurityEvidence/Logs")
        try? fileManager.createDirectory(at: logsPath, withIntermediateDirectories: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "casestudy_suite_\(timestamp).json"
        
        let filePath = logsPath.appendingPathComponent(filename)
        
        let summary: [String: Any] = [
            "executedAt": ISO8601DateFormatter().string(from: Date()),
            "totalCaseStudies": results.count,
            "passed": results.filter { $0.outcome == .passed }.count,
            "failed": results.filter { $0.outcome == .failed }.count,
            "inconclusive": results.filter { $0.outcome == .inconclusive }.count,
            "skipped": results.filter { $0.outcome == .skipped }.count,
            "results": results.map { result -> [String: Any] in
                return [
                    "caseStudyId": result.caseStudyId,
                    "outcome": result.outcome.rawValue,
                    "findings": result.findings,
                    "durationSeconds": result.durationSeconds
                ]
            }
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]) {
            try? jsonData.write(to: filePath)
            log("Suite results written to: \(filePath.path)")
        }
    }
    #endif
    
    // MARK: - Built-in Registration
    
    #if DEBUG
    private func registerBuiltInCaseStudies() {
        // Original case studies
        register(GhostPacketCaseStudy())
        register(ResidualMemoryCaseStudy())
        register(MetadataLeakageCaseStudy())
        
        // Adversarial stress test case studies (Phase 12E)
        register(ZeroNetworkingCaseStudy())         // CS-NET-002: Full air-gap verification
        register(ProofPackIntegrityCaseStudy())     // CS-LEAK-002: ProofPack content inference
        register(RuntimeSealBypassCaseStudy())      // CS-SEAL-001: Seal bypass attempts
        register(ApprovalGateCoercionCaseStudy())   // CS-APPROVAL-001: Approval bypass attempts
        register(BuildSystemIntegrityCaseStudy())   // CS-BUILD-001: Debug/Release integrity
    }
    #endif
}

// MARK: - Convenience Entry Points

#if DEBUG
/// Entry point for running all case studies from tests or debug builds.
/// Usage: SecurityCaseStudies.runAll()
public enum SecurityCaseStudies {
    
    /// Run all registered case studies.
    @discardableResult
    public static func runAll() -> [CaseStudyResult] {
        return CaseStudyRunner.shared.runAll()
    }
    
    /// Run a specific case study by ID.
    @discardableResult
    public static func run(id: String) -> CaseStudyResult? {
        return CaseStudyRunner.shared.run(caseStudyId: id)
    }
    
    /// Run all case studies in a category.
    @discardableResult
    public static func run(category: CaseStudyCategory) -> [CaseStudyResult] {
        return CaseStudyRunner.shared.run(category: category)
    }
    
    /// List all registered case study IDs.
    public static var registeredIds: [String] {
        return CaseStudyRunner.shared.registeredIds
    }
}
#endif
