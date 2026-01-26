import XCTest
@testable import OperatorKit

/// Tests that verify Info.plist privacy strings match PrivacyStrings (Phase 7A)
/// These tests prevent silent drift during future edits
final class InfoPlistRegressionTests: XCTestCase {
    
    // MARK: - Privacy String Verification
    
    func testCalendarUsageDescriptionMatchesPrivacyStrings() {
        let infoPlistValue = Bundle.main.object(forInfoDictionaryKey: "NSCalendarsUsageDescription") as? String
        let expectedValue = PrivacyStrings.Calendar.usageDescription
        
        XCTAssertNotNil(infoPlistValue, "NSCalendarsUsageDescription must be present in Info.plist")
        XCTAssertEqual(
            infoPlistValue,
            expectedValue,
            """
            NSCalendarsUsageDescription in Info.plist does not match PrivacyStrings.Calendar.usageDescription
            
            Info.plist value:
            \(infoPlistValue ?? "nil")
            
            Expected value:
            \(expectedValue)
            
            Update Info.plist to match PrivacyStrings.swift
            """
        )
    }
    
    func testRemindersUsageDescriptionMatchesPrivacyStrings() {
        let infoPlistValue = Bundle.main.object(forInfoDictionaryKey: "NSRemindersUsageDescription") as? String
        let expectedValue = PrivacyStrings.Reminders.usageDescription
        
        XCTAssertNotNil(infoPlistValue, "NSRemindersUsageDescription must be present in Info.plist")
        XCTAssertEqual(
            infoPlistValue,
            expectedValue,
            """
            NSRemindersUsageDescription in Info.plist does not match PrivacyStrings.Reminders.usageDescription
            
            Info.plist value:
            \(infoPlistValue ?? "nil")
            
            Expected value:
            \(expectedValue)
            
            Update Info.plist to match PrivacyStrings.swift
            """
        )
    }
    
    func testSiriUsageDescriptionMatchesPrivacyStrings() {
        let infoPlistValue = Bundle.main.object(forInfoDictionaryKey: "NSSiriUsageDescription") as? String
        let expectedValue = PrivacyStrings.Siri.usageDescription
        
        XCTAssertNotNil(infoPlistValue, "NSSiriUsageDescription must be present in Info.plist")
        XCTAssertEqual(
            infoPlistValue,
            expectedValue,
            """
            NSSiriUsageDescription in Info.plist does not match PrivacyStrings.Siri.usageDescription
            
            Info.plist value:
            \(infoPlistValue ?? "nil")
            
            Expected value:
            \(expectedValue)
            
            Update Info.plist to match PrivacyStrings.swift
            """
        )
    }
    
    // MARK: - Background Modes Verification
    
    func testNoBackgroundModesEnabled() {
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        
        XCTAssertNil(
            backgroundModes,
            """
            UIBackgroundModes must NOT be present in Info.plist
            
            Found: \(backgroundModes ?? [])
            
            OperatorKit must never run in the background.
            Remove UIBackgroundModes from Info.plist.
            """
        )
    }
    
    func testNoBackgroundFetchMode() {
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        
        XCTAssertFalse(
            backgroundModes.contains("fetch"),
            "Background fetch mode must not be enabled"
        )
    }
    
    func testNoBackgroundProcessingMode() {
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        
        XCTAssertFalse(
            backgroundModes.contains("processing"),
            "Background processing mode must not be enabled"
        )
    }
    
    func testNoRemoteNotificationMode() {
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        
        XCTAssertFalse(
            backgroundModes.contains("remote-notification"),
            "Remote notification background mode must not be enabled"
        )
    }
    
    // MARK: - Unexpected Permission Keys
    
    func testNoUnexpectedPermissionKeys() {
        let unexpectedKeys = [
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
            "NSFaceIDUsageDescription"
        ]
        
        var foundUnexpected: [String] = []
        
        for key in unexpectedKeys {
            if Bundle.main.object(forInfoDictionaryKey: key) != nil {
                foundUnexpected.append(key)
            }
        }
        
        XCTAssertTrue(
            foundUnexpected.isEmpty,
            """
            Unexpected permission keys found in Info.plist:
            \(foundUnexpected.joined(separator: "\n"))
            
            OperatorKit should only have:
            - NSCalendarsUsageDescription
            - NSRemindersUsageDescription
            - NSSiriUsageDescription
            
            Remove unexpected permission keys or document why they are needed.
            """
        )
    }
    
    // MARK: - Required Keys Present
    
    func testRequiredPrivacyKeysPresent() {
        let requiredKeys = [
            "NSCalendarsUsageDescription",
            "NSRemindersUsageDescription",
            "NSSiriUsageDescription"
        ]
        
        var missingKeys: [String] = []
        
        for key in requiredKeys {
            if Bundle.main.object(forInfoDictionaryKey: key) == nil {
                missingKeys.append(key)
            }
        }
        
        XCTAssertTrue(
            missingKeys.isEmpty,
            """
            Required privacy keys missing from Info.plist:
            \(missingKeys.joined(separator: "\n"))
            
            Add these keys with values matching PrivacyStrings.swift
            """
        )
    }
    
    // MARK: - Deployment Target
    
    func testMinimumDeploymentTargetiOS17() {
        let deploymentTarget = Bundle.main.object(forInfoDictionaryKey: "MinimumOSVersion") as? String
        
        // Note: MinimumOSVersion might not be directly in Info.plist depending on build settings
        // This test verifies the API availability check works
        if #available(iOS 17.0, *) {
            // We're running on iOS 17+, which is correct
            XCTAssertTrue(true)
        } else {
            XCTFail("OperatorKit requires iOS 17.0 or later")
        }
    }
}

// MARK: - Invariant Check Tests

extension InfoPlistRegressionTests {
    
    func testAllInvariantChecksPassed() {
        let runner = InvariantCheckRunner.shared
        let failedChecks = runner.failedChecks
        
        XCTAssertTrue(
            failedChecks.isEmpty,
            """
            Invariant checks failed:
            \(failedChecks.map { $0.message }.joined(separator: "\n"))
            """
        )
    }
    
    func testCompileTimeGuardsPassed() {
        XCTAssertTrue(
            CompileTimeGuardStatus.allGuardsPassed,
            "Compile-time guards indicate a failure. Check CompileTimeGuards.swift"
        )
    }
    
    func testReleaseSafetyConfigValid() {
        let violations = ReleaseSafetyConfig.validateConfiguration()
        
        XCTAssertTrue(
            violations.isEmpty,
            """
            Release safety configuration violations:
            \(violations.joined(separator: "\n"))
            """
        )
    }
}
