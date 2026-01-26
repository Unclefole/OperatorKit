import XCTest
@testable import OperatorKit

// ============================================================================
// PROCUREMENT EMAIL TEMPLATE TESTS (Phase 10N)
//
// Tests for procurement email templates:
// - Templates contain no identifiers
// - Templates contain no banned words
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class ProcurementEmailTemplateTests: XCTestCase {
    
    // MARK: - A) No Identifiers
    
    /// Verifies templates contain no user/device identifiers
    func testTemplatesNoIdentifiers() {
        let violations = ProcurementEmailTemplates.validateNoIdentifiers()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Templates contain identifiers: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies templates use placeholders
    func testTemplatesUsePlaceholders() {
        let templates = [
            ProcurementEmailTemplates.securityReview,
            ProcurementEmailTemplates.pilotProposal,
            ProcurementEmailTemplates.invoiceRequest
        ]
        
        for template in templates {
            XCTAssertTrue(
                template.contains("[Your Organization]"),
                "Template should use organization placeholder"
            )
        }
    }
    
    // MARK: - B) No Banned Words
    
    /// Verifies templates contain no banned/anthropomorphic words
    func testTemplatesNoBannedWords() {
        let violations = ProcurementEmailTemplates.validateNoBannedWords()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Templates contain banned words: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies templates don't claim security features
    func testTemplatesNoSecurityClaims() {
        let templates = [
            ProcurementEmailTemplates.securityReview,
            ProcurementEmailTemplates.pilotProposal,
            ProcurementEmailTemplates.invoiceRequest
        ]
        
        let securityClaims = ["encrypted", "secure your", "protected by", "unhackable"]
        
        for template in templates {
            let lowercased = template.lowercased()
            for claim in securityClaims {
                XCTAssertFalse(
                    lowercased.contains(claim),
                    "Template makes security claim: \(claim)"
                )
            }
        }
    }
    
    // MARK: - C) Template Completeness
    
    /// Verifies all templates have required info
    func testAllTemplatesHaveRequiredInfo() {
        XCTAssertEqual(
            ProcurementEmailTemplates.allTemplates.count,
            3,
            "Should have 3 templates"
        )
        
        for template in ProcurementEmailTemplates.allTemplates {
            XCTAssertFalse(template.id.isEmpty, "Template has empty ID")
            XCTAssertFalse(template.name.isEmpty, "Template \(template.id) has empty name")
            XCTAssertFalse(template.emailAddress.isEmpty, "Template \(template.id) has empty email")
            XCTAssertFalse(template.subject.isEmpty, "Template \(template.id) has empty subject")
            XCTAssertFalse(template.body.isEmpty, "Template \(template.id) has empty body")
            XCTAssertFalse(template.icon.isEmpty, "Template \(template.id) has empty icon")
        }
    }
    
    /// Verifies template lookup works
    func testTemplateLookup() {
        let template = ProcurementEmailTemplates.template(byId: "security-review")
        XCTAssertNotNil(template)
        XCTAssertEqual(template?.name, "Security Review")
        
        let notFound = ProcurementEmailTemplates.template(byId: "nonexistent")
        XCTAssertNil(notFound)
    }
    
    // MARK: - D) Email Addresses
    
    /// Verifies email addresses are valid format
    func testEmailAddressesAreValid() {
        for template in ProcurementEmailTemplates.allTemplates {
            XCTAssertTrue(
                template.emailAddress.contains("@"),
                "Template \(template.id) has invalid email address"
            )
            XCTAssertTrue(
                template.emailAddress.hasSuffix("operatorkit.app"),
                "Template \(template.id) should use operatorkit.app domain"
            )
        }
    }
    
    // MARK: - E) Schema
    
    /// Verifies schema version is set
    func testSchemaVersionIsSet() {
        XCTAssertGreaterThan(ProcurementEmailTemplates.schemaVersion, 0)
    }
}
