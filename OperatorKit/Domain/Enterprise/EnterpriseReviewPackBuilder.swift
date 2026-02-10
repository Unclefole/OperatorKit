import Foundation
import CryptoKit

// ============================================================================
// ENTERPRISE REVIEW PACK BUILDER — Exportable Security + Compliance Artifacts
//
// Generates:
//   1. Security Claims Matrix
//   2. Threat Model
//   3. Incident Runbook
//   4. Compliance Pack v2 (combines all above + mirror/chain/device data)
// ============================================================================

@MainActor
public final class EnterpriseReviewPackBuilder: ObservableObject {

    public static let shared = EnterpriseReviewPackBuilder()

    @Published private(set) var isExporting = false
    @Published private(set) var lastExportAt: Date?
    @Published private(set) var lastExportPath: String?

    private init() {}

    // =========================================================================
    // 1. SECURITY CLAIMS MATRIX
    // =========================================================================

    public struct SecurityClaim: Codable, Identifiable {
        public let id: String
        public let invariant: String
        public let enforcementPoint: String
        public let testCoverage: String
        public let evidenceLogTag: String
    }

    public func generateSecurityClaims() -> [SecurityClaim] {
        return [
            SecurityClaim(
                id: "SC-001",
                invariant: "No side effect without KernelAuthorizationToken",
                enforcementPoint: "ExecutionEngine.execute() — HARD GATE 1",
                testCoverage: "AdversarialSecuritySimulationTests.testTokenWithOldKeyVersionFails",
                evidenceLogTag: "unauthorized_execution"
            ),
            SecurityClaim(
                id: "SC-002",
                invariant: "Tokens are single-use with durable replay protection",
                enforcementPoint: "CapabilityKernel.consumeToken() + ConsumedTokenStore",
                testCoverage: "AdversarialSecuritySimulationTests.testConsumedTokenCannotReplayAfterSimulatedRestart",
                evidenceLogTag: "token_consumed"
            ),
            SecurityClaim(
                id: "SC-003",
                invariant: "Evidence chain is hash-linked and tamper-evident",
                enforcementPoint: "EvidenceEngine.appendEntry() + verifyChainIntegrity()",
                testCoverage: "AdversarialSecuritySimulationTests.testEvidenceChainIntegrityCheckExists",
                evidenceLogTag: "evidence_integrity_violation"
            ),
            SecurityClaim(
                id: "SC-004",
                invariant: "Cloud calls require ModelCallToken + DataDiode + allowlist",
                enforcementPoint: "ModelRouter.generateGoverned() + NetworkPolicyEnforcer",
                testCoverage: "EnterpriseFirewallTests.testEnterpriseFeatureFlagsDefaultOff",
                evidenceLogTag: "model_call_decision"
            ),
            SecurityClaim(
                id: "SC-005",
                invariant: "Write-capable services require ServiceAccessToken",
                enforcementPoint: "CalendarService/ReminderService/MailComposerService fileprivate init",
                testCoverage: "AdversarialSecuritySimulationTests.testAllSideEffectTypesHaveAuthorizationScope",
                evidenceLogTag: "scope_violation"
            ),
            SecurityClaim(
                id: "SC-006",
                invariant: "Human approval via Secure Enclave signature",
                enforcementPoint: "ExecutionEngine HARD GATE 6 — verifySignature",
                testCoverage: "AdversarialSecuritySimulationTests.testIntegrityGuardProducesReport",
                evidenceLogTag: "human_approval"
            ),
            SecurityClaim(
                id: "SC-007",
                invariant: "Key rotation immediately invalidates old tokens",
                enforcementPoint: "TrustEpochManager.rotateKey() + ExecutionEngine HARD GATE 4",
                testCoverage: "AdversarialSecuritySimulationTests.testTokenWithOldKeyVersionFails",
                evidenceLogTag: "key_rotation"
            ),
            SecurityClaim(
                id: "SC-008",
                invariant: "Revoked devices cannot issue or execute tokens",
                enforcementPoint: "TrustedDeviceRegistry + ExecutionEngine HARD GATE 5",
                testCoverage: "AdversarialSecuritySimulationTests.testRevokedDeviceCannotPassTrustCheck",
                evidenceLogTag: "device_revoked"
            ),
            SecurityClaim(
                id: "SC-009",
                invariant: "Quorum enforcement by risk tier",
                enforcementPoint: "CapabilityKernel.validateQuorum() + ExecutionEngine HARD GATE 7",
                testCoverage: "AdversarialSecuritySimulationTests.testQuorumFailsWithMissingSigner",
                evidenceLogTag: "quorum_violation"
            ),
            SecurityClaim(
                id: "SC-010",
                invariant: "Network egress controlled by NetworkPolicyEnforcer",
                enforcementPoint: "NetworkPolicyEnforcer.validate() on all URLSession paths",
                testCoverage: "EnterpriseFirewallTests (network firewall)",
                evidenceLogTag: "network_policy_violation"
            ),
            SecurityClaim(
                id: "SC-011",
                invariant: "Background tasks cannot reach ExecutionEngine or Services",
                enforcementPoint: "Module boundary — no imports",
                testCoverage: "EnterpriseFirewallTests.testBackgroundFilesContainNoForbiddenSymbols",
                evidenceLogTag: "bg_proposal_prepared"
            ),
            SecurityClaim(
                id: "SC-012",
                invariant: "Webhook/deep link nonces are single-use",
                enforcementPoint: "WebhookHandler + NotificationBridge ConsumedTokenStore",
                testCoverage: "AdversarialSecuritySimulationTests.testNonceConsumedOnceOnly",
                evidenceLogTag: "webhook_violation"
            ),
            SecurityClaim(
                id: "SC-013",
                invariant: "Kernel self-integrity check on every launch",
                enforcementPoint: "KernelIntegrityGuard.performFullCheck() in onAppear",
                testCoverage: "AdversarialSecuritySimulationTests.testIntegrityGuardProducesReport",
                evidenceLogTag: "kernel_integrity_failure"
            ),
        ]
    }

    // =========================================================================
    // 2. THREAT MODEL
    // =========================================================================

    public struct ThreatModelEntry: Codable, Identifiable {
        public let id: String
        public let asset: String
        public let trustBoundary: String
        public let attacker: String
        public let threat: String
        public let mitigation: String
        public let claimRef: String
    }

    public func generateThreatModel() -> [ThreatModelEntry] {
        return [
            ThreatModelEntry(id: "TM-001", asset: "AuthorizationToken", trustBoundary: "CapabilityKernel → ExecutionEngine", attacker: "Malicious code in module", threat: "Forge or replay token", mitigation: "HMAC signature + one-use consumption + durable store + epoch binding", claimRef: "SC-001, SC-002"),
            ThreatModelEntry(id: "TM-002", asset: "Evidence Chain", trustBoundary: "EvidenceEngine → storage", attacker: "Privileged local attacker", threat: "Tamper with audit log", mitigation: "Hash-chained ledger + remote mirror attestation", claimRef: "SC-003"),
            ThreatModelEntry(id: "TM-003", asset: "User PII in prompts", trustBoundary: "Device → Cloud AI provider", attacker: "Cloud provider / network eavesdropper", threat: "Data exfiltration", mitigation: "DataDiode referential tokenization + HTTPS + domain allowlist", claimRef: "SC-004, SC-010"),
            ThreatModelEntry(id: "TM-004", asset: "Calendar/Mail/Reminder data", trustBoundary: "ExecutionEngine → OS services", attacker: "Autonomous agent code", threat: "Unauthorized mutations", mitigation: "ServiceAccessToken + KernelAuthorizationToken + scope enforcement", claimRef: "SC-005"),
            ThreatModelEntry(id: "TM-005", asset: "Signing keys", trustBoundary: "Keychain / Secure Enclave", attacker: "Key compromise via backup", threat: "Token forgery after key extraction", mitigation: "Key rotation + epoch advancement + revocation", claimRef: "SC-007"),
            ThreatModelEntry(id: "TM-006", asset: "Device identity", trustBoundary: "TrustedDeviceRegistry", attacker: "Stolen/lost device", threat: "Continued execution from untrusted hardware", mitigation: "Remote device revocation + epoch advance + lockdown", claimRef: "SC-008"),
            ThreatModelEntry(id: "TM-007", asset: "Execution budget", trustBoundary: "EconomicGovernor", attacker: "Runaway autonomous loop", threat: "Uncontrolled cloud spend", mitigation: "EconomicGovernor budget gates + kill switch", claimRef: "SC-004"),
            ThreatModelEntry(id: "TM-008", asset: "Deep link actions", trustBoundary: "Notification → App", attacker: "Crafted notification", threat: "Trigger execution via deep link", mitigation: "Signed nonce + one-time consumption + navigation-only routing", claimRef: "SC-012"),
            ThreatModelEntry(id: "TM-009", asset: "Background execution", trustBoundary: "BGTaskScheduler → BackgroundTaskQueue", attacker: "BG code path gaining execution access", threat: "Side effects from background without approval", mitigation: "Module boundary — zero imports of ExecutionEngine/Services", claimRef: "SC-011"),
            ThreatModelEntry(id: "TM-010", asset: "Kernel integrity", trustBoundary: "App launch", attacker: "Tampered binary / corrupted state", threat: "Operating with compromised kernel", mitigation: "KernelIntegrityGuard 5-point check + automatic lockdown", claimRef: "SC-013"),
        ]
    }

    // =========================================================================
    // 3. INCIDENT RUNBOOK
    // =========================================================================

    public struct RunbookEntry: Codable, Identifiable {
        public let id: String
        public let trigger: String
        public let cause: String
        public let immediateAction: String
        public let recoverySteps: [String]
        public let escalation: String
    }

    public func generateRunbook() -> [RunbookEntry] {
        return [
            RunbookEntry(
                id: "RB-001",
                trigger: "KernelIntegrityFailure → EXECUTION LOCKDOWN",
                cause: "Signing keys missing, revoked key active, device registry corruption, evidence chain broken, or mirror divergence",
                immediateAction: "All execution blocked. No tokens issued. Mission Control shows lockdown banner.",
                recoverySteps: [
                    "1. Navigate to System Integrity screen",
                    "2. Review failed checks in detail",
                    "3. If key issue: rotate keys (Config > Enterprise > Kill Switches)",
                    "4. If evidence corruption: export audit packet for forensics",
                    "5. If device issue: re-register device in Trust Registry",
                    "6. Tap 'Attempt Recovery' to re-run integrity checks",
                    "7. If recovery fails: contact org admin for co-signed recovery"
                ],
                escalation: "Org admin must review IntegrityReport.json and approve recovery"
            ),
            RunbookEntry(
                id: "RB-002",
                trigger: "EvidenceDivergenceViolation",
                cause: "Local evidence chain hash differs from mirrored server hash",
                immediateAction: "Trust epoch advanced. Integrity incident logged.",
                recoverySteps: [
                    "1. Export local evidence chain (Audit Status > Export)",
                    "2. Compare with server mirror records",
                    "3. Identify divergence point (timestamp + entry index)",
                    "4. If local tamper suspected: forensic review required",
                    "5. If server error: re-push attestation after verification"
                ],
                escalation: "Security team forensic review"
            ),
            RunbookEntry(
                id: "RB-003",
                trigger: "Key rotation required",
                cause: "Scheduled rotation, suspected compromise, or policy mandate",
                immediateAction: "Navigate to Config > Enterprise > Kill Switches or Trust Registry",
                recoverySteps: [
                    "1. Tap 'Rotate Keys' with reason",
                    "2. Old key version is immediately revoked",
                    "3. All in-flight tokens become invalid",
                    "4. New tokens issued with new key version",
                    "5. Trust epoch advances automatically"
                ],
                escalation: "N/A — admin self-service"
            ),
            RunbookEntry(
                id: "RB-004",
                trigger: "Device revocation",
                cause: "Device lost, stolen, employee departure, or policy violation",
                immediateAction: "Navigate to Trust Registry > tap device > Revoke",
                recoverySteps: [
                    "1. Confirm revocation (includes reason)",
                    "2. Trust epoch advances",
                    "3. Revoked device cannot issue or execute tokens",
                    "4. Evidence logged with revocation reason",
                    "5. Org co-signer updated if applicable"
                ],
                escalation: "N/A — admin self-service"
            ),
        ]
    }

    // =========================================================================
    // 4. FULL ENTERPRISE REVIEW PACK EXPORT
    // =========================================================================

    public struct EnterpriseReviewPack: Codable {
        public let generatedAt: Date
        public let appVersion: String
        public let deviceFingerprint: String?
        public let trustEpoch: Int
        public let keyVersion: Int
        public let systemPosture: String
        public let securityClaims: [SecurityClaim]
        public let threatModel: [ThreatModelEntry]
        public let runbook: [RunbookEntry]
        public let compliancePacket: EvidenceMirrorClient.ComplianceAuditPacket
        public let deviceRegistrySnapshot: [DeviceSnapshot]
        public let featureFlagState: [String: Bool]
    }

    public struct DeviceSnapshot: Codable {
        public let fingerprint: String
        public let displayName: String
        public let trustState: String
        public let registeredAt: Date
    }

    public func exportReviewPack() -> URL? {
        isExporting = true
        defer { isExporting = false }

        let claims = generateSecurityClaims()
        let threats = generateThreatModel()
        let runbook = generateRunbook()
        let compliance = EvidenceMirrorClient.shared.generateCompliancePacket()

        let devices = TrustedDeviceRegistry.shared.devices.map {
            DeviceSnapshot(
                fingerprint: String($0.devicePublicKeyFingerprint.prefix(16)) + "...",
                displayName: $0.displayName,
                trustState: $0.trustState.rawValue,
                registeredAt: $0.registeredAt
            )
        }

        let flags: [String: Bool] = [
            "cloudModelsEnabled": IntelligenceFeatureFlags.cloudModelsEnabled,
            "apnsEnabled": EnterpriseFeatureFlags.apnsEnabled,
            "mirrorEnabled": EnterpriseFeatureFlags.mirrorEnabled,
            "orgCoSignEnabled": EnterpriseFeatureFlags.orgCoSignEnabled,
            "bgAutonomyEnabled": EnterpriseFeatureFlags.backgroundAutonomyEnabled,
            "executionKillSwitch": EnterpriseFeatureFlags.executionKillSwitch,
            "cloudKillSwitch": EnterpriseFeatureFlags.cloudKillSwitch,
        ]

        let pack = EnterpriseReviewPack(
            generatedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            deviceFingerprint: SecureEnclaveApprover.shared.deviceFingerprint,
            trustEpoch: TrustEpochManager.shared.trustEpoch,
            keyVersion: TrustEpochManager.shared.activeKeyVersion,
            systemPosture: KernelIntegrityGuard.shared.systemPosture.rawValue,
            securityClaims: claims,
            threatModel: threats,
            runbook: runbook,
            compliancePacket: compliance,
            deviceRegistrySnapshot: devices,
            featureFlagState: flags
        )

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("EnterpriseReviewPack", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Write individual artifacts
        writeJSON(pack.securityClaims, to: dir.appendingPathComponent("SecurityClaimsMatrix.json"))
        writeJSON(pack.threatModel, to: dir.appendingPathComponent("ThreatModel.json"))
        writeJSON(pack.runbook, to: dir.appendingPathComponent("IncidentRunbook.json"))
        writeJSON(pack.compliancePacket, to: dir.appendingPathComponent("CompliancePacket.json"))

        // Write full pack
        let fullFile = dir.appendingPathComponent("EnterpriseReviewPack.json")
        writeJSON(pack, to: fullFile)

        lastExportAt = Date()
        lastExportPath = dir.path

        log("[REVIEW_PACK] Exported to \(dir.path)")
        return dir
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
