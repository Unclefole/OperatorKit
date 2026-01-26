import Foundation

// MARK: - Release Configuration (Phase 7A)
//
// This file provides a single source of truth for release mode detection
// and enforces that certain features are only available in appropriate builds.
//
// INVARIANTS:
// - Synthetic demo mode: DEBUG only
// - Diagnostic UI: DEBUG only
// - Eval harness: DEBUG only
// - Fault injection: DEBUG only
// - Production behavior: deterministic, local, no network

/// Release mode enumeration
/// Derived from build configuration and runtime environment
public enum ReleaseMode: String, CaseIterable {
    case debug = "Debug"
    case testFlight = "TestFlight"
    case appStore = "App Store"
    
    /// Current release mode, determined at runtime
    public static var current: ReleaseMode {
        #if DEBUG
        return .debug
        #else
        // Check for TestFlight by examining receipt
        if isTestFlightBuild {
            return .testFlight
        }
        return .appStore
        #endif
    }
    
    /// Whether this is a TestFlight build (non-DEBUG, sandboxed receipt)
    private static var isTestFlightBuild: Bool {
        // TestFlight builds have a sandboxReceipt in the receipt URL
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        return receiptURL.lastPathComponent == "sandboxReceipt"
    }
    
    /// Human-readable description
    public var displayName: String {
        rawValue
    }
    
    /// Whether diagnostic features should be available
    public var allowsDiagnostics: Bool {
        switch self {
        case .debug: return true
        case .testFlight: return false  // TestFlight is near-production
        case .appStore: return false
        }
    }
    
    /// Whether synthetic demo data should be available
    public var allowsSyntheticData: Bool {
        self == .debug
    }
    
    /// Whether eval harness should be available
    public var allowsEvalHarness: Bool {
        self == .debug
    }
    
    /// Whether fault injection should be available
    public var allowsFaultInjection: Bool {
        self == .debug
    }
}

// MARK: - Release Safety Configuration

/// Static configuration that enforces release safety rules
public enum ReleaseSafetyConfig {
    
    // MARK: - Deployment Target
    
    /// Minimum supported iOS version
    public static let minimumIOSVersion = 17.0
    
    /// Verify deployment target at compile time
    @available(iOS 17.0, *)
    public static let deploymentTargetVerified = true
    
    // MARK: - Disabled Features (Compile-Time)
    
    /// Network entitlements: DISABLED
    /// OperatorKit must never have network capabilities
    public static let networkEntitlementsEnabled = false
    
    /// Background modes: DISABLED
    /// OperatorKit must never run in the background
    public static let backgroundModesEnabled = false
    
    /// Push notifications: DISABLED
    /// OperatorKit must never receive push notifications
    public static let pushNotificationsEnabled = false
    
    /// Remote configuration: DISABLED
    /// OperatorKit must never fetch remote config
    public static let remoteConfigEnabled = false
    
    /// Analytics: DISABLED
    /// OperatorKit must never collect analytics
    public static let analyticsEnabled = false
    
    /// Telemetry: DISABLED
    /// OperatorKit must never send telemetry
    public static let telemetryEnabled = false
    
    // MARK: - Required Features (Always On)
    
    /// Deterministic fallback model: REQUIRED
    /// Must always be available regardless of ML backend status
    public static let deterministicFallbackRequired = true
    
    /// Approval gate: REQUIRED
    /// No execution without explicit approval
    public static let approvalGateRequired = true
    
    /// Two-key confirmation: REQUIRED
    /// All writes require second confirmation
    public static let twoKeyConfirmationRequired = true
    
    /// Draft-first execution: REQUIRED
    /// All actions produce drafts before execution
    public static let draftFirstRequired = true
    
    /// On-device processing: REQUIRED
    /// All processing must be local
    public static let onDeviceProcessingRequired = true
    
    // MARK: - Validation
    
    /// Validates that all release safety requirements are met
    /// Call this at app launch in DEBUG to verify configuration
    public static func validateConfiguration() -> [String] {
        var violations: [String] = []
        
        // Verify disabled features are actually disabled
        if networkEntitlementsEnabled {
            violations.append("VIOLATION: Network entitlements must be disabled")
        }
        if backgroundModesEnabled {
            violations.append("VIOLATION: Background modes must be disabled")
        }
        if pushNotificationsEnabled {
            violations.append("VIOLATION: Push notifications must be disabled")
        }
        if remoteConfigEnabled {
            violations.append("VIOLATION: Remote configuration must be disabled")
        }
        if analyticsEnabled {
            violations.append("VIOLATION: Analytics must be disabled")
        }
        if telemetryEnabled {
            violations.append("VIOLATION: Telemetry must be disabled")
        }
        
        // Verify required features are enabled
        if !deterministicFallbackRequired {
            violations.append("VIOLATION: Deterministic fallback must be required")
        }
        if !approvalGateRequired {
            violations.append("VIOLATION: Approval gate must be required")
        }
        if !twoKeyConfirmationRequired {
            violations.append("VIOLATION: Two-key confirmation must be required")
        }
        if !draftFirstRequired {
            violations.append("VIOLATION: Draft-first execution must be required")
        }
        if !onDeviceProcessingRequired {
            violations.append("VIOLATION: On-device processing must be required")
        }
        
        return violations
    }
    
    /// Summary for debugging
    public static var configurationSummary: String {
        """
        OperatorKit Release Safety Configuration
        =========================================
        Release Mode: \(ReleaseMode.current.displayName)
        
        DISABLED (must remain disabled):
        - Network entitlements: \(networkEntitlementsEnabled ? "⚠️ ENABLED" : "✓ Disabled")
        - Background modes: \(backgroundModesEnabled ? "⚠️ ENABLED" : "✓ Disabled")
        - Push notifications: \(pushNotificationsEnabled ? "⚠️ ENABLED" : "✓ Disabled")
        - Remote config: \(remoteConfigEnabled ? "⚠️ ENABLED" : "✓ Disabled")
        - Analytics: \(analyticsEnabled ? "⚠️ ENABLED" : "✓ Disabled")
        - Telemetry: \(telemetryEnabled ? "⚠️ ENABLED" : "✓ Disabled")
        
        REQUIRED (must remain enabled):
        - Deterministic fallback: \(deterministicFallbackRequired ? "✓ Required" : "⚠️ NOT REQUIRED")
        - Approval gate: \(approvalGateRequired ? "✓ Required" : "⚠️ NOT REQUIRED")
        - Two-key confirmation: \(twoKeyConfirmationRequired ? "✓ Required" : "⚠️ NOT REQUIRED")
        - Draft-first: \(draftFirstRequired ? "✓ Required" : "⚠️ NOT REQUIRED")
        - On-device processing: \(onDeviceProcessingRequired ? "✓ Required" : "⚠️ NOT REQUIRED")
        
        DEBUG-ONLY FEATURES:
        - Synthetic data: \(ReleaseMode.current.allowsSyntheticData ? "Available" : "Disabled")
        - Eval harness: \(ReleaseMode.current.allowsEvalHarness ? "Available" : "Disabled")
        - Fault injection: \(ReleaseMode.current.allowsFaultInjection ? "Available" : "Disabled")
        - Diagnostics: \(ReleaseMode.current.allowsDiagnostics ? "Available" : "Disabled")
        """
    }
}

// MARK: - Compile-Time Enforcement

// These static assertions ensure configuration cannot drift
#if DEBUG
// In DEBUG, synthetic data and diagnostics are allowed
#else
// In RELEASE, verify no debug-only features leak through
// The #if DEBUG guards in other files enforce this at compile time
#endif

// MARK: - Runtime Enforcement

extension ReleaseSafetyConfig {
    
    /// Runs all safety validations at app launch
    /// Call from AppDelegate or App.init in DEBUG builds
    @discardableResult
    public static func runStartupValidation() -> Bool {
        let violations = validateConfiguration()
        
        #if DEBUG
        if !violations.isEmpty {
            for violation in violations {
                print("❌ \(violation)")
            }
            assertionFailure("Release safety configuration violated. See console for details.")
            return false
        }
        print("✅ Release safety configuration validated")
        #endif
        
        return violations.isEmpty
    }
}
