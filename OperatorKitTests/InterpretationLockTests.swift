import XCTest
@testable import OperatorKit

// ============================================================================
// INTERPRETATION LOCK TESTS (Phase 12C)
//
// Tests proving interpretation locks exist and are complete.
// Documentation-only tests — no runtime behavior validation.
//
// See: docs/INTERPRETATION_LOCKS.md
// ============================================================================

final class InterpretationLockTests: XCTestCase {
    
    // MARK: - Test 1: Interpretation Locks Document Exists
    
    func testInterpretationLocksExists() throws {
        let locksPath = findDocFile(named: "INTERPRETATION_LOCKS.md")
        
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: locksPath),
            "INTERPRETATION_LOCKS.md must exist"
        )
        
        let content = try String(contentsOfFile: locksPath, encoding: .utf8)
        XCTAssertFalse(content.isEmpty, "INTERPRETATION_LOCKS.md must not be empty")
    }
    
    // MARK: - Test 2: All Phase 12B Issues Addressed
    
    func testAllPhase12BIssuesAddressed() throws {
        let locksPath = findDocFile(named: "INTERPRETATION_LOCKS.md")
        let content = try String(contentsOfFile: locksPath, encoding: .utf8)
        
        // The 8 issues from Phase 12B Residual Confusion Register
        let phase12BIssues = [
            "SwiftData",
            "Code File Names",
            "Supabase",
            "admin console",
            "On-Device",
            "Safety Model",
            "Drafted Outcomes",
            "Execution Engine"
        ]
        
        for issue in phase12BIssues {
            XCTAssertTrue(
                content.lowercased().contains(issue.lowercased()),
                "INTERPRETATION_LOCKS.md must address Phase 12B issue: '\(issue)'"
            )
        }
    }
    
    // MARK: - Test 3: Each Lock Has Required Sections
    
    func testLocksHaveRequiredSections() throws {
        let locksPath = findDocFile(named: "INTERPRETATION_LOCKS.md")
        let content = try String(contentsOfFile: locksPath, encoding: .utf8)
        
        // Each lock should have these sections
        XCTAssertTrue(
            content.contains("**Risky Phrasing**") || content.contains("Risky Phrasing"),
            "Locks must have 'Risky Phrasing' section"
        )
        
        XCTAssertTrue(
            content.contains("**Wrong Inference**") || content.contains("Wrong Inference"),
            "Locks must have 'Wrong Inference' section"
        )
        
        XCTAssertTrue(
            content.contains("**Locked Interpretation**") || content.contains("Locked Interpretation"),
            "Locks must have 'Locked Interpretation' section"
        )
    }
    
    // MARK: - Test 4: No Speculative Language
    
    func testNoSpeculativeLanguage() throws {
        let locksPath = findDocFile(named: "INTERPRETATION_LOCKS.md")
        let content = try String(contentsOfFile: locksPath, encoding: .utf8).lowercased()
        
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
                "INTERPRETATION_LOCKS.md should not contain speculative language: '\(pattern)'"
            )
        }
    }
    
    // MARK: - Test 5: No Feature Proposals
    
    func testNoFeatureProposals() throws {
        let locksPath = findDocFile(named: "INTERPRETATION_LOCKS.md")
        let content = try String(contentsOfFile: locksPath, encoding: .utf8).lowercased()
        
        let featureProposalPatterns = [
            "we should add",
            "we need to add",
            "recommended fix:",
            "proposed change:",
            "new feature"
        ]
        
        for pattern in featureProposalPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "INTERPRETATION_LOCKS.md should not contain feature proposals: '\(pattern)'"
            )
        }
    }
    
    // MARK: - Test 6: Has Severity Ratings
    
    func testHasSeverityRatings() throws {
        let locksPath = findDocFile(named: "INTERPRETATION_LOCKS.md")
        let content = try String(contentsOfFile: locksPath, encoding: .utf8)
        
        XCTAssertTrue(
            content.contains("LOW") || content.contains("MEDIUM") || content.contains("HIGH"),
            "INTERPRETATION_LOCKS.md must include severity ratings"
        )
    }
    
    // MARK: - Test 7: Has Summary Table
    
    func testHasSummaryTable() throws {
        let locksPath = findDocFile(named: "INTERPRETATION_LOCKS.md")
        let content = try String(contentsOfFile: locksPath, encoding: .utf8)
        
        XCTAssertTrue(
            content.contains("Summary Table") || content.contains("| # | Issue"),
            "INTERPRETATION_LOCKS.md must have a summary table"
        )
    }
    
    // MARK: - Test 8: No New Hypothetical Risks
    
    func testNoNewHypotheticalRisks() throws {
        let locksPath = findDocFile(named: "INTERPRETATION_LOCKS.md")
        let content = try String(contentsOfFile: locksPath, encoding: .utf8)
        
        // Count the number of "Lock #" entries
        let lockCount = content.components(separatedBy: "## Lock #").count - 1
        
        // Phase 12B identified exactly 8 issues
        XCTAssertLessThanOrEqual(
            lockCount, 10,
            "INTERPRETATION_LOCKS.md should not introduce many new hypothetical risks"
        )
    }
    
    // MARK: - Test 9: No Runtime Files Modified
    
    func testNoRuntimeFilesModified() throws {
        let protectedFiles = [
            ("ExecutionEngine.swift", "Domain/Execution"),
            ("ApprovalGate.swift", "Domain/Approval"),
            ("ModelRouter.swift", "Models")
        ]
        
        for (fileName, subdirectory) in protectedFiles {
            let filePath = findProjectFile(named: fileName, in: subdirectory)
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertFalse(
                content.contains("Phase 12C") || content.contains("INTERPRETATION_LOCK"),
                "\(fileName) should not contain Phase 12C references"
            )
        }
    }
    
    // MARK: - Test 10: No Contradictions Across Documents
    
    func testNoContradictionsAcrossDocuments() throws {
        // Verify "Drafted Outcomes" is used consistently
        let canonPath = findDocFile(named: "TERMINOLOGY_CANON.md")
        let locksPath = findDocFile(named: "INTERPRETATION_LOCKS.md")
        
        let canonContent = try String(contentsOfFile: canonPath, encoding: .utf8)
        let locksContent = try String(contentsOfFile: locksPath, encoding: .utf8)
        
        // Both documents should use "Drafted Outcome" terminology
        XCTAssertTrue(
            canonContent.contains("Drafted Outcome"),
            "TERMINOLOGY_CANON.md must define 'Drafted Outcome'"
        )
        
        XCTAssertTrue(
            locksContent.contains("Drafted Outcomes"),
            "INTERPRETATION_LOCKS.md must address 'Drafted Outcomes' term"
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
}
