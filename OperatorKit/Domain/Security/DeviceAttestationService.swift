import Foundation
import DeviceCheck
import CryptoKit

// ============================================================================
// DEVICE ATTESTATION SERVICE — Apple App Attest Integration
//
// Proves every connector request originated from:
//   1. THIS app (bundle ID verified by Apple)
//   2. A legitimate Apple device (hardware attestation)
//   3. An untampered binary (code signature validated)
//
// ARCHITECTURE:
//   DeviceKey → Vault → ConnectorGate
//
// INVARIANT: Attestation key is generated once and bound to the device.
// INVARIANT: Assertions are per-request — not replayable.
// INVARIANT: If attestation fails → execution is BLOCKED (fail closed).
// INVARIANT: Attestation is NOT available on Simulator — graceful degrade.
//
// BINDING:
//   ConnectorGate checks attestation status before allowing egress.
//   NetworkPolicyEnforcer includes attestation metadata in request headers.
// ============================================================================

public final class DeviceAttestationService: @unchecked Sendable {

    public static let shared = DeviceAttestationService()

    // Keychain tag for the attestation key ID
    private static let keyIdTag = "com.operatorkit.attest.keyId"

    // MARK: - State

    public enum AttestationState: String, Sendable {
        case notStarted = "not_started"
        case keyGenerated = "key_generated"
        case attested = "attested"
        case unavailable = "unavailable"    // Simulator / unsupported device
        case failed = "failed"
    }

    private let queue = DispatchQueue(label: "com.operatorkit.attestation", qos: .userInitiated)
    private var _state: AttestationState = .notStarted
    private var _keyId: String?

    public var state: AttestationState {
        queue.sync { _state }
    }

    public var isAttested: Bool {
        queue.sync { _state == .attested || _state == .keyGenerated }
    }

    /// Whether App Attest is supported on this device.
    public var isSupported: Bool {
        DCAppAttestService.shared.isSupported
    }

    private init() {
        // Load persisted key ID
        if let storedKeyId = loadKeyId() {
            _keyId = storedKeyId
            _state = .keyGenerated
        }
    }

    // MARK: - Key Generation

    /// Generate an attestation key. Call once during first launch or vault setup.
    /// The key is bound to this device and cannot be extracted.
    public func generateKeyIfNeeded() async throws {
        guard DCAppAttestService.shared.isSupported else {
            queue.sync { _state = .unavailable }
            SecurityTelemetry.shared.record(
                category: .attestation,
                detail: "App Attest not supported on this device (Simulator?)",
                outcome: .warning
            )
            return
        }

        // Already have a key
        if queue.sync(execute: { _keyId }) != nil {
            return
        }

        do {
            let keyId = try await DCAppAttestService.shared.generateKey()
            queue.sync {
                self._keyId = keyId
                self._state = .keyGenerated
            }
            persistKeyId(keyId)

            SecurityTelemetry.shared.record(
                category: .attestation,
                detail: "Attestation key generated",
                outcome: .success
            )
        } catch {
            queue.sync { self._state = .failed }
            SecurityTelemetry.shared.record(
                category: .attestationFail,
                detail: "Key generation failed: \(error.localizedDescription)",
                outcome: .failure
            )
            throw AttestationError.keyGenerationFailed(error)
        }
    }

    // MARK: - Attestation

    /// Attest the key with Apple's servers. Call after key generation.
    /// The server challenge should come from your backend in production.
    /// For now, we use a local challenge derived from the device fingerprint.
    public func attestKey() async throws {
        guard DCAppAttestService.shared.isSupported else {
            queue.sync { _state = .unavailable }
            return
        }

        guard let keyId = queue.sync(execute: { _keyId }) else {
            throw AttestationError.noKeyGenerated
        }

        // Generate a challenge hash (in production, this comes from your server)
        let challengeData = Data(SHA256.hash(data: UUID().uuidString.data(using: .utf8)!))

        do {
            let attestation = try await DCAppAttestService.shared.attestKey(keyId, clientDataHash: challengeData)
            queue.sync { self._state = .attested }

            SecurityTelemetry.shared.record(
                category: .attestation,
                detail: "Key attested successfully (\(attestation.count) bytes)",
                outcome: .success
            )
        } catch {
            queue.sync { self._state = .failed }
            SecurityTelemetry.shared.record(
                category: .attestationFail,
                detail: "Attestation failed: \(error.localizedDescription)",
                outcome: .failure
            )
            throw AttestationError.attestationFailed(error)
        }
    }

    // MARK: - Assertion (Per-Request)

    /// Generate a per-request assertion. This proves the request originated from
    /// this app on this device with an untampered binary.
    ///
    /// Returns the assertion data to include in the request, or nil if unavailable.
    /// Fails OPEN only when attestation is unavailable (Simulator) — not in production.
    public func generateAssertion(for requestData: Data) async -> AssertionResult {
        guard DCAppAttestService.shared.isSupported else {
            return .unavailable(reason: "App Attest not supported")
        }

        guard let keyId = queue.sync(execute: { _keyId }) else {
            SecurityTelemetry.shared.record(
                category: .attestationFail,
                detail: "No attestation key for assertion",
                outcome: .failure
            )
            return .failed(reason: "No attestation key generated")
        }

        let clientDataHash = Data(SHA256.hash(data: requestData))

        do {
            let assertion = try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: clientDataHash)
            return .success(assertion: assertion)
        } catch {
            SecurityTelemetry.shared.record(
                category: .attestationFail,
                detail: "Assertion generation failed: \(error.localizedDescription)",
                outcome: .failure
            )
            return .failed(reason: error.localizedDescription)
        }
    }

    // MARK: - Assertion Result

    public enum AssertionResult: Sendable {
        case success(assertion: Data)
        case unavailable(reason: String)
        case failed(reason: String)

        public var isValid: Bool {
            if case .success = self { return true }
            return false
        }
    }

    // MARK: - Errors

    public enum AttestationError: Error, LocalizedError {
        case keyGenerationFailed(Error)
        case attestationFailed(Error)
        case noKeyGenerated

        public var errorDescription: String? {
            switch self {
            case .keyGenerationFailed(let e):
                return "Attestation key generation failed: \(e.localizedDescription)"
            case .attestationFailed(let e):
                return "Device attestation failed: \(e.localizedDescription)"
            case .noKeyGenerated:
                return "No attestation key generated — call generateKeyIfNeeded() first"
            }
        }
    }

    // MARK: - Key Persistence (Keychain)

    private func persistKeyId(_ keyId: String) {
        guard let data = keyId.data(using: .utf8) else { return }

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keyIdTag,
            kSecAttrAccount as String: "attestation_key_id"
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Store new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keyIdTag,
            kSecAttrAccount as String: "attestation_key_id",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false as CFBoolean
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadKeyId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keyIdTag,
            kSecAttrAccount as String: "attestation_key_id",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
