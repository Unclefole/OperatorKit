import Foundation
import CryptoKit

// ============================================================================
// EXECUTION CERTIFICATE — Cryptographic Non-Repudiation Record
//
// WHO approved, WHAT was executed, WHY it was allowed, WHICH connector
// acted, WHEN it happened, UNDER WHICH policy.
//
// INVARIANT: Generated ONLY after a valid AuthorizationToken is consumed.
// INVARIANT: Not forgeable from outside CapabilityKernel execution path.
// INVARIANT: Contains ONLY hashes — never raw prompts, tokens, or PII.
// INVARIANT: Signature from device-bound key (Secure Enclave / Keychain).
// INVARIANT: Immutable after creation.
// INVARIANT: Certificate generation MUST NOT block execution (>50ms budget).
// INVARIANT: If certificate generation fails → FAIL CLOSED → abort execution.
//
// "Execution receipt for intelligent machines."
// ============================================================================

// MARK: - Execution Certificate

/// Cryptographically sealed, tamper-evident execution record.
/// Stores ONLY hashes of sensitive inputs — never plaintext.
public struct ExecutionCertificate: Sendable, Identifiable, Codable {

    // ── Identity ──────────────────────────────────────
    public let id: UUID                          // certificateId
    public let timestamp: Date                   // When certificate was created

    // ── Execution Context (all hashed) ────────────────
    public let intentHash: String                // SHA256 of intent action + target
    public let proposalHash: String              // SHA256 of proposal/plan content

    // ── Authorization (hashed) ────────────────────────
    public let authorizationTokenHash: String    // SHA256 of token ID + planId + signature
    public let approverIdHash: String            // SHA256 of approver identifier
    public let deviceKeyId: String               // Public key fingerprint of signing device

    // ── Connector (optional) ──────────────────────────
    public let connectorId: String?              // Connector ID if a connector was involved
    public let connectorVersion: String?         // Connector version

    // ── Policy Snapshot ───────────────────────────────
    public let riskTier: RiskTier                // Risk tier at approval time
    public let policySnapshotHash: String        // SHA256 of policy state at execution time

    // ── Result ────────────────────────────────────────
    public let resultHash: String                // SHA256 of execution result summary

    // ── Cryptographic Seal ────────────────────────────
    public let signature: Data                   // ECDSA-P256 signature over canonical payload
    public let signerPublicKey: Data             // Public key that produced the signature

    // ── Enclave Backing ──────────────────────────────
    /// Whether the signing key is backed by Secure Enclave hardware.
    /// `false` on simulator or devices without SE (logged as enclave_unavailable_simulator).
    public let enclaveBacked: Bool

    // ── Hash Chain ────────────────────────────────────
    public let certificateHash: String           // SHA256 of this certificate's content
    public let previousCertificateHash: String   // SHA256 of the previous certificate (chain link)

    // MARK: - Memberwise Init

    public init(
        id: UUID,
        timestamp: Date,
        intentHash: String,
        proposalHash: String,
        authorizationTokenHash: String,
        approverIdHash: String,
        deviceKeyId: String,
        connectorId: String?,
        connectorVersion: String?,
        riskTier: RiskTier,
        policySnapshotHash: String,
        resultHash: String,
        signature: Data,
        signerPublicKey: Data,
        enclaveBacked: Bool = false,
        certificateHash: String,
        previousCertificateHash: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.intentHash = intentHash
        self.proposalHash = proposalHash
        self.authorizationTokenHash = authorizationTokenHash
        self.approverIdHash = approverIdHash
        self.deviceKeyId = deviceKeyId
        self.connectorId = connectorId
        self.connectorVersion = connectorVersion
        self.riskTier = riskTier
        self.policySnapshotHash = policySnapshotHash
        self.resultHash = resultHash
        self.signature = signature
        self.signerPublicKey = signerPublicKey
        self.enclaveBacked = enclaveBacked
        self.certificateHash = certificateHash
        self.previousCertificateHash = previousCertificateHash
    }

    // ── Computed Properties ───────────────────────────

    /// Canonical payload that was signed.
    /// This is the exact byte sequence the signature covers.
    public var canonicalPayload: Data {
        let canonical = [
            id.uuidString,
            timestamp.ISO8601Format(),
            intentHash,
            proposalHash,
            authorizationTokenHash,
            approverIdHash,
            deviceKeyId,
            connectorId ?? "none",
            connectorVersion ?? "none",
            riskTier.rawValue,
            policySnapshotHash,
            resultHash,
            previousCertificateHash
        ].joined(separator: "|")
        return Data(canonical.utf8)
    }

    /// Verify the signature against the stored public key.
    public func verifySignature() -> Bool {
        guard let publicKey = try? P256.Signing.PublicKey(x963Representation: signerPublicKey) else {
            return false
        }
        guard let ecdsaSignature = try? P256.Signing.ECDSASignature(derRepresentation: signature) else {
            return false
        }
        return publicKey.isValidSignature(ecdsaSignature, for: canonicalPayload)
    }

    /// Verify the certificate hash is consistent.
    public func verifyHash() -> Bool {
        let computed = ExecutionCertificate.computeHash(
            intentHash: intentHash,
            proposalHash: proposalHash,
            authorizationTokenHash: authorizationTokenHash,
            resultHash: resultHash,
            timestamp: timestamp,
            previousCertificateHash: previousCertificateHash
        )
        return computed == certificateHash
    }

    /// Full verification: signature + hash integrity.
    public var isValid: Bool {
        verifySignature() && verifyHash()
    }

    // ── Static Hash Helpers ───────────────────────────

    /// Compute certificate hash from components.
    public static func computeHash(
        intentHash: String,
        proposalHash: String,
        authorizationTokenHash: String,
        resultHash: String,
        timestamp: Date,
        previousCertificateHash: String
    ) -> String {
        let material = "\(intentHash)|\(proposalHash)|\(authorizationTokenHash)|\(resultHash)|\(timestamp.ISO8601Format())|\(previousCertificateHash)"
        return sha256Hex(material)
    }

    /// SHA256 hex digest of a string.
    public static func sha256Hex(_ input: String) -> String {
        let data = Data(input.utf8)
        return SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    /// SHA256 hex digest of Data.
    public static func sha256HexData(_ data: Data) -> String {
        SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: - Codable (backward-compatible with pre-enclaveBacked certificates)

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, intentHash, proposalHash
        case authorizationTokenHash, approverIdHash, deviceKeyId
        case connectorId, connectorVersion
        case riskTier, policySnapshotHash, resultHash
        case signature, signerPublicKey
        case enclaveBacked
        case certificateHash, previousCertificateHash
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        intentHash = try container.decode(String.self, forKey: .intentHash)
        proposalHash = try container.decode(String.self, forKey: .proposalHash)
        authorizationTokenHash = try container.decode(String.self, forKey: .authorizationTokenHash)
        approverIdHash = try container.decode(String.self, forKey: .approverIdHash)
        deviceKeyId = try container.decode(String.self, forKey: .deviceKeyId)
        connectorId = try container.decodeIfPresent(String.self, forKey: .connectorId)
        connectorVersion = try container.decodeIfPresent(String.self, forKey: .connectorVersion)
        riskTier = try container.decode(RiskTier.self, forKey: .riskTier)
        policySnapshotHash = try container.decode(String.self, forKey: .policySnapshotHash)
        resultHash = try container.decode(String.self, forKey: .resultHash)
        signature = try container.decode(Data.self, forKey: .signature)
        signerPublicKey = try container.decode(Data.self, forKey: .signerPublicKey)
        // Backward compatible: defaults to false for pre-existing certificates
        enclaveBacked = try container.decodeIfPresent(Bool.self, forKey: .enclaveBacked) ?? false
        certificateHash = try container.decode(String.self, forKey: .certificateHash)
        previousCertificateHash = try container.decode(String.self, forKey: .previousCertificateHash)
    }
}

// MARK: - Certificate Verification Status

/// Human-readable verification result for UI display.
public struct CertificateVerificationStatus: Sendable {
    public let signatureValid: Bool
    public let hashIntegrity: Bool
    public let chainIntact: Bool
    public let verifiedAt: Date

    public var allValid: Bool {
        signatureValid && hashIntegrity && chainIntact
    }

    public var summary: String {
        if allValid { return "All checks passed" }
        var issues: [String] = []
        if !signatureValid { issues.append("signature invalid") }
        if !hashIntegrity { issues.append("hash tampered") }
        if !chainIntact { issues.append("chain broken") }
        return "Issues: \(issues.joined(separator: ", "))"
    }
}

// MARK: - Certificate Export Bundle (Enterprise Audit)

/// Signed bundle for external auditors. Contains NO secrets.
public struct CertificateExportBundle: Sendable, Codable {
    public let certificate: ExecutionCertificate
    public let signerPublicKeyHex: String
    public let hashChainProof: [String]           // Chain of hashes back to root
    public let exportedAt: Date
    public let exportSignature: Data              // Signature over the export itself
}
