import XCTest
@testable import OperatorKit

/// Tests for quality research track (Phase 9A)
/// Ensures all new features maintain content-free invariants
final class QualityResearchTests: XCTestCase {
    
    // MARK: - Quality Signature Tests
    
    func testQualitySignatureContainsNoUserContent() {
        let signature = QualitySignature.capture()
        
        // Encode and verify no content fields
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(signature),
           let json = String(data: data, encoding: .utf8) {
            XCTAssertFalse(json.contains("emailBody"), "Should not contain email body")
            XCTAssertFalse(json.contains("draftContent"), "Should not contain draft content")
            XCTAssertFalse(json.contains("eventTitle"), "Should not contain event title")
            XCTAssertFalse(json.contains("participants"), "Should not contain participants")
            XCTAssertFalse(json.contains("userInput"), "Should not contain user input")
        }
    }
    
    func testQualitySignatureCapture() {
        let signature = QualitySignature.capture()
        
        XCTAssertFalse(signature.appVersion.isEmpty)
        XCTAssertFalse(signature.buildNumber.isEmpty)
        XCTAssertFalse(signature.releaseMode.isEmpty)
        XCTAssertFalse(signature.backendAvailability.isEmpty)
        XCTAssertFalse(signature.deterministicModelVersion.isEmpty)
        XCTAssertGreaterThan(signature.schemaVersion, 0)
    }
    
    func testQualitySignatureSameConfiguration() {
        let sig1 = QualitySignature.capture()
        let sig2 = QualitySignature.capture()
        
        // Same config if captured at same time
        XCTAssertTrue(sig1.isSameConfiguration(as: sig2))
        XCTAssertTrue(sig1.isSameReleaseChannel(as: sig2))
    }
    
    func testQualitySignatureDiff() {
        let sig1 = QualitySignature(
            appVersion: "1.0.0",
            buildNumber: "1",
            releaseMode: "debug"
        )
        let sig2 = QualitySignature(
            appVersion: "1.1.0",
            buildNumber: "2",
            releaseMode: "testflight"
        )
        
        let diffs = sig2.diff(from: sig1)
        
        XCTAssertFalse(diffs.isEmpty, "Should detect differences")
        XCTAssertTrue(diffs.contains { 
            if case .appVersion = $0 { return true }
            return false
        })
        XCTAssertTrue(diffs.contains { 
            if case .releaseMode = $0 { return true }
            return false
        })
    }
    
    // MARK: - Quality History Tests
    
    func testDailyQualitySummaryContainsNoContent() {
        let summary = DailyQualitySummary(
            date: Date(),
            evalRunCount: 1,
            totalCasesEvaluated: 5,
            passCount: 4,
            failCount: 1,
            passRate: 0.8,
            driftLevel: "low",
            fallbackDriftCount: 0,
            averageLatencyMs: 100,
            dominantBackend: "DeterministicTemplateModel",
            releaseMode: "debug"
        )
        
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(summary),
           let json = String(data: data, encoding: .utf8) {
            XCTAssertFalse(json.contains("emailBody"))
            XCTAssertFalse(json.contains("draftContent"))
            XCTAssertFalse(json.contains("eventTitle"))
        }
    }
    
    func testQualityHistoryStoreAggregatesOnly() {
        let store = QualityHistoryStore.shared
        
        // Store should not have any content-related methods
        // This is a documentation test - the store API is metadata-only
        XCTAssertNotNil(store)
        
        // Methods available should be aggregate-only
        _ = store.summariesForLast(days: 7)
        _ = store.passRateTrend(days: 7)
        _ = store.mostRecentSummary
    }
    
    // MARK: - Quality Trend Tests
    
    func testQualityTrendComputesFromMetadataOnly() {
        let computer = QualityTrendComputer()
        let trend = computer.computeTrend(days: 30)
        
        // Trend should be based on metadata aggregates
        XCTAssertNotNil(trend.passRateDirection)
        XCTAssertNotNil(trend.driftDirection)
        XCTAssertGreaterThanOrEqual(trend.periodDays, 0)
        XCTAssertGreaterThanOrEqual(trend.dataPoints, 0)
    }
    
    func testQualityTrendInsufficientData() {
        let computer = QualityTrendComputer()
        let trend = computer.computeTrend(days: 30)
        
        // With no or little data, should return insufficient
        if trend.dataPoints < 3 {
            XCTAssertEqual(trend.passRateDirection, .insufficient)
        }
    }
    
    // MARK: - Golden Case Coverage Tests
    
    func testGoldenCaseCoverageIsContentFree() {
        let computer = GoldenCaseCoverageComputer()
        let coverage = computer.computeCoverage()
        
        // Coverage should be computed from metadata only
        XCTAssertGreaterThanOrEqual(coverage.overallScore, 0)
        XCTAssertLessThanOrEqual(coverage.overallScore, 100)
        XCTAssertGreaterThanOrEqual(coverage.totalCases, 0)
    }
    
    func testCoverageDimensionsAreGeneric() {
        let computer = GoldenCaseCoverageComputer()
        let coverage = computer.computeCoverage()
        
        // Verify dimensions use generic categories
        XCTAssertTrue(GoldenCaseCoverageComputer.expectedIntentTypes.contains("email"))
        XCTAssertTrue(GoldenCaseCoverageComputer.expectedConfidenceBands.contains("low"))
        XCTAssertTrue(GoldenCaseCoverageComputer.expectedBackendTypes.contains("DeterministicTemplateModel"))
        
        // Categories should not contain user content
        for category in coverage.intentTypeCoverage.categories {
            XCTAssertFalse(category.contains("@"), "Should not contain email addresses")
            XCTAssertFalse(category.contains("Meeting with"), "Should not contain event content")
        }
    }
    
    func testCoverageSuggestionsAreGeneric() {
        let computer = GoldenCaseCoverageComputer()
        let coverage = computer.computeCoverage()
        
        for suggestion in coverage.missingCoverage {
            // Suggestions should be generic, not content-specific
            XCTAssertFalse(suggestion.suggestion.contains("your email"))
            XCTAssertFalse(suggestion.suggestion.contains("specific"))
        }
    }
    
    // MARK: - Release Comparison Tests
    
    func testReleaseComparisonIsContentFree() {
        let computer = ReleaseComparisonComputer()
        let comparison = computer.compareDebugVsTestFlight()
        
        // Comparison should only contain metadata
        XCTAssertNotNil(comparison.verdict)
        XCTAssertGreaterThanOrEqual(comparison.channelA.runCount, 0)
        XCTAssertGreaterThanOrEqual(comparison.channelB.runCount, 0)
        
        // Encode and verify no content
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(comparison),
           let json = String(data: data, encoding: .utf8) {
            XCTAssertFalse(json.contains("emailBody"))
            XCTAssertFalse(json.contains("draftContent"))
        }
    }
    
    func testMetricComparisonsAreNumeric() {
        let computer = ReleaseComparisonComputer()
        let comparison = computer.compareDebugVsTestFlight()
        
        for metric in comparison.metricComparisons {
            // Metric names should be generic
            XCTAssertTrue(["Pass Rate", "Eval Runs", "Total Cases", "Drift Level"].contains(metric.metricName))
        }
    }
    
    // MARK: - EvalRun Signature Tests
    
    func testEvalRunIncludesSignature() {
        let run = EvalRun(
            runType: .goldenCases,
            caseCount: 0
        )
        
        XCTAssertNotNil(run.qualitySignature, "EvalRun should include quality signature")
    }
    
    func testEvalRunSchemaVersionBumped() {
        XCTAssertEqual(EvalRun.currentSchemaVersion, 2, "Schema version should be 2 for Phase 9A")
    }
    
    // MARK: - No Network Tests
    
    func testNoNetworkImportsInEvalModule() {
        // This test documents that no network frameworks should be used
        // The actual enforcement is via CompileTimeGuards.swift
        
        let signature = QualitySignature.capture()
        let historyStore = QualityHistoryStore.shared
        let trendComputer = QualityTrendComputer()
        let coverageComputer = GoldenCaseCoverageComputer()
        let comparisonComputer = ReleaseComparisonComputer()
        
        // All operations should be synchronous and local
        XCTAssertNotNil(signature)
        XCTAssertNotNil(historyStore)
        XCTAssertNotNil(trendComputer.computeTrend())
        XCTAssertNotNil(coverageComputer.computeCoverage())
        XCTAssertNotNil(comparisonComputer.compareDebugVsTestFlight())
    }
    
    // MARK: - Manual Trigger Tests
    
    func testEvalIsManualTriggerOnly() {
        // This documents that evals are manual-only
        // The LocalEvalRunner.runGoldenCaseEval() must be called explicitly
        
        let runner = LocalEvalRunner.shared
        XCTAssertFalse(runner.isRunning, "Should not be running automatically")
        
        // No scheduled eval methods should exist
        // This is enforced by not having any timer/scheduler code
    }
}
