import Foundation

// ============================================================================
// PROOF PACK FEATURE FLAG (Phase 13H)
//
// Feature flag controlling Proof Pack visibility.
// Enabled by default in both DEBUG and RELEASE for transparency.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No runtime behavior changes
// ❌ No networking
// ❌ No background tasks
// ❌ No user content
// ❌ No telemetry
// ✅ Read-only aggregation only
// ✅ User-initiated export only
// ============================================================================

public enum ProofPackFeatureFlag {
    
    /// Whether Proof Pack is enabled
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
    
    public static let featurePhase = "13H"
    public static let featureName = "Proof Pack"
    public static let schemaVersion = 1
}
