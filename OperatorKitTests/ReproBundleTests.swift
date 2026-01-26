import XCTest
@testable import OperatorKit

// ============================================================================
// REPRO BUNDLE TESTS (Phase 10P)
//
// Tests for repro bundle export:
// - No forbidden keys
// - Soft-fail behavior works
// - Round-trip encode/decode
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class ReproBundleTests: XCTestCase {
    
    // MARK: - A) No Forbidden Keys
    
    /// Verifies bundle contains no forbidden keys
    func testBundleNoForbiddenKeys() async throws {
        let builder = await ReproBundleBuilder()
        let bundle = await builder.build()
        
        let violations = try bundle.validateNoForbiddenKeys()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Bundle contains forbidden keys: \(violations.joined(separator: ", "))"
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
                ReproBundleExport.forbiddenKeys.contains(key),
                "Missing forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - B) Soft-Fail Behavior
    
    /// Verifies builder handles missing sections gracefully
    func testBuilderSoftFail() async {
        let builder = await ReproBundleBuilder()
        let bundle = await builder.build()
        
        // Should have tracked available/unavailable sections
        let totalSections = bundle.availableSections.count + bundle.unavailableSections.count
        XCTAssertGreaterThan(totalSections, 0, "Should track section availability")
        
        // Bundle should be exportable even if some sections are unavailable
        do {
            let data = try bundle.toJSONData()
            XCTAssertGreaterThan(data.count, 0)
        } catch {
            XCTFail("Export should succeed even with unavailable sections: \(error)")
        }
    }
    
    /// Verifies all summary types encode properly
    func testSummaryTypesEncode() throws {
        let diagnosticsSummary = DiagnosticsSummaryExport(
            totalExecutions: 100,
            successCount: 90,
            failureCount: 10,
            approvalRate: 0.95,
            invariantsPassing: true,
            schemaVersion: 1
        )
        
        let qualitySummary = QualitySummaryExport(
            qualityGateStatus: "passing",
            coverageScore: 85,
            trendDirection: "improving",
            invariantsPassing: true,
            lastEvalDayRounded: "2026-01-26",
            schemaVersion: 2
        )
        
        let policySummary = PolicySummaryExport(
            policyEnabled: true,
            allowEmailDrafts: true,
            allowCalendarWrites: true,
            allowTaskCreation: true,
            allowMemoryWrites: false,
            maxExecutionsPerDay: 10,
            requireExplicitConfirmation: true,
            schemaVersion: 1
        )
        
        let pilotSummary = PilotSummaryExport(
            hasTeamTier: false,
            hasActiveTrial: true,
            enterpriseReadinessScore: 75,
            availableSections: 5,
            schemaVersion: 1
        )
        
        // All should encode without error
        let encoder = JSONEncoder()
        _ = try encoder.encode(diagnosticsSummary)
        _ = try encoder.encode(qualitySummary)
        _ = try encoder.encode(policySummary)
        _ = try encoder.encode(pilotSummary)
    }
    
    // MARK: - C) Round-Trip
    
    /// Verifies bundle can be encoded and decoded
    func testRoundTrip() async throws {
        let builder = await ReproBundleBuilder()
        let original = await builder.build()
        
        let jsonData = try original.toJSONData()
        let decoded = try ReproBundleExport.fromJSONData(jsonData)
        
        XCTAssertEqual(original.schemaVersion, decoded.schemaVersion)
        XCTAssertEqual(original.exportedAtDayRounded, decoded.exportedAtDayRounded)
        XCTAssertEqual(original.appVersion, decoded.appVersion)
        XCTAssertEqual(original.availableSections, decoded.availableSections)
        XCTAssertEqual(original.unavailableSections, decoded.unavailableSections)
    }
    
    /// Verifies JSON is valid
    func testJSONIsValid() async throws {
        let builder = await ReproBundleBuilder()
        let bundle = await builder.build()
        
        let jsonData = try bundle.toJSONData()
        
        // Should be valid JSON
        let json = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(json)
        
        // Should be a dictionary
        XCTAssertTrue(json is [String: Any])
    }
    
    // MARK: - D) Metadata
    
    /// Verifies export metadata is present
    func testExportMetadata() async {
        let builder = await ReproBundleBuilder()
        let bundle = await builder.build()
        
        XCTAssertGreaterThan(bundle.schemaVersion, 0)
        XCTAssertFalse(bundle.exportedAtDayRounded.isEmpty)
        XCTAssertFalse(bundle.appVersion.isEmpty)
        XCTAssertFalse(bundle.buildNumber.isEmpty)
        XCTAssertFalse(bundle.releaseMode.isEmpty)
    }
    
    /// Verifies exportedAtDayRounded is day-rounded
    func testExportedAtIsDayRounded() async {
        let builder = await ReproBundleBuilder()
        let bundle = await builder.build()
        
        // Should be in yyyy-MM-dd format
        let dateComponents = bundle.exportedAtDayRounded.split(separator: "-")
        XCTAssertEqual(dateComponents.count, 3)
        
        // Should not have time component
        XCTAssertFalse(bundle.exportedAtDayRounded.contains(":"))
        XCTAssertFalse(bundle.exportedAtDayRounded.contains("T"))
    }
    
    /// Verifies filename is generated correctly
    func testFilename() async {
        let builder = await ReproBundleBuilder()
        let bundle = await builder.build()
        
        XCTAssertTrue(bundle.filename.hasPrefix("OperatorKit_ReproBundle_"))
        XCTAssertTrue(bundle.filename.hasSuffix(".json"))
    }
    
    // MARK: - E) Audit Trail Inclusion
    
    /// Verifies audit trail summary is included
    func testAuditTrailIncluded() async {
        let builder = await ReproBundleBuilder()
        let bundle = await builder.build()
        
        // Audit trail should be included (even if empty)
        if bundle.availableSections.contains("auditTrail") {
            XCTAssertNotNil(bundle.auditTrailSummary)
        }
    }
    
    // MARK: - F) Schema
    
    /// Verifies schema version is set
    func testSchemaVersionIsSet() {
        XCTAssertGreaterThan(ReproBundleExport.currentSchemaVersion, 0)
    }
}
