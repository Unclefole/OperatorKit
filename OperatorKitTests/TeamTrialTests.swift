import XCTest
@testable import OperatorKit

// ============================================================================
// TEAM TRIAL TESTS (Phase 10N)
//
// Tests for team trial:
// - Trial state contains no forbidden keys
// - Trial start requires acknowledgement
// - No tier mutation side effects
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

final class TeamTrialTests: XCTestCase {
    
    // MARK: - A) No Forbidden Keys
    
    /// Verifies trial state contains no forbidden keys
    func testTrialStateNoForbiddenKeys() throws {
        let trial = TeamTrialState.createTrial()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(trial)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to encode trial state")
            return
        }
        
        let forbiddenKeys = [
            "body", "subject", "content", "draft", "prompt",
            "context", "note", "email", "attendees", "title",
            "description", "message", "text", "recipient", "sender",
            "userId", "deviceId"
        ]
        
        for key in json.keys {
            XCTAssertFalse(
                forbiddenKeys.contains(key.lowercased()),
                "Trial state contains forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - B) Trial Start Requires Acknowledgement
    
    /// Verifies trial state has acknowledgement timestamp
    func testTrialHasAcknowledgementTimestamp() {
        let acknowledgedAt = Date()
        let trial = TeamTrialState.createTrial(acknowledgedAt: acknowledgedAt)
        
        XCTAssertEqual(
            trial.acknowledgedAt.timeIntervalSince1970,
            acknowledgedAt.timeIntervalSince1970,
            accuracy: 1.0
        )
    }
    
    /// Verifies acknowledgement terms exist
    func testAcknowledgementTermsExist() {
        XCTAssertGreaterThan(
            TeamTrialAcknowledgement.terms.count,
            0,
            "Should have acknowledgement terms"
        )
        
        XCTAssertFalse(
            TeamTrialAcknowledgement.summary.isEmpty,
            "Should have acknowledgement summary"
        )
    }
    
    /// Verifies acknowledgement terms mention process-only
    func testAcknowledgementMentionsProcessOnly() {
        let allTerms = TeamTrialAcknowledgement.terms.joined(separator: " ")
        
        XCTAssertTrue(
            allTerms.lowercased().contains("process"),
            "Terms should mention process-only"
        )
    }
    
    // MARK: - C) No Tier Mutation Side Effects
    
    /// Verifies trial store does not import execution modules
    func testTrialStoreNoExecutionImports() throws {
        let filePath = findProjectFile(named: "TeamTrialStore.swift", in: "Team")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let executionPatterns = [
            "ExecutionEngine",
            "ApprovalGate",
            "ModelRouter"
        ]
        
        for pattern in executionPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "TeamTrialStore.swift imports execution module: \(pattern)"
            )
        }
    }
    
    /// Verifies trial store has no networking
    func testTrialStoreNoNetworking() throws {
        let filePath = findProjectFile(named: "TeamTrialStore.swift", in: "Team")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "HTTPURLResponse"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "TeamTrialStore.swift contains networking: \(pattern)"
            )
        }
    }
    
    // MARK: - D) Trial Properties
    
    /// Verifies trial duration calculation
    func testTrialDurationCalculation() {
        let trial = TeamTrialState.createTrial(days: 14)
        
        XCTAssertEqual(trial.trialDays, 14)
        XCTAssertTrue(trial.isActive)
        XCTAssertGreaterThan(trial.daysRemaining, 0)
        XCTAssertLessThan(trial.progress, 1.0)
    }
    
    /// Verifies trial end date calculation
    func testTrialEndDateCalculation() {
        let trial = TeamTrialState.createTrial(days: 14)
        
        let expectedEnd = Calendar.current.date(byAdding: .day, value: 14, to: trial.trialStartDate)!
        XCTAssertEqual(
            trial.trialEndDate.timeIntervalSince1970,
            expectedEnd.timeIntervalSince1970,
            accuracy: 60  // Within 1 minute
        )
    }
    
    // MARK: - E) Schema
    
    /// Verifies schema version is set
    func testSchemaVersionIsSet() {
        XCTAssertGreaterThan(TeamTrialState.currentSchemaVersion, 0)
    }
    
    // MARK: - Helpers
    
    private func findProjectFile(named fileName: String, in subdirectory: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        return projectRoot
            .appendingPathComponent("OperatorKit")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent(fileName)
            .path
    }
}
