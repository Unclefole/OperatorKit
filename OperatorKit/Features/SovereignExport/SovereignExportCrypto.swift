import Foundation
import CryptoKit
import LocalAuthentication

// ============================================================================
// SOVEREIGN EXPORT CRYPTO (Phase 13C)
//
// Encryption layer for Sovereign Export using AES-GCM.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No key persistence
// ❌ No plaintext on disk
// ❌ No networking
// ✅ AES-GCM encryption
// ✅ User-derived key (biometric/passcode)
// ✅ Ephemeral keys only
// ============================================================================

// MARK: - Sovereign Export Crypto

public enum SovereignExportCrypto {
    
    // MARK: - Configuration
    
    /// Salt for key derivation (constant, not secret)
    private static let keySalt = "com.operatorkit.sovereign.export.v1".data(using: .utf8)!
    
    /// File header to identify encrypted exports
    public static let fileHeader = "OKSOV1".data(using: .utf8)!
    
    // MARK: - Encrypt
    
    /// Encrypt a bundle with a user-provided passphrase
    public static func encrypt(
        bundle: SovereignExportBundle,
        passphrase: String
    ) -> EncryptionResult {
        guard SovereignExportFeatureFlag.isEnabled else {
            return .failure("Sovereign Export is not enabled")
        }
        
        // Validate bundle before encryption
        let validation = SovereignExportBundleValidator.validate(bundle)
        guard validation.isValid else {
            return .failure("Bundle validation failed: \(validation.errors.joined(separator: ", "))")
        }
        
        do {
            // Encode bundle to JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let plaintext = try encoder.encode(bundle)
            
            // Derive key from passphrase
            let key = deriveKey(from: passphrase)
            
            // Generate nonce
            let nonce = AES.GCM.Nonce()
            
            // Encrypt
            let sealedBox = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
            
            // Combine: header + nonce + ciphertext + tag
            var encryptedData = Data()
            encryptedData.append(fileHeader)
            encryptedData.append(contentsOf: nonce)
            encryptedData.append(sealedBox.ciphertext)
            encryptedData.append(sealedBox.tag)
            
            return .success(EncryptedBundle(
                data: encryptedData,
                filename: "sovereign_export_\(bundle.exportedAtDayRounded).oksov"
            ))
            
        } catch {
            return .failure("Encryption failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Decrypt
    
    /// Decrypt an encrypted bundle with a user-provided passphrase
    public static func decrypt(
        encryptedData: Data,
        passphrase: String
    ) -> DecryptionResult {
        guard SovereignExportFeatureFlag.isEnabled else {
            return .failure("Sovereign Export is not enabled")
        }
        
        // Verify header
        guard encryptedData.count > fileHeader.count + 12 + 16,
              encryptedData.prefix(fileHeader.count) == fileHeader else {
            return .failure("Invalid file format")
        }
        
        do {
            // Extract components
            let nonceStart = fileHeader.count
            let nonceEnd = nonceStart + 12
            let tagStart = encryptedData.count - 16
            
            let nonceData = encryptedData[nonceStart..<nonceEnd]
            let ciphertext = encryptedData[nonceEnd..<tagStart]
            let tag = encryptedData[tagStart...]
            
            // Recreate nonce
            let nonce = try AES.GCM.Nonce(data: nonceData)
            
            // Derive key from passphrase
            let key = deriveKey(from: passphrase)
            
            // Recreate sealed box
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: ciphertext,
                tag: tag
            )
            
            // Decrypt
            let plaintext = try AES.GCM.open(sealedBox, using: key)
            
            // Decode bundle
            let bundle = try JSONDecoder().decode(SovereignExportBundle.self, from: plaintext)
            
            // Validate decrypted bundle
            let validation = SovereignExportBundleValidator.validate(bundle)
            guard validation.isValid else {
                return .failure("Decrypted bundle validation failed")
            }
            
            return .success(bundle)
            
        } catch {
            return .failure("Decryption failed: Invalid passphrase or corrupted file")
        }
    }
    
    // MARK: - Key Derivation
    
    /// Derive an AES key from passphrase using HKDF
    private static func deriveKey(from passphrase: String) -> SymmetricKey {
        let passphraseData = passphrase.data(using: .utf8)!
        
        // Use SHA256 of passphrase + salt as input key material
        let inputKeyMaterial = SHA256.hash(data: passphraseData + keySalt)
        let ikm = SymmetricKey(data: inputKeyMaterial)
        
        // Derive final key using HKDF
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: ikm,
            salt: keySalt,
            info: "sovereign-export-aes-key".data(using: .utf8)!,
            outputByteCount: 32
        )
        
        return derivedKey
    }
    
    // MARK: - Result Types
    
    public enum EncryptionResult {
        case success(EncryptedBundle)
        case failure(String)
    }
    
    public enum DecryptionResult {
        case success(SovereignExportBundle)
        case failure(String)
    }
}

// MARK: - Encrypted Bundle

public struct EncryptedBundle {
    public let data: Data
    public let filename: String
}

// MARK: - Biometric Authentication Helper

public enum SovereignExportAuth {
    
    /// Request biometric/passcode authentication
    public static func authenticate(
        reason: String,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(false, error)
            return
        }
        
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
        ) { success, evaluateError in
            DispatchQueue.main.async {
                completion(success, evaluateError)
            }
        }
    }
}
