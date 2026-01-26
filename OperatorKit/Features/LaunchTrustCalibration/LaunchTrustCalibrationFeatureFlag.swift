import Foundation

// ============================================================================
// LAUNCH TRUST CALIBRATION FEATURE FLAG (Phase L2)
//
// Controls visibility of the first-launch trust calibration ceremony.
// Enabled by default in both DEBUG and RELEASE.
//
// CONSTRAINTS:
// ❌ No enforcement logic
// ❌ No networking
// ✅ UX ceremony only
// ============================================================================

public enum LaunchTrustCalibrationFeatureFlag {
    
    /// Whether first-launch trust calibration is enabled
    public static var isEnabled: Bool {
        #if DEBUG
        return _debugOverride ?? true
        #else
        return _releaseEnabled
        #endif
    }
    
    // MARK: - Internal Configuration
    
    /// Debug override (for testing)
    static var _debugOverride: Bool? = nil
    
    /// Release default (true for user trust building)
    static let _releaseEnabled: Bool = true
    
    // MARK: - Testing Helpers
    
    #if DEBUG
    /// Reset to default state (testing only)
    public static func resetToDefault() {
        _debugOverride = nil
    }
    
    /// Override for testing (DEBUG only)
    public static func setEnabled(_ enabled: Bool) {
        _debugOverride = enabled
    }
    #endif
}
