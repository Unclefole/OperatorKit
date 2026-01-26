import XCTest
@testable import OperatorKit

// ============================================================================
// PILOT SHARE PACK TESTS (Phase 10O)
//
// Tests for pilot share pack:
// - No forbidden keys
// - Round-trip encode/decode
// - Builder soft-fail works
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class PilotSharePackTests: XCTestCase {
    
    // MARK: - A) No Forbidden Keys
    
    /// Verifies pack contains no forbidden keys
    func testPackNoForbiddenKeys() async throws {
        let builder = await PilotSharePackBuilder()
        let pack = await builder.build()
        
        let violations = try pack.validateNoForbiddenKeys()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Pack contains forbidden keys: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies forbidden keys list is complete
    func testForbiddenKeysListIsComplete() {
        let expectedForbidden = [
            "body", "subject", "content", "draft", "prompt",
            "context", "note", "email", "attendees", "title",
            "description", "message", "text", "recipient", "sender",
            "userId", "deviceId"
        ]
        
        for key in expectedForbidden {
            XCTAssertTrue(
                PilotSharePack.forbiddenKeys.contains(key),
                "Missing forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - B) Round-trip
    
    /// Verifies pack can be encoded and decoded
    func testRoundTrip() async throws {
        let builder = await PilotSharePackBuilder()
        let original = await builder.build()
        
        let jsonData = try original.toJSONData()
        let decoded = try PilotSharePack.fromJSONData(jsonData)
        
        XCTAssertEqual(original.schemaVersion, decoded.schemaVersion)
        XCTAssertEqual(original.exportedAt, decoded.exportedAt)
        XCTAssertEqual(original.appVersion, decoded.appVersion)
        XCTAssertEqual(original.availableSections, decoded.availableSections)
        XCTAssertEqual(original.unavailableSections, decoded.unavailableSections)
    }
    
    /// Verifies JSON is valid
    func testJSONIsValid() async throws {
        let builder = await PilotSharePackBuilder()
        let pack = await builder.build()
        
        let jsonData = try pack.toJSONData()
        
        // Should be valid JSON
        let json = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(json)
        
        // Should be a dictionary
        XCTAssertTrue(json is [String: Any])
    }
    
    // MARK: - C) Builder Soft-Fail
    
    /// Verifies builder handles missing sections gracefully
    func testBuilderSoftFail() async {
        let builder = await PilotSharePackBuilder()
        let pack = await builder.build()
        
        // Should have tracked available/unavailable sections
        let totalSections = pack.availableSections.count + pack.unavailableSections.count
        XCTAssertGreaterThan(totalSections, 0, "Should track section availability")
        
        // Pack should be exportable even if some sections are unavailable
        do {
            let data = try pack.toJSONData()
            XCTAssertGreaterThan(data.count, 0)
        } catch {
            XCTFail("Export should succeed even with unavailable sections: \(error)")
        }
    }
    
    /// Verifies all summary types encode properly
    func testSummaryTypesEncode() throws {
        let enterpriseSummary = EnterpriseReadinessSummary(
            readinessStatus: "ready",
            readinessScore: 85,
            safetyContractMatch: true,
            docIntegrityPassing: true,
            sectionsAvailable: 6,
            schemaVersion: 1
        )
        
        let qualitySummary = QualityPacketSummary(
            qualityGateStatus: "passing",
            coverageScore: 80,
            trendDirection: "improving",
            invariantsPassing: true,
            schemaVersion: 2
        )
        
        let diagnosticsSummary = DiagnosticsPacketSummary(
            totalExecutions: 100,
            approvalRate: 0.95,
            invariantsPassing: true,
            schemaVersion: 1
        )
        
        let policySummary = PolicyPacketSummary(
            allowEmailDrafts: true,
            allowCalendarWrites: true,
            allowTaskCreation: true,
            allowMemoryWrites: false,
            schemaVersion: 1
        )
        
        let teamSummary = TeamPacketSummary(
            hasTeamTier: false,
            hasActiveTrial: true,
            teamMembersCount: nil,
            policyTemplatesCount: 4,
            schemaVersion: 1
        )
        
        let conversionSummary = ConversionPacketSummary(
            pricingVariant: "variant-a",
            totalPurchases: 5,
            satisfactionAverage: 4.2,
            templatesUsed: 10,
            schemaVersion: 3
        )
        
        // All should encode without error
        let encoder = JSONEncoder()
        _ = try encoder.encode(enterpriseSummary)
        _ = try encoder.encode(qualitySummary)
        _ = try encoder.encode(diagnosticsSummary)
        _ = try encoder.encode(policySummary)
        _ = try encoder.encode(teamSummary)
        _ = try encoder.encode(conversionSummary)
    }
    
    // MARK: - D) Metadata
    
    /// Verifies export metadata is present
    func testExportMetadata() async {
        let builder = await PilotSharePackBuilder()
        let pack = await builder.build()
        
        XCTAssertGreaterThan(pack.schemaVersion, 0)
        XCTAssertFalse(pack.exportedAt.isEmpty)
        XCTAssertFalse(pack.appVersion.isEmpty)
        XCTAssertFalse(pack.buildNumber.isEmpty)
        XCTAssertFalse(pack.releaseMode.isEmpty)
    }
    
    /// Verifies exportedAt is day-rounded
    func testExportedAtIsDayRounded() async {
        let builder = await PilotSharePackBuilder()
        let pack = await builder.build()
        
        // Should be in yyyy-MM-dd format
        let dateComponents = pack.exportedAt.split(separator: "-")
        XCTAssertEqual(dateComponents.count, 3)
        
        // Should not have time component
        XCTAssertFalse(pack.exportedAt.contains(":"))
        XCTAssertFalse(pack.exportedAt.contains("T"))
    }
    
    /// Verifies filename is generated correctly
    func testFilename() async {
        let builder = await PilotSharePackBuilder()
        let pack = await builder.build()
        
        XCTAssertTrue(pack.filename.hasPrefix("OperatorKit_PilotSharePack_"))
        XCTAssertTrue(pack.filename.hasSuffix(".json"))
    }
    
    // MARK: - E) Schema
    
    /// Verifies schema version is set
    func testSchemaVersionIsSet() {
        XCTAssertGreaterThan(PilotSharePack.currentSchemaVersion, 0)
    }
}
