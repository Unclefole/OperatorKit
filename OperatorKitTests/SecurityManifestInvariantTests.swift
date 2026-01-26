import XCTest
@testable import OperatorKit

// ============================================================================
// SECURITY MANIFEST INVARIANT TESTS (Phase 13F)
//
// Tests proving OperatorKit is:
// - WebKit-Free
// - JavaScript-Free
// - No Embedded Browsers
// - No Remote Code Execution
//
// These tests fail loudly if any violation occurs.
//
// See: docs/SECURITY_MANIFEST.md
// ============================================================================

final class SecurityManifestInvariantTests: XCTestCase {
    
    // MARK: - Test 1: No WebKit Import
    
    func testNoWebKitImport() throws {
        let violations = try scanAllSwiftFiles(for: "import WebKit")
        XCTAssertTrue(
            violations.isEmpty,
            "WebKit import found in: \(violations.joined(separator: ", "))"
        )
    }
    
    // MARK: - Test 2: No JavaScriptCore Import
    
    func testNoJavaScriptCoreImport() throws {
        let violations = try scanAllSwiftFiles(for: "import JavaScriptCore")
        XCTAssertTrue(
            violations.isEmpty,
            "JavaScriptCore import found in: \(violations.joined(separator: ", "))"
        )
    }
    
    // MARK: - Test 3: No WKWebView Usage
    
    func testNoWKWebViewUsage() throws {
        let violations = try scanAllSwiftFiles(for: "WKWebView")
        XCTAssertTrue(
            violations.isEmpty,
            "WKWebView found in: \(violations.joined(separator: ", "))"
        )
    }
    
    // MARK: - Test 4: No JSContext Usage
    
    func testNoJSContextUsage() throws {
        let violations = try scanAllSwiftFiles(for: "JSContext")
        XCTAssertTrue(
            violations.isEmpty,
            "JSContext found in: \(violations.joined(separator: ", "))"
        )
    }
    
    // MARK: - Test 5: No SFSafariViewController Usage
    
    func testNoSFSafariViewControllerUsage() throws {
        let violations = try scanAllSwiftFiles(for: "SFSafariViewController")
        XCTAssertTrue(
            violations.isEmpty,
            "SFSafariViewController found in: \(violations.joined(separator: ", "))"
        )
    }
    
    // MARK: - Test 6: No JSValue Usage
    
    func testNoJSValueUsage() throws {
        let violations = try scanAllSwiftFiles(for: "JSValue")
        XCTAssertTrue(
            violations.isEmpty,
            "JSValue found in: \(violations.joined(separator: ", "))"
        )
    }
    
    // MARK: - Test 7: Security Manifest View Is Read-Only
    
    func testSecurityManifestViewIsReadOnly() throws {
        let viewPath = findProjectFile(at: "OperatorKit/Features/SecurityManifest/SecurityManifestView.swift")
        let content = try String(contentsOfFile: viewPath, encoding: .utf8)
        
        // Should not have buttons with actions (except navigation)
        let actionIndicators = [
            "Button(action:",
            "Toggle(",
            "Slider(",
            "TextField(",
            "TextEditor(",
            ".onTapGesture"
        ]
        
        for indicator in actionIndicators {
            XCTAssertFalse(
                content.contains(indicator),
                "SecurityManifestView should be read-only, found: \(indicator)"
            )
        }
    }
    
    // MARK: - Test 8: Feature Flag Gates Access
    
    func testFeatureFlagGatesAccess() throws {
        let viewPath = findProjectFile(at: "OperatorKit/Features/SecurityManifest/SecurityManifestView.swift")
        let content = try String(contentsOfFile: viewPath, encoding: .utf8)
        
        XCTAssertTrue(
            content.contains("SecurityManifestFeatureFlag.isEnabled"),
            "SecurityManifestView must check feature flag"
        )
    }
    
    // MARK: - Test 9: No Network APIs in Security Manifest
    
    func testNoNetworkAPIsInSecurityManifest() throws {
        let files = [
            "SecurityManifestFeatureFlag.swift",
            "SecurityManifestView.swift"
        ]
        
        for fileName in files {
            let filePath = findProjectFile(at: "OperatorKit/Features/SecurityManifest/\(fileName)")
            
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
    
    // MARK: - Test 10: No Sealed Artifact Hashes Changed
    
    func testNoSealedArtifactHashesChanged() {
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
    
    // MARK: - Test 11: Core Execution Modules Untouched
    
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
                content.contains("Phase 13F"),
                "\(fileName) should not contain Phase 13F references"
            )
            
            XCTAssertFalse(
                content.contains("SecurityManifest"),
                "\(fileName) should not import SecurityManifest"
            )
        }
    }
    
    // MARK: - Test 12: Security Manifest Doc Exists
    
    func testSecurityManifestDocExists() throws {
        let docPath = findDocFile(named: "SECURITY_MANIFEST.md")
        let content = try String(contentsOfFile: docPath, encoding: .utf8)
        
        // Verify required claims are documented
        XCTAssertTrue(content.contains("100% WebKit-Free"), "Doc must claim WebKit-Free")
        XCTAssertTrue(content.contains("0% JavaScript"), "Doc must claim JavaScript-Free")
        XCTAssertTrue(content.contains("No Embedded Browsers"), "Doc must claim no browsers")
        XCTAssertTrue(content.contains("No Remote Code Execution"), "Doc must claim no RCE")
        
        // Verify disclaimers are present
        XCTAssertTrue(content.contains("What This Does NOT Mean"), "Doc must include disclaimers")
        XCTAssertTrue(content.contains("not a marketing"), "Doc must clarify not marketing")
    }
    
    // MARK: - Helpers
    
    private func scanAllSwiftFiles(for pattern: String) throws -> [String] {
        var violations: [String] = []
        let projectRoot = findProjectRoot()
        let operatorKitPath = projectRoot.appendingPathComponent("OperatorKit")
        
        let enumerator = FileManager.default.enumerator(
            at: operatorKitPath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            
            // Skip test files - we're checking production code
            guard !fileURL.path.contains("Tests") else { continue }
            
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            if content.contains(pattern) {
                violations.append(fileURL.lastPathComponent)
            }
        }
        
        return violations
    }
    
    private func findProjectRoot() -> URL {
        let currentFile = URL(fileURLWithPath: #file)
        return currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
    
    private func findProjectFile(at relativePath: String) -> String {
        findProjectRoot()
            .appendingPathComponent(relativePath)
            .path
    }
    
    private func findDocFile(named name: String) -> String {
        findProjectRoot()
            .appendingPathComponent("docs")
            .appendingPathComponent(name)
            .path
    }
}
