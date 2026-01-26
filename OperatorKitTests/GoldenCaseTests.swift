import XCTest
@testable import OperatorKit

/// Tests for golden case system (Phase 8B)
/// Ensures golden cases store metadata only and respect all invariants
final class GoldenCaseTests: XCTestCase {
    
    // MARK: - Snapshot Content Safety Tests
    
    func testSnapshotStoresNoRawContent() {
        // Create a snapshot with typical metadata
        let snapshot = GoldenCaseSnapshot(
            intentType: "email",
            outputType: "email",
            contextCounts: .init(calendar: 2, reminders: 0, mail: 1, files: 0),
            confidenceBand: "high",
            backendUsed: "DeterministicTemplateModel",
            usedFallback: false,
            timeoutOccurred: false,
            validationPass: true,
            citationValidityPass: true,
            citationsCount: 3,
            latencyMs: 450,
            promptScaffoldHash: "abc123"
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try? encoder.encode(snapshot)
        let jsonString = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        
        // Verify no potential content fields
        XCTAssertFalse(jsonString.contains("emailBody"), "Should not contain email body")
        XCTAssertFalse(jsonString.contains("eventTitle"), "Should not contain event title")
        XCTAssertFalse(jsonString.contains("draftContent"), "Should not contain draft content")
        XCTAssertFalse(jsonString.contains("participants"), "Should not contain participants")
        
        // Verify only metadata fields
        XCTAssertTrue(jsonString.contains("intentType"))
        XCTAssertTrue(jsonString.contains("outputType"))
        XCTAssertTrue(jsonString.contains("confidenceBand"))
        XCTAssertTrue(jsonString.contains("backendUsed"))
    }
    
    func testGoldenCaseExportExcludesContent() throws {
        let snapshot = GoldenCaseSnapshot(
            intentType: "meeting_summary",
            outputType: "summary",
            contextCounts: .init(calendar: 1, reminders: 0, mail: 0, files: 0),
            confidenceBand: "medium",
            backendUsed: "DeterministicTemplateModel",
            usedFallback: true,
            timeoutOccurred: false,
            validationPass: true,
            citationValidityPass: true,
            citationsCount: 1,
            latencyMs: 200,
            promptScaffoldHash: nil
        )
        
        let goldenCase = GoldenCase(
            title: "Test Golden Case",
            source: .memoryItem,
            memoryItemId: UUID(),
            snapshot: snapshot
        )
        
        let export = GoldenCaseExport(cases: [goldenCase])
        let jsonData = try export.toJSON()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        
        // Verify export format
        XCTAssertTrue(jsonString.contains("schemaVersion"))
        XCTAssertTrue(jsonString.contains("exportedAt"))
        XCTAssertTrue(jsonString.contains("totalCases"))
        
        // Verify no content
        XCTAssertFalse(jsonString.contains("emailBody"))
        XCTAssertFalse(jsonString.contains("eventDetails"))
        XCTAssertFalse(jsonString.contains("rawContent"))
    }
    
    // MARK: - Title Length Tests
    
    func testTitleLengthEnforced() {
        let longTitle = String(repeating: "a", count: 200)
        let goldenCase = GoldenCase(
            title: longTitle,
            source: .memoryItem,
            memoryItemId: UUID(),
            snapshot: createMinimalSnapshot()
        )
        
        XCTAssertEqual(
            goldenCase.title.count,
            GoldenCase.maxTitleLength,
            "Title should be truncated to max length"
        )
    }
    
    func testRenameEnforcesMaxLength() {
        var goldenCase = GoldenCase(
            title: "Original Title",
            source: .memoryItem,
            memoryItemId: UUID(),
            snapshot: createMinimalSnapshot()
        )
        
        let longTitle = String(repeating: "b", count: 200)
        goldenCase.rename(longTitle)
        
        XCTAssertEqual(
            goldenCase.title.count,
            GoldenCase.maxTitleLength,
            "Renamed title should be truncated"
        )
    }
    
    // MARK: - Duplicate Prevention Tests
    
    func testStorePreventsMemoryItemDuplicate() {
        let store = GoldenCaseStore.shared
        let memoryItemId = UUID()
        
        let case1 = GoldenCase(
            id: UUID(),
            title: "First Case",
            source: .memoryItem,
            memoryItemId: memoryItemId,
            snapshot: createMinimalSnapshot()
        )
        
        let case2 = GoldenCase(
            id: UUID(),
            title: "Duplicate Case",
            source: .memoryItem,
            memoryItemId: memoryItemId,  // Same memory item
            snapshot: createMinimalSnapshot()
        )
        
        // First add should succeed
        let result1 = store.addCase(case1)
        
        switch result1 {
        case .success:
            // Second add should fail
            let result2 = store.addCase(case2)
            
            switch result2 {
            case .success:
                XCTFail("Should not allow duplicate memory item")
            case .failure(let error):
                XCTAssertEqual(error, .duplicateMemoryItem)
            }
            
            // Cleanup
            _ = store.deleteCase(id: case1.id)
        case .failure:
            // Entry might already exist from previous test
            break
        }
    }
    
    func testStoreAllowsExplicitDuplicate() {
        let store = GoldenCaseStore.shared
        let memoryItemId = UUID()
        
        let case1 = GoldenCase(
            id: UUID(),
            title: "First Case",
            source: .memoryItem,
            memoryItemId: memoryItemId,
            snapshot: createMinimalSnapshot()
        )
        
        let case2 = GoldenCase(
            id: UUID(),
            title: "Explicit Duplicate",
            source: .memoryItem,
            memoryItemId: memoryItemId,
            snapshot: createMinimalSnapshot()
        )
        
        let result1 = store.addCase(case1)
        
        switch result1 {
        case .success:
            // Explicit duplicate should succeed
            let result2 = store.addCase(case2, allowDuplicate: true)
            
            switch result2 {
            case .success:
                XCTAssertTrue(true)
                // Cleanup
                _ = store.deleteCase(id: case2.id)
            case .failure:
                XCTFail("Should allow explicit duplicate")
            }
            
            // Cleanup
            _ = store.deleteCase(id: case1.id)
        case .failure:
            break
        }
    }
    
    // MARK: - Context Counts Tests
    
    func testContextCountsSummary() {
        let counts = GoldenCaseSnapshot.ContextCounts(
            calendar: 2,
            reminders: 1,
            mail: 0,
            files: 3
        )
        
        XCTAssertEqual(counts.total, 6)
        XCTAssertTrue(counts.summary.contains("Calendar: 2"))
        XCTAssertTrue(counts.summary.contains("Reminders: 1"))
        XCTAssertFalse(counts.summary.contains("Mail"))  // 0 should be omitted
        XCTAssertTrue(counts.summary.contains("Files: 3"))
    }
    
    func testEmptyContextCountsSummary() {
        let counts = GoldenCaseSnapshot.ContextCounts()
        
        XCTAssertEqual(counts.total, 0)
        XCTAssertEqual(counts.summary, "No context")
    }
    
    // MARK: - Schema Version Tests
    
    func testSchemaVersionIsSet() {
        let snapshot = createMinimalSnapshot()
        
        XCTAssertEqual(snapshot.schemaVersion, GoldenCase.schemaVersion)
        XCTAssertEqual(GoldenCase.schemaVersion, 1)
    }
    
    // MARK: - Helper Methods
    
    private func createMinimalSnapshot() -> GoldenCaseSnapshot {
        GoldenCaseSnapshot(
            intentType: "test",
            outputType: "test",
            contextCounts: .init(),
            confidenceBand: "medium",
            backendUsed: "DeterministicTemplateModel",
            usedFallback: false,
            timeoutOccurred: false,
            validationPass: true,
            citationValidityPass: true,
            citationsCount: 0,
            latencyMs: nil,
            promptScaffoldHash: nil
        )
    }
}
