import XCTest
@testable import OperatorKit

// ============================================================================
// DIAGNOSTICS INVARIANT TESTS (Phase 10B)
//
// These tests enforce that diagnostics are:
// - Content-free (no user data)
// - Read-only (no side effects)
// - Non-interfering (don't touch execution modules)
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

final class DiagnosticsInvariantTests: XCTestCase {
    
    // MARK: - A) No Forbidden Keys in Diagnostics
    
    /// Verifies ExecutionDiagnosticsSnapshot contains no user content keys
    func testExecutionDiagnosticsContainsNoForbiddenKeys() throws {
        let snapshot = ExecutionDiagnosticsSnapshot(
            executionsLast7Days: 5,
            executionsToday: 2,
            lastExecutionAt: Date(),
            lastExecutionOutcome: .success,
            lastFailureCategory: nil,
            fallbackUsedRecently: false
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Forbidden keys that would indicate user content
        let forbiddenKeys = [
            "body", "subject", "title", "recipient", "draft",
            "context", "email", "event", "description", "attendee",
            "participants", "content", "message", "text"
        ]
        
        for key in forbiddenKeys {
            XCTAssertFalse(
                jsonString.lowercased().contains("\"\(key)\""),
                "INVARIANT VIOLATION: ExecutionDiagnosticsSnapshot contains forbidden key: \(key)"
            )
        }
    }
    
    /// Verifies UsageDiagnosticsSnapshot contains no user content keys
    func testUsageDiagnosticsContainsNoForbiddenKeys() throws {
        let snapshot = UsageDiagnosticsSnapshot(
            subscriptionTier: .free,
            weeklyExecutionLimit: 5,
            executionsRemainingThisWindow: 3,
            memoryItemCount: 7,
            memoryLimit: 10,
            windowResetsAt: Date().addingTimeInterval(86400 * 3)
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let jsonString = String(data: data, encoding: .utf8)!
        
        let forbiddenKeys = [
            "body", "subject", "title", "recipient", "draft",
            "context", "email", "event", "description", "attendee",
            "participants", "content", "message", "text"
        ]
        
        for key in forbiddenKeys {
            XCTAssertFalse(
                jsonString.lowercased().contains("\"\(key)\""),
                "INVARIANT VIOLATION: UsageDiagnosticsSnapshot contains forbidden key: \(key)"
            )
        }
    }
    
    /// Verifies DiagnosticsExportPacket contains no user content keys
    func testExportPacketContainsNoForbiddenKeys() throws {
        let executionSnapshot = ExecutionDiagnosticsSnapshot(
            executionsLast7Days: 5,
            executionsToday: 2,
            lastExecutionAt: Date(),
            lastExecutionOutcome: .success,
            lastFailureCategory: nil,
            fallbackUsedRecently: false
        )
        
        let usageSnapshot = UsageDiagnosticsSnapshot(
            subscriptionTier: .pro,
            weeklyExecutionLimit: nil,
            executionsRemainingThisWindow: nil,
            memoryItemCount: 15,
            memoryLimit: nil,
            windowResetsAt: nil
        )
        
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
        let jsonString = String(data: data, encoding: .utf8)!
        
        let forbiddenKeys = [
            "body", "subject", "title", "recipient", "draft",
            "context", "email", "event", "description", "attendee",
            "participants", "content", "message", "text"
        ]
        
        for key in forbiddenKeys {
            XCTAssertFalse(
                jsonString.lowercased().contains("\"\(key)\""),
                "INVARIANT VIOLATION: DiagnosticsExportPacket contains forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - B) Diagnostics Do Not Reference Core Modules
    
    /// Verifies ExecutionDiagnostics.swift does NOT import ExecutionEngine
    func testExecutionDiagnosticsDoesNotImportExecutionEngine() throws {
        let filePath = findProjectFile(named: "ExecutionDiagnostics.swift", in: "Diagnostics")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        XCTAssertFalse(
            content.contains("import ExecutionEngine") || content.contains("ExecutionEngine.shared"),
            "INVARIANT VIOLATION: ExecutionDiagnostics.swift must NOT reference ExecutionEngine"
        )
    }
    
    /// Verifies UsageDiagnostics.swift does NOT import ApprovalGate
    func testUsageDiagnosticsDoesNotImportApprovalGate() throws {
        let filePath = findProjectFile(named: "UsageDiagnostics.swift", in: "Diagnostics")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        XCTAssertFalse(
            content.contains("ApprovalGate"),
            "INVARIANT VIOLATION: UsageDiagnostics.swift must NOT reference ApprovalGate"
        )
    }
    
    /// Verifies DiagnosticsExportPacket.swift does NOT import ModelRouter
    func testDiagnosticsExportDoesNotImportModelRouter() throws {
        let filePath = findProjectFile(named: "DiagnosticsExportPacket.swift", in: "Diagnostics")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        XCTAssertFalse(
            content.contains("ModelRouter"),
            "INVARIANT VIOLATION: DiagnosticsExportPacket.swift must NOT reference ModelRouter"
        )
    }
    
    // MARK: - C) Export Packet Codable + Round-Trippable + Versioned
    
    /// Verifies DiagnosticsExportPacket is Codable
    func testExportPacketIsCodable() throws {
        let executionSnapshot = ExecutionDiagnosticsSnapshot(
            executionsLast7Days: 3,
            executionsToday: 1,
            lastExecutionAt: Date(),
            lastExecutionOutcome: .partialSuccess,
            lastFailureCategory: .timeout,
            fallbackUsedRecently: true
        )
        
        let usageSnapshot = UsageDiagnosticsSnapshot(
            subscriptionTier: .free,
            weeklyExecutionLimit: 5,
            executionsRemainingThisWindow: 2,
            memoryItemCount: 8,
            memoryLimit: 10,
            windowResetsAt: Date().addingTimeInterval(86400)
        )
        
        let packet = DiagnosticsExportPacket(
            appVersion: "1.0.0",
            buildNumber: "100",
            iosVersion: "17.0",
            deviceModel: "iPhone",
            execution: executionSnapshot,
            usage: usageSnapshot,
            invariantsPassing: true,
            safetyContractHash: "test123"
        )
        
        // Encode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(packet)
        
        // Decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DiagnosticsExportPacket.self, from: data)
        
        // Verify round-trip
        XCTAssertEqual(decoded.appVersion, packet.appVersion)
        XCTAssertEqual(decoded.buildNumber, packet.buildNumber)
        XCTAssertEqual(decoded.execution.executionsLast7Days, packet.execution.executionsLast7Days)
        XCTAssertEqual(decoded.usage.subscriptionTier, packet.usage.subscriptionTier)
        XCTAssertEqual(decoded.invariantsPassing, packet.invariantsPassing)
    }
    
    /// Verifies export packet has schema version
    func testExportPacketHasSchemaVersion() throws {
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
            safetyContractHash: "test"
        )
        
        XCTAssertEqual(packet.schemaVersion, DiagnosticsExportPacket.currentSchemaVersion)
        XCTAssertGreaterThan(packet.schemaVersion, 0)
    }
    
    /// Verifies all snapshot types have schema versions
    func testAllSnapshotsHaveSchemaVersions() {
        let execution = ExecutionDiagnosticsSnapshot.empty
        XCTAssertEqual(execution.schemaVersion, ExecutionDiagnosticsSnapshot.currentSchemaVersion)
        
        let usage = UsageDiagnosticsSnapshot.empty
        XCTAssertEqual(usage.schemaVersion, UsageDiagnosticsSnapshot.currentSchemaVersion)
    }
    
    // MARK: - D) Diagnostics Collection Does Not Increment Counters
    
    /// Verifies that capturing diagnostics does not increment usage counters
    func testDiagnosticsCollectionDoesNotIncrementCounters() {
        let ledger = UsageLedger.shared
        
        #if DEBUG
        ledger.forceReset()
        #endif
        
        // Get initial count
        let initialCount = ledger.data.executionsThisWindow
        
        // Capture diagnostics multiple times
        let collector = ExecutionDiagnosticsCollector()
        _ = collector.captureSnapshot()
        _ = collector.captureSnapshot()
        _ = collector.captureSnapshot()
        
        // Verify count unchanged
        let finalCount = ledger.data.executionsThisWindow
        XCTAssertEqual(initialCount, finalCount, "Diagnostics collection must NOT increment counters")
    }
    
    /// Verifies usage diagnostics collection does not modify state
    func testUsageDiagnosticsCollectionDoesNotModifyState() {
        let ledger = UsageLedger.shared
        
        #if DEBUG
        ledger.forceReset()
        #endif
        
        // Record initial state
        let initialWindowStart = ledger.data.windowStart
        let initialExecutions = ledger.data.executionsThisWindow
        
        // Capture usage diagnostics multiple times
        let collector = UsageDiagnosticsCollector()
        _ = collector.captureSnapshot()
        _ = collector.captureSnapshot()
        _ = collector.captureSnapshot()
        
        // Verify state unchanged
        XCTAssertEqual(ledger.data.windowStart, initialWindowStart)
        XCTAssertEqual(ledger.data.executionsThisWindow, initialExecutions)
    }
    
    // MARK: - E) Outcome and Failure Enums
    
    /// Verifies all ExecutionOutcome values have display text
    func testExecutionOutcomeHasDisplayText() {
        let outcomes: [ExecutionOutcome] = [
            .success, .cancelled, .failed, .partialSuccess, .savedDraftOnly, .unknown
        ]
        
        for outcome in outcomes {
            XCTAssertFalse(outcome.displayText.isEmpty, "Outcome \(outcome) must have display text")
            XCTAssertFalse(outcome.systemImage.isEmpty, "Outcome \(outcome) must have system image")
            XCTAssertFalse(outcome.colorName.isEmpty, "Outcome \(outcome) must have color name")
        }
    }
    
    /// Verifies all FailureCategory values have display text
    func testFailureCategoryHasDisplayText() {
        let categories: [FailureCategory] = [
            .approvalNotGranted, .permissionDenied, .confidenceTooLow,
            .timeout, .validationFailed, .serviceUnavailable, .userCancelled, .unknown
        ]
        
        for category in categories {
            XCTAssertFalse(category.displayText.isEmpty, "Category \(category) must have display text")
        }
    }
    
    /// Verifies outcome and failure enums are Codable
    func testEnumsAreCodable() throws {
        // ExecutionOutcome
        for outcome in [ExecutionOutcome.success, .failed, .cancelled] {
            let encoder = JSONEncoder()
            let data = try encoder.encode(outcome)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(ExecutionOutcome.self, from: data)
            XCTAssertEqual(decoded, outcome)
        }
        
        // FailureCategory
        for category in [FailureCategory.timeout, .permissionDenied, .unknown] {
            let encoder = JSONEncoder()
            let data = try encoder.encode(category)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(FailureCategory.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }
    
    // MARK: - F) No Network or Analytics References
    
    /// Verifies diagnostics files don't import networking
    func testDiagnosticsFilesNoNetworkImports() throws {
        let files = [
            ("ExecutionDiagnostics.swift", "Diagnostics"),
            ("UsageDiagnostics.swift", "Diagnostics"),
            ("DiagnosticsExportPacket.swift", "Diagnostics")
        ]
        
        let networkPatterns = [
            "import Network",
            "import Alamofire",
            "URLSession",
            "URLRequest",
            "HTTPURLResponse"
        ]
        
        for (fileName, directory) in files {
            let filePath = findProjectFile(named: fileName, in: directory)
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            for pattern in networkPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "INVARIANT VIOLATION: \(fileName) contains network reference: \(pattern)"
                )
            }
        }
    }
    
    /// Verifies diagnostics files don't import analytics
    func testDiagnosticsFilesNoAnalyticsImports() throws {
        let files = [
            ("ExecutionDiagnostics.swift", "Diagnostics"),
            ("UsageDiagnostics.swift", "Diagnostics"),
            ("DiagnosticsExportPacket.swift", "Diagnostics")
        ]
        
        let analyticsPatterns = [
            "import Firebase",
            "import Amplitude",
            "import Mixpanel",
            "Analytics",
            "Telemetry",
            "Crashlytics"
        ]
        
        for (fileName, directory) in files {
            let filePath = findProjectFile(named: fileName, in: directory)
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            for pattern in analyticsPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "INVARIANT VIOLATION: \(fileName) contains analytics reference: \(pattern)"
                )
            }
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

// MARK: - Display Helpers Tests

extension DiagnosticsInvariantTests {
    
    /// Verifies formatted display helpers work correctly
    func testDisplayHelpers() {
        let execution = ExecutionDiagnosticsSnapshot(
            executionsLast7Days: 10,
            executionsToday: 3,
            lastExecutionAt: nil,
            lastExecutionOutcome: .unknown,
            lastFailureCategory: nil,
            fallbackUsedRecently: false
        )
        
        XCTAssertEqual(execution.formattedLastExecution, "Never")
        XCTAssertTrue(execution.summaryStatus.contains("10"))
        
        let usage = UsageDiagnosticsSnapshot(
            subscriptionTier: .free,
            weeklyExecutionLimit: 5,
            executionsRemainingThisWindow: 2,
            memoryItemCount: 8,
            memoryLimit: 10,
            windowResetsAt: nil
        )
        
        XCTAssertTrue(usage.executionUsageSummary.contains("3/5"))
        XCTAssertTrue(usage.memoryUsageSummary.contains("8/10"))
        XCTAssertFalse(usage.isExecutionLimitReached)
        XCTAssertTrue(usage.isExecutionLimitApproaching)
        XCTAssertTrue(usage.isMemoryLimitApproaching)
        XCTAssertFalse(usage.isMemoryLimitReached)
    }
    
    /// Verifies Pro tier shows unlimited correctly
    func testProTierShowsUnlimited() {
        let usage = UsageDiagnosticsSnapshot(
            subscriptionTier: .pro,
            weeklyExecutionLimit: nil,
            executionsRemainingThisWindow: nil,
            memoryItemCount: 50,
            memoryLimit: nil,
            windowResetsAt: nil
        )
        
        XCTAssertEqual(usage.executionUsageSummary, "Unlimited")
        XCTAssertTrue(usage.memoryUsageSummary.contains("50"))
        XCTAssertFalse(usage.isExecutionLimitReached)
        XCTAssertFalse(usage.isMemoryLimitReached)
    }
}
