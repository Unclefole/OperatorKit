import Foundation
import CryptoKit
import Security

// ============================================================================
// TRUST EPOCH MANAGER — Cryptographic Key Lifecycle
//
// INVARIANT: Keys are epoch-bound and version-tracked.
// INVARIANT: A compromised key becomes useless IMMEDIATELY on rotation.
// INVARIANT: No grace window. No revoked-key verification. FAIL CLOSED.
// INVARIANT: Tokens must carry keyVersion + epoch. Mismatch = HARD FAIL.
//
// Key rotation:
//   1. Generate new SymmetricKey (Keychain-stored)
//   2. Increment activeKeyVersion
//   3. Mark prior key version as revoked
//   4. All tokens signed with prior key version become invalid instantly
//
// Trust epoch:
//   Increments on any security-material event (key rotation, device revocation,
//   integrity failure). Forces all outstanding tokens to expire immediately.
// ============================================================================

@MainActor
public final class TrustEpochManager: ObservableObject {

    public static let shared = TrustEpochManager()

    // MARK: - Published State

    @Published private(set) var trustEpoch: Int
    @Published private(set) var activeKeyVersion: Int
    @Published private(set) var revokedKeyVersions: Set<Int>

    // MARK: - Storage

    private let stateFileURL: URL
    private static let keychainServicePrefix = "com.operatorkit.signing-key-v"

    // MARK: - State Model

    private struct EpochState: Codable {
        var trustEpoch: Int
        var activeKeyVersion: Int
        var revokedKeyVersions: [Int]
        var lastRotatedAt: Date?
        var epochAdvancedAt: Date?
    }

    // MARK: - Init

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("KernelSecurity", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.stateFileURL = dir.appendingPathComponent("trust_epoch_state.json")

        // Load or initialize
        if let data = try? Data(contentsOf: stateFileURL),
           let state = try? JSONDecoder().decode(EpochState.self, from: data) {
            self.trustEpoch = state.trustEpoch
            self.activeKeyVersion = state.activeKeyVersion
            self.revokedKeyVersions = Set(state.revokedKeyVersions)
        } else {
            // First launch: epoch 1, key version 1
            self.trustEpoch = 1
            self.activeKeyVersion = 1
            self.revokedKeyVersions = []
            // Ensure key v1 exists
            Self.ensureKeyExists(version: 1)
            persist(EpochState(
                trustEpoch: 1,
                activeKeyVersion: 1,
                revokedKeyVersions: [],
                lastRotatedAt: Date(),
                epochAdvancedAt: Date()
            ))
        }
    }

    // MARK: - Key Access

    /// Get the ACTIVE signing key. Only the current version is usable.
    public nonisolated func activeSigningKey() -> SymmetricKey? {
        // Load from stored state (nonisolated-safe: reads file)
        guard let data = try? Data(contentsOf: stateFileURL),
              let state = try? JSONDecoder().decode(EpochState.self, from: data) else {
            return nil
        }
        return Self.loadKey(version: state.activeKeyVersion)
    }

    /// Check if a key version is revoked.
    public func isKeyRevoked(version: Int) -> Bool {
        revokedKeyVersions.contains(version)
    }

    /// Check if key version and epoch match the current active state.
    public func validateTokenBinding(keyVersion: Int, epoch: Int) -> Bool {
        keyVersion == activeKeyVersion && epoch == trustEpoch && !revokedKeyVersions.contains(keyVersion)
    }

    // MARK: - Key Rotation

    /// Rotate the signing key. Generates a new key, increments version, revokes prior.
    /// All tokens signed with the old key become invalid IMMEDIATELY.
    public func rotateKey() {
        let oldVersion = activeKeyVersion
        let newVersion = oldVersion + 1

        // Generate new key in Keychain
        Self.ensureKeyExists(version: newVersion)

        // Revoke old key
        revokedKeyVersions.insert(oldVersion)

        // Advance
        activeKeyVersion = newVersion
        trustEpoch += 1  // Epoch always advances on rotation

        persist(EpochState(
            trustEpoch: trustEpoch,
            activeKeyVersion: activeKeyVersion,
            revokedKeyVersions: Array(revokedKeyVersions),
            lastRotatedAt: Date(),
            epochAdvancedAt: Date()
        ))

        log("[TRUST_EPOCH] Key rotated: v\(oldVersion) → v\(newVersion), epoch → \(trustEpoch)")

        // Evidence log
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "key_rotation",
            planId: UUID(),
            jsonString: """
            {"oldVersion":\(oldVersion),"newVersion":\(newVersion),"epoch":\(trustEpoch),"rotatedAt":"\(Date())"}
            """
        )
    }

    // MARK: - Epoch Advancement

    /// Advance the trust epoch without key rotation.
    /// Used on security events (device revocation, integrity failure).
    /// Invalidates all outstanding tokens.
    public func advanceEpoch(reason: String) {
        trustEpoch += 1

        persist(EpochState(
            trustEpoch: trustEpoch,
            activeKeyVersion: activeKeyVersion,
            revokedKeyVersions: Array(revokedKeyVersions),
            lastRotatedAt: nil,
            epochAdvancedAt: Date()
        ))

        log("[TRUST_EPOCH] Epoch advanced to \(trustEpoch), reason: \(reason)")

        try? EvidenceEngine.shared.logGenericArtifact(
            type: "epoch_advanced",
            planId: UUID(),
            jsonString: """
            {"epoch":\(trustEpoch),"reason":"\(reason)","advancedAt":"\(Date())"}
            """
        )
    }

    // MARK: - Keychain Key Management (Static)

    nonisolated private static func keychainAccount(version: Int) -> String {
        "token-hmac-v\(version)"
    }

    static func ensureKeyExists(version: Int) {
        if loadKey(version: version) == nil {
            let newKey = SymmetricKey(size: .bits256)
            storeKey(newKey, version: version)
        }
    }

    nonisolated static func loadKey(version: Int) -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServicePrefix + "\(version)",
            kSecAttrAccount as String: keychainAccount(version: version),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    nonisolated private static func storeKey(_ key: SymmetricKey, version: Int) {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServicePrefix + "\(version)",
            kSecAttrAccount as String: keychainAccount(version: version),
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    // MARK: - Persistence

    private func persist(_ state: EpochState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: stateFileURL, options: .atomic)
    }

    // MARK: - Integrity Check

    /// Verify key lifecycle integrity on launch.
    /// Returns false if active key is missing or revoked.
    public func verifyIntegrity() -> Bool {
        // Active key must exist in Keychain
        guard Self.loadKey(version: activeKeyVersion) != nil else {
            logError("[TRUST_EPOCH] INTEGRITY FAILURE: Active key v\(activeKeyVersion) missing from Keychain")
            return false
        }
        // Active key must NOT be in revoked set
        guard !revokedKeyVersions.contains(activeKeyVersion) else {
            logError("[TRUST_EPOCH] INTEGRITY FAILURE: Active key v\(activeKeyVersion) found in revoked set")
            return false
        }
        return true
    }
}
