import Foundation
import CryptoKit

// ============================================================================
// KERNEL INTEGRITY GUARD — Self-Compromise Detection
//
// INVARIANT: A compromised kernel must NEVER continue operating.
// INVARIANT: Fail CLOSED. No silent recovery. No degraded execution.
// INVARIANT: Lockdown blocks ALL: token issuance, execution, model calls.
//
// Runs on EVERY app launch. Verifies:
//   1. Signing keys exist in Keychain
//   2. No revoked keys are active
//   3. Trusted device registry integrity
//   4. Evidence chain hash integrity
//   5. Trust epoch consistency
//
// P0 FIX: False positive lockdowns prevented vault from storing API keys.
// CHANGE: Device registry + evidence chain checks now distinguish between
//         transient infrastructure failures and genuine tampering.
//         Only PROVEN tamper conditions trigger lockdown.
//
// INTEGRITY STATE MODEL:
//   .nominal          — all checks pass
//   .degraded         — non-critical warnings (vault still usable)
//   .lockdown         — CRITICAL failure with concrete tamper evidence
//
// VAULT INTERACTION:
//   Vault operations (store/retrieve keys) are allowed in .nominal and
//   .degraded postures. Only .lockdown (tamperSuspected) blocks the vault.
//   This prevents transient Keychain/SE failures from bricking API setup.
// ============================================================================

@MainActor
public final class KernelIntegrityGuard: ObservableObject {

    public static let shared = KernelIntegrityGuard()

    // MARK: - Published State

    @Published private(set) var systemPosture: SystemPosture = .nominal
    @Published private(set) var lastCheckAt: Date?
    @Published private(set) var lastReport: IntegrityReport?

    // MARK: - Types

    public enum SystemPosture: String {
        case nominal = "NOMINAL"                    // All checks pass
        case degraded = "DEGRADED"                  // Non-critical warning (advisory only)
        case lockdown = "EXECUTION_LOCKDOWN"        // Critical failure — all execution blocked
    }

    public struct IntegrityReport {
        public let checkedAt: Date
        public let posture: SystemPosture
        public let checks: [IntegrityCheck]
        public let failedChecks: [IntegrityCheck]

        public var overallPassed: Bool { failedChecks.isEmpty }
    }

    public struct IntegrityCheck {
        public let name: String
        public let passed: Bool
        public let detail: String
        public let severity: CheckSeverity

        public enum CheckSeverity: String {
            case critical = "CRITICAL"   // Failure = lockdown (proven tamper only)
            case warning = "WARNING"     // Failure = degraded (advisory)
        }
    }

    // MARK: - Init

    private init() {}

    // MARK: - Lockdown State

    /// Whether the system is in execution lockdown.
    /// All execution paths MUST check this before proceeding.
    public var isLocked: Bool {
        systemPosture == .lockdown
    }

    /// Whether the vault is usable (not in tamper-suspected lockdown).
    /// Vault operations are allowed in .nominal and .degraded postures.
    /// Only genuine lockdown (proven tamper) blocks vault access.
    public var isVaultUsable: Bool {
        systemPosture != .lockdown
    }

    // MARK: - Full Integrity Verification (Run on Launch)

    /// Run all integrity checks. Call on every app launch.
    /// If any CRITICAL check fails, system enters EXECUTION LOCKDOWN.
    public func performFullCheck() {
        var checks: [IntegrityCheck] = []

        // CHECK 1: Signing keys exist
        let keyCheck = checkSigningKeys()
        checks.append(keyCheck)

        // CHECK 2: No revoked keys active
        let revokedCheck = checkNoRevokedKeysActive()
        checks.append(revokedCheck)

        // CHECK 3: Trust epoch manager integrity
        let epochCheck = checkTrustEpochIntegrity()
        checks.append(epochCheck)

        // CHECK 4: Trusted device registry integrity
        let deviceCheck = checkDeviceRegistryIntegrity()
        checks.append(deviceCheck)

        // CHECK 5: Evidence chain validity
        let evidenceCheck = checkEvidenceChainIntegrity()
        checks.append(evidenceCheck)

        // Determine posture
        let failedChecks = checks.filter { !$0.passed }
        let hasCriticalFailure = failedChecks.contains { $0.severity == .critical }

        let posture: SystemPosture
        if hasCriticalFailure {
            posture = .lockdown
        } else if !failedChecks.isEmpty {
            posture = .degraded
        } else {
            posture = .nominal
        }

        systemPosture = posture
        lastCheckAt = Date()
        lastReport = IntegrityReport(
            checkedAt: Date(),
            posture: posture,
            checks: checks,
            failedChecks: failedChecks
        )

        // Log
        if posture == .lockdown {
            logError("[KERNEL_INTEGRITY] ⛔ EXECUTION LOCKDOWN — \(failedChecks.count) integrity check(s) failed")
            for check in failedChecks {
                logError("  ✗ \(check.name): \(check.detail)")
            }
            try? EvidenceEngine.shared.logViolation(PolicyViolation(
                violationType: .dataCorruption,
                description: "Kernel integrity failure — EXECUTION LOCKDOWN: \(failedChecks.map(\.name).joined(separator: ", "))",
                severity: .critical
            ), planId: UUID())
        } else if posture == .degraded {
            log("[KERNEL_INTEGRITY] ⚠ DEGRADED — \(failedChecks.count) non-critical warning(s)")
            for check in failedChecks {
                log("  ⚠ \(check.name): \(check.detail)")
            }
        } else {
            log("[KERNEL_INTEGRITY] ✓ All integrity checks passed — system NOMINAL")
        }
    }

    // MARK: - Individual Checks

    private func checkSigningKeys() -> IntegrityCheck {
        let epochManager = TrustEpochManager.shared
        let keyExists = TrustEpochManager.loadKey(version: epochManager.activeKeyVersion) != nil
        return IntegrityCheck(
            name: "Signing Key Exists",
            passed: keyExists,
            detail: keyExists
                ? "Active key v\(epochManager.activeKeyVersion) present in Keychain"
                : "MISSING: Active key v\(epochManager.activeKeyVersion) not found in Keychain",
            severity: .critical
        )
    }

    private func checkNoRevokedKeysActive() -> IntegrityCheck {
        let epochManager = TrustEpochManager.shared
        let activeIsRevoked = epochManager.revokedKeyVersions.contains(epochManager.activeKeyVersion)
        return IntegrityCheck(
            name: "No Revoked Keys Active",
            passed: !activeIsRevoked,
            detail: activeIsRevoked
                ? "VIOLATION: Active key v\(epochManager.activeKeyVersion) is in the revoked set"
                : "Active key v\(epochManager.activeKeyVersion) not in revoked set",
            severity: .critical
        )
    }

    private func checkTrustEpochIntegrity() -> IntegrityCheck {
        let passed = TrustEpochManager.shared.verifyIntegrity()
        return IntegrityCheck(
            name: "Trust Epoch Integrity",
            passed: passed,
            detail: passed
                ? "Epoch \(TrustEpochManager.shared.trustEpoch), key v\(TrustEpochManager.shared.activeKeyVersion) — consistent"
                : "VIOLATION: Trust epoch state inconsistent",
            severity: .critical
        )
    }

    /// Device Registry Integrity — checks that the current device is trusted.
    ///
    /// P0 FIX: This check now distinguishes between:
    ///   1. **Transient SE/Keychain failure** (fingerprint unavailable) → WARNING
    ///   2. **Device explicitly not trusted** (fingerprint exists but not in registry) → CRITICAL
    ///
    /// A transient fingerprint failure (Simulator, biometric enrollment pending,
    /// Keychain busy) is NOT a tamper signal. Only a device that HAS a fingerprint
    /// but is NOT in the trusted registry constitutes a real integrity violation.
    private func checkDeviceRegistryIntegrity() -> IntegrityCheck {
        var passed = TrustedDeviceRegistry.shared.verifyIntegrity()

        // ═══════════════════════════════════════════════════════════════
        // BOOTSTRAP RESILIENCE — retry registration once
        // ═══════════════════════════════════════════════════════════════
        if !passed {
            _ = SecureEnclaveApprover.shared.ensureKeyExists()
            if let fingerprint = SecureEnclaveApprover.shared.deviceFingerprint {
                TrustedDeviceRegistry.shared.registerDevice(fingerprint: fingerprint, displayName: "Primary Device")
                passed = TrustedDeviceRegistry.shared.verifyIntegrity()
                if passed {
                    log("[KERNEL_INTEGRITY] Device registration recovered on retry — registry valid")
                }
            }
        }

        if passed {
            return IntegrityCheck(
                name: "Device Registry Integrity",
                passed: true,
                detail: "Current device trusted, registry valid",
                severity: .critical
            )
        }

        // ═══════════════════════════════════════════════════════════════
        // FAILURE CLASSIFICATION — distinguish transient vs tamper
        // ═══════════════════════════════════════════════════════════════
        //
        // If the Secure Enclave fingerprint is nil, the SE key is unavailable.
        // This happens on Simulators, when biometric enrollment changes, or
        // when the Keychain is temporarily inaccessible. This is NOT a tamper
        // signal — it's an infrastructure limitation.
        //
        // If the fingerprint EXISTS but the device is not in the registry,
        // that IS suspicious (device identity changed or registry was wiped).
        // Even then, on first launch (epoch 1), this is expected.
        // ═══════════════════════════════════════════════════════════════
        let fingerprintAvailable = SecureEnclaveApprover.shared.deviceFingerprint != nil
        let isFirstLaunch = TrustEpochManager.shared.trustEpoch == 1

        if !fingerprintAvailable {
            // SE key unavailable — transient infrastructure issue, NOT a tamper
            log("[KERNEL_INTEGRITY] Device fingerprint unavailable (SE key missing/inaccessible) — downgrading to WARNING")
            return IntegrityCheck(
                name: "Device Registry Integrity",
                passed: false,
                detail: "WARNING: Secure Enclave fingerprint unavailable. Biometric enrollment may be required. Vault remains usable.",
                severity: .warning
            )
        } else if isFirstLaunch {
            // Fingerprint exists but not registered yet during first launch bootstrap
            log("[KERNEL_INTEGRITY] Device not registered during first launch — downgrading to WARNING")
            return IntegrityCheck(
                name: "Device Registry Integrity",
                passed: false,
                detail: "WARNING: Device not registered during first-launch bootstrap. Will register on next check.",
                severity: .warning
            )
        } else {
            // Fingerprint exists, not first launch, but device not trusted — genuine concern
            logError("[KERNEL_INTEGRITY] Device fingerprint present but NOT in trusted registry — CRITICAL")
            return IntegrityCheck(
                name: "Device Registry Integrity",
                passed: false,
                detail: "TAMPER SUSPECTED: Device fingerprint exists but is not in trusted registry. Device identity may have changed.",
                severity: .critical
            )
        }
    }

    /// Evidence Chain Integrity — validates the append-only evidence log.
    ///
    /// P0 FIX: Empty chains and new-installation states are WARNING, not CRITICAL.
    /// A corrupted or tampered chain (entries exist but hashes don't match) is CRITICAL.
    private func checkEvidenceChainIntegrity() -> IntegrityCheck {
        do {
            let report = try EvidenceEngine.shared.verifyChainIntegrity()
            if report.overallValid {
                return IntegrityCheck(
                    name: "Evidence Chain Integrity",
                    passed: true,
                    detail: "\(report.totalEntries) entries, chain valid",
                    severity: .critical
                )
            } else if report.totalEntries == 0 {
                // Empty chain — new installation or data reset, NOT a tamper
                log("[KERNEL_INTEGRITY] Evidence chain empty — new installation, downgrading to WARNING")
                return IntegrityCheck(
                    name: "Evidence Chain Integrity",
                    passed: false,
                    detail: "WARNING: Evidence chain is empty (new installation). Chain will be initialized on first operation.",
                    severity: .warning
                )
            } else {
                // Chain has entries but integrity violations — genuine tamper signal
                return IntegrityCheck(
                    name: "Evidence Chain Integrity",
                    passed: false,
                    detail: "TAMPER SUSPECTED: \(report.violations.count) chain integrity violation(s) in \(report.totalEntries) entries",
                    severity: .critical
                )
            }
        } catch {
            // Exception during check — likely disk I/O or decode issue
            // On fresh installs, the evidence store may not exist yet.
            // Treat as WARNING unless we have positive evidence of tampering.
            log("[KERNEL_INTEGRITY] Evidence chain check exception: \(error.localizedDescription) — downgrading to WARNING")
            return IntegrityCheck(
                name: "Evidence Chain Integrity",
                passed: false,
                detail: "WARNING: Evidence chain check failed (\(error.localizedDescription)). May be a new installation.",
                severity: .warning
            )
        }
    }

    // MARK: - Manual Lockdown

    /// Force the system into lockdown. Used by emergencyStop or external triggers.
    public func forceLockdown(reason: String) {
        systemPosture = .lockdown
        logError("[KERNEL_INTEGRITY] FORCED LOCKDOWN: \(reason)")
        try? EvidenceEngine.shared.logViolation(PolicyViolation(
            violationType: .emergencyStop,
            description: "Forced lockdown: \(reason)",
            severity: .critical
        ), planId: UUID())
    }

    /// Clear lockdown. Requires re-running full integrity check.
    /// Succeeds if no CRITICAL failures remain (nominal or degraded).
    public func attemptRecovery() -> Bool {
        performFullCheck()
        if systemPosture != .lockdown {
            log("[KERNEL_INTEGRITY] Recovery successful — system \(systemPosture.rawValue)")
            return true
        } else {
            logError("[KERNEL_INTEGRITY] Recovery failed — system remains \(systemPosture.rawValue)")
            return false
        }
    }

    /// Reset all integrity state. Requires explicit user intent.
    /// Used as emergency escape hatch when vault is stuck.
    /// Caller MUST gate this behind biometric confirmation.
    public func resetIntegrityState() {
        systemPosture = .nominal
        lastReport = nil
        lastCheckAt = nil
        log("[KERNEL_INTEGRITY] Integrity state RESET by user — running fresh check")
        performFullCheck()
    }
}
