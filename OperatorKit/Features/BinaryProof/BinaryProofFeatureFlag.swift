import Foundation

// ============================================================================
// BINARY PROOF FEATURE FLAG (Phase 13G)
//
// Feature flag controlling Binary Proof visibility.
// Enabled by default in both DEBUG and RELEASE for transparency.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No runtime behavior changes
// ❌ No networking
// ❌ No background tasks
// ❌ No user content access
// ✅ Read-only inspection only
// ✅ Deterministic results
// ✅ Offline-capable
// ============================================================================

public enum BinaryProofFeatureFlag {
    
    /// Whether Binary Proof is enabled
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
    
    public static let featurePhase = "13G"
    public static let featureName = "Binary Proof"
    public static let schemaVersion = 1
}
