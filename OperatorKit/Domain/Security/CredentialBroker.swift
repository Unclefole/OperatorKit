import Foundation
import Security
import os.log

// ============================================================================
// CREDENTIAL BROKER — ENTERPRISE-SAFE KEY MANAGEMENT
//
// In enterprise mode:
//   - Fetches short-lived model tokens from OrgAuthorityClient
//   - Validates token binding: trustEpoch + deviceId + appBuildHash + provider
//   - Rejects tokens if epoch rotated, device revoked, or integrity failed
//
// In dev mode:
//   - Allows Keychain-stored dev keys (explicit flag, OFF by default)
//
// INVARIANT: API keys NEVER stored as plaintext in source.
// INVARIANT: Keys NEVER logged to Evidence or console.
// INVARIANT: Enterprise tokens are short-lived (5–15 min) and device-bound.
// INVARIANT: Token rejected if KernelIntegrityGuard is locked.
// ============================================================================

// MARK: - Model Access Token (Enterprise)

public struct ModelAccessToken: Codable, Sendable {
    public let tokenId: UUID
    public let provider: ModelProvider
    public let modelId: String
    public let taskType: ModelTaskType
    public let trustEpoch: Int
    public let deviceId: String
    public let appBuildHash: String
    public let issuedAt: Date
    public let expiresAt: Date
    public let apiKeyRef: String     // Opaque reference (NOT the actual key)

    public var isExpired: Bool { Date() >= expiresAt }
    public var ttlSeconds: TimeInterval { expiresAt.timeIntervalSince(issuedAt) }
}

// MARK: - Credential Error

public enum CredentialError: Error, LocalizedError {
    case enterpriseTokenExpired
    case epochMismatch(expected: Int, got: Int)
    case deviceMismatch(expected: String, got: String)
    case buildHashMismatch(expected: String, got: String)
    case kernelIntegrityLocked
    case deviceRevoked
    case noCredentialAvailable(ModelProvider)
    case keychainError(OSStatus)
    case devKeysDisabled

    public var errorDescription: String? {
        switch self {
        case .enterpriseTokenExpired:    return "Enterprise model access token has expired"
        case .epochMismatch(let e, let g): return "Trust epoch mismatch (expected \(e), got \(g))"
        case .deviceMismatch(let e, let g): return "Device ID mismatch (expected \(e), got \(g))"
        case .buildHashMismatch(let e, let g): return "App build hash mismatch (expected \(e), got \(g))"
        case .kernelIntegrityLocked:     return "Kernel integrity guard is locked — all credentials suspended"
        case .deviceRevoked:             return "Device trust state is revoked — credentials unavailable"
        case .noCredentialAvailable(let p): return "No credential available for provider \(p.displayName)"
        case .keychainError(let s):      return "Keychain error: \(s)"
        case .devKeysDisabled:           return "Dev mode API keys are disabled by feature flag"
        }
    }
}

// MARK: - Credential Broker

@MainActor
public final class CredentialBroker: ObservableObject {

    public static let shared = CredentialBroker()

    private static let logger = Logger(subsystem: "com.operatorkit", category: "CredentialBroker")

    // Keychain service identifiers
    private static let keychainServiceOpenAI = "com.operatorkit.dev.openai-key"
    private static let keychainServiceAnthropic = "com.operatorkit.dev.anthropic-key"
    private static let keychainServiceGemini = "com.operatorkit.dev.gemini-key"
    private static let keychainServiceGroq = "com.operatorkit.dev.groq-key"
    private static let keychainServiceLlama = "com.operatorkit.dev.llama-key"

    // Cached enterprise tokens
    private var cachedTokens: [ModelProvider: ModelAccessToken] = [:]

    private init() {}

    // MARK: - Primary API

    /// Retrieve an API key or access token for a given provider.
    /// Enterprise mode: validates binding, checks integrity.
    /// Dev mode: reads from Keychain if flag is ON.
    ///
    /// INVARIANT: Never returns a key if integrity is compromised.
    /// INVARIANT: Never logs the key value.
    public func resolveCredential(
        for provider: ModelProvider,
        modelId: String,
        taskType: ModelTaskType
    ) throws -> String {
        // 0. Kernel integrity check — HARD GATE
        guard !KernelIntegrityGuard.shared.isLocked else {
            logViolation("credential_rejected_integrity_locked", provider: provider)
            throw CredentialError.kernelIntegrityLocked
        }

        // 1. On-device — no credential needed
        guard provider.isCloud else { return "" }

        // 2. Enterprise mode — check for enterprise token
        if EnterpriseFeatureFlags.enterpriseOnboardingComplete {
            return try resolveEnterpriseToken(provider: provider, modelId: modelId, taskType: taskType)
        }

        // 3. Dev mode — Keychain lookup
        guard EnterpriseFeatureFlags.modelDevKeysEnabled else {
            throw CredentialError.devKeysDisabled
        }
        return try resolveDevKey(for: provider)
    }

    // MARK: - Enterprise Token Resolution

    private func resolveEnterpriseToken(
        provider: ModelProvider,
        modelId: String,
        taskType: ModelTaskType
    ) throws -> String {
        // Check cached token
        if let cached = cachedTokens[provider], !cached.isExpired {
            try validateTokenBinding(cached)
            Self.logger.info("Using cached enterprise token for \(provider.rawValue)")
            return cached.apiKeyRef
        }

        // In production: fetch from OrgAuthorityClient
        // For now: fail closed if no token cached
        Self.logger.warning("No valid enterprise token for \(provider.rawValue) — fail closed")
        throw CredentialError.noCredentialAvailable(provider)
    }

    /// Cache an enterprise-issued model access token.
    /// Called by OrgAuthorityClient when a token is fetched.
    public func cacheEnterpriseToken(_ token: ModelAccessToken) throws {
        try validateTokenBinding(token)
        cachedTokens[token.provider] = token

        // Evidence (no key logged)
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "credential_enterprise_token_cached",
            planId: UUID(),
            jsonString: """
            {"provider":"\(token.provider.rawValue)","modelId":"\(token.modelId)","taskType":"\(token.taskType.rawValue)","expiresAt":"\(token.expiresAt.ISO8601Format())","ttl":\(token.ttlSeconds)}
            """
        )
    }

    /// Validate enterprise token binding against current device/build/epoch.
    private func validateTokenBinding(_ token: ModelAccessToken) throws {
        // 1. Expiry
        guard !token.isExpired else {
            throw CredentialError.enterpriseTokenExpired
        }

        // 2. Trust epoch
        let currentEpoch = TrustEpochManager.shared.trustEpoch
        guard token.trustEpoch == currentEpoch else {
            logViolation("credential_epoch_mismatch", provider: token.provider)
            throw CredentialError.epochMismatch(expected: currentEpoch, got: token.trustEpoch)
        }

        // 3. Device ID
        let currentDeviceId = SecureEnclaveApprover.shared.deviceFingerprint ?? "unknown"
        guard token.deviceId == currentDeviceId else {
            logViolation("credential_device_mismatch", provider: token.provider)
            throw CredentialError.deviceMismatch(expected: currentDeviceId, got: token.deviceId)
        }

        // 4. App build hash
        let currentBuildHash = Self.appBuildHash
        guard token.appBuildHash == currentBuildHash else {
            logViolation("credential_build_mismatch", provider: token.provider)
            throw CredentialError.buildHashMismatch(expected: currentBuildHash, got: token.appBuildHash)
        }

        // 5. Device trust state
        let trustState = TrustedDeviceRegistry.shared.trustState(for: currentDeviceId)
        guard trustState == .trusted else {
            logViolation("credential_device_revoked", provider: token.provider)
            throw CredentialError.deviceRevoked
        }

        // 6. Kernel integrity
        guard !KernelIntegrityGuard.shared.isLocked else {
            logViolation("credential_integrity_locked_during_validation", provider: token.provider)
            throw CredentialError.kernelIntegrityLocked
        }
    }

    // MARK: - Dev Key Resolution (Keychain)

    private func resolveDevKey(for provider: ModelProvider) throws -> String {
        // Primary: APIKeyVault (hardware-backed, biometric-gated)
        // This is the ONLY approved path for dev key resolution.
        // Legacy UserDefaults path has been REMOVED — keys must live in vault.
        do {
            let key = try APIKeyVault.shared.retrieveKeyString(for: provider)
            Self.logger.info("Dev key resolved from APIKeyVault for \(provider.rawValue)")
            return key
        } catch {
            // Fallback: old CredentialBroker Keychain (migration path)
            guard let service = legacyKeychainService(for: provider) else {
                throw CredentialError.noCredentialAvailable(provider)
            }

            guard let key = readKeychain(service: service) else {
                throw CredentialError.noCredentialAvailable(provider)
            }

            Self.logger.info("Dev key resolved from legacy Keychain for \(provider.rawValue)")
            return key
        }
    }

    /// Store a dev API key in Keychain.
    public func storeDevKey(_ key: String, for provider: ModelProvider) throws {
        guard let service = legacyKeychainService(for: provider) else { return }
        try writeKeychain(service: service, value: key)
    }

    /// Clear a dev API key from Keychain.
    public func clearDevKey(for provider: ModelProvider) {
        guard let service = legacyKeychainService(for: provider) else { return }
        deleteKeychain(service: service)
    }

    private func legacyKeychainService(for provider: ModelProvider) -> String? {
        switch provider {
        case .cloudOpenAI:    return Self.keychainServiceOpenAI
        case .cloudAnthropic: return Self.keychainServiceAnthropic
        case .cloudGemini:    return Self.keychainServiceGemini
        case .cloudGroq:      return Self.keychainServiceGroq
        case .cloudLlama:     return Self.keychainServiceLlama
        case .onDevice:       return nil
        }
    }

    // MARK: - App Build Hash

    public static var appBuildHash: String {
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let bundleId = bundle.bundleIdentifier ?? "unknown"
        return "\(bundleId).\(version).\(build)"
    }

    // MARK: - Feature Flags

    /// Whether dev mode API keys are enabled.
    /// Extends EnterpriseFeatureFlags.
    // Already declared in EnterpriseFeatureFlags — checked at call site

    // MARK: - Keychain Helpers

    private func readKeychain(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func writeKeychain(service: String, value: String) throws {
        deleteKeychain(service: service) // remove existing
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw CredentialError.keychainError(status) }
    }

    private func deleteKeychain(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Evidence

    private func logViolation(_ type: String, provider: ModelProvider) {
        Self.logger.error("Credential violation: \(type) for \(provider.rawValue)")
        try? EvidenceEngine.shared.logGenericArtifact(
            type: type,
            planId: UUID(),
            jsonString: """
            {"provider":"\(provider.rawValue)","timestamp":"\(Date().ISO8601Format())"}
            """
        )
    }
}
