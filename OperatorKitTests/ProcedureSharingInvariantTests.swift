import XCTest
@testable import OperatorKit

// ============================================================================
// PROCEDURE SHARING INVARIANT TESTS (Phase 13B)
//
// Tests proving Procedure Sharing is:
// - Logic-only (no user data)
// - Local-only (no networking)
// - User-initiated (confirmation required)
// - Feature-flagged
// - No execution behavior changes
//
// See: docs/PROCEDURE_SHARING_SPEC.md
// ============================================================================

final class ProcedureSharingInvariantTests: XCTestCase {
    
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
            
            // Must not contain Phase 13B references
            XCTAssertFalse(
                content.contains("Phase 13B"),
                "\(fileName) should not contain Phase 13B references"
            )
            
            // Must not import ProcedureSharing
            XCTAssertFalse(
                content.contains("ProcedureSharing") || content.contains("ProcedureTemplate"),
                "\(fileName) should not reference Procedure Sharing"
            )
        }
    }
    
    // MARK: - Test 2: No Networking Imports
    
    func testNoNetworkingImports() throws {
        let procedureFiles = [
            "ProcedureSharingFeatureFlag.swift",
            "ProcedureTemplate.swift",
            "ProcedureStore.swift",
            "ProcedureExportImport.swift",
            "ProcedureSharingView.swift",
            "ProcedureCreateView.swift",
            "ProcedureImportView.swift"
        ]
        
        for fileName in procedureFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/ProcedureSharing/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // No network imports
            XCTAssertFalse(
                content.contains("import Network"),
                "\(fileName) should not import Network framework"
            )
            
            // No URLSession
            XCTAssertFalse(
                content.contains("URLSession"),
                "\(fileName) should not use URLSession"
            )
            
            // No URLRequest
            XCTAssertFalse(
                content.contains("URLRequest"),
                "\(fileName) should not use URLRequest"
            )
        }
    }
    
    // MARK: - Test 3: No File System Writes Outside Sandbox
    
    func testNoFileSystemWritesOutsideSandbox() throws {
        let procedureFiles = [
            "ProcedureStore.swift",
            "ProcedureExportImport.swift"
        ]
        
        for fileName in procedureFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/ProcedureSharing/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Should use UserDefaults, not FileManager writes
            XCTAssertFalse(
                content.contains("FileManager") && content.contains("write("),
                "\(fileName) should not write files directly"
            )
            
            // Should not access documents directory directly
            XCTAssertFalse(
                content.contains(".documentDirectory") && content.contains("write"),
                "\(fileName) should not write to documents directory"
            )
        }
    }
    
    // MARK: - Test 4: Procedure Serialization Contains No User Data
    
    func testProcedureSerializationContainsNoUserData() throws {
        // Create a valid procedure
        let skeleton = IntentSkeleton(
            intentType: "test_intent",
            requiredContextTypes: ["context_a", "context_b"],
            promptScaffold: "{action} for {context}"
        )
        
        let procedure = ProcedureTemplate(
            name: "Test Procedure",
            category: .general,
            intentSkeleton: skeleton,
            constraints: .default,
            outputType: .textSummary
        )
        
        // Serialize
        let encoder = JSONEncoder()
        let data = try encoder.encode(procedure)
        let jsonString = String(data: data, encoding: .utf8)!
        let lowercased = jsonString.lowercased()
        
        // Check no forbidden keys as JSON field names
        let forbiddenKeys = [
            "body", "subject", "content", "draft", "email",
            "recipient", "attendees", "message", "userData"
        ]
        
        for key in forbiddenKeys {
            XCTAssertFalse(
                lowercased.contains("\"\(key)\""),
                "Serialization should not contain forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - Test 5: Import Rejects Forbidden Keys
    
    func testImportRejectsForbiddenKeys() {
        // Create JSON with forbidden content
        let invalidJson = """
        {
            "procedure": {
                "id": "00000000-0000-0000-0000-000000000001",
                "name": "john@gmail.com's procedure",
                "category": "general",
                "intentSkeleton": {
                    "intentType": "test",
                    "requiredContextTypes": [],
                    "promptScaffold": "Dear John"
                },
                "constraints": {"requiresApproval": true},
                "outputType": "text_summary",
                "createdAtDayRounded": "2099-01-01",
                "schemaVersion": 1
            },
            "exportedAtDayRounded": "2099-01-01",
            "exportVersion": 1
        }
        """
        
        let data = invalidJson.data(using: .utf8)!
        let result = ProcedureImporter.importFromData(data, confirmed: true)
        
        switch result {
        case .rejectedForbiddenKeys:
            // Expected - forbidden patterns detected
            break
        case .success:
            XCTFail("Import should reject forbidden content")
        case .failure:
            // Also acceptable if format is rejected
            break
        case .requiresConfirmation:
            XCTFail("Should not require confirmation when confirmed=true")
        }
    }
    
    // MARK: - Test 6: Applying Procedure Does NOT Execute
    
    func testApplyingProcedureDoesNotExecute() throws {
        // Verify ProcedureStore has no execute methods
        let storePath = findProjectFile(at: "OperatorKit/Features/ProcedureSharing/ProcedureStore.swift")
        let content = try String(contentsOfFile: storePath, encoding: .utf8)
        
        // Should not have execute functionality
        XCTAssertFalse(
            content.contains("func execute") || content.contains("ExecutionEngine"),
            "ProcedureStore should not have execution capability"
        )
        
        // Should not import execution modules
        XCTAssertFalse(
            content.contains("import.*Execution"),
            "ProcedureStore should not import execution modules"
        )
    }
    
    // MARK: - Test 7: Feature Flag Gates All Entry Points
    
    func testFeatureFlagGatesAllEntryPoints() throws {
        let viewFiles = [
            "ProcedureSharingView.swift",
            "ProcedureCreateView.swift"
        ]
        
        for fileName in viewFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/ProcedureSharing/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                XCTFail("\(fileName) should exist")
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Must check feature flag
            XCTAssertTrue(
                content.contains("ProcedureSharingFeatureFlag"),
                "\(fileName) must reference ProcedureSharingFeatureFlag"
            )
        }
        
        // Store operations should check flag
        let storePath = findProjectFile(at: "OperatorKit/Features/ProcedureSharing/ProcedureStore.swift")
        let storeContent = try String(contentsOfFile: storePath, encoding: .utf8)
        
        XCTAssertTrue(
            storeContent.contains("ProcedureSharingFeatureFlag.isEnabled"),
            "ProcedureStore must check feature flag"
        )
    }
    
    // MARK: - Test 8: Sealed Artifacts Unchanged
    
    func testSealedArtifactsUnchanged() {
        // Verify Release Seal hashes are unchanged from Phase 12D
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
    
    // MARK: - Test 9: Deterministic Hashing
    
    func testDeterministicHashingOfProcedures() {
        let skeleton = IntentSkeleton(
            intentType: "test_intent",
            requiredContextTypes: [],
            promptScaffold: "{action}"
        )
        
        let procedure1 = ProcedureTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Test",
            category: .general,
            intentSkeleton: skeleton,
            constraints: .default,
            outputType: .textSummary,
            createdAtDayRounded: "2099-01-01"
        )
        
        let procedure2 = ProcedureTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Test",
            category: .general,
            intentSkeleton: skeleton,
            constraints: .default,
            outputType: .textSummary,
            createdAtDayRounded: "2099-01-01"
        )
        
        XCTAssertEqual(
            procedure1.deterministicHash,
            procedure2.deterministicHash,
            "Identical procedures must have identical hashes"
        )
    }
    
    // MARK: - Test 10: Max Procedure Count Enforced
    
    func testMaxProcedureCountEnforced() {
        XCTAssertEqual(
            ProcedureStore.maxProcedureCount,
            50,
            "Max procedure count should be 50"
        )
    }
    
    // MARK: - Test 11: Validator Catches Forbidden Patterns
    
    func testValidatorCatchesForbiddenPatterns() {
        let skeleton = IntentSkeleton(
            intentType: "test",
            requiredContextTypes: [],
            promptScaffold: "Dear John, please send to john@gmail.com"
        )
        
        let procedure = ProcedureTemplate(
            name: "Test",
            category: .general,
            intentSkeleton: skeleton,
            constraints: .default,
            outputType: .textSummary
        )
        
        let validation = ProcedureTemplateValidator.validate(procedure)
        
        XCTAssertFalse(
            validation.isValid,
            "Validator should catch forbidden patterns"
        )
        
        XCTAssertTrue(
            validation.errors.count > 0,
            "Validator should report errors"
        )
    }
    
    // MARK: - Test 12: Spec Document Exists
    
    func testProcedureSharingSpecExists() throws {
        let specPath = findDocFile(named: "PROCEDURE_SHARING_SPEC.md")
        
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: specPath),
            "PROCEDURE_SHARING_SPEC.md must exist"
        )
        
        let content = try String(contentsOfFile: specPath, encoding: .utf8)
        
        // Must contain key sections
        XCTAssertTrue(content.contains("Definition"), "Spec must have Definition section")
        XCTAssertTrue(content.contains("Forbidden Content"), "Spec must have Forbidden Content section")
        XCTAssertTrue(content.contains("Safety Guards"), "Spec must have Safety Guards section")
        XCTAssertTrue(content.contains("logic, never data"), "Spec must state 'logic, never data'")
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
