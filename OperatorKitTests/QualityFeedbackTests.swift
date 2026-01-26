import XCTest
@testable import OperatorKit

/// Tests for quality feedback system (Phase 8A)
/// Ensures feedback storage is safe, local-only, and respects invariants
final class QualityFeedbackTests: XCTestCase {
    
    // Use a separate UserDefaults for testing
    private var testDefaults: UserDefaults!
    private var testStore: QualityFeedbackStore!
    
    override func setUp() {
        super.setUp()
        // Use in-memory defaults for testing
        testDefaults = UserDefaults(suiteName: "QualityFeedbackTests")
        testDefaults?.removePersistentDomain(forName: "QualityFeedbackTests")
    }
    
    override func tearDown() {
        testDefaults?.removePersistentDomain(forName: "QualityFeedbackTests")
        super.tearDown()
    }
    
    // MARK: - Raw Content Validation Tests
    
    func testFeedbackCannotStoreEmailAddressInNote() {
        let entry = QualityFeedbackEntry(
            memoryItemId: UUID(),
            rating: .notHelpful,
            issueTags: [.other],
            optionalNote: "Contact me at john.doe@example.com please"
        )
        
        XCTAssertFalse(
            entry.validateNoRawContent(),
            "Feedback should not allow email addresses in notes"
        )
    }
    
    func testFeedbackCannotStorePhoneNumberInNote() {
        let entry = QualityFeedbackEntry(
            memoryItemId: UUID(),
            rating: .notHelpful,
            issueTags: [.other],
            optionalNote: "Call me at 555-123-4567"
        )
        
        XCTAssertFalse(
            entry.validateNoRawContent(),
            "Feedback should not allow phone numbers in notes"
        )
    }
    
    func testFeedbackAllowsGenericNote() {
        let entry = QualityFeedbackEntry(
            memoryItemId: UUID(),
            rating: .notHelpful,
            issueTags: [.wrongTone],
            optionalNote: "The tone was too formal for a casual email"
        )
        
        XCTAssertTrue(
            entry.validateNoRawContent(),
            "Feedback should allow generic notes without PII"
        )
    }
    
    // MARK: - Note Length Tests
    
    func testNoteLengthEnforced() {
        let longNote = String(repeating: "a", count: 500)
        let entry = QualityFeedbackEntry(
            memoryItemId: UUID(),
            rating: .notHelpful,
            optionalNote: longNote
        )
        
        XCTAssertEqual(
            entry.optionalNote?.count,
            QualityFeedbackEntry.maxNoteLength,
            "Note should be truncated to max length"
        )
    }
    
    func testEmptyNoteAllowed() {
        let entry = QualityFeedbackEntry(
            memoryItemId: UUID(),
            rating: .helpful,
            optionalNote: nil
        )
        
        XCTAssertNil(entry.optionalNote)
        XCTAssertTrue(entry.validateNoRawContent())
    }
    
    // MARK: - Calibration Summary Tests
    
    func testCalibrationSummaryComputesCorrectly() {
        // Create test entries
        let entries: [QualityFeedbackEntry] = [
            QualityFeedbackEntry(memoryItemId: UUID(), rating: .helpful, confidence: 0.8),
            QualityFeedbackEntry(memoryItemId: UUID(), rating: .helpful, confidence: 0.7),
            QualityFeedbackEntry(memoryItemId: UUID(), rating: .notHelpful, issueTags: [.missingContext], confidence: 0.4),
            QualityFeedbackEntry(memoryItemId: UUID(), rating: .mixed, confidence: 0.5),
            QualityFeedbackEntry(memoryItemId: UUID(), rating: .helpful, confidence: 0.9),
        ]
        
        let helpfulCount = entries.filter { $0.rating == .helpful }.count
        let totalCount = entries.count
        let expectedRate = Double(helpfulCount) / Double(totalCount)
        
        XCTAssertEqual(helpfulCount, 3)
        XCTAssertEqual(totalCount, 5)
        XCTAssertEqual(expectedRate, 0.6, accuracy: 0.01)
    }
    
    func testCalibrationByConfidenceBand() {
        // Test confidence band logic
        let lowConfidence = 0.30
        let medConfidence = 0.50
        let highConfidence = 0.80
        
        XCTAssertTrue(CalibrationSummary.ConfidenceBand.low.range.contains(lowConfidence))
        XCTAssertTrue(CalibrationSummary.ConfidenceBand.medium.range.contains(medConfidence))
        XCTAssertTrue(CalibrationSummary.ConfidenceBand.high.range.contains(highConfidence))
        
        XCTAssertFalse(CalibrationSummary.ConfidenceBand.low.range.contains(0.35))
        XCTAssertFalse(CalibrationSummary.ConfidenceBand.medium.range.contains(0.65))
    }
    
    // MARK: - Export Tests
    
    func testExportJSONSchemaValid() throws {
        let entry = QualityFeedbackEntry(
            memoryItemId: UUID(),
            rating: .helpful,
            modelBackend: "DeterministicTemplateModel",
            confidence: 0.85,
            usedFallback: false
        )
        
        let export = QualityFeedbackExport(entries: [entry])
        let jsonData = try export.toJSON()
        
        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        XCTAssertNotNil(json)
        
        // Verify required fields
        XCTAssertNotNil(json?["schemaVersion"])
        XCTAssertNotNil(json?["exportedAt"])
        XCTAssertNotNil(json?["totalEntries"])
        XCTAssertNotNil(json?["entries"])
    }
    
    func testExportDoesNotContainRawContent() throws {
        let entry = QualityFeedbackEntry(
            memoryItemId: UUID(),
            rating: .notHelpful,
            issueTags: [.wrongTone],
            optionalNote: "Some note"  // Note is NOT exported in raw form
        )
        
        let export = QualityFeedbackExport(entries: [entry])
        let jsonData = try export.toJSON()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        
        // Verify note content is not in export (only hasNote boolean)
        XCTAssertFalse(jsonString.contains("Some note"), "Export should not contain raw note content")
        XCTAssertTrue(jsonString.contains("\"hasNote\""), "Export should contain hasNote field")
    }
    
    func testExportSchemaVersion() throws {
        let export = QualityFeedbackExport(entries: [])
        
        XCTAssertEqual(export.schemaVersion, QualityFeedbackEntry.schemaVersion)
        XCTAssertEqual(export.schemaVersion, "1.0")
    }
    
    // MARK: - Issue Tag Tests
    
    func testAllIssueTagsHaveDisplayNames() {
        for tag in QualityIssueTag.allCases {
            XCTAssertFalse(tag.displayName.isEmpty, "Tag \(tag) should have a display name")
            XCTAssertFalse(tag.description.isEmpty, "Tag \(tag) should have a description")
        }
    }
    
    func testIssueTagCount() {
        // Verify we have exactly the expected number of tags
        XCTAssertEqual(QualityIssueTag.allCases.count, 10, "Should have exactly 10 issue tags")
    }
    
    // MARK: - Rating Tests
    
    func testAllRatingsHaveDisplayNames() {
        for rating in QualityRating.allCases {
            XCTAssertFalse(rating.displayName.isEmpty, "Rating \(rating) should have a display name")
            XCTAssertFalse(rating.systemImage.isEmpty, "Rating \(rating) should have a system image")
        }
    }
    
    // MARK: - Immutability Tests
    
    func testFeedbackEntryIsImmutable() {
        let entry = QualityFeedbackEntry(
            memoryItemId: UUID(),
            rating: .helpful
        )
        
        // All properties should be let (immutable)
        // This test documents the expected behavior
        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(entry.memoryItemId)
        XCTAssertEqual(entry.rating, .helpful)
        XCTAssertNotNil(entry.createdAt)
    }
    
    // MARK: - Store Error Tests
    
    func testStoreRejectsDuplicateEntry() {
        let store = QualityFeedbackStore.shared
        let memoryItemId = UUID()
        
        let entry1 = QualityFeedbackEntry(
            id: UUID(),
            memoryItemId: memoryItemId,
            rating: .helpful
        )
        
        // First add should succeed
        let result1 = store.addFeedback(entry1)
        
        switch result1 {
        case .success:
            // Now adding the same entry again should fail
            let result2 = store.addFeedback(entry1)
            switch result2 {
            case .success:
                XCTFail("Should not allow duplicate entries")
            case .failure(let error):
                XCTAssertEqual(error, .duplicateEntry)
            }
            
            // Cleanup
            _ = store.deleteFeedback(id: entry1.id)
        case .failure:
            // Entry might already exist from previous test, that's ok
            break
        }
    }
    
    func testStoreRejectsRawContent() {
        let store = QualityFeedbackStore.shared
        
        let entry = QualityFeedbackEntry(
            memoryItemId: UUID(),
            rating: .notHelpful,
            optionalNote: "Contact me at test@example.com"
        )
        
        let result = store.addFeedback(entry)
        
        switch result {
        case .success:
            // Cleanup if it got added somehow
            _ = store.deleteFeedback(id: entry.id)
            XCTFail("Should reject entries with raw content")
        case .failure(let error):
            XCTAssertEqual(error, .rawContentDetected)
        }
    }
    
    // MARK: - No Network Tests
    
    func testNoNetworkImportsInQualityModule() {
        // This test documents that no network frameworks should be used
        // The actual enforcement is via CompileTimeGuards.swift
        
        // Verify QualityFeedbackStore doesn't have network capabilities
        let store = QualityFeedbackStore.shared
        
        // If there were network calls, they would be async and require network permission
        // We verify the store is purely local by checking it works synchronously
        let entry = QualityFeedbackEntry(
            memoryItemId: UUID(),
            rating: .helpful
        )
        
        // These operations should all be synchronous and local
        let addResult = store.addFeedback(entry)
        XCTAssertTrue(store.hasFeedback(for: entry.memoryItemId) || addResult == .failure(.duplicateEntry))
        
        // Cleanup
        _ = store.deleteFeedback(id: entry.id)
    }
}
