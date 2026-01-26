import XCTest
@testable import OperatorKit

// ============================================================================
// TERMINOLOGY CANON TESTS (Phase 12C)
//
// Tests proving terminology canon exists and is complete.
// Documentation-only tests — no runtime behavior validation.
//
// See: docs/TERMINOLOGY_CANON.md
// ============================================================================

final class TerminologyCanonTests: XCTestCase {
    
    // MARK: - Test 1: Terminology Canon Exists
    
    func testTerminologyCanonExists() throws {
        let canonPath = findDocFile(named: "TERMINOLOGY_CANON.md")
        
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: canonPath),
            "TERMINOLOGY_CANON.md must exist"
        )
        
        let content = try String(contentsOfFile: canonPath, encoding: .utf8)
        XCTAssertFalse(content.isEmpty, "TERMINOLOGY_CANON.md must not be empty")
        XCTAssertGreaterThan(content.count, 3000, "TERMINOLOGY_CANON.md should be substantial")
    }
    
    // MARK: - Test 2: Required Terms Defined
    
    func testRequiredTermsDefined() throws {
        let canonPath = findDocFile(named: "TERMINOLOGY_CANON.md")
        let content = try String(contentsOfFile: canonPath, encoding: .utf8)
        
        let requiredTerms = [
            "Drafted Outcome",
            "Execution",
            "Approval",
            "Procedure",
            "Procedure Sharing",
            "On-Device",
            "Cloud Sync",
            "Lifetime Sovereign",
            "Team Governance"
        ]
        
        for term in requiredTerms {
            XCTAssertTrue(
                content.contains(term),
                "TERMINOLOGY_CANON.md must define term: '\(term)'"
            )
        }
    }
    
    // MARK: - Test 3: Terms Have Required Sections
    
    func testTermsHaveRequiredSections() throws {
        let canonPath = findDocFile(named: "TERMINOLOGY_CANON.md")
        let content = try String(contentsOfFile: canonPath, encoding: .utf8)
        
        // Each term definition should have these sections
        XCTAssertTrue(
            content.contains("**Definition**"),
            "Terms must have Definition section"
        )
        
        XCTAssertTrue(
            content.contains("**What It Is NOT**"),
            "Terms must have 'What It Is NOT' section"
        )
        
        XCTAssertTrue(
            content.contains("**Where It Appears**"),
            "Terms must have 'Where It Appears' section"
        )
    }
    
    // MARK: - Test 4: No Banned Words
    
    func testNoBannedWords() throws {
        let canonPath = findDocFile(named: "TERMINOLOGY_CANON.md")
        let content = try String(contentsOfFile: canonPath, encoding: .utf8).lowercased()
        
        // Banned words that should not appear in definitions
        let bannedWords = [
            "ai agent",
            "assistant thinks",
            "learns",
            "smart ai",
            "intelligent ai",
            "guaranteed",
            "100%"
        ]
        
        // Check that banned words don't appear in definition context
        // (They may appear in "What It Is NOT" sections explaining what to avoid)
        let definitionSections = content.components(separatedBy: "**definition**")
        for section in definitionSections.dropFirst() {
            // Get text until next section marker
            if let endIndex = section.range(of: "**what it is not**")?.lowerBound {
                let definitionText = String(section[..<endIndex])
                for banned in bannedWords {
                    XCTAssertFalse(
                        definitionText.contains(banned),
                        "Definition contains banned word: '\(banned)'"
                    )
                }
            }
        }
    }
    
    // MARK: - Test 5: No Speculative Language
    
    func testNoSpeculativeLanguage() throws {
        let canonPath = findDocFile(named: "TERMINOLOGY_CANON.md")
        let content = try String(contentsOfFile: canonPath, encoding: .utf8).lowercased()
        
        let speculativePatterns = [
            "we believe",
            "we think",
            "probably",
            "might be",
            "could potentially",
            "hopefully",
            "we hope",
            "in the future",
            "coming soon",
            "planned"
        ]
        
        for pattern in speculativePatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "TERMINOLOGY_CANON.md should not contain speculative language: '\(pattern)'"
            )
        }
    }
    
    // MARK: - Test 6: Has Forbidden Synonyms Table
    
    func testHasForbiddenSynonymsTable() throws {
        let canonPath = findDocFile(named: "TERMINOLOGY_CANON.md")
        let content = try String(contentsOfFile: canonPath, encoding: .utf8)
        
        XCTAssertTrue(
            content.contains("Forbidden Synonyms"),
            "TERMINOLOGY_CANON.md must have Forbidden Synonyms section"
        )
        
        XCTAssertTrue(
            content.contains("Forbidden Term") && content.contains("Use Instead"),
            "Forbidden Synonyms must be in table format with alternatives"
        )
    }
    
    // MARK: - Test 7: No Runtime Files Modified
    
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
                content.contains("Phase 12C") || content.contains("TERMINOLOGY_CANON"),
                "\(fileName) should not contain Phase 12C references"
            )
        }
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
