import Foundation
import CryptoKit

// ============================================================================
// TRUSTED DEVICE REGISTRY — Governed Hardware Identity
//
// INVARIANT: Only explicitly trusted hardware identities may execute.
// INVARIANT: Revoked devices cannot request tokens. FAIL CLOSED.
// INVARIANT: Suspended devices block until reinstated.
// INVARIANT: Trust state is persisted — survives restart.
//
// Every Secure Enclave public key fingerprint is a registered operator.
// This is the root of hardware-backed authority.
// ============================================================================

@MainActor
public final class TrustedDeviceRegistry: ObservableObject {

    public static let shared = TrustedDeviceRegistry()

    // MARK: - State

    @Published private(set) var devices: [TrustedDevice] = []

    // MARK: - Storage

    private let storeFileURL: URL

    // MARK: - Types

    public struct TrustedDevice: Codable, Identifiable {
        public let id: UUID
        public let devicePublicKeyFingerprint: String
        public var trustState: TrustState
        public let registeredAt: Date
        public var revokedAt: Date?
        public var revocationReason: String?
        public var suspendedAt: Date?
        public var suspensionReason: String?
        public var displayName: String

        public enum TrustState: String, Codable {
            case trusted = "trusted"
            case revoked = "revoked"
            case suspended = "suspended"
        }
    }

    // MARK: - Init

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("KernelSecurity", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.storeFileURL = dir.appendingPathComponent("trusted_device_registry.json")
        loadDevices()
        ensureCurrentDeviceRegistered()
    }

    // MARK: - Registration

    /// Register a device by its SE public key fingerprint.
    /// Called automatically for the current device on first launch.
    public func registerDevice(fingerprint: String, displayName: String = "This Device") {
        guard !devices.contains(where: { $0.devicePublicKeyFingerprint == fingerprint }) else {
            return // Already registered
        }
        let device = TrustedDevice(
            id: UUID(),
            devicePublicKeyFingerprint: fingerprint,
            trustState: .trusted,
            registeredAt: Date(),
            displayName: displayName
        )
        devices.append(device)
        persist()

        log("[DEVICE_REGISTRY] Device registered: \(fingerprint.prefix(16))... as '\(displayName)'")
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "device_registered",
            planId: UUID(),
            jsonString: """
            {"fingerprint":"\(fingerprint.prefix(32))...","displayName":"\(displayName)","registeredAt":"\(Date())"}
            """
        )
    }

    // MARK: - Trust State Checks

    /// Check if a device fingerprint is currently trusted.
    /// Returns false for revoked, suspended, or unknown devices.
    public func isDeviceTrusted(fingerprint: String) -> Bool {
        guard let device = devices.first(where: { $0.devicePublicKeyFingerprint == fingerprint }) else {
            return false // Unknown device
        }
        return device.trustState == .trusted
    }

    /// Check if the CURRENT device is trusted.
    public var isCurrentDeviceTrusted: Bool {
        guard let fingerprint = SecureEnclaveApprover.shared.deviceFingerprint else {
            return false
        }
        return isDeviceTrusted(fingerprint: fingerprint)
    }

    /// Get the trust state for a device, or nil if unknown.
    public func trustState(for fingerprint: String) -> TrustedDevice.TrustState? {
        devices.first(where: { $0.devicePublicKeyFingerprint == fingerprint })?.trustState
    }

    // MARK: - Revocation

    /// Revoke a device. Immediate. No grace window.
    /// Revoked devices can NEVER request tokens or execute.
    public func revokeDevice(fingerprint: String, reason: String) {
        guard let index = devices.firstIndex(where: { $0.devicePublicKeyFingerprint == fingerprint }) else {
            logError("[DEVICE_REGISTRY] Cannot revoke unknown device: \(fingerprint.prefix(16))...")
            return
        }
        devices[index].trustState = .revoked
        devices[index].revokedAt = Date()
        devices[index].revocationReason = reason
        persist()

        // Advance trust epoch — all outstanding tokens become invalid
        TrustEpochManager.shared.advanceEpoch(reason: "Device revoked: \(reason)")

        log("[DEVICE_REGISTRY] Device REVOKED: \(fingerprint.prefix(16))... reason: \(reason)")
        try? EvidenceEngine.shared.logViolation(PolicyViolation(
            violationType: .unauthorizedExecution,
            description: "Device revoked: \(fingerprint.prefix(32))... reason: \(reason)",
            severity: .critical
        ), planId: UUID())
    }

    // MARK: - Suspension

    /// Suspend a device. Blocks execution until reinstated.
    public func suspendDevice(fingerprint: String, reason: String) {
        guard let index = devices.firstIndex(where: { $0.devicePublicKeyFingerprint == fingerprint }) else {
            return
        }
        devices[index].trustState = .suspended
        devices[index].suspendedAt = Date()
        devices[index].suspensionReason = reason
        persist()

        log("[DEVICE_REGISTRY] Device SUSPENDED: \(fingerprint.prefix(16))... reason: \(reason)")
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "device_suspended",
            planId: UUID(),
            jsonString: """
            {"fingerprint":"\(fingerprint.prefix(32))...","reason":"\(reason)","suspendedAt":"\(Date())"}
            """
        )
    }

    /// Reinstate a suspended device. Revoked devices cannot be reinstated.
    public func reinstateDevice(fingerprint: String) {
        guard let index = devices.firstIndex(where: { $0.devicePublicKeyFingerprint == fingerprint }),
              devices[index].trustState == .suspended else {
            logError("[DEVICE_REGISTRY] Cannot reinstate — device not suspended or not found")
            return
        }
        devices[index].trustState = .trusted
        devices[index].suspendedAt = nil
        devices[index].suspensionReason = nil
        persist()

        log("[DEVICE_REGISTRY] Device REINSTATED: \(fingerprint.prefix(16))...")
    }

    // MARK: - Integrity

    /// Verify registry integrity. Returns false if registry is empty or current device missing.
    public func verifyIntegrity() -> Bool {
        guard !devices.isEmpty else {
            logError("[DEVICE_REGISTRY] INTEGRITY FAILURE: Registry is empty")
            return false
        }
        guard isCurrentDeviceTrusted else {
            logError("[DEVICE_REGISTRY] INTEGRITY FAILURE: Current device not trusted")
            return false
        }
        return true
    }

    // MARK: - Persistence

    private func loadDevices() {
        guard let data = try? Data(contentsOf: storeFileURL),
              let loaded = try? JSONDecoder().decode([TrustedDevice].self, from: data) else {
            devices = []
            return
        }
        devices = loaded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        try? data.write(to: storeFileURL, options: .atomic)
    }

    // MARK: - Auto-Registration

    private func ensureCurrentDeviceRegistered() {
        // Ensure SE key exists
        _ = SecureEnclaveApprover.shared.ensureKeyExists()
        guard let fingerprint = SecureEnclaveApprover.shared.deviceFingerprint else {
            log("[DEVICE_REGISTRY] No SE fingerprint available — device not registered")
            return
        }
        if !devices.contains(where: { $0.devicePublicKeyFingerprint == fingerprint }) {
            registerDevice(fingerprint: fingerprint, displayName: "Primary Device")
        }
    }
}
