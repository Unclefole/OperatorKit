import XCTest
@testable import OperatorKit

// ============================================================================
// SATISFACTION SIGNAL TESTS (Phase 10N)
//
// Tests for satisfaction signal:
// - Aggregates only, no free text
// - No forbidden keys
// - Questions are complete
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class SatisfactionSignalTests: XCTestCase {
    
    // MARK: - A) Aggregates Only
    
    /// Verifies summary contains only numeric aggregates
    func testSummaryIsAggregatesOnly() {
        let summary = SatisfactionSummary(
            totalResponses: 10,
            averageByQuestion: ["q1": 4.5, "q2": 3.8],
            overallAverage: 4.15,
            countByQuestion: ["q1": 5, "q2": 5],
            schemaVersion: 1,
            capturedAt: "2026-01-24"
        )
        
        // All values should be numeric types
        XCTAssertGreaterThanOrEqual(summary.totalResponses, 0)
        XCTAssertGreaterThanOrEqual(summary.overallAverage, 0)
        
        for (_, avg) in summary.averageByQuestion {
            XCTAssertGreaterThanOrEqual(avg, 0)
            XCTAssertLessThanOrEqual(avg, 5)
        }
    }
    
    /// Verifies no free text fields in response
    func testResponseHasNoFreeText() throws {
        let response = SatisfactionResponse(questionId: "test", rating: 4)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to encode response")
            return
        }
        
        // Check no string fields except questionId
        for (key, value) in json {
            if key != "questionId" && key != "respondedAt" {
                XCTAssertFalse(
                    value is String,
                    "Response has unexpected string field: \(key)"
                )
            }
        }
    }
    
    // MARK: - B) No Forbidden Keys
    
    /// Verifies summary contains no forbidden keys
    func testSummaryNoForbiddenKeys() throws {
        let summary = SatisfactionSummary(
            totalResponses: 5,
            averageByQuestion: ["q1": 4.0],
            overallAverage: 4.0,
            countByQuestion: ["q1": 5],
            schemaVersion: 1,
            capturedAt: "2026-01-24"
        )
        
        let violations = try summary.validateNoForbiddenKeys()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Summary contains forbidden keys: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies forbidden keys list includes free text keys
    func testForbiddenKeysIncludesFreeText() {
        let freeTextKeys = ["freeText", "comment", "feedback"]
        
        for key in freeTextKeys {
            XCTAssertTrue(
                SatisfactionSummary.forbiddenKeys.contains(key),
                "Missing forbidden free text key: \(key)"
            )
        }
    }
    
    // MARK: - C) Questions Completeness
    
    /// Verifies all questions have required fields
    func testQuestionsHaveRequiredFields() {
        XCTAssertEqual(
            SatisfactionQuestions.questions.count,
            3,
            "Should have 3 questions"
        )
        
        for question in SatisfactionQuestions.questions {
            XCTAssertFalse(question.id.isEmpty, "Question has empty ID")
            XCTAssertFalse(question.questionText.isEmpty, "Question \(question.id) has empty text")
            XCTAssertFalse(question.minLabel.isEmpty, "Question \(question.id) has empty min label")
            XCTAssertFalse(question.maxLabel.isEmpty, "Question \(question.id) has empty max label")
        }
    }
    
    /// Verifies questions don't ask for personal info
    func testQuestionsNoPersonalInfo() {
        let personalPatterns = ["name", "email", "phone", "address"]
        
        for question in SatisfactionQuestions.questions {
            let lowercased = question.questionText.lowercased()
            for pattern in personalPatterns {
                XCTAssertFalse(
                    lowercased.contains(pattern),
                    "Question \(question.id) asks for personal info: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - D) Rating Bounds
    
    /// Verifies rating is clamped to 1-5
    func testRatingBounds() {
        let tooLow = SatisfactionResponse(questionId: "test", rating: 0)
        XCTAssertEqual(tooLow.rating, 1, "Rating should be clamped to minimum 1")
        
        let tooHigh = SatisfactionResponse(questionId: "test", rating: 10)
        XCTAssertEqual(tooHigh.rating, 5, "Rating should be clamped to maximum 5")
        
        let valid = SatisfactionResponse(questionId: "test", rating: 3)
        XCTAssertEqual(valid.rating, 3, "Valid rating should be unchanged")
    }
    
    // MARK: - E) Export in ConversionPacket
    
    /// Verifies satisfaction is included in conversion export
    func testSatisfactionInConversionExport() async throws {
        let packet = await ConversionExportPacket()
        
        // Satisfaction summary should be present (even if empty)
        XCTAssertNotNil(packet.satisfactionSummary)
    }
    
    // MARK: - F) Schema
    
    /// Verifies schema version is set
    func testSchemaVersionIsSet() {
        XCTAssertGreaterThan(SatisfactionQuestions.schemaVersion, 0)
        XCTAssertGreaterThan(SatisfactionSummary.currentSchemaVersion, 0)
    }
}
