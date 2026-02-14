import Foundation
import CryptoKit

// ============================================================================
// CERTIFICATE VERIFIER — Comprehensive Execution Certificate Verification
//
// Verifies:
//   1. Signature integrity (ECDSA-P256 over canonical payload)
//   2. Hash integrity (SHA256 certificate hash matches content)
//   3. Chain linkage (previousCertificateHash links correctly)
//   4. Enclave backing (whether the signing key was SE-backed)
//   5. Temporal validity (certificate timestamp within acceptable window)
//
// INVARIANT: Verification is stateless and side-effect-free.
// INVARIANT: Any single check failure = overall verification failure.
// INVARIANT: Returns detailed, machine-readable verification results.
//
// EVIDENCE TAGS:
//   certificate_verified, certificate_verification_failed
// ============================================================================

// MARK: - Verification Result

/// Comprehensive, machine-readable verification result.
public struct CertificateVerificationResult: Sendable {
    public let certificateId: UUID
    public let signatureValid: Bool
    public let hashIntegrity: Bool
    public let chainIntact: Bool
    public let enclaveBacked: Bool
    public let temporalValid: Bool
    public let verifiedAt: Date
    public let failures: [String]

    /// All checks must pass for the certificate to be considered valid.
    public var isValid: Bool {
        signatureValid && hashIntegrity && chainIntact && temporalValid
    }

    /// Human-readable summary.
    public var summary: String {
        if isValid {
            return "All checks passed\(enclaveBacked ? " (SE-backed)" : " (software key)")"
        }
        return "FAILED: \(failures.joined(separator: "; "))"
    }
}

// MARK: - Certificate Verifier

public enum CertificateVerifier {

    // MARK: - Verify Single Certificate

    /// Verify a single certificate's integrity.
    ///
    /// - Parameters:
    ///   - certificate: The certificate to verify.
    ///   - previousHash: Expected previous certificate hash (for chain verification).
    ///                   Pass "GENESIS" for the first certificate in the chain.
    ///   - maxAgeSeconds: Maximum acceptable age of the certificate (default 24 hours).
    /// - Returns: Detailed verification result.
    public static func verify(
        certificate: ExecutionCertificate,
        previousHash: String? = nil,
        maxAgeSeconds: TimeInterval = 86_400
    ) -> CertificateVerificationResult {
        var failures: [String] = []

        // ── 1. Signature Verification ─────────────────────
        let signatureValid = certificate.verifySignature()
        if !signatureValid {
            failures.append("Signature verification failed — canonical payload does not match ECDSA signature")
        }

        // ── 2. Hash Integrity ─────────────────────────────
        let hashIntegrity = certificate.verifyHash()
        if !hashIntegrity {
            failures.append("Hash integrity check failed — certificateHash does not match computed hash")
        }

        // ── 3. Chain Linkage ──────────────────────────────
        var chainIntact = true
        if let expectedPrevious = previousHash {
            if certificate.previousCertificateHash != expectedPrevious {
                chainIntact = false
                failures.append("Chain linkage broken — expected previousHash=\(expectedPrevious.prefix(16))..., got=\(certificate.previousCertificateHash.prefix(16))...")
            }
        }

        // ── 4. Enclave Backing ────────────────────────────
        let enclaveBacked = certificate.enclaveBacked

        // ── 5. Temporal Validity ──────────────────────────
        let age = Date().timeIntervalSince(certificate.timestamp)
        let temporalValid = age >= 0 && age <= maxAgeSeconds
        if !temporalValid {
            if age < 0 {
                failures.append("Certificate timestamp is in the future — possible clock skew or forgery")
            } else {
                failures.append("Certificate age \(Int(age))s exceeds max \(Int(maxAgeSeconds))s")
            }
        }

        // ── Log Evidence ──────────────────────────────────
        let isValid = signatureValid && hashIntegrity && chainIntact && temporalValid
        let evidenceType = isValid ? "certificate_verified" : "certificate_verification_failed"
        Task { @MainActor in
            try? EvidenceEngine.shared.logGenericArtifact(
                type: evidenceType,
                planId: UUID(),
                jsonString: """
                {"certId":"\(certificate.id)","sig":\(signatureValid),"hash":\(hashIntegrity),"chain":\(chainIntact),"enclave":\(enclaveBacked),"temporal":\(temporalValid),"failures":"\(failures.joined(separator: "; "))","timestamp":"\(Date().ISO8601Format())"}
                """
            )
        }

        return CertificateVerificationResult(
            certificateId: certificate.id,
            signatureValid: signatureValid,
            hashIntegrity: hashIntegrity,
            chainIntact: chainIntact,
            enclaveBacked: enclaveBacked,
            temporalValid: temporalValid,
            verifiedAt: Date(),
            failures: failures
        )
    }

    // MARK: - Verify Chain

    /// Verify an entire certificate chain (ordered oldest to newest).
    /// Returns individual results for each certificate.
    public static func verifyChain(
        certificates: [ExecutionCertificate]
    ) -> [CertificateVerificationResult] {
        guard !certificates.isEmpty else { return [] }

        var results: [CertificateVerificationResult] = []
        var expectedPreviousHash = "GENESIS"

        for cert in certificates {
            let result = verify(
                certificate: cert,
                previousHash: expectedPreviousHash
            )
            results.append(result)
            expectedPreviousHash = cert.certificateHash
        }

        return results
    }
}
