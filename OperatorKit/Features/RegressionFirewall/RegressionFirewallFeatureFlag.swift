import Foundation

// ============================================================================
// REGRESSION FIREWALL FEATURE FLAG (Phase 13D)
//
// Feature flag controlling Regression Firewall visibility.
// All verification surfaces are gated behind this flag.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No execution behavior changes
// ❌ No networking
// ❌ No background tasks
// ❌ No telemetry
// ✅ Read-only verification only
// ✅ Deterministic checks
// ✅ On-device only
// ============================================================================

public enum RegressionFirewallFeatureFlag {
    
    /// Whether Regression Firewall visibility is enabled
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
    
    public static let featurePhase = "13D"
    public static let featureName = "Regression Firewall Verification"
    public static let schemaVersion = 1
}
