import XCTest
@testable import OperatorKit

/// Tests for quality packet export (Phase 9B)
/// Ensures export is content-free and dates are day-rounded
final class ExportQualityPacketTests: XCTestCase {
    
    // MARK: - Forbidden Keys Tests
    
    /// List of keys that must NEVER appear in exports
    private let forbiddenKeys = [
        "emailBody",
        "draftContent",
        "eventTitle",
        "participants",
        "userInput",
        "promptText",
        "contextPayload",
        "subject",
        "body",
        "messageText",
        "content",
        "draftText",
        "userEmail",
        "recipientEmail",
        "attendees",
        "description",  // Event description
        "notes",        // User notes (except structured recommendation notes)
    ]
    
    func testExportDoesNotContainForbiddenKeys() throws {
        let exporter = QualityPacketExporter()
        let json = try exporter.exportJSON()
        let jsonString = String(data: json, encoding: .utf8) ?? ""
        
        for key in forbiddenKeys {
            // Check for exact key matches (as JSON keys)
            let keyPattern = "\"\(key)\""
            XCTAssertFalse(
                jsonString.contains(keyPattern),
                "Export should NOT contain forbidden key: \(key)"
            )
        }
    }
    
    func testExportSchemaVersion() {
        let exporter = QualityPacketExporter()
        let packet = exporter.createPacket()
        
        XCTAssertGreaterThan(packet.schemaVersion, 0)
        XCTAssertEqual(packet.schemaVersion, ExportQualityPacket.currentSchemaVersion)
    }
    
    // MARK: - Day-Rounded Dates Tests
    
    func testDatesAreDayRounded() throws {
        let exporter = QualityPacketExporter()
        let packet = exporter.createPacket()
        
        // exportedAtDayRounded should be in yyyy-MM-dd format
        let dayRoundedRegex = try NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}$")
        let range = NSRange(packet.exportedAtDayRounded.startIndex..., in: packet.exportedAtDayRounded)
        XCTAssertNotNil(
            dayRoundedRegex.firstMatch(in: packet.exportedAtDayRounded, range: range),
            "exportedAtDayRounded should be in yyyy-MM-dd format"
        )
        
        // If acknowledgement exists, its date should also be day-rounded
        if let ack = packet.lastAcknowledgement {
            let ackRange = NSRange(ack.acknowledgedAtDayRounded.startIndex..., in: ack.acknowledgedAtDayRounded)
            XCTAssertNotNil(
                dayRoundedRegex.firstMatch(in: ack.acknowledgedAtDayRounded, range: ackRange),
                "acknowledgedAtDayRounded should be in yyyy-MM-dd format"
            )
        }
    }
    
    // MARK: - Content Validation Tests
    
    func testPacketContainsExpectedSections() {
        let exporter = QualityPacketExporter()
        let packet = exporter.createPacket()
        
        // Should have all required sections
        XCTAssertFalse(packet.appVersion.isEmpty)
        XCTAssertFalse(packet.buildNumber.isEmpty)
        XCTAssertFalse(packet.releaseMode.isEmpty)
        
        // Safety contract
        XCTAssertFalse(packet.safetyContractStatus.currentHash.isEmpty)
        
        // Quality gate
        XCTAssertFalse(packet.qualityGateResult.status.isEmpty)
        
        // Coverage
        XCTAssertGreaterThanOrEqual(packet.coverageScore, 0)
        XCTAssertLessThanOrEqual(packet.coverageScore, 100)
        XCTAssertFalse(packet.coverageDimensions.isEmpty)
        
        // Trend
        XCTAssertFalse(packet.trend.passRateDirection.isEmpty)
        
        // Prompt scaffold
        XCTAssertGreaterThan(packet.promptScaffoldMetadata.schemaVersion, 0)
    }
    
    func testCoverageDimensionsAreValid() {
        let exporter = QualityPacketExporter()
        let packet = exporter.createPacket()
        
        for dimension in packet.coverageDimensions {
            XCTAssertFalse(dimension.name.isEmpty)
            XCTAssertGreaterThanOrEqual(dimension.coveragePercent, 0)
            XCTAssertLessThanOrEqual(dimension.coveragePercent, 100)
            XCTAssertGreaterThanOrEqual(dimension.coveredCount, 0)
            XCTAssertGreaterThanOrEqual(dimension.totalCount, dimension.coveredCount)
        }
    }
    
    func testRecommendationsAreMetadataOnly() {
        let exporter = QualityPacketExporter()
        let packet = exporter.createPacket()
        
        for rec in packet.recommendations {
            // Should only have severity, title, category
            XCTAssertFalse(rec.severity.isEmpty)
            XCTAssertFalse(rec.title.isEmpty)
            XCTAssertFalse(rec.category.isEmpty)
            
            // Title should not contain user content
            XCTAssertFalse(rec.title.contains("your"))
            XCTAssertFalse(rec.title.contains("specific"))
        }
    }
    
    // MARK: - JSON Validity Tests
    
    func testExportIsValidJSON() throws {
        let exporter = QualityPacketExporter()
        let json = try exporter.exportJSON()
        
        // Should be valid JSON
        let decoded = try JSONDecoder().decode(ExportQualityPacket.self, from: json)
        XCTAssertNotNil(decoded)
    }
    
    func testExportIsRoundTrippable() throws {
        let exporter = QualityPacketExporter()
        let packet = exporter.createPacket()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(packet)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportQualityPacket.self, from: json)
        
        XCTAssertEqual(decoded.schemaVersion, packet.schemaVersion)
        XCTAssertEqual(decoded.appVersion, packet.appVersion)
        XCTAssertEqual(decoded.coverageScore, packet.coverageScore)
    }
}
