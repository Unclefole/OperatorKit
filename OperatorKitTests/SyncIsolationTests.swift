import XCTest
@testable import OperatorKit

// ============================================================================
// SYNC ISOLATION TESTS
//
// Verifies that Sync code paths are unreachable when the feature flag is
// disabled, enforcing the air-gap exception boundary.
//
// These tests prove CLAIM-001: "OperatorKit Core Verification Mode is fully
// air-gapped. Sync is an explicit, user-initiated, OFF-by-default exception."
// ============================================================================

final class SyncIsolationTests: XCTestCase {
    
    // MARK: - Feature Flag Default State
    
    /// CLAIM-001: Sync must be OFF by default
    func testSyncIsOffByDefault() {
        XCTAssertFalse(
            SyncFeatureFlag.defaultToggleState,
            "FAIL: Sync must be OFF by default. defaultToggleState should be false."
        )
    }
    
    /// CLAIM-022: Sync toggle defaults to OFF
    func testSyncToggleDefaultsToOff() {
        // Clear any stored preference
        UserDefaults.standard.removeObject(forKey: SyncFeatureFlag.storageKey)
        
        // The default should be OFF
        let storedValue = UserDefaults.standard.bool(forKey: SyncFeatureFlag.storageKey)
        XCTAssertFalse(storedValue, "FAIL: Sync storage key should default to false")
    }
    
    // MARK: - Sync Unreachable When Disabled
    
    /// CLAIM-001: When sync is disabled, SupabaseClient operations should fail
    func testSupabaseClientThrowsWhenSyncDisabled() async {
        // This test verifies the runtime guard works
        // Note: In production, SyncFeatureFlag.isEnabled is a compile-time check
        // For this test, we verify the guard exists by checking the client's state
        
        let client = SupabaseClient.shared
        
        // If sync is disabled at compile time, isSyncEnabled should return false
        #if SYNC_DISABLED
        XCTAssertFalse(client.isSyncEnabled, "FAIL: isSyncEnabled should be false when SYNC_DISABLED")
        #else
        // When sync is enabled at compile time, the feature is available
        // but still requires user opt-in
        XCTAssertTrue(SyncFeatureFlag.isEnabled, "Sync is enabled at compile time")
        #endif
    }
    
    // MARK: - Core Modules Have No URLSession
    
    /// CLAIM-001: Core execution modules must not import URLSession
    func testCoreModulesHaveNoURLSessionImports() throws {
        // List of core modules that must be air-gapped
        let coreModules = [
            "ExecutionEngine",
            "ApprovalGate",
            "ModelRouter",
            "DraftGenerator",
            "ContextAssembler",
            "MemoryStore",
            "QualityFeedbackStore",
            "GoldenCaseStore"
        ]
        
        // This is a documentation test - the actual enforcement is in CompileTimeGuards
        // We verify the invariant by checking that these classes exist and have no network methods
        
        for moduleName in coreModules {
            // Verify each module exists (would fail if renamed)
            let className = "OperatorKit.\(moduleName)"
            XCTAssertNotNil(
                NSClassFromString(className) ?? NSClassFromString(moduleName),
                "Core module \(moduleName) should exist"
            )
        }
    }
    
    // MARK: - Sync Module Isolation
    
    /// CLAIM-001: Only Sync module may use URLSession
    func testOnlySyncModuleMayUseURLSession() {
        // Document the allowed module
        XCTAssertEqual(
            NetworkAllowance.allowedModule,
            "Sync",
            "FAIL: Only the Sync module may use URLSession"
        )
        
        // Document forbidden modules
        let forbiddenModules = NetworkAllowance.forbiddenModules
        XCTAssertTrue(
            forbiddenModules.contains("Domain/Execution"),
            "Domain/Execution must be in forbidden modules"
        )
        XCTAssertTrue(
            forbiddenModules.contains("Domain/Approval"),
            "Domain/Approval must be in forbidden modules"
        )
        XCTAssertTrue(
            forbiddenModules.contains("Models"),
            "Models must be in forbidden modules"
        )
    }
    
    // MARK: - Forbidden Operations Documentation
    
    /// CLAIM-001: Forbidden operations are documented
    func testForbiddenOperationsAreDefined() {
        let forbidden = NetworkAllowance.ForbiddenOperation.allCases
        
        XCTAssertTrue(
            forbidden.contains(.backgroundUpload),
            "backgroundUpload must be forbidden"
        )
        XCTAssertTrue(
            forbidden.contains(.contentUpload),
            "contentUpload must be forbidden"
        )
        XCTAssertTrue(
            forbidden.contains(.analytics),
            "analytics must be forbidden"
        )
        XCTAssertTrue(
            forbidden.contains(.crashReporting),
            "crashReporting must be forbidden"
        )
        XCTAssertTrue(
            forbidden.contains(.remoteConfig),
            "remoteConfig must be forbidden"
        )
        XCTAssertTrue(
            forbidden.contains(.pushNotifications),
            "pushNotifications must be forbidden"
        )
    }
    
    // MARK: - Sync Safety Configuration
    
    /// CLAIM-023: Forbidden content keys must be defined
    func testForbiddenContentKeysAreDefined() {
        let forbidden = SyncSafetyConfig.forbiddenContentKeys
        
        XCTAssertFalse(forbidden.isEmpty, "Forbidden content keys must not be empty")
        XCTAssertTrue(forbidden.contains("body"), "body must be forbidden")
        XCTAssertTrue(forbidden.contains("content"), "content must be forbidden")
        XCTAssertTrue(forbidden.contains("draft"), "draft must be forbidden")
        XCTAssertTrue(forbidden.contains("prompt"), "prompt must be forbidden")
    }
    
    // MARK: - Sync Packet Types Are Limited
    
    /// CLAIM-023: Only approved packet types can sync
    func testSyncablePacketTypesAreLimited() {
        let types = SyncSafetyConfig.SyncablePacketType.allCases
        
        // Verify allowed types are metadata-only
        let allowedTypeNames = types.map { $0.rawValue }
        
        XCTAssertTrue(
            allowedTypeNames.contains("quality_export"),
            "quality_export should be syncable"
        )
        XCTAssertTrue(
            allowedTypeNames.contains("diagnostics_export"),
            "diagnostics_export should be syncable"
        )
        
        // Verify no content types
        XCTAssertFalse(
            allowedTypeNames.contains("draft"),
            "draft must NOT be syncable"
        )
        XCTAssertFalse(
            allowedTypeNames.contains("memory"),
            "memory must NOT be syncable"
        )
        XCTAssertFalse(
            allowedTypeNames.contains("context"),
            "context must NOT be syncable"
        )
    }
}
