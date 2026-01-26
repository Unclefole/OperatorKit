import Foundation

// ============================================================================
// BUILD SEALS FEATURE FLAG (Phase 13J)
//
// Controls visibility of Build Seals proof surface.
// Enabled by default in both DEBUG and RELEASE for transparency.
//
// CONSTRAINTS:
// ❌ No networking
// ❌ No user content
// ✅ Read-only proof display
// ============================================================================

public enum BuildSealsFeatureFlag {
    
    /// Whether Build Seals UI is enabled
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
    
    /// Release default (true for transparency)
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
