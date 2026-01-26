import XCTest
@testable import OperatorKit

// ============================================================================
// BINARY PROOF INVARIANT TESTS (Phase 13G)
//
// Tests proving Binary Proof is:
// - Read-only inspection only
// - No networking
// - No background tasks
// - No user content
// - Deterministic
// - Does not touch core modules
// - Does not break sealed artifacts
//
// See: Features/BinaryProof/*, docs/BINARY_PROOF_SPEC.md
// ============================================================================

final class BinaryProofInvariantTests: XCTestCase {
    
    // MARK: - Test 1: Core Modules Untouched
    
    func testCoreModulesUntouched_NoPhase13GImports() throws {
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
                content.contains("Phase 13G"),
                "\(fileName) should not contain Phase 13G references"
            )
            
            XCTAssertFalse(
                content.contains("BinaryProof"),
                "\(fileName) should not import BinaryProof"
            )
            
            XCTAssertFalse(
                content.contains("BinaryImageInspector"),
                "\(fileName) should not import BinaryImageInspector"
            )
        }
    }
    
    // MARK: - Test 2: No URLSession/Network Imports
    
    func testNoURLSessionOrNetworkImportsInBinaryProof() throws {
        let binaryProofFiles = [
            "BinaryProofFeatureFlag.swift",
            "BinaryImageInspector.swift",
            "BinaryProofPacket.swift",
            "BinaryProofView.swift"
        ]
        
        for fileName in binaryProofFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/BinaryProof/\(fileName)")
            
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
    
    // MARK: - Test 3: No Background Task APIs
    
    func testNoBackgroundTaskAPIsInBinaryProof() throws {
        let binaryProofFiles = [
            "BinaryImageInspector.swift",
            "BinaryProofView.swift"
        ]
        
        for fileName in binaryProofFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/BinaryProof/\(fileName)")
            
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
    
    // MARK: - Test 4: Proof Packet Contains No Forbidden Keys
    
    func testProofPacketContainsNoForbiddenKeys() throws {
        // Create a mock inspection result
        let result = BinaryInspectionResult(
            status: .pass,
            linkedFrameworks: ["UIKit", "Foundation", "SwiftUI"],
            sensitiveChecks: [
                SensitiveFrameworkCheck(framework: "WebKit", isPresent: false),
                SensitiveFrameworkCheck(framework: "JavaScriptCore", isPresent: false)
            ],
            notes: ["No sensitive web frameworks detected"]
        )
        
        let packet = BinaryProofPacket(from: result)
        let errors = packet.validate()
        
        XCTAssertTrue(
            errors.isEmpty,
            "Proof packet should have no forbidden keys: \(errors)"
        )
    }
    
    // MARK: - Test 5: Determinism - Two Runs Produce Identical Results
    
    func testDeterminism_TwoRunsProduceIdenticalResults() {
        let result1 = BinaryImageInspector.inspect()
        let result2 = BinaryImageInspector.inspect()
        
        XCTAssertEqual(
            result1.linkedFrameworks,
            result2.linkedFrameworks,
            "Two inspection runs should produce identical framework lists"
        )
        
        XCTAssertEqual(
            result1.status,
            result2.status,
            "Two inspection runs should produce identical status"
        )
    }
    
    // MARK: - Test 6: Sensitive Checks Include Required Frameworks
    
    func testSensitiveChecksIncludeRequiredFrameworks() {
        let sensitiveFrameworks = BinaryImageInspector.sensitiveFrameworks
        
        XCTAssertTrue(
            sensitiveFrameworks.contains("WebKit"),
            "Sensitive frameworks must include WebKit"
        )
        
        XCTAssertTrue(
            sensitiveFrameworks.contains("JavaScriptCore"),
            "Sensitive frameworks must include JavaScriptCore"
        )
        
        XCTAssertTrue(
            sensitiveFrameworks.contains("SafariServices"),
            "Sensitive frameworks must include SafariServices"
        )
    }
    
    // MARK: - Test 7: Export Is User-Initiated Only (ShareSheet Used)
    
    func testExportIsUserInitiatedOnly() throws {
        let viewPath = findProjectFile(at: "OperatorKit/Features/BinaryProof/BinaryProofView.swift")
        let content = try String(contentsOfFile: viewPath, encoding: .utf8)
        
        // Must use ShareLink for export
        XCTAssertTrue(
            content.contains("ShareLink"),
            "BinaryProofView must use ShareLink for export"
        )
        
        // Should not auto-export on appear
        XCTAssertFalse(
            content.contains(".onAppear { export"),
            "BinaryProofView should not auto-export on appear"
        )
    }
    
    // MARK: - Test 8: Feature Flag Gates Entry Points
    
    func testFeatureFlagGatesEntryPoints() throws {
        let viewPath = findProjectFile(at: "OperatorKit/Features/BinaryProof/BinaryProofView.swift")
        let content = try String(contentsOfFile: viewPath, encoding: .utf8)
        
        XCTAssertTrue(
            content.contains("BinaryProofFeatureFlag.isEnabled"),
            "BinaryProofView must check feature flag"
        )
        
        // Trust Dashboard should also check flag
        let dashboardPath = findProjectFile(at: "OperatorKit/Features/TrustSurfaces/TrustDashboardView.swift")
        let dashboardContent = try String(contentsOfFile: dashboardPath, encoding: .utf8)
        
        XCTAssertTrue(
            dashboardContent.contains("BinaryProofFeatureFlag.isEnabled"),
            "TrustDashboardView must check BinaryProofFeatureFlag"
        )
    }
    
    // MARK: - Test 9: Sealed Artifacts Unchanged
    
    func testSealedArtifactsUnchanged() {
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
    
    // MARK: - Test 10: No Free Text Fields in Models
    
    func testNoFreeTextFieldsInModels() throws {
        let packetPath = findProjectFile(at: "OperatorKit/Features/BinaryProof/BinaryProofPacket.swift")
        let content = try String(contentsOfFile: packetPath, encoding: .utf8)
        
        // Should not have common free text property names
        let freeTextIndicators = [
            "var note:", "var description:", "var title:",
            "var text:", "var message:", "var body:", "var subject:",
            "var content:", "var draft:", "var prompt:"
        ]
        
        for indicator in freeTextIndicators {
            XCTAssertFalse(
                content.contains(indicator),
                "BinaryProofPacket should not have free text field: \(indicator)"
            )
        }
    }
    
    // MARK: - Test 11: App Store Safe Copy (No Banned Words)
    
    func testAppStoreSafeCopy() throws {
        let binaryProofFiles = [
            "BinaryProofView.swift",
            "BinaryProofPacket.swift"
        ]
        
        let bannedWords = ["guaranteed", "secure", "encrypted", "hack-proof", "unbreakable", "bulletproof"]
        
        for fileName in binaryProofFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/BinaryProof/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8).lowercased()
            
            for word in bannedWords {
                XCTAssertFalse(
                    content.contains(word),
                    "\(fileName) should not contain banned word: \(word)"
                )
            }
        }
    }
    
    // MARK: - Test 12: No File Writes (No FileManager Writes)
    
    func testNoFileWritesInBinaryProof() throws {
        let binaryProofFiles = [
            "BinaryImageInspector.swift",
            "BinaryProofPacket.swift",
            "BinaryProofView.swift"
        ]
        
        for fileName in binaryProofFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/BinaryProof/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Check for write operations
            XCTAssertFalse(
                content.contains("createFile("),
                "\(fileName) should not create files"
            )
            
            XCTAssertFalse(
                content.contains("write(to:"),
                "\(fileName) should not write to disk"
            )
            
            XCTAssertFalse(
                content.contains(".write("),
                "\(fileName) should not write to disk"
            )
        }
    }
    
    // MARK: - Test 13: Framework Names Are Sanitized (No Paths)
    
    func testFrameworkNamesAreSanitized() {
        let result = BinaryImageInspector.inspect()
        
        for framework in result.linkedFrameworks {
            XCTAssertFalse(
                framework.contains("/"),
                "Framework name should not contain path separator: \(framework)"
            )
            
            XCTAssertFalse(
                framework.hasPrefix("/"),
                "Framework name should not start with path: \(framework)"
            )
            
            XCTAssertFalse(
                framework.contains("Users"),
                "Framework name should not contain user directory: \(framework)"
            )
        }
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
}
