import XCTest
@testable import OperatorKit

// ============================================================================
// OUTCOME TEMPLATE TESTS (Phase 10O)
//
// Tests for outcome templates:
// - No forbidden keys
// - Templates are static + generic
// - No banned words / anthropomorphic / security claims
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class OutcomeTemplateTests: XCTestCase {
    
    // MARK: - A) No Forbidden Keys
    
    /// Verifies templates contain no forbidden keys in JSON
    func testTemplatesNoForbiddenKeys() throws {
        let violations = try OutcomeTemplates.validateNoForbiddenKeys()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Templates contain forbidden keys: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies forbidden keys list is complete
    func testForbiddenKeysListIsComplete() {
        let expectedForbidden = [
            "body", "subject", "content", "draft", "prompt",
            "context", "note", "email", "attendees", "title",
            "description", "message", "text", "recipient", "sender"
        ]
        
        for key in expectedForbidden {
            XCTAssertTrue(
                OutcomeTemplates.forbiddenKeys.contains(key),
                "Missing forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - B) No Banned Words
    
    /// Verifies templates contain no banned/anthropomorphic words
    func testTemplatesNoBannedWords() {
        let violations = OutcomeTemplates.validateNoBannedWords()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Templates contain banned words: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies templates don't have anthropomorphic language
    func testTemplatesNoAnthropomorphicLanguage() {
        let anthropomorphicPatterns = [
            "ai thinks", "ai learns", "ai decides", "ai understands",
            "intelligent", "smart assistant"
        ]
        
        for template in OutcomeTemplates.all {
            let content = "\(template.templateTitle) \(template.sampleIntent)".lowercased()
            
            for pattern in anthropomorphicPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "Template \(template.id) contains anthropomorphic language: '\(pattern)'"
                )
            }
        }
    }
    
    /// Verifies templates don't have security claims
    func testTemplatesNoSecurityClaims() {
        let securityClaims = ["secure", "encrypted", "protected", "safe"]
        
        for template in OutcomeTemplates.all {
            let content = "\(template.templateTitle) \(template.sampleIntent)".lowercased()
            
            for claim in securityClaims {
                XCTAssertFalse(
                    content.contains(claim),
                    "Template \(template.id) contains security claim: '\(claim)'"
                )
            }
        }
    }
    
    // MARK: - C) Static and Generic
    
    /// Verifies templates are static
    func testTemplatesAreStatic() {
        XCTAssertGreaterThanOrEqual(
            OutcomeTemplates.all.count,
            6,
            "Should have at least 6 templates"
        )
        
        // Templates should not change between accesses
        let first = OutcomeTemplates.all
        let second = OutcomeTemplates.all
        
        XCTAssertEqual(first.count, second.count)
        
        for (t1, t2) in zip(first, second) {
            XCTAssertEqual(t1.id, t2.id)
            XCTAssertEqual(t1.sampleIntent, t2.sampleIntent)
        }
    }
    
    /// Verifies sample intents are generic
    func testSampleIntentsAreGeneric() {
        for template in OutcomeTemplates.all {
            // Should not contain email addresses
            XCTAssertFalse(
                template.sampleIntent.contains("@"),
                "Template \(template.id) contains email-like pattern"
            )
            
            // Should not contain specific names
            XCTAssertFalse(
                template.sampleIntent.lowercased().contains("john"),
                "Template \(template.id) contains specific name"
            )
            
            // Should be reasonable length
            XCTAssertGreaterThan(
                template.sampleIntent.count,
                10,
                "Template \(template.id) has too short sample intent"
            )
        }
    }
    
    // MARK: - D) Completeness
    
    /// Verifies all templates have required fields
    func testTemplatesHaveRequiredFields() {
        for template in OutcomeTemplates.all {
            XCTAssertFalse(template.id.isEmpty, "Template has empty ID")
            XCTAssertFalse(template.templateTitle.isEmpty, "Template \(template.id) has empty title")
            XCTAssertFalse(template.sampleIntent.isEmpty, "Template \(template.id) has empty sample intent")
        }
    }
    
    /// Verifies categories are covered
    func testCategoriesAreCovered() {
        let coveredCategories = Set(OutcomeTemplates.all.map { $0.category })
        
        // Should cover at least 4 categories
        XCTAssertGreaterThanOrEqual(
            coveredCategories.count,
            4,
            "Should cover at least 4 categories"
        )
    }
    
    /// Verifies template lookup works
    func testTemplateLookup() {
        let template = OutcomeTemplates.template(byId: "outcome-email-followup")
        XCTAssertNotNil(template)
        XCTAssertEqual(template?.category, .email)
        
        let notFound = OutcomeTemplates.template(byId: "nonexistent")
        XCTAssertNil(notFound)
    }
    
    /// Verifies byCategory grouping works
    func testByCategoryGrouping() {
        let byCategory = OutcomeTemplates.byCategory
        
        XCTAssertGreaterThan(byCategory.count, 0)
        
        for (category, templates) in byCategory {
            for template in templates {
                XCTAssertEqual(template.category, category)
            }
        }
    }
    
    // MARK: - E) Schema
    
    /// Verifies schema version is set
    func testSchemaVersionIsSet() {
        XCTAssertGreaterThan(OutcomeTemplates.schemaVersion, 0)
        
        for template in OutcomeTemplates.all {
            XCTAssertGreaterThan(template.schemaVersion, 0)
        }
    }
}
