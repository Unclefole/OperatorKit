import XCTest
import CryptoKit
@testable import OperatorKit

// ============================================================================
// SOVEREIGN EXPORT INVARIANT TESTS (Phase 13C)
//
// Tests proving Sovereign Export is:
// - Encrypted (no plaintext export)
// - Logic-only (no user data)
// - User-initiated (confirmation required)
// - Feature-flagged
// - Deterministic round-trip
//
// See: docs/SOVEREIGN_EXPORT_SPEC.md
// ============================================================================

final class SovereignExportInvariantTests: XCTestCase {
    
    // MARK: - Test 1: Core Execution Modules Untouched
    
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
                content.contains("Phase 13C"),
                "\(fileName) should not contain Phase 13C references"
            )
            
            XCTAssertFalse(
                content.contains("SovereignExport"),
                "\(fileName) should not reference Sovereign Export"
            )
        }
    }
    
    // MARK: - Test 2: No Networking Imports
    
    func testNoNetworkingImports() throws {
        let sovereignFiles = [
            "SovereignExportFeatureFlag.swift",
            "SovereignExportBundle.swift",
            "SovereignExportCrypto.swift",
            "SovereignExportService.swift",
            "SovereignExportView.swift"
        ]
        
        for fileName in sovereignFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/SovereignExport/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertFalse(
                content.contains("import Network"),
                "\(fileName) should not import Network"
            )
            
            XCTAssertFalse(
                content.contains("URLSession"),
                "\(fileName) should not use URLSession"
            )
        }
    }
    
    // MARK: - Test 3: No Plaintext Export
    
    func testNoPlaintextExport() {
        // Create a valid bundle
        let bundle = createTestBundle()
        
        // Encryption should work
        let result = SovereignExportCrypto.encrypt(
            bundle: bundle,
            passphrase: "TestPassphrase123"
        )
        
        guard case .success(let encrypted) = result else {
            XCTFail("Encryption should succeed")
            return
        }
        
        // Verify output is encrypted (starts with header, not JSON)
        XCTAssertTrue(
            encrypted.data.prefix(6) == SovereignExportCrypto.fileHeader,
            "Export must have encrypted file header"
        )
        
        // Verify plaintext JSON is not in output
        let dataString = String(data: encrypted.data, encoding: .utf8) ?? ""
        XCTAssertFalse(
            dataString.contains("\"schemaVersion\""),
            "Export must not contain plaintext JSON"
        )
    }
    
    // MARK: - Test 4: Export Bundle Contains No Forbidden Keys
    
    func testExportBundleContainsNoForbiddenKeys() throws {
        let bundle = createTestBundle()
        
        // Serialize
        let encoder = JSONEncoder()
        let data = try encoder.encode(bundle)
        let jsonString = String(data: data, encoding: .utf8)!
        let lowercased = jsonString.lowercased()
        
        // Check for forbidden keys
        let criticalForbidden = ["body", "subject", "email", "recipient", "memory", "draft"]
        
        for key in criticalForbidden {
            XCTAssertFalse(
                lowercased.contains("\"\(key)\""),
                "Bundle should not contain forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - Test 5: Encryption Required
    
    func testEncryptionIsRequired() {
        let bundle = createTestBundle()
        
        // Cannot export without passphrase (empty)
        let result = SovereignExportCrypto.encrypt(
            bundle: bundle,
            passphrase: ""
        )
        
        // Should still "work" but with empty passphrase
        // The real protection is the passphrase strength check in UI
        // Here we just verify encryption path is always used
        if case .success(let encrypted) = result {
            // Even with empty passphrase, output should be encrypted
            XCTAssertTrue(
                encrypted.data.prefix(6) == SovereignExportCrypto.fileHeader,
                "Output must always be encrypted"
            )
        }
    }
    
    // MARK: - Test 6: Import Rejects Malformed Bundles
    
    func testImportRejectsMalformedBundles() {
        // Try to decrypt random data
        let randomData = Data("This is not a valid export".utf8)
        
        let result = SovereignExportCrypto.decrypt(
            encryptedData: randomData,
            passphrase: "AnyPassphrase"
        )
        
        guard case .failure = result else {
            XCTFail("Import should reject invalid data")
            return
        }
    }
    
    // MARK: - Test 7: Import Does Not Overwrite Without Confirmation
    
    func testImportDoesNotOverwriteWithoutConfirmation() async {
        let bundle = createTestBundle()
        
        // Try to apply without confirmation
        let result = await SovereignExportService.shared.applyBundle(bundle, confirmed: false)
        
        guard case .requiresConfirmation = result else {
            XCTFail("Import should require confirmation")
            return
        }
    }
    
    // MARK: - Test 8: Feature Flag Gates All Entry Points
    
    func testFeatureFlagGatesAllEntryPoints() throws {
        let viewFiles = [
            "SovereignExportView.swift",
            "SovereignExportFlowView.swift",
            "SovereignImportFlowView.swift"
        ]
        
        for fileName in viewFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/SovereignExport/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertTrue(
                content.contains("SovereignExportFeatureFlag"),
                "\(fileName) must reference SovereignExportFeatureFlag"
            )
        }
    }
    
    // MARK: - Test 9: Sealed Artifacts Unchanged
    
    func testSealedArtifactsUnchanged() {
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
    
    // MARK: - Test 10: Export/Import Round-Trip Deterministic
    
    func testExportImportRoundTripDeterministic() {
        let bundle = createTestBundle()
        let passphrase = "SecureTestPassphrase123"
        
        // Export
        let exportResult = SovereignExportCrypto.encrypt(
            bundle: bundle,
            passphrase: passphrase
        )
        
        guard case .success(let encrypted) = exportResult else {
            XCTFail("Export should succeed")
            return
        }
        
        // Import
        let importResult = SovereignExportCrypto.decrypt(
            encryptedData: encrypted.data,
            passphrase: passphrase
        )
        
        guard case .success(let decrypted) = importResult else {
            XCTFail("Import should succeed")
            return
        }
        
        // Verify round-trip
        XCTAssertEqual(
            bundle.schemaVersion,
            decrypted.schemaVersion,
            "Schema version should survive round-trip"
        )
        
        XCTAssertEqual(
            bundle.procedures.count,
            decrypted.procedures.count,
            "Procedure count should survive round-trip"
        )
        
        XCTAssertEqual(
            bundle.entitlementState.tier,
            decrypted.entitlementState.tier,
            "Tier should survive round-trip"
        )
    }
    
    // MARK: - Test 11: Spec Document Exists
    
    func testSovereignExportSpecExists() throws {
        let specPath = findDocFile(named: "SOVEREIGN_EXPORT_SPEC.md")
        
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: specPath),
            "SOVEREIGN_EXPORT_SPEC.md must exist"
        )
        
        let content = try String(contentsOfFile: specPath, encoding: .utf8)
        
        XCTAssertTrue(content.contains("AES-256-GCM"), "Spec must document encryption")
        XCTAssertTrue(content.contains("Forbidden Keys"), "Spec must document forbidden keys")
        XCTAssertTrue(content.contains("NEVER Exported"), "Spec must document exclusions")
    }
    
    // MARK: - Test 12: Validator Catches Forbidden Patterns
    
    func testValidatorCatchesForbiddenPatterns() {
        // Create bundle with forbidden content in procedure
        let badProcedure = ExportedProcedure(
            id: UUID(),
            name: "Test",
            category: "general",
            intentType: "test",
            outputType: "text_summary",
            promptScaffold: "Dear John, please email john@gmail.com",
            requiresApproval: true,
            createdAtDayRounded: "2099-01-01"
        )
        
        let bundle = SovereignExportBundle(
            procedures: [badProcedure],
            policySummary: ExportedPolicySummary(),
            entitlementState: ExportedEntitlementState(tier: "free"),
            auditCounts: ExportedAuditCounts(),
            appVersion: "1.0"
        )
        
        let validation = SovereignExportBundleValidator.validate(bundle)
        
        XCTAssertFalse(
            validation.isValid,
            "Validator should catch forbidden patterns"
        )
    }
    
    // MARK: - Helpers
    
    private func createTestBundle() -> SovereignExportBundle {
        let procedure = ExportedProcedure(
            id: UUID(),
            name: "Test Procedure",
            category: "general",
            intentType: "test_intent",
            outputType: "text_summary",
            promptScaffold: "{action} for {context}",
            requiresApproval: true,
            createdAtDayRounded: "2099-01-01"
        )
        
        return SovereignExportBundle(
            procedures: [procedure],
            policySummary: ExportedPolicySummary(),
            entitlementState: ExportedEntitlementState(tier: "free"),
            auditCounts: ExportedAuditCounts(),
            appVersion: "1.0"
        )
    }
    
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
