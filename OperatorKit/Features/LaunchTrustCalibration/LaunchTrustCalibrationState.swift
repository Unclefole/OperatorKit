import Foundation

// ============================================================================
// LAUNCH TRUST CALIBRATION STATE (Phase L2)
//
// Tracks whether the first-launch trust calibration ceremony has completed.
// Uses UserDefaults for persistence (no security relevance — purely UX).
//
// CONSTRAINTS:
// ❌ No security enforcement
// ❌ No cryptography
// ❌ No networking
// ✅ Simple boolean flag
// ✅ Resets on app reinstall (standard UserDefaults behavior)
// ============================================================================

public enum LaunchTrustCalibrationState {
    
    // MARK: - Keys
    
    private static let hasCompletedKey = "operatorkit.trustcalibration.completed"
    
    // MARK: - State Access
    
    /// Whether the trust calibration ceremony has been completed
    public static var hasCompletedTrustCalibration: Bool {
        get {
            UserDefaults.standard.bool(forKey: hasCompletedKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hasCompletedKey)
        }
    }
    
    /// Check if calibration should be shown
    /// Returns true if calibration has NOT been completed and feature is enabled
    public static var shouldShowCalibration: Bool {
        LaunchTrustCalibrationFeatureFlag.isEnabled && !hasCompletedTrustCalibration
    }
    
    // MARK: - Actions
    
    /// Mark calibration as complete
    /// Called once when user taps "Continue" after verification
    public static func markComplete() {
        hasCompletedTrustCalibration = true
    }
    
    // MARK: - Testing Helpers
    
    #if DEBUG
    /// Reset state for testing (DEBUG only)
    public static func resetForTesting() {
        hasCompletedTrustCalibration = false
    }
    #endif
}
