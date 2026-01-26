import Foundation

// ============================================================================
// OFFLINE CERTIFICATION FEATURE FLAG (Phase 13I)
//
// Feature flag controlling Offline Certification visibility.
// Enabled by default in both DEBUG and RELEASE for transparency.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No runtime behavior changes
// ❌ No networking
// ❌ No background tasks
// ❌ No enforcement (certification only)
// ✅ Read-only verification only
// ✅ User-initiated only
// ============================================================================

public enum OfflineCertificationFeatureFlag {
    
    /// Whether Offline Certification is enabled
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
    private static let _releaseEnabled = true // Enabled for trust surface transparency
    
    #if DEBUG
    public static func setDebugOverride(_ value: Bool?) {
        _debugOverride = value
    }
    #endif
    
    // MARK: - Metadata
    
    public static let featurePhase = "13I"
    public static let featureName = "Offline Certification"
    public static let schemaVersion = 1
}
