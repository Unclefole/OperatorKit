import Foundation

// ============================================================================
// SECURITY MANIFEST UI FEATURE FLAG (Phase L1)
//
// Controls visibility of the user-facing Security Manifest surface.
// Enabled by default in both DEBUG and RELEASE for transparency.
//
// CONSTRAINTS:
// ❌ No enforcement logic
// ❌ No networking
// ❌ No telemetry
// ✅ Read-only presentation only
// ============================================================================

public enum SecurityManifestUIFeatureFlag {
    
    /// Whether Security Manifest UI is enabled
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
    
    /// Release default (true for user transparency)
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
