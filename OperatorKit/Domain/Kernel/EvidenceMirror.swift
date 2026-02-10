import Foundation
import CryptoKit

// ============================================================================
// EVIDENCE MIRROR — Remote Audit Attestation
//
// INVARIANT: Audit durability must not depend on device survival.
// INVARIANT: Server is a WITNESS — not a control plane.
// INVARIANT: Server cannot authorize, forge signatures, or mutate history.
// INVARIANT: Device signs chainHash using Secure Enclave private key.
// INVARIANT: Divergence between device + mirror triggers immediate violation.
//
// Pattern:
//   1. Device computes chainHash from hash-chained evidence ledger
//   2. Device signs chainHash with SE private key
//   3. Signed attestation pushed to remote storage periodically
//   4. Server stores immutable timeline of signed hashes
//   5. On verification: compare device chainHash vs mirrored history
//   6. Divergence → EvidenceDivergenceViolation → Mission Control alert
// ============================================================================

@MainActor
public final class EvidenceMirror: ObservableObject {

    public static let shared = EvidenceMirror()

    // MARK: - Published State

    @Published private(set) var lastAttestationAt: Date?
    @Published private(set) var lastMirroredChainHash: String?
    @Published private(set) var divergenceDetected: Bool = false
    @Published private(set) var attestationHistory: [Attestation] = []

    // MARK: - Types

    /// A signed attestation of the evidence chain state at a point in time.
    public struct Attestation: Codable, Identifiable {
        public let id: UUID
        public let chainHash: String
        public let entryCount: Int
        public let deviceFingerprint: String
        public let signature: Data         // SE-signed chainHash
        public let epoch: Int
        public let keyVersion: Int
        public let createdAt: Date
    }

    /// Divergence report when device and mirror disagree.
    public struct DivergenceReport: Codable {
        public let detectedAt: Date
        public let deviceChainHash: String
        public let mirroredChainHash: String
        public let deviceEntryCount: Int
        public let mirroredEntryCount: Int
    }

    // MARK: - Storage

    private let localAttestationFileURL: URL

    // MARK: - Init

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("KernelSecurity", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.localAttestationFileURL = dir.appendingPathComponent("attestation_history.json")
        loadAttestations()
    }

    // MARK: - Create Attestation

    /// Create a signed attestation of the current evidence chain state.
    /// This is called periodically or after significant evidence entries.
    public func createAttestation() async -> Attestation? {
        // Step 1: Verify chain integrity first
        guard let report = try? EvidenceEngine.shared.verifyChainIntegrity(),
              report.overallValid else {
            logError("[EVIDENCE_MIRROR] Cannot create attestation — chain integrity failed")
            return nil
        }

        // Step 2: Compute the chain hash (hash of all entry hashes)
        let chainHash = computeCurrentChainHash()
        guard !chainHash.isEmpty else {
            logError("[EVIDENCE_MIRROR] Cannot create attestation — empty chain hash")
            return nil
        }

        // Step 3: Sign with Secure Enclave
        guard let signature = await SecureEnclaveApprover.shared.signApproval(planHash: chainHash) else {
            logError("[EVIDENCE_MIRROR] Cannot create attestation — SE signing failed (biometric required)")
            return nil
        }

        let fingerprint = SecureEnclaveApprover.shared.deviceFingerprint ?? "unknown"
        let epochManager = TrustEpochManager.shared

        let attestation = Attestation(
            id: UUID(),
            chainHash: chainHash,
            entryCount: EvidenceEngine.shared.entryCount,
            deviceFingerprint: fingerprint,
            signature: signature,
            epoch: epochManager.trustEpoch,
            keyVersion: epochManager.activeKeyVersion,
            createdAt: Date()
        )

        // Step 4: Store locally
        attestationHistory.append(attestation)
        lastAttestationAt = attestation.createdAt
        lastMirroredChainHash = chainHash
        persistAttestations()

        log("[EVIDENCE_MIRROR] Attestation created: chain=\(chainHash.prefix(16))..., entries=\(attestation.entryCount)")

        // Step 5: Log to evidence chain
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "audit_attestation_created",
            planId: UUID(),
            jsonString: """
            {"chainHash":"\(chainHash.prefix(32))...","entryCount":\(attestation.entryCount),"epoch":\(attestation.epoch),"keyVersion":\(attestation.keyVersion)}
            """
        )

        return attestation
    }

    // MARK: - Push to Remote (Interface)

    /// Push attestation to remote storage.
    /// The remote endpoint is configured via enterprise settings.
    /// Remote server ONLY stores — it cannot modify or authorize.
    public func pushToRemote(_ attestation: Attestation, endpoint: URL) async throws {
        // Build the payload
        let payload = try JSONEncoder().encode(attestation)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("OperatorKit-EvidenceMirror/1.0", forHTTPHeaderField: "User-Agent")

        let (_, response) = try await NetworkPolicyEnforcer.shared.execute(request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            logError("[EVIDENCE_MIRROR] Remote push failed: non-2xx response")
            throw EvidenceMirrorError.remotePushFailed
        }

        log("[EVIDENCE_MIRROR] Attestation pushed to remote successfully")
    }

    // MARK: - Verify Against Mirror

    /// Verify the current chain against a mirrored chain hash from the server.
    /// If they diverge, triggers EvidenceDivergenceViolation.
    public func verifyAgainstMirror(mirroredChainHash: String, mirroredEntryCount: Int) -> DivergenceReport? {
        let deviceChainHash = computeCurrentChainHash()
        let deviceEntryCount = EvidenceEngine.shared.entryCount

        if deviceChainHash == mirroredChainHash && deviceEntryCount == mirroredEntryCount {
            divergenceDetected = false
            log("[EVIDENCE_MIRROR] Mirror verification PASSED")
            return nil
        }

        // DIVERGENCE DETECTED
        divergenceDetected = true
        let report = DivergenceReport(
            detectedAt: Date(),
            deviceChainHash: deviceChainHash,
            mirroredChainHash: mirroredChainHash,
            deviceEntryCount: deviceEntryCount,
            mirroredEntryCount: mirroredEntryCount
        )

        logError("[EVIDENCE_MIRROR] DIVERGENCE DETECTED — device chain does not match mirror")

        // Log violation
        try? EvidenceEngine.shared.logViolation(PolicyViolation(
            violationType: .dataCorruption,
            description: "Evidence divergence: device(\(deviceChainHash.prefix(16))..., \(deviceEntryCount) entries) vs mirror(\(mirroredChainHash.prefix(16))..., \(mirroredEntryCount) entries)",
            severity: .critical
        ), planId: UUID())

        // Advance epoch — this is a security event
        TrustEpochManager.shared.advanceEpoch(reason: "Evidence divergence detected")

        return report
    }

    // MARK: - Chain Hash Computation

    /// Compute the aggregate chain hash from all evidence entries.
    private nonisolated func computeCurrentChainHash() -> String {
        // Read the chain file and compute hash of all currentHash values
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let chainFile = docs.appendingPathComponent("EvidenceChain", isDirectory: true)
            .appendingPathComponent("chain.jsonl")

        guard let data = try? Data(contentsOf: chainFile),
              let content = String(data: data, encoding: .utf8) else {
            return ""
        }

        // Hash the entire chain file content
        let digest = SHA256.hash(data: content.data(using: .utf8)!)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Persistence

    private func loadAttestations() {
        guard let data = try? Data(contentsOf: localAttestationFileURL),
              let loaded = try? JSONDecoder().decode([Attestation].self, from: data) else {
            attestationHistory = []
            return
        }
        attestationHistory = loaded
        lastAttestationAt = loaded.last?.createdAt
        lastMirroredChainHash = loaded.last?.chainHash
    }

    private func persistAttestations() {
        guard let data = try? JSONEncoder().encode(attestationHistory) else { return }
        try? data.write(to: localAttestationFileURL, options: .atomic)
    }

    // MARK: - Errors

    public enum EvidenceMirrorError: Error {
        case remotePushFailed
        case chainIntegrityFailed
        case signingFailed
    }
}
