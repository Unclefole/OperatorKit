import Foundation
import LocalAuthentication

// ============================================================================
// BIOMETRIC GATE — SECURITY-SENSITIVE MUTATION GUARD
// ============================================================================
// Any security-sensitive toggle or policy mutation MUST pass through
// BiometricGate.authenticate() before the change is committed.
//
// Used by:
// - Enabling auto-approval for Tier 1 actions
// - Enabling Cloud Sync
// - Disabling explicit confirmation requirement
// - Any future security-downgrade mutation
//
// INVARIANT: If biometric fails or is unavailable, the mutation is DENIED.
// ============================================================================

public enum BiometricGate {

    /// Whether biometric authentication is available on this device
    public static var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// The type of biometric available (FaceID / TouchID / none)
    public static var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }

    /// Authenticate with biometrics before allowing a security-sensitive mutation.
    /// Returns true if authenticated, false if denied or unavailable.
    ///
    /// - Parameter reason: Human-readable reason shown in the biometric prompt.
    ///   Example: "Confirm policy change" or "Enable Cloud Sync"
    public static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        do {
            // Prefer biometrics, fall back to device passcode
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return success
        } catch {
            logDebug("Biometric authentication failed: \(error.localizedDescription)", category: .flow)
            return false
        }
    }

    /// Convenience: authenticate, then execute a closure if successful.
    /// If authentication fails, returns nil.
    @MainActor
    public static func withAuthentication<T>(
        reason: String,
        action: @MainActor () -> T
    ) async -> T? {
        let authenticated = await authenticate(reason: reason)
        guard authenticated else { return nil }
        return action()
    }
}
