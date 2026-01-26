import Foundation

// ============================================================================
// AUDIT VAULT FEATURE FLAG (Phase 13E)
//
// Feature flag controlling Audit Vault Lineage visibility.
// All entry points are gated behind this flag.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No execution behavior changes
// ❌ No networking
// ❌ No background tasks
// ❌ No telemetry
// ✅ Read-only lineage display
// ✅ Zero-content storage only
// ✅ Local-only
// ============================================================================

public enum AuditVaultFeatureFlag {
    
    /// Whether Audit Vault is enabled
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
    
    public static let featurePhase = "13E"
    public static let featureName = "Audit Vault Lineage"
    public static let schemaVersion = 1
}
