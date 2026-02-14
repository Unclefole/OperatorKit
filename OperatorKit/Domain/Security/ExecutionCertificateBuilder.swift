import Foundation
import CryptoKit

// ============================================================================
// EXECUTION CERTIFICATE BUILDER — Assembles & Signs Certificates
//
// INVARIANT: All inputs are hashed before inclusion.
// INVARIANT: Signing happens via ExecutionSigner (device-bound key).
// INVARIANT: Certificate is immutable after creation.
// INVARIANT: FAIL CLOSED if signing or hashing fails.
// INVARIANT: MUST complete within 50ms budget.
//
// EVIDENCE TAG: execution_certificate_created
// ============================================================================

// MARK: - Builder Errors

public enum CertificateBuilderError: Error, LocalizedError {
    case signingFailed(String)
    case publicKeyUnavailable
    case hashingFailed
    case storeAppendFailed(String)

    public var errorDescription: String? {
        switch self {
        case .signingFailed(let r): return "Certificate signing failed: \(r)"
        case .publicKeyUnavailable: return "Signer public key unavailable"
        case .hashingFailed: return "Certificate hashing failed"
        case .storeAppendFailed(let r): return "Certificate store append failed: \(r)"
        }
    }
}

// MARK: - Certificate Input

/// All inputs to the certificate builder.
/// These are hashed — never stored as plaintext.
public struct CertificateInput: Sendable {
    public let intentAction: String          // Will be hashed
    public let intentTarget: String?         // Will be hashed
    public let proposalSummary: String       // Will be hashed
    public let proposalStepCount: Int

    public let tokenId: UUID                 // Will be hashed
    public let tokenPlanId: UUID             // Will be hashed
    public let tokenSignature: String        // Will be hashed

    public let approverId: String            // Will be hashed
    public let riskTier: RiskTier

    public let connectorId: String?
    public let connectorVersion: String?

    public let resultSummary: String         // Will be hashed
    public let resultStatus: String

    public init(
        intentAction: String,
        intentTarget: String?,
        proposalSummary: String,
        proposalStepCount: Int,
        tokenId: UUID,
        tokenPlanId: UUID,
        tokenSignature: String,
        approverId: String,
        riskTier: RiskTier,
        connectorId: String? = nil,
        connectorVersion: String? = nil,
        resultSummary: String,
        resultStatus: String
    ) {
        self.intentAction = intentAction
        self.intentTarget = intentTarget
        self.proposalSummary = proposalSummary
        self.proposalStepCount = proposalStepCount
        self.tokenId = tokenId
        self.tokenPlanId = tokenPlanId
        self.tokenSignature = tokenSignature
        self.approverId = approverId
        self.riskTier = riskTier
        self.connectorId = connectorId
        self.connectorVersion = connectorVersion
        self.resultSummary = resultSummary
        self.resultStatus = resultStatus
    }
}

// MARK: - Execution Certificate Builder

public enum ExecutionCertificateBuilder {

    /// Build and sign an execution certificate.
    ///
    /// Steps:
    /// 1. Hash all inputs
    /// 2. Build canonical payload
    /// 3. Sign payload
    /// 4. Attach signature
    /// 5. Append to store
    /// 6. Log evidence
    ///
    /// FAIL CLOSED: any failure throws.
    public static func buildCertificate(
        input: CertificateInput
    ) throws -> ExecutionCertificate {
        let signer = ExecutionSigner.shared

        // Ensure signing key exists (FAIL CLOSED)
        try signer.generateKeyIfNeeded()

        // ── 1. Hash all inputs ───────────────────────────
        let intentHash = ExecutionCertificate.sha256Hex(
            "\(input.intentAction)|\(input.intentTarget ?? "none")"
        )
        let proposalHash = ExecutionCertificate.sha256Hex(
            "\(input.proposalSummary)|\(input.proposalStepCount)"
        )
        let authorizationTokenHash = ExecutionCertificate.sha256Hex(
            "\(input.tokenId.uuidString)|\(input.tokenPlanId.uuidString)|\(input.tokenSignature)"
        )
        let approverIdHash = ExecutionCertificate.sha256Hex(input.approverId)
        let resultHash = ExecutionCertificate.sha256Hex(
            "\(input.resultSummary)|\(input.resultStatus)"
        )

        // Policy snapshot: hash of current feature flag state
        let policySnapshotHash = ExecutionCertificate.sha256Hex(
            "cloudKill=\(EnterpriseFeatureFlags.cloudKillSwitch)|execKill=\(EnterpriseFeatureFlags.executionKillSwitch)|webRes=\(EnterpriseFeatureFlags.webResearchFullyEnabled)"
        )

        // Device key ID (public key fingerprint)
        let deviceKeyId: String
        do {
            deviceKeyId = try signer.publicKeyFingerprint()
        } catch {
            throw CertificateBuilderError.publicKeyUnavailable
        }

        // Public key data
        let publicKeyData: Data
        do {
            publicKeyData = try signer.publicKey()
        } catch {
            throw CertificateBuilderError.publicKeyUnavailable
        }

        // ── 2. Previous certificate hash (chain link) ────
        let previousHash = ExecutionCertificateStore.shared.lastCertificateHash ?? "GENESIS"

        // ── 3. Compute certificate hash ──────────────────
        let certificateHash = ExecutionCertificate.computeHash(
            intentHash: intentHash,
            proposalHash: proposalHash,
            authorizationTokenHash: authorizationTokenHash,
            resultHash: resultHash,
            timestamp: Date(),
            previousCertificateHash: previousHash
        )

        // ── 4. Build certificate (pre-signature) ────────
        let certId = UUID()
        let timestamp = Date()

        // Build canonical payload for signing
        let canonical = [
            certId.uuidString,
            timestamp.ISO8601Format(),
            intentHash,
            proposalHash,
            authorizationTokenHash,
            approverIdHash,
            deviceKeyId,
            input.connectorId ?? "none",
            input.connectorVersion ?? "none",
            input.riskTier.rawValue,
            policySnapshotHash,
            resultHash,
            previousHash
        ].joined(separator: "|")
        let canonicalData = Data(canonical.utf8)

        // ── 5. Sign ──────────────────────────────────────
        let signature: Data
        do {
            signature = try signer.sign(canonicalData)
        } catch {
            throw CertificateBuilderError.signingFailed(error.localizedDescription)
        }

        // ── 6. Assemble immutable certificate ────────────
        let certificate = ExecutionCertificate(
            id: certId,
            timestamp: timestamp,
            intentHash: intentHash,
            proposalHash: proposalHash,
            authorizationTokenHash: authorizationTokenHash,
            approverIdHash: approverIdHash,
            deviceKeyId: deviceKeyId,
            connectorId: input.connectorId,
            connectorVersion: input.connectorVersion,
            riskTier: input.riskTier,
            policySnapshotHash: policySnapshotHash,
            resultHash: resultHash,
            signature: signature,
            signerPublicKey: publicKeyData,
            certificateHash: certificateHash,
            previousCertificateHash: previousHash
        )

        // ── 7. Append to tamper-evident store ────────────
        do {
            try ExecutionCertificateStore.shared.append(certificate)
        } catch {
            throw CertificateBuilderError.storeAppendFailed(error.localizedDescription)
        }

        // ── 8. Log evidence ──────────────────────────────
        Task { @MainActor in
            try? EvidenceEngine.shared.logGenericArtifact(
                type: "execution_certificate_created",
                planId: input.tokenPlanId,
                jsonString: """
                {"certificateId":"\(certId)","intentHash":"\(intentHash.prefix(16))","riskTier":"\(input.riskTier.rawValue)","connectorId":"\(input.connectorId ?? "none")","chainLink":"\(previousHash.prefix(16))","timestamp":"\(timestamp.ISO8601Format())"}
                """
            )
        }

        return certificate
    }
}
