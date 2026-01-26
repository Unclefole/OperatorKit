import Foundation

// ============================================================================
// SECURITY MANIFEST FEATURE FLAG (Phase 13F)
//
// Feature flag controlling Security Manifest visibility.
// Enabled by default in both DEBUG and RELEASE builds for transparency.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No runtime behavior changes
// ❌ No networking
// ❌ No side effects
// ✅ Read-only display only
// ✅ Transparency by default
// ============================================================================

public enum SecurityManifestFeatureFlag {
    
    /// Whether Security Manifest is enabled
    /// Defaults to true in both DEBUG and RELEASE for transparency
    public static var isEnabled: Bool {
        #if DEBUG
        return _debugOverride ?? true
        #else
        return _releaseEnabled
        #endif
    }
    
    // MARK: - Internal Configuration
    
    private static var _debugOverride: Bool? = nil
    private static let _releaseEnabled = true // Enabled by default for transparency
    
    #if DEBUG
    public static func setDebugOverride(_ value: Bool?) {
        _debugOverride = value
    }
    #endif
    
    // MARK: - Metadata
    
    public static let featurePhase = "13F"
    public static let featureName = "Security Manifest"
    public static let schemaVersion = 1
}
