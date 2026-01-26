import XCTest
@testable import OperatorKit

// ============================================================================
// LAUNCH TRUST CALIBRATION INVARIANT TESTS (Phase L2)
//
// Tests proving the trust calibration ceremony is:
// - One-time only
// - Proof-backed
// - Non-enforcing
// - Free of networking/background tasks
//
// CONSTRAINTS:
// ❌ No runtime modifications
// ❌ No networking
// ✅ UX verification only
// ============================================================================

final class LaunchTrustCalibrationInvariantTests: XCTestCase {
    
    // MARK: - Setup / Teardown
    
    override func setUp() {
        super.setUp()
        #if DEBUG
        // Reset state before each test
        LaunchTrustCalibrationState.resetForTesting()
        LaunchTrustCalibrationFeatureFlag.resetToDefault()
        #endif
    }
    
    override func tearDown() {
        #if DEBUG
        // Clean up after each test
        LaunchTrustCalibrationState.resetForTesting()
        LaunchTrustCalibrationFeatureFlag.resetToDefault()
        #endif
        super.tearDown()
    }
    
    // MARK: - One-Time Only Tests
    
    /// Test that calibration is shown only once
    func testCalibrationShownOnlyOnce() {
        #if DEBUG
        // Initially should show calibration
        LaunchTrustCalibrationState.resetForTesting()
        XCTAssertTrue(
            LaunchTrustCalibrationState.shouldShowCalibration,
            "Calibration should show on first launch"
        )
        
        // After marking complete, should not show
        LaunchTrustCalibrationState.markComplete()
        XCTAssertFalse(
            LaunchTrustCalibrationState.shouldShowCalibration,
            "Calibration should NOT show after completion"
        )
        
        // Even after multiple checks, should stay false
        XCTAssertFalse(LaunchTrustCalibrationState.shouldShowCalibration)
        XCTAssertFalse(LaunchTrustCalibrationState.shouldShowCalibration)
        #endif
    }
    
    /// Test completion flag persists correctly
    func testCompletionFlagPersists() {
        #if DEBUG
        // Reset to uncompleted state
        LaunchTrustCalibrationState.resetForTesting()
        XCTAssertFalse(
            LaunchTrustCalibrationState.hasCompletedTrustCalibration,
            "Should start as not completed"
        )
        
        // Mark complete
        LaunchTrustCalibrationState.markComplete()
        XCTAssertTrue(
            LaunchTrustCalibrationState.hasCompletedTrustCalibration,
            "Should be marked as completed"
        )
        
        // Verify it persists (in same session at least)
        XCTAssertTrue(
            LaunchTrustCalibrationState.hasCompletedTrustCalibration,
            "Completion should persist"
        )
        #endif
    }
    
    // MARK: - Feature Flag Tests
    
    /// Test feature flag controls visibility
    func testFeatureFlagGatesCalibration() {
        #if DEBUG
        // Reset state
        LaunchTrustCalibrationState.resetForTesting()
        
        // With flag enabled, should show
        LaunchTrustCalibrationFeatureFlag.setEnabled(true)
        XCTAssertTrue(
            LaunchTrustCalibrationState.shouldShowCalibration,
            "Should show when flag enabled and not completed"
        )
        
        // With flag disabled, should not show (even if not completed)
        LaunchTrustCalibrationFeatureFlag.setEnabled(false)
        XCTAssertFalse(
            LaunchTrustCalibrationState.shouldShowCalibration,
            "Should NOT show when flag disabled"
        )
        
        // Reset
        LaunchTrustCalibrationFeatureFlag.resetToDefault()
        #endif
    }
    
    // MARK: - No Networking Tests
    
    /// Test that feature has no networking imports
    func testNoNetworkingImports() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let featurePath = projectRoot.appendingPathComponent(
            "OperatorKit/Features/LaunchTrustCalibration"
        )
        
        let networkingPatterns = [
            "import Network",
            "URLSession",
            "URLRequest",
            "CFNetwork",
            "BGTaskScheduler",
            "BackgroundTasks"
        ]
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: featurePath,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            
            for pattern in networkingPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "LaunchTrustCalibration file \(fileURL.lastPathComponent) should not contain: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - No Background APIs Tests
    
    /// Test that feature has no background task APIs
    func testNoBackgroundAPIs() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let featurePath = projectRoot.appendingPathComponent(
            "OperatorKit/Features/LaunchTrustCalibration"
        )
        
        let backgroundPatterns = [
            "BGTaskScheduler",
            "BGAppRefreshTask",
            "BGProcessingTask",
            "beginBackgroundTask",
            "UIApplication.shared.backgroundTimeRemaining"
        ]
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: featurePath,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            
            for pattern in backgroundPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "LaunchTrustCalibration file \(fileURL.lastPathComponent) should not contain: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - No Enforcement Logic Tests
    
    /// Test that there's no enforcement logic in the feature
    func testNoEnforcementLogic() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let viewPath = projectRoot.appendingPathComponent(
            "OperatorKit/Features/LaunchTrustCalibration/LaunchTrustCalibrationView.swift"
        )
        
        guard FileManager.default.fileExists(atPath: viewPath.path) else {
            return
        }
        
        let content = try String(contentsOf: viewPath, encoding: .utf8)
        
        // Should explicitly state it's a ceremony
        XCTAssertTrue(
            content.contains("ceremony") || content.contains("CEREMONY"),
            "View should document it's a ceremony"
        )
        
        // Should not contain enforcement patterns
        XCTAssertFalse(
            content.contains("fatalError"),
            "Should not contain fatalError enforcement"
        )
        
        // Should not block based on results
        XCTAssertFalse(
            content.contains("guard.*else.*return") && content.contains("step.status == .failed"),
            "Should not block app based on step results"
        )
    }
    
    // MARK: - All Steps Map to Proof Tests
    
    /// Test that all calibration steps map to existing proof sources
    func testAllStepsMapToProofSources() {
        let steps = CalibrationStepFactory.createSteps()
        
        // Should have exactly 7 steps as defined
        XCTAssertEqual(
            steps.count,
            7,
            "Should have 7 calibration steps"
        )
        
        // Valid proof sources
        let validProofSources: Set<String> = [
            "Binary Proof",
            "Entitlements Seal",
            "Symbol Seal",
            "Offline Certification",
            "Build Seals",
            "ProofPack"
        ]
        
        for step in steps {
            // Each step should have a label
            XCTAssertFalse(
                step.label.isEmpty,
                "Step should have a label"
            )
            
            // Each step should have a valid proof source
            XCTAssertTrue(
                validProofSources.contains(step.proofSource),
                "Step '\(step.label)' has invalid proof source: '\(step.proofSource)'"
            )
            
            // Each step's verify closure should be callable
            let _ = step.verify() // Just verify it doesn't crash
        }
    }
    
    /// Test specific required steps are present
    func testRequiredStepsPresent() {
        let steps = CalibrationStepFactory.createSteps()
        let labels = steps.map { $0.label }
        
        let requiredLabels = [
            "Binary contains no WebKit",
            "JavaScript not linked",
            "Network entitlements absent",
            "Forbidden symbols absent",
            "Offline execution certified",
            "Build integrity verified",
            "Proof export available"
        ]
        
        for required in requiredLabels {
            XCTAssertTrue(
                labels.contains(required),
                "Missing required step: \(required)"
            )
        }
    }
    
    // MARK: - Protected Modules Tests
    
    /// Test that protected modules are not touched
    func testProtectedModulesUntouched() throws {
        let protectedModules = [
            "ExecutionEngine.swift",
            "ApprovalGate.swift",
            "ModelRouter.swift",
            "SideEffectContract.swift"
        ]
        
        let calibrationIdentifiers = [
            "LaunchTrustCalibration",
            "TrustCalibration",
            "CalibrationStep"
        ]
        
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        for module in protectedModules {
            let possiblePaths = [
                projectRoot.appendingPathComponent("OperatorKit/Domain/Execution/\(module)"),
                projectRoot.appendingPathComponent("OperatorKit/Domain/Approval/\(module)"),
                projectRoot.appendingPathComponent("OperatorKit/Models/\(module)")
            ]
            
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path.path) {
                    let content = try String(contentsOf: path, encoding: .utf8)
                    
                    for identifier in calibrationIdentifiers {
                        XCTAssertFalse(
                            content.contains(identifier),
                            "Protected module \(module) should not reference \(identifier)"
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Interpretation Lock Tests
    
    /// Test that interpretation lock #19 exists
    func testInterpretationLockExists() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let lockPath = projectRoot.appendingPathComponent("docs/INTERPRETATION_LOCKS.md")
        
        guard FileManager.default.fileExists(atPath: lockPath.path) else {
            XCTFail("INTERPRETATION_LOCKS.md should exist")
            return
        }
        
        let content = try String(contentsOf: lockPath, encoding: .utf8)
        
        XCTAssertTrue(
            content.contains("Lock #19"),
            "INTERPRETATION_LOCKS.md should contain Lock #19"
        )
        
        XCTAssertTrue(
            content.contains("Trust Calibration") || content.contains("Calibration"),
            "Lock #19 should reference Trust Calibration"
        )
        
        XCTAssertTrue(
            content.contains("ceremony") || content.contains("Ceremony") || content.contains("CEREMONY"),
            "Lock #19 should clarify ceremony nature"
        )
    }
    
    // MARK: - Step Verification Tests
    
    /// Test that step verifications are deterministic
    func testStepVerificationsDeterministic() {
        let steps = CalibrationStepFactory.createSteps()
        
        for step in steps {
            let result1 = step.verify()
            let result2 = step.verify()
            
            XCTAssertEqual(
                result1,
                result2,
                "Step '\(step.label)' verification should be deterministic"
            )
        }
    }
    
    /// Test that steps don't modify state
    func testStepsDoNotModifyState() {
        #if DEBUG
        // Get initial state
        let initialCompleted = LaunchTrustCalibrationState.hasCompletedTrustCalibration
        
        // Run all step verifications
        let steps = CalibrationStepFactory.createSteps()
        for step in steps {
            let _ = step.verify()
        }
        
        // State should be unchanged
        XCTAssertEqual(
            LaunchTrustCalibrationState.hasCompletedTrustCalibration,
            initialCompleted,
            "Step verifications should not modify completion state"
        )
        #endif
    }
}
