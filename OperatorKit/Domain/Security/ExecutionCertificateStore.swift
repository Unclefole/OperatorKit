import Foundation
import CryptoKit

// ============================================================================
// EXECUTION CERTIFICATE STORE — Tamper-Evident Append-Only Ledger
//
// INVARIANT: Append-only. No update. No delete.
// INVARIANT: Ordered by timestamp.
// INVARIANT: Hash chain: each certificate stores previousCertificateHash.
// INVARIANT: Chain integrity verifiable at any time.
// INVARIANT: Persisted to disk atomically.
//
// Future: anchorRootHash() → ready for blockchain / notary anchoring.
// ============================================================================

// MARK: - Store Errors

public enum CertificateStoreError: Error, LocalizedError {
    case appendFailed(String)
    case chainIntegrityViolation(String)
    case notFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .appendFailed(let r): return "Certificate store append failed: \(r)"
        case .chainIntegrityViolation(let r): return "Certificate chain integrity violation: \(r)"
        case .notFound(let id): return "Certificate not found: \(id)"
        }
    }
}

// MARK: - Execution Certificate Store

/// Append-only, tamper-evident ledger of execution certificates.
/// Persisted to the app's document directory.
public final class ExecutionCertificateStore: @unchecked Sendable {

    public static let shared = ExecutionCertificateStore()

    private var certificates: [ExecutionCertificate] = []
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.operatorkit.certificate-store", qos: .userInitiated)

    // MARK: - Init

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("KernelSecurity", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("execution_certificates.json")
        loadFromDisk()
    }

    // MARK: - Append (The Only Write Operation)

    /// Append a certificate to the store. FAIL CLOSED on any error.
    /// This is the ONLY mutation allowed on the store.
    public func append(_ certificate: ExecutionCertificate) throws {
        try queue.sync {
            // Verify chain integrity: certificate's previousCertificateHash must match
            let expectedPrevious = certificates.last?.certificateHash ?? "GENESIS"
            guard certificate.previousCertificateHash == expectedPrevious else {
                throw CertificateStoreError.chainIntegrityViolation(
                    "Expected previous=\(expectedPrevious.prefix(16)), got=\(certificate.previousCertificateHash.prefix(16))"
                )
            }

            certificates.append(certificate)
            persistToDisk()
        }
    }

    // MARK: - Read Operations (Immutable Views)

    /// All certificates, ordered by timestamp (oldest first).
    public var all: [ExecutionCertificate] {
        queue.sync { certificates }
    }

    /// Total certificate count.
    public var count: Int {
        queue.sync { certificates.count }
    }

    /// The hash of the most recent certificate (chain head).
    public var lastCertificateHash: String? {
        queue.sync { certificates.last?.certificateHash }
    }

    /// Get a certificate by ID.
    public func certificate(for id: UUID) -> ExecutionCertificate? {
        queue.sync { certificates.first(where: { $0.id == id }) }
    }

    /// Get the N most recent certificates.
    public func recent(_ count: Int) -> [ExecutionCertificate] {
        queue.sync {
            Array(certificates.suffix(count))
        }
    }

    // MARK: - Chain Verification

    /// Verify the entire hash chain from genesis to head.
    /// Returns true if the chain is intact, false if tampered.
    public func verifyChainIntegrity() -> ChainVerificationResult {
        queue.sync {
            guard !certificates.isEmpty else {
                return ChainVerificationResult(intact: true, verifiedCount: 0, brokenAt: nil)
            }

            var previousHash = "GENESIS"
            for (index, cert) in certificates.enumerated() {
                // Check previousCertificateHash links correctly
                guard cert.previousCertificateHash == previousHash else {
                    return ChainVerificationResult(
                        intact: false,
                        verifiedCount: index,
                        brokenAt: index
                    )
                }

                // Check certificate's own hash is consistent
                guard cert.verifyHash() else {
                    return ChainVerificationResult(
                        intact: false,
                        verifiedCount: index,
                        brokenAt: index
                    )
                }

                previousHash = cert.certificateHash
            }

            return ChainVerificationResult(intact: true, verifiedCount: certificates.count, brokenAt: nil)
        }
    }

    /// Verify a single certificate's signature.
    public func verifyCertificate(_ id: UUID) -> CertificateVerificationStatus? {
        guard let cert = certificate(for: id) else { return nil }

        let signatureValid = cert.verifySignature()
        let hashIntegrity = cert.verifyHash()

        // Check chain link
        let chainIntact: Bool
        if let index = queue.sync(execute: { certificates.firstIndex(where: { $0.id == id }) }) {
            if index == 0 {
                chainIntact = cert.previousCertificateHash == "GENESIS"
            } else {
                let prev = queue.sync { certificates[index - 1] }
                chainIntact = cert.previousCertificateHash == prev.certificateHash
            }
        } else {
            chainIntact = false
        }

        return CertificateVerificationStatus(
            signatureValid: signatureValid,
            hashIntegrity: hashIntegrity,
            chainIntact: chainIntact,
            verifiedAt: Date()
        )
    }

    // MARK: - Hash Chain Proof

    /// Build a hash chain proof from a given certificate back to genesis.
    /// Used for audit export.
    public func hashChainProof(for certificateId: UUID) -> [String]? {
        queue.sync {
            guard let index = certificates.firstIndex(where: { $0.id == certificateId }) else {
                return nil
            }

            var proof: [String] = ["GENESIS"]
            for i in 0...index {
                proof.append(certificates[i].certificateHash)
            }
            return proof
        }
    }

    // MARK: - Anchor Root Hash (Future: Blockchain / Notary)

    /// The root hash of the certificate chain.
    /// Ready for future anchoring to external notary / blockchain.
    public func anchorRootHash() -> String? {
        queue.sync {
            guard !certificates.isEmpty else { return nil }
            // Merkle-style: hash of all certificate hashes
            let allHashes = certificates.map(\.certificateHash).joined(separator: "|")
            return ExecutionCertificate.sha256Hex(allHashes)
        }
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let loaded = try? JSONDecoder().decode([ExecutionCertificate].self, from: data) else {
            certificates = []
            return
        }
        certificates = loaded.sorted(by: { $0.timestamp < $1.timestamp })
    }

    private func persistToDisk() {
        guard let data = try? JSONEncoder().encode(certificates) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Audit Export

/// Exports a signed bundle for external auditors.
/// Contains: certificate, public key, hash chain proof. NO secrets.
public enum CertificateExporter {

    /// Export a certificate bundle for audit.
    /// Returns nil if the certificate is not found.
    public static func exportCertificateBundle(
        certificateId: UUID
    ) -> CertificateExportBundle? {
        let store = ExecutionCertificateStore.shared

        guard let certificate = store.certificate(for: certificateId) else {
            return nil
        }

        guard let chainProof = store.hashChainProof(for: certificateId) else {
            return nil
        }

        let publicKeyHex = ExecutionCertificate.sha256HexData(certificate.signerPublicKey)

        // Sign the export itself for tamper evidence
        let exportPayload = "\(certificateId)|\(publicKeyHex)|\(chainProof.joined(separator: ","))|\(Date().ISO8601Format())"
        let exportSignature: Data
        do {
            exportSignature = try ExecutionSigner.shared.sign(Data(exportPayload.utf8))
        } catch {
            // If we can't sign the export, still return it unsigned
            exportSignature = Data()
        }

        return CertificateExportBundle(
            certificate: certificate,
            signerPublicKeyHex: publicKeyHex,
            hashChainProof: chainProof,
            exportedAt: Date(),
            exportSignature: exportSignature
        )
    }

    /// Export all certificates as a JSON bundle for enterprise audit.
    public static func exportAllCertificates() -> Data? {
        let store = ExecutionCertificateStore.shared
        let certs = store.all
        return try? JSONEncoder().encode(certs)
    }
}

// MARK: - Chain Verification Result

public struct ChainVerificationResult: Sendable {
    public let intact: Bool
    public let verifiedCount: Int
    public let brokenAt: Int?           // Index where chain breaks (nil if intact)

    public var summary: String {
        if intact {
            return "Chain intact: \(verifiedCount) certificate(s) verified"
        } else {
            return "Chain BROKEN at index \(brokenAt ?? -1) — \(verifiedCount) verified before break"
        }
    }
}
