import Foundation
import Security
import CryptoKit

// ============================================================================
// EXECUTION SIGNER — Device-Bound Cryptographic Signing for Certificates
//
// INVARIANT: Private key lives in Secure Enclave (preferred) or Keychain.
// INVARIANT: Key is non-exportable (kSecAttrIsExtractable = false).
// INVARIANT: If key creation fails → FAIL CLOSED.
// INVARIANT: Never logs private key material.
//
// EVIDENCE TAGS:
//   execution_key_created
//   execution_signed
//   execution_sign_failed
// ============================================================================

// MARK: - Signer Errors

public enum ExecutionSignerError: Error, LocalizedError {
    case keyGenerationFailed(String)
    case keyNotFound
    case signingFailed(String)
    case publicKeyExtractionFailed
    case failClosed(String)

    public var errorDescription: String? {
        switch self {
        case .keyGenerationFailed(let r): return "Execution signer key generation failed: \(r)"
        case .keyNotFound: return "Execution signing key not found — FAIL CLOSED"
        case .signingFailed(let r): return "Execution signing failed: \(r)"
        case .publicKeyExtractionFailed: return "Failed to extract public key"
        case .failClosed(let r): return "ExecutionSigner FAIL CLOSED: \(r)"
        }
    }
}

// MARK: - Execution Signer

/// Signs execution certificates with a device-bound P-256 key.
/// Key lives in Secure Enclave on physical devices, Keychain on simulator.
public final class ExecutionSigner: @unchecked Sendable {

    public static let shared = ExecutionSigner()

    private let keyTag = "com.operatorkit.execution-certificate-signing-key"

    /// Whether Secure Enclave is available (physical device with SE hardware).
    private let secureEnclaveAvailable: Bool

    private init() {
        // SE is available if we can create an SE-backed key
        // On simulator this will be false
        var testError: Unmanaged<CFError>?
        let testAccess = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .privateKeyUsage,
            &testError
        )
        // Check if SE is available by testing the hardware token
        #if targetEnvironment(simulator)
        self.secureEnclaveAvailable = false
        #else
        self.secureEnclaveAvailable = testAccess != nil
        #endif
    }

    // MARK: - Key Lifecycle

    /// Ensure the signing key exists. Creates one if needed.
    /// FAIL CLOSED: throws if key cannot be created or loaded.
    @discardableResult
    public func generateKeyIfNeeded() throws -> Data {
        // Try to load existing key
        if let pubKey = try? publicKey() {
            return pubKey
        }

        // Generate new key
        if secureEnclaveAvailable {
            return try generateSecureEnclaveKey()
        } else {
            return try generateKeychainKey()
        }
    }

    /// Get the public key data (X9.63 representation).
    public func publicKey() throws -> Data {
        guard let privateKeyRef = loadPrivateKeyRef() else {
            throw ExecutionSignerError.keyNotFound
        }
        guard let pubKeyRef = SecKeyCopyPublicKey(privateKeyRef) else {
            throw ExecutionSignerError.publicKeyExtractionFailed
        }
        var error: Unmanaged<CFError>?
        guard let pubData = SecKeyCopyExternalRepresentation(pubKeyRef, &error) as Data? else {
            throw ExecutionSignerError.publicKeyExtractionFailed
        }
        return pubData
    }

    /// SHA256 hex fingerprint of the public key.
    public func publicKeyFingerprint() throws -> String {
        let pubData = try publicKey()
        return SHA256.hash(data: pubData)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: - Signing

    /// Sign data with the device-bound private key.
    /// Returns DER-encoded ECDSA signature.
    public func sign(_ data: Data) throws -> Data {
        guard let privateKeyRef = loadPrivateKeyRef() else {
            logEvidence(type: "execution_sign_failed", detail: "Key not found")
            throw ExecutionSignerError.keyNotFound
        }

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKeyRef,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) as Data? else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "unknown"
            logEvidence(type: "execution_sign_failed", detail: reason)
            throw ExecutionSignerError.signingFailed(reason)
        }

        logEvidence(type: "execution_signed", detail: "bytes=\(data.count), sig=\(signature.count)B")
        return signature
    }

    // MARK: - Secure Enclave Key Generation

    private func generateSecureEnclaveKey() throws -> Data {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .privateKeyUsage,
            &error
        ) else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "access control creation failed"
            throw ExecutionSignerError.keyGenerationFailed(reason)
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
                kSecAttrAccessControl as String: access,
                kSecAttrIsExtractable as String: false  // NON-EXPORTABLE
            ] as [String: Any]
        ]

        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "key creation failed"
            throw ExecutionSignerError.keyGenerationFailed(reason)
        }

        guard let pubKeyRef = SecKeyCopyPublicKey(privateKey) else {
            throw ExecutionSignerError.publicKeyExtractionFailed
        }

        guard let pubData = SecKeyCopyExternalRepresentation(pubKeyRef, &error) as Data? else {
            throw ExecutionSignerError.publicKeyExtractionFailed
        }

        logEvidence(type: "execution_key_created", detail: "Secure Enclave P-256")
        log("[EXEC_SIGNER] Signing key created in Secure Enclave")
        return pubData
    }

    // MARK: - Keychain Fallback Key Generation

    private func generateKeychainKey() throws -> Data {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [],
            &error
        ) else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "access control creation failed"
            throw ExecutionSignerError.keyGenerationFailed(reason)
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
                kSecAttrAccessControl as String: access,
                kSecAttrIsExtractable as String: false  // NON-EXPORTABLE
            ] as [String: Any]
        ]

        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "key creation failed"
            throw ExecutionSignerError.keyGenerationFailed(reason)
        }

        guard let pubKeyRef = SecKeyCopyPublicKey(privateKey) else {
            throw ExecutionSignerError.publicKeyExtractionFailed
        }

        guard let pubData = SecKeyCopyExternalRepresentation(pubKeyRef, &error) as Data? else {
            throw ExecutionSignerError.publicKeyExtractionFailed
        }

        logEvidence(type: "execution_key_created", detail: "Keychain fallback P-256")
        log("[EXEC_SIGNER] Signing key created in Keychain (simulator fallback)")
        return pubData
    }

    // MARK: - Key Loading

    private func loadPrivateKeyRef() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            return nil
        }

        return (item as! SecKey)
    }

    // MARK: - Evidence

    private func logEvidence(type: String, detail: String) {
        Task { @MainActor in
            try? EvidenceEngine.shared.logGenericArtifact(
                type: type,
                planId: UUID(),
                jsonString: """
                {"detail":"\(detail)","secureEnclave":\(secureEnclaveAvailable),"timestamp":"\(Date().ISO8601Format())"}
                """
            )
        }
    }
}
