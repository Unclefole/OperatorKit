import Foundation

// ============================================================================
// TRUST SURFACES FEATURE FLAG (Phase 13A)
//
// Feature flag controlling all Trust Surfaces UI.
// All Phase 13A surfaces are gated behind this flag.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No runtime behavior changes when enabled/disabled
// ❌ No networking
// ❌ No permissions
// ✅ UI visibility only
// ✅ Read-only, observational
// ============================================================================

// MARK: - Trust Surfaces Feature Flag

public enum TrustSurfacesFeatureFlag {
    
    /// Whether Trust Surfaces UI is enabled
    /// Set to `true` to expose trust dashboard and related views
    public static var isEnabled: Bool {
        #if DEBUG
        return _debugOverride ?? true
        #else
        return _releaseEnabled
        #endif
    }
    
    // MARK: - Internal Configuration
    
    /// Debug override for testing
    private static var _debugOverride: Bool? = nil
    
    /// Release configuration (disabled by default for staged rollout)
    private static let _releaseEnabled = false
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    /// Override flag for testing (DEBUG only)
    public static func setDebugOverride(_ value: Bool?) {
        _debugOverride = value
    }
    #endif
    
    // MARK: - Feature Components
    
    /// Individual component flags (all gated by main flag)
    public enum Components {
        
        /// Trust Dashboard visibility
        public static var trustDashboardEnabled: Bool {
            TrustSurfacesFeatureFlag.isEnabled
        }
        
        /// Procedure Sharing Preview visibility
        public static var procedureSharingPreviewEnabled: Bool {
            TrustSurfacesFeatureFlag.isEnabled
        }
        
        /// Regression Firewall Visibility
        public static var regressionFirewallVisibilityEnabled: Bool {
            TrustSurfacesFeatureFlag.isEnabled
        }
        
        /// Sovereign Export Stub visibility
        public static var sovereignExportStubEnabled: Bool {
            TrustSurfacesFeatureFlag.isEnabled
        }
    }
    
    // MARK: - Metadata
    
    public static let featurePhase = "13A"
    public static let featureName = "Trust Surfaces & Proof Exposure"
    public static let schemaVersion = 1
}
