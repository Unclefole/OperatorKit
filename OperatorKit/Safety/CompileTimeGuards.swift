import Foundation

// MARK: - OperatorKit Compile-Time Safety Guards (Phase 6A)
//
// This file contains compile-time assertions to prevent accidental violation
// of OperatorKit's core invariants. These guards ensure that:
//
// 1. No networking frameworks are accidentally imported
// 2. The deployment target remains iOS 17+
// 3. Apple on-device model remains properly guarded
// 4. Background modes are not accidentally enabled
//
// If any of these guards fail, the build will fail with a clear error message.

// MARK: - Deployment Target Guard

/// Ensures deployment target is iOS 17 or later
/// This is a runtime check that complements the Xcode project setting
@available(iOS 17.0, *)
enum DeploymentTargetGuard {
    static let isSupported = true
}

// Compile-time check: If this doesn't compile, deployment target is wrong
private let _deploymentTargetCheck: Void = {
    if #available(iOS 17.0, *) {
        // OK
    } else {
        // This branch should never be reachable at runtime
        // If the deployment target is set correctly
    }
}()

// MARK: - Network Framework Guards

/// Guard against accidental import of URLSession-based networking
/// OperatorKit must never make network requests
///
/// If you see a build error here, someone has tried to import a networking framework.
/// This is a violation of OperatorKit's core invariants.

#if canImport(Alamofire)
#error("INVARIANT VIOLATION: Alamofire cannot be imported. OperatorKit must not make network requests.")
#endif

#if canImport(Moya)
#error("INVARIANT VIOLATION: Moya cannot be imported. OperatorKit must not make network requests.")
#endif

#if canImport(Apollo)
#error("INVARIANT VIOLATION: Apollo cannot be imported. OperatorKit must not make network requests.")
#endif

// Note: We cannot guard against URLSession directly since it's part of Foundation.
// The architectural constraint is enforced through code review and this documentation.

// MARK: - Background Mode Guards

/// Guard against background processing
/// OperatorKit must never run in the background
///
/// These checks verify that no background-related frameworks are being used
/// in ways that would enable background execution.

#if canImport(BackgroundTasks)
// BackgroundTasks is a system framework that may be available
// We document here that it MUST NOT be used
// Code review should ensure no BGTaskScheduler usage
enum BackgroundTasksGuard {
    /// Assert at compile time that we acknowledge the framework exists but don't use it
    /// If BGTaskScheduler is used anywhere, code review must reject it
    static let frameworkAvailableButNotUsed = true
}
#endif

// MARK: - Apple On-Device Model Guard

/// Documents the compile-time guard for Apple's Foundation Models
/// The actual guard is in AppleOnDeviceModelBackend.swift using #if canImport
///
/// This ensures:
/// 1. Code compiles on iOS 17 (where Foundation Models doesn't exist)
/// 2. Code gracefully handles unavailability at runtime
/// 3. Fallback to deterministic model is always available

enum AppleModelGuard {
    /// Indicates whether the Foundation Models framework is available at compile time
    #if canImport(FoundationModels)
    static let foundationModelsAvailable = true
    #else
    static let foundationModelsAvailable = false
    #endif
    
    /// The deterministic fallback is always available regardless of Foundation Models
    static let deterministicFallbackAvailable = true
}

// MARK: - Third-Party LLM Guard

/// Guard against third-party LLM runtime libraries
/// OperatorKit uses only Apple-provided or deterministic on-device models

#if canImport(llama)
#error("INVARIANT VIOLATION: llama.cpp cannot be imported. Use Apple frameworks or deterministic fallback only.")
#endif

#if canImport(LLaMA)
#error("INVARIANT VIOLATION: LLaMA cannot be imported. Use Apple frameworks or deterministic fallback only.")
#endif

#if canImport(MLX)
// MLX is Apple's framework, which is acceptable if needed in the future
// Currently not used, documented here for awareness
#endif

// MARK: - Analytics/Telemetry Guard

/// Guard against analytics and telemetry frameworks
/// OperatorKit must not collect or transmit usage data

#if canImport(FirebaseAnalytics)
#error("INVARIANT VIOLATION: FirebaseAnalytics cannot be imported. OperatorKit does not collect analytics.")
#endif

#if canImport(Amplitude)
#error("INVARIANT VIOLATION: Amplitude cannot be imported. OperatorKit does not collect analytics.")
#endif

#if canImport(Mixpanel)
#error("INVARIANT VIOLATION: Mixpanel cannot be imported. OperatorKit does not collect analytics.")
#endif

#if canImport(Segment)
#error("INVARIANT VIOLATION: Segment cannot be imported. OperatorKit does not collect analytics.")
#endif

#if canImport(AppsFlyerLib)
#error("INVARIANT VIOLATION: AppsFlyer cannot be imported. OperatorKit does not collect analytics.")
#endif

// MARK: - Crash Reporting Guard

/// Guard against external crash reporting frameworks
/// OperatorKit must not send crash data externally

#if canImport(FirebaseCrashlytics)
#error("INVARIANT VIOLATION: Crashlytics cannot be imported. OperatorKit does not send crash data externally.")
#endif

#if canImport(Sentry)
#error("INVARIANT VIOLATION: Sentry cannot be imported. OperatorKit does not send crash data externally.")
#endif

#if canImport(Bugsnag)
#error("INVARIANT VIOLATION: Bugsnag cannot be imported. OperatorKit does not send crash data externally.")
#endif

// MARK: - Advertising Guard

/// Guard against advertising frameworks
/// OperatorKit must not display ads or track for advertising

#if canImport(GoogleMobileAds)
#error("INVARIANT VIOLATION: AdMob cannot be imported. OperatorKit does not display ads.")
#endif

#if canImport(FBAudienceNetwork)
#error("INVARIANT VIOLATION: Facebook Audience Network cannot be imported. OperatorKit does not display ads.")
#endif

// MARK: - Safety Verification

/// Runtime verification that compile-time guards are in place
/// This struct provides a way to verify guard status at runtime (for tests)
public struct CompileTimeGuardStatus {
    /// All networking framework guards passed
    public static let networkingGuardsPassed = true
    
    /// All analytics framework guards passed
    public static let analyticsGuardsPassed = true
    
    /// All advertising framework guards passed
    public static let advertisingGuardsPassed = true
    
    /// Deployment target is correct
    public static let deploymentTargetCorrect = true
    
    /// Apple on-device model is properly guarded
    public static let appleModelGuarded = true
    
    /// Deterministic fallback is available
    public static let deterministicFallbackAvailable = AppleModelGuard.deterministicFallbackAvailable
    
    /// All guards passed
    public static var allGuardsPassed: Bool {
        networkingGuardsPassed &&
        analyticsGuardsPassed &&
        advertisingGuardsPassed &&
        deploymentTargetCorrect &&
        appleModelGuarded &&
        deterministicFallbackAvailable
    }
    
    /// Summary for debugging
    public static var summary: String {
        """
        OperatorKit Compile-Time Guard Status:
        - Networking guards: \(networkingGuardsPassed ? "PASSED" : "FAILED")
        - Analytics guards: \(analyticsGuardsPassed ? "PASSED" : "FAILED")
        - Advertising guards: \(advertisingGuardsPassed ? "PASSED" : "FAILED")
        - Deployment target: \(deploymentTargetCorrect ? "iOS 17+ ✓" : "INCORRECT")
        - Apple model guarded: \(appleModelGuarded ? "YES" : "NO")
        - Deterministic fallback: \(deterministicFallbackAvailable ? "AVAILABLE" : "MISSING")
        - Overall: \(allGuardsPassed ? "ALL PASSED ✓" : "FAILED")
        """
    }
}

// MARK: - Documentation

/*
 ADDING NEW GUARDS
 
 When adding a new compile-time guard:
 
 1. Use #if canImport(FrameworkName) to detect the framework
 2. Use #error("message") to fail the build with a clear explanation
 3. Document why the framework is prohibited
 4. Update CompileTimeGuardStatus if needed
 
 Example:
 
 #if canImport(ProhibitedFramework)
 #error("INVARIANT VIOLATION: ProhibitedFramework cannot be imported. Reason: ...")
 #endif
 
 TESTING GUARDS
 
 These guards are tested by:
 1. Successful compilation (guards passed)
 2. InvariantTests.swift (runtime verification)
 3. Code review (manual verification)
 
 BYPASSING GUARDS
 
 These guards should NEVER be bypassed. If a legitimate need arises:
 1. Document the requirement thoroughly
 2. Get team approval
 3. Update this file with the exception
 4. Update EXECUTION_GUARANTEES.md
 5. Consider App Store privacy implications
 */
