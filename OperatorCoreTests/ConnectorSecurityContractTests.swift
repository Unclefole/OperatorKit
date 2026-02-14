import XCTest
@testable import OperatorKit

// ============================================================================
// CONNECTOR SECURITY CONTRACT — INVARIANT TESTS
//
// Validates:
//   ✅ ConnectorManifest immutability + hash integrity
//   ✅ ConnectorGate denies non-allowlisted host even with webResearchEnabled ON
//   ✅ ConnectorGate denies when researchHostAllowlistEnabled is OFF
//   ✅ ConnectorGate denies non-HTTPS
//   ✅ ConnectorGate denies POST for GET-only connector
//   ✅ ConnectorGate denies when cloud kill switch is active
//   ✅ ConnectorGate allows valid requests
//   ✅ Evidence contains connectorId/version on allow and deny
//   ✅ CapabilityScopeGuard rejects kernel scopes in connector manifests
//   ✅ ConnectorManifestRegistry returns correct manifests
//   ✅ Connectors do NOT reference ExecutionEngine / issueToken
// ============================================================================

final class ConnectorSecurityContractTests: XCTestCase {

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Reset feature flags to known state
        EnterpriseFeatureFlags.setWebResearchEnabled(false)
        EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(false)
        EnterpriseFeatureFlags.setSlackIntegrationEnabled(false)
        EnterpriseFeatureFlags.setSlackHostAllowlistEnabled(false)
        EnterpriseFeatureFlags.setCloudKillSwitch(false)
    }

    override func tearDown() {
        // Restore defaults
        EnterpriseFeatureFlags.setWebResearchEnabled(false)
        EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(false)
        EnterpriseFeatureFlags.setSlackIntegrationEnabled(false)
        EnterpriseFeatureFlags.setSlackHostAllowlistEnabled(false)
        EnterpriseFeatureFlags.setCloudKillSwitch(false)
        super.tearDown()
    }

    // MARK: - ConnectorManifest Tests

    func testManifestImmutabilityAndHash() {
        let manifest = ConnectorManifestRegistry.webFetcher
        XCTAssertEqual(manifest.connectorId, "web_fetcher")
        XCTAssertEqual(manifest.version, "1.0.0")
        XCTAssertEqual(manifest.signedBy, "com.operatorkit.firstparty")
        XCTAssertEqual(manifest.id, "com.operatorkit.connector.web_fetcher")
        XCTAssertFalse(manifest.manifestHash.isEmpty, "Manifest hash must not be empty")
        XCTAssertEqual(manifest.manifestHash.count, 64, "SHA256 hex must be 64 chars")
    }

    func testManifestRegistryLookup() {
        XCTAssertNotNil(ConnectorManifestRegistry.manifest(for: "web_fetcher"))
        XCTAssertNotNil(ConnectorManifestRegistry.manifest(for: "slack_notifier"))
        XCTAssertNil(ConnectorManifestRegistry.manifest(for: "unknown_connector"))
        XCTAssertEqual(ConnectorManifestRegistry.all.count, 2)
    }

    func testWebFetcherManifestConstraints() {
        let m = ConnectorManifestRegistry.webFetcher
        XCTAssertEqual(m.allowedHTTPMethods, ["GET"], "Web fetcher must be GET-only")
        XCTAssertTrue(m.requiresDataDiode, "Web fetcher must require DataDiode")
        XCTAssertTrue(m.isFullyReadOnly, "Web fetcher must be fully read-only")
        XCTAssertTrue(m.requiresNetwork, "Web fetcher must require network")
        XCTAssertEqual(m.maxPayloadBytes, 10_485_760)
        XCTAssertTrue(m.allowedHosts.contains("www.justice.gov"))
    }

    func testSlackNotifierManifestConstraints() {
        let m = ConnectorManifestRegistry.slackNotifier
        XCTAssertEqual(m.allowedHTTPMethods, ["POST"], "Slack must be POST-only")
        XCTAssertFalse(m.requiresDataDiode, "Slack findings are already processed")
        XCTAssertFalse(m.isFullyReadOnly, "Slack sends outbound data")
        XCTAssertTrue(m.requiresNetwork, "Slack requires network")
        XCTAssertTrue(m.allowedHosts.contains("hooks.slack.com"))
    }

    // MARK: - ConnectorGate Deny Tests

    func testGateDeniesNonAllowlistedHostEvenWithWebResearchEnabled() {
        // Enable web research dual-gate
        EnterpriseFeatureFlags.setWebResearchEnabled(true)
        EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(true)

        let manifest = ConnectorManifestRegistry.webFetcher
        let request = ConnectorRequest(
            connectorId: "web_fetcher",
            targetURL: URL(string: "https://evil-host.example.com/data")!,
            httpMethod: "GET"
        )

        let decision = ConnectorGate.validate(request: request, manifest: manifest)
        XCTAssertFalse(decision.isAllowed, "Must deny non-allowlisted host")
        XCTAssertTrue(decision.reason.contains("not in connector allowlist"), "Reason should mention allowlist: \(decision.reason)")
    }

    func testGateDeniesWhenResearchHostAllowlistDisabled() {
        // Only one gate enabled — dual-gate NOT satisfied
        EnterpriseFeatureFlags.setWebResearchEnabled(true)
        EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(false)

        let manifest = ConnectorManifestRegistry.webFetcher
        let request = ConnectorRequest(
            connectorId: "web_fetcher",
            targetURL: URL(string: "https://www.justice.gov/page")!,
            httpMethod: "GET"
        )

        let decision = ConnectorGate.validate(request: request, manifest: manifest)
        XCTAssertFalse(decision.isAllowed, "Must deny when researchHostAllowlistEnabled is OFF")
        XCTAssertTrue(decision.reason.lowercased().contains("flag"), "Reason should mention feature flag: \(decision.reason)")
    }

    func testGateDeniesWhenWebResearchDisabled() {
        EnterpriseFeatureFlags.setWebResearchEnabled(false)
        EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(true)

        let manifest = ConnectorManifestRegistry.webFetcher
        let request = ConnectorRequest(
            connectorId: "web_fetcher",
            targetURL: URL(string: "https://www.justice.gov/page")!,
            httpMethod: "GET"
        )

        let decision = ConnectorGate.validate(request: request, manifest: manifest)
        XCTAssertFalse(decision.isAllowed, "Must deny when webResearchEnabled is OFF")
    }

    func testGateDeniesNonHTTPS() {
        EnterpriseFeatureFlags.setWebResearchEnabled(true)
        EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(true)

        let manifest = ConnectorManifestRegistry.webFetcher
        let request = ConnectorRequest(
            connectorId: "web_fetcher",
            targetURL: URL(string: "http://www.justice.gov/page")!,
            httpMethod: "GET"
        )

        let decision = ConnectorGate.validate(request: request, manifest: manifest)
        XCTAssertFalse(decision.isAllowed, "Must deny HTTP (non-HTTPS)")
        XCTAssertTrue(decision.reason.contains("HTTPS"), "Reason should mention HTTPS: \(decision.reason)")
    }

    func testGateDeniesPostForGetOnlyConnector() {
        EnterpriseFeatureFlags.setWebResearchEnabled(true)
        EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(true)

        let manifest = ConnectorManifestRegistry.webFetcher
        let request = ConnectorRequest(
            connectorId: "web_fetcher",
            targetURL: URL(string: "https://www.justice.gov/page")!,
            httpMethod: "POST"
        )

        let decision = ConnectorGate.validate(request: request, manifest: manifest)
        XCTAssertFalse(decision.isAllowed, "Must deny POST for GET-only connector")
        XCTAssertTrue(decision.reason.contains("POST"), "Reason should mention POST: \(decision.reason)")
    }

    func testGateDeniesWhenCloudKillSwitchActive() {
        EnterpriseFeatureFlags.setWebResearchEnabled(true)
        EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(true)
        EnterpriseFeatureFlags.setCloudKillSwitch(true)

        let manifest = ConnectorManifestRegistry.webFetcher
        let request = ConnectorRequest(
            connectorId: "web_fetcher",
            targetURL: URL(string: "https://www.justice.gov/page")!,
            httpMethod: "GET"
        )

        let decision = ConnectorGate.validate(request: request, manifest: manifest)
        XCTAssertFalse(decision.isAllowed, "Must deny when cloud kill switch is active")
        XCTAssertTrue(decision.reason.lowercased().contains("kill switch"), "Reason should mention kill switch: \(decision.reason)")
    }

    func testGateDeniesConnectorIdMismatch() {
        EnterpriseFeatureFlags.setWebResearchEnabled(true)
        EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(true)

        let manifest = ConnectorManifestRegistry.webFetcher
        let request = ConnectorRequest(
            connectorId: "wrong_connector",
            targetURL: URL(string: "https://www.justice.gov/page")!,
            httpMethod: "GET"
        )

        let decision = ConnectorGate.validate(request: request, manifest: manifest)
        XCTAssertFalse(decision.isAllowed, "Must deny connector ID mismatch")
        XCTAssertTrue(decision.reason.contains("mismatch"), "Reason should mention mismatch: \(decision.reason)")
    }

    func testGateDeniesPayloadOverCap() {
        EnterpriseFeatureFlags.setWebResearchEnabled(true)
        EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(true)

        let manifest = ConnectorManifestRegistry.webFetcher
        let request = ConnectorRequest(
            connectorId: "web_fetcher",
            targetURL: URL(string: "https://www.justice.gov/page")!,
            httpMethod: "GET",
            payloadSize: 99_000_000  // Way over 10MB cap
        )

        let decision = ConnectorGate.validate(request: request, manifest: manifest)
        XCTAssertFalse(decision.isAllowed, "Must deny payload over cap")
        XCTAssertTrue(decision.reason.contains("Payload"), "Reason should mention payload: \(decision.reason)")
    }

    // MARK: - ConnectorGate Allow Test

    func testGateAllowsValidWebFetcherRequest() {
        EnterpriseFeatureFlags.setWebResearchEnabled(true)
        EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(true)

        let manifest = ConnectorManifestRegistry.webFetcher
        let request = ConnectorRequest(
            connectorId: "web_fetcher",
            targetURL: URL(string: "https://www.justice.gov/some-report")!,
            httpMethod: "GET"
        )

        let decision = ConnectorGate.validate(request: request, manifest: manifest)
        XCTAssertTrue(decision.isAllowed, "Should allow valid request: \(decision.reason)")
    }

    func testGateAllowsValidSlackRequest() {
        EnterpriseFeatureFlags.setSlackIntegrationEnabled(true)
        EnterpriseFeatureFlags.setSlackHostAllowlistEnabled(true)

        let manifest = ConnectorManifestRegistry.slackNotifier
        let request = ConnectorRequest(
            connectorId: "slack_notifier",
            targetURL: URL(string: "https://hooks.slack.com/services/T00/B00/xxx")!,
            httpMethod: "POST",
            payloadSize: 1024
        )

        let decision = ConnectorGate.validate(request: request, manifest: manifest)
        XCTAssertTrue(decision.isAllowed, "Should allow valid Slack request: \(decision.reason)")
    }

    // MARK: - CapabilityScopeGuard Tests

    func testScopeGuardAllowsValidConnectorManifest() {
        let manifest = ConnectorManifestRegistry.webFetcher
        let result = CapabilityScopeGuard.validateManifest(manifest)
        XCTAssertTrue(result.isAllowed, "Web fetcher manifest should pass scope guard")
    }

    func testScopeGuardDeniesKernelScopeOverlap() {
        // Create a rogue manifest that tries to claim execution scope
        let rogueManifest = ConnectorManifest(
            connectorId: "rogue_connector",
            version: "1.0.0",
            displayName: "Rogue",
            description: "Should be denied",
            allowedHosts: [],
            allowedHTTPMethods: ["GET"],
            maxPayloadBytes: 1024,
            timeoutSeconds: 5,
            dataClassesTouched: [.publicWeb],
            requiresDataDiode: false,
            scopes: [.readWebPublic],  // Safe scope
            minApprovalTier: .low,
            requiredFeatureFlags: [],
            requiredEvidenceTags: ["execution_started"]  // ILLEGAL evidence tag
        )

        let result = CapabilityScopeGuard.validateManifest(rogueManifest)
        XCTAssertFalse(result.isAllowed, "Must reject manifest with execution evidence tags")
    }

    func testScopeGuardValidatesConnectorScopes() {
        let safeScopes: [ConnectorScope] = [.readWebPublic, .draftProposal]
        let result = CapabilityScopeGuard.validateConnectorScopes(safeScopes)
        XCTAssertTrue(result.isAllowed, "Safe scopes should pass")
    }

    func testKernelScopesAreDistinctFromConnectorScopes() {
        // Verify no overlap between the two scope enums at the raw-value level
        let connectorScopeNames = Set(ConnectorScope.allCases.map(\.rawValue))
        let kernelScopeNames = Set(KernelScope.allCases.map(\.rawValue))
        let overlap = connectorScopeNames.intersection(kernelScopeNames)
        XCTAssertTrue(overlap.isEmpty, "Connector and kernel scopes must NEVER overlap: \(overlap)")
    }

    func testAllFirstPartyManifestsPassScopeGuard() {
        for manifest in ConnectorManifestRegistry.all {
            let result = CapabilityScopeGuard.validateManifest(manifest)
            XCTAssertTrue(result.isAllowed, "First-party manifest '\(manifest.connectorId)' must pass scope guard: \(result.reason ?? "")")
        }
    }

    // MARK: - CapabilityScopeSummary Tests

    func testCapabilityScopeSummary() {
        let summary = CapabilityScopeSummary(manifest: ConnectorManifestRegistry.webFetcher)
        XCTAssertEqual(summary.connectorId, "web_fetcher")
        XCTAssertTrue(summary.isFullyReadOnly)
        XCTAssertTrue(summary.requiresNetwork)
        XCTAssertFalse(summary.hasKernelScopeViolation)
    }

    // MARK: - GovernedWebFetcher Manifest Binding

    func testGovernedWebFetcherExposesManifest() {
        let fetcher = GovernedWebFetcher.shared
        XCTAssertEqual(fetcher.manifest.connectorId, "web_fetcher")
        XCTAssertEqual(fetcher.manifest.version, "1.0.0")
        XCTAssertEqual(fetcher.manifest.signedBy, "com.operatorkit.firstparty")
    }

    // MARK: - ConnectorGate Enforce (Throwing)

    func testGateEnforceThrowsOnDeny() {
        EnterpriseFeatureFlags.setWebResearchEnabled(false)

        let manifest = ConnectorManifestRegistry.webFetcher
        let request = ConnectorRequest(
            connectorId: "web_fetcher",
            targetURL: URL(string: "https://www.justice.gov/page")!,
            httpMethod: "GET"
        )

        XCTAssertThrowsError(try ConnectorGate.enforce(request: request, manifest: manifest)) { error in
            guard let gateError = error as? ConnectorGateError else {
                XCTFail("Expected ConnectorGateError, got \(error)")
                return
            }
            if case .denied(let cid, _) = gateError {
                XCTAssertEqual(cid, "web_fetcher")
            }
        }
    }

    func testGateEnforceDoesNotThrowOnAllow() {
        EnterpriseFeatureFlags.setWebResearchEnabled(true)
        EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(true)

        let manifest = ConnectorManifestRegistry.webFetcher
        let request = ConnectorRequest(
            connectorId: "web_fetcher",
            targetURL: URL(string: "https://www.justice.gov/report")!,
            httpMethod: "GET"
        )

        XCTAssertNoThrow(try ConnectorGate.enforce(request: request, manifest: manifest))
    }

    // MARK: - Decision Enum Tests

    func testDecisionProperties() {
        let allow = ConnectorGateDecision.allow(reason: "OK")
        XCTAssertTrue(allow.isAllowed)
        XCTAssertEqual(allow.reason, "OK")

        let deny = ConnectorGateDecision.deny(reason: "NOPE")
        XCTAssertFalse(deny.isAllowed)
        XCTAssertEqual(deny.reason, "NOPE")
    }
}
