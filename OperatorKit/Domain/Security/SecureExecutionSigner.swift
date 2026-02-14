import Foundation
import Security
import CryptoKit

// ============================================================================
// SECURE EXECUTION SIGNER — Hardware-Rooted Certificate Signing
//
// Uses Secure Enclave keys for execution certificate signing when available.
// Falls back to Keychain-backed P256 on simulator with explicit logging.
//
// INVARIANT: SE keys are non-exportable (kSecAttrIsExtractable = false).
// INVARIANT: SE keys require biometric (kSecAccessControlBiometryCurrentSet).
// INVARIANT: Simulator fallback produces valid certs with enclaveBacked = false.
// INVARIANT: Never logs private key material.
// INVARIANT: FAIL CLOSED — if signing fails, execution aborts.
//
// EVIDENCE TAGS:
//   se_cert_key_created, se_cert_signed, se_cert_sign_failed,
//   enclave_unavailable_simulator
// ============================================================================

// MARK: - Signer Errors

public enum SecureExecutionSignerError: Error, LocalizedError {
    case keyGenerationFailed(String)
    case keyNotFound
    case signingFailed(String)
    case publicKeyExtractionFailed
    case biometricRequired

    public var errorDescription: String? {
        switch self {
        case .keyGenerationFailed(let r): return "SE cert key generation failed: \(r)"
        case .keyNotFound: return "SE cert signing key not found — FAIL CLOSED"
        case .signingFailed(let r): return "SE cert signing failed: \(r)"
        case .publicKeyExtractionFailed: return "Failed to extract SE cert public key"
        case .biometricRequired: return "Biometric authentication required for SE signing"
        }
    }
}

// MARK: - Secure Execution Signer

/// Signs execution certificates with a Secure Enclave-backed P-256 key.
/// On simulator: uses Keychain-backed key with `enclaveBacked = false`.
public final class SecureExecutionSigner: @unchecked Sendable {

    public static let shared = SecureExecutionSigner()

    private let keyTag = "com.operatorkit.se-execution-certificate-signing-key"

    /// Whether Secure Enclave hardware is available.
    public let isEnclaveAvailable: Bool

    private init() {
        #if targetEnvironment(simulator)
        self.isEnclaveAvailable = false
        #else
        // Test SE availability by checking hardware token support
        var testError: Unmanaged<CFError>?
        let testAccess = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            &testError
        )
        self.isEnclaveAvailable = testAccess != nil && testError == nil
        #endif

        if !isEnclaveAvailable {
            logEvidence(type: "enclave_unavailable_simulator", detail: "SE not available — will use Keychain fallback")
        }
    }

    // MARK: - Key Lifecycle

    /// Ensure the SE signing key exists. Creates one if needed.
    /// FAIL CLOSED: throws if key cannot be created or loaded.
    @discardableResult
    public func generateKeyIfNeeded() throws -> Data {
        if let pubKey = try? publicKey() {
            return pubKey
        }

        if isEnclaveAvailable {
            return try generateSecureEnclaveKey()
        } else {
            return try generateKeychainFallbackKey()
        }
    }

    /// Get the public key data (X9.63 representation).
    public func publicKey() throws -> Data {
        guard let privateKeyRef = loadPrivateKeyRef() else {
            throw SecureExecutionSignerError.keyNotFound
        }
        guard let pubKeyRef = SecKeyCopyPublicKey(privateKeyRef) else {
            throw SecureExecutionSignerError.publicKeyExtractionFailed
        }
        var error: Unmanaged<CFError>?
        guard let pubData = SecKeyCopyExternalRepresentation(pubKeyRef, &error) as Data? else {
            throw SecureExecutionSignerError.publicKeyExtractionFailed
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

    /// Sign data with the SE-backed private key.
    /// Returns DER-encoded ECDSA signature.
    /// On physical device: requires biometric authentication.
    public func sign(_ data: Data) throws -> Data {
        guard let privateKeyRef = loadPrivateKeyRef() else {
            logEvidence(type: "se_cert_sign_failed", detail: "Key not found")
            throw SecureExecutionSignerError.keyNotFound
        }

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKeyRef,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) as Data? else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "unknown"
            logEvidence(type: "se_cert_sign_failed", detail: reason)
            throw SecureExecutionSignerError.signingFailed(reason)
        }

        logEvidence(
            type: "se_cert_signed",
            detail: "bytes=\(data.count), sig=\(signature.count)B, enclave=\(isEnclaveAvailable)"
        )
        return signature
    }

    // MARK: - Secure Enclave Key Generation

    private func generateSecureEnclaveKey() throws -> Data {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            &error
        ) else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "access control creation failed"
            throw SecureExecutionSignerError.keyGenerationFailed(reason)
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
            throw SecureExecutionSignerError.keyGenerationFailed(reason)
        }

        guard let pubKeyRef = SecKeyCopyPublicKey(privateKey) else {
            throw SecureExecutionSignerError.publicKeyExtractionFailed
        }

        guard let pubData = SecKeyCopyExternalRepresentation(pubKeyRef, &error) as Data? else {
            throw SecureExecutionSignerError.publicKeyExtractionFailed
        }

        logEvidence(type: "se_cert_key_created", detail: "Secure Enclave P-256 with biometryCurrentSet")
        return pubData
    }

    // MARK: - Keychain Fallback Key Generation (Simulator)

    private func generateKeychainFallbackKey() throws -> Data {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [],
            &error
        ) else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "access control creation failed"
            throw SecureExecutionSignerError.keyGenerationFailed(reason)
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
            throw SecureExecutionSignerError.keyGenerationFailed(reason)
        }

        guard let pubKeyRef = SecKeyCopyPublicKey(privateKey) else {
            throw SecureExecutionSignerError.publicKeyExtractionFailed
        }

        guard let pubData = SecKeyCopyExternalRepresentation(pubKeyRef, &error) as Data? else {
            throw SecureExecutionSignerError.publicKeyExtractionFailed
        }

        logEvidence(type: "se_cert_key_created", detail: "Keychain fallback P-256 (simulator — enclaveBacked=false)")
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
                {"detail":"\(detail)","secureEnclave":\(isEnclaveAvailable),"timestamp":"\(Date().ISO8601Format())"}
                """
            )
        }
    }
}
