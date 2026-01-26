import Foundation

// ============================================================================
// PROCUREMENT EMAIL TEMPLATES (Phase 10N)
//
// Static email templates for B2B procurement workflows.
// Pure strings with placeholders only, no identifiers.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user identifiers
// ❌ No device identifiers
// ❌ No auto-send
// ❌ No anthropomorphic language
// ✅ Static templates
// ✅ Placeholders only
// ✅ User controls send
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

public enum ProcurementEmailTemplates {
    
    /// Schema version
    public static let schemaVersion = 1
    
    // MARK: - Templates
    
    /// Security review request template
    public static let securityReview = """
    Hello,
    
    I am conducting a security review of OperatorKit for potential deployment at [Your Organization].
    
    Please provide:
    - Security architecture documentation
    - Data handling practices
    - Privacy policy details
    - Compliance certifications (if any)
    
    Organization: [Your Organization]
    Contact: [Your Name]
    Role: [Your Role]
    
    Thank you.
    """
    
    /// Pilot proposal template
    public static let pilotProposal = """
    Hello,
    
    I would like to propose a pilot deployment of OperatorKit at [Your Organization].
    
    Pilot Details:
    - Number of users: [Number]
    - Duration: [Duration]
    - Use case: [Brief description]
    
    We have reviewed the Enterprise Readiness packet and would like to discuss next steps.
    
    Organization: [Your Organization]
    Contact: [Your Name]
    Role: [Your Role]
    
    Thank you.
    """
    
    /// Invoice request template
    public static let invoiceRequest = """
    Hello,
    
    I would like to request an invoice for OperatorKit Team tier subscription.
    
    Billing Details:
    - Organization: [Your Organization]
    - Billing contact: [Contact Name]
    - Billing email: [Billing Email]
    - Number of seats: [Number]
    - Billing cycle: [Monthly/Annual]
    
    Please include payment instructions in the invoice.
    
    Thank you.
    """
    
    // MARK: - Template Info
    
    public struct TemplateInfo: Identifiable {
        public let id: String
        public let name: String
        public let templateDescription: String
        public let emailAddress: String
        public let subject: String
        public let body: String
        public let icon: String
    }
    
    /// All available templates
    public static let allTemplates: [TemplateInfo] = [
        TemplateInfo(
            id: "security-review",
            name: "Security Review",
            templateDescription: "Request security documentation for review",
            emailAddress: "security@operatorkit.app",
            subject: "Security Review Request - [Organization]",
            body: securityReview,
            icon: "shield"
        ),
        TemplateInfo(
            id: "pilot-proposal",
            name: "Pilot Proposal",
            templateDescription: "Propose a team pilot deployment",
            emailAddress: "team@operatorkit.app",
            subject: "Pilot Proposal - [Organization]",
            body: pilotProposal,
            icon: "airplane"
        ),
        TemplateInfo(
            id: "invoice-request",
            name: "Invoice Request",
            templateDescription: "Request an invoice for team subscription",
            emailAddress: "billing@operatorkit.app",
            subject: "Invoice Request - [Organization]",
            body: invoiceRequest,
            icon: "doc.text"
        )
    ]
    
    /// Gets a template by ID
    public static func template(byId id: String) -> TemplateInfo? {
        allTemplates.first { $0.id == id }
    }
    
    // MARK: - Validation
    
    /// Banned words that must not appear in templates
    public static let bannedWords: [String] = [
        "ai thinks", "ai learns", "ai decides", "ai understands",
        "secure", "encrypted", "protected",
        "monitors", "tracks", "watches",
        "automatically sends", "auto-send"
    ]
    
    /// Validates templates have no banned words
    public static func validateNoBannedWords() -> [String] {
        var violations: [String] = []
        
        let allContent = [securityReview, pilotProposal, invoiceRequest].joined(separator: " ")
        let lowercased = allContent.lowercased()
        
        for banned in bannedWords {
            if lowercased.contains(banned) {
                violations.append("Templates contain banned word: '\(banned)'")
            }
        }
        
        return violations
    }
    
    /// Validates templates have no identifiers
    public static func validateNoIdentifiers() -> [String] {
        var violations: [String] = []
        
        let identifierPatterns = [
            "deviceId", "device_id", "userId", "user_id",
            "UDID", "IMEI", "serialNumber", "serial_number",
            "receipt", "transactionId", "transaction_id",
            "UUID"
        ]
        
        let allContent = [securityReview, pilotProposal, invoiceRequest].joined(separator: " ")
        
        for pattern in identifierPatterns {
            if allContent.contains(pattern) {
                violations.append("Templates contain identifier: '\(pattern)'")
            }
        }
        
        return violations
    }
}
