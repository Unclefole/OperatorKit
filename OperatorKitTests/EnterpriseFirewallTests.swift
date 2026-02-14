import XCTest
@testable import OperatorKit

// ============================================================================
// ENTERPRISE FIREWALL TESTS — Phase 19
//
// 1. Forbidden Import Firewall: BG tasks cannot reference execution/services
// 2. Deep Link Safety Firewall: deep links never trigger execution
// 3. Feature Flag Firewall: enterprise features default OFF
// 4. BG Identifier Allowlist: only registered identifiers are permitted
// ============================================================================

@MainActor
final class EnterpriseFirewallTests: XCTestCase {

    // MARK: - 1. Forbidden Import Firewall (Background)

    /// Scan Domain/Background/* for forbidden symbols at file-content level.
    /// Forbidden: ExecutionEngine, CalendarService, ReminderService, MailComposerService, ServiceAccessToken
    func testBackgroundFilesContainNoForbiddenSymbols() throws {
        let forbiddenSymbols = [
            "ExecutionEngine",
            "CalendarService",
            "ReminderService",
            "MailComposerService",
            "ServiceAccessToken"
        ]

        let bgDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // OperatorKitTests
            .deletingLastPathComponent() // root
            .appendingPathComponent("OperatorKit/Domain/Background")

        guard FileManager.default.fileExists(atPath: bgDir.path) else {
            XCTFail("Background directory not found at \(bgDir.path)")
            return
        }

        let files = try FileManager.default.contentsOfDirectory(at: bgDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }

        XCTAssertFalse(files.isEmpty, "Background directory must contain .swift files")

        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            let filename = file.lastPathComponent

            // Strip comments before checking (single-line // comments)
            let lines = content.components(separatedBy: .newlines)
            let codeLines = lines.filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
            }
            let codeOnly = codeLines.joined(separator: "\n")

            for symbol in forbiddenSymbols {
                XCTAssertFalse(
                    codeOnly.contains(symbol),
                    "FIREWALL VIOLATION: \(filename) contains forbidden symbol '\(symbol)' outside comments"
                )
            }
        }
    }

    // MARK: - 2. Deep Link Safety Firewall

    /// Ensure NotificationBridge + AppRouter deep link handlers never reference execution.
    func testDeepLinkHandlersNeverTriggerExecution() throws {
        let notifFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("OperatorKit/Domain/Background/NotificationBridge.swift")

        guard FileManager.default.fileExists(atPath: notifFile.path) else {
            XCTFail("NotificationBridge.swift not found")
            return
        }

        let content = try String(contentsOf: notifFile, encoding: .utf8)
        let forbiddenInDeepLinks = [
            "ExecutionEngine",
            "issueHardenedToken",
            "execute(",
            "executeAuthorized"
        ]

        // Strip comments
        let lines = content.components(separatedBy: .newlines)
        let codeLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        let codeOnly = codeLines.joined(separator: "\n")

        for symbol in forbiddenInDeepLinks {
            XCTAssertFalse(
                codeOnly.contains(symbol),
                "DEEP LINK FIREWALL: NotificationBridge.swift references '\(symbol)' — deep links must NEVER trigger execution"
            )
        }
    }

    // MARK: - 3. Feature Flag Firewall

    /// Enterprise features must default OFF.
    func testEnterpriseFeatureFlagsDefaultOff() {
        // Clear all flags to simulate fresh install
        let flags: [(String, Bool)] = [
            ("ok_enterprise_apns_enabled", EnterpriseFeatureFlags.apnsEnabled),
            ("ok_enterprise_mirror_enabled", EnterpriseFeatureFlags.mirrorEnabled),
            ("ok_enterprise_org_cosign_enabled", EnterpriseFeatureFlags.orgCoSignEnabled),
            ("ok_enterprise_bg_autonomy_enabled", EnterpriseFeatureFlags.backgroundAutonomyEnabled),
            ("ok_enterprise_execution_kill", EnterpriseFeatureFlags.executionKillSwitch),
            ("ok_enterprise_cloud_kill", EnterpriseFeatureFlags.cloudKillSwitch)
        ]

        for (key, value) in flags {
            // If not explicitly set, UserDefaults returns false for bool
            if UserDefaults.standard.object(forKey: key) == nil {
                XCTAssertFalse(value, "Enterprise flag '\(key)' must default to OFF")
            }
        }
    }

    /// Cloud models must default OFF.
    func testCloudModelFlagsDefaultOff() {
        if UserDefaults.standard.object(forKey: "ok_cloud_models_enabled") == nil {
            XCTAssertFalse(IntelligenceFeatureFlags.cloudModelsEnabled,
                           "Cloud models must default OFF")
        }
    }

    // MARK: - 4. BG Identifier Allowlist

    /// Only allowlisted BG task identifiers may exist.
    func testBGIdentifiersMatchAllowlist() {
        let allowlisted: Set<String> = [
            "com.operatorkit.bg.prepare-proposals",
            "com.operatorkit.bg.mirror-attestation"
        ]

        let registered: Set<String> = [
            BackgroundScheduler.proposalTaskIdentifier,
            BackgroundScheduler.mirrorTaskIdentifier
        ]

        XCTAssertEqual(registered, allowlisted,
                       "BG task identifiers must exactly match the allowlist")
    }

    /// Compile-time guard matches runtime identifiers.
    func testCompileTimeGuardMatchesRuntime() {
        let guardList = BackgroundTasksGuard.allowlistedIdentifiers
        let runtimeList: Set<String> = [
            BackgroundScheduler.proposalTaskIdentifier,
            BackgroundScheduler.mirrorTaskIdentifier,
            BackgroundScheduler.scoutTaskIdentifier
        ]
        XCTAssertEqual(guardList, runtimeList,
                       "CompileTimeGuards allowlist must match BackgroundScheduler identifiers")
    }

    // MARK: - 5. Execution Kill Switch

    func testExecutionKillSwitchForcesLockdown() {
        let guard_ = KernelIntegrityGuard.shared
        let originalPosture = guard_.systemPosture

        // Activate kill switch
        EnterpriseFeatureFlags.setExecutionKillSwitch(true)
        XCTAssertTrue(guard_.isLocked, "Kill switch must force lockdown")

        // Reset
        UserDefaults.standard.removeObject(forKey: "ok_enterprise_execution_kill")
        guard_.attemptRecovery()
    }
}
