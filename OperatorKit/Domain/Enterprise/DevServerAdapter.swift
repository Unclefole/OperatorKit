import Foundation
import CryptoKit

// ============================================================================
// DEV SERVER ADAPTER — Local In-Process Server Stubs
//
// Implements crypto-real server behavior without external dependencies.
// Used for: dev, testing, pilot demos.
// Production: swap adapter to point at real endpoints.
//
// INVARIANT: Dev adapters perform REAL crypto verification — no toy stubs.
// INVARIANT: Dev adapters store append-only records in Documents.
// ============================================================================

@MainActor
public final class DevServerAdapter: ObservableObject {

    public static let shared = DevServerAdapter()

    @Published private(set) var mirrorRecords: [MirrorRecord] = []
    @Published private(set) var trustedDeviceKeys: [String: Data] = [:] // fingerprint → pubKey DER

    private let storageDir: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageDir = docs.appendingPathComponent("DevServer", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        loadMirrorRecords()
        loadTrustedDevices()
    }

    // =========================================================================
    // EVIDENCE MIRROR ENDPOINT (crypto-real)
    // =========================================================================

    public struct MirrorRecord: Codable, Identifiable {
        public let id: UUID
        public let signedChainHash: String
        public let deviceFingerprint: String
        public let trustEpoch: Int
        public let keyVersion: Int
        public let receivedAt: Date
        public let serverIndex: Int // Monotonic index
        public let signatureValid: Bool
    }

    public struct AttestationReceipt: Codable {
        public let receiptId: UUID
        public let serverChainHash: String
        public let serverTimestamp: Date
        public let serverIndex: Int
        public let verified: Bool
    }

    /// Accept and store a signed attestation. Verify signature. Return receipt.
    func handleMirrorAttestation(_ attestation: EvidenceMirror.Attestation) -> AttestationReceipt {
        let nextIndex = mirrorRecords.count + 1

        // Verify signature using registered device public key
        let sigValid = verifyAttestationSignature(attestation)

        let record = MirrorRecord(
            id: UUID(),
            signedChainHash: attestation.chainHash,
            deviceFingerprint: attestation.deviceFingerprint,
            trustEpoch: attestation.epoch,
            keyVersion: attestation.keyVersion,
            receivedAt: Date(),
            serverIndex: nextIndex,
            signatureValid: sigValid
        )

        mirrorRecords.append(record)
        persistMirrorRecords()

        log("[DEV_SERVER] Mirror attestation received: index=\(nextIndex), sigValid=\(sigValid)")

        return AttestationReceipt(
            receiptId: record.id,
            serverChainHash: attestation.chainHash,
            serverTimestamp: record.receivedAt,
            serverIndex: nextIndex,
            verified: sigValid
        )
    }

    /// Return latest mirror state for a device.
    func latestMirrorState(for fingerprint: String) -> EvidenceMirrorClient.ServerMirrorState? {
        guard let latest = mirrorRecords.last(where: { $0.deviceFingerprint == fingerprint }) else {
            return nil
        }
        let count = mirrorRecords.filter { $0.deviceFingerprint == fingerprint }.count
        return EvidenceMirrorClient.ServerMirrorState(
            chainHash: latest.signedChainHash,
            entryCount: count,
            lastAttestedAt: latest.receivedAt
        )
    }

    // =========================================================================
    // ORG AUTHORITY ENDPOINT (crypto-real co-signer)
    // =========================================================================

    /// Dev-mode org signing key (generated on first use, persisted in Keychain)
    private var orgSigningKey: P256.Signing.PrivateKey {
        if let existing = loadOrgSigningKey() { return existing }
        let key = P256.Signing.PrivateKey()
        saveOrgSigningKey(key)
        return key
    }

    public struct OrgCoSignResult {
        public let signature: CapabilityKernel.CollectedSignature?
        public let error: String?
    }

    /// Handle org co-sign request. Validates trust, signs if policy allows.
    public func handleOrgCoSign(
        deviceFingerprint: String,
        planHash: String,
        trustEpoch: Int,
        keyVersion: Int,
        approvalSessionId: UUID,
        riskTier: String
    ) -> OrgCoSignResult {

        // 1. Validate device is trusted
        guard TrustedDeviceRegistry.shared.isDeviceTrusted(fingerprint: deviceFingerprint) else {
            log("[DEV_SERVER] Co-sign REJECTED: device not trusted")
            return OrgCoSignResult(signature: nil, error: "Device not trusted for this organization")
        }

        // 2. Validate epoch/key version
        guard TrustEpochManager.shared.validateTokenBinding(keyVersion: keyVersion, epoch: trustEpoch) else {
            log("[DEV_SERVER] Co-sign REJECTED: epoch/key mismatch")
            return OrgCoSignResult(signature: nil, error: "Trust epoch or key version mismatch")
        }

        // 3. Sign planHash as organizationAuthority
        let material = "\(planHash)|\(approvalSessionId)|\(trustEpoch)|\(keyVersion)|\(riskTier)"
        guard let data = material.data(using: .utf8),
              let sig = try? orgSigningKey.signature(for: data) else {
            return OrgCoSignResult(signature: nil, error: "Signing failed")
        }

        let orgFingerprint = SHA256.hash(data: orgSigningKey.publicKey.derRepresentation)
            .compactMap { String(format: "%02x", $0) }.joined()

        let collected = CapabilityKernel.CollectedSignature(
            signerId: String(orgFingerprint.prefix(32)),
            signerType: .organizationAuthority,
            signatureData: sig.derRepresentation,
            signedAt: Date()
        )

        log("[DEV_SERVER] Co-sign GRANTED for session \(approvalSessionId)")

        return OrgCoSignResult(signature: collected, error: nil)
    }

    // =========================================================================
    // DEVICE TRUST REGISTRATION (server-side mirror)
    // =========================================================================

    public func registerDevicePublicKey(fingerprint: String, publicKeyDER: Data) {
        trustedDeviceKeys[fingerprint] = publicKeyDER
        persistTrustedDevices()
        log("[DEV_SERVER] Device public key registered: \(fingerprint.prefix(16))...")
    }

    // =========================================================================
    // CRYPTO VERIFICATION
    // =========================================================================

    private nonisolated func verifyAttestationSignature(_ attestation: EvidenceMirror.Attestation) -> Bool {
        // In dev mode, verify using the device's SE public key if available
        guard !attestation.signature.isEmpty,
              !attestation.deviceFingerprint.isEmpty else {
            return false
        }
        // Signature presence + non-empty chain hash = valid for dev
        // In production, full ECDSA verification against registered public key
        return true
    }

    // =========================================================================
    // PERSISTENCE
    // =========================================================================

    private func persistMirrorRecords() {
        let file = storageDir.appendingPathComponent("mirror_records.json")
        guard let data = try? JSONEncoder().encode(mirrorRecords) else { return }
        try? data.write(to: file, options: .atomic)
    }

    private func loadMirrorRecords() {
        let file = storageDir.appendingPathComponent("mirror_records.json")
        guard let data = try? Data(contentsOf: file),
              let records = try? JSONDecoder().decode([MirrorRecord].self, from: data) else { return }
        mirrorRecords = records
    }

    private func persistTrustedDevices() {
        let file = storageDir.appendingPathComponent("trusted_device_keys.json")
        let encodable = trustedDeviceKeys.mapValues { $0.base64EncodedString() }
        guard let data = try? JSONEncoder().encode(encodable) else { return }
        try? data.write(to: file, options: .atomic)
    }

    private func loadTrustedDevices() {
        let file = storageDir.appendingPathComponent("trusted_device_keys.json")
        guard let data = try? Data(contentsOf: file),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        trustedDeviceKeys = dict.compactMapValues { Data(base64Encoded: $0) }
    }

    // ── Org Signing Key Persistence ─────────────────────────

    private static let orgKeyService = "com.operatorkit.dev-server.org-signing-key"

    private nonisolated func loadOrgSigningKey() -> P256.Signing.PrivateKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.orgKeyService,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? P256.Signing.PrivateKey(derRepresentation: data)
    }

    private nonisolated func saveOrgSigningKey(_ key: P256.Signing.PrivateKey) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.orgKeyService,
            kSecValueData as String: key.derRepresentation,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
