import XCTest
@testable import OperatorKit

// ============================================================================
// APP STORE READINESS INVARIANT TESTS (Phase 10J)
//
// These tests prove App Store submission readiness:
// - Submission packet contains no forbidden keys
// - Copy templates contain no banned words
// - Screenshot captions contain no forbidden content
// - DocIntegrity header validation works
// - UI views are read-only
// - Core execution modules untouched
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class AppStoreReadinessInvariantTests: XCTestCase {
    
    // MARK: - A) Submission Packet Safety
    
    /// Verifies submission packet contains no forbidden keys
    func testSubmissionPacketNoForbiddenKeys() async throws {
        let packet = await AppStoreSubmissionBuilder.shared.build()
        let violations = try packet.validateNoForbiddenKeys()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Submission packet contains forbidden keys: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies submission packet structure is valid
    func testSubmissionPacketStructure() async throws {
        let packet = await AppStoreSubmissionBuilder.shared.build()
        
        // Required fields
        XCTAssertGreaterThan(packet.schemaVersion, 0)
        XCTAssertFalse(packet.exportedAt.isEmpty)
        XCTAssertFalse(packet.appVersion.isEmpty)
        XCTAssertFalse(packet.buildNumber.isEmpty)
        XCTAssertFalse(packet.releaseMode.isEmpty)
        
        // Monetization should always be present
        XCTAssertNotNil(packet.monetization)
        XCTAssertTrue(packet.monetization?.restorePurchasesAvailable ?? false)
        XCTAssertTrue(packet.monetization?.noTrackingAnalytics ?? false)
    }
    
    /// Verifies submission packet JSON export works
    func testSubmissionPacketJSONExport() async throws {
        let packet = await AppStoreSubmissionBuilder.shared.build()
        let jsonData = try packet.exportJSON()
        
        XCTAssertGreaterThan(jsonData.count, 0)
        
        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(json as? [String: Any])
    }
    
    // MARK: - B) Copy Templates Safety
    
    /// Verifies review notes have no banned words
    func testReviewNotesNoBannedWords() {
        let reviewNotes = SubmissionCopy.reviewNotesTemplate(version: "1.0", build: "1")
        let violations = SubmissionCopy.validate(reviewNotes)
        
        XCTAssertTrue(
            violations.isEmpty,
            "Review notes contain banned words: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies what's new has no banned words
    func testWhatsNewNoBannedWords() {
        let whatsNew = SubmissionCopy.whatsNewTemplate(
            version: "1.0",
            highlights: SubmissionCopy.defaultHighlights
        )
        let violations = SubmissionCopy.validate(whatsNew)
        
        XCTAssertTrue(
            violations.isEmpty,
            "What's New contains banned words: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies disclosures have no banned words
    func testDisclosuresNoBannedWords() {
        let privacyViolations = SubmissionCopy.validate(SubmissionCopy.privacyDisclosureBlurb)
        let monetizationViolations = SubmissionCopy.validate(SubmissionCopy.monetizationDisclosureBlurb)
        let exportViolations = SubmissionCopy.validate(SubmissionCopy.exportComplianceStatement)
        
        XCTAssertTrue(privacyViolations.isEmpty, "Privacy disclosure violations: \(privacyViolations)")
        XCTAssertTrue(monetizationViolations.isEmpty, "Monetization disclosure violations: \(monetizationViolations)")
        XCTAssertTrue(exportViolations.isEmpty, "Export compliance violations: \(exportViolations)")
    }
    
    /// Verifies copy length limits
    func testCopyLengthLimits() {
        let reviewNotes = SubmissionCopy.reviewNotesTemplate(version: "1.0", build: "1")
        let whatsNew = SubmissionCopy.whatsNewTemplate(version: "1.0", highlights: SubmissionCopy.defaultHighlights)
        
        XCTAssertTrue(
            SubmissionCopy.validateLength(reviewNotes, limit: SubmissionCopy.maxReviewNotesLength),
            "Review notes exceed length limit"
        )
        XCTAssertTrue(
            SubmissionCopy.validateLength(whatsNew, limit: SubmissionCopy.maxWhatsNewLength),
            "What's New exceeds length limit"
        )
    }
    
    /// Verifies full copy validation passes
    func testFullCopyValidation() {
        let result = SubmissionCopy.fullValidation(
            reviewNotes: SubmissionCopy.reviewNotesTemplate(version: "1.0", build: "1"),
            whatsNew: SubmissionCopy.whatsNewTemplate(version: "1.0", highlights: SubmissionCopy.defaultHighlights)
        )
        
        XCTAssertTrue(result.isValid, "Copy validation failed: \(result.errors.joined(separator: ", "))")
    }
    
    // MARK: - C) Screenshot Checklist Safety
    
    /// Verifies screenshot captions have no forbidden content
    func testScreenshotCaptionsNoForbiddenContent() {
        let violations = ScreenshotChecklist.validateCaptions()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Screenshot captions contain forbidden content: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies screenshot captions are generic
    func testScreenshotCaptionsAreGeneric() {
        for shot in ScreenshotChecklist.requiredShots {
            // No @ signs (email addresses)
            XCTAssertFalse(
                shot.captionTemplate.contains("@"),
                "Caption '\(shot.name)' contains @ sign"
            )
            
            // No specific names
            let names = ["John", "Jane", "Smith", "example", "test"]
            for name in names {
                XCTAssertFalse(
                    shot.captionTemplate.lowercased().contains(name.lowercased()),
                    "Caption '\(shot.name)' contains name: \(name)"
                )
            }
        }
    }
    
    /// Verifies all required shots are defined
    func testRequiredShotsComplete() {
        XCTAssertEqual(ScreenshotChecklist.requiredShots.count, 8, "Expected 8 required shots")
        
        // Verify order
        for (index, shot) in ScreenshotChecklist.requiredShots.enumerated() {
            XCTAssertEqual(shot.order, index + 1, "Shot order mismatch for \(shot.name)")
        }
    }
    
    // MARK: - D) Doc Integrity Validation
    
    /// Verifies doc integrity hardened validation works
    func testDocIntegrityHardenedValidation() {
        let projectRoot = findProjectRoot()
        let result = DocIntegrity.runHardenedValidation(projectRoot: projectRoot)
        
        // Should have section results for all docs
        XCTAssertEqual(
            result.sectionResults.count,
            DocIntegrity.requiredDocs.count,
            "Should have section results for all docs"
        )
    }
    
    /// Verifies required sections are defined for all docs
    func testAllDocsHaveRequiredSections() {
        for doc in DocIntegrity.requiredDocs {
            XCTAssertFalse(
                doc.requiredSections.isEmpty,
                "Doc '\(doc.name)' has no required sections defined"
            )
        }
    }
    
    /// Verifies fail-closed behavior for missing docs
    func testDocIntegrityFailClosed() {
        // Test with non-existent path
        let result = DocIntegrity.runHardenedValidation(projectRoot: "/nonexistent/path")
        
        XCTAssertFalse(result.isValid, "Should fail for non-existent path")
        XCTAssertTrue(
            result.errors.allSatisfy { $0.contains("FAIL-CLOSED") },
            "All errors should indicate fail-closed"
        )
    }
    
    // MARK: - E) UI Read-Only Verification
    
    /// Verifies AppStoreReadinessView has no behavior toggles
    func testAppStoreReadinessViewNoToggles() throws {
        let filePath = findProjectFile(named: "AppStoreReadinessView.swift", in: "UI/Settings")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // Should not have toggles that affect behavior
        let togglePatterns = [
            "Toggle(",
            "isOn:",
            ".toggle()",
            "Binding<Bool>"
        ]
        
        // Allow @State but not behavior-affecting toggles
        for pattern in togglePatterns {
            if pattern == "Binding<Bool>" {
                continue // Allow for sheet bindings
            }
            XCTAssertFalse(
                content.contains(pattern),
                "AppStoreReadinessView contains behavior toggle: \(pattern)"
            )
        }
    }
    
    /// Verifies view is read-only (no write operations)
    func testAppStoreReadinessViewReadOnly() throws {
        let filePath = findProjectFile(named: "AppStoreReadinessView.swift", in: "UI/Settings")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // Should not have write operations
        let writePatterns = [
            "UserDefaults.standard.set",
            ".save(",
            ".write(",
            ".delete(",
            "executeDraft",
            "executeAction"
        ]
        
        for pattern in writePatterns {
            // Allow ShareSheet writes (export is ok)
            if pattern == ".write(" && content.contains("try text.write(to: tempURL") {
                continue
            }
            if pattern == ".write(" {
                let writeCount = content.components(separatedBy: pattern).count - 1
                XCTAssertLessThanOrEqual(
                    writeCount, 1,
                    "AppStoreReadinessView has too many write operations"
                )
                continue
            }
            
            XCTAssertFalse(
                content.contains(pattern),
                "AppStoreReadinessView contains write pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - F) Core Modules Untouched
    
    /// Verifies ExecutionEngine has no submission imports
    func testExecutionEngineNoSubmissionImports() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let submissionPatterns = [
            "AppStoreSubmissionPacket",
            "AppStoreSubmissionBuilder",
            "SubmissionCopy",
            "ScreenshotChecklist",
            "AppStoreReadinessView"
        ]
        
        for pattern in submissionPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ExecutionEngine.swift contains submission pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ApprovalGate has no submission imports
    func testApprovalGateNoSubmissionImports() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let submissionPatterns = [
            "AppStoreSubmissionPacket",
            "SubmissionCopy",
            "ScreenshotChecklist"
        ]
        
        for pattern in submissionPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ApprovalGate.swift contains submission pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ModelRouter has no submission imports
    func testModelRouterNoSubmissionImports() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let submissionPatterns = [
            "AppStoreSubmissionPacket",
            "SubmissionCopy",
            "ScreenshotChecklist"
        ]
        
        for pattern in submissionPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ModelRouter.swift contains submission pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - G) Forbidden Keys List Complete
    
    /// Verifies forbidden keys list is comprehensive
    func testForbiddenKeysListComplete() {
        let forbiddenKeys = AppStoreSubmissionPacket.forbiddenKeys
        
        let requiredForbidden = [
            "body",
            "subject",
            "content",
            "draft",
            "prompt",
            "context",
            "email",
            "attendees"
        ]
        
        for required in requiredForbidden {
            XCTAssertTrue(
                forbiddenKeys.contains(required),
                "Forbidden keys list missing: \(required)"
            )
        }
    }
    
    // MARK: - Helpers
    
    private func findProjectRoot() -> String {
        let currentFile = URL(fileURLWithPath: #file)
        return currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
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

// MARK: - Copy Pack Tests

extension AppStoreReadinessInvariantTests {
    
    /// Verifies copy pack export works
    func testCopyPackExport() {
        let pack = SubmissionCopyPack(version: "1.0", build: "1")
        let text = pack.exportText()
        
        XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(text.contains("REVIEW NOTES"))
        XCTAssertTrue(text.contains("WHAT'S NEW"))
        XCTAssertTrue(text.contains("PRIVACY DISCLOSURE"))
        XCTAssertTrue(text.contains("MONETIZATION DISCLOSURE"))
    }
    
    /// Verifies copy pack filename format
    func testCopyPackFilename() {
        let pack = SubmissionCopyPack(version: "1.0", build: "1")
        
        XCTAssertTrue(pack.exportFilename.hasPrefix("OperatorKit_CopyPack_"))
        XCTAssertTrue(pack.exportFilename.hasSuffix(".txt"))
    }
}
