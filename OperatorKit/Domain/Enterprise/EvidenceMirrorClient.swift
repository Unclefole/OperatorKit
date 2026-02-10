import Foundation
import CryptoKit

// ============================================================================
// EVIDENCE MIRROR CLIENT — Real Remote Endpoint + Retention + Compliance Export
//
// INVARIANT: Server stores immutable append-only records (WORM semantics).
// INVARIANT: Server cannot authorize, forge signatures, or mutate history.
// INVARIANT: Divergence detection raises EvidenceDivergenceViolation.
// INVARIANT: Network is feature-flag gated.
// ============================================================================

@MainActor
public final class EvidenceMirrorClient: ObservableObject {

    public static let shared = EvidenceMirrorClient()

    @Published private(set) var isConfigured: Bool = false
    @Published private(set) var mirrorEndpoint: URL?
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var syncStatus: SyncStatus = .idle

    public enum SyncStatus: String {
        case idle = "idle"
        case syncing = "syncing"
        case synced = "synced"
        case failed = "failed"
        case divergent = "DIVERGENT"
    }

    private init() {}

    // MARK: - Configuration

    public func configure(endpoint: URL) {
        self.mirrorEndpoint = endpoint
        self.isConfigured = true
        log("[MIRROR_CLIENT] Configured with endpoint: \(endpoint)")
    }

    // MARK: - Push Attestation

    /// Dev mode: use local in-process server adapter instead of network.
    @Published public var useDevServer: Bool = true

    /// Push a signed attestation. Uses DevServerAdapter in dev mode, real HTTP in prod.
    public func pushAttestation(_ attestation: EvidenceMirror.Attestation) async -> Bool {
        guard isConfigured else {
            logError("[MIRROR_CLIENT] Not configured")
            return false
        }

        syncStatus = .syncing

        if useDevServer {
            // Dev mode: in-process crypto-real server
            let receipt = DevServerAdapter.shared.handleMirrorAttestation(attestation)
            lastSyncAt = Date()
            lastReceipt = receipt
            syncStatus = receipt.verified ? .synced : .failed
            log("[MIRROR_CLIENT] Dev attestation pushed: index=\(receipt.serverIndex), verified=\(receipt.verified)")
            return receipt.verified
        }

        // Prod mode: real HTTP endpoint
        guard let endpoint = mirrorEndpoint else { return false }
        do {
            var request = URLRequest(url: endpoint.appendingPathComponent("/api/v1/mirror/attest"))
            request.httpMethod = "POST"
            request.httpBody = try JSONEncoder().encode(attestation)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("OperatorKit-Mirror/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 30

            let (_, response) = try await NetworkPolicyEnforcer.shared.execute(request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                syncStatus = .failed
                return false
            }

            lastSyncAt = Date()
            syncStatus = .synced
            log("[MIRROR_CLIENT] Attestation pushed successfully")
            return true

        } catch {
            logError("[MIRROR_CLIENT] Push failed: \(error)")
            syncStatus = .failed
            return false
        }
    }

    /// Latest attestation receipt (dev mode)
    @Published public var lastReceipt: DevServerAdapter.AttestationReceipt?

    // MARK: - Verify Against Server

    /// Fetch the latest chain hash from the server and compare with local.
    public func verifyConsistency() async -> Bool {
        if useDevServer {
            guard let fingerprint = SecureEnclaveApprover.shared.deviceFingerprint else { return false }
            guard let state = DevServerAdapter.shared.latestMirrorState(for: fingerprint) else { return true }
            let divergence = EvidenceMirror.shared.verifyAgainstMirror(
                mirroredChainHash: state.chainHash,
                mirroredEntryCount: state.entryCount
            )
            if divergence != nil {
                syncStatus = .divergent
                return false
            }
            syncStatus = .synced
            return true
        }

        guard isConfigured, let endpoint = mirrorEndpoint else { return false }
        guard let fingerprint = SecureEnclaveApprover.shared.deviceFingerprint else { return false }

        do {
            var request = URLRequest(url: endpoint.appendingPathComponent("/api/v1/mirror/latest"))
            request.httpMethod = "GET"
            request.setValue(fingerprint, forHTTPHeaderField: "X-Device-Fingerprint")
            request.timeoutInterval = 15

            let (data, response) = try await NetworkPolicyEnforcer.shared.execute(request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return false }

            let serverState = try JSONDecoder().decode(ServerMirrorState.self, from: data)

            // Compare
            let divergence = EvidenceMirror.shared.verifyAgainstMirror(
                mirroredChainHash: serverState.chainHash,
                mirroredEntryCount: serverState.entryCount
            )

            if divergence != nil {
                syncStatus = .divergent
                // Notify
                NotificationBridge.shared.scheduleIntegrityLockdown(reason: "Evidence divergence detected")
                return false
            }

            syncStatus = .synced
            return true

        } catch {
            logError("[MIRROR_CLIENT] Verification failed: \(error)")
            return false
        }
    }

    struct ServerMirrorState: Codable {
        let chainHash: String
        let entryCount: Int
        let lastAttestedAt: Date
    }

    // MARK: - Compliance Export

    /// Generate a compliance audit packet as a dictionary (can be serialized to JSON/zip).
    public func generateCompliancePacket() -> ComplianceAuditPacket {
        let epochManager = TrustEpochManager.shared
        let deviceRegistry = TrustedDeviceRegistry.shared
        let integrityGuard = KernelIntegrityGuard.shared
        let evidenceEngine = EvidenceEngine.shared

        let chainReport = try? evidenceEngine.verifyChainIntegrity()

        return ComplianceAuditPacket(
            generatedAt: Date(),
            deviceFingerprint: SecureEnclaveApprover.shared.deviceFingerprint ?? "unknown",
            trustEpoch: epochManager.trustEpoch,
            activeKeyVersion: epochManager.activeKeyVersion,
            revokedKeyVersions: Array(epochManager.revokedKeyVersions),
            registeredDevices: deviceRegistry.devices.map { device in
                ComplianceAuditPacket.DeviceSummary(
                    fingerprint: device.devicePublicKeyFingerprint,
                    trustState: device.trustState.rawValue,
                    registeredAt: device.registeredAt,
                    revokedAt: device.revokedAt
                )
            },
            evidenceEntryCount: evidenceEngine.entryCount,
            evidenceChainValid: chainReport?.overallValid ?? false,
            evidenceViolations: chainReport?.violations.count ?? 0,
            systemPosture: integrityGuard.systemPosture.rawValue,
            lastIntegrityCheckAt: integrityGuard.lastCheckAt,
            mirrorSyncStatus: syncStatus.rawValue,
            lastMirrorSyncAt: lastSyncAt,
            attestationCount: EvidenceMirror.shared.attestationHistory.count,
            latestAttestationChainHash: EvidenceMirror.shared.lastMirroredChainHash
        )
    }

    // MARK: - Compliance Packet Type

    public struct ComplianceAuditPacket: Codable {
        public let generatedAt: Date
        public let deviceFingerprint: String
        public let trustEpoch: Int
        public let activeKeyVersion: Int
        public let revokedKeyVersions: [Int]
        public let registeredDevices: [DeviceSummary]
        public let evidenceEntryCount: Int
        public let evidenceChainValid: Bool
        public let evidenceViolations: Int
        public let systemPosture: String
        public let lastIntegrityCheckAt: Date?
        public let mirrorSyncStatus: String
        public let lastMirrorSyncAt: Date?
        public let attestationCount: Int
        public let latestAttestationChainHash: String?

        public struct DeviceSummary: Codable {
            public let fingerprint: String
            public let trustState: String
            public let registeredAt: Date
            public let revokedAt: Date?
        }
    }
}
