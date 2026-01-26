import XCTest
@testable import OperatorKit

// ============================================================================
// EXTERNAL REVIEW DRY-RUN TESTS (Phase 12B)
//
// Tests proving Phase 12B constraints:
// - Dry-run documentation exists and is complete
// - Required sections are present
// - No speculative language
// - No feature proposals
// - No runtime files modified
// - No networking or permission references
//
// These tests validate documentation only, not runtime behavior.
//
// See: docs/EXTERNAL_REVIEW_DRY_RUN.md
// ============================================================================

final class ExternalReviewDryRunTests: XCTestCase {
    
    // MARK: - Test 1: Dry-Run Document Exists
    
    func testDryRunDocumentExists() throws {
        let dryRunPath = findDocFile(named: "EXTERNAL_REVIEW_DRY_RUN.md")
        
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: dryRunPath),
            "EXTERNAL_REVIEW_DRY_RUN.md must exist"
        )
        
        let content = try String(contentsOfFile: dryRunPath, encoding: .utf8)
        XCTAssertFalse(content.isEmpty, "EXTERNAL_REVIEW_DRY_RUN.md must not be empty")
        XCTAssertGreaterThan(content.count, 5000, "EXTERNAL_REVIEW_DRY_RUN.md should be substantial")
    }
    
    // MARK: - Test 2: Required Sections Present
    
    func testRequiredSectionsPresent() throws {
        let dryRunPath = findDocFile(named: "EXTERNAL_REVIEW_DRY_RUN.md")
        let content = try String(contentsOfFile: dryRunPath, encoding: .utf8)
        
        // Required sections per spec
        let requiredSections = [
            "Persona Walkthroughs",
            "Misinterpretation Stress Test",
            "Timing Audit",
            "Evidence Sufficiency",
            "Residual Confusion Register"
        ]
        
        for section in requiredSections {
            XCTAssertTrue(
                content.contains(section),
                "EXTERNAL_REVIEW_DRY_RUN.md missing required section: \(section)"
            )
        }
        
        // Required personas
        let requiredPersonas = [
            "Apple App Store Reviewer",
            "Enterprise Security Reviewer",
            "Skeptical Power User"
        ]
        
        for persona in requiredPersonas {
            XCTAssertTrue(
                content.contains(persona),
                "EXTERNAL_REVIEW_DRY_RUN.md missing required persona: \(persona)"
            )
        }
        
        // Must explicitly state no runtime changes
        XCTAssertTrue(
            content.contains("No runtime behavior was evaluated or changed"),
            "Document must explicitly state no runtime behavior was changed"
        )
    }
    
    // MARK: - Test 3: No Speculative Language
    
    func testNoSpeculativeLanguage() throws {
        let dryRunPath = findDocFile(named: "EXTERNAL_REVIEW_DRY_RUN.md")
        let content = try String(contentsOfFile: dryRunPath, encoding: .utf8).lowercased()
        
        let speculativePatterns = [
            "we believe",
            "we think",
            "probably",
            "might be",
            "could potentially",
            "hopefully",
            "we hope",
            "we expect",
            "should work",
            "likely to"
        ]
        
        for pattern in speculativePatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "EXTERNAL_REVIEW_DRY_RUN.md should not contain speculative language: '\(pattern)'"
            )
        }
    }
    
    // MARK: - Test 4: No Feature Proposals
    
    func testNoFeatureProposals() throws {
        let dryRunPath = findDocFile(named: "EXTERNAL_REVIEW_DRY_RUN.md")
        let content = try String(contentsOfFile: dryRunPath, encoding: .utf8).lowercased()
        
        let featureProposalPatterns = [
            "we should add",
            "we need to add",
            "recommendation: add",
            "proposed feature",
            "new feature",
            "implement a",
            "create a new",
            "add a new"
        ]
        
        for pattern in featureProposalPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "EXTERNAL_REVIEW_DRY_RUN.md should not contain feature proposals: '\(pattern)'"
            )
        }
    }
    
    // MARK: - Test 5: No Runtime Files Modified
    
    func testNoRuntimeFilesModified() throws {
        // These files must NOT contain any Phase 12B references
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
            
            // Phase 12B should not modify these files
            XCTAssertFalse(
                content.contains("Phase 12B") || content.contains("12B") || content.contains("DryRun"),
                "\(fileName) should not contain Phase 12B references"
            )
        }
    }
    
    // MARK: - Test 6: No Networking References
    
    func testNoNetworkingReferences() throws {
        let dryRunPath = findDocFile(named: "EXTERNAL_REVIEW_DRY_RUN.md")
        let content = try String(contentsOfFile: dryRunPath, encoding: .utf8)
        
        // Document should not propose new networking
        let networkProposalPatterns = [
            "add networking",
            "implement networking",
            "new API endpoint",
            "new URLSession",
            "add telemetry",
            "add analytics"
        ]
        
        for pattern in networkProposalPatterns {
            XCTAssertFalse(
                content.lowercased().contains(pattern.lowercased()),
                "EXTERNAL_REVIEW_DRY_RUN.md should not propose networking: '\(pattern)'"
            )
        }
        
        // Verify document states no networking was added
        XCTAssertTrue(
            content.contains("Networking Added | None") || content.contains("Networking Added: None"),
            "Document should explicitly state no networking was added"
        )
    }
    
    // MARK: - Test 7: No Permission References
    
    func testNoPermissionReferences() throws {
        let dryRunPath = findDocFile(named: "EXTERNAL_REVIEW_DRY_RUN.md")
        let content = try String(contentsOfFile: dryRunPath, encoding: .utf8)
        
        // Document should not propose new permissions
        let newPermissionPatterns = [
            "add permission",
            "new permission",
            "request location",
            "request camera",
            "request microphone",
            "request contacts",
            "request photos"
        ]
        
        for pattern in newPermissionPatterns {
            XCTAssertFalse(
                content.lowercased().contains(pattern.lowercased()),
                "EXTERNAL_REVIEW_DRY_RUN.md should not propose new permissions: '\(pattern)'"
            )
        }
        
        // Verify document states no permissions were added
        XCTAssertTrue(
            content.contains("Permissions Added | None") || content.contains("Permissions Added: None"),
            "Document should explicitly state no permissions were added"
        )
    }
    
    // MARK: - Additional Validation Tests
    
    /// Verify timing audit has all personas
    func testTimingAuditComplete() throws {
        let dryRunPath = findDocFile(named: "EXTERNAL_REVIEW_DRY_RUN.md")
        let content = try String(contentsOfFile: dryRunPath, encoding: .utf8)
        
        // Should have timing for all personas
        XCTAssertTrue(
            content.contains("Persona A") || content.contains("Apple Reviewer"),
            "Timing audit should include Apple Reviewer"
        )
        
        XCTAssertTrue(
            content.contains("Persona B") || content.contains("Enterprise"),
            "Timing audit should include Enterprise Reviewer"
        )
        
        XCTAssertTrue(
            content.contains("Persona C") || content.contains("Power User"),
            "Timing audit should include Power User"
        )
    }
    
    /// Verify evidence sufficiency answers YES/NO/CONDITIONAL
    func testEvidenceSufficiencyHasAnswers() throws {
        let dryRunPath = findDocFile(named: "EXTERNAL_REVIEW_DRY_RUN.md")
        let content = try String(contentsOfFile: dryRunPath, encoding: .utf8)
        
        // Should have explicit answers
        let validAnswers = ["**YES**", "**NO**", "**CONDITIONAL**"]
        var foundAnswers = 0
        
        for answer in validAnswers {
            if content.contains(answer) {
                foundAnswers += 1
            }
        }
        
        XCTAssertGreaterThan(foundAnswers, 0, "Evidence sufficiency section should have YES/NO/CONDITIONAL answers")
    }
    
    /// Verify residual confusion register has severity levels
    func testResidualConfusionHasSeverity() throws {
        let dryRunPath = findDocFile(named: "EXTERNAL_REVIEW_DRY_RUN.md")
        let content = try String(contentsOfFile: dryRunPath, encoding: .utf8)
        
        // Should have severity levels
        XCTAssertTrue(
            content.contains("LOW") || content.contains("MEDIUM") || content.contains("HIGH"),
            "Residual confusion register should have severity levels"
        )
    }
    
    /// Verify misinterpretation stress test addresses key questions
    func testMisinterpretationStressTestComplete() throws {
        let dryRunPath = findDocFile(named: "EXTERNAL_REVIEW_DRY_RUN.md")
        let content = try String(contentsOfFile: dryRunPath, encoding: .utf8).lowercased()
        
        let keyQuestions = [
            "run automatically",
            "cloud",
            "autonomous"
        ]
        
        for question in keyQuestions {
            XCTAssertTrue(
                content.contains(question),
                "Misinterpretation stress test should address: '\(question)'"
            )
        }
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
