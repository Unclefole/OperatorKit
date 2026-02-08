import XCTest
@testable import OperatorKit

// ============================================================================
// AUDIT TRAIL STORE ATOMIC WRITE TESTS (Hardening Phase)
//
// Tests crash-safe persistence:
// - Atomic write verification
// - Backup recovery on corruption
// - Checksum tamper detection
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

final class AuditTrailStoreAtomicWriteTests: XCTestCase {

    private var testDirectory: URL!
    private var mainFileURL: URL!
    private var backupFileURL: URL!
    private var checksumFileURL: URL!

    override func setUpWithError() throws {
        // Create isolated test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AuditTrailTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )

        mainFileURL = testDirectory.appendingPathComponent("audit_trail.json")
        backupFileURL = testDirectory.appendingPathComponent("audit_trail.json.backup")
        checksumFileURL = testDirectory.appendingPathComponent("audit_trail.checksum")
    }

    override func tearDownWithError() throws {
        // Clean up test directory
        try? FileManager.default.removeItem(at: testDirectory)
    }

    // MARK: - A) Backup Recovery on Corruption

    /// Verifies that corrupted main file triggers recovery from backup
    func testRecoveryFromBackupOnCorruption() throws {
        // 1. Create valid backup data
        let validEvents = [
            createTestEvent(outputType: "backup_event_1"),
            createTestEvent(outputType: "backup_event_2")
        ]
        let validData = try JSONEncoder().encode(validEvents)

        // Write valid backup
        try validData.write(to: backupFileURL)

        // 2. Write corrupted main file (invalid JSON)
        let corruptedData = "{ invalid json [[[ }}}".data(using: .utf8)!
        try corruptedData.write(to: mainFileURL)

        // 3. Attempt read with recovery
        let result = AtomicFileWriter.readWithRecovery(
            from: mainFileURL,
            backupURL: backupFileURL,
            checksumURL: nil
        )

        // 4. Verify recovery succeeded
        XCTAssertNotNil(result, "Should recover from backup")
        XCTAssertTrue(result!.wasRecovered, "Should indicate recovery occurred")

        // 5. Verify data is valid
        let recoveredEvents = try JSONDecoder().decode([CustomerAuditEvent].self, from: result!.data)
        XCTAssertEqual(recoveredEvents.count, 2, "Should have 2 events from backup")
        XCTAssertEqual(recoveredEvents[0].outputType, "backup_event_1")
        XCTAssertEqual(recoveredEvents[1].outputType, "backup_event_2")
    }

    // MARK: - B) Checksum Tamper Detection

    /// Verifies checksum mismatch triggers backup recovery
    func testChecksumMismatchTriggersRecovery() throws {
        // 1. Create main file with tampered checksum
        let mainEvents = [createTestEvent(outputType: "tampered_main")]
        let mainData = try JSONEncoder().encode(mainEvents)
        try mainData.write(to: mainFileURL)

        // Write wrong checksum
        let wrongChecksum = "0000000000000000000000000000000000000000000000000000000000000000"
        try wrongChecksum.write(to: checksumFileURL, atomically: true, encoding: .utf8)

        // 2. Create valid backup
        let backupEvents = [createTestEvent(outputType: "valid_backup")]
        let backupData = try JSONEncoder().encode(backupEvents)
        try backupData.write(to: backupFileURL)

        // 3. Attempt read with recovery
        let result = AtomicFileWriter.readWithRecovery(
            from: mainFileURL,
            backupURL: backupFileURL,
            checksumURL: checksumFileURL
        )

        // 4. Verify recovery from backup due to checksum mismatch
        XCTAssertNotNil(result, "Should recover from backup")
        XCTAssertTrue(result!.wasRecovered, "Should indicate recovery occurred")

        let recoveredEvents = try JSONDecoder().decode([CustomerAuditEvent].self, from: result!.data)
        XCTAssertEqual(recoveredEvents[0].outputType, "valid_backup")
    }

    // MARK: - C) Atomic Write Verification

    /// Verifies atomic write creates all expected files
    func testAtomicWriteCreatesAllFiles() throws {
        let events = [
            createTestEvent(outputType: "atomic_test_1"),
            createTestEvent(outputType: "atomic_test_2"),
            createTestEvent(outputType: "atomic_test_3")
        ]
        let data = try JSONEncoder().encode(events)

        // Perform atomic write
        let success = AtomicFileWriter.writeAtomically(
            data: data,
            to: mainFileURL,
            backupURL: backupFileURL,
            checksumURL: checksumFileURL
        )

        XCTAssertTrue(success, "Atomic write should succeed")

        // Verify main file exists and is valid
        XCTAssertTrue(FileManager.default.fileExists(atPath: mainFileURL.path))
        let readData = try Data(contentsOf: mainFileURL)
        let readEvents = try JSONDecoder().decode([CustomerAuditEvent].self, from: readData)
        XCTAssertEqual(readEvents.count, 3)

        // Verify checksum file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: checksumFileURL.path))
        let storedChecksum = try String(contentsOf: checksumFileURL, encoding: .utf8)
        let expectedChecksum = AtomicFileWriter.computeChecksum(data)
        XCTAssertEqual(storedChecksum, expectedChecksum)
    }

    // MARK: - D) Backup Created on Overwrite

    /// Verifies backup is created when overwriting existing file
    func testBackupCreatedOnOverwrite() throws {
        // 1. Write initial data
        let initialEvents = [createTestEvent(outputType: "initial")]
        let initialData = try JSONEncoder().encode(initialEvents)
        let _ = AtomicFileWriter.writeAtomically(
            data: initialData,
            to: mainFileURL,
            backupURL: backupFileURL,
            checksumURL: checksumFileURL
        )

        // 2. Overwrite with new data
        let newEvents = [createTestEvent(outputType: "updated")]
        let newData = try JSONEncoder().encode(newEvents)
        let success = AtomicFileWriter.writeAtomically(
            data: newData,
            to: mainFileURL,
            backupURL: backupFileURL,
            checksumURL: checksumFileURL
        )

        XCTAssertTrue(success)

        // 3. Verify backup contains old data
        let backupData = try Data(contentsOf: backupFileURL)
        let backupEvents = try JSONDecoder().decode([CustomerAuditEvent].self, from: backupData)
        XCTAssertEqual(backupEvents[0].outputType, "initial")

        // 4. Verify main contains new data
        let mainData = try Data(contentsOf: mainFileURL)
        let mainEvents = try JSONDecoder().decode([CustomerAuditEvent].self, from: mainData)
        XCTAssertEqual(mainEvents[0].outputType, "updated")
    }

    // MARK: - E) No Backup No Main Returns Nil

    /// Verifies nil returned when neither main nor backup exist
    func testNoFilesReturnsNil() {
        let result = AtomicFileWriter.readWithRecovery(
            from: mainFileURL,
            backupURL: backupFileURL,
            checksumURL: checksumFileURL
        )

        XCTAssertNil(result, "Should return nil when no files exist")
    }

    // MARK: - F) Valid Main With Matching Checksum

    /// Verifies valid main file with correct checksum loads directly
    func testValidMainWithChecksumLoadsDirectly() throws {
        let events = [createTestEvent(outputType: "valid_main")]
        let data = try JSONEncoder().encode(events)

        // Write main and checksum
        try data.write(to: mainFileURL)
        let checksum = AtomicFileWriter.computeChecksum(data)
        try checksum.write(to: checksumFileURL, atomically: true, encoding: .utf8)

        // Also write backup with different data
        let backupEvents = [createTestEvent(outputType: "should_not_load")]
        let backupData = try JSONEncoder().encode(backupEvents)
        try backupData.write(to: backupFileURL)

        // Read should load main, not backup
        let result = AtomicFileWriter.readWithRecovery(
            from: mainFileURL,
            backupURL: backupFileURL,
            checksumURL: checksumFileURL
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result!.wasRecovered, "Should not indicate recovery")

        let loadedEvents = try JSONDecoder().decode([CustomerAuditEvent].self, from: result!.data)
        XCTAssertEqual(loadedEvents[0].outputType, "valid_main")
    }

    // MARK: - Helper

    private func createTestEvent(outputType: String) -> CustomerAuditEvent {
        CustomerAuditEvent(
            kind: .executionSucceeded,
            intentType: "test",
            outputType: outputType,
            result: .success,
            backendUsed: "test",
            tierAtTime: "free"
        )
    }
}
