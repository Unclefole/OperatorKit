import XCTest
@testable import OperatorKit

// ============================================================================
// OFFLINE CERTIFICATION INVARIANT TESTS (Phase 13I)
//
// Tests proving Offline Certification is:
// - Verification only (not enforcement)
// - No networking
// - No background tasks
// - No user content
// - Deterministic
// - Does not touch core modules
// - Does not break sealed artifacts
//
// See: Features/OfflineCertification/*, docs/OFFLINE_CERTIFICATION_SPEC.md
// ============================================================================

final class OfflineCertificationInvariantTests: XCTestCase {
    
    // MARK: - Test 1: No Networking Imports
    
    func testNoNetworkingImportsInOfflineCertification() throws {
        let certificationFiles = [
            "OfflineCertificationFeatureFlag.swift",
            "OfflineCertificationCheck.swift",
            "OfflineCertificationRunner.swift",
            "OfflineCertificationPacket.swift",
            "OfflineCertificationView.swift"
        ]
        
        for fileName in certificationFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/OfflineCertification/\(fileName)")
            
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
    
    // MARK: - Test 2: No Background APIs
    
    func testNoBackgroundAPIsInOfflineCertification() throws {
        let certificationFiles = [
            "OfflineCertificationRunner.swift",
            "OfflineCertificationView.swift"
        ]
        
        for fileName in certificationFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/OfflineCertification/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertFalse(
                content.contains("BGTaskScheduler"),
                "\(fileName) should not use BGTaskScheduler"
            )
            
            XCTAssertFalse(
                content.contains("BackgroundTask"),
                "\(fileName) should not use BackgroundTask"
            )
        }
    }
    
    // MARK: - Test 3: Feature Flag Gating
    
    func testFeatureFlagGatesAllEntryPoints() throws {
        let viewPath = findProjectFile(at: "OperatorKit/Features/OfflineCertification/OfflineCertificationView.swift")
        let content = try String(contentsOfFile: viewPath, encoding: .utf8)
        
        XCTAssertTrue(
            content.contains("OfflineCertificationFeatureFlag.isEnabled"),
            "OfflineCertificationView must check feature flag"
        )
        
        // Runner should also check
        let runnerPath = findProjectFile(at: "OperatorKit/Features/OfflineCertification/OfflineCertificationRunner.swift")
        let runnerContent = try String(contentsOfFile: runnerPath, encoding: .utf8)
        
        XCTAssertTrue(
            runnerContent.contains("OfflineCertificationFeatureFlag.isEnabled"),
            "OfflineCertificationRunner must check feature flag"
        )
    }
    
    // MARK: - Test 4: Determinism
    
    func testDeterministicResults() {
        let report1 = OfflineCertificationRunner.shared.runAllChecks()
        let report2 = OfflineCertificationRunner.shared.runAllChecks()
        
        XCTAssertEqual(report1.ruleCount, report2.ruleCount, "Rule count should be deterministic")
        XCTAssertEqual(report1.passedCount, report2.passedCount, "Passed count should be deterministic")
        XCTAssertEqual(report1.status, report2.status, "Status should be deterministic")
    }
    
    // MARK: - Test 5: No Sealed Hash Changes
    
    func testNoSealedHashChanges() {
        XCTAssertEqual(
            ReleaseSeal.terminologyCanonHash,
            "SEAL_TERMINOLOGY_CANON_V1",
            "Terminology Canon seal must remain intact"
        )
        
        XCTAssertEqual(
            ReleaseSeal.claimRegistryHash,
            "SEAL_CLAIM_REGISTRY_V25",
            "Claim Registry seal must remain intact"
        )
        
        XCTAssertEqual(
            ReleaseSeal.safetyContractHash,
            "SEAL_SAFETY_CONTRACT_V1",
            "Safety Contract seal must remain intact"
        )
        
        XCTAssertEqual(
            ReleaseSeal.pricingRegistryHash,
            "SEAL_PRICING_REGISTRY_V2",
            "Pricing Registry seal must remain intact"
        )
        
        XCTAssertEqual(
            ReleaseSeal.storeListingCopyHash,
            "SEAL_STORE_LISTING_V1",
            "Store Listing seal must remain intact"
        )
    }
    
    // MARK: - Test 6: No Forbidden Keys
    
    func testNoForbiddenKeysInPacket() {
        let report = OfflineCertificationRunner.shared.runAllChecks()
        let packet = OfflineCertificationPacket(from: report)
        
        let errors = packet.validate()
        XCTAssertTrue(
            errors.isEmpty,
            "Certification packet should contain no forbidden keys: \(errors)"
        )
    }
    
    // MARK: - Test 7: No Runtime Mutation
    
    func testNoRuntimeMutation() throws {
        let runnerPath = findProjectFile(at: "OperatorKit/Features/OfflineCertification/OfflineCertificationRunner.swift")
        let content = try String(contentsOfFile: runnerPath, encoding: .utf8)
        
        // Should not have mutation keywords in check logic
        XCTAssertFalse(
            content.contains("var ") && content.contains(" = ") && content.contains("mutating"),
            "Runner should not mutate state"
        )
        
        // Should not write files
        XCTAssertFalse(
            content.contains("write(to:"),
            "Runner should not write to disk"
        )
        
        XCTAssertFalse(
            content.contains("FileManager"),
            "Runner should not use FileManager"
        )
    }
    
    // MARK: - Test 8: No Core Module Imports
    
    func testNoCoreModuleImportsFromOfflineCertification() throws {
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
                content.contains("Phase 13I"),
                "\(fileName) should not contain Phase 13I references"
            )
            
            XCTAssertFalse(
                content.contains("OfflineCertification"),
                "\(fileName) should not import OfflineCertification"
            )
        }
    }
    
    // MARK: - Test 9: Spec Document Exists
    
    func testSpecDocumentExists() throws {
        let specPath = findDocFile(named: "OFFLINE_CERTIFICATION_SPEC.md")
        let content = try String(contentsOfFile: specPath, encoding: .utf8)
        
        XCTAssertTrue(content.contains("What Offline Certification IS"), "Spec must explain what it is")
        XCTAssertTrue(content.contains("What Offline Certification IS NOT"), "Spec must explain what it is not")
        XCTAssertTrue(content.contains("Certification, Not Enforcement") || content.contains("not enforcement"), "Spec must clarify not enforcement")
    }
    
    // MARK: - Test 10: Check Count Matches Expected
    
    func testCheckCountMatchesExpected() {
        let allChecks = OfflineCertificationChecks.all
        XCTAssertEqual(allChecks.count, 12, "Should have exactly 12 certification checks")
    }
    
    // MARK: - Test 11: All Categories Covered
    
    func testAllCategoriesCovered() {
        let allChecks = OfflineCertificationChecks.all
        let coveredCategories = Set(allChecks.map { $0.category })
        
        for category in OfflineCertificationCategory.allCases {
            XCTAssertTrue(
                coveredCategories.contains(category),
                "Category \(category.rawValue) should have at least one check"
            )
        }
    }
    
    // MARK: - Test 12: User-Initiated Only
    
    func testUserInitiatedOnly() throws {
        let viewPath = findProjectFile(at: "OperatorKit/Features/OfflineCertification/OfflineCertificationView.swift")
        let content = try String(contentsOfFile: viewPath, encoding: .utf8)
        
        // Should use ShareLink for export
        XCTAssertTrue(
            content.contains("ShareLink"),
            "OfflineCertificationView must use ShareLink for export"
        )
        
        // Should not auto-run on appear
        XCTAssertFalse(
            content.contains(".onAppear { run"),
            "OfflineCertificationView should not auto-run on appear"
        )
        
        // Should have explicit button
        XCTAssertTrue(
            content.contains("Verify Offline Status"),
            "View should have explicit verify button"
        )
    }
    
    // MARK: - Test 13: Serialization Round-Trip
    
    func testSerializationRoundTrip() throws {
        let report = OfflineCertificationRunner.shared.runAllChecks()
        let packet = OfflineCertificationPacket(from: report)
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(packet)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OfflineCertificationPacket.self, from: data)
        
        // Verify
        XCTAssertEqual(packet.ruleCount, decoded.ruleCount)
        XCTAssertEqual(packet.passedCount, decoded.passedCount)
        XCTAssertEqual(packet.overallStatus, decoded.overallStatus)
    }
    
    // MARK: - Helpers
    
    private func findProjectFile(at relativePath: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        return projectRoot
            .appendingPathComponent(relativePath)
            .path
    }
    
    private func findDocFile(named name: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        return projectRoot
            .appendingPathComponent("docs")
            .appendingPathComponent(name)
            .path
    }
}
