import Foundation

// ============================================================================
// PAYWALL FEATURE FLAG (Ship Blocker Fix)
//
// Controls visibility of Pro upgrade/subscription screens.
// Set to FALSE to ship without IAP risk if StoreKit products aren't ready.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No runtime behavior changes to execution
// ❌ No user data access
// ✅ Gates UI navigation only
// ✅ Safe to toggle without resubmission risk
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

public enum PaywallFeatureFlag {

    /// Whether the paywall/upgrade screens are enabled
    /// Set to FALSE to hide all monetization UI for safe App Store submission
    public static var isEnabled: Bool {
        #if DEBUG
        return _debugOverride ?? _defaultEnabled
        #else
        return _releaseEnabled
        #endif
    }

    // MARK: - Configuration

    /// Default state for DEBUG builds
    /// Set to true to test paywall during development
    private static let _defaultEnabled = true

    /// Release state - SET TO FALSE TO SHIP WITHOUT IAP
    /// Change to true once App Store Connect products are verified working
    private static let _releaseEnabled = false  // ← SHIP SAFE: Paywall hidden in Release

    /// Debug override for testing
    private static var _debugOverride: Bool? = nil

    #if DEBUG
    /// Override the feature flag in DEBUG builds for testing
    public static func setDebugOverride(_ value: Bool?) {
        _debugOverride = value
    }
    #endif

    // MARK: - Metadata

    public static let featureName = "Paywall"
    public static let reason = "StoreKit products not yet configured in App Store Connect"
}
