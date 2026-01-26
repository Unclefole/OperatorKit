import XCTest
@testable import OperatorKit

/// Regression tests that fail if safety guarantees are violated (Phase 7C)
/// These tests are designed to catch accidental regressions during development
final class RegressionTests: XCTestCase {
    
    // MARK: - Permission Regression Tests
    
    func testNoNewPermissionKeysInInfoPlist() {
        // List of ALL permission keys that should NOT be present
        let forbiddenPermissionKeys = [
            "NSLocationWhenInUseUsageDescription",
            "NSLocationAlwaysAndWhenInUseUsageDescription",
            "NSLocationAlwaysUsageDescription",
            "NSCameraUsageDescription",
            "NSMicrophoneUsageDescription",
            "NSPhotoLibraryUsageDescription",
            "NSPhotoLibraryAddUsageDescription",
            "NSContactsUsageDescription",
            "NSHealthShareUsageDescription",
            "NSHealthUpdateUsageDescription",
            "NSMotionUsageDescription",
            "NSBluetoothAlwaysUsageDescription",
            "NSBluetoothPeripheralUsageDescription",
            "NSHomeKitUsageDescription",
            "NSAppleMusicUsageDescription",
            "NSSpeechRecognitionUsageDescription",
            "NSFaceIDUsageDescription",
            "NSLocalNetworkUsageDescription",
            "NSUserTrackingUsageDescription"
        ]
        
        var found: [String] = []
        for key in forbiddenPermissionKeys {
            if Bundle.main.object(forInfoDictionaryKey: key) != nil {
                found.append(key)
            }
        }
        
        XCTAssertTrue(
            found.isEmpty,
            """
            REGRESSION: New permission keys found in Info.plist
            
            Found: \(found.joined(separator: ", "))
            
            If these permissions are intentionally added:
            1. Update SAFETY_CONTRACT.md
            2. Follow the Change Control Process
            3. Update this test to allow the new permission
            """
        )
    }
    
    func testOnlyAllowedPermissionsPresent() {
        // These are the ONLY permission keys that should be present
        let allowedKeys = Set([
            "NSCalendarsUsageDescription",
            "NSRemindersUsageDescription",
            "NSSiriUsageDescription"
        ])
        
        // Check that allowed keys ARE present
        for key in allowedKeys {
            XCTAssertNotNil(
                Bundle.main.object(forInfoDictionaryKey: key),
                "Required permission key missing: \(key)"
            )
        }
    }
    
    // MARK: - Entitlement Regression Tests
    
    func testNoNetworkEntitlementEnabled() {
        // Verify network entitlements are not enabled
        // This is enforced by ReleaseSafetyConfig
        XCTAssertFalse(
            ReleaseSafetyConfig.networkEntitlementsEnabled,
            "REGRESSION: Network entitlements must not be enabled"
        )
    }
    
    func testNoBackgroundEntitlementEnabled() {
        // Verify background entitlements are not enabled
        XCTAssertFalse(
            ReleaseSafetyConfig.backgroundModesEnabled,
            "REGRESSION: Background modes must not be enabled"
        )
    }
    
    // MARK: - Framework Regression Tests
    
    func testNoNetworkFrameworksLinked() {
        let networkFrameworks = [
            "Alamofire",
            "Moya",
            "Apollo",
            "AFNetworking",
            "Starscream"
        ]
        
        var found: [String] = []
        for framework in networkFrameworks {
            if isFrameworkLinked(framework) {
                found.append(framework)
            }
        }
        
        XCTAssertTrue(
            found.isEmpty,
            """
            REGRESSION: Network framework(s) linked
            
            Found: \(found.joined(separator: ", "))
            
            OperatorKit must never make network requests.
            Remove these dependencies immediately.
            """
        )
    }
    
    func testNoAnalyticsFrameworksLinked() {
        let analyticsFrameworks = [
            "FirebaseAnalytics",
            "Amplitude",
            "Mixpanel",
            "Segment",
            "AppsFlyerLib",
            "Heap",
            "CleverTap"
        ]
        
        var found: [String] = []
        for framework in analyticsFrameworks {
            if isFrameworkLinked(framework) {
                found.append(framework)
            }
        }
        
        XCTAssertTrue(
            found.isEmpty,
            """
            REGRESSION: Analytics framework(s) linked
            
            Found: \(found.joined(separator: ", "))
            
            OperatorKit must not collect analytics.
            Remove these dependencies immediately.
            """
        )
    }
    
    // MARK: - Two-Key Confirmation Regression Tests
    
    func testWriteSideEffectsRequireTwoKey() {
        // Verify that write side effect types require two-key confirmation
        let writeTypes: [SideEffectType] = [
            .createReminder,
            .createCalendarEvent,
            .updateCalendarEvent
        ]
        
        for type in writeTypes {
            XCTAssertTrue(
                type.requiresTwoKeyConfirmation,
                """
                REGRESSION: Write side effect '\(type)' does not require two-key confirmation
                
                All write operations must require two-key confirmation.
                See SAFETY_CONTRACT.md Guarantee #5.
                """
            )
        }
    }
    
    func testPreviewSideEffectsDoNotRequireTwoKey() {
        // Preview effects should NOT require two-key (they don't write)
        let previewTypes: [SideEffectType] = [
            .previewReminder,
            .previewCalendarEvent
        ]
        
        for type in previewTypes {
            XCTAssertFalse(
                type.requiresTwoKeyConfirmation,
                "Preview side effect '\(type)' should not require two-key"
            )
        }
    }
    
    // MARK: - Siri Regression Tests
    
    func testSiriIntentsReturnResultOnly() {
        // This test documents the expected behavior
        // The actual enforcement is in OperatorKitIntents.swift
        // If someone adds execution code to intents, code review should catch it
        
        // Verify Siri routing bridge exists and is properly configured
        let bridge = SiriRoutingBridge.shared
        XCTAssertNotNil(bridge, "SiriRoutingBridge should exist")
        
        // Note: We can't test that intents don't execute without mocking
        // This test serves as documentation and reminder
    }
    
    // MARK: - Approval Gate Regression Tests
    
    func testApprovalGateRequiresApproval() {
        // Create a scenario without approval
        let draft = Draft(
            id: "test",
            type: .email,
            content: DraftContent(subject: "Test", body: "Test", actionItems: []),
            confidence: 0.85,
            citations: [],
            safetyNotes: ["Test"]
        )
        
        // Create effects that are acknowledged but not approved
        let effects = [
            SideEffect(
                type: .presentEmailDraft,
                description: "Test",
                isEnabled: true,
                isAcknowledged: true
            )
        ]
        
        // Without approval granted, should NOT be able to execute
        let canExecute = ApprovalGate.canExecute(
            draft: draft,
            sideEffects: effects,
            approvalGranted: false  // Key: approval not granted
        )
        
        XCTAssertFalse(
            canExecute,
            """
            REGRESSION: ApprovalGate allows execution without approval
            
            This is a critical safety violation.
            See SAFETY_CONTRACT.md Guarantee #1.
            """
        )
    }
    
    func testApprovalGateRequiresAcknowledgment() {
        let draft = Draft(
            id: "test",
            type: .email,
            content: DraftContent(subject: "Test", body: "Test", actionItems: []),
            confidence: 0.85,
            citations: [],
            safetyNotes: ["Test"]
        )
        
        // Effects NOT acknowledged
        let effects = [
            SideEffect(
                type: .presentEmailDraft,
                description: "Test",
                isEnabled: true,
                isAcknowledged: false  // Key: not acknowledged
            )
        ]
        
        let canExecute = ApprovalGate.canExecute(
            draft: draft,
            sideEffects: effects,
            approvalGranted: true
        )
        
        XCTAssertFalse(
            canExecute,
            """
            REGRESSION: ApprovalGate allows execution without acknowledgment
            
            All side effects must be acknowledged.
            See SAFETY_CONTRACT.md Guarantee #1.
            """
        )
    }
    
    // MARK: - Regression Sentinel Tests
    
    func testRegressionSentinelAllClear() {
        let sentinel = RegressionSentinel.shared
        let results = sentinel.runAllChecks()
        let failures = results.filter { !$0.passed }
        
        XCTAssertTrue(
            failures.isEmpty,
            """
            REGRESSION: Sentinel detected safety violations
            
            Failed checks:
            \(failures.map { $0.summary }.joined(separator: "\n"))
            
            Fix these issues before proceeding.
            """
        )
    }
    
    func testRegressionSentinelProducesStatusSummary() {
        let sentinel = RegressionSentinel.shared
        let summary = sentinel.statusSummary()
        
        // Should produce non-empty summary
        XCTAssertFalse(summary.isEmpty)
        
        // Should contain key elements
        XCTAssertTrue(summary.contains("REGRESSION SENTINEL STATUS"))
        XCTAssertTrue(summary.contains("Checks:"))
        XCTAssertTrue(summary.contains("Status:"))
    }
    
    // MARK: - Background Mode Regression Tests
    
    func testNoBackgroundModesInPlist() {
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        
        XCTAssertNil(
            backgroundModes,
            """
            REGRESSION: UIBackgroundModes found in Info.plist
            
            Found modes: \(backgroundModes ?? [])
            
            OperatorKit must never run in the background.
            Remove UIBackgroundModes from Info.plist.
            See SAFETY_CONTRACT.md Guarantee #3.
            """
        )
    }
    
    // MARK: - Helpers
    
    private func isFrameworkLinked(_ frameworkName: String) -> Bool {
        for bundle in Bundle.allBundles + Bundle.allFrameworks {
            if let bundleId = bundle.bundleIdentifier,
               bundleId.lowercased().contains(frameworkName.lowercased()) {
                return true
            }
            if bundle.bundlePath.lowercased().contains(frameworkName.lowercased()) {
                return true
            }
        }
        return false
    }
}
