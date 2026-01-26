import Foundation
import CryptoKit

/// Handles encryption for sensitive data
/// Phase 1: Basic implementation for local storage
final class EncryptionService {
    
    static let shared = EncryptionService()
    
    private init() {}
    
    // MARK: - Key Management
    
    private var symmetricKey: SymmetricKey {
        // Phase 1: Use a deterministic key for development
        // Production: Should use Keychain-stored key
        let keyData = "OperatorKitDevelopmentKey2024".data(using: .utf8)!
        return SymmetricKey(data: SHA256.hash(data: keyData))
    }
    
    // MARK: - Encryption
    
    func encrypt(_ string: String) -> Data? {
        guard let data = string.data(using: .utf8) else { return nil }
        return encrypt(data)
    }
    
    func encrypt(_ data: Data) -> Data? {
        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
            return sealedBox.combined
        } catch {
            logError("Encryption failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Decryption
    
    func decrypt(_ data: Data) -> Data? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            logError("Decryption failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    func decryptToString(_ data: Data) -> String? {
        guard let decrypted = decrypt(data) else { return nil }
        return String(data: decrypted, encoding: .utf8)
    }
    
    // MARK: - Hashing
    
    func hash(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
