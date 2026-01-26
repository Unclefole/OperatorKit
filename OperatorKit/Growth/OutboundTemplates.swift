import Foundation

// ============================================================================
// OUTBOUND TEMPLATES (Phase 11A)
//
// Static email templates for outbound sales.
// Placeholder-based. No auto-filled personal info.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No auto-filled personal info
// ❌ No promises
// ❌ No banned words
// ❌ No anthropomorphic language
// ❌ No "secure/encrypted" claims
// ✅ Placeholder-based only
// ✅ Factual statements
// ✅ User-initiated send
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Outbound Template

public struct OutboundTemplate: Identifiable, Codable, Equatable {
    public let id: String
    public let templateName: String
    public let category: OutboundTemplateCategory
    public let subjectTemplate: String
    public let bodyTemplate: String
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public init(
        id: String,
        templateName: String,
        category: OutboundTemplateCategory,
        subjectTemplate: String,
        bodyTemplate: String
    ) {
        self.id = id
        self.templateName = templateName
        self.category = category
        self.subjectTemplate = subjectTemplate
        self.bodyTemplate = bodyTemplate
        self.schemaVersion = Self.currentSchemaVersion
    }
}

// MARK: - Outbound Template Category

public enum OutboundTemplateCategory: String, Codable, CaseIterable {
    case pilot = "pilot"
    case procurement = "procurement"
    case security = "security"
    case pricing = "pricing"
    case followUp = "follow_up"
    
    public var displayName: String {
        switch self {
        case .pilot: return "Pilot Proposal"
        case .procurement: return "Procurement"
        case .security: return "Security Review"
        case .pricing: return "Pricing & Plans"
        case .followUp: return "Follow-up"
        }
    }
    
    public var icon: String {
        switch self {
        case .pilot: return "airplane"
        case .procurement: return "building.2"
        case .security: return "shield"
        case .pricing: return "dollarsign.circle"
        case .followUp: return "arrow.uturn.right"
        }
    }
}

// MARK: - Outbound Templates Registry

public enum OutboundTemplates {
    
    public static let all: [OutboundTemplate] = [
        // Pilot Proposal
        OutboundTemplate(
            id: "outbound-pilot-proposal",
            templateName: "Pilot Proposal",
            category: .pilot,
            subjectTemplate: "OperatorKit Pilot Proposal for [Organization Name]",
            bodyTemplate: """
            Hello [Contact Name],
            
            I'd like to propose a pilot evaluation of OperatorKit for [Organization Name].
            
            OperatorKit is a draft-first task assistant that runs on-device. Key points:
            
            - All drafts require explicit approval before execution
            - No background processing or monitoring
            - Local-first: data stays on-device unless you choose to sync
            - Full audit trail available for review
            
            Proposed pilot scope:
            - Duration: [X weeks]
            - Team size: [X users]
            - Use cases: [specific workflows]
            
            I can provide a proof packet with quality metrics and safety verification.
            
            Would [date/time] work for a brief walkthrough?
            
            Best,
            [Your Name]
            [Your Title]
            """
        ),
        
        // Procurement Intro
        OutboundTemplate(
            id: "outbound-procurement-intro",
            templateName: "Procurement Introduction",
            category: .procurement,
            subjectTemplate: "OperatorKit - Procurement Information Request",
            bodyTemplate: """
            Hello [Procurement Contact],
            
            I'm reaching out regarding OperatorKit for [Organization Name].
            
            OperatorKit is an on-device task assistant. For procurement review:
            
            - Pricing: [Plan type] at [price]/user/month
            - Deployment: App Store distribution
            - Data handling: On-device by default, optional cloud sync
            - Compliance: Available documentation on request
            
            I can provide:
            - Technical specification document
            - Buyer proof packet (quality and safety metrics)
            - Vendor information form
            
            Please let me know what documentation you need.
            
            Best,
            [Your Name]
            [Your Contact Info]
            """
        ),
        
        // Security Review Request
        OutboundTemplate(
            id: "outbound-security-review",
            templateName: "Security Review Request",
            category: .security,
            subjectTemplate: "OperatorKit Security Review Documentation",
            bodyTemplate: """
            Hello [Security Contact],
            
            I'm providing information for your security review of OperatorKit.
            
            Architecture overview:
            - Processing: On-device (Apple Neural Engine / Core ML)
            - Storage: Local device storage by default
            - Network: Optional sync only, user-initiated
            - Permissions: Calendar, Reminders, Siri (user-granted)
            
            Available documentation:
            - Safety contract with hash verification
            - Audit trail export (metadata only)
            - Quality gate status
            - Policy configuration options
            
            I can schedule a technical walkthrough at your convenience.
            
            Please share any questionnaires or requirements.
            
            Best,
            [Your Name]
            """
        ),
        
        // Pricing & Plans
        OutboundTemplate(
            id: "outbound-pricing-plans",
            templateName: "Pricing & Plans Overview",
            category: .pricing,
            subjectTemplate: "OperatorKit Pricing for [Organization Name]",
            bodyTemplate: """
            Hello [Contact Name],
            
            Here's the pricing overview for OperatorKit:
            
            Plans:
            - Free: Limited executions per week
            - Pro: Unlimited executions, optional sync
            - Team: Pro features + team governance
            
            Volume pricing available for [X]+ seats.
            
            All plans include:
            - On-device processing
            - Audit trail
            - Quality metrics
            - Export capabilities
            
            Would you like to discuss which plan fits your needs?
            
            Best,
            [Your Name]
            """
        ),
        
        // Follow-up After Demo
        OutboundTemplate(
            id: "outbound-demo-followup",
            templateName: "Demo Follow-up",
            category: .followUp,
            subjectTemplate: "Following up: OperatorKit Demo",
            bodyTemplate: """
            Hello [Contact Name],
            
            Thank you for taking the time to see OperatorKit in action.
            
            As discussed:
            - [Key point 1 from demo]
            - [Key point 2 from demo]
            - [Key point 3 from demo]
            
            Next steps:
            - [Action item 1]
            - [Action item 2]
            
            I've attached the buyer proof packet with our quality metrics.
            
            Let me know if you have any questions.
            
            Best,
            [Your Name]
            """
        )
    ]
    
    /// Templates grouped by category
    public static var byCategory: [OutboundTemplateCategory: [OutboundTemplate]] {
        Dictionary(grouping: all, by: { $0.category })
    }
    
    // MARK: - Validation
    
    /// Validates templates contain no banned words
    public static func validateNoBannedWords() -> [String] {
        let bannedWords = [
            "AI agent", "autonomous", "automatically learns",
            "secure", "encrypted", "protected", "safe",
            "guaranteed", "promise", "ensure", "always will",
            "thinks", "decides", "understands", "knows"
        ]
        
        var violations: [String] = []
        
        for template in all {
            let combined = "\(template.subjectTemplate) \(template.bodyTemplate)".lowercased()
            for word in bannedWords {
                if combined.contains(word.lowercased()) {
                    violations.append("Template '\(template.id)' contains banned phrase: \(word)")
                }
            }
        }
        
        return violations
    }
    
    /// Validates templates contain no promises
    public static func validateNoPromises() -> [String] {
        let promisePatterns = [
            "we guarantee", "we promise", "you will always",
            "100%", "never fails", "perfect"
        ]
        
        var violations: [String] = []
        
        for template in all {
            let combined = "\(template.subjectTemplate) \(template.bodyTemplate)".lowercased()
            for pattern in promisePatterns {
                if combined.contains(pattern.lowercased()) {
                    violations.append("Template '\(template.id)' contains promise: \(pattern)")
                }
            }
        }
        
        return violations
    }
    
    /// Validates templates use placeholders (no auto-filled info)
    public static func validatePlaceholdersOnly() -> [String] {
        var violations: [String] = []
        
        for template in all {
            // Check for brackets indicating placeholders
            let hasPlaceholders = template.bodyTemplate.contains("[") && template.bodyTemplate.contains("]")
            
            if !hasPlaceholders {
                violations.append("Template '\(template.id)' may be missing placeholders")
            }
            
            // Check for no actual email addresses
            let emailPattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
            if template.bodyTemplate.range(of: emailPattern, options: .regularExpression) != nil {
                violations.append("Template '\(template.id)' contains actual email address")
            }
        }
        
        return violations
    }
}

// MARK: - Outbound Templates Ledger

@MainActor
public final class OutboundTemplatesLedger: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = OutboundTemplatesLedger()
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let storageKeyPrefix = "com.operatorkit.outbound.ledger"
    
    // MARK: - State
    
    @Published public private(set) var copyCountByTemplate: [String: Int] = [:]
    @Published public private(set) var mailOpenCountByTemplate: [String: Int] = [:]
    @Published public private(set) var totalCopies: Int = 0
    @Published public private(set) var totalMailOpens: Int = 0
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadCounts()
    }
    
    // MARK: - Recording
    
    public func recordCopy(templateId: String) {
        copyCountByTemplate[templateId, default: 0] += 1
        totalCopies += 1
        saveCounts()
        
        logDebug("Outbound template copied: \(templateId)", category: .monetization)
    }
    
    public func recordMailOpen(templateId: String) {
        mailOpenCountByTemplate[templateId, default: 0] += 1
        totalMailOpens += 1
        saveCounts()
        
        logDebug("Outbound mail opened: \(templateId)", category: .monetization)
    }
    
    public func mostUsedTemplateId() -> String? {
        let combined = copyCountByTemplate.merging(mailOpenCountByTemplate) { $0 + $1 }
        return combined.max(by: { $0.value < $1.value })?.key
    }
    
    // MARK: - Reset
    
    public func reset() {
        copyCountByTemplate = [:]
        mailOpenCountByTemplate = [:]
        totalCopies = 0
        totalMailOpens = 0
        
        defaults.removeObject(forKey: "\(storageKeyPrefix).copies")
        defaults.removeObject(forKey: "\(storageKeyPrefix).mail_opens")
        defaults.removeObject(forKey: "\(storageKeyPrefix).total_copies")
        defaults.removeObject(forKey: "\(storageKeyPrefix).total_mail_opens")
    }
    
    // MARK: - Private
    
    private func loadCounts() {
        if let data = defaults.data(forKey: "\(storageKeyPrefix).copies"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            copyCountByTemplate = decoded
        }
        
        if let data = defaults.data(forKey: "\(storageKeyPrefix).mail_opens"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            mailOpenCountByTemplate = decoded
        }
        
        totalCopies = defaults.integer(forKey: "\(storageKeyPrefix).total_copies")
        totalMailOpens = defaults.integer(forKey: "\(storageKeyPrefix).total_mail_opens")
    }
    
    private func saveCounts() {
        if let data = try? JSONEncoder().encode(copyCountByTemplate) {
            defaults.set(data, forKey: "\(storageKeyPrefix).copies")
        }
        if let data = try? JSONEncoder().encode(mailOpenCountByTemplate) {
            defaults.set(data, forKey: "\(storageKeyPrefix).mail_opens")
        }
        defaults.set(totalCopies, forKey: "\(storageKeyPrefix).total_copies")
        defaults.set(totalMailOpens, forKey: "\(storageKeyPrefix).total_mail_opens")
    }
}
