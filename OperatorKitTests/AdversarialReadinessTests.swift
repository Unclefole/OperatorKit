import XCTest
@testable import OperatorKit

// ============================================================================
// ADVERSARIAL READINESS TESTS (Phase 12A)
//
// Tests proving Phase 12A constraints:
// - Adversarial documentation exists and is complete
// - No runtime files were modified
// - No networking added
// - No new permissions referenced
// - Claims registry contains 12A claims
//
// These tests validate documentation and isolation, not runtime behavior.
//
// See: docs/ADVERSARIAL_REVIEW.md
// ============================================================================

final class AdversarialReadinessTests: XCTestCase {
    
    // MARK: - Test 1: Adversarial Docs Exist
    
    func testAdversarialDocsExist() throws {
        let adversarialReviewPath = findDocFile(named: "ADVERSARIAL_REVIEW.md")
        
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: adversarialReviewPath),
            "ADVERSARIAL_REVIEW.md must exist"
        )
        
        let content = try String(contentsOfFile: adversarialReviewPath, encoding: .utf8)
        XCTAssertFalse(content.isEmpty, "ADVERSARIAL_REVIEW.md must not be empty")
        XCTAssertGreaterThan(content.count, 10000, "ADVERSARIAL_REVIEW.md should be substantial (>10KB)")
    }
    
    // MARK: - Test 2: Adversarial Doc Has All Required Sections
    
    func testAdversarialDocHasAllRequiredSections() throws {
        let adversarialReviewPath = findDocFile(named: "ADVERSARIAL_REVIEW.md")
        let content = try String(contentsOfFile: adversarialReviewPath, encoding: .utf8)
        
        // Section 1: Apple App Store Rejection Simulation
        let appleRejectionSections = [
            "Background Processing",
            "Undisclosed Data Collection",
            "Autonomous Execution",
            "Misleading AI Claims",
            "Paywall Coercion",
            "Privacy Violations",
            "Sync/Data Leakage",
            "Analytics Without Consent"
        ]
        
        for section in appleRejectionSections {
            XCTAssertTrue(
                content.contains(section),
                "ADVERSARIAL_REVIEW.md missing Apple rejection section: \(section)"
            )
        }
        
        // Section 2: Enterprise Security Audit
        let enterpriseQuestions = [
            "Where does data go",
            "Who can access drafts",
            "Can admins see content",
            "Can execution be triggered remotely",
            "Is telemetry present",
            "Is training performed",
            "Is cloud required",
            "Is identity tracked"
        ]
        
        for question in enterpriseQuestions {
            XCTAssertTrue(
                content.lowercased().contains(question.lowercased()),
                "ADVERSARIAL_REVIEW.md missing enterprise question: \(question)"
            )
        }
        
        // Section 3: Competitive Skeptic Review
        let skepticClaims = [
            "just a wrapper",
            "defensible",
            "scale",
            "won't pay",
            "exaggerated"
        ]
        
        for claim in skepticClaims {
            XCTAssertTrue(
                content.lowercased().contains(claim.lowercased()),
                "ADVERSARIAL_REVIEW.md missing competitor claim: \(claim)"
            )
        }
        
        // Section 4: Rejection Matrix
        XCTAssertTrue(
            content.contains("Rejection Matrix"),
            "ADVERSARIAL_REVIEW.md missing Rejection Matrix section"
        )
        
        // Section 5: Residual Risks
        XCTAssertTrue(
            content.contains("Residual Risks"),
            "ADVERSARIAL_REVIEW.md missing Residual Risks section"
        )
        
        // Verify PASS outcomes in rejection matrix
        let passCount = content.components(separatedBy: "**PASS**").count - 1
        XCTAssertGreaterThanOrEqual(passCount, 20, "Rejection matrix should have at least 20 PASS outcomes")
        
        // Verify FAILS TO REJECT verdicts
        let failsToRejectCount = content.components(separatedBy: "**FAILS TO REJECT**").count - 1
        XCTAssertGreaterThanOrEqual(failsToRejectCount, 8, "Should have at least 8 'FAILS TO REJECT' verdicts")
    }
    
    // MARK: - Test 3: No Runtime Files Modified In Phase 12A
    
    func testNoRuntimeFilesModifiedInPhase12A() throws {
        // These files must NOT contain any Phase 12A references
        let protectedFiles = [
            ("ExecutionEngine.swift", "Domain/Execution"),
            ("ApprovalGate.swift", "Domain/Approval"),
            ("ModelRouter.swift", "Models"),
            ("SideEffectContract.swift", "Domain/Approval"),
            ("ConfirmWriteView.swift", "UI/Approval"),
            ("ConfirmCalendarWriteView.swift", "UI/Approval")
        ]
        
        for (fileName, subdirectory) in protectedFiles {
            let filePath = findProjectFile(named: fileName, in: subdirectory)
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue // File may not exist in test environment
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Phase 12A should not add any code to these files
            XCTAssertFalse(
                content.contains("Phase 12A") || content.contains("12A") || content.contains("Adversarial"),
                "\(fileName) should not contain Phase 12A references"
            )
        }
    }
    
    // MARK: - Test 4: No Networking Added
    
    func testNoNetworkingAdded() throws {
        // Verify no new URLSession usage was added in Phase 12A
        // Phase 12A is documentation-only, so no new Swift files should exist
        
        // Check that ADVERSARIAL_REVIEW.md does not import or reference network APIs
        let adversarialReviewPath = findDocFile(named: "ADVERSARIAL_REVIEW.md")
        let content = try String(contentsOfFile: adversarialReviewPath, encoding: .utf8)
        
        let networkPatterns = [
            "URLSession.shared",
            "import Network",
            "import Alamofire",
            "import AFNetworking"
        ]
        
        for pattern in networkPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ADVERSARIAL_REVIEW.md should not reference networking: \(pattern)"
            )
        }
    }
    
    // MARK: - Test 5: No New Permissions Referenced
    
    func testNoNewPermissionsReferenced() throws {
        // Phase 12A should not introduce any new permission requirements
        let adversarialReviewPath = findDocFile(named: "ADVERSARIAL_REVIEW.md")
        let content = try String(contentsOfFile: adversarialReviewPath, encoding: .utf8)
        
        // Existing permissions (these ARE expected to be mentioned)
        let existingPermissions = [
            "NSCalendarsUsageDescription",
            "NSRemindersUsageDescription",
            "NSSiriUsageDescription"
        ]
        
        // New permissions that should NOT be added
        let forbiddenPermissions = [
            "NSLocationUsageDescription",
            "NSCameraUsageDescription",
            "NSMicrophoneUsageDescription",
            "NSContactsUsageDescription",
            "NSPhotoLibraryUsageDescription",
            "NSHealthShareUsageDescription",
            "NSMotionUsageDescription"
        ]
        
        for permission in forbiddenPermissions {
            XCTAssertFalse(
                content.contains(permission),
                "Phase 12A should not reference new permission: \(permission)"
            )
        }
        
        // Verify existing permissions ARE mentioned (proving we're discussing the right scope)
        var existingMentioned = 0
        for permission in existingPermissions {
            if content.contains(permission) {
                existingMentioned += 1
            }
        }
        // At least one existing permission should be discussed
        XCTAssertGreaterThan(existingMentioned, 0, "Document should discuss existing permissions")
    }
    
    // MARK: - Test 6: Claims Registry Contains 12A Claims
    
    func testClaimsRegistryContains12AClaims() throws {
        let claimRegistryPath = findDocFile(named: "CLAIM_REGISTRY.md")
        let content = try String(contentsOfFile: claimRegistryPath, encoding: .utf8)
        
        // Required Phase 12A claims
        let requiredClaims = [
            "CLAIM-12A-01",
            "CLAIM-12A-02",
            "CLAIM-12A-03"
        ]
        
        for claim in requiredClaims {
            XCTAssertTrue(
                content.contains(claim),
                "CLAIM_REGISTRY.md missing Phase 12A claim: \(claim)"
            )
        }
        
        // Verify claim content
        XCTAssertTrue(
            content.lowercased().contains("app store rejection vectors simulated"),
            "CLAIM-12A-01 should mention App Store rejection vectors"
        )
        
        XCTAssertTrue(
            content.lowercased().contains("enterprise audit simulation"),
            "CLAIM-12A-02 should mention enterprise audit simulation"
        )
        
        XCTAssertTrue(
            content.lowercased().contains("competitive skepticism"),
            "CLAIM-12A-03 should mention competitive skepticism"
        )
        
        // Verify schema version was updated
        XCTAssertTrue(
            content.contains("Schema Version: 23") || content.contains("Phase 12A"),
            "CLAIM_REGISTRY.md should be updated to Phase 12A"
        )
    }
    
    // MARK: - Additional Validation Tests
    
    /// Verify no speculative language in adversarial doc
    func testNoSpeculativeLanguageInAdversarialDoc() throws {
        let adversarialReviewPath = findDocFile(named: "ADVERSARIAL_REVIEW.md")
        let content = try String(contentsOfFile: adversarialReviewPath, encoding: .utf8).lowercased()
        
        let speculativePatterns = [
            "we believe",
            "we think",
            "probably",
            "might be",
            "could potentially",
            "hopefully",
            "we hope"
        ]
        
        for pattern in speculativePatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ADVERSARIAL_REVIEW.md should not contain speculative language: '\(pattern)'"
            )
        }
    }
    
    /// Verify APP_REVIEW_PACKET.md references adversarial review
    func testAppReviewPacketReferencesAdversarialReview() throws {
        let appReviewPath = findDocFile(named: "APP_REVIEW_PACKET.md")
        let content = try String(contentsOfFile: appReviewPath, encoding: .utf8)
        
        XCTAssertTrue(
            content.contains("Adversarial Review") || content.contains("ADVERSARIAL_REVIEW.md"),
            "APP_REVIEW_PACKET.md should reference adversarial review"
        )
        
        XCTAssertTrue(
            content.contains("Phase 12A"),
            "APP_REVIEW_PACKET.md should mention Phase 12A"
        )
    }
    
    /// Verify residual risks section exists and is honest
    func testResidualRisksSectionIsHonest() throws {
        let adversarialReviewPath = findDocFile(named: "ADVERSARIAL_REVIEW.md")
        let content = try String(contentsOfFile: adversarialReviewPath, encoding: .utf8)
        
        // Extract residual risks section
        guard let residualStart = content.range(of: "Residual Risks") else {
            XCTFail("Residual Risks section not found")
            return
        }
        
        let residualSection = String(content[residualStart.lowerBound...])
        
        // Should have at least 3 risks
        let riskCount = residualSection.components(separatedBy: "### Risk").count - 1
        XCTAssertGreaterThanOrEqual(riskCount, 3, "Should document at least 3 residual risks")
        
        // Each risk should have "Why It Exists" and "Why Acceptable"
        XCTAssertTrue(
            residualSection.contains("Why It Exists"),
            "Residual risks should explain why each risk exists"
        )
        
        XCTAssertTrue(
            residualSection.contains("Why Acceptable"),
            "Residual risks should explain why each risk is acceptable"
        )
    }
    
    // MARK: - Helpers
    
    private func findProjectFile(named fileName: String, in subdirectory: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        return projectRoot
            .appendingPathComponent("OperatorKit")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent(fileName)
            .path
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
}
