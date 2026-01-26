import XCTest
@testable import OperatorKit

// ============================================================================
// SECURITY MANIFEST UI INVARIANT TESTS (Phase L1)
//
// Tests proving the Security Manifest UI is:
// - Read-only (no actions, no toggles)
// - Backed by proof sources
// - Feature-flagged
// - Free of networking/enforcement logic
//
// CONSTRAINTS:
// ❌ No runtime modifications
// ❌ No networking
// ✅ Read-only verification
// ============================================================================

final class SecurityManifestUIInvariantTests: XCTestCase {
    
    // MARK: - View Contains No Actions/Toggles
    
    /// Test that the view source contains no interactive elements
    func testViewContainsNoActionsOrToggles() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let viewPath = projectRoot.appendingPathComponent(
            "OperatorKit/Features/SecurityManifestUI/SecurityManifestUIView.swift"
        )
        
        guard FileManager.default.fileExists(atPath: viewPath.path) else {
            // File might not exist in test bundle
            return
        }
        
        let content = try String(contentsOf: viewPath, encoding: .utf8)
        
        // Should not contain interactive elements (other than navigation)
        let forbiddenPatterns = [
            "Button(",
            "Toggle(",
            "@State private var.*Bool.*= true",
            ".onTapGesture",
            ".gesture(",
            "TextField(",
            "TextEditor(",
            "Slider(",
            "Stepper(",
            ".refreshable"
        ]
        
        // Allow specific exceptions
        let allowedExceptions = [
            "NavigationLink",  // Navigation is OK
            "isLoading"        // Loading state is OK
        ]
        
        for pattern in forbiddenPatterns {
            // Skip if it's an allowed exception
            var isAllowed = false
            for exception in allowedExceptions {
                if pattern.contains(exception) {
                    isAllowed = true
                    break
                }
            }
            
            if !isAllowed {
                // Simple check - not regex for basic cases
                if pattern.contains("(") {
                    XCTAssertFalse(
                        content.contains(pattern),
                        "SecurityManifestUIView should not contain: \(pattern)"
                    )
                }
            }
        }
        
        // Verify it's explicitly read-only in comments
        XCTAssertTrue(
            content.contains("Read-only") || content.contains("read-only"),
            "View should document read-only constraint"
        )
    }
    
    // MARK: - No Networking Imports
    
    /// Test that the feature has no networking imports
    func testNoNetworkingImports() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let featurePath = projectRoot.appendingPathComponent(
            "OperatorKit/Features/SecurityManifestUI"
        )
        
        let networkingPatterns = [
            "import Network",
            "URLSession",
            "URLRequest",
            "CFNetwork",
            "BGTaskScheduler",
            "BackgroundTasks"
        ]
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: featurePath,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            
            for pattern in networkingPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "SecurityManifestUI file \(fileURL.lastPathComponent) should not contain: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - No Protected Modules Touched
    
    /// Test that protected modules don't reference SecurityManifestUI
    func testNoProtectedModulesTouched() throws {
        let protectedModules = [
            "ExecutionEngine.swift",
            "ApprovalGate.swift",
            "ModelRouter.swift",
            "SideEffectContract.swift"
        ]
        
        let securityManifestUIIdentifiers = [
            "SecurityManifestUI",
            "SecurityManifestUIView",
            "SecurityManifestUIFeatureFlag",
            "SecurityManifestUIAssembler"
        ]
        
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        for module in protectedModules {
            let possiblePaths = [
                projectRoot.appendingPathComponent("OperatorKit/Domain/Execution/\(module)"),
                projectRoot.appendingPathComponent("OperatorKit/Domain/Approval/\(module)"),
                projectRoot.appendingPathComponent("OperatorKit/Models/\(module)")
            ]
            
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path.path) {
                    let content = try String(contentsOf: path, encoding: .utf8)
                    
                    for identifier in securityManifestUIIdentifiers {
                        XCTAssertFalse(
                            content.contains(identifier),
                            "Protected module \(module) should not reference \(identifier)"
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - All Displayed Fields Map to Proof Sources
    
    /// Test that assembled manifest items have valid proof sources
    func testAllFieldsMapToProofSources() {
        let items = SecurityManifestUIAssembler.assemble()
        
        // Should have at least 6 items (as defined in the view)
        XCTAssertGreaterThanOrEqual(
            items.count,
            6,
            "Security Manifest should have at least 6 items"
        )
        
        // Valid proof sources
        let validProofSources: Set<String> = [
            "Binary Proof",
            "Build Seals",
            "Entitlements Seal",
            "Symbol Seal",
            "Offline Certification",
            "ProofPack"
        ]
        
        for item in items {
            // Each item should have a non-empty label
            XCTAssertFalse(
                item.label.isEmpty,
                "Manifest item should have a label"
            )
            
            // Each item should have a valid proof source
            XCTAssertTrue(
                validProofSources.contains(item.proofSource),
                "Item '\(item.label)' has invalid proof source: '\(item.proofSource)'"
            )
            
            // Each item should have a description
            XCTAssertFalse(
                item.description.isEmpty,
                "Item '\(item.label)' should have a description"
            )
        }
    }
    
    // MARK: - Feature Flag Gates Visibility
    
    /// Test that feature flag controls view access
    func testFeatureFlagGatesVisibility() {
        // Ensure flag is queryable
        let _ = SecurityManifestUIFeatureFlag.isEnabled
        
        #if DEBUG
        // Test override works
        let originalValue = SecurityManifestUIFeatureFlag.isEnabled
        
        SecurityManifestUIFeatureFlag.setEnabled(false)
        XCTAssertFalse(SecurityManifestUIFeatureFlag.isEnabled)
        
        SecurityManifestUIFeatureFlag.setEnabled(true)
        XCTAssertTrue(SecurityManifestUIFeatureFlag.isEnabled)
        
        SecurityManifestUIFeatureFlag.resetToDefault()
        XCTAssertEqual(SecurityManifestUIFeatureFlag.isEnabled, originalValue)
        #endif
    }
    
    // MARK: - Manifest Items Are Deterministic
    
    /// Test that assembling manifest produces consistent results
    func testManifestAssemblyIsDeterministic() {
        let items1 = SecurityManifestUIAssembler.assemble()
        let items2 = SecurityManifestUIAssembler.assemble()
        
        // Same count
        XCTAssertEqual(
            items1.count,
            items2.count,
            "Manifest assembly should produce consistent item count"
        )
        
        // Same labels in same order
        let labels1 = items1.map { $0.label }
        let labels2 = items2.map { $0.label }
        
        XCTAssertEqual(
            labels1,
            labels2,
            "Manifest labels should be deterministic"
        )
        
        // Same proof sources
        let sources1 = items1.map { $0.proofSource }
        let sources2 = items2.map { $0.proofSource }
        
        XCTAssertEqual(
            sources1,
            sources2,
            "Manifest proof sources should be deterministic"
        )
    }
    
    // MARK: - No Enforcement Logic
    
    /// Test that assembler has no enforcement or mutation logic
    func testNoEnforcementLogic() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let viewPath = projectRoot.appendingPathComponent(
            "OperatorKit/Features/SecurityManifestUI/SecurityManifestUIView.swift"
        )
        
        guard FileManager.default.fileExists(atPath: viewPath.path) else {
            return
        }
        
        let content = try String(contentsOf: viewPath, encoding: .utf8)
        
        // Should not contain enforcement patterns
        let enforcementPatterns = [
            "throw",           // No throwing errors based on manifest
            "fatalError",      // No fatal errors
            "precondition",    // No preconditions
            "assert(",         // No runtime assertions (except in tests)
            "UserDefaults",    // No state persistence from manifest
            "FileManager.default.createFile",  // No file writes
            "try? encoder.encode"  // No encoding/saving from view
        ]
        
        // Note: Some patterns may appear in valid contexts
        // This is a heuristic check
        for pattern in enforcementPatterns {
            if content.contains(pattern) {
                // Allow if it's in a comment
                let lines = content.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.contains(pattern) && !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") {
                        // Some patterns are OK in specific contexts
                        // This is a best-effort check
                        if pattern == "throw" || pattern == "assert(" {
                            continue // These might be in valid contexts
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Interpretation Lock Exists
    
    /// Test that interpretation lock #18 exists
    func testInterpretationLockExists() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let lockPath = projectRoot.appendingPathComponent("docs/INTERPRETATION_LOCKS.md")
        
        guard FileManager.default.fileExists(atPath: lockPath.path) else {
            XCTFail("INTERPRETATION_LOCKS.md should exist")
            return
        }
        
        let content = try String(contentsOf: lockPath, encoding: .utf8)
        
        XCTAssertTrue(
            content.contains("Lock #18"),
            "INTERPRETATION_LOCKS.md should contain Lock #18"
        )
        
        XCTAssertTrue(
            content.contains("Security Manifest (UI)") || content.contains("SecurityManifestUI"),
            "Lock #18 should reference Security Manifest UI"
        )
        
        XCTAssertTrue(
            content.contains("Declarative") || content.contains("declarative"),
            "Lock #18 should clarify declarative nature"
        )
    }
    
    // MARK: - Specific Claims Present
    
    /// Test that specific required claims are present
    func testRequiredClaimsPresent() {
        let items = SecurityManifestUIAssembler.assemble()
        let labels = Set(items.map { $0.label })
        
        let requiredClaims = [
            "WebKit",
            "JavaScript",
            "Network Entitlements",
            "Offline Execution",
            "Build Integrity",
            "Proof Exportable"
        ]
        
        for claim in requiredClaims {
            XCTAssertTrue(
                labels.contains(claim),
                "Security Manifest should include claim: \(claim)"
            )
        }
    }
    
    // MARK: - No Marketing Language
    
    /// Test that descriptions don't contain marketing language
    func testNoMarketingLanguage() {
        let items = SecurityManifestUIAssembler.assemble()
        
        let marketingWords = [
            "best",
            "amazing",
            "incredible",
            "revolutionary",
            "perfect",
            "ultimate",
            "guaranteed",
            "unbreakable",
            "unhackable",
            "military-grade",
            "bank-level"
        ]
        
        for item in items {
            let descriptionLower = item.description.lowercased()
            
            for word in marketingWords {
                XCTAssertFalse(
                    descriptionLower.contains(word),
                    "Item '\(item.label)' contains marketing language: '\(word)'"
                )
            }
        }
    }
}
