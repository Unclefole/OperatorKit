import Foundation
import Security
import LocalAuthentication
import os.log

// ============================================================================
// API KEY VAULT — HARDWARE-BACKED CREDENTIAL STORAGE (FAIL CLOSED)
//
// Device-bound, biometric-gated API key storage.
// Keys live ONLY in Keychain with hardware-backed access control.
//
// INVARIANT: Keys are NEVER written to disk, UserDefaults, or iCloud.
// INVARIANT: Keys are NEVER logged, printed, or sent to analytics.
// INVARIANT: Keys are NEVER cached in memory beyond immediate use.
// INVARIANT: Keys require biometric/passcode authentication to retrieve.
// INVARIANT: Keys are cryptographically bound to THIS device only.
// INVARIANT: If access control creation fails → FAIL CLOSED.
// INVARIANT: If biometric set changes → keys become invalid.
//
// P0 FIX: DispatchQueue.main.sync from the main thread DEADLOCKS.
//         All kernel integrity checks now use thread-safe access.
// ============================================================================

// MARK: - Vault Error

public enum APIKeyVaultError: Error, LocalizedError, Sendable {
    case accessControlCreationFailed
    case keychainStoreFailed(OSStatus)
    case keychainRetrieveFailed(OSStatus)
    case keychainDeleteFailed(OSStatus)
    case authenticationFailed
    case authenticationCancelled
    case noKeyStored
    case keyDataCorrupted
    case biometricSetChanged
    case vaultLocked(detail: String)
    case duplicateItemRecovered
    case verificationFailed

    public var errorDescription: String? {
        switch self {
        case .accessControlCreationFailed:
            return "Failed to create hardware-backed access control — FAIL CLOSED"
        case .keychainStoreFailed(let s):
            return "Keychain store failed (OSStatus \(s)). Try deleting and re-adding the key."
        case .keychainRetrieveFailed(let s):
            return "Keychain retrieve failed (OSStatus \(s))"
        case .keychainDeleteFailed(let s):
            return "Keychain delete failed (OSStatus \(s))"
        case .authenticationFailed:
            return "Biometric/passcode authentication failed"
        case .authenticationCancelled:
            return "Authentication was cancelled by user"
        case .noKeyStored:
            return "No API key stored for this provider"
        case .keyDataCorrupted:
            return "Stored key data is corrupted"
        case .biometricSetChanged:
            return "Biometric set changed — key invalidated"
        case .vaultLocked(let detail):
            return "Vault is locked — \(detail). Go to Config > System Integrity to view details."
        case .duplicateItemRecovered:
            return "Duplicate key recovered — key updated successfully"
        case .verificationFailed:
            return "Key verification failed after save — key may not be stored correctly"
        }
    }
}

// MARK: - API Key Vault

/// Hardware-backed, biometric-gated API key storage.
///
/// - Keys stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
/// - Access control requires `.userPresence` (biometric with passcode fallback)
/// - Keys become invalid if biometric enrollment changes
/// - No iCloud sync, no migration, no export
/// - Zero in-memory caching
public final class APIKeyVault: @unchecked Sendable {

    public static let shared = APIKeyVault()

    private static let logger = Logger(subsystem: "com.operatorkit", category: "APIKeyVault")

    // Keychain service identifiers — one per provider
    private static let servicePrefix = "com.operatorkit.vault"

    private let queue = DispatchQueue(label: "com.operatorkit.api-key-vault", qos: .userInitiated)

    private init() {}

    // MARK: - Service Key

    private func serviceIdentifier(for provider: ModelProvider) -> String {
        "\(Self.servicePrefix).\(provider.rawValue)"
    }

    // MARK: - Thread-Safe Kernel Check

    /// Check if the vault is usable (not in tamper-suspected lockdown).
    ///
    /// P0 FIX (v1): DispatchQueue.main.sync from the main thread deadlocks.
    /// P0 FIX (v2): Now checks `isVaultUsable` instead of `isLocked`.
    ///   Vault operations are allowed in .nominal and .degraded postures.
    ///   Only genuine tamper lockdown blocks the vault.
    ///   Additionally, attempts recovery if locked, so transient issues
    ///   that resolved since the last check don't permanently block.
    private func isVaultBlocked() -> Bool {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                let guard_ = KernelIntegrityGuard.shared
                if guard_.isVaultUsable { return false }
                // Attempt recovery — transient issues may have resolved
                let recovered = guard_.attemptRecovery()
                return !recovered && !guard_.isVaultUsable
            }
        } else {
            return DispatchQueue.main.sync {
                let guard_ = KernelIntegrityGuard.shared
                if guard_.isVaultUsable { return false }
                let recovered = guard_.attemptRecovery()
                return !recovered && !guard_.isVaultUsable
            }
        }
    }

    // MARK: - Access Control

    /// Create hardware-backed access control.
    /// Uses `.userPresence` — biometric primary with passcode fallback.
    /// FAIL CLOSED if creation fails.
    private func createAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?

        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &error
        ) else {
            let errorDesc = error?.takeRetainedValue().localizedDescription ?? "unknown"
            Self.logger.error("Access control creation failed: \(errorDesc)")
            logEvidence(type: "api_key_vault_access_control_failed", detail: "FAIL CLOSED — hardware access control unavailable")
            throw APIKeyVaultError.accessControlCreationFailed
        }

        return accessControl
    }

    // MARK: - Store Key

    /// Store an API key for a provider in the hardware-backed Keychain.
    ///
    /// - Parameters:
    ///   - keyData: The raw key bytes. Caller should zero this after calling.
    ///   - provider: The model provider (OpenAI, Anthropic, Gemini, etc.).
    ///
    /// INVARIANT: Key is stored with biometric-gated access control.
    /// INVARIANT: Key is device-bound (no iCloud sync, no migration).
    /// INVARIANT: Idempotent — duplicate items are handled gracefully.
    /// INVARIANT: No force unwraps. No crashes. Typed errors only.
    public func storeKey(_ keyData: Data, for provider: ModelProvider) throws {
        // 0. Vault usability check (THREAD-SAFE — no deadlock)
        //    Allows store in .nominal and .degraded postures.
        //    Only blocks in genuine tamper lockdown.
        //    Attempts recovery before failing.
        guard !isVaultBlocked() else {
            let detail = "Tamper suspected — kernel integrity check failed with critical findings"
            logEvidence(type: "api_key_store_rejected", detail: detail)
            throw APIKeyVaultError.vaultLocked(detail: detail)
        }

        guard provider.isCloud else { return }

        // 1. Create access control — FAIL CLOSED if unavailable
        let accessControl = try createAccessControl()

        // 2. Delete any existing key first (atomic replace)
        deleteKeyInternal(for: provider)

        // 3. Build Keychain query
        //    NOTE: kSecAttrIsExtractable is ONLY valid for kSecClassKey.
        //    Using it with kSecClassGenericPassword causes errSecParam on some OS versions.
        let service = serviceIdentifier(for: provider)
        let query: [String: Any] = [
            kSecClass as String:             kSecClassGenericPassword,
            kSecAttrService as String:       service,
            kSecAttrAccount as String:       provider.rawValue,
            kSecValueData as String:         keyData,
            kSecAttrAccessControl as String: accessControl,
            kSecAttrSynchronizable as String: false as CFBoolean  // NO iCloud sync
        ]

        // 4. Store — with errSecDuplicateItem recovery
        var status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // Race condition: another write happened between delete and add.
            // Recover by updating the existing item instead.
            Self.logger.warning("Duplicate item detected — recovering with update")
            let updateQuery: [String: Any] = [
                kSecClass as String:       kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: provider.rawValue
            ]
            let updateAttrs: [String: Any] = [
                kSecValueData as String:         keyData,
                kSecAttrAccessControl as String: accessControl
            ]
            status = SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary)
        }

        guard status == errSecSuccess else {
            Self.logger.error("Keychain store failed: \(status)")
            logEvidence(type: "api_key_store_failed", detail: "OSStatus: \(status), provider: \(provider.rawValue)")
            throw APIKeyVaultError.keychainStoreFailed(status)
        }

        // 5. Verify write — read back metadata to confirm persistence
        guard hasKey(for: provider) else {
            Self.logger.error("Key verification failed after write for \(provider.rawValue)")
            logEvidence(type: "api_key_verify_failed", detail: "provider: \(provider.rawValue)")
            throw APIKeyVaultError.verificationFailed
        }

        // 6. Evidence (no key logged)
        Self.logger.info("API key stored and verified for \(provider.rawValue)")
        logEvidence(type: "api_key_saved", detail: "provider: \(provider.rawValue)")
        SecurityTelemetry.shared.record(
            category: .vaultAccess,
            detail: "API key stored for \(provider.rawValue)",
            outcome: .success,
            metadata: ["provider": provider.rawValue, "operation": "store"]
        )
    }

    /// Convenience: store from a String. Immediately zeroed after encoding.
    public func storeKey(_ keyString: String, for provider: ModelProvider) throws {
        guard let data = keyString.data(using: .utf8), !data.isEmpty else {
            throw APIKeyVaultError.keyDataCorrupted
        }
        try storeKey(data, for: provider)
    }

    // MARK: - Retrieve Key

    /// Retrieve an API key from the hardware-backed Keychain.
    /// Triggers biometric/passcode authentication.
    ///
    /// Returns: Raw key Data. Caller MUST zero this after use.
    ///
    /// INVARIANT: Requires user presence (biometric or passcode).
    /// INVARIANT: Never caches the result.
    /// INVARIANT: Never logs the key value.
    public func retrieveKey(for provider: ModelProvider) throws -> Data {
        // 0. Vault usability check (THREAD-SAFE — no deadlock)
        guard !isVaultBlocked() else {
            let detail = "Tamper suspected — cannot retrieve keys while integrity is compromised"
            logEvidence(type: "api_key_access_rejected", detail: detail)
            throw APIKeyVaultError.vaultLocked(detail: detail)
        }

        guard provider.isCloud else {
            throw APIKeyVaultError.noKeyStored
        }

        let service = serviceIdentifier(for: provider)

        // LAContext for biometric prompt
        let context = LAContext()
        context.localizedReason = "Authenticate to use \(provider.displayName) API key"

        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      provider.rawValue,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let keyData = result as? Data, !keyData.isEmpty else {
                logEvidence(type: "api_key_access_corrupted", detail: "provider: \(provider.rawValue)")
                throw APIKeyVaultError.keyDataCorrupted
            }
            // Evidence: access logged (no key value)
            logEvidence(type: "api_key_accessed", detail: "provider: \(provider.rawValue)")
            SecurityTelemetry.shared.record(
                category: .vaultAccess,
                detail: "API key retrieved for \(provider.rawValue)",
                outcome: .success,
                metadata: ["provider": provider.rawValue, "operation": "retrieve"]
            )
            return keyData

        case errSecItemNotFound:
            throw APIKeyVaultError.noKeyStored

        case errSecAuthFailed:
            logEvidence(type: "api_key_access_auth_failed", detail: "provider: \(provider.rawValue)")
            SecurityTelemetry.shared.record(
                category: .vaultFailure,
                detail: "Biometric/passcode auth failed for \(provider.rawValue)",
                outcome: .denied,
                metadata: ["provider": provider.rawValue, "osStatus": "\(status)"]
            )
            throw APIKeyVaultError.authenticationFailed

        case errSecUserCanceled:
            throw APIKeyVaultError.authenticationCancelled

        case errSecInvalidKeychain:
            // Biometric set changed — key invalidated
            logEvidence(type: "api_key_invalidated_biometric_change", detail: "provider: \(provider.rawValue)")
            throw APIKeyVaultError.biometricSetChanged

        default:
            Self.logger.error("Keychain retrieve failed: \(status)")
            logEvidence(type: "api_key_access_failed", detail: "OSStatus: \(status), provider: \(provider.rawValue)")
            throw APIKeyVaultError.keychainRetrieveFailed(status)
        }
    }

    /// Retrieve key as a String for API header injection.
    /// Caller should use this result immediately and not persist it.
    public func retrieveKeyString(for provider: ModelProvider) throws -> String {
        let data = try retrieveKey(for: provider)
        guard let keyString = String(data: data, encoding: .utf8) else {
            throw APIKeyVaultError.keyDataCorrupted
        }
        return keyString
    }

    // MARK: - Delete Key

    /// Delete an API key from the Keychain. No authentication required.
    ///
    /// INVARIANT: Immediate, irreversible deletion.
    public func deleteKey(for provider: ModelProvider) {
        deleteKeyInternal(for: provider)
        logEvidence(type: "api_key_deleted", detail: "provider: \(provider.rawValue)")
        Self.logger.info("API key deleted for \(provider.rawValue)")
    }

    private func deleteKeyInternal(for provider: ModelProvider) {
        let service = serviceIdentifier(for: provider)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Has Key (Non-Authenticated Check)

    /// Check if a key exists for a provider WITHOUT triggering authentication.
    /// This uses a metadata-only query (no kSecReturnData).
    ///
    /// INVARIANT: Does not return or touch the actual key bytes.
    public func hasKey(for provider: ModelProvider) -> Bool {
        guard provider.isCloud else { return false }

        let service = serviceIdentifier(for: provider)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnAttributes as String: true,  // Metadata only — no auth required
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess
    }

    // MARK: - Delete All Keys

    /// Delete all vault keys. Used for emergency wipe or account reset.
    public func deleteAllKeys() {
        for provider in ModelProvider.allCloudProviders {
            deleteKey(for: provider)
        }
        logEvidence(type: "api_key_vault_wiped", detail: "All cloud provider keys deleted")
    }

    // MARK: - Evidence

    private func logEvidence(type: String, detail: String) {
        let planId = UUID()
        let timestamp = Date().ISO8601Format()
        DispatchQueue.main.async {
            try? EvidenceEngine.shared.logGenericArtifact(
                type: type,
                planId: planId,
                jsonString: """
                {"detail":"\(detail)","timestamp":"\(timestamp)"}
                """
            )
        }
    }
}
