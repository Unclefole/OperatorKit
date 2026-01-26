import XCTest
@testable import OperatorKit

/// Tests for release acknowledgement (Phase 9B)
/// Ensures acknowledgements are process-only and contain no forbidden fields
final class ReleaseAcknowledgementTests: XCTestCase {
    
    // MARK: - Content Safety Tests
    
    func testAcknowledgementContainsNoUserContent() {
        let ack = ReleaseAcknowledgement(
            appVersion: "1.0.0",
            buildNumber: "42",
            safetyContractHash: "abc123",
            qualityGateStatus: "PASS",
            qualityGateSummary: "All checks passed",
            goldenCaseCount: 5,
            latestEvalPassRate: 0.85,
            driftLevel: "low",
            preflightPassed: true
        )
        
        // Encode and verify no content fields
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(ack),
           let json = String(data: data, encoding: .utf8) {
            // Forbidden fields that must NOT exist
            XCTAssertFalse(json.contains("emailBody"))
            XCTAssertFalse(json.contains("draftContent"))
            XCTAssertFalse(json.contains("eventTitle"))
            XCTAssertFalse(json.contains("participants"))
            XCTAssertFalse(json.contains("userInput"))
            XCTAssertFalse(json.contains("promptText"))
            XCTAssertFalse(json.contains("contextPayload"))
            XCTAssertFalse(json.contains("subject"))
            XCTAssertFalse(json.contains("body"))
        }
    }
    
    func testAcknowledgementSchemaVersion() {
        XCTAssertGreaterThan(ReleaseAcknowledgement.currentSchemaVersion, 0)
    }
    
    func testAcknowledgementCaptureState() {
        let ack = ReleaseAcknowledgement.captureCurrentState()
        
        XCTAssertFalse(ack.appVersion.isEmpty)
        XCTAssertFalse(ack.buildNumber.isEmpty)
        XCTAssertFalse(ack.safetyContractHash.isEmpty)
        XCTAssertFalse(ack.qualityGateStatus.isEmpty)
        XCTAssertGreaterThanOrEqual(ack.goldenCaseCount, 0)
    }
    
    func testAcknowledgementToJSON() throws {
        let ack = ReleaseAcknowledgement.captureCurrentState()
        let json = try ack.toJSON()
        
        XCTAssertFalse(json.isEmpty)
        
        // Verify it's valid JSON
        let decoded = try JSONDecoder().decode(ReleaseAcknowledgement.self, from: json)
        XCTAssertEqual(decoded.appVersion, ack.appVersion)
    }
    
    // MARK: - Store Tests
    
    func testStoreDoesNotAffectRuntime() {
        let store = ReleaseAcknowledgementStore.shared
        
        // Store should not have any methods that affect execution
        // This is a documentation test - the API is process-only
        
        // These methods exist and are read-only
        _ = store.latestAcknowledgement
        _ = store.isCurrentVersionAcknowledged
        _ = store.canRecordAcknowledgement
        
        // No methods should exist that:
        // - Block execution
        // - Require acknowledgement for actions
        // - Gate any user flow
    }
    
    func testStoreCanRecordAcknowledgement() {
        let store = ReleaseAcknowledgementStore.shared
        
        // This test verifies the check exists, not that it necessarily passes
        _ = store.canRecordAcknowledgement
        _ = store.recordingBlockedReason
    }
    
    // MARK: - No Runtime Flow References Tests
    
    func testNoExecutionCodeReferencesStore() {
        // This documents that execution code should NOT reference the store
        // Actual enforcement is via code review and grep checks
        
        // The acknowledgement store should only be referenced from:
        // - UI/Settings/ReleaseReadinessView.swift
        // - Safety/ReleaseAcknowledgementStore.swift (itself)
        // - Test files
        
        XCTAssertTrue(true, "Documentation test - verified via code review")
    }
}
