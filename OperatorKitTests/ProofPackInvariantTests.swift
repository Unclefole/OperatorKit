import XCTest
@testable import OperatorKit

// ============================================================================
// PROOF PACK INVARIANT TESTS (Phase 13H)
//
// Tests proving Proof Pack is:
// - Metadata-only (no user content)
// - Read-only aggregation (no side effects)
// - User-initiated export only
// - Deterministic
// - Does not touch core modules
// - Does not break sealed artifacts
//
// See: Features/ProofPack/*, docs/PROOF_PACK_SPEC.md
// ============================================================================

final class ProofPackInvariantTests: XCTestCase {
    
    // MARK: - Test 1: No Networking Imports in ProofPack
    
    func testNoNetworkingImportsInProofPack() throws {
        let proofPackFiles = [
            "ProofPackFeatureFlag.swift",
            "ProofPackModel.swift",
            "ProofPackAssembler.swift",
            "ProofPackView.swift"
        ]
        
        for fileName in proofPackFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/ProofPack/\(fileName)")
            
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
    
    func testNoBackgroundAPIsInProofPack() throws {
        let proofPackFiles = [
            "ProofPackAssembler.swift",
            "ProofPackView.swift"
        ]
        
        for fileName in proofPackFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/ProofPack/\(fileName)")
            
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
    
    // MARK: - Test 3: No Free-Text Fields in Models
    
    func testNoFreeTextFieldsInModels() throws {
        let modelPath = findProjectFile(at: "OperatorKit/Features/ProofPack/ProofPackModel.swift")
        let content = try String(contentsOfFile: modelPath, encoding: .utf8)
        
        // Should not have common free text property names
        let freeTextIndicators = [
            "var note:", "var notes:", "var description:", "var title:",
            "var text:", "var message:", "var body:", "var subject:",
            "var content:", "var draft:", "var prompt:", "var context:"
        ]
        
        for indicator in freeTextIndicators {
            XCTAssertFalse(
                content.contains(indicator),
                "ProofPackModel should not have free text field: \(indicator)"
            )
        }
    }
    
    // MARK: - Test 4: Proof Pack Contains Only Allowed Keys
    
    @MainActor
    func testProofPackContainsOnlyAllowedKeys() async {
        let pack = ProofPackAssembler.assemble()
        let errors = pack.validate()
        
        XCTAssertTrue(
            errors.isEmpty,
            "Proof Pack should contain no forbidden keys: \(errors)"
        )
    }
    
    // MARK: - Test 5: Deterministic Output Across Runs
    
    @MainActor
    func testDeterministicOutputAcrossRuns() async {
        let pack1 = ProofPackAssembler.assemble()
        let pack2 = ProofPackAssembler.assemble()
        
        // Core fields should be identical (excluding timestamp which is day-rounded)
        XCTAssertEqual(pack1.schemaVersion, pack2.schemaVersion)
        XCTAssertEqual(pack1.appVersion, pack2.appVersion)
        XCTAssertEqual(pack1.buildNumber, pack2.buildNumber)
        XCTAssertEqual(pack1.releaseSeals, pack2.releaseSeals)
        XCTAssertEqual(pack1.securityManifest, pack2.securityManifest)
        XCTAssertEqual(pack1.binaryProof, pack2.binaryProof)
        XCTAssertEqual(pack1.regressionFirewall.ruleCount, pack2.regressionFirewall.ruleCount)
        XCTAssertEqual(pack1.featureFlags, pack2.featureFlags)
    }
    
    // MARK: - Test 6: Export Is User-Initiated Only
    
    func testExportIsUserInitiatedOnly() throws {
        let viewPath = findProjectFile(at: "OperatorKit/Features/ProofPack/ProofPackView.swift")
        let content = try String(contentsOfFile: viewPath, encoding: .utf8)
        
        // Must use ShareLink for export
        XCTAssertTrue(
            content.contains("ShareLink"),
            "ProofPackView must use ShareLink for export"
        )
        
        // Should not auto-export on appear
        XCTAssertFalse(
            content.contains(".onAppear { export"),
            "ProofPackView should not auto-export on appear"
        )
        
        // Should not auto-assemble on appear
        XCTAssertFalse(
            content.contains(".onAppear { assemble"),
            "ProofPackView should not auto-assemble on appear"
        )
    }
    
    // MARK: - Test 7: Core Execution Modules Untouched
    
    func testCoreExecutionModulesUntouched() throws {
        let protectedFiles = [
            ("ExecutionEngine.swift", "OperatorKit/Domain/Execution"),
            ("ApprovalGate.swift", "OperatorKit/Domain/Approval"),
            ("ModelRouter.swift", "OperatorKit/Models"),
            ("SideEffectContract.swift", "OperatorKit/Domain/SideEffects")
        ]
        
        for (fileName, subdirectory) in protectedFiles {
            let filePath = findProjectFile(at: "\(subdirectory)/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertFalse(
                content.contains("Phase 13H"),
                "\(fileName) should not contain Phase 13H references"
            )
            
            XCTAssertFalse(
                content.contains("ProofPack"),
                "\(fileName) should not import ProofPack"
            )
        }
    }
    
    // MARK: - Test 8: All Release Seals Unchanged
    
    func testAllReleaseSealsUnchanged() {
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
    
    // MARK: - Test 9: Proof Pack Spec Exists
    
    func testProofPackSpecExists() throws {
        let specPath = findDocFile(named: "PROOF_PACK_SPEC.md")
        let content = try String(contentsOfFile: specPath, encoding: .utf8)
        
        // Verify required sections
        XCTAssertTrue(content.contains("What Proof Pack IS"), "Spec must explain what it is")
        XCTAssertTrue(content.contains("What Proof Pack IS NOT"), "Spec must explain what it is not")
        XCTAssertTrue(content.contains("Forbidden Content"), "Spec must list forbidden content")
        XCTAssertTrue(content.contains("not telemetry"), "Spec must clarify not telemetry")
    }
    
    // MARK: - Test 10: Feature Flag Gates All Entry Points
    
    func testFeatureFlagGatesAllEntryPoints() throws {
        let viewPath = findProjectFile(at: "OperatorKit/Features/ProofPack/ProofPackView.swift")
        let content = try String(contentsOfFile: viewPath, encoding: .utf8)
        
        XCTAssertTrue(
            content.contains("ProofPackFeatureFlag.isEnabled"),
            "ProofPackView must check feature flag"
        )
        
        // Trust Dashboard should also check flag
        let dashboardPath = findProjectFile(at: "OperatorKit/Features/TrustSurfaces/TrustDashboardView.swift")
        let dashboardContent = try String(contentsOfFile: dashboardPath, encoding: .utf8)
        
        XCTAssertTrue(
            dashboardContent.contains("ProofPackFeatureFlag.isEnabled"),
            "TrustDashboardView must check ProofPackFeatureFlag"
        )
    }
    
    // MARK: - Test 11: No File Writes Outside Export
    
    func testNoFileWritesOutsideExport() throws {
        let proofPackFiles = [
            "ProofPackAssembler.swift",
            "ProofPackModel.swift"
        ]
        
        for fileName in proofPackFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/ProofPack/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertFalse(
                content.contains("createFile("),
                "\(fileName) should not create files"
            )
            
            XCTAssertFalse(
                content.contains("write(to:"),
                "\(fileName) should not write to disk"
            )
            
            XCTAssertFalse(
                content.contains("FileManager"),
                "\(fileName) should not use FileManager"
            )
        }
    }
    
    // MARK: - Test 12: No Forbidden Content Patterns
    
    @MainActor
    func testNoForbiddenContentPatterns() async {
        let pack = ProofPackAssembler.assemble()
        
        guard let json = pack.toJSON() else {
            XCTFail("Failed to serialize Proof Pack")
            return
        }
        
        let lowercased = json.lowercased()
        
        // Check for common PII patterns
        let forbiddenPatterns = [
            "@gmail.com", "@yahoo.com", "@outlook.com",
            "users/", "/home/", "documents/",
            "device_", "user_id", "session_"
        ]
        
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                lowercased.contains(pattern),
                "Proof Pack should not contain pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - Test 13: Serialization Round-Trip
    
    @MainActor
    func testSerializationRoundTrip() async throws {
        let pack = ProofPackAssembler.assemble()
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(pack)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProofPack.self, from: data)
        
        // Verify
        XCTAssertEqual(pack.schemaVersion, decoded.schemaVersion)
        XCTAssertEqual(pack.appVersion, decoded.appVersion)
        XCTAssertEqual(pack.releaseSeals, decoded.releaseSeals)
        XCTAssertEqual(pack.securityManifest, decoded.securityManifest)
        XCTAssertEqual(pack.binaryProof, decoded.binaryProof)
        XCTAssertEqual(pack.featureFlags, decoded.featureFlags)
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
