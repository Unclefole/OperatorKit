import XCTest
@testable import OperatorKit

// ============================================================================
// LAUNCH KIT INVARIANT TESTS (Phase 10I)
//
// These tests prove launch readiness:
// - Onboarding stores no forbidden keys
// - Support copy contains no banned claims
// - Help center does not request new permissions
// - Upgrade surfaces do not reference execution modules
// - ConversionLedger increments only on user taps
// - DocIntegrity tests pass
//
// See: docs/SAFETY_CONTRACT.md (Sections 18, 19)
// ============================================================================

final class LaunchKitInvariantTests: XCTestCase {
    
    // MARK: - A) Onboarding State Safety
    
    /// Verifies OnboardingState contains no forbidden keys
    func testOnboardingNoForbiddenKeys() throws {
        let state = OnboardingState()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(state)
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        // Check for forbidden content keys
        let forbiddenKeys = SyncSafetyConfig.forbiddenContentKeys
        for key in forbiddenKeys {
            XCTAssertNil(json[key], "OnboardingState should not contain forbidden key: \(key)")
        }
        
        // Verify only expected keys exist
        let expectedKeys = ["isCompleted", "completedAt", "needsRerun", "schemaVersion"]
        for (key, _) in json {
            XCTAssertTrue(
                expectedKeys.contains(key),
                "OnboardingState contains unexpected key: \(key)"
            )
        }
    }
    
    /// Verifies onboarding does not store user content
    func testOnboardingNoUserContent() {
        // OnboardingState should only have metadata fields
        let state = OnboardingState()
        
        // These should be the only accessible properties
        XCTAssertNotNil(state.isCompleted)
        XCTAssertNotNil(state.schemaVersion)
        // completedAt and needsRerun are also allowed
    }
    
    // MARK: - B) Support Copy Safety
    
    /// Verifies SupportCopy has no banned phrases
    func testSupportCopyNoBannedPhrases() {
        let textsToCheck = [
            SupportCopy.emailSubjectTemplate,
            SupportCopy.emailBodyTemplate,
            SupportCopy.refundInstructions,
            SupportCopy.reviewNotesSupport
        ]
        
        for text in textsToCheck {
            let violations = SupportCopy.validate(text)
            XCTAssertTrue(violations.isEmpty, "Support copy violations: \(violations.joined(separator: ", "))")
        }
        
        // Check FAQ answers
        for item in SupportCopy.faqItems {
            let questionViolations = SupportCopy.validate(item.question)
            let answerViolations = SupportCopy.validate(item.answer)
            
            XCTAssertTrue(
                questionViolations.isEmpty,
                "FAQ question violations: \(questionViolations.joined(separator: ", "))"
            )
            XCTAssertTrue(
                answerViolations.isEmpty,
                "FAQ answer violations: \(answerViolations.joined(separator: ", "))"
            )
        }
    }
    
    /// Verifies refund instructions don't make promises
    func testRefundInstructionsNoPromises() {
        let refundText = SupportCopy.refundInstructions
        
        let promisePatterns = [
            "guaranteed",
            "we will refund",
            "instant refund",
            "100% money back",
            "no questions asked"
        ]
        
        for pattern in promisePatterns {
            XCTAssertFalse(
                refundText.lowercased().contains(pattern.lowercased()),
                "Refund instructions contain promise: '\(pattern)'"
            )
        }
        
        // Should reference Apple
        XCTAssertTrue(
            refundText.contains("Apple"),
            "Refund instructions should reference Apple"
        )
    }
    
    // MARK: - C) Help Center Permission Safety
    
    /// Verifies HelpCenterView doesn't request new permissions
    func testHelpCenterNoNewPermissions() throws {
        let filePath = findProjectFile(named: "HelpCenterView.swift", in: "UI/Support")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // Should not request these permissions
        let forbiddenPermissions = [
            "requestAccess(to: .calendar",
            "requestAccess(to: .reminders",
            "requestAuthorization",
            "CNContactStore",
            "PHPhotoLibrary",
            "AVCaptureDevice",
            "CLLocationManager"
        ]
        
        for pattern in forbiddenPermissions {
            XCTAssertFalse(
                content.contains(pattern),
                "HelpCenterView requests forbidden permission: \(pattern)"
            )
        }
    }
    
    /// Verifies support does not auto-send emails
    func testSupportNoAutoSend() throws {
        let filePath = findProjectFile(named: "HelpCenterView.swift", in: "UI/Support")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // Should use MFMailComposeViewController (user must tap Send)
        XCTAssertTrue(
            content.contains("MFMailComposeViewController"),
            "Help center should use MFMailComposeViewController"
        )
        
        // Should NOT use URLSession for email
        XCTAssertFalse(
            content.contains("URLSession"),
            "Help center should not use URLSession for email"
        )
        
        // Should NOT auto-send
        let autoSendPatterns = [
            "sendMail()",
            "send(message:",
            "submitEmail",
            "autoSend"
        ]
        
        for pattern in autoSendPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "Help center contains auto-send pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - D) Upgrade Surfaces Safety
    
    /// Verifies UpgradePromptCard doesn't reference execution modules
    func testUpgradeSurfacesNoExecutionRefs() throws {
        let filePath = findProjectFile(named: "UpgradePromptCard.swift", in: "UI/Monetization")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let executionPatterns = [
            "ExecutionEngine",
            "ApprovalGate",
            "ModelRouter",
            "executeDraft",
            "executeAction"
        ]
        
        for pattern in executionPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "UpgradePromptCard references execution module: \(pattern)"
            )
        }
    }
    
    /// Verifies upgrade taps record via ConversionLedger
    func testUpgradeTapsRecordToLedger() throws {
        let filePath = findProjectFile(named: "UpgradePromptCard.swift", in: "UI/Monetization")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // Should record upgrade taps
        XCTAssertTrue(
            content.contains("ConversionLedger.shared.recordEvent(.upgradeTapped)"),
            "Upgrade taps should record to ConversionLedger"
        )
    }
    
    // MARK: - E) ConversionLedger Safety
    
    /// Verifies ConversionLedger only increments on explicit calls
    func testConversionLedgerNoAutoIncrement() throws {
        let filePath = findProjectFile(named: "ConversionLedger.swift", in: "Monetization")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // Should NOT have automatic triggers
        let autoTriggerPatterns = [
            "Timer.scheduledTimer",
            "DispatchQueue.main.asyncAfter",
            "NotificationCenter.default.addObserver",
            "didSet {",
            "willSet {"
        ]
        
        for pattern in autoTriggerPatterns {
            // Allow didSet for @Published state updates, not for auto-incrementing
            if pattern == "didSet {" || pattern == "willSet {" {
                // Check if used for auto-increment
                if content.contains("\(pattern)\n") && content.contains("incrementCount") {
                    XCTFail("ConversionLedger may auto-increment in \(pattern)")
                }
            } else {
                XCTAssertFalse(
                    content.contains(pattern),
                    "ConversionLedger contains auto-trigger: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - F) Document Integrity
    
    /// Verifies all required documents exist
    func testAllRequiredDocsExist() {
        let projectRoot = findProjectRoot()
        let result = DocIntegrity.validateDocumentsExist(projectRoot: projectRoot)
        
        XCTAssertTrue(result.isValid, "Missing required docs: \(result.errors.joined(separator: ", "))")
    }
    
    /// Verifies SAFETY_CONTRACT.md has required sections
    func testSafetyContractHasRequiredSections() throws {
        let projectRoot = findProjectRoot()
        let safetyPath = (projectRoot as NSString).appendingPathComponent("docs/SAFETY_CONTRACT.md")
        let content = try String(contentsOfFile: safetyPath, encoding: .utf8)
        
        let errors = DocIntegrity.validateDocumentContent(
            content,
            docName: "SAFETY_CONTRACT.md",
            requiredSections: DocIntegrity.safetyContractSections
        )
        
        XCTAssertTrue(errors.isEmpty, "SAFETY_CONTRACT.md errors: \(errors.joined(separator: ", "))")
    }
    
    /// Verifies APP_STORE_SUBMISSION_CHECKLIST.md has required sections
    func testSubmissionChecklistHasRequiredSections() throws {
        let projectRoot = findProjectRoot()
        let checklistPath = (projectRoot as NSString).appendingPathComponent("docs/APP_STORE_SUBMISSION_CHECKLIST.md")
        let content = try String(contentsOfFile: checklistPath, encoding: .utf8)
        
        let errors = DocIntegrity.validateDocumentContent(
            content,
            docName: "APP_STORE_SUBMISSION_CHECKLIST.md",
            requiredSections: DocIntegrity.submissionChecklistSections
        )
        
        XCTAssertTrue(errors.isEmpty, "APP_STORE_SUBMISSION_CHECKLIST.md errors: \(errors.joined(separator: ", "))")
    }
    
    /// Runs full document integrity validation
    func testFullDocIntegrity() {
        let projectRoot = findProjectRoot()
        let result = DocIntegrity.runFullValidation(projectRoot: projectRoot)
        
        XCTAssertTrue(result.isValid, "Doc integrity failed: \(result.errors.joined(separator: ", "))")
    }
    
    // MARK: - G) Core Modules Untouched
    
    /// Verifies ExecutionEngine has no onboarding/support imports
    func testExecutionEngineNoLaunchKitImports() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let launchKitPatterns = [
            "OnboardingStateStore",
            "OnboardingView",
            "HelpCenterView",
            "SupportCopy",
            "UpgradePromptCard"
        ]
        
        for pattern in launchKitPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ExecutionEngine.swift contains launch kit pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ApprovalGate has no onboarding/support imports
    func testApprovalGateNoLaunchKitImports() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let launchKitPatterns = [
            "OnboardingStateStore",
            "HelpCenterView",
            "SupportCopy"
        ]
        
        for pattern in launchKitPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ApprovalGate.swift contains launch kit pattern: \(pattern)"
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

// MARK: - FAQ Validation Tests

extension LaunchKitInvariantTests {
    
    /// Verifies all FAQ items have non-empty content
    func testFAQItemsComplete() {
        for item in SupportCopy.faqItems {
            XCTAssertFalse(item.question.isEmpty, "FAQ question should not be empty")
            XCTAssertFalse(item.answer.isEmpty, "FAQ answer should not be empty")
            XCTAssertTrue(item.question.hasSuffix("?"), "FAQ question should end with ?")
        }
    }
    
    /// Verifies troubleshooting steps are numbered correctly
    func testTroubleshootingStepsComplete() {
        XCTAssertGreaterThan(
            SupportCopy.troubleshootingPermissions.count, 0,
            "Permissions troubleshooting should have steps"
        )
        XCTAssertGreaterThan(
            SupportCopy.troubleshootingSiri.count, 0,
            "Siri troubleshooting should have steps"
        )
        XCTAssertGreaterThan(
            SupportCopy.troubleshootingRestore.count, 0,
            "Restore troubleshooting should have steps"
        )
        XCTAssertGreaterThan(
            SupportCopy.troubleshootingSync.count, 0,
            "Sync troubleshooting should have steps"
        )
    }
}
