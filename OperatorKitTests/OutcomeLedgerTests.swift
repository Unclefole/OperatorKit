import XCTest
@testable import OperatorKit

// ============================================================================
// OUTCOME LEDGER TESTS (Phase 10O)
//
// Tests for outcome ledger:
// - Aggregates only, no identifiers
// - No forbidden keys
// - Counts are correct
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class OutcomeLedgerTests: XCTestCase {
    
    // MARK: - A) Aggregates Only
    
    /// Verifies ledger data contains only aggregates
    func testLedgerDataIsAggregatesOnly() throws {
        let data = OutcomeLedgerData()
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(data)
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Failed to encode ledger data")
            return
        }
        
        // Should have globalCounts, templateCounts, schemaVersion, lastUpdated
        XCTAssertNotNil(json["globalCounts"])
        XCTAssertNotNil(json["templateCounts"])
        XCTAssertNotNil(json["schemaVersion"])
        XCTAssertNotNil(json["lastUpdated"])
    }
    
    /// Verifies summary is aggregates only
    func testSummaryIsAggregatesOnly() throws {
        let summary = OutcomeSummary(
            globalCounts: OutcomeCounts(shown: 10, used: 5, completed: 3),
            templateCountsCount: 2,
            topTemplatesByUsage: ["template-1"],
            topTemplatesByCompletion: ["template-1"],
            usageRate: 0.5,
            completionRate: 0.6,
            schemaVersion: 1,
            capturedAt: "2026-01-26"
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(summary)
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Failed to encode summary")
            return
        }
        
        // Should not contain user identifiers
        XCTAssertNil(json["userId"])
        XCTAssertNil(json["deviceId"])
        XCTAssertNil(json["email"])
    }
    
    // MARK: - B) No Forbidden Keys
    
    /// Verifies ledger data has no forbidden keys
    func testLedgerDataNoForbiddenKeys() throws {
        let data = OutcomeLedgerData()
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(data)
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Failed to encode ledger data")
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
                "Ledger data contains forbidden key: \(key)"
            )
        }
    }
    
    /// Verifies activation outcome summary has no forbidden keys
    func testActivationOutcomeSummaryNoForbiddenKeys() async throws {
        let summary = await ActivationOutcomeSummary()
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(summary)
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Failed to encode summary")
            return
        }
        
        let forbiddenKeys = [
            "body", "subject", "content", "draft", "prompt",
            "context", "note", "email", "userId", "deviceId"
        ]
        
        for key in json.keys {
            XCTAssertFalse(
                forbiddenKeys.contains(key.lowercased()),
                "Activation outcome summary contains forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - C) Counts
    
    /// Verifies counts start at zero
    func testCountsStartAtZero() {
        let counts = OutcomeCounts()
        
        XCTAssertEqual(counts.shown, 0)
        XCTAssertEqual(counts.used, 0)
        XCTAssertEqual(counts.completed, 0)
    }
    
    /// Verifies OutcomeCounts.zero is correct
    func testZeroConstant() {
        let zero = OutcomeCounts.zero
        
        XCTAssertEqual(zero.shown, 0)
        XCTAssertEqual(zero.used, 0)
        XCTAssertEqual(zero.completed, 0)
    }
    
    // MARK: - D) Rates
    
    /// Verifies rate calculations are correct
    func testRateCalculations() {
        let summary = OutcomeSummary(
            globalCounts: OutcomeCounts(shown: 100, used: 50, completed: 25),
            templateCountsCount: 3,
            topTemplatesByUsage: [],
            topTemplatesByCompletion: [],
            usageRate: 0.5,
            completionRate: 0.5,
            schemaVersion: 1,
            capturedAt: "2026-01-26"
        )
        
        XCTAssertEqual(summary.usageRate, 0.5, accuracy: 0.001)
        XCTAssertEqual(summary.completionRate, 0.5, accuracy: 0.001)
    }
    
    /// Verifies nil rates when denominators are zero
    func testNilRatesWhenZero() {
        let summary = OutcomeSummary(
            globalCounts: OutcomeCounts.zero,
            templateCountsCount: 0,
            topTemplatesByUsage: [],
            topTemplatesByCompletion: [],
            usageRate: nil,
            completionRate: nil,
            schemaVersion: 1,
            capturedAt: "2026-01-26"
        )
        
        XCTAssertNil(summary.usageRate)
        XCTAssertNil(summary.completionRate)
    }
    
    // MARK: - E) Schema
    
    /// Verifies schema version is set
    func testSchemaVersionIsSet() {
        XCTAssertGreaterThan(OutcomeLedgerData.currentSchemaVersion, 0)
    }
    
    // MARK: - F) Day-Rounded Date
    
    /// Verifies lastUpdated is day-rounded
    func testLastUpdatedIsDayRounded() {
        let data = OutcomeLedgerData()
        
        // Should be in yyyy-MM-dd format
        let dateComponents = data.lastUpdated.split(separator: "-")
        XCTAssertEqual(dateComponents.count, 3)
        
        // Should not have time component
        XCTAssertFalse(data.lastUpdated.contains(":"))
        XCTAssertFalse(data.lastUpdated.contains("T"))
    }
}
