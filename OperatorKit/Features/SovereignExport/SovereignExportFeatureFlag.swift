import Foundation

// ============================================================================
// SOVEREIGN EXPORT FEATURE FLAG (Phase 13C)
//
// Feature flag controlling Sovereign Export capability.
// All export/import surfaces are gated behind this flag.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No execution behavior changes
// ❌ No networking
// ❌ No background tasks
// ❌ No user content export
// ✅ Encrypted export only
// ✅ User-initiated only
// ✅ Reversible import
// ============================================================================

public enum SovereignExportFeatureFlag {
    
    /// Whether Sovereign Export is enabled
    public static var isEnabled: Bool {
        #if DEBUG
        return _debugOverride ?? true
        #else
        return _releaseEnabled
        #endif
    }
    
    // MARK: - Internal Configuration
    
    private static var _debugOverride: Bool? = nil
    private static let _releaseEnabled = false
    
    #if DEBUG
    public static func setDebugOverride(_ value: Bool?) {
        _debugOverride = value
    }
    #endif
    
    // MARK: - Metadata
    
    public static let featurePhase = "13C"
    public static let featureName = "Sovereign Export (Encrypted)"
    public static let schemaVersion = 1
}
