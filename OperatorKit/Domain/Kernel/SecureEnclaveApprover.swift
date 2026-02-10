import Foundation
import Security
import CryptoKit
import LocalAuthentication

// ============================================================================
// SECURE ENCLAVE APPROVER — Hardware-Backed Human Authority
//
// INVARIANT: No execution without a cryptographic human signature.
// INVARIANT: Private key lives in Secure Enclave — cannot be extracted.
// INVARIANT: Signing requires biometric (Face ID / Touch ID) at the moment of approval.
// INVARIANT: Verification uses the public key stored in Keychain.
//
// This is OperatorKit's category-defining security primitive.
// Almost no AI platform leverages hardware attestation for execution authority.
// ============================================================================

/// Hardware-backed approval signer using the iPhone Secure Enclave.
/// Private key never leaves the SE. Signing requires biometric authentication.
@MainActor
public final class SecureEnclaveApprover {

    public static let shared = SecureEnclaveApprover()

    private let keyTag = "com.operatorkit.approval-signing-key"

    // MARK: - Key Management

    /// Ensure the Secure Enclave key pair exists. Creates on first launch.
    /// Returns the public key data for identity binding.
    public func ensureKeyExists() -> Data? {
        if let pubKey = loadPublicKey() {
            return pubKey
        }
        return generateKeyPair()
    }

    /// Generate a new P-256 key pair in the Secure Enclave.
    /// Private key is protected by biometryCurrentSet — invalidated if biometrics change.
    private func generateKeyPair() -> Data? {
        // Access control: biometric required for signing
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            &error
        ) else {
            logError("[SE_APPROVER] Failed to create access control: \(error.debugDescription)")
            return nil
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
                kSecAttrAccessControl as String: access
            ] as [String: Any]
        ]

        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            logError("[SE_APPROVER] Key generation failed: \(error.debugDescription)")
            return nil
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            logError("[SE_APPROVER] Failed to extract public key")
            return nil
        }

        guard let pubData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            logError("[SE_APPROVER] Failed to export public key")
            return nil
        }

        log("[SE_APPROVER] Key pair generated in Secure Enclave")
        return pubData
    }

    /// Load the public key from the SE-backed key pair.
    /// nonisolated: safe because it only reads the Keychain (no mutable state).
    nonisolated func loadPublicKey() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let privateKey = item else {
            return nil
        }

        // Safe to force cast here — SecItemCopyMatching with kSecReturnRef returns SecKey
        let secKey = privateKey as! SecKey
        guard let publicKey = SecKeyCopyPublicKey(secKey) else { return nil }

        var error: Unmanaged<CFError>?
        guard let pubData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }
        return pubData
    }

    // MARK: - Signing (Biometric-Gated)

    /// Sign a plan hash with the Secure Enclave private key.
    /// Triggers Face ID / Touch ID at the moment of signing.
    /// Returns the DER-encoded ECDSA signature, or nil if biometric fails.
    public func signApproval(planHash: String) async -> Data? {
        let context = LAContext()
        context.localizedReason = "Authorize execution"

        // Load private key reference
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecReturnRef as String: true,
            kSecUseAuthenticationContext as String: context
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let privateKey = item else {
            logError("[SE_APPROVER] Cannot load SE private key for signing (status: \(status))")
            return nil
        }

        let secKey = privateKey as! SecKey
        let dataToSign = planHash.data(using: .utf8)!

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            secKey,
            .ecdsaSignatureMessageX962SHA256,
            dataToSign as CFData,
            &error
        ) as Data? else {
            logError("[SE_APPROVER] Signing failed: \(error.debugDescription)")
            return nil
        }

        log("[SE_APPROVER] Plan hash signed with Secure Enclave (biometric authenticated)")
        return signature
    }

    // MARK: - Verification

    /// Verify a signature against a plan hash using the stored public key.
    /// Does NOT require biometric — verification is public-key operation.
    /// nonisolated: safe because it only reads the Keychain (no mutable state).
    nonisolated public func verifySignature(_ signature: Data, planHash: String) -> Bool {
        guard let pubData = loadPublicKey() else {
            logError("[SE_APPROVER] No public key available for verification")
            return false
        }

        var error: Unmanaged<CFError>?
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 256
        ]

        guard let publicKey = SecKeyCreateWithData(
            pubData as CFData,
            attributes as CFDictionary,
            &error
        ) else {
            logError("[SE_APPROVER] Cannot reconstruct public key: \(error.debugDescription)")
            return false
        }

        let dataToVerify = planHash.data(using: .utf8)!

        let result = SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            dataToVerify as CFData,
            signature as CFData,
            &error
        )

        if !result {
            logError("[SE_APPROVER] Signature verification FAILED: \(error.debugDescription)")
        }
        return result
    }

    // MARK: - Device Identity

    /// Returns the SHA256 fingerprint of the public key — used as device identity.
    /// nonisolated: safe because it only reads the Keychain (no mutable state).
    nonisolated public var deviceFingerprint: String? {
        guard let pubData = loadPublicKey() else { return nil }
        let hash = SHA256.hash(data: pubData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
