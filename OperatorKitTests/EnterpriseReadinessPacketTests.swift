import XCTest
@testable import OperatorKit

// ============================================================================
// ENTERPRISE READINESS PACKET TESTS (Phase 10M)
//
// Tests for enterprise readiness export:
// - Packet contains no forbidden keys
// - Packet is metadata-only
// - Builder soft-fails missing sections
// - Export round-trips correctly
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class EnterpriseReadinessPacketTests: XCTestCase {
    
    // MARK: - A) Forbidden Keys
    
    /// Verifies packet contains no forbidden keys
    func testPacketContainsNoForbiddenKeys() async throws {
        let exportPacket = await EnterpriseReadinessExportPacket()
        let violations = try exportPacket.validateNoForbiddenKeys()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Export contains forbidden keys: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies all forbidden keys are checked
    func testForbiddenKeysListIsComplete() {
        let expectedForbidden = [
            "body", "subject", "content", "draft", "prompt",
            "context", "note", "email", "attendees", "title",
            "description", "message", "text", "recipient", "sender"
        ]
        
        for key in expectedForbidden {
            XCTAssertTrue(
                EnterpriseReadinessExportPacket.forbiddenKeys.contains(key),
                "Missing forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - B) Metadata Only
    
    /// Verifies packet is metadata-only (no large strings, no doc bodies)
    func testPacketIsMetadataOnly() async throws {
        let packet = await EnterpriseReadinessBuilder.shared.build()
        let jsonData = try packet.exportJSON()
        
        // Check size is reasonable (< 50KB for metadata)
        XCTAssertLessThan(jsonData.count, 50 * 1024, "Export too large for metadata-only")
        
        // Parse and check no large string values
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Invalid JSON")
            return
        }
        
        checkNoLargeStrings(in: json, maxLength: 1000)
    }
    
    private func checkNoLargeStrings(in dict: [String: Any], maxLength: Int, path: String = "") {
        for (key, value) in dict {
            let fullPath = path.isEmpty ? key : "\(path).\(key)"
            
            if let string = value as? String {
                XCTAssertLessThan(
                    string.count,
                    maxLength,
                    "String too large at \(fullPath): \(string.count) chars"
                )
            }
            
            if let nested = value as? [String: Any] {
                checkNoLargeStrings(in: nested, maxLength: maxLength, path: fullPath)
            }
            
            if let array = value as? [[String: Any]] {
                for (index, item) in array.enumerated() {
                    checkNoLargeStrings(in: item, maxLength: maxLength, path: "\(fullPath)[\(index)]")
                }
            }
        }
    }
    
    // MARK: - C) Soft-Fail Sections
    
    /// Verifies builder soft-fails missing sections
    func testBuilderSoftFailsMissingSections() async {
        let packet = await EnterpriseReadinessBuilder.shared.build()
        
        // Even if sections are unavailable, packet should still be valid
        XCTAssertGreaterThan(packet.schemaVersion, 0)
        XCTAssertFalse(packet.exportedAt.isEmpty)
        XCTAssertFalse(packet.appVersion.isEmpty)
        
        // Readiness should still be calculated
        XCTAssertGreaterThanOrEqual(packet.readinessScore, 0)
        XCTAssertLessThanOrEqual(packet.readinessScore, 100)
    }
    
    /// Verifies optional sections are handled gracefully
    func testOptionalSectionsHandledGracefully() async {
        let packet = await EnterpriseReadinessBuilder.shared.build()
        
        // All optional sections should be safely optional
        // If nil, that's fine; if present, should be valid
        if let safety = packet.safetyContractStatus {
            XCTAssertFalse(safety.status.isEmpty)
        }
        
        if let docs = packet.docIntegritySummary {
            XCTAssertGreaterThanOrEqual(docs.requiredDocsCount, 0)
        }
        
        if let quality = packet.qualitySummary {
            XCTAssertFalse(quality.gateStatus.isEmpty)
        }
    }
    
    // MARK: - D) Export Round-Trip
    
    /// Verifies export round-trips correctly
    func testExportRoundTrip() async throws {
        let original = await EnterpriseReadinessExportPacket()
        let jsonData = try original.toJSONData()
        
        // Round-trip
        let restored = try EnterpriseReadinessExportPacket.fromJSONData(jsonData)
        
        // Verify key fields match
        XCTAssertEqual(original.packet.schemaVersion, restored.packet.schemaVersion)
        XCTAssertEqual(original.packet.exportedAt, restored.packet.exportedAt)
        XCTAssertEqual(original.packet.appVersion, restored.packet.appVersion)
        XCTAssertEqual(original.packet.readinessScore, restored.packet.readinessScore)
        XCTAssertEqual(original.packet.readinessStatus, restored.packet.readinessStatus)
    }
    
    /// Verifies JSON is valid and well-formed
    func testExportJSONIsValid() async throws {
        let exportPacket = await EnterpriseReadinessExportPacket()
        let jsonData = try exportPacket.toJSONData()
        
        XCTAssertGreaterThan(jsonData.count, 0)
        
        // Verify valid JSON
        let json = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(json as? [String: Any])
    }
    
    // MARK: - E) Schema
    
    /// Verifies schema version is set
    func testSchemaVersionIsSet() async {
        let packet = await EnterpriseReadinessBuilder.shared.build()
        XCTAssertGreaterThan(packet.schemaVersion, 0)
    }
    
    /// Verifies export filename format
    func testExportFilenameFormat() async {
        let packet = await EnterpriseReadinessBuilder.shared.build()
        
        XCTAssertTrue(packet.exportFilename.hasPrefix("OperatorKit_EnterpriseReadiness_"))
        XCTAssertTrue(packet.exportFilename.hasSuffix(".json"))
    }
}
