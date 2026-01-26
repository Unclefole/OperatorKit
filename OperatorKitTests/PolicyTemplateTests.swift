import XCTest
@testable import OperatorKit

// ============================================================================
// POLICY TEMPLATE TESTS (Phase 10M)
//
// Tests for policy templates:
// - Templates are conservative
// - Templates contain no forbidden keys
// - Apply template requires confirmation
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

final class PolicyTemplateTests: XCTestCase {
    
    // MARK: - A) Templates Are Conservative
    
    /// Verifies default templates are conservative
    func testTemplatesAreConservative() {
        let templates = PolicyTemplateStore.defaultTemplates
        
        // All templates should require explicit confirmation
        for template in templates {
            XCTAssertTrue(
                template.policyPayload.requireExplicitConfirmation,
                "Template '\(template.name)' should require explicit confirmation"
            )
        }
        
        // Conservative template should have strictest settings
        let conservative = templates.first { $0.id == "template-conservative" }
        XCTAssertNotNil(conservative)
        
        if let conservative = conservative {
            XCTAssertFalse(conservative.policyPayload.allowCalendarWrites, "Conservative should not allow calendar writes")
            XCTAssertFalse(conservative.policyPayload.allowTaskCreation, "Conservative should not allow task creation")
            XCTAssertNotNil(conservative.policyPayload.maxExecutionsPerDay, "Conservative should have execution limit")
            XCTAssertTrue(conservative.policyPayload.localProcessingOnly, "Conservative should be local-only")
        }
        
        // Read-only template should be most restrictive
        let readOnly = templates.first { $0.id == "template-read-only" }
        XCTAssertNotNil(readOnly)
        
        if let readOnly = readOnly {
            XCTAssertFalse(readOnly.policyPayload.allowCalendarWrites)
            XCTAssertFalse(readOnly.policyPayload.allowTaskCreation)
            XCTAssertFalse(readOnly.policyPayload.allowMemoryWrites)
        }
    }
    
    /// Verifies all templates have execution limits or explicit confirmation
    func testTemplatesHaveSafetyGuards() {
        for template in PolicyTemplateStore.defaultTemplates {
            // Every template must have at least one safety guard
            let hasSafetyGuard = template.policyPayload.requireExplicitConfirmation ||
                                 template.policyPayload.maxExecutionsPerDay != nil ||
                                 template.policyPayload.localProcessingOnly
            
            XCTAssertTrue(
                hasSafetyGuard,
                "Template '\(template.name)' has no safety guards"
            )
        }
    }
    
    // MARK: - B) No Forbidden Keys
    
    /// Verifies templates contain no forbidden keys
    func testTemplatesContainNoForbiddenKeys() throws {
        for template in PolicyTemplateStore.defaultTemplates {
            let violations = try template.validateNoForbiddenKeys()
            
            XCTAssertTrue(
                violations.isEmpty,
                "Template '\(template.name)' contains forbidden keys: \(violations.joined(separator: ", "))"
            )
        }
    }
    
    /// Verifies policy payload has no content fields
    func testPolicyPayloadHasNoContentFields() {
        let payload = PolicyPayload.standard()
        
        // Encode and check keys
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to encode payload")
            return
        }
        
        let forbiddenKeys = [
            "body", "subject", "content", "draft", "prompt",
            "context", "note", "email", "text", "message"
        ]
        
        for key in json.keys {
            XCTAssertFalse(
                forbiddenKeys.contains(key.lowercased()),
                "PolicyPayload contains forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - C) Template Conversion
    
    /// Verifies template converts to OperatorPolicy correctly
    func testTemplateConversion() {
        let template = PolicyTemplateStore.defaultTemplates.first!
        let policy = template.toOperatorPolicy()
        
        XCTAssertTrue(policy.enabled)
        XCTAssertEqual(policy.allowEmailDrafts, template.policyPayload.allowEmailDrafts)
        XCTAssertEqual(policy.allowCalendarWrites, template.policyPayload.allowCalendarWrites)
        XCTAssertEqual(policy.allowTaskCreation, template.policyPayload.allowTaskCreation)
        XCTAssertEqual(policy.requireExplicitConfirmation, template.policyPayload.requireExplicitConfirmation)
    }
    
    // MARK: - D) Store Operations
    
    /// Verifies default templates are loaded
    func testDefaultTemplatesAreLoaded() async {
        let store = await PolicyTemplateStore.shared
        let templates = await store.templates
        
        XCTAssertGreaterThanOrEqual(templates.count, 4, "Should have at least 4 default templates")
        
        // Check all default templates are present
        let defaultIds = PolicyTemplateStore.defaultTemplates.map { $0.id }
        for id in defaultIds {
            XCTAssertTrue(
                templates.contains { $0.id == id },
                "Missing default template: \(id)"
            )
        }
    }
    
    /// Verifies template lookup works
    func testTemplateLookup() async {
        let store = await PolicyTemplateStore.shared
        
        let conservative = await store.template(byId: "template-conservative")
        XCTAssertNotNil(conservative)
        XCTAssertEqual(conservative?.name, "Conservative")
        
        let notFound = await store.template(byId: "nonexistent")
        XCTAssertNil(notFound)
    }
    
    // MARK: - E) Schema
    
    /// Verifies schema version is set
    func testSchemaVersionIsSet() {
        XCTAssertGreaterThan(PolicyTemplate.currentSchemaVersion, 0)
        
        for template in PolicyTemplateStore.defaultTemplates {
            XCTAssertEqual(template.schemaVersion, PolicyTemplate.currentSchemaVersion)
        }
    }
}
