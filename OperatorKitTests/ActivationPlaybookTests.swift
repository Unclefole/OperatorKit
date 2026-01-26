import XCTest
@testable import OperatorKit

// ============================================================================
// ACTIVATION PLAYBOOK TESTS (Phase 10N)
//
// Tests for activation playbook:
// - No forbidden keys
// - Prefill strings are static and generic
// - All steps have required fields
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class ActivationPlaybookTests: XCTestCase {
    
    // MARK: - A) No Forbidden Keys
    
    /// Verifies playbook steps contain no forbidden keys
    func testPlaybookNoForbiddenKeys() throws {
        let violations = try ActivationPlaybook.validateNoForbiddenKeys()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Playbook contains forbidden keys: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies all forbidden keys are checked
    func testForbiddenKeysListIsComplete() {
        let expectedForbidden = [
            "body", "subject", "content", "draft", "prompt",
            "context", "note", "email", "attendees", "title",
            "description", "message", "text", "recipient", "sender"
        ]
        
        for key in expectedForbidden {
            XCTAssertTrue(
                ActivationPlaybook.forbiddenKeys.contains(key),
                "Missing forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - B) Static and Generic Prefill Strings
    
    /// Verifies sample intents are static and generic
    func testSampleIntentsAreGeneric() {
        for step in ActivationPlaybook.steps {
            // Should not contain personal identifiers
            XCTAssertFalse(
                step.sampleIntent.contains("@"),
                "Step \(step.id) contains email-like pattern"
            )
            
            // Should not contain specific names
            XCTAssertFalse(
                step.sampleIntent.lowercased().contains("john"),
                "Step \(step.id) contains specific name"
            )
            
            // Should be generic
            XCTAssertTrue(
                step.sampleIntent.count > 10,
                "Step \(step.id) has too short sample intent"
            )
        }
    }
    
    /// Verifies sample intents don't contain user identifiers
    func testSampleIntentsNoIdentifiers() {
        let identifierPatterns = [
            "userId", "deviceId", "UUID", "email@",
            "phone:", "555-", "1-800"
        ]
        
        for step in ActivationPlaybook.steps {
            for pattern in identifierPatterns {
                XCTAssertFalse(
                    step.sampleIntent.contains(pattern),
                    "Step \(step.id) contains identifier pattern: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - C) Steps Completeness
    
    /// Verifies all steps have required fields
    func testStepsHaveRequiredFields() {
        XCTAssertEqual(ActivationPlaybook.steps.count, 3, "Should have 3 steps")
        
        for step in ActivationPlaybook.steps {
            XCTAssertFalse(step.id.isEmpty, "Step has empty ID")
            XCTAssertFalse(step.title.isEmpty, "Step \(step.id) has empty title")
            XCTAssertFalse(step.stepDescription.isEmpty, "Step \(step.id) has empty description")
            XCTAssertFalse(step.sampleIntent.isEmpty, "Step \(step.id) has empty sample intent")
            XCTAssertFalse(step.icon.isEmpty, "Step \(step.id) has empty icon")
            XCTAssertGreaterThan(step.stepNumber, 0, "Step \(step.id) has invalid step number")
        }
    }
    
    /// Verifies step lookup works
    func testStepLookup() {
        let step = ActivationPlaybook.step(byId: "activation-step-1")
        XCTAssertNotNil(step)
        XCTAssertEqual(step?.stepNumber, 1)
        
        let notFound = ActivationPlaybook.step(byId: "nonexistent")
        XCTAssertNil(notFound)
    }
    
    // MARK: - D) State Store
    
    /// Verifies state store works correctly
    func testStateStoreProgress() async {
        let store = await ActivationStateStore.shared
        
        // Reset first
        await store.reset()
        
        var progress = await store.progress
        XCTAssertEqual(progress, 0)
        
        // Mark first step
        await store.markStepCompleted("activation-step-1")
        progress = await store.progress
        XCTAssertGreaterThan(progress, 0)
        
        // Reset
        await store.reset()
    }
    
    // MARK: - E) Schema
    
    /// Verifies schema version is set
    func testSchemaVersionIsSet() {
        XCTAssertGreaterThan(ActivationPlaybook.schemaVersion, 0)
    }
}
