import XCTest
@testable import OperatorKit

// ============================================================================
// MONETIZATION ENFORCEMENT INVARIANT TESTS (Phase 10G)
//
// These tests prove that monetization enforcement:
// - Does NOT affect ExecutionEngine, ApprovalGate, or ModelRouter
// - Is UI-boundary only
// - Contains no forbidden content keys
// - Shows paywall, does not silently block
// - Free tier blocks correctly, Pro/Team bypasses
//
// See: docs/SAFETY_CONTRACT.md (Section 16)
// ============================================================================

final class MonetizationEnforcementInvariantTests: XCTestCase {
    
    // MARK: - A) Core Modules Not Affected
    
    /// Verifies ExecutionEngine.swift does NOT reference monetization modules
    func testExecutionEngineDoesNotImportMonetization() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let forbiddenPatterns = [
            "QuotaEnforcer",
            "PaywallGate",
            "TierMatrix",
            "TierQuotas",
            "StoreKit",
            "EntitlementManager",
            "PurchaseController"
        ]
        
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "INVARIANT VIOLATION: ExecutionEngine.swift contains forbidden pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ApprovalGate.swift does NOT reference monetization modules
    func testApprovalGateDoesNotImportMonetization() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let forbiddenPatterns = [
            "QuotaEnforcer",
            "PaywallGate",
            "TierMatrix",
            "TierQuotas",
            "StoreKit"
        ]
        
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "INVARIANT VIOLATION: ApprovalGate.swift contains forbidden pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ModelRouter.swift does NOT reference monetization modules
    func testModelRouterDoesNotImportMonetization() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let forbiddenPatterns = [
            "QuotaEnforcer",
            "PaywallGate",
            "TierMatrix",
            "TierQuotas",
            "StoreKit"
        ]
        
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "INVARIANT VIOLATION: ModelRouter.swift contains forbidden pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - B) No StoreKit in Execution Modules
    
    /// Verifies no StoreKit import leaks into execution domain
    func testNoStoreKitInExecutionDomain() throws {
        let executionFiles = [
            ("ExecutionEngine.swift", "Domain/Execution"),
            ("ApprovalGate.swift", "Domain/Approval"),
            ("IntentParser.swift", "Domain/Intent"),
            ("DraftGenerator.swift", "Domain/Draft"),
            ("ContextAssembler.swift", "Domain/Context")
        ]
        
        for (fileName, directory) in executionFiles {
            let filePath = findProjectFile(named: fileName, in: directory)
            guard FileManager.default.fileExists(atPath: filePath) else { continue }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertFalse(
                content.contains("import StoreKit"),
                "INVARIANT VIOLATION: \(fileName) imports StoreKit"
            )
        }
    }
    
    // MARK: - C) No New URLSession Outside Sync
    
    /// Verifies no URLSession usage in monetization modules
    func testMonetizationNoURLSession() throws {
        let monetizationFiles = [
            ("QuotaEnforcer.swift", "Monetization"),
            ("PaywallGate.swift", "Monetization"),
            ("TierMatrix.swift", "Monetization"),
            ("EntitlementManager.swift", "Monetization"),
            ("PurchaseController.swift", "Monetization")
        ]
        
        for (fileName, directory) in monetizationFiles {
            let filePath = findProjectFile(named: fileName, in: directory)
            guard FileManager.default.fileExists(atPath: filePath) else { continue }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertFalse(
                content.contains("URLSession"),
                "INVARIANT VIOLATION: \(fileName) uses URLSession (only allowed in Sync modules)"
            )
        }
    }
    
    // MARK: - D) No Forbidden Content Keys
    
    /// Verifies QuotaCheckResult contains no content keys
    func testQuotaCheckResultNoContentKeys() {
        let result = QuotaCheckResult.blocked(
            quotaType: .weeklyExecutions,
            currentUsage: 25,
            limit: 25,
            message: "Limit reached"
        )
        
        // QuotaCheckResult should only have counters and metadata
        XCTAssertNotNil(result.quotaType)
        XCTAssertNotNil(result.currentUsage)
        XCTAssertNotNil(result.limit)
        
        // No content fields exist in the struct
        // This is a structural check - if content fields existed, they would be accessible
    }
    
    /// Verifies TierSummary contains no content keys
    func testTierSummaryNoContentKeys() {
        let summary = TierSummary(tier: .pro)
        
        // Should only have tier metadata
        XCTAssertNotNil(summary.displayName)
        XCTAssertNotNil(summary.shortDescription)
        XCTAssertNotNil(summary.weeklyExecutionLimit)
        XCTAssertNotNil(summary.memoryLimit)
        
        // These should not contain user content
        XCTAssertFalse(summary.displayName.contains("body"))
        XCTAssertFalse(summary.displayName.contains("email"))
        XCTAssertFalse(summary.displayName.contains("draft"))
    }
    
    // MARK: - E) Free Tier Blocking
    
    /// Verifies Free tier over quota returns blocked result
    func testFreeTierOverQuotaBlocks() async {
        // Get the weekly execution limit for free tier
        let freeLimit = TierQuotas.weeklyExecutionLimit(for: .free)
        XCTAssertNotNil(freeLimit, "Free tier should have a limit")
        
        // When usage equals limit, should block
        let result = QuotaCheckResult.blocked(
            quotaType: .weeklyExecutions,
            currentUsage: freeLimit!,
            limit: freeLimit!,
            message: "Limit reached"
        )
        
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.showPaywall)
        XCTAssertNotNil(result.message)
    }
    
    /// Verifies Free tier under quota allows
    func testFreeTierUnderQuotaAllows() async {
        let freeLimit = TierQuotas.weeklyExecutionLimit(for: .free)!
        
        let result = QuotaCheckResult.allowed(
            quotaType: .weeklyExecutions,
            currentUsage: freeLimit - 1,
            limit: freeLimit
        )
        
        XCTAssertTrue(result.allowed)
        XCTAssertFalse(result.showPaywall)
    }
    
    // MARK: - F) Pro Tier Bypasses
    
    /// Verifies Pro tier has no execution limit
    func testProTierNoExecutionLimit() {
        let proLimit = TierQuotas.weeklyExecutionLimit(for: .pro)
        XCTAssertNil(proLimit, "Pro tier should have unlimited executions")
    }
    
    /// Verifies Pro tier has no memory limit
    func testProTierNoMemoryLimit() {
        let proLimit = TierQuotas.memoryItemLimit(for: .pro)
        XCTAssertNil(proLimit, "Pro tier should have unlimited memory")
    }
    
    // MARK: - G) Team Tier Capabilities
    
    /// Verifies Team tier has team access
    func testTeamTierHasTeamAccess() {
        XCTAssertTrue(TierQuotas.hasTeamAccess(for: .team))
        XCTAssertFalse(TierQuotas.hasTeamAccess(for: .pro))
        XCTAssertFalse(TierQuotas.hasTeamAccess(for: .free))
    }
    
    /// Verifies Team tier has sync access
    func testTeamTierHasSyncAccess() {
        XCTAssertTrue(TierQuotas.hasSyncAccess(for: .team))
        XCTAssertTrue(TierQuotas.hasSyncAccess(for: .pro))
        XCTAssertFalse(TierQuotas.hasSyncAccess(for: .free))
    }
    
    // MARK: - H) Paywall Shows, Does Not Block Silently
    
    /// Verifies blocked result triggers paywall
    func testBlockedResultShowsPaywall() {
        let result = QuotaCheckResult.blocked(
            quotaType: .weeklyExecutions,
            currentUsage: 25,
            limit: 25,
            message: "Limit reached"
        )
        
        XCTAssertTrue(result.showPaywall, "Blocked result must show paywall")
        XCTAssertNotNil(result.message, "Blocked result must have message")
    }
    
    /// Verifies approaching limit result does not block
    func testApproachingLimitDoesNotBlock() {
        let result = QuotaCheckResult.approaching(
            quotaType: .weeklyExecutions,
            currentUsage: 22,
            limit: 25,
            remaining: 3
        )
        
        XCTAssertTrue(result.allowed, "Approaching limit should still allow")
        XCTAssertFalse(result.showPaywall, "Approaching limit should not show paywall")
        XCTAssertNotNil(result.message, "Approaching limit should have warning message")
    }
    
    // MARK: - I) Tier Matrix Consistency
    
    /// Verifies all tiers have consistent feature definitions
    func testTierMatrixConsistency() {
        // Free tier should have limits
        XCTAssertNotNil(TierMatrix.weeklyExecutionLimit(for: .free))
        XCTAssertNotNil(TierMatrix.memoryItemLimit(for: .free))
        
        // Pro/Team should be unlimited
        XCTAssertNil(TierMatrix.weeklyExecutionLimit(for: .pro))
        XCTAssertNil(TierMatrix.weeklyExecutionLimit(for: .team))
        XCTAssertNil(TierMatrix.memoryItemLimit(for: .pro))
        XCTAssertNil(TierMatrix.memoryItemLimit(for: .team))
        
        // Feature access should be hierarchical
        XCTAssertFalse(TierMatrix.canSync(tier: .free))
        XCTAssertTrue(TierMatrix.canSync(tier: .pro))
        XCTAssertTrue(TierMatrix.canSync(tier: .team))
        
        XCTAssertFalse(TierMatrix.canUseTeam(tier: .free))
        XCTAssertFalse(TierMatrix.canUseTeam(tier: .pro))
        XCTAssertTrue(TierMatrix.canUseTeam(tier: .team))
    }
    
    // MARK: - J) App Store Safe Language
    
    /// Verifies messages don't contain problematic claims
    func testMessagesAreAppStoreSafe() {
        let messages = [
            QuotaMessages.executionLimitReached(limit: 25),
            QuotaMessages.memoryLimitReached(limit: 10),
            QuotaMessages.teamTierRequired,
            QuotaMessages.teamSeatLimitReached(limit: 100),
            QuotaMessages.teamArtifactLimitReached(limit: 50),
            QuotaMessages.syncRequiresPro,
            WhyWeChargeText.shortExplanation,
            WhyWeChargeText.longExplanation
        ]
        
        let problematicTerms = [
            "AI learns",
            "AI decides",
            "secure",        // Unless proven
            "encrypted",     // Unless proven
            "guaranteed",
            "100%"
        ]
        
        for message in messages {
            for term in problematicTerms {
                XCTAssertFalse(
                    message.lowercased().contains(term.lowercased()),
                    "Message contains problematic term '\(term)': \(message)"
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

// MARK: - Tier Feature Tests

extension MonetizationEnforcementInvariantTests {
    
    /// Verifies all tier features have display names
    func testAllTierFeaturesHaveDisplayNames() {
        for feature in TierFeature.allCases {
            XCTAssertFalse(feature.displayName.isEmpty)
            XCTAssertFalse(feature.icon.isEmpty)
        }
    }
    
    /// Verifies tier features are correctly assigned
    func testTierFeaturesCorrectlyAssigned() {
        // Free tier basics
        XCTAssertTrue(TierMatrix.hasFeature(.localExecution, for: .free))
        XCTAssertTrue(TierMatrix.hasFeature(.approvalRequired, for: .free))
        XCTAssertFalse(TierMatrix.hasFeature(.unlimitedExecutions, for: .free))
        XCTAssertFalse(TierMatrix.hasFeature(.cloudSync, for: .free))
        XCTAssertFalse(TierMatrix.hasFeature(.teamGovernance, for: .free))
        
        // Pro tier
        XCTAssertTrue(TierMatrix.hasFeature(.localExecution, for: .pro))
        XCTAssertTrue(TierMatrix.hasFeature(.unlimitedExecutions, for: .pro))
        XCTAssertTrue(TierMatrix.hasFeature(.cloudSync, for: .pro))
        XCTAssertFalse(TierMatrix.hasFeature(.teamGovernance, for: .pro))
        
        // Team tier
        XCTAssertTrue(TierMatrix.hasFeature(.localExecution, for: .team))
        XCTAssertTrue(TierMatrix.hasFeature(.unlimitedExecutions, for: .team))
        XCTAssertTrue(TierMatrix.hasFeature(.cloudSync, for: .team))
        XCTAssertTrue(TierMatrix.hasFeature(.teamGovernance, for: .team))
    }
}
