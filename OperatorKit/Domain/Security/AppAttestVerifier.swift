import Foundation
import CryptoKit

// ============================================================================
// APP ATTEST VERIFIER — Attestation Verification with TTL Cache
//
// Validates that the device has:
//   1. Generated an App Attest key (DCAppAttestService)
//   2. Attested the key with Apple servers
//   3. Has a valid, non-expired attestation verdict
//
// In production with a backend: server validates the CBOR attestation object
// and returns a signed verdict. For on-device-only deployments, we verify
// key generation + attestation completion + TTL freshness.
//
// INVARIANT: Unverified devices CANNOT execute connectors (professional/enterprise).
// INVARIANT: Verification verdict expires after TTL — re-attestation required.
// INVARIANT: Simulator is ALWAYS denied in release builds.
// INVARIANT: Cache is in-memory only — no disk persistence of verdicts.
// ============================================================================

public final class AppAttestVerifier: @unchecked Sendable {

    public static let shared = AppAttestVerifier()

    // TTL for cached verdicts — 24 hours
    private static let verdictTTL: TimeInterval = 86400

    private let queue = DispatchQueue(label: "com.operatorkit.attest.verifier", qos: .userInitiated)

    // MARK: - Verdict

    public struct AttestationVerdict: Sendable {
        public let isValid: Bool
        public let reason: String
        public let verifiedAt: Date
        public let expiresAt: Date

        public var isExpired: Bool {
            Date() > expiresAt
        }
    }

    private var _cachedVerdict: AttestationVerdict?

    /// The current verification verdict. May be nil if never checked.
    public var currentVerdict: AttestationVerdict? {
        queue.sync {
            guard let verdict = _cachedVerdict, !verdict.isExpired else { return nil }
            return verdict
        }
    }

    /// Whether the device is verified (valid, non-expired verdict exists).
    public var isVerified: Bool {
        if let verdict = currentVerdict {
            return verdict.isValid
        }
        return false
    }

    private init() {}

    // MARK: - Verify

    /// Perform attestation verification. Returns a verdict.
    ///
    /// Flow:
    ///   1. Check if App Attest is supported
    ///   2. Check if key has been generated
    ///   3. Check if key has been attested
    ///   4. Optionally generate a fresh assertion to prove liveness
    ///   5. Cache verdict with TTL
    public func verify() async -> AttestationVerdict {
        let service = DeviceAttestationService.shared

        // Check support
        guard service.isSupported else {
            #if DEBUG
            // In DEBUG, allow Simulator with warning
            let verdict = AttestationVerdict(
                isValid: true,
                reason: "DEBUG: Simulator attestation bypass",
                verifiedAt: Date(),
                expiresAt: Date().addingTimeInterval(Self.verdictTTL)
            )
            queue.sync { _cachedVerdict = verdict }
            SecurityTelemetry.shared.record(
                category: .attestation,
                detail: "DEBUG: Simulator attestation bypassed",
                outcome: .warning
            )
            return verdict
            #else
            let verdict = AttestationVerdict(
                isValid: false,
                reason: "App Attest not supported — device ineligible for execution",
                verifiedAt: Date(),
                expiresAt: Date() // Immediately expired
            )
            queue.sync { _cachedVerdict = verdict }
            SecurityTelemetry.shared.record(
                category: .attestationFail,
                detail: "Release build on unsupported device — attestation DENIED",
                outcome: .denied
            )
            return verdict
            #endif
        }

        // Check key generation
        if service.state == .notStarted || service.state == .failed {
            // Attempt to generate key
            do {
                try await service.generateKeyIfNeeded()
            } catch {
                let verdict = AttestationVerdict(
                    isValid: false,
                    reason: "Attestation key generation failed: \(error.localizedDescription)",
                    verifiedAt: Date(),
                    expiresAt: Date()
                )
                queue.sync { _cachedVerdict = verdict }
                return verdict
            }
        }

        // Attempt attestation if not yet attested
        if service.state == .keyGenerated {
            do {
                try await service.attestKey()
            } catch {
                // Attestation failed but key exists — partial trust
                let verdict = AttestationVerdict(
                    isValid: false,
                    reason: "Key attestation failed: \(error.localizedDescription)",
                    verifiedAt: Date(),
                    expiresAt: Date().addingTimeInterval(300) // Retry in 5 min
                )
                queue.sync { _cachedVerdict = verdict }
                return verdict
            }
        }

        // Generate a liveness assertion to prove current state
        let proofData = "operatorkit-attest-verify-\(Date().timeIntervalSince1970)".data(using: .utf8)!
        let assertion = await service.generateAssertion(for: proofData)

        let isValid: Bool
        let reason: String

        switch assertion {
        case .success:
            isValid = true
            reason = "Device verified: key attested, assertion valid"
        case .unavailable(let r):
            isValid = false
            reason = "Assertion unavailable: \(r)"
        case .failed(let r):
            isValid = false
            reason = "Assertion failed: \(r)"
        }

        let verdict = AttestationVerdict(
            isValid: isValid,
            reason: reason,
            verifiedAt: Date(),
            expiresAt: Date().addingTimeInterval(Self.verdictTTL)
        )
        queue.sync { _cachedVerdict = verdict }

        SecurityTelemetry.shared.record(
            category: isValid ? .attestation : .attestationFail,
            detail: reason,
            outcome: isValid ? .success : .failure
        )

        return verdict
    }

    /// Invalidate cached verdict. Forces re-verification on next check.
    public func invalidate() {
        queue.sync { _cachedVerdict = nil }
    }
}
