import XCTest
@testable import OperatorKit

// ============================================================================
// LAUNCH DOCS INVARIANT TESTS (Phase L3)
//
// Tests verifying launch documentation exists and is compliant.
//
// CONSTRAINTS:
// ❌ No runtime modifications
// ❌ No networking
// ✅ Documentation verification only
// ============================================================================

final class LaunchDocsInvariantTests: XCTestCase {
    
    // MARK: - Required Documents
    
    /// Test that all required launch documents exist
    func testAllRequiredDocsExist() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let requiredDocs = [
            "docs/LAUNCH_DILIGENCE_PACKET.md",
            "docs/EXECUTIVE_SUMMARY_FOR_COUNSEL.md",
            "docs/TECHNICAL_AUDIT_GUIDE.md",
            "docs/WEBSITE_SECURITY_PROOF_COPY.md",
            "docs/APP_STORE_PROOF_LANGUAGE.md",
            "docs/packet/INDEX.md"
        ]
        
        for doc in requiredDocs {
            let docPath = projectRoot.appendingPathComponent(doc)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: docPath.path),
                "Required document should exist: \(doc)"
            )
        }
    }
    
    // MARK: - Forbidden Phrases
    
    /// Test that documents contain no forbidden phrases
    func testDocsContainNoForbiddenPhrases() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let docsToCheck = [
            "docs/LAUNCH_DILIGENCE_PACKET.md",
            "docs/EXECUTIVE_SUMMARY_FOR_COUNSEL.md",
            "docs/WEBSITE_SECURITY_PROOF_COPY.md",
            "docs/APP_STORE_PROOF_LANGUAGE.md"
        ]
        
        // Phrases that should not appear as claims (OK in "do not use" lists)
        let forbiddenPhrases = [
            "guaranteed secure",
            "unhackable",
            "military-grade",
            "bank-level security",
            "100% safe",
            "bulletproof",
            "ironclad protection",
            "fortress"
        ]
        
        for doc in docsToCheck {
            let docPath = projectRoot.appendingPathComponent(doc)
            
            guard FileManager.default.fileExists(atPath: docPath.path) else {
                continue
            }
            
            let content = try String(contentsOf: docPath, encoding: .utf8).lowercased()
            
            for phrase in forbiddenPhrases {
                // Check if phrase appears outside of "forbidden" or "avoid" sections
                let occurrences = content.components(separatedBy: phrase.lowercased()).count - 1
                
                // Allow if it only appears in "forbidden phrases" table
                if occurrences > 0 {
                    // Check if it's in a "do not use" context
                    let lines = content.components(separatedBy: .newlines)
                    for line in lines {
                        if line.contains(phrase.lowercased()) {
                            // OK if in a "forbidden" or "avoid" table row
                            let isForbiddenTable = line.contains("forbidden") ||
                                                   line.contains("avoid") ||
                                                   line.contains("do not") ||
                                                   line.contains("| reason") ||
                                                   line.contains("❌")
                            
                            if !isForbiddenTable {
                                XCTFail("Document \(doc) contains forbidden phrase '\(phrase)' outside of warning context")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - No User Content Markers
    
    /// Test that documents contain no user content markers
    func testDocsContainNoUserContentMarkers() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let docsToCheck = [
            "docs/LAUNCH_DILIGENCE_PACKET.md",
            "docs/EXECUTIVE_SUMMARY_FOR_COUNSEL.md",
            "docs/TECHNICAL_AUDIT_GUIDE.md",
            "docs/WEBSITE_SECURITY_PROOF_COPY.md",
            "docs/APP_STORE_PROOF_LANGUAGE.md"
        ]
        
        // Markers that would indicate user content
        let userContentMarkers = [
            "[USER_EMAIL]",
            "[USER_NAME]",
            "[DRAFT_CONTENT]",
            "[PERSONAL_DATA]",
            "{{user.",
            "${user.",
            "john@example.com",  // Specific fake user data
            "Jane Doe",          // Specific fake user name
            "555-"               // Fake phone number prefix
        ]
        
        for doc in docsToCheck {
            let docPath = projectRoot.appendingPathComponent(doc)
            
            guard FileManager.default.fileExists(atPath: docPath.path) else {
                continue
            }
            
            let content = try String(contentsOf: docPath, encoding: .utf8)
            
            for marker in userContentMarkers {
                XCTAssertFalse(
                    content.contains(marker),
                    "Document \(doc) should not contain user content marker: \(marker)"
                )
            }
        }
    }
    
    // MARK: - Protected Modules Test
    
    /// Test that no protected modules are touched
    func testNoProtectedModulesTouched() throws {
        let protectedModules = [
            "ExecutionEngine.swift",
            "ApprovalGate.swift",
            "ModelRouter.swift",
            "SideEffectContract.swift"
        ]
        
        let launchDocIdentifiers = [
            "LaunchDiligence",
            "LAUNCH_DILIGENCE",
            "ExecutiveSummary",
            "EXECUTIVE_SUMMARY",
            "TechnicalAuditGuide",
            "WebsiteSecurityProof",
            "AppStoreProofLanguage"
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
                    
                    for identifier in launchDocIdentifiers {
                        XCTAssertFalse(
                            content.contains(identifier),
                            "Protected module \(module) should not reference \(identifier)"
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Document Structure Tests
    
    /// Test that launch diligence packet has required sections
    func testLaunchDiligencePacketStructure() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let docPath = projectRoot.appendingPathComponent("docs/LAUNCH_DILIGENCE_PACKET.md")
        
        guard FileManager.default.fileExists(atPath: docPath.path) else {
            XCTFail("LAUNCH_DILIGENCE_PACKET.md should exist")
            return
        }
        
        let content = try String(contentsOf: docPath, encoding: .utf8)
        
        let requiredSections = [
            "What Is OperatorKit",
            "Threat Model",
            "Zero-Network",
            "Evidence Artifacts",
            "ProofPack",
            "Build Seals",
            "Auditor Checklist"
        ]
        
        for section in requiredSections {
            XCTAssertTrue(
                content.contains(section),
                "Launch diligence packet should contain section: \(section)"
            )
        }
    }
    
    /// Test that executive summary is plain English
    func testExecutiveSummaryPlainEnglish() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let docPath = projectRoot.appendingPathComponent("docs/EXECUTIVE_SUMMARY_FOR_COUNSEL.md")
        
        guard FileManager.default.fileExists(atPath: docPath.path) else {
            XCTFail("EXECUTIVE_SUMMARY_FOR_COUNSEL.md should exist")
            return
        }
        
        let content = try String(contentsOf: docPath, encoding: .utf8)
        
        // Should not contain excessive code
        let codeBlockCount = content.components(separatedBy: "```").count - 1
        XCTAssertLessThan(
            codeBlockCount,
            6,
            "Executive summary should be plain English with minimal code"
        )
        
        // Should contain plain English sections
        let requiredSections = [
            "What Data Stays on Device",
            "What Cannot Happen",
            "What Evidence Is Available"
        ]
        
        for section in requiredSections {
            XCTAssertTrue(
                content.contains(section),
                "Executive summary should contain: \(section)"
            )
        }
    }
    
    /// Test that technical audit guide has commands
    func testTechnicalAuditGuideHasCommands() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let docPath = projectRoot.appendingPathComponent("docs/TECHNICAL_AUDIT_GUIDE.md")
        
        guard FileManager.default.fileExists(atPath: docPath.path) else {
            XCTFail("TECHNICAL_AUDIT_GUIDE.md should exist")
            return
        }
        
        let content = try String(contentsOf: docPath, encoding: .utf8)
        
        // Should contain command examples
        let requiredCommands = [
            "codesign",
            "shasum",
            "otool",
            "nm"
        ]
        
        for command in requiredCommands {
            XCTAssertTrue(
                content.contains(command),
                "Technical audit guide should contain command: \(command)"
            )
        }
    }
    
    /// Test that App Store language avoids forbidden phrases
    func testAppStoreLanguageCompliant() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let docPath = projectRoot.appendingPathComponent("docs/APP_STORE_PROOF_LANGUAGE.md")
        
        guard FileManager.default.fileExists(atPath: docPath.path) else {
            XCTFail("APP_STORE_PROOF_LANGUAGE.md should exist")
            return
        }
        
        let content = try String(contentsOf: docPath, encoding: .utf8)
        
        // Should contain guidelines
        XCTAssertTrue(
            content.contains("Avoid") || content.contains("avoid"),
            "App Store language should contain avoidance guidelines"
        )
        
        // Should have bullet suggestions
        XCTAssertTrue(
            content.contains("•") || content.contains("-"),
            "App Store language should have bullet points"
        )
    }
    
    // MARK: - Packet Index Tests
    
    /// Test that packet index links to key specs
    func testPacketIndexLinksSpecs() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let docPath = projectRoot.appendingPathComponent("docs/packet/INDEX.md")
        
        guard FileManager.default.fileExists(atPath: docPath.path) else {
            XCTFail("docs/packet/INDEX.md should exist")
            return
        }
        
        let content = try String(contentsOf: docPath, encoding: .utf8)
        
        let requiredLinks = [
            "OFFLINE_CERTIFICATION_SPEC.md",
            "BINARY_PROOF_SPEC.md",
            "PROOF_PACK_SPEC.md",
            "SECURITY_MANIFEST.md"
        ]
        
        for link in requiredLinks {
            XCTAssertTrue(
                content.contains(link),
                "Packet index should link to: \(link)"
            )
        }
    }
    
    // MARK: - No Runtime Changes Test
    
    /// Test that no runtime code was added in this phase
    func testNoRuntimeCodeAdded() throws {
        let testFilePath = URL(fileURLWithPath: #file)
        let projectRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        // Check that no Swift files were added in docs/
        let docsPath = projectRoot.appendingPathComponent("docs")
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: docsPath,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            // No Swift files should be in docs/
            XCTAssertNotEqual(
                fileURL.pathExtension,
                "swift",
                "docs/ folder should not contain Swift files"
            )
        }
    }
}
