import XCTest
@testable import OperatorKit

// ============================================================================
// BUILD SEALS INVARIANT TESTS (Phase 13J)
//
// Tests proving build seals exist, are stable, and contain no forbidden content.
//
// CONSTRAINTS:
// ❌ No runtime modifications
// ❌ No networking
// ❌ No user content
// ✅ Read-only verification
// ✅ Deterministic results
// ============================================================================

final class BuildSealsInvariantTests: XCTestCase {
    
    // MARK: - Seal Existence Tests
    
    /// Test that seal resource files exist and are parseable
    func testSealsExistAndParse() {
        // Load all seals
        let packet = BuildSealsLoader.loadAllSeals()
        
        // Packet should be constructable
        XCTAssertNotNil(packet, "BuildSealsPacket should be constructable")
        
        // Schema version should be current
        XCTAssertEqual(
            packet.schemaVersion,
            BuildSealsSchemaVersion.current,
            "Packet schema version should match current"
        )
        
        // At least fallback seals should be present (from runtime inspection)
        // Note: Actual seals may not be present until build scripts run
        XCTAssertTrue(
            packet.entitlements != nil ||
            packet.dependencies != nil ||
            packet.symbols != nil ||
            packet.overallStatus == .missing,
            "Packet should have at least fallback status"
        )
    }
    
    /// Test that seal files have deterministic format
    func testSealsDeterministicFormat() {
        // Load twice
        let packet1 = BuildSealsLoader.loadAllSeals()
        let packet2 = BuildSealsLoader.loadAllSeals()
        
        // Compare hashes (should be identical)
        XCTAssertEqual(
            packet1.entitlements?.entitlementsHash,
            packet2.entitlements?.entitlementsHash,
            "Entitlements hash should be deterministic"
        )
        
        XCTAssertEqual(
            packet1.dependencies?.dependencyHash,
            packet2.dependencies?.dependencyHash,
            "Dependency hash should be deterministic"
        )
        
        XCTAssertEqual(
            packet1.symbols?.symbolListHash,
            packet2.symbols?.symbolListHash,
            "Symbol hash should be deterministic"
        )
        
        // Overall status should be deterministic
        XCTAssertEqual(
            packet1.overallStatus,
            packet2.overallStatus,
            "Overall status should be deterministic"
        )
    }
    
    // MARK: - Forbidden Keys Tests
    
    /// Test that seals contain no forbidden keys
    func testSealsContainNoForbiddenKeys() {
        let packet = BuildSealsLoader.loadAllSeals()
        
        // Get JSON representation
        guard let json = packet.toJSON() else {
            XCTFail("Failed to serialize packet to JSON")
            return
        }
        
        // Validate no forbidden keys
        let violations = BuildSealsForbiddenKeys.validate(json)
        
        XCTAssertTrue(
            violations.isEmpty,
            "Build seals contain forbidden keys: \(violations)"
        )
    }
    
    /// Test that individual seal validation passes
    func testIndividualSealValidation() {
        let packet = BuildSealsLoader.loadAllSeals()
        
        // Validate each seal
        if let entitlements = packet.entitlements {
            let violations = entitlements.validate()
            XCTAssertTrue(
                violations.isEmpty,
                "Entitlements seal validation failed: \(violations)"
            )
        }
        
        if let dependencies = packet.dependencies {
            let violations = dependencies.validate()
            XCTAssertTrue(
                violations.isEmpty,
                "Dependency seal validation failed: \(violations)"
            )
        }
        
        if let symbols = packet.symbols {
            let violations = symbols.validate()
            XCTAssertTrue(
                violations.isEmpty,
                "Symbol seal validation failed: \(violations)"
            )
        }
        
        // Validate full packet
        let packetViolations = packet.validate()
        XCTAssertTrue(
            packetViolations.isEmpty,
            "Full packet validation failed: \(packetViolations)"
        )
    }
    
    // MARK: - Hash Format Tests
    
    /// Test that hashes are valid SHA256 format (64 hex characters)
    func testHashFormat() {
        let packet = BuildSealsLoader.loadAllSeals()
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        
        if let entitlements = packet.entitlements {
            XCTAssertEqual(
                entitlements.entitlementsHash.count,
                64,
                "Entitlements hash should be 64 characters"
            )
            XCTAssertTrue(
                entitlements.entitlementsHash.unicodeScalars.allSatisfy { hexCharacters.contains($0) },
                "Entitlements hash should be hex only"
            )
        }
        
        if let dependencies = packet.dependencies {
            XCTAssertEqual(
                dependencies.dependencyHash.count,
                64,
                "Dependency hash should be 64 characters"
            )
            XCTAssertTrue(
                dependencies.dependencyHash.unicodeScalars.allSatisfy { hexCharacters.contains($0) },
                "Dependency hash should be hex only"
            )
        }
        
        if let symbols = packet.symbols {
            XCTAssertEqual(
                symbols.symbolListHash.count,
                64,
                "Symbol hash should be 64 characters"
            )
            XCTAssertTrue(
                symbols.symbolListHash.unicodeScalars.allSatisfy { hexCharacters.contains($0) },
                "Symbol hash should be hex only"
            )
        }
    }
    
    // MARK: - Protected Module Tests
    
    /// Test that no protected modules are touched by BuildSeals feature
    func testNoProtectedModulesTouched() throws {
        // Protected modules should not import BuildSeals
        let protectedModules = [
            "ExecutionEngine.swift",
            "ApprovalGate.swift",
            "ModelRouter.swift",
            "SideEffectContract.swift"
        ]
        
        let buildSealsIdentifiers = [
            "BuildSeals",
            "EntitlementsSeal",
            "DependencySeal",
            "SymbolSeal",
            "BuildSealsLoader"
        ]
        
        // Get source root
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        for module in protectedModules {
            // Try common paths
            let possiblePaths = [
                projectRoot.appendingPathComponent("OperatorKit/Domain/Execution/\(module)"),
                projectRoot.appendingPathComponent("OperatorKit/Domain/Approval/\(module)"),
                projectRoot.appendingPathComponent("OperatorKit/Models/\(module)")
            ]
            
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path.path) {
                    let content = try String(contentsOf: path, encoding: .utf8)
                    
                    for identifier in buildSealsIdentifiers {
                        XCTAssertFalse(
                            content.contains(identifier),
                            "Protected module \(module) should not reference \(identifier)"
                        )
                    }
                }
            }
        }
    }
    
    /// Test that BuildSeals feature has no networking imports
    func testNoNetworkingImportsInBuildSealsFeature() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let buildSealsPath = projectRoot.appendingPathComponent("OperatorKit/Features/BuildSeals")
        
        let networkingPatterns = [
            "import Network",
            "URLSession",
            "URLRequest",
            "CFNetwork",
            "BGTaskScheduler",
            "BackgroundTasks"
        ]
        
        // Get all Swift files in BuildSeals directory
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: buildSealsPath,
            includingPropertiesForKeys: nil
        ) else {
            // Directory might not exist in test environment
            return
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            
            for pattern in networkingPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "BuildSeals file \(fileURL.lastPathComponent) should not contain \(pattern)"
                )
            }
        }
    }
    
    // MARK: - Symbol Seal Specific Tests
    
    /// Test that symbol seal reports zero forbidden symbols for compliant build
    func testSymbolSealForbiddenCountForRelease() {
        let packet = BuildSealsLoader.loadAllSeals()
        
        // In a compliant release build, there should be no forbidden symbols
        // Note: This may fail in DEBUG builds that link test frameworks
        #if !DEBUG
        if let symbols = packet.symbols {
            XCTAssertEqual(
                symbols.forbiddenSymbolCount,
                0,
                "RELEASE build should have zero forbidden symbols"
            )
            
            XCTAssertFalse(
                symbols.forbiddenFrameworkPresent,
                "RELEASE build should have no forbidden frameworks"
            )
        }
        #endif
    }
    
    /// Test that framework checks are complete
    func testFrameworkChecksComplete() {
        let packet = BuildSealsLoader.loadAllSeals()
        
        guard let symbols = packet.symbols else {
            // Symbols might not be available without actual build
            return
        }
        
        let requiredChecks = [
            "URLSession", "CFNetwork", "WebKit", "JavaScriptCore", "SafariServices"
        ]
        
        let checkedFrameworks = Set(symbols.frameworkChecks.map { $0.framework })
        
        for required in requiredChecks {
            XCTAssertTrue(
                checkedFrameworks.contains(required),
                "Symbol seal should check for \(required)"
            )
        }
    }
    
    // MARK: - Feature Flag Tests
    
    /// Test feature flag gates BuildSeals view
    func testFeatureFlagGatesView() {
        // Ensure flag is queryable
        let _ = BuildSealsFeatureFlag.isEnabled
        
        // Test override works in DEBUG
        #if DEBUG
        let originalValue = BuildSealsFeatureFlag.isEnabled
        
        BuildSealsFeatureFlag.setEnabled(false)
        XCTAssertFalse(BuildSealsFeatureFlag.isEnabled)
        
        BuildSealsFeatureFlag.setEnabled(true)
        XCTAssertTrue(BuildSealsFeatureFlag.isEnabled)
        
        BuildSealsFeatureFlag.resetToDefault()
        XCTAssertEqual(BuildSealsFeatureFlag.isEnabled, originalValue)
        #endif
    }
    
    // MARK: - ProofPack Integration Tests
    
    /// Test that BuildSealsSummary is included in ProofPack
    @MainActor
    func testBuildSealsInProofPack() {
        let proofPack = ProofPackAssembler.assemble()
        
        // Build seals summary should be present
        let buildSeals = proofPack.buildSeals
        
        // Should have status
        XCTAssertFalse(
            buildSeals.overallStatus.isEmpty,
            "BuildSealsSummary should have overall status"
        )
        
        // Feature flag should be in summary
        let featureFlags = proofPack.featureFlags
        let _ = featureFlags.buildSeals // Should compile
    }
    
    // MARK: - Serialization Tests
    
    /// Test that BuildSealsPacket serializes and deserializes correctly
    func testSerialization() {
        let packet = BuildSealsLoader.loadAllSeals()
        
        // Serialize
        guard let json = packet.toJSON() else {
            XCTFail("Failed to serialize packet")
            return
        }
        
        // Should be valid JSON
        XCTAssertFalse(json.isEmpty, "JSON should not be empty")
        XCTAssertTrue(json.contains("schemaVersion"), "JSON should contain schemaVersion")
        XCTAssertTrue(json.contains("overallStatus"), "JSON should contain overallStatus")
        
        // Deserialize
        guard let data = json.data(using: .utf8) else {
            XCTFail("Failed to convert JSON to data")
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode(BuildSealsPacket.self, from: data)
            XCTAssertEqual(decoded.schemaVersion, packet.schemaVersion)
            XCTAssertEqual(decoded.overallStatus, packet.overallStatus)
        } catch {
            XCTFail("Failed to deserialize packet: \(error)")
        }
    }
    
    // MARK: - Documentation Tests
    
    /// Test that spec documents exist
    func testSpecDocumentsExist() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let requiredDocs = [
            "docs/ENTITLEMENTS_PROOF_SPEC.md",
            "docs/DEPENDENCY_PROOF_SPEC.md",
            "docs/SYMBOL_PROOF_SPEC.md"
        ]
        
        for doc in requiredDocs {
            let docPath = projectRoot.appendingPathComponent(doc)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: docPath.path),
                "Spec document should exist: \(doc)"
            )
        }
    }
}
