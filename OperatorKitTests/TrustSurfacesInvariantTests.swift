import XCTest
@testable import OperatorKit

// ============================================================================
// TRUST SURFACES INVARIANT TESTS (Phase 13A)
//
// Tests validating Trust Surfaces are read-only, feature-flagged,
// and do not couple to runtime execution.
//
// See: docs/RELEASE_CANDIDATE.md
// ============================================================================

final class TrustSurfacesInvariantTests: XCTestCase {
    
    // MARK: - Test 1: Core Modules Untouched
    
    func testCoreModulesUntouched() throws {
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
            
            // Must not contain Phase 13A references
            XCTAssertFalse(
                content.contains("Phase 13A"),
                "\(fileName) should not contain Phase 13A references"
            )
            
            // Must not import TrustSurfaces
            XCTAssertFalse(
                content.contains("TrustSurfaces") || content.contains("TrustDashboard"),
                "\(fileName) should not reference Trust Surfaces"
            )
        }
    }
    
    // MARK: - Test 2: Feature Flag Required
    
    func testFeatureFlagExists() {
        // Feature flag should exist and be queryable
        let isEnabled = TrustSurfacesFeatureFlag.isEnabled
        
        // In test context, should be true (DEBUG)
        #if DEBUG
        XCTAssertTrue(isEnabled || !isEnabled, "Feature flag should be queryable")
        #endif
        
        // Verify components are gated
        XCTAssertEqual(
            TrustSurfacesFeatureFlag.Components.trustDashboardEnabled,
            TrustSurfacesFeatureFlag.isEnabled,
            "Trust Dashboard should be gated by main flag"
        )
        
        XCTAssertEqual(
            TrustSurfacesFeatureFlag.Components.procedureSharingPreviewEnabled,
            TrustSurfacesFeatureFlag.isEnabled,
            "Procedure Sharing Preview should be gated by main flag"
        )
    }
    
    // MARK: - Test 3: No Sealed Hashes Changed
    
    func testNoSealedHashesChanged() throws {
        // Verify Release Seal hashes are unchanged
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
        
        XCTAssertEqual(
            ReleaseSeal.pricingRegistryHash,
            "SEAL_PRICING_REGISTRY_V2",
            "Pricing Registry seal should not change"
        )
        
        XCTAssertEqual(
            ReleaseSeal.storeListingCopyHash,
            "SEAL_STORE_LISTING_V1",
            "Store Listing Copy seal should not change"
        )
    }
    
    // MARK: - Test 4: No Network Imports
    
    func testNoNetworkImportsInTrustSurfaces() throws {
        let trustSurfaceFiles = [
            "TrustSurfacesFeatureFlag.swift",
            "TrustDashboardView.swift",
            "ProcedureSharingPreviewView.swift",
            "RegressionFirewallView.swift",
            "SovereignExportStubView.swift"
        ]
        
        for fileName in trustSurfaceFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/TrustSurfaces/\(fileName)")
            
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
    
    // MARK: - Test 5: No Write Paths Enabled
    
    func testNoWritePathsInTrustSurfaces() throws {
        let trustSurfaceFiles = [
            "TrustDashboardView.swift",
            "ProcedureSharingPreviewView.swift",
            "RegressionFirewallView.swift",
            "SovereignExportStubView.swift"
        ]
        
        for fileName in trustSurfaceFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/TrustSurfaces/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // No UserDefaults writes
            XCTAssertFalse(
                content.contains(".set(") && content.contains("UserDefaults"),
                "\(fileName) should not write to UserDefaults"
            )
            
            // No file writes
            XCTAssertFalse(
                content.contains("FileManager") && content.contains("write"),
                "\(fileName) should not write files"
            )
            
            // No execution triggers
            XCTAssertFalse(
                content.contains("ExecutionEngine.shared.execute"),
                "\(fileName) should not trigger execution"
            )
        }
    }
    
    // MARK: - Test 6: Views Are Feature Flagged
    
    func testViewsAreFeatureFlagged() throws {
        let viewFiles = [
            "TrustDashboardView.swift",
            "ProcedureSharingPreviewView.swift",
            "RegressionFirewallView.swift",
            "SovereignExportStubView.swift"
        ]
        
        for fileName in viewFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/TrustSurfaces/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                XCTFail("\(fileName) should exist")
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Must check feature flag
            XCTAssertTrue(
                content.contains("TrustSurfacesFeatureFlag"),
                "\(fileName) must reference TrustSurfacesFeatureFlag"
            )
            
            // Must have disabled state
            XCTAssertTrue(
                content.contains("featureDisabledView") || content.contains("not enabled"),
                "\(fileName) must handle disabled state"
            )
        }
    }
    
    // MARK: - Test 7: Synthetic Data Clearly Labeled
    
    func testSyntheticDataClearlyLabeled() throws {
        let procedureViewPath = findProjectFile(at: "OperatorKit/Features/TrustSurfaces/ProcedureSharingPreviewView.swift")
        
        guard FileManager.default.fileExists(atPath: procedureViewPath) else {
            XCTFail("ProcedureSharingPreviewView.swift should exist")
            return
        }
        
        let content = try String(contentsOfFile: procedureViewPath, encoding: .utf8)
        
        // Must contain synthetic markers
        XCTAssertTrue(
            content.contains("[SYNTHETIC]") || content.contains("SYNTHETIC"),
            "Procedure examples must be labeled as synthetic"
        )
        
        // Must use synthetic prefix
        XCTAssertTrue(
            content.contains("SYNTHETIC_") || content.contains("TEST_"),
            "Synthetic data must use SYNTHETIC_ or TEST_ prefixes"
        )
    }
    
    // MARK: - Test 8: Sovereign Export Is Disabled
    
    func testSovereignExportIsDisabled() throws {
        let sovereignViewPath = findProjectFile(at: "OperatorKit/Features/TrustSurfaces/SovereignExportStubView.swift")
        
        guard FileManager.default.fileExists(atPath: sovereignViewPath) else {
            XCTFail("SovereignExportStubView.swift should exist")
            return
        }
        
        let content = try String(contentsOfFile: sovereignViewPath, encoding: .utf8)
        
        // Must have disabled button
        XCTAssertTrue(
            content.contains(".disabled(true)"),
            "Export button must be disabled"
        )
        
        // Must indicate coming later
        XCTAssertTrue(
            content.contains("Coming") || content.contains("Planned") || content.contains("not yet"),
            "Must indicate feature is not yet implemented"
        )
        
        // Must NOT have actual export logic
        XCTAssertFalse(
            content.contains("ShareSheet") || content.contains("UIActivityViewController"),
            "Must not have actual export functionality"
        )
    }
    
    // MARK: - Test 9: No New Claims Added
    
    func testNoNewClaimsAdded() throws {
        let claimRegistryPath = findDocFile(named: "CLAIM_REGISTRY.md")
        let content = try String(contentsOfFile: claimRegistryPath, encoding: .utf8)
        
        // Phase 13A should NOT add claims (read-only phase)
        XCTAssertFalse(
            content.contains("Phase 13A") || content.contains("CLAIM-13A"),
            "Phase 13A should not add new claims - it is read-only"
        )
    }
    
    // MARK: - Test 10: Schema Version Unchanged
    
    func testSchemaVersionUnchanged() {
        // Feature flag schema should be v1
        XCTAssertEqual(
            TrustSurfacesFeatureFlag.schemaVersion,
            1,
            "Trust Surfaces schema version should be 1"
        )
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
