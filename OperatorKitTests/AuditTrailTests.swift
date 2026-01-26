import XCTest
@testable import OperatorKit

// ============================================================================
// CUSTOMER AUDIT TRAIL TESTS (Phase 10P)
//
// Tests for customer audit trail:
// - No forbidden keys
// - Ring buffer cap enforced
// - Day-rounded formatting valid
// - Events encode/decode round-trip
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class AuditTrailTests: XCTestCase {
    
    // MARK: - A) No Forbidden Keys
    
    /// Verifies events contain no forbidden keys
    func testEventNoForbiddenKeys() throws {
        let event = CustomerAuditEvent(
            kind: .executionSucceeded,
            intentType: "email_draft",
            outputType: "draft",
            result: .success,
            backendUsed: "apple_on_device",
            tierAtTime: "pro"
        )
        
        let violations = try event.validateNoForbiddenKeys()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Event contains forbidden keys: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies forbidden keys list is complete
    func testForbiddenKeysListIsComplete() {
        let expectedForbidden = [
            "body", "subject", "content", "draft", "prompt",
            "context", "note", "email", "attendees", "title",
            "description", "message", "text", "recipient", "sender"
        ]
        
        for key in expectedForbidden {
            XCTAssertTrue(
                CustomerAuditEvent.forbiddenKeys.contains(key),
                "Missing forbidden key: \(key)"
            )
        }
    }
    
    /// Verifies summary contains no forbidden keys
    func testSummaryNoForbiddenKeys() throws {
        let event = CustomerAuditEvent(
            kind: .executionSucceeded,
            intentType: "email_draft",
            outputType: "draft",
            result: .success,
            backendUsed: "apple_on_device",
            tierAtTime: "pro"
        )
        
        let summary = CustomerAuditTrailSummary(
            totalEvents: 1,
            eventsLast7Days: 1,
            countByKind: ["execution_succeeded": 1],
            countByResult: ["success": 1],
            successRate: 1.0,
            recentEvents: [event],
            schemaVersion: 1,
            capturedAt: "2026-01-26"
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(summary)
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Failed to encode summary")
            return
        }
        
        let forbiddenKeys = CustomerAuditEvent.forbiddenKeys
        
        func checkKeys(in dict: [String: Any], path: String) {
            for (key, value) in dict {
                XCTAssertFalse(
                    forbiddenKeys.contains(key.lowercased()),
                    "Summary contains forbidden key at \(path).\(key)"
                )
                
                if let nested = value as? [String: Any] {
                    checkKeys(in: nested, path: "\(path).\(key)")
                }
            }
        }
        
        checkKeys(in: json, path: "")
    }
    
    // MARK: - B) Ring Buffer Cap
    
    /// Verifies ring buffer enforces max events
    func testRingBufferCapEnforced() async {
        let store = await CustomerAuditTrailStore.shared
        await store.reset()
        
        // Record more than max events
        let maxEvents = CustomerAuditTrailStore.maxEvents
        for i in 0...(maxEvents + 10) {
            await store.record(
                kind: .executionSucceeded,
                intentType: "test",
                outputType: "test_\(i)",
                result: .success,
                backendUsed: "test",
                tierAtTime: "free"
            )
        }
        
        let count = await store.events.count
        XCTAssertLessThanOrEqual(
            count,
            maxEvents,
            "Ring buffer should enforce max \(maxEvents) events"
        )
        
        await store.reset()
    }
    
    /// Verifies oldest events are removed first
    func testRingBufferRemovesOldestFirst() async {
        let store = await CustomerAuditTrailStore.shared
        await store.reset()
        
        // Record 3 events
        for i in 1...3 {
            await store.record(
                kind: .executionSucceeded,
                intentType: "test",
                outputType: "output_\(i)",
                result: .success,
                backendUsed: "test",
                tierAtTime: "free"
            )
        }
        
        let events = await store.events
        XCTAssertEqual(events.count, 3)
        
        // Verify ordering (most recent should be last)
        XCTAssertEqual(events.last?.outputType, "output_3")
        
        await store.reset()
    }
    
    // MARK: - C) Day-Rounded Formatting
    
    /// Verifies createdAtDayRounded is valid format
    func testDayRoundedFormatting() {
        let event = CustomerAuditEvent(
            kind: .intentSubmitted,
            intentType: "email",
            outputType: "draft",
            result: .pending,
            backendUsed: "apple",
            tierAtTime: "free"
        )
        
        // Should be yyyy-MM-dd format
        let dateComponents = event.createdAtDayRounded.split(separator: "-")
        XCTAssertEqual(dateComponents.count, 3, "Should have year-month-day")
        
        // Should not have time component
        XCTAssertFalse(event.createdAtDayRounded.contains(":"))
        XCTAssertFalse(event.createdAtDayRounded.contains("T"))
        
        // Year should be 4 digits
        XCTAssertEqual(dateComponents[0].count, 4)
        
        // Month and day should be 2 digits
        XCTAssertEqual(dateComponents[1].count, 2)
        XCTAssertEqual(dateComponents[2].count, 2)
    }
    
    /// Verifies no raw timestamps in events
    func testNoRawTimestamps() throws {
        let event = CustomerAuditEvent(
            kind: .executionSucceeded,
            intentType: "test",
            outputType: "test",
            result: .success,
            backendUsed: "test",
            tierAtTime: "free"
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(event)
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Failed to encode event")
            return
        }
        
        // Should not have raw timestamp keys
        XCTAssertNil(json["rawTimestamp"])
        XCTAssertNil(json["createdAt"])  // Only day-rounded is allowed
        XCTAssertNotNil(json["createdAtDayRounded"])
    }
    
    // MARK: - D) Round-Trip Encode/Decode
    
    /// Verifies events can be encoded and decoded
    func testEventRoundTrip() throws {
        let original = CustomerAuditEvent(
            kind: .executionSucceeded,
            intentType: "email_draft",
            outputType: "draft",
            result: .success,
            failureCategory: nil,
            backendUsed: "apple_on_device",
            policyDecision: .allowed,
            tierAtTime: "pro"
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(CustomerAuditEvent.self, from: encoded)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.kind, decoded.kind)
        XCTAssertEqual(original.intentType, decoded.intentType)
        XCTAssertEqual(original.outputType, decoded.outputType)
        XCTAssertEqual(original.result, decoded.result)
        XCTAssertEqual(original.backendUsed, decoded.backendUsed)
        XCTAssertEqual(original.tierAtTime, decoded.tierAtTime)
    }
    
    /// Verifies summary can be encoded and decoded
    func testSummaryRoundTrip() throws {
        let event = CustomerAuditEvent(
            kind: .executionSucceeded,
            intentType: "test",
            outputType: "test",
            result: .success,
            backendUsed: "test",
            tierAtTime: "free"
        )
        
        let original = CustomerAuditTrailSummary(
            totalEvents: 100,
            eventsLast7Days: 50,
            countByKind: ["execution_succeeded": 80, "execution_failed": 20],
            countByResult: ["success": 80, "failure": 20],
            successRate: 0.8,
            recentEvents: [event],
            schemaVersion: 1,
            capturedAt: "2026-01-26"
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(CustomerAuditTrailSummary.self, from: encoded)
        
        XCTAssertEqual(original.totalEvents, decoded.totalEvents)
        XCTAssertEqual(original.eventsLast7Days, decoded.eventsLast7Days)
        XCTAssertEqual(original.successRate, decoded.successRate)
        XCTAssertEqual(original.recentEvents.count, decoded.recentEvents.count)
    }
    
    // MARK: - E) Event Kinds and Results
    
    /// Verifies all event kinds are defined
    func testAllEventKindsDefined() {
        let allKinds = CustomerAuditEventKind.allCases
        
        XCTAssertGreaterThan(allKinds.count, 5, "Should have multiple event kinds")
        
        for kind in allKinds {
            XCTAssertFalse(kind.displayName.isEmpty)
            XCTAssertFalse(kind.icon.isEmpty)
        }
    }
    
    // MARK: - F) Schema
    
    /// Verifies schema version is set
    func testSchemaVersionIsSet() {
        XCTAssertGreaterThan(CustomerAuditEvent.currentSchemaVersion, 0)
        XCTAssertGreaterThan(CustomerAuditTrailSummary.currentSchemaVersion, 0)
    }
}
