import Foundation

// ============================================================================
// PROCEDURE SHARING FEATURE FLAG (Phase 13B)
//
// Feature flag controlling Procedure Sharing capability.
// All sharing surfaces are gated behind this flag.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No execution behavior changes when enabled/disabled
// ❌ No networking
// ❌ No background tasks
// ❌ No permissions
// ✅ Logic-only templates
// ✅ User-initiated only
// ✅ Local storage only
// ============================================================================

public enum ProcedureSharingFeatureFlag {
    
    /// Whether Procedure Sharing is enabled
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
    
    public static let featurePhase = "13B"
    public static let featureName = "Procedure Sharing (Logic-Only)"
    public static let schemaVersion = 1
}
