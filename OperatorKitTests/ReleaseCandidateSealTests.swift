import XCTest
@testable import OperatorKit

// ============================================================================
// RELEASE CANDIDATE SEAL TESTS (Phase 12D)
//
// Tests that verify Release Candidate seals are intact.
// These tests MUST FAIL if any sealed artifact changes.
//
// TESTS IN THIS FILE:
// 1. testReleaseCandidateDocumentExists
// 2. testTestScopeManifestExists
// 3. testSyntheticFixturesContainNoForbiddenPatterns
// 4. testSyntheticFixturesAreDeterministic
// 5. testNoRuntimeFilesModifiedAfter12D
// 6. testTerminologyCanonHashLocked
// 7. testPricingRegistryHashLocked
// 8. testClaimRegistryHashLocked
// 9. testSafetyContractHashLocked
// 10. testStoreListingCopyHashLocked
// 11. testNoNetworkImportsInSyntheticHarness
// 12. testNoUserDataMarkersInSyntheticFixtures
// ============================================================================

final class ReleaseCandidateSealTests: XCTestCase {
    
    // MARK: - Test 1: Release Candidate Document Exists
    
    func testReleaseCandidateDocumentExists() throws {
        let rcPath = findDocFile(named: "RELEASE_CANDIDATE.md")
        
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: rcPath),
            "RELEASE_CANDIDATE.md must exist"
        )
        
        let content = try String(contentsOfFile: rcPath, encoding: .utf8)
        XCTAssertFalse(content.isEmpty, "RELEASE_CANDIDATE.md must not be empty")
        
        // Verify key sections
        XCTAssertTrue(content.contains("RC Declaration"), "Must have RC Declaration section")
        XCTAssertTrue(content.contains("Frozen Artifacts"), "Must have Frozen Artifacts section")
        XCTAssertTrue(content.contains("Allowed Changes"), "Must have Allowed Changes section")
        XCTAssertTrue(content.contains("Forbidden Changes"), "Must have Forbidden Changes section")
    }
    
    // MARK: - Test 2: Test Scope Manifest Exists
    
    func testTestScopeManifestExists() throws {
        let manifestPath = findTestingFile(named: "TestScopeManifest.md")
        
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: manifestPath),
            "TestScopeManifest.md must exist"
        )
        
        let content = try String(contentsOfFile: manifestPath, encoding: .utf8)
        XCTAssertFalse(content.isEmpty, "TestScopeManifest.md must not be empty")
        
        // Verify key sections
        XCTAssertTrue(content.contains("Allowed Test Categories"), "Must list allowed test categories")
        XCTAssertTrue(content.contains("Forbidden Test Categories"), "Must list forbidden test categories")
        XCTAssertTrue(content.contains("Synthetic Data Requirements"), "Must specify synthetic data requirements")
    }
    
    // MARK: - Test 3: Synthetic Fixtures Contain No Forbidden Patterns
    
    func testSyntheticFixturesContainNoForbiddenPatterns() throws {
        // Generate all fixture types
        let draftedOutcomes = SyntheticFixtures.draftedOutcomes(count: 10)
        let policyDecisions = SyntheticFixtures.policyDecisions(count: 10)
        let auditEvents = SyntheticFixtures.auditEvents(count: 10)
        let pricingStates = SyntheticFixtures.pricingStates()
        let teamStates = SyntheticFixtures.teamStates(count: 10)
        
        // Check drafted outcomes
        for outcome in draftedOutcomes {
            XCTAssertTrue(
                SyntheticFixtures.validateNoForbiddenPatterns(outcome.intentType),
                "Drafted outcome intentType contains forbidden pattern"
            )
            XCTAssertTrue(
                SyntheticFixtures.validateNoForbiddenPatterns(outcome.outputType),
                "Drafted outcome outputType contains forbidden pattern"
            )
        }
        
        // Check policy decisions
        for decision in policyDecisions {
            XCTAssertTrue(
                SyntheticFixtures.validateNoForbiddenPatterns(decision.decision),
                "Policy decision contains forbidden pattern"
            )
            XCTAssertTrue(
                SyntheticFixtures.validateNoForbiddenPatterns(decision.reason),
                "Policy reason contains forbidden pattern"
            )
        }
        
        // Check audit events
        for event in auditEvents {
            XCTAssertTrue(
                SyntheticFixtures.validateNoForbiddenPatterns(event.kind),
                "Audit event kind contains forbidden pattern"
            )
            XCTAssertTrue(
                SyntheticFixtures.validateNoForbiddenPatterns(event.backendUsed),
                "Audit event backend contains forbidden pattern"
            )
        }
        
        // Check pricing states
        for state in pricingStates {
            XCTAssertTrue(
                SyntheticFixtures.validateNoForbiddenPatterns(state.tier),
                "Pricing tier contains forbidden pattern"
            )
        }
        
        // Check team states
        for state in teamStates {
            XCTAssertTrue(
                SyntheticFixtures.validateNoForbiddenPatterns(state.role),
                "Team role contains forbidden pattern"
            )
        }
    }
    
    // MARK: - Test 4: Synthetic Fixtures Are Deterministic
    
    func testSyntheticFixturesAreDeterministic() {
        // Generate fixtures twice
        let outcomes1 = SyntheticFixtures.draftedOutcomes(count: 5)
        let outcomes2 = SyntheticFixtures.draftedOutcomes(count: 5)
        
        // They must be identical
        for i in 0..<5 {
            XCTAssertEqual(outcomes1[i].id, outcomes2[i].id, "UUIDs must be deterministic")
            XCTAssertEqual(outcomes1[i].intentType, outcomes2[i].intentType, "Intent types must be deterministic")
            XCTAssertEqual(outcomes1[i].createdAtDayRounded, outcomes2[i].createdAtDayRounded, "Dates must be deterministic")
        }
        
        // Check seed-based UUIDs are stable
        let uuid1 = SyntheticSeed.uuid(index: 0)
        let uuid2 = SyntheticSeed.uuid(index: 0)
        XCTAssertEqual(uuid1, uuid2, "Seeded UUIDs must be identical")
        
        // Check seed-based dates are stable
        let date1 = SyntheticSeed.date(dayOffset: 0)
        let date2 = SyntheticSeed.date(dayOffset: 0)
        XCTAssertEqual(date1, date2, "Seeded dates must be identical")
    }
    
    // MARK: - Test 5: No Runtime Files Modified After 12D
    
    func testNoRuntimeFilesModifiedAfter12D() throws {
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
            
            // Must not contain Phase 12D references
            XCTAssertFalse(
                content.contains("Phase 12D"),
                "\(fileName) should not contain Phase 12D references"
            )
            
            // Must not contain Release Seal references
            XCTAssertFalse(
                content.contains("ReleaseSeal") || content.contains("RELEASE_CANDIDATE"),
                "\(fileName) should not reference release seals"
            )
        }
    }
    
    // MARK: - Test 6: Terminology Canon Hash Locked
    
    func testTerminologyCanonHashLocked() throws {
        let canonPath = findDocFile(named: "TERMINOLOGY_CANON.md")
        let content = try String(contentsOfFile: canonPath, encoding: .utf8)
        
        let result = ReleaseSeal.verifySeal(
            artifactName: "TERMINOLOGY_CANON",
            content: content,
            expectedMarker: ReleaseSeal.terminologyCanonHash
        )
        
        XCTAssertTrue(result.isSealed, "Terminology Canon seal is broken: \(result.description)")
    }
    
    // MARK: - Test 7: Pricing Registry Hash Locked
    
    func testPricingRegistryHashLocked() throws {
        let registryPath = findProjectFile(at: "OperatorKit/Monetization/PricingPackageRegistry.swift")
        let content = try String(contentsOfFile: registryPath, encoding: .utf8)
        
        let result = ReleaseSeal.verifySeal(
            artifactName: "PRICING_REGISTRY",
            content: content,
            expectedMarker: ReleaseSeal.pricingRegistryHash
        )
        
        XCTAssertTrue(result.isSealed, "Pricing Registry seal is broken: \(result.description)")
    }
    
    // MARK: - Test 8: Claim Registry Hash Locked
    
    func testClaimRegistryHashLocked() throws {
        let registryPath = findDocFile(named: "CLAIM_REGISTRY.md")
        let content = try String(contentsOfFile: registryPath, encoding: .utf8)
        
        let result = ReleaseSeal.verifySeal(
            artifactName: "CLAIM_REGISTRY",
            content: content,
            expectedMarker: ReleaseSeal.claimRegistryHash
        )
        
        XCTAssertTrue(result.isSealed, "Claim Registry seal is broken: \(result.description)")
    }
    
    // MARK: - Test 9: Safety Contract Hash Locked
    
    func testSafetyContractHashLocked() throws {
        let contractPath = findDocFile(named: "SAFETY_CONTRACT.md")
        let content = try String(contentsOfFile: contractPath, encoding: .utf8)
        
        let result = ReleaseSeal.verifySeal(
            artifactName: "SAFETY_CONTRACT",
            content: content,
            expectedMarker: ReleaseSeal.safetyContractHash
        )
        
        XCTAssertTrue(result.isSealed, "Safety Contract seal is broken: \(result.description)")
    }
    
    // MARK: - Test 10: Store Listing Copy Hash Locked
    
    func testStoreListingCopyHashLocked() throws {
        let listingPath = findProjectFile(at: "Resources/StoreMetadata/StoreListingCopy.swift")
        let content = try String(contentsOfFile: listingPath, encoding: .utf8)
        
        let result = ReleaseSeal.verifySeal(
            artifactName: "STORE_LISTING",
            content: content,
            expectedMarker: ReleaseSeal.storeListingCopyHash
        )
        
        XCTAssertTrue(result.isSealed, "Store Listing Copy seal is broken: \(result.description)")
    }
    
    // MARK: - Test 11: No Network Imports In Synthetic Harness
    
    func testNoNetworkImportsInSyntheticHarness() throws {
        let fixturesPath = findTestingFile(named: "SyntheticData/SyntheticFixtures.swift")
        let sealPath = findTestingFile(named: "ReleaseSeal.swift")
        
        let testFiles = [fixturesPath, sealPath]
        
        for filePath in testFiles {
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // No network imports
            XCTAssertFalse(
                content.contains("import Network"),
                "Testing files should not import Network framework"
            )
            
            // No URLSession
            XCTAssertFalse(
                content.contains("URLSession"),
                "Testing files should not use URLSession"
            )
            
            // No async networking
            XCTAssertFalse(
                content.contains("URLRequest"),
                "Testing files should not use URLRequest"
            )
        }
    }
    
    // MARK: - Test 12: No User Data Markers In Synthetic Fixtures
    
    func testNoUserDataMarkersInSyntheticFixtures() throws {
        let fixturesPath = findTestingFile(named: "SyntheticData/SyntheticFixtures.swift")
        let content = try String(contentsOfFile: fixturesPath, encoding: .utf8)
        
        // Must contain synthetic markers
        XCTAssertTrue(
            content.contains("[SYNTHETIC]") || content.contains("SYNTHETIC"),
            "Synthetic fixtures must be clearly labeled"
        )
        
        XCTAssertTrue(
            content.contains("TEST_"),
            "Synthetic fixtures must use TEST_ prefixes"
        )
        
        // Must NOT contain real user data patterns
        let realDataPatterns = [
            "john@", "jane@", "smith@",
            "John Doe", "Jane Doe",
            "123 Main St",
            "Schedule meeting with",
            "Call mom",
            "Pick up kids"
        ]
        
        let lowercasedContent = content.lowercased()
        for pattern in realDataPatterns {
            XCTAssertFalse(
                lowercasedContent.contains(pattern.lowercased()),
                "Synthetic fixtures must not contain real user data pattern: '\(pattern)'"
            )
        }
        
        // Must have forbidden patterns list
        XCTAssertTrue(
            content.contains("forbiddenPatterns"),
            "Synthetic fixtures must define forbidden patterns"
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
    
    private func findTestingFile(named fileName: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        return projectRoot
            .appendingPathComponent("Testing")
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
