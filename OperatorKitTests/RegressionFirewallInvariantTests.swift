import XCTest
@testable import OperatorKit

// ============================================================================
// REGRESSION FIREWALL INVARIANT TESTS (Phase 13D)
//
// Tests proving Regression Firewall is:
// - Deterministic
// - Pure (no side effects)
// - No networking
// - No state mutation
// - Feature-flagged
//
// See: docs/REGRESSION_FIREWALL_SPEC.md
// ============================================================================

final class RegressionFirewallInvariantTests: XCTestCase {
    
    // MARK: - Test 1: Firewall Rules Exist And Are Deterministic
    
    func testFirewallRulesExistAndAreDeterministic() {
        let rules = RegressionFirewallRules.all
        
        // Rules should exist
        XCTAssertGreaterThan(rules.count, 0, "Firewall rules should exist")
        XCTAssertEqual(rules.count, 12, "Expected 12 firewall rules")
        
        // Run verification twice
        let results1 = rules.map { $0.verify() }
        let results2 = rules.map { $0.verify() }
        
        // Results should be deterministic
        for i in 0..<rules.count {
            XCTAssertEqual(
                results1[i].passed,
                results2[i].passed,
                "Rule \(rules[i].id) should be deterministic"
            )
        }
    }
    
    // MARK: - Test 2: Runner Performs No Network Calls
    
    func testRunnerPerformsNoNetworkCalls() throws {
        let runnerFiles = [
            "RegressionFirewallRunner.swift",
            "RegressionFirewallRule.swift"
        ]
        
        for fileName in runnerFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/RegressionFirewall/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertFalse(
                content.contains("URLSession"),
                "\(fileName) should not use URLSession"
            )
            
            XCTAssertFalse(
                content.contains("URLRequest"),
                "\(fileName) should not use URLRequest"
            )
            
            XCTAssertFalse(
                content.contains("import Network"),
                "\(fileName) should not import Network"
            )
        }
    }
    
    // MARK: - Test 3: Runner Cannot Mutate State
    
    func testRunnerCannotMutateState() throws {
        let runnerPath = findProjectFile(at: "OperatorKit/Features/RegressionFirewall/RegressionFirewallRunner.swift")
        let content = try String(contentsOfFile: runnerPath, encoding: .utf8)
        
        // Should not have UserDefaults writes
        XCTAssertFalse(
            content.contains("UserDefaults") && content.contains(".set("),
            "Runner should not write to UserDefaults"
        )
        
        // Should not have file writes
        XCTAssertFalse(
            content.contains("FileManager") && content.contains("write"),
            "Runner should not write files"
        )
        
        // Should not modify execution state
        XCTAssertFalse(
            content.contains("ExecutionEngine"),
            "Runner should not reference ExecutionEngine"
        )
    }
    
    // MARK: - Test 4: Core Execution Modules Untouched
    
    func testCoreExecutionModulesUntouched() throws {
        let protectedFiles = [
            ("ExecutionEngine.swift", "OperatorKit/Domain/Execution"),
            ("ApprovalGate.swift", "OperatorKit/Domain/Approval"),
            ("ModelRouter.swift", "OperatorKit/Models")
        ]
        
        for (fileName, subdirectory) in protectedFiles {
            let filePath = findProjectFile(at: "\(subdirectory)/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertFalse(
                content.contains("Phase 13D"),
                "\(fileName) should not contain Phase 13D references"
            )
            
            XCTAssertFalse(
                content.contains("RegressionFirewall"),
                "\(fileName) should not reference RegressionFirewall"
            )
        }
    }
    
    // MARK: - Test 5: Firewall Detects Simulated Violations
    
    func testFirewallDetectsSimulatedViolations() {
        // Create a rule that simulates a violation
        let failingRule = RegressionFirewallRule(
            id: "TEST-FAIL",
            name: "Test Failing Rule",
            category: .networking,
            description: "This rule always fails for testing",
            severity: .critical,
            verify: {
                .fail("Simulated violation for testing")
            }
        )
        
        let result = failingRule.verify()
        
        XCTAssertFalse(result.passed, "Simulated failing rule should fail")
        XCTAssertTrue(result.evidence.contains("Simulated"), "Evidence should explain failure")
    }
    
    // MARK: - Test 6: Firewall Passes On Clean Build
    
    func testFirewallPassesOnCleanBuild() {
        let report = RegressionFirewallRunner.shared.runAllRules()
        
        // On a clean build, all rules should pass
        XCTAssertEqual(
            report.status,
            .passed,
            "Firewall should pass on clean build"
        )
        
        XCTAssertEqual(
            report.failedCount,
            0,
            "No rules should fail on clean build"
        )
        
        XCTAssertEqual(
            report.passedCount,
            report.ruleCount,
            "All rules should pass"
        )
    }
    
    // MARK: - Test 7: Feature Flag Gates Visibility
    
    func testFeatureFlagGatesVisibility() throws {
        let viewPath = findProjectFile(at: "OperatorKit/Features/RegressionFirewall/RegressionFirewallDashboardView.swift")
        let content = try String(contentsOfFile: viewPath, encoding: .utf8)
        
        XCTAssertTrue(
            content.contains("RegressionFirewallFeatureFlag.isEnabled"),
            "Dashboard must check feature flag"
        )
        
        XCTAssertTrue(
            content.contains("featureDisabledView"),
            "Dashboard must handle disabled state"
        )
    }
    
    // MARK: - Test 8: No Sealed Hashes Changed
    
    func testNoSealedHashesChanged() {
        XCTAssertEqual(
            ReleaseSeal.terminologyCanonHash,
            "SEAL_TERMINOLOGY_CANON_V1",
            "Terminology Canon seal should not change"
        )
        
        XCTAssertEqual(
            ReleaseSeal.claimRegistryHash,
            "SEAL_CLAIM_REGISTRY_V25",
            "Claim Registry seal should not change"
        )
        
        XCTAssertEqual(
            ReleaseSeal.safetyContractHash,
            "SEAL_SAFETY_CONTRACT_V1",
            "Safety Contract seal should not change"
        )
    }
    
    // MARK: - Test 9: All Categories Have Rules
    
    func testAllCategoriesHaveRules() {
        for category in RuleCategory.allCases {
            let categoryRules = RegressionFirewallRules.rules(in: category)
            XCTAssertGreaterThan(
                categoryRules.count,
                0,
                "Category \(category.rawValue) should have at least one rule"
            )
        }
    }
    
    // MARK: - Test 10: Quick Status Is Consistent
    
    func testQuickStatusIsConsistent() {
        let quickStatus = RegressionFirewallRunner.shared.quickStatus()
        let fullReport = RegressionFirewallRunner.shared.runAllRules()
        
        XCTAssertEqual(
            quickStatus,
            fullReport.status,
            "Quick status should match full report status"
        )
    }
    
    // MARK: - Test 11: Spec Document Exists
    
    func testRegressionFirewallSpecExists() throws {
        let specPath = findDocFile(named: "REGRESSION_FIREWALL_SPEC.md")
        
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: specPath),
            "REGRESSION_FIREWALL_SPEC.md must exist"
        )
        
        let content = try String(contentsOfFile: specPath, encoding: .utf8)
        
        XCTAssertTrue(content.contains("Rule Categories"), "Spec must document rule categories")
        XCTAssertTrue(content.contains("Failure Semantics"), "Spec must document failure handling")
        XCTAssertTrue(content.contains("NOT"), "Spec must document non-guarantees")
    }
    
    // MARK: - Test 12: Results Are Reproducible
    
    func testResultsAreReproducible() {
        let report1 = RegressionFirewallRunner.shared.runAllRules()
        let report2 = RegressionFirewallRunner.shared.runAllRules()
        
        // Status should be the same
        XCTAssertEqual(report1.status, report2.status, "Status should be reproducible")
        
        // Rule count should be the same
        XCTAssertEqual(report1.ruleCount, report2.ruleCount, "Rule count should be reproducible")
        
        // Passed count should be the same
        XCTAssertEqual(report1.passedCount, report2.passedCount, "Passed count should be reproducible")
        
        // Each rule should have same result
        for i in 0..<report1.results.count {
            XCTAssertEqual(
                report1.results[i].passed,
                report2.results[i].passed,
                "Rule \(report1.results[i].ruleId) result should be reproducible"
            )
        }
    }
    
    // MARK: - Helpers
    
    private func findDocFile(named fileName: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        return projectRoot
            .appendingPathComponent("docs")
            .appendingPathComponent(fileName)
            .path
    }
    
    private func findProjectFile(at relativePath: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        return projectRoot
            .appendingPathComponent(relativePath)
            .path
    }
}
