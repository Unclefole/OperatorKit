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
// If ANY check fails → KernelIntegrityFailure → EXECUTION LOCKDOWN.
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
            case critical = "CRITICAL"   // Failure = lockdown
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

    private func checkDeviceRegistryIntegrity() -> IntegrityCheck {
        let passed = TrustedDeviceRegistry.shared.verifyIntegrity()
        return IntegrityCheck(
            name: "Device Registry Integrity",
            passed: passed,
            detail: passed
                ? "Current device trusted, registry valid"
                : "VIOLATION: Current device not trusted or registry empty",
            severity: .critical
        )
    }

    private func checkEvidenceChainIntegrity() -> IntegrityCheck {
        do {
            let report = try EvidenceEngine.shared.verifyChainIntegrity()
            return IntegrityCheck(
                name: "Evidence Chain Integrity",
                passed: report.overallValid,
                detail: report.overallValid
                    ? "\(report.totalEntries) entries, chain valid"
                    : "VIOLATION: \(report.violations.count) chain integrity violation(s)",
                severity: .critical
            )
        } catch {
            return IntegrityCheck(
                name: "Evidence Chain Integrity",
                passed: false,
                detail: "EXCEPTION: \(error.localizedDescription)",
                severity: .critical
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
    /// Only succeeds if ALL checks now pass.
    public func attemptRecovery() -> Bool {
        performFullCheck()
        if systemPosture == .nominal {
            log("[KERNEL_INTEGRITY] Recovery successful — system NOMINAL")
            return true
        } else {
            logError("[KERNEL_INTEGRITY] Recovery failed — system remains \(systemPosture.rawValue)")
            return false
        }
    }
}
