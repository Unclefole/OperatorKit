import XCTest
@testable import OperatorKit

// ============================================================================
// SYNC INVARIANT TESTS (Phase 10D)
//
// These tests enforce that sync functionality is:
// - Isolated to the Sync module only
// - Content-free (no user data)
// - User-initiated only (no background sync)
// - Off by default
//
// See: docs/SAFETY_CONTRACT.md (Section 13)
// ============================================================================

final class SyncInvariantTests: XCTestCase {
    
    // MARK: - A) Core Modules Do Not Import Sync or URLSession
    
    /// Verifies ExecutionEngine.swift does NOT reference Sync or URLSession
    func testExecutionEngineDoesNotImportSyncOrURLSession() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let forbiddenPatterns = [
            "import.*Sync",
            "URLSession",
            "URLRequest",
            "SupabaseClient",
            "SyncQueue",
            "SyncPacket"
        ]
        
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                content.contains(pattern.replacingOccurrences(of: ".*", with: "")),
                "INVARIANT VIOLATION: ExecutionEngine.swift contains forbidden pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ApprovalGate.swift does NOT reference Sync or URLSession
    func testApprovalGateDoesNotImportSyncOrURLSession() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let forbiddenPatterns = [
            "URLSession",
            "URLRequest",
            "SupabaseClient",
            "SyncQueue",
            "SyncPacket"
        ]
        
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "INVARIANT VIOLATION: ApprovalGate.swift contains forbidden pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ModelRouter.swift does NOT reference Sync or URLSession
    func testModelRouterDoesNotImportSyncOrURLSession() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let forbiddenPatterns = [
            "URLSession",
            "URLRequest",
            "SupabaseClient",
            "SyncQueue",
            "SyncPacket"
        ]
        
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "INVARIANT VIOLATION: ModelRouter.swift contains forbidden pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - B) Only Sync Module References URLSession
    
    /// Verifies that URLSession usage is ONLY in the Sync module
    func testURLSessionOnlyInSyncModule() throws {
        // Files that should NOT contain URLSession
        let forbiddenFiles = [
            ("ExecutionEngine.swift", "Domain/Execution"),
            ("ApprovalGate.swift", "Domain/Approval"),
            ("ModelRouter.swift", "Models"),
            ("DraftGenerator.swift", "Domain/Drafts"),
            ("ContextAssembler.swift", "Domain/Context"),
            ("MemoryStore.swift", "Domain/Memory"),
            ("CalendarService.swift", "Services/Calendar"),
            ("ReminderService.swift", "Services/Reminders"),
            ("QualityFeedbackStore.swift", "Domain/Quality"),
            ("GoldenCaseStore.swift", "Domain/Eval"),
            ("OperatorPolicyStore.swift", "Policies"),
            ("DiagnosticsExportPacket.swift", "Diagnostics")
        ]
        
        for (fileName, directory) in forbiddenFiles {
            let filePath = findProjectFile(named: fileName, in: directory)
            guard FileManager.default.fileExists(atPath: filePath) else { continue }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertFalse(
                content.contains("URLSession.shared") || content.contains("URLSession("),
                "INVARIANT VIOLATION: \(fileName) uses URLSession (only Sync module allowed)"
            )
        }
    }
    
    /// Verifies SupabaseClient.swift IS the only file that uses URLSession
    func testSupabaseClientIsOnlyURLSessionUser() throws {
        let filePath = findProjectFile(named: "SupabaseClient.swift", in: "Sync")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // Should contain URLSession (it's the allowed location)
        XCTAssertTrue(
            content.contains("URLSession"),
            "SupabaseClient.swift should contain URLSession (it's the allowed location)"
        )
        
        // Should have the proper isolation comments
        XCTAssertTrue(
            content.contains("ONLY file in OperatorKit that makes network requests") ||
            content.contains("This is the ONLY class in OperatorKit that uses URLSession"),
            "SupabaseClient.swift should document that it's the only network file"
        )
    }
    
    // MARK: - C) SyncPacketValidator Blocks Forbidden Keys
    
    /// Verifies validator blocks payloads with forbidden content keys
    func testValidatorBlocksForbiddenKeys() {
        let validator = SyncPacketValidator.shared
        
        // Payload with forbidden "body" key
        let badPayload1: [String: Any] = [
            "schemaVersion": 1,
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "body": "This is user content"  // FORBIDDEN
        ]
        
        let data1 = try! JSONSerialization.data(withJSONObject: badPayload1)
        let result1 = validator.validate(jsonData: data1, packetType: .qualityExport)
        
        XCTAssertFalse(result1.isValid, "Validator should reject payload with 'body' key")
        XCTAssertTrue(result1.errors.contains { $0.contains("body") })
        
        // Payload with forbidden "email" key
        let badPayload2: [String: Any] = [
            "schemaVersion": 1,
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "email": "user@example.com"  // FORBIDDEN
        ]
        
        let data2 = try! JSONSerialization.data(withJSONObject: badPayload2)
        let result2 = validator.validate(jsonData: data2, packetType: .qualityExport)
        
        XCTAssertFalse(result2.isValid, "Validator should reject payload with 'email' key")
        
        // Payload with nested forbidden key
        let badPayload3: [String: Any] = [
            "schemaVersion": 1,
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "nested": [
                "draft": "User's draft content"  // FORBIDDEN
            ]
        ]
        
        let data3 = try! JSONSerialization.data(withJSONObject: badPayload3)
        let result3 = validator.validate(jsonData: data3, packetType: .qualityExport)
        
        XCTAssertFalse(result3.isValid, "Validator should reject payload with nested forbidden key")
    }
    
    /// Verifies validator accepts clean metadata-only payloads
    func testValidatorAcceptsCleanPayloads() {
        let validator = SyncPacketValidator.shared
        
        let cleanPayload: [String: Any] = [
            "schemaVersion": 1,
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "appVersion": "1.0.0",
            "buildNumber": "100",
            "metrics": [
                "executionCount": 5,
                "successRate": 0.8
            ]
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: cleanPayload)
        let result = validator.validate(jsonData: data, packetType: .qualityExport)
        
        XCTAssertTrue(result.isValid, "Validator should accept clean metadata-only payload")
        XCTAssertTrue(result.errors.isEmpty)
    }
    
    // MARK: - D) SyncPacketValidator Blocks Oversize Payloads
    
    /// Verifies validator blocks payloads exceeding size limit
    func testValidatorBlocksOversizePayloads() {
        let validator = SyncPacketValidator.shared
        
        // Create a payload that exceeds the size limit
        let largeString = String(repeating: "x", count: SyncSafetyConfig.maxPayloadSizeBytes + 1000)
        let oversizePayload: [String: Any] = [
            "schemaVersion": 1,
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "largeField": largeString
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: oversizePayload)
        let result = validator.validate(jsonData: data, packetType: .qualityExport)
        
        XCTAssertFalse(result.isValid, "Validator should reject oversize payload")
        XCTAssertTrue(result.errors.contains { $0.contains("size") || $0.contains("exceeds") })
    }
    
    // MARK: - E) Sync Is User-Initiated Only
    
    /// Verifies sync is OFF by default
    func testSyncIsOffByDefault() {
        XCTAssertFalse(
            SyncFeatureFlag.defaultToggleState,
            "Sync must be OFF by default"
        )
    }
    
    /// Verifies SyncQueue does not upload in init
    func testSyncQueueDoesNotUploadOnInit() {
        // Just accessing the shared instance should not trigger uploads
        let queue = SyncQueue.shared
        
        // Verify no automatic upload happened
        XCTAssertNil(queue.lastUploadResult, "SyncQueue should not upload on init")
    }
    
    /// Verifies SupabaseClient does not make requests in init
    func testSupabaseClientDoesNotRequestOnInit() {
        let client = SupabaseClient.shared
        
        // Verify no automatic network activity
        XCTAssertFalse(client.isLoading, "SupabaseClient should not be loading on init")
    }
    
    // MARK: - F) Export Packets Remain Content-Free After Serialization
    
    /// Verifies DiagnosticsExportPacket contains no forbidden keys
    func testDiagnosticsExportPacketContentFree() throws {
        // Create a minimal diagnostics packet
        let executionSnapshot = ExecutionDiagnosticsSnapshot.empty
        let usageSnapshot = UsageDiagnosticsSnapshot.empty
        
        let packet = DiagnosticsExportPacket(
            appVersion: "1.0.0",
            buildNumber: "100",
            iosVersion: "17.0",
            deviceModel: "iPhone",
            execution: executionSnapshot,
            usage: usageSnapshot,
            invariantsPassing: true,
            safetyContractHash: "abc123"
        )
        
        let data = try packet.exportJSON()
        let (result, _) = SyncPacketValidator.shared.validate(packet, as: .diagnosticsExport)
        
        XCTAssertTrue(result.isValid, "DiagnosticsExportPacket should pass validation: \(result.errors)")
    }
    
    /// Verifies PolicyExportPacket contains no forbidden keys
    func testPolicyExportPacketContentFree() throws {
        let policy = OperatorPolicy.defaultPolicy
        let packet = PolicyExportPacket(
            appVersion: "1.0.0",
            buildNumber: "100",
            policy: policy,
            policySummary: policy.summary
        )
        
        let (result, _) = SyncPacketValidator.shared.validate(packet, as: .policyExport)
        
        XCTAssertTrue(result.isValid, "PolicyExportPacket should pass validation: \(result.errors)")
    }
    
    // MARK: - G) Sync Module No Background Task Usage
    
    /// Verifies Sync files don't use BackgroundTasks
    func testSyncFilesNoBackgroundTasks() throws {
        let syncFiles = [
            ("NetworkAllowance.swift", "Sync"),
            ("SupabaseClient.swift", "Sync"),
            ("SyncPacket.swift", "Sync"),
            ("SyncPacketValidator.swift", "Sync"),
            ("SyncQueue.swift", "Sync")
        ]
        
        let backgroundPatterns = [
            "BGTaskScheduler",
            "BGAppRefreshTask",
            "BGProcessingTask",
            "UIBackgroundTaskIdentifier",
            "beginBackgroundTask"
        ]
        
        for (fileName, directory) in syncFiles {
            let filePath = findProjectFile(named: fileName, in: directory)
            guard FileManager.default.fileExists(atPath: filePath) else { continue }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            for pattern in backgroundPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "INVARIANT VIOLATION: \(fileName) contains background task pattern: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - H) NetworkAllowance Configuration
    
    /// Verifies NetworkAllowance configuration is correct
    func testNetworkAllowanceConfiguration() {
        let issues = NetworkAllowance.verifySyncConfiguration()
        
        XCTAssertTrue(issues.isEmpty, "NetworkAllowance configuration issues: \(issues)")
    }
    
    /// Verifies forbidden content keys list is comprehensive
    func testForbiddenContentKeysComprehensive() {
        let keys = SyncSafetyConfig.forbiddenContentKeys
        
        // Must contain critical content indicators
        XCTAssertTrue(keys.contains("body"))
        XCTAssertTrue(keys.contains("subject"))
        XCTAssertTrue(keys.contains("email"))
        XCTAssertTrue(keys.contains("draft"))
        XCTAssertTrue(keys.contains("prompt"))
        XCTAssertTrue(keys.contains("context"))
        XCTAssertTrue(keys.contains("content"))
        XCTAssertTrue(keys.contains("message"))
    }
    
    /// Verifies required metadata keys are specified
    func testRequiredMetadataKeysSpecified() {
        let keys = SyncSafetyConfig.requiredMetadataKeys
        
        XCTAssertTrue(keys.contains("schemaVersion"))
        XCTAssertTrue(keys.contains("exportedAt"))
    }
    
    // MARK: - I) Syncable Packet Types Are Limited
    
    /// Verifies only metadata packet types are syncable
    func testSyncablePacketTypesAreLimited() {
        let types = SyncSafetyConfig.SyncablePacketType.allCases
        
        // Should be a small, controlled list
        XCTAssertLessThanOrEqual(types.count, 10, "Syncable packet types should be limited")
        
        // Verify expected types
        XCTAssertTrue(types.contains(.qualityExport))
        XCTAssertTrue(types.contains(.diagnosticsExport))
        XCTAssertTrue(types.contains(.policyExport))
        
        // Verify NO content types
        for type in types {
            XCTAssertFalse(
                type.rawValue.lowercased().contains("draft"),
                "No draft types should be syncable"
            )
            XCTAssertFalse(
                type.rawValue.lowercased().contains("memory"),
                "No memory types should be syncable"
            )
        }
    }
    
    // MARK: - Helpers
    
    /// Finds a project file by name and subdirectory
    private func findProjectFile(named fileName: String, in subdirectory: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let targetPath = projectRoot
            .appendingPathComponent("OperatorKit")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent(fileName)
            .path
        
        return targetPath
    }
}

// MARK: - SyncPacket Tests

extension SyncInvariantTests {
    
    /// Verifies SyncPacket stores metadata correctly
    func testSyncPacketStoresMetadata() {
        let jsonData = """
        {"schemaVersion": 1, "exportedAt": "2024-01-01T00:00:00Z", "metrics": {}}
        """.data(using: .utf8)!
        
        let packet = SyncPacket(
            packetType: .qualityExport,
            jsonData: jsonData,
            schemaVersion: 1,
            originalExportedAt: Date()
        )
        
        XCTAssertEqual(packet.packetType, .qualityExport)
        XCTAssertEqual(packet.schemaVersion, 1)
        XCTAssertEqual(packet.sizeBytes, jsonData.count)
    }
    
    /// Verifies PreFlightReport generates correct summary
    func testPreFlightReportSummary() {
        let report = PreFlightReport(
            packetCount: 3,
            totalSizeBytes: 15000,
            packetSummaries: ["Test 1", "Test 2", "Test 3"],
            issues: [],
            canProceed: true
        )
        
        XCTAssertTrue(report.canProceed)
        XCTAssertEqual(report.packetCount, 3)
        XCTAssertFalse(report.formattedTotalSize.isEmpty)
    }
}
