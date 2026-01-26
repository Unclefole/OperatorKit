import XCTest
@testable import OperatorKit

// ============================================================================
// PRICING PACKAGING 11C TESTS
//
// Tests proving Phase 11C pricing constraints:
// - Core modules unchanged
// - Pricing registry contains Lifetime option
// - Lifetime product ID defined
// - Team minimum seats = 3
// - Free uses "Drafted Outcomes" language
// - No forbidden keys in pricing exports
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

final class PricingPackaging11CTests: XCTestCase {
    
    // MARK: - 1) ExecutionEngine No Phase 11C Imports
    
    func testExecutionEngineNoPhase11CImports() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase11CPatterns = [
            "PricingPackageRegistry",
            "PricingConsistencyValidator",
            "lifetimeSovereign",
            "teamMinimumSeats",
            "PurchaseType"
        ]
        
        for pattern in phase11CPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ExecutionEngine.swift contains Phase 11C pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - 2) ApprovalGate No Phase 11C Imports
    
    func testApprovalGateNoPhase11CImports() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase11CPatterns = [
            "PricingPackageRegistry",
            "lifetimeSovereign",
            "teamMinimumSeats"
        ]
        
        for pattern in phase11CPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ApprovalGate.swift contains Phase 11C pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - 3) ModelRouter No Phase 11C Imports
    
    func testModelRouterNoPhase11CImports() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase11CPatterns = [
            "PricingPackageRegistry",
            "lifetimeSovereign",
            "teamMinimumSeats"
        ]
        
        for pattern in phase11CPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ModelRouter.swift contains Phase 11C pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - 4) Pricing Registry Contains Lifetime Option
    
    func testPricingRegistryContainsLifetimeOption() {
        // Verify Lifetime Sovereign package exists
        XCTAssertNotNil(PricingPackageRegistry.lifetimeSovereign)
        XCTAssertEqual(PricingPackageRegistry.lifetimeSovereign.id, "package-lifetime-sovereign")
        
        // Verify it has a lifetime price
        XCTAssertNotNil(PricingPackageRegistry.lifetimeSovereign.lifetimePrice)
        XCTAssertEqual(PricingPackageRegistry.lifetimeSovereign.lifetimePrice, "$249")
        
        // Verify hasLifetimeOption flag
        XCTAssertTrue(PricingPackageRegistry.hasLifetimeOption)
    }
    
    // MARK: - 5) Lifetime Product ID Is Defined
    
    func testLifetimeProductIdIsDefined() {
        // Verify the product ID constant exists
        let lifetimeId = StoreKitProductIDs.lifetimeSovereign
        XCTAssertEqual(lifetimeId, "com.operatorkit.lifetime.sovereign")
        
        // Verify it's in allProducts
        XCTAssertTrue(StoreKitProductIDs.allProducts.contains(lifetimeId))
        
        // Verify it's in oneTimePurchases
        XCTAssertTrue(StoreKitProductIDs.oneTimePurchases.contains(lifetimeId))
        
        // Verify tier resolution
        XCTAssertEqual(StoreKitProductIDs.tier(for: lifetimeId), .pro)
        
        // Verify isLifetimeSovereign check
        XCTAssertTrue(StoreKitProductIDs.isLifetimeSovereign(lifetimeId))
        XCTAssertFalse(StoreKitProductIDs.isLifetimeSovereign(StoreKitProductIDs.proMonthly))
    }
    
    // MARK: - 6) Team Minimum Seats Is Three
    
    func testTeamMinimumSeatsIsThree() {
        // Verify constant
        XCTAssertEqual(PricingPackageRegistry.teamMinimumSeats, 3)
        
        // Verify Team package has minimumSeats set
        XCTAssertEqual(PricingPackageRegistry.team.minimumSeats, 3)
        
        // Verify validation passes
        XCTAssertTrue(PricingPackageRegistry.validateTeamMinimumSeats())
    }
    
    // MARK: - 7) Free Uses Drafted Outcomes Language
    
    func testFreeUsesDraftedOutcomesLanguage() {
        // Verify constant
        XCTAssertEqual(PricingPackageRegistry.freeWeeklyLimit, 25)
        XCTAssertEqual(PricingPackageRegistry.freeWeeklyLimitLabel, "25 Drafted Outcomes / week")
        
        // Verify Free package uses the language
        let freeBullets = PricingPackageRegistry.free.bullets.joined(separator: " ").lowercased()
        XCTAssertTrue(freeBullets.contains("drafted outcomes"))
        
        // Verify validation passes
        XCTAssertTrue(PricingPackageRegistry.validateFreeUsesDraftedOutcomesLanguage())
        
        // Verify "executions" is NOT used in Free bullets
        XCTAssertFalse(freeBullets.contains("executions"))
    }
    
    // MARK: - 8) Pricing Validator Finds No Errors For Default Config
    
    func testPricingValidatorFindsNoErrorsForDefaultConfig() {
        let result = PricingConsistencyValidator.shared.validate()
        
        // Should not have any failures
        XCTAssertNotEqual(result.status, .fail, "Validator should not fail for default config")
        
        // Check specific Phase 11C findings
        let draftedOutcomesFinding = result.findings.first { $0.id == "drafted-outcomes-language" }
        XCTAssertNotNil(draftedOutcomesFinding)
        XCTAssertEqual(draftedOutcomesFinding?.severity, .pass)
        
        let teamSeatsFinding = result.findings.first { $0.id == "team-min-seats" }
        XCTAssertNotNil(teamSeatsFinding)
        XCTAssertEqual(teamSeatsFinding?.severity, .pass)
        
        let lifetimePriceFinding = result.findings.first { $0.id == "lifetime-price-consistent" }
        XCTAssertNotNil(lifetimePriceFinding)
        XCTAssertEqual(lifetimePriceFinding?.severity, .pass)
        
        let lifetimeProductFinding = result.findings.first { $0.id == "lifetime-product-id" }
        XCTAssertNotNil(lifetimeProductFinding)
        XCTAssertEqual(lifetimeProductFinding?.severity, .pass)
    }
    
    // MARK: - 9) Pricing Copy No Banned Words
    
    func testPricingCopyNoBannedWords() {
        let violations = PricingPackageRegistry.validateNoBannedWords()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Pricing copy contains banned words: \(violations.joined(separator: ", "))"
        )
    }
    
    // MARK: - 10) No Forbidden Keys In Pricing Exports
    
    func testNoForbiddenKeysInPricingExportsOrPackets() throws {
        // Create snapshot and encode
        let snapshot = PricingPackageRegistrySnapshot()
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Could not decode snapshot JSON")
            return
        }
        
        // Forbidden keys
        let forbiddenKeys = [
            "body", "subject", "content", "draft", "prompt",
            "context", "email", "recipient", "attendees", "title",
            "description", "message", "text", "name", "address", "location"
        ]
        
        let violations = findForbiddenKeys(in: json, forbidden: forbiddenKeys, path: "")
        
        XCTAssertTrue(
            violations.isEmpty,
            "Pricing snapshot contains forbidden keys: \(violations.joined(separator: ", "))"
        )
    }
    
    // MARK: - Additional Phase 11C Tests
    
    /// Verify Pro package includes lifetime option mention
    func testProPackageMentionsLifetimeOption() {
        let proBullets = PricingPackageRegistry.pro.bullets.joined(separator: " ").lowercased()
        XCTAssertTrue(proBullets.contains("lifetime"))
    }
    
    /// Verify Team package describes procedure sharing
    func testTeamPackageDescribesProcedureSharing() {
        let teamBullets = PricingPackageRegistry.team.bullets.joined(separator: " ").lowercased()
        XCTAssertTrue(teamBullets.contains("procedure"))
        
        // Should mention "no shared drafts"
        XCTAssertTrue(teamBullets.contains("no shared drafts"))
    }
    
    /// Verify Team package mentions monthly audit export
    func testTeamPackageMentionsMonthlyAuditExport() {
        let teamBullets = PricingPackageRegistry.team.bullets.joined(separator: " ").lowercased()
        XCTAssertTrue(teamBullets.contains("monthly audit"))
    }
    
    /// Verify SubscriptionStatus handles lifetime correctly
    func testSubscriptionStatusHandlesLifetime() {
        let lifetimeStatus = SubscriptionStatus.lifetimeSovereign(productId: StoreKitProductIDs.lifetimeSovereign)
        
        XCTAssertTrue(lifetimeStatus.isLifetime)
        XCTAssertTrue(lifetimeStatus.isActive)
        XCTAssertEqual(lifetimeStatus.tier, .pro)
        XCTAssertNil(lifetimeStatus.renewalDate)
        XCTAssertEqual(lifetimeStatus.periodDescription, "Lifetime")
        XCTAssertEqual(lifetimeStatus.subscriptionTypeLabel, "Lifetime Sovereign")
    }
    
    /// Verify Sales Playbook includes new sections
    func testSalesPlaybookIncludesPhase11CSections() {
        let sectionIds = SalesPlaybookContent.allSections.map { $0.id }
        
        XCTAssertTrue(sectionIds.contains("team-procedure-sharing"))
        XCTAssertTrue(sectionIds.contains("lifetime-sovereign"))
    }
    
    /// Verify no anthropomorphic language in pricing
    func testPricingNoAnthropomorphicLanguage() {
        let violations = PricingPackageRegistry.validateNoAnthropomorphicLanguage()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Pricing copy contains anthropomorphic language: \(violations.joined(separator: ", "))"
        )
    }
    
    // MARK: - Helpers
    
    private func findProjectFile(named fileName: String, in subdirectory: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        return projectRoot
            .appendingPathComponent("OperatorKit")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent(fileName)
            .path
    }
    
    private func findForbiddenKeys(in dict: [String: Any], forbidden: [String], path: String) -> [String] {
        var violations: [String] = []
        
        for (key, value) in dict {
            let fullPath = path.isEmpty ? key : "\(path).\(key)"
            
            if forbidden.contains(key.lowercased()) {
                violations.append("Forbidden key: \(fullPath)")
            }
            
            if let nested = value as? [String: Any] {
                violations.append(contentsOf: findForbiddenKeys(in: nested, forbidden: forbidden, path: fullPath))
            }
            
            if let array = value as? [[String: Any]] {
                for (index, item) in array.enumerated() {
                    violations.append(contentsOf: findForbiddenKeys(in: item, forbidden: forbidden, path: "\(fullPath)[\(index)]"))
                }
            }
        }
        
        return violations
    }
}
