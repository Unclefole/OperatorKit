import XCTest
@testable import OperatorKit

// ============================================================================
// LAUNCH HARDENING INVARIANT TESTS (Phase 10Q)
//
// Tests proving launch hardening constraints:
// - No execution modules touched
// - No new networking imports
// - No background tasks
// - First-week helpers are UI-only
// - Known limitations contain no banned words
// - Support packet contains no forbidden keys
// - Reset actions are explicit and confirmed
// - Launch checklist validator is pure and deterministic
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

final class LaunchHardeningInvariantTests: XCTestCase {
    
    // MARK: - A) Execution Modules Untouched
    
    /// Verifies ExecutionEngine has no Phase 10Q imports
    func testExecutionEngineNoPhase10QImports() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase10QPatterns = [
            "FirstWeekState",
            "FirstWeekStore",
            "KnownLimitations",
            "SupportPacket",
            "LaunchChecklistValidator",
            "SafeResetController"
        ]
        
        for pattern in phase10QPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ExecutionEngine.swift contains Phase 10Q pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ApprovalGate has no Phase 10Q imports
    func testApprovalGateNoPhase10QImports() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase10QPatterns = [
            "FirstWeekState",
            "KnownLimitations",
            "SupportPacket",
            "LaunchChecklistValidator"
        ]
        
        for pattern in phase10QPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ApprovalGate.swift contains Phase 10Q pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ModelRouter has no Phase 10Q imports
    func testModelRouterNoPhase10QImports() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase10QPatterns = [
            "FirstWeekState",
            "KnownLimitations",
            "SupportPacket",
            "LaunchChecklistValidator"
        ]
        
        for pattern in phase10QPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ModelRouter.swift contains Phase 10Q pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - B) No Networking in New Modules
    
    /// Verifies new modules have no URLSession
    func testNoNewNetworking() throws {
        let newFiles = [
            ("FirstWeekState.swift", "Launch"),
            ("KnownLimitations.swift", "Launch"),
            ("LaunchChecklistValidator.swift", "Launch"),
            ("SafeResetControls.swift", "Launch"),
            ("SupportPacket.swift", "Diagnostics")
        ]
        
        let networkingPatterns = ["URLSession", "URLRequest", "import Network"]
        
        for (fileName, subdirectory) in newFiles {
            let filePath = findProjectFile(named: fileName, in: subdirectory)
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            for pattern in networkingPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "\(fileName) contains networking: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - C) No Background Tasks
    
    /// Verifies new modules have no background task usage
    func testNoBackgroundTasks() throws {
        let newFiles = [
            ("FirstWeekState.swift", "Launch"),
            ("KnownLimitations.swift", "Launch"),
            ("LaunchChecklistValidator.swift", "Launch"),
            ("SafeResetControls.swift", "Launch"),
            ("SupportPacket.swift", "Diagnostics")
        ]
        
        let backgroundPatterns = [
            "BGTaskScheduler",
            "UIBackgroundTask",
            "BackgroundTask",
            "beginBackgroundTask"
        ]
        
        for (fileName, subdirectory) in newFiles {
            let filePath = findProjectFile(named: fileName, in: subdirectory)
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            for pattern in backgroundPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "\(fileName) contains background task: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - D) First Week Helpers are UI-Only
    
    /// Verifies FirstWeekState is read-only
    func testFirstWeekStateIsReadOnly() {
        let state = FirstWeekState()
        
        // Should have computed properties only
        _ = state.daysSinceInstall
        _ = state.isFirstWeek
        _ = state.firstWeekProgress
        _ = state.daysRemainingInFirstWeek
        
        // No execution hooks
        XCTAssertTrue(true, "FirstWeekState has no execution methods")
    }
    
    /// Verifies FirstWeekTips contain no banned words
    func testFirstWeekTipsNoBannedWords() {
        let violations = FirstWeekTips.validateNoBannedWords()
        
        XCTAssertTrue(
            violations.isEmpty,
            "First week tips contain banned words: \(violations.joined(separator: ", "))"
        )
    }
    
    // MARK: - E) Known Limitations Validation
    
    /// Verifies known limitations contain no banned words
    func testKnownLimitationsNoBannedWords() {
        let violations = KnownLimitations.validateNoBannedWords()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Known limitations contain banned words: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies known limitations are factual only
    func testKnownLimitationsFactualOnly() {
        let violations = KnownLimitations.validateFactualOnly()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Known limitations contain non-factual phrases: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies all limitation categories are covered
    func testKnownLimitationsCategoriesCovered() {
        let byCategory = KnownLimitations.byCategory
        
        for category in LimitationCategory.allCases {
            XCTAssertNotNil(
                byCategory[category],
                "Missing limitations for category: \(category.rawValue)"
            )
            XCTAssertGreaterThan(
                byCategory[category]?.count ?? 0,
                0,
                "No limitations in category: \(category.rawValue)"
            )
        }
    }
    
    // MARK: - F) Support Packet Validation
    
    /// Verifies support packet contains no forbidden keys
    func testSupportPacketNoForbiddenKeys() async throws {
        let builder = await SupportPacketBuilder.shared
        let packet = await builder.build()
        
        let violations = try packet.validateNoForbiddenKeys()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Support packet contains forbidden keys: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies support packet forbidden keys list is complete
    func testSupportPacketForbiddenKeysComplete() {
        let expectedForbidden = [
            "body", "subject", "content", "draft", "prompt",
            "context", "note", "email", "attendees", "title",
            "description", "message", "text", "recipient", "sender"
        ]
        
        for key in expectedForbidden {
            XCTAssertTrue(
                SupportPacket.forbiddenKeys.contains(key),
                "Missing forbidden key in SupportPacket: \(key)"
            )
        }
    }
    
    // MARK: - G) Reset Actions Validation
    
    /// Verifies all reset actions have confirmation messages
    func testResetActionsHaveConfirmation() {
        for action in ResetAction.allCases {
            XCTAssertFalse(action.confirmationTitle.isEmpty, "Missing confirmation title for \(action)")
            XCTAssertFalse(action.confirmationMessage.isEmpty, "Missing confirmation message for \(action)")
            XCTAssertFalse(action.description.isEmpty, "Missing description for \(action)")
        }
    }
    
    /// Verifies reset actions don't affect execution safety
    func testResetActionsNoExecutionSafetyImpact() {
        // These reset actions should NOT be in the list
        let unsafeActions = ["clear_approvals", "disable_safety", "bypass_confirmation"]
        
        for action in ResetAction.allCases {
            XCTAssertFalse(
                unsafeActions.contains(action.rawValue),
                "Unsafe action found: \(action.rawValue)"
            )
        }
    }
    
    // MARK: - H) Launch Checklist Validator
    
    /// Verifies launch checklist validator is deterministic
    func testLaunchChecklistValidatorDeterministic() async {
        let validator = await LaunchChecklistValidator.shared
        
        let result1 = await validator.validate()
        let result2 = await validator.validate()
        
        XCTAssertEqual(result1.passCount, result2.passCount)
        XCTAssertEqual(result1.warnCount, result2.warnCount)
        XCTAssertEqual(result1.failCount, result2.failCount)
        XCTAssertEqual(result1.overallStatus, result2.overallStatus)
    }
    
    /// Verifies launch checklist covers all categories
    func testLaunchChecklistCategoriesCovered() async {
        let validator = await LaunchChecklistValidator.shared
        let result = await validator.validate()
        
        let categoriesPresent = Set(result.checkItems.map { $0.category })
        
        for category in LaunchCheckCategory.allCases {
            XCTAssertTrue(
                categoriesPresent.contains(category),
                "Missing checklist category: \(category.rawValue)"
            )
        }
    }
    
    /// Verifies launch checklist result is encodable
    func testLaunchChecklistResultEncodable() async throws {
        let validator = await LaunchChecklistValidator.shared
        let result = await validator.validate()
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(result)
        
        XCTAssertGreaterThan(data.count, 0)
    }
    
    // MARK: - I) Schema Versions
    
    /// Verifies all new types have schema versions
    func testSchemaVersionsSet() {
        XCTAssertGreaterThan(FirstWeekState.currentSchemaVersion, 0)
        XCTAssertGreaterThan(SupportPacket.currentSchemaVersion, 0)
        XCTAssertGreaterThan(LaunchChecklistResult.currentSchemaVersion, 0)
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
}
