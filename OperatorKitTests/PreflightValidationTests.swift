import XCTest
@testable import OperatorKit

/// Tests for preflight validation (Phase 7B)
/// These tests ensure the app is ready for TestFlight and App Store submission
final class PreflightValidationTests: XCTestCase {
    
    // MARK: - Preflight Validator Tests
    
    func testPreflightValidatorRunsAllChecks() {
        let validator = PreflightValidator.shared
        let report = validator.runAllChecks()
        
        // Should have multiple checks
        XCTAssertGreaterThan(report.totalCount, 10, "Should run at least 10 preflight checks")
    }
    
    func testPreflightValidatorNoBlockers() {
        let validator = PreflightValidator.shared
        let report = validator.runAllChecks()
        
        XCTAssertTrue(
            report.blockers.isEmpty,
            """
            Preflight validation has blocking issues:
            \(report.blockers.map { $0.message }.joined(separator: "\n"))
            """
        )
    }
    
    func testPreflightValidatorIsReady() {
        let validator = PreflightValidator.shared
        
        // In DEBUG, some checks may fail (e.g., "not a release build")
        // But there should be no blockers
        XCTAssertTrue(
            validator.blockingIssues.isEmpty,
            "Should have no blocking issues: \(validator.blockingIssues.map { $0.message })"
        )
    }
    
    // MARK: - Release Config Tests
    
    func testReleaseModeDetected() {
        let mode = ReleaseMode.current
        
        // In test environment, should be debug
        #if DEBUG
        XCTAssertEqual(mode, .debug)
        #endif
    }
    
    func testReleaseSafetyConfigValid() {
        let violations = ReleaseSafetyConfig.validateConfiguration()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Release safety config violations: \(violations)"
        )
    }
    
    func testDisabledFeaturesAreDisabled() {
        // These should all be false
        XCTAssertFalse(ReleaseSafetyConfig.networkEntitlementsEnabled)
        XCTAssertFalse(ReleaseSafetyConfig.backgroundModesEnabled)
        XCTAssertFalse(ReleaseSafetyConfig.pushNotificationsEnabled)
        XCTAssertFalse(ReleaseSafetyConfig.analyticsEnabled)
        XCTAssertFalse(ReleaseSafetyConfig.telemetryEnabled)
    }
    
    func testRequiredFeaturesAreEnabled() {
        // These should all be true
        XCTAssertTrue(ReleaseSafetyConfig.deterministicFallbackRequired)
        XCTAssertTrue(ReleaseSafetyConfig.approvalGateRequired)
        XCTAssertTrue(ReleaseSafetyConfig.twoKeyConfirmationRequired)
        XCTAssertTrue(ReleaseSafetyConfig.draftFirstRequired)
        XCTAssertTrue(ReleaseSafetyConfig.onDeviceProcessingRequired)
    }
    
    // MARK: - App Store Metadata Tests
    
    func testAppStoreMetadataValid() {
        let issues = AppStoreMetadata.validate()
        
        XCTAssertTrue(
            issues.isEmpty,
            "App Store metadata validation issues: \(issues)"
        )
    }
    
    func testSubtitleLengthValid() {
        XCTAssertLessThanOrEqual(
            AppStoreMetadata.subtitle.count,
            30,
            "Subtitle must be 30 characters or less"
        )
    }
    
    func testPromotionalTextLengthValid() {
        XCTAssertLessThanOrEqual(
            AppStoreMetadata.promotionalText.count,
            170,
            "Promotional text must be 170 characters or less"
        )
    }
    
    func testKeywordsLengthValid() {
        XCTAssertLessThanOrEqual(
            AppStoreMetadata.keywords.count,
            100,
            "Keywords must be 100 characters or less"
        )
    }
    
    func testDescriptionLengthValid() {
        XCTAssertLessThanOrEqual(
            AppStoreMetadata.fullDescription.count,
            4000,
            "Description must be 4000 characters or less"
        )
    }
    
    // MARK: - Invariant Runner Tests
    
    func testInvariantRunnerAllChecksPassed() {
        let runner = InvariantCheckRunner.shared
        let failedChecks = runner.failedChecks
        
        XCTAssertTrue(
            failedChecks.isEmpty,
            "Invariant checks failed: \(failedChecks.map { $0.message })"
        )
    }
    
    func testNoBackgroundModesInInfoPlist() {
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        
        XCTAssertNil(
            backgroundModes,
            "UIBackgroundModes should not be present in Info.plist"
        )
    }
    
    // MARK: - Logger Tests
    
    func testLoggerDoesNotCrash() {
        // These should not crash
        logDebug("Test debug message")
        logInfo("Test info message")
        logWarning("Test warning message")
        logError("Test error message")
        
        ReleaseLogger.shared.flowStep(from: "test", to: "test")
        ReleaseLogger.shared.permissionRequest("calendar", granted: true)
        ReleaseLogger.shared.modelGeneration(backend: "test", latencyMs: 100, confidence: 0.85)
        ReleaseLogger.shared.executionStep("test", success: true)
        ReleaseLogger.shared.auditEvent("test", itemId: "test-id-12345")
        ReleaseLogger.shared.siriRoute(intentText: "test intent")
        ReleaseLogger.shared.preflightCheck("test", passed: true)
        
        // If we got here, logging works
        XCTAssertTrue(true)
    }
    
    // MARK: - Audit Immutability Tests
    
    func testAuditImmutabilityGuardTracksFinalization() {
        let guard_ = AuditImmutabilityGuard.shared
        let testId = "test-\(UUID().uuidString)"
        
        // Initially not finalized
        XCTAssertFalse(guard_.isFinalized(id: testId))
        
        // Finalize
        guard_.finalizeItem(id: testId)
        
        // Now finalized
        XCTAssertTrue(guard_.isFinalized(id: testId))
    }
    
    // MARK: - Privacy Strings Tests
    
    func testPrivacyStringsNotEmpty() {
        XCTAssertFalse(PrivacyStrings.Calendar.usageDescription.isEmpty)
        XCTAssertFalse(PrivacyStrings.Reminders.usageDescription.isEmpty)
        XCTAssertFalse(PrivacyStrings.Siri.usageDescription.isEmpty)
        XCTAssertFalse(PrivacyStrings.General.mainStatement.isEmpty)
    }
    
    func testPrivacyStringsConsistent() {
        // All strings should mention on-device or no network
        let onDeviceKeywords = ["on-device", "on your device", "locally", "no data is sent", "not transmitted"]
        
        let generalStatement = PrivacyStrings.General.onDeviceStatement.lowercased()
        let containsKeyword = onDeviceKeywords.contains { generalStatement.contains($0) }
        
        XCTAssertTrue(containsKeyword, "On-device statement should mention local processing")
    }
}

// MARK: - Safety Contract Tests (Phase 8C)

extension PreflightValidationTests {
    
    func testSafetyContractSnapshotSchemaVersion() {
        XCTAssertGreaterThan(SafetyContractSnapshot.schemaVersion, 0)
    }
    
    func testSafetyContractSnapshotLastUpdateReason() {
        XCTAssertFalse(SafetyContractSnapshot.lastUpdateReason.isEmpty)
    }
    
    func testSafetyContractStatusTypes() {
        // Test status types have proper display names
        XCTAssertEqual(SafetyContractStatus.MatchStatus.matched.displayName, "Matched")
        XCTAssertEqual(SafetyContractStatus.MatchStatus.modified.displayName, "Modified")
        XCTAssertEqual(SafetyContractStatus.MatchStatus.notFound.displayName, "Not Found")
    }
    
    func testSafetyContractExportFormat() throws {
        let export = SafetyContractExport()
        let jsonData = try export.toJSON()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        
        XCTAssertTrue(jsonString.contains("schemaVersion"))
        XCTAssertTrue(jsonString.contains("exportedAt"))
        XCTAssertTrue(jsonString.contains("expectedHash"))
        XCTAssertTrue(jsonString.contains("isUnchanged"))
    }
}

// MARK: - Quality Gate Tests (Phase 8C)

extension PreflightValidationTests {
    
    func testQualityGateThresholdsDefaults() {
        let thresholds = QualityGateThresholds.default
        
        XCTAssertEqual(thresholds.minimumGoldenCases, 5)
        XCTAssertEqual(thresholds.minimumPassRate, 0.80)
        XCTAssertEqual(thresholds.maximumFallbackDriftPercentage, 0.20)
        XCTAssertEqual(thresholds.maximumDaysWithoutEval, 7)
    }
    
    func testQualityGateEvaluatorRuns() {
        let evaluator = QualityGateEvaluator()
        let result = evaluator.evaluate()
        
        // Should always return a result
        XCTAssertNotNil(result)
        
        // Reasons should never be empty
        XCTAssertFalse(result.reasons.isEmpty)
        
        // Metrics should be populated
        XCTAssertGreaterThanOrEqual(result.metrics.goldenCaseCount, 0)
        XCTAssertGreaterThanOrEqual(result.metrics.totalEvalRuns, 0)
    }
    
    func testQualityGateSkippedWithoutGoldenCases() {
        // With no golden cases, gate should be skipped
        let evaluator = QualityGateEvaluator(
            goldenCaseStore: .shared,
            evalRunner: .shared,
            thresholds: .default
        )
        
        let result = evaluator.evaluate()
        
        if result.metrics.goldenCaseCount < QualityGateThresholds.default.minimumGoldenCases {
            XCTAssertEqual(result.status, .skipped, "Should skip when insufficient golden cases")
        }
    }
    
    func testQualityGateStatusDisplayNames() {
        XCTAssertEqual(GateStatus.pass.displayName, "PASS")
        XCTAssertEqual(GateStatus.warn.displayName, "WARN")
        XCTAssertEqual(GateStatus.fail.displayName, "FAIL")
        XCTAssertEqual(GateStatus.skipped.displayName, "SKIPPED")
    }
    
    func testQualityGateResultExport() throws {
        let evaluator = QualityGateEvaluator()
        let result = evaluator.evaluate()
        
        let jsonData = try result.toJSON()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        
        XCTAssertTrue(jsonString.contains("status"))
        XCTAssertTrue(jsonString.contains("reasons"))
        XCTAssertTrue(jsonString.contains("metrics"))
        XCTAssertTrue(jsonString.contains("thresholds"))
    }
    
    func testQualityGateResultSummary() {
        let evaluator = QualityGateEvaluator()
        let result = evaluator.evaluate()
        
        // Summary should be human-readable
        XCTAssertFalse(result.summary.isEmpty)
        XCTAssertTrue(result.summary.contains("gate") || result.summary.contains("Quality"))
    }
}

// MARK: - Integration Tests

extension PreflightValidationTests {
    
    func testFullPreflightReport() {
        let validator = PreflightValidator.shared
        let report = validator.runAllChecks()
        
        // Print summary for manual review
        print(report.summary)
        
        // Basic sanity checks
        XCTAssertGreaterThan(report.passedCount, 0, "Should have some passed checks")
        XCTAssertEqual(report.releaseMode, .debug, "Should be in debug mode during tests")
    }
    
    func testPreflightIncludesSafetyContractCheck() {
        let validator = PreflightValidator.shared
        let report = validator.runAllChecks()
        
        // Should have a safety contract check
        let safetyContractChecks = report.results.filter { $0.category == "Safety Contract" }
        XCTAssertGreaterThan(safetyContractChecks.count, 0, "Should include safety contract checks")
    }
    
    func testPreflightIncludesQualityGateCheck() {
        let validator = PreflightValidator.shared
        let report = validator.runAllChecks()
        
        // Should have quality gate checks
        let qualityGateChecks = report.results.filter { $0.category == "Quality Gate" }
        XCTAssertGreaterThan(qualityGateChecks.count, 0, "Should include quality gate checks")
    }
}
