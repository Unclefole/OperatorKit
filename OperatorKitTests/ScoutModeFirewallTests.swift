import XCTest
@testable import OperatorKit

// ============================================================================
// SCOUT MODE FIREWALL + FUNCTIONALITY TESTS
//
// 1. Forbidden import firewall (Scout + Background)
// 2. Deep link safety
// 3. Slack payload signing + nonce replay
// 4. Network policy gating
// 5. ScoutEngine read-only output
// 6. Feature flag defaults
// ============================================================================

@MainActor
final class ScoutModeFirewallTests: XCTestCase {

    // MARK: - 1. Forbidden Import Firewall

    /// Scout files must have ZERO runtime references to execution primitives.
    func testScoutFilesContainNoForbiddenSymbols() throws {
        let forbiddenSymbols = [
            "ExecutionEngine",
            "ServiceAccessToken",
            "CalendarService",
            "ReminderService",
            "MailComposerService",
            "issueHardenedToken",
            "issueToken"
        ]

        let scoutDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("OperatorKit/Domain/Scout")

        guard FileManager.default.fileExists(atPath: scoutDir.path) else {
            XCTFail("Scout directory not found at \(scoutDir.path)"); return
        }

        let files = try FileManager.default.contentsOfDirectory(at: scoutDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }

        XCTAssertFalse(files.isEmpty, "Scout directory must contain .swift files")

        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            let filename = file.lastPathComponent

            // Strip comments
            let lines = content.components(separatedBy: .newlines)
            let codeLines = lines.filter { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                return !t.hasPrefix("//") && !t.hasPrefix("*") && !t.hasPrefix("/*")
            }
            let codeOnly = codeLines.joined(separator: "\n")

            for symbol in forbiddenSymbols {
                XCTAssertFalse(
                    codeOnly.contains(symbol),
                    "SCOUT FIREWALL: \(filename) contains forbidden symbol '\(symbol)' outside comments"
                )
            }
        }
    }

    /// Background files must remain clean of execution symbols.
    func testBackgroundFilesStillClean() throws {
        let forbiddenSymbols = ["ExecutionEngine", "ServiceAccessToken", "CalendarService", "ReminderService", "MailComposerService"]

        let bgDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("OperatorKit/Domain/Background")

        guard FileManager.default.fileExists(atPath: bgDir.path) else { return }

        let files = try FileManager.default.contentsOfDirectory(at: bgDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }

        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            let codeOnly = lines.joined(separator: "\n")

            for symbol in forbiddenSymbols {
                XCTAssertFalse(codeOnly.contains(symbol),
                    "BG FIREWALL: \(file.lastPathComponent) references '\(symbol)'")
            }
        }
    }

    // MARK: - 2. Deep Link Safety

    func testScoutDeepLinksNeverTriggerExecution() throws {
        let scoutUIDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("OperatorKit/UI/Scout")

        guard FileManager.default.fileExists(atPath: scoutUIDir.path) else { return }

        let files = try FileManager.default.contentsOfDirectory(at: scoutUIDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }

        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            let codeOnly = content.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")

            XCTAssertFalse(codeOnly.contains("ExecutionEngine"),
                "DEEP LINK SAFETY: \(file.lastPathComponent) must not reference ExecutionEngine")
            XCTAssertFalse(codeOnly.contains("issueHardenedToken"),
                "DEEP LINK SAFETY: \(file.lastPathComponent) must not reference token issuance")
        }
    }

    // MARK: - 3. Slack Payload Signing + Nonce

    func testSlackNonceReplayRejected() {
        let store = ConsumedTokenStore(filename: "test_slack_nonces_\(UUID().uuidString).json")
        let nonce = UUID()
        let expiry = Date().addingTimeInterval(3600)

        // First consumption: success
        XCTAssertTrue(store.consume(tokenId: nonce, expiresAt: expiry))
        // Replay: rejected
        XCTAssertFalse(store.consume(tokenId: nonce, expiresAt: expiry))
    }

    // MARK: - 4. Network Policy Gating

    func testSlackHostBlockedUnlessAllowlisted() {
        let enforcer = NetworkPolicyEnforcer.shared
        let savedMode = enforcer.mode
        enforcer.mode = .enterpriseAllowlist

        let slackURL = URL(string: "https://hooks.slack.com/services/T000/B000/xxx")!

        // Without allowlisting: should fail
        enforcer.removeEnterpriseHost("hooks.slack.com")
        XCTAssertThrowsError(try enforcer.validate(slackURL),
            "Slack host should be blocked when not allowlisted")

        // After allowlisting: should pass
        enforcer.registerEnterpriseHost("hooks.slack.com")
        XCTAssertNoThrow(try enforcer.validate(slackURL),
            "Slack host should pass when allowlisted")

        // Cleanup
        enforcer.removeEnterpriseHost("hooks.slack.com")
        enforcer.mode = savedMode
    }

    func testSlackDualGateRequiresBothFlags() {
        // Reset flags
        let savedIntegration = EnterpriseFeatureFlags.slackIntegrationEnabled
        let savedAllowlist = EnterpriseFeatureFlags.slackHostAllowlistEnabled

        // Both off
        EnterpriseFeatureFlags.setSlackIntegrationEnabled(false)
        EnterpriseFeatureFlags.setSlackHostAllowlistEnabled(false)
        XCTAssertFalse(EnterpriseFeatureFlags.slackDeliveryPermitted, "Dual gate: both off → not permitted")

        // Integration on, allowlist off
        EnterpriseFeatureFlags.setSlackIntegrationEnabled(true)
        EnterpriseFeatureFlags.setSlackHostAllowlistEnabled(false)
        XCTAssertFalse(EnterpriseFeatureFlags.slackDeliveryPermitted, "Dual gate: only integration → not permitted")

        // Integration off, allowlist on
        EnterpriseFeatureFlags.setSlackIntegrationEnabled(false)
        EnterpriseFeatureFlags.setSlackHostAllowlistEnabled(true)
        XCTAssertFalse(EnterpriseFeatureFlags.slackDeliveryPermitted, "Dual gate: only allowlist → not permitted")

        // Both on
        EnterpriseFeatureFlags.setSlackIntegrationEnabled(true)
        EnterpriseFeatureFlags.setSlackHostAllowlistEnabled(true)
        XCTAssertTrue(EnterpriseFeatureFlags.slackDeliveryPermitted, "Dual gate: both on → permitted")

        // Restore
        EnterpriseFeatureFlags.setSlackIntegrationEnabled(savedIntegration)
        EnterpriseFeatureFlags.setSlackHostAllowlistEnabled(savedAllowlist)
    }

    // MARK: - 4b. Inbound Webhook Scout Trigger

    func testInboundWebhookScoutRunRequestedRoutesSafely() {
        EnterpriseFeatureFlags.setAPNsEnabled(true)
        guard let payload = WebhookHandler.createSigned(type: .scoutRunRequested, data: [:]) else {
            XCTFail("Could not create signed webhook"); return
        }
        // Should not throw
        XCTAssertNoThrow(try WebhookHandler.shared.handleInbound(payload))
        EnterpriseFeatureFlags.setAPNsEnabled(false)
    }

    func testInboundWebhookScoutDoesNotCallExecution() throws {
        // Verify WebhookHandler.swift has no references to ExecutionEngine
        let whFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("OperatorKit/Domain/Enterprise/WebhookHandler.swift")
        guard FileManager.default.fileExists(atPath: whFile.path) else { return }
        let content = try String(contentsOf: whFile, encoding: .utf8)
        let codeOnly = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        XCTAssertFalse(codeOnly.contains("ExecutionEngine"),
            "WebhookHandler must never reference ExecutionEngine")
    }

    // MARK: - 5. ScoutEngine Read-Only Output

    func testScoutEngineProducesFindingPack() async {
        let engine = ScoutEngine.shared
        let pack = await engine.run(config: .default)

        XCTAssertFalse(pack.id.uuidString.isEmpty)
        XCTAssertFalse(pack.summary.isEmpty, "Summary must not be empty")
        // Findings should exist (at least system health checks)
        XCTAssertGreaterThan(pack.findings.count, 0, "Scout should produce at least one finding")
    }

    func testFindingPackIsCodable() throws {
        let finding = Finding(
            title: "Test finding",
            detail: "Detail",
            category: .systemHealth,
            confidence: 0.9
        )
        let pack = FindingPack(
            scoutRunId: UUID(),
            scope: .full,
            severity: .info,
            summary: "Test",
            findings: [finding],
            evidenceRefs: [],
            recommendedActions: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(pack)
        XCTAssertGreaterThan(data.count, 0)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FindingPack.self, from: data)
        XCTAssertEqual(decoded.id, pack.id)
        XCTAssertEqual(decoded.findings.count, 1)
    }

    // MARK: - 6. Feature Flag Defaults

    func testScoutModeDefaultOff() {
        if UserDefaults.standard.object(forKey: "ok_enterprise_scout_mode") == nil {
            XCTAssertFalse(EnterpriseFeatureFlags.scoutModeEnabled, "Scout must default OFF")
        }
    }

    func testSlackIntegrationDefaultOff() {
        if UserDefaults.standard.object(forKey: "ok_enterprise_slack_enabled") == nil {
            XCTAssertFalse(EnterpriseFeatureFlags.slackIntegrationEnabled, "Slack must default OFF")
        }
    }

    func testSlackHostAllowlistDefaultOff() {
        if UserDefaults.standard.object(forKey: "ok_enterprise_slack_host_allowlist") == nil {
            XCTAssertFalse(EnterpriseFeatureFlags.slackHostAllowlistEnabled, "Slack host allowlist must default OFF")
        }
    }

    // MARK: - 7. BG Identifier Allowlist Updated

    func testScoutBGIdentifierInAllowlist() {
        let allowlist = BackgroundTasksGuard.allowlistedIdentifiers
        XCTAssertTrue(allowlist.contains(BackgroundScheduler.scoutTaskIdentifier),
            "Scout BG identifier must be in allowlist")
    }
}
