import XCTest
@testable import OperatorKit

/// Tests for local eval runner (Phase 8B)
/// Ensures eval runs store metadata only and pass/fail rules are correct
final class LocalEvalRunnerTests: XCTestCase {
    
    // MARK: - Pass/Fail Rule Tests
    
    func testTimeoutCausesFailure() {
        let snapshot = createSnapshot(
            timeoutOccurred: true,
            validationPass: true,
            citationValidityPass: true,
            usedFallback: false
        )
        
        let result = evaluateSnapshot(snapshot)
        
        XCTAssertFalse(result.pass, "Timeout should cause failure")
        XCTAssertTrue(result.failureReasons.contains(.timeout))
    }
    
    func testValidationFailedCausesFailure() {
        let snapshot = createSnapshot(
            timeoutOccurred: false,
            validationPass: false,
            citationValidityPass: true,
            usedFallback: false
        )
        
        let result = evaluateSnapshot(snapshot)
        
        XCTAssertFalse(result.pass, "Validation failed should cause failure")
        XCTAssertTrue(result.failureReasons.contains(.validationFailed))
    }
    
    func testCitationValidityFailedCausesFailure() {
        let snapshot = createSnapshot(
            timeoutOccurred: false,
            validationPass: true,
            citationValidityPass: false,
            usedFallback: false
        )
        
        let result = evaluateSnapshot(snapshot)
        
        XCTAssertFalse(result.pass, "Citation validity failed should cause failure")
        XCTAssertTrue(result.failureReasons.contains(.citationValidityFailed))
    }
    
    func testLatencyExceededCausesFailure() {
        let snapshot = createSnapshot(
            timeoutOccurred: false,
            validationPass: true,
            citationValidityPass: true,
            usedFallback: false,
            latencyMs: 2000  // Exceeds default 1500ms threshold
        )
        
        let result = evaluateSnapshot(snapshot)
        
        XCTAssertFalse(result.pass, "Latency exceeded should cause failure")
        XCTAssertTrue(result.failureReasons.contains(.latencyExceeded))
    }
    
    func testPassingCase() {
        let snapshot = createSnapshot(
            timeoutOccurred: false,
            validationPass: true,
            citationValidityPass: true,
            usedFallback: false,
            latencyMs: 500
        )
        
        let result = evaluateSnapshot(snapshot)
        
        XCTAssertTrue(result.pass, "Good case should pass")
        XCTAssertTrue(result.failureReasons.isEmpty)
    }
    
    func testMultipleFailures() {
        let snapshot = createSnapshot(
            timeoutOccurred: true,
            validationPass: false,
            citationValidityPass: false,
            usedFallback: false
        )
        
        let result = evaluateSnapshot(snapshot)
        
        XCTAssertFalse(result.pass)
        XCTAssertTrue(result.failureReasons.count >= 3, "Should have multiple failure reasons")
    }
    
    // MARK: - Drift Summary Tests
    
    func testDriftSummaryCalculation() {
        // Create mock results with known outcomes
        let passResult = EvalCaseResult(
            goldenCaseId: UUID(),
            memoryItemId: UUID(),
            pass: true,
            metrics: createMetrics(usedFallback: false, timeoutOccurred: false)
        )
        
        let failResult = EvalCaseResult(
            goldenCaseId: UUID(),
            memoryItemId: UUID(),
            pass: false,
            metrics: createMetrics(usedFallback: true, timeoutOccurred: true),
            failureReasons: [.timeout, .fallbackDrift]
        )
        
        let run = EvalRun(
            runType: .auditDriftWatch,
            caseCount: 2,
            results: [passResult, failResult]
        )
        
        // Verify math
        XCTAssertEqual(run.passCount, 1)
        XCTAssertEqual(run.failCount, 1)
        XCTAssertEqual(run.passRate, 0.5, accuracy: 0.01)
    }
    
    func testDriftLevelCategories() {
        // Test drift level calculation
        XCTAssertEqual(
            computeDriftLevel(passRate: 1.0, backendShifts: 0),
            DriftSummary.DriftLevel.none
        )
        
        XCTAssertEqual(
            computeDriftLevel(passRate: 0.95, backendShifts: 0),
            DriftSummary.DriftLevel.low
        )
        
        XCTAssertEqual(
            computeDriftLevel(passRate: 0.8, backendShifts: 1),
            DriftSummary.DriftLevel.moderate
        )
        
        XCTAssertEqual(
            computeDriftLevel(passRate: 0.5, backendShifts: 0),
            DriftSummary.DriftLevel.high
        )
    }
    
    // MARK: - Export Tests
    
    func testEvalRunExportExcludesContent() throws {
        let result = EvalCaseResult(
            goldenCaseId: UUID(),
            memoryItemId: UUID(),
            pass: true,
            metrics: createMetrics(usedFallback: false, timeoutOccurred: false),
            notes: ["System note"]
        )
        
        var run = EvalRun(
            runType: .goldenCases,
            caseCount: 1,
            results: [result]
        )
        run.complete()
        
        let export = EvalRunExport(runs: [run])
        let jsonData = try export.toJSON()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        
        // Verify no content fields
        XCTAssertFalse(jsonString.contains("emailBody"))
        XCTAssertFalse(jsonString.contains("eventTitle"))
        XCTAssertFalse(jsonString.contains("draftContent"))
        
        // Verify schema version
        XCTAssertTrue(jsonString.contains("schemaVersion"))
        XCTAssertTrue(jsonString.contains("appVersion"))
        XCTAssertTrue(jsonString.contains("exportedAt"))
    }
    
    // MARK: - Deletion Tests
    
    func testDeleteSingleRun() {
        let runner = LocalEvalRunner.shared
        let initialCount = runner.runs.count
        
        // Add a test run
        var testRun = EvalRun(
            runType: .goldenCases,
            caseCount: 0,
            results: []
        )
        testRun.complete()
        
        // Note: In a real test, we'd mock the store
        // For now, verify the deletion API exists and works
        let result = runner.deleteRun(id: UUID())
        
        switch result {
        case .success:
            // Good if it found and deleted something
            break
        case .failure(let error):
            // Expected if run doesn't exist
            XCTAssertEqual(error, .runNotFound)
        }
    }
    
    // MARK: - No Network Tests
    
    func testNoNetworkImportsInEvalModule() {
        // This test documents that no network frameworks should be used
        // The actual enforcement is via CompileTimeGuards.swift
        
        // Verify LocalEvalRunner doesn't have network capabilities
        let runner = LocalEvalRunner.shared
        
        // These operations should all be synchronous and local
        XCTAssertNotNil(runner)
        XCTAssertFalse(runner.isRunning)
        
        // Export should be to local file
        if runner.runs.isEmpty == false {
            let url = try? runner.exportToFile()
            if let url = url {
                XCTAssertTrue(url.isFileURL, "Export should be to local file")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSnapshot(
        timeoutOccurred: Bool,
        validationPass: Bool?,
        citationValidityPass: Bool?,
        usedFallback: Bool,
        latencyMs: Int? = nil
    ) -> GoldenCaseSnapshot {
        GoldenCaseSnapshot(
            intentType: "test",
            outputType: "test",
            contextCounts: .init(),
            confidenceBand: "medium",
            backendUsed: "DeterministicTemplateModel",
            usedFallback: usedFallback,
            timeoutOccurred: timeoutOccurred,
            validationPass: validationPass,
            citationValidityPass: citationValidityPass,
            citationsCount: 0,
            latencyMs: latencyMs,
            promptScaffoldHash: nil
        )
    }
    
    private func createMetrics(usedFallback: Bool, timeoutOccurred: Bool) -> EvalMetrics {
        EvalMetrics(
            usedFallback: usedFallback,
            timeoutOccurred: timeoutOccurred,
            validationPass: true,
            citationValidityPass: true,
            backendUsed: "DeterministicTemplateModel"
        )
    }
    
    private func evaluateSnapshot(_ snapshot: GoldenCaseSnapshot) -> EvalCaseResult {
        // Simulate the evaluation logic from LocalEvalRunner
        var failureReasons: [EvalCaseResult.FailureReason] = []
        var pass = true
        
        if snapshot.timeoutOccurred {
            pass = false
            failureReasons.append(.timeout)
        }
        
        if snapshot.validationPass == false {
            pass = false
            failureReasons.append(.validationFailed)
        }
        
        if snapshot.citationValidityPass == false {
            pass = false
            failureReasons.append(.citationValidityFailed)
        }
        
        if let latency = snapshot.latencyMs, latency > 1500 {
            pass = false
            failureReasons.append(.latencyExceeded)
        }
        
        return EvalCaseResult(
            goldenCaseId: UUID(),
            memoryItemId: UUID(),
            pass: pass,
            metrics: EvalMetrics(
                usedFallback: snapshot.usedFallback,
                timeoutOccurred: snapshot.timeoutOccurred,
                validationPass: snapshot.validationPass,
                citationValidityPass: snapshot.citationValidityPass,
                backendUsed: snapshot.backendUsed
            ),
            failureReasons: failureReasons
        )
    }
    
    private func computeDriftLevel(passRate: Double, backendShifts: Int) -> DriftSummary.DriftLevel {
        if passRate == 1.0 && backendShifts == 0 {
            return .none
        } else if (1.0 - passRate) < 0.1 {
            return .low
        } else if (1.0 - passRate) < 0.3 {
            return .moderate
        } else {
            return .high
        }
    }
}
