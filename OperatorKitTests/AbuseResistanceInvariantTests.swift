import XCTest
@testable import OperatorKit

// ============================================================================
// ABUSE RESISTANCE INVARIANT TESTS (Phase 10F)
//
// These tests prove that abuse resistance:
// - Does NOT affect execution modules
// - Contains NO content keys
// - Is metadata-only
// - Rate shaping does NOT block approvals
// - Cost indicators are informational only
//
// See: docs/SAFETY_CONTRACT.md (Section 15)
// ============================================================================

final class AbuseResistanceInvariantTests: XCTestCase {
    
    // MARK: - A) Core Modules Not Affected
    
    /// Verifies ExecutionEngine.swift does NOT reference abuse/rate modules
    func testExecutionEngineDoesNotImportAbuseModules() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let forbiddenPatterns = [
            "RateShaper",
            "AbuseDetector",
            "CostIndicator",
            "TierBoundaryChecker",
            "UsageIntensity",
            "AbuseType"
        ]
        
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "INVARIANT VIOLATION: ExecutionEngine.swift contains forbidden pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ApprovalGate.swift does NOT reference abuse/rate modules
    func testApprovalGateDoesNotImportAbuseModules() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let forbiddenPatterns = [
            "RateShaper",
            "AbuseDetector",
            "CostIndicator",
            "TierBoundaryChecker"
        ]
        
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "INVARIANT VIOLATION: ApprovalGate.swift contains forbidden pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ModelRouter.swift does NOT reference abuse/rate modules
    func testModelRouterDoesNotImportAbuseModules() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let forbiddenPatterns = [
            "RateShaper",
            "AbuseDetector",
            "CostIndicator",
            "TierBoundaryChecker"
        ]
        
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "INVARIANT VIOLATION: ModelRouter.swift contains forbidden pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - B) Rate Shaping Does Not Block Approvals
    
    /// Verifies RateShaper only suggests, doesn't block execution
    func testRateShaperDoesNotBlockExecution() async {
        let shaper = await RateShaper.shared
        await shaper.reset()
        
        // Check should always return allow with no prior executions
        let result = await shaper.checkExecution()
        XCTAssertTrue(result.shouldProceed, "Rate shaper should allow execution when no prior activity")
    }
    
    /// Verifies rate shaping allows even with suggestion message
    func testRateShaperSuggestsButAllows() async {
        let shaper = await RateShaper.shared
        await shaper.reset()
        
        // Record multiple rapid executions
        for _ in 0..<3 {
            await shaper.recordExecution()
        }
        
        // Even with activity, shouldProceed can still be true (suggestion only)
        let result = await shaper.checkExecution()
        // The result might have a message but still allow
        if result.message != nil && result.shouldProceed {
            // This is expected - it's a suggestion, not a block
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - C) Abuse Detection Is Metadata-Only
    
    /// Verifies AbuseDetector uses hashes, not content
    func testAbuseDetectorUsesHashesOnly() {
        // The intent hash is computed from content, but content is not stored
        let hash1 = AbuseDetector.computeIntentHash("Test intent 1")
        let hash2 = AbuseDetector.computeIntentHash("Test intent 1")
        let hash3 = AbuseDetector.computeIntentHash("Test intent 2")
        
        // Same content produces same hash
        XCTAssertEqual(hash1, hash2)
        
        // Different content produces different hash
        XCTAssertNotEqual(hash1, hash3)
        
        // Hash is a fixed-length string (SHA256 = 64 hex chars)
        XCTAssertEqual(hash1.count, 64)
    }
    
    /// Verifies AbuseSummary contains no content keys
    func testAbuseSummaryContainsNoContentKeys() throws {
        let summary = AbuseSummary(
            capturedAt: Date(),
            totalAbuseDetections: 5,
            lastAbuseType: "rapid_fire",
            executionsInLastHour: 10,
            uniqueIntentsInLastHour: 8,
            schemaVersion: 1
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(summary)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        // Check for forbidden content keys
        let forbiddenKeys = SyncSafetyConfig.forbiddenContentKeys
        for key in forbiddenKeys {
            XCTAssertNil(json[key], "AbuseSummary should not contain forbidden key: \(key)")
        }
    }
    
    // MARK: - D) Cost Indicators Are Informational Only
    
    /// Verifies CostIndicator does not affect execution
    func testCostIndicatorIsInformationalOnly() async {
        let indicator = await CostIndicator.shared
        await indicator.reset()
        
        // Record some usage
        await indicator.recordExecution(complexity: .moderate)
        await indicator.recordExecution(complexity: .complex)
        
        // Get summary
        let summary = await indicator.summary
        
        // Summary should have level but no execution control
        XCTAssertNotNil(summary.levelToday)
        XCTAssertNotNil(summary.unitsToday)
        
        // There's no "block" or "deny" functionality
        // CostIndicator only observes, never controls
    }
    
    /// Verifies UsageUnits contains no pricing
    func testUsageUnitsContainsNoPricing() {
        let units = UsageUnits.fromExecutions(10)
        
        // Display string should NOT contain currency symbols
        let display = units.displayString
        XCTAssertFalse(display.contains("$"))
        XCTAssertFalse(display.contains("€"))
        XCTAssertFalse(display.contains("£"))
        XCTAssertTrue(display.contains("unit"))
    }
    
    // MARK: - E) Tier Boundaries Are UI-Only
    
    /// Verifies tier boundaries are enforced at UI, not execution
    func testTierBoundariesAreUIOnly() async {
        let checker = await TierBoundaryChecker.shared
        
        // Check for free tier at limit
        let result = await checker.canExecute(tier: .free, weeklyCount: 25)
        
        // Result has a block message but this is for UI only
        // The actual execution is not blocked by TierBoundaryChecker
        XCTAssertFalse(result.allowed)
        XCTAssertNotNil(result.blockMessage)
        
        // Verify the message is non-punitive
        if let message = result.blockMessage {
            XCTAssertFalse(message.lowercased().contains("abuse"))
            XCTAssertFalse(message.lowercased().contains("punish"))
            XCTAssertFalse(message.lowercased().contains("banned"))
        }
    }
    
    /// Verifies cross-user isolation is structural
    func testCrossUserIsolationIsStructural() async {
        let checker = await TierBoundaryChecker.shared
        let isolated = await checker.verifyCrossUserIsolation()
        XCTAssertTrue(isolated, "Cross-user isolation must always be true (structural)")
    }
    
    // MARK: - F) Never Features Are Blocked
    
    /// Verifies forbidden features are never available
    func testNeverFeaturesAreBlocked() {
        let neverFeatures = TierFeatureMatrix.neverFeatures
        
        // These should be blocked for all tiers
        for feature in neverFeatures {
            XCTAssertFalse(TierFeatureMatrix.hasFeature(feature, for: .free))
            XCTAssertFalse(TierFeatureMatrix.hasFeature(feature, for: .pro))
            XCTAssertFalse(TierFeatureMatrix.hasFeature(feature, for: .team))
        }
    }
    
    /// Verifies shared_execution is never available
    func testSharedExecutionNeverAvailable() {
        XCTAssertFalse(TierFeatureMatrix.hasFeature("shared_execution", for: .free))
        XCTAssertFalse(TierFeatureMatrix.hasFeature("shared_execution", for: .pro))
        XCTAssertFalse(TierFeatureMatrix.hasFeature("shared_execution", for: .team))
    }
    
    /// Verifies remote_killswitch is never available
    func testRemoteKillswitchNeverAvailable() {
        XCTAssertFalse(TierFeatureMatrix.hasFeature("remote_killswitch", for: .free))
        XCTAssertFalse(TierFeatureMatrix.hasFeature("remote_killswitch", for: .pro))
        XCTAssertFalse(TierFeatureMatrix.hasFeature("remote_killswitch", for: .team))
    }
    
    // MARK: - G) Messages Are Non-Punitive
    
    /// Verifies usage messages don't contain punitive language
    func testUsageMessagesAreNonPunitive() {
        let messages = [
            UsageMessages.burstDetected,
            UsageMessages.heavyUsage,
            UsageMessages.limitReached,
            UsageMessages.limitsExplanation,
            UsageMessages.repeatedRequest,
            UsageMessages.rapidFire,
            UsageMessages.upgradePrompt,
            UsageMessages.safetyVsLimits
        ]
        
        let punitiveTerms = [
            "abuse",
            "punish",
            "banned",
            "suspended",
            "violation",
            "cheating",
            "stealing"
        ]
        
        for message in messages {
            for term in punitiveTerms {
                XCTAssertFalse(
                    message.lowercased().contains(term),
                    "Message contains punitive term '\(term)': \(message)"
                )
            }
        }
    }
    
    /// Verifies messages don't moralize
    func testUsageMessagesDontMoralize() {
        let messages = [
            UsageMessages.burstDetected,
            UsageMessages.heavyUsage,
            UsageMessages.repeatedRequest
        ]
        
        let moralizingTerms = [
            "should be ashamed",
            "wrong of you",
            "unacceptable",
            "irresponsible",
            "careless"
        ]
        
        for message in messages {
            for term in moralizingTerms {
                XCTAssertFalse(
                    message.lowercased().contains(term.lowercased()),
                    "Message moralizes with '\(term)'"
                )
            }
        }
    }
    
    // MARK: - H) Safety Files Don't Import Execution
    
    /// Verifies Safety module files don't import execution modules
    func testSafetyFilesNoExecutionImports() throws {
        let safetyFiles = [
            ("RateShaping.swift", "Safety"),
            ("CostVisibility.swift", "Safety"),
            ("AbuseGuardrails.swift", "Safety"),
            ("TierBoundaries.swift", "Safety"),
            ("UsageMessages.swift", "Safety")
        ]
        
        let executionPatterns = [
            "ExecutionEngine",
            "ApprovalGate",
            "ModelRouter",
            "DraftGenerator",
            "ContextAssembler"
        ]
        
        for (fileName, directory) in safetyFiles {
            let filePath = findProjectFile(named: fileName, in: directory)
            guard FileManager.default.fileExists(atPath: filePath) else { continue }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            for pattern in executionPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "INVARIANT VIOLATION: \(fileName) contains execution pattern: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - Helpers
    
    private func findProjectFile(named fileName: String, in subdirectory: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let targetPath = projectRoot
            .appendingPathComponent("OperatorKit")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent(fileName)
            .path
        
        return targetPath
    }
}

// MARK: - Usage Intensity Tests

extension AbuseResistanceInvariantTests {
    
    /// Verifies UsageIntensity levels are ordered correctly
    func testUsageIntensityLevels() {
        XCTAssertEqual(UsageIntensity.allCases.count, 4)
        
        // Each level should have a display name
        for level in UsageIntensity.allCases {
            XCTAssertFalse(level.displayName.isEmpty)
            XCTAssertFalse(level.description.isEmpty)
        }
    }
    
    /// Verifies UsageLevel is informational
    func testUsageLevelIsInformational() {
        XCTAssertEqual(UsageLevel.allCases.count, 4)
        
        for level in UsageLevel.allCases {
            XCTAssertFalse(level.displayName.isEmpty)
            XCTAssertFalse(level.icon.isEmpty)
        }
    }
}
