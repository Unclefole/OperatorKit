import Foundation

// ============================================================================
// SYNTHETIC DATA SCHEMA (Phase 13I)
//
// Canonical JSON schema model for synthetic test fixtures.
// Used for verification harness only — no runtime behavior changes.
//
// CONSTRAINTS:
// ❌ No networking
// ❌ No user content storage
// ❌ No runtime modifications
// ✅ Read-only schema definitions
// ✅ Forbidden keys enforcement
// ============================================================================

// MARK: - Schema Version

public enum SyntheticDataSchemaVersion {
    public static let current = 1
}

// MARK: - Forbidden Keys Registry

/// Keys that must NEVER appear in synthetic data unless explicitly marked as placeholders
public enum SyntheticForbiddenKeys {
    
    /// Forbidden field names that could indicate real user data
    public static let fieldNames: Set<String> = [
        // Personal identifiers
        "ssn", "socialSecurityNumber", "taxId", "driverLicense",
        "passport", "nationalId", "birthDate", "dateOfBirth",
        
        // Contact information (unless synthetic placeholder)
        "realEmail", "personalEmail", "workEmail", "homePhone",
        "mobilePhone", "cellPhone", "fax", "homeAddress",
        "workAddress", "streetAddress", "zipCode", "postalCode",
        
        // Financial
        "creditCard", "cardNumber", "cvv", "bankAccount",
        "routingNumber", "iban", "swift", "salary", "income",
        
        // Health
        "diagnosis", "prescription", "medicalRecord", "healthId",
        
        // Credentials
        "password", "pin", "secretKey", "apiKey", "token",
        "accessToken", "refreshToken", "privateKey"
    ]
    
    /// Content patterns that indicate real data (regex patterns)
    public static let contentPatterns: [String] = [
        // Real email pattern (not synthetic placeholders)
        "[a-zA-Z0-9._%+-]+@(?!example\\.com|test\\.com|synthetic\\.local|placeholder\\.dev)[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
        
        // Phone numbers (US format)
        "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b",
        
        // SSN
        "\\b\\d{3}[-]?\\d{2}[-]?\\d{4}\\b",
        
        // Credit card (basic pattern)
        "\\b(?:\\d{4}[-\\s]?){3}\\d{4}\\b",
        
        // IP addresses (could indicate real infrastructure)
        "\\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\b"
    ]
    
    /// Allowed synthetic placeholder domains
    public static let allowedDomains: Set<String> = [
        "example.com",
        "test.com",
        "synthetic.local",
        "placeholder.dev",
        "acme.example",
        "corp.example"
    ]
    
    /// Known firm names that should not appear (would indicate real data)
    public static let forbiddenFirmNames: Set<String> = [
        // Major tech companies
        "google", "apple", "microsoft", "amazon", "meta", "facebook",
        "netflix", "tesla", "nvidia", "openai", "anthropic",
        
        // Major financial institutions
        "jpmorgan", "goldman", "morgan stanley", "blackrock",
        "citadel", "bridgewater", "berkshire",
        
        // Major consulting firms
        "mckinsey", "bain", "bcg", "deloitte", "pwc", "kpmg", "ey"
    ]
    
    /// Validate a string contains no forbidden patterns
    public static func validate(_ content: String) -> [String] {
        var violations: [String] = []
        
        let lowercased = content.lowercased()
        
        // Check for forbidden firm names
        for firm in forbiddenFirmNames {
            if lowercased.contains(firm) {
                violations.append("Contains forbidden firm name: \(firm)")
            }
        }
        
        // Check regex patterns
        for pattern in contentPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(content.startIndex..., in: content)
                if regex.firstMatch(in: content, options: [], range: range) != nil {
                    violations.append("Matches forbidden pattern: \(pattern.prefix(30))...")
                }
            }
        }
        
        return violations
    }
    
    /// Validate a dictionary has no forbidden field names
    public static func validateFields(_ dict: [String: Any]) -> [String] {
        var violations: [String] = []
        
        for key in dict.keys {
            if fieldNames.contains(key.lowercased()) {
                violations.append("Contains forbidden field: \(key)")
            }
        }
        
        return violations
    }
}

// MARK: - Context Types

/// Types of context that can be selected for synthetic examples
public enum SyntheticContextType: String, Codable, CaseIterable {
    case calendarEvent = "calendar_event"
    case documentSnippet = "document_snippet"
    case emailStub = "email_stub"
    case noteStub = "note_stub"
    case contactCard = "contact_card"
    case taskItem = "task_item"
}

// MARK: - Selected Context

/// A piece of selected context in a synthetic example
public struct SyntheticSelectedContext: Codable, Equatable {
    public let contextType: SyntheticContextType
    public let contextId: String
    public let syntheticContent: SyntheticContextContent
    
    enum CodingKeys: String, CodingKey {
        case contextType = "context_type"
        case contextId = "context_id"
        case syntheticContent = "synthetic_content"
    }
    
    public init(contextType: SyntheticContextType, contextId: String, syntheticContent: SyntheticContextContent) {
        self.contextType = contextType
        self.contextId = contextId
        self.syntheticContent = syntheticContent
    }
}

/// Content structure for synthetic context (all fields are synthetic placeholders)
public struct SyntheticContextContent: Codable, Equatable {
    /// Synthetic title/subject (e.g., "[SYNTHETIC] Meeting with Client")
    public let syntheticTitle: String?
    
    /// Synthetic date (ISO format)
    public let syntheticDate: String?
    
    /// Synthetic participants (e.g., ["user@example.com", "contact@test.com"])
    public let syntheticParticipants: [String]?
    
    /// Synthetic snippet (always prefixed with [SYNTHETIC])
    public let syntheticSnippet: String?
    
    /// Synthetic location (placeholder only)
    public let syntheticLocation: String?
    
    enum CodingKeys: String, CodingKey {
        case syntheticTitle = "synthetic_title"
        case syntheticDate = "synthetic_date"
        case syntheticParticipants = "synthetic_participants"
        case syntheticSnippet = "synthetic_snippet"
        case syntheticLocation = "synthetic_location"
    }
    
    public init(
        syntheticTitle: String? = nil,
        syntheticDate: String? = nil,
        syntheticParticipants: [String]? = nil,
        syntheticSnippet: String? = nil,
        syntheticLocation: String? = nil
    ) {
        self.syntheticTitle = syntheticTitle
        self.syntheticDate = syntheticDate
        self.syntheticParticipants = syntheticParticipants
        self.syntheticSnippet = syntheticSnippet
        self.syntheticLocation = syntheticLocation
    }
}

// MARK: - Expected Native Outcome

/// The expected outcome for a synthetic example
public struct SyntheticExpectedOutcome: Codable, Equatable {
    /// The action ID that should be selected
    public let actionId: String
    
    /// Expected draft fields (synthetic placeholders only)
    public let draftFields: SyntheticDraftFields?
    
    /// Whether this should trigger the safety gate
    public let shouldTriggerSafetyGate: Bool
    
    enum CodingKeys: String, CodingKey {
        case actionId = "action_id"
        case draftFields = "draft_fields"
        case shouldTriggerSafetyGate = "should_trigger_safety_gate"
    }
    
    public init(actionId: String, draftFields: SyntheticDraftFields? = nil, shouldTriggerSafetyGate: Bool = false) {
        self.actionId = actionId
        self.draftFields = draftFields
        self.shouldTriggerSafetyGate = shouldTriggerSafetyGate
    }
}

/// Synthetic draft fields (all placeholders)
public struct SyntheticDraftFields: Codable, Equatable {
    public let syntheticRecipient: String?
    public let syntheticSubject: String?
    public let syntheticBodyPlaceholder: String?
    public let syntheticEventTitle: String?
    public let syntheticEventDate: String?
    
    enum CodingKeys: String, CodingKey {
        case syntheticRecipient = "synthetic_recipient"
        case syntheticSubject = "synthetic_subject"
        case syntheticBodyPlaceholder = "synthetic_body_placeholder"
        case syntheticEventTitle = "synthetic_event_title"
        case syntheticEventDate = "synthetic_event_date"
    }
    
    public init(
        syntheticRecipient: String? = nil,
        syntheticSubject: String? = nil,
        syntheticBodyPlaceholder: String? = nil,
        syntheticEventTitle: String? = nil,
        syntheticEventDate: String? = nil
    ) {
        self.syntheticRecipient = syntheticRecipient
        self.syntheticSubject = syntheticSubject
        self.syntheticBodyPlaceholder = syntheticBodyPlaceholder
        self.syntheticEventTitle = syntheticEventTitle
        self.syntheticEventDate = syntheticEventDate
    }
}

// MARK: - Safety Gate

/// Safety gate configuration for synthetic examples
public struct SyntheticSafetyGate: Codable, Equatable {
    /// Whether approval is required
    public let requiresApproval: Bool
    
    /// Reason for safety gate trigger (if any)
    public let triggerReason: String?
    
    /// Risk level classification
    public let riskLevel: SyntheticRiskLevel
    
    enum CodingKeys: String, CodingKey {
        case requiresApproval = "requires_approval"
        case triggerReason = "trigger_reason"
        case riskLevel = "risk_level"
    }
    
    public init(requiresApproval: Bool = true, triggerReason: String? = nil, riskLevel: SyntheticRiskLevel = .standard) {
        self.requiresApproval = requiresApproval
        self.triggerReason = triggerReason
        self.riskLevel = riskLevel
    }
}

/// Risk level for synthetic examples
public enum SyntheticRiskLevel: String, Codable, CaseIterable {
    case low = "low"
    case standard = "standard"
    case elevated = "elevated"
    case high = "high"
}

// MARK: - Domain Classification

/// Domain classification for synthetic examples
public enum SyntheticDomain: String, Codable, CaseIterable {
    case email = "email"
    case calendar = "calendar"
    case notes = "notes"
    case tasks = "tasks"
    case documents = "documents"
    case contacts = "contacts"
    case general = "general"
}

// MARK: - Main Example Model

/// A single synthetic example for testing
public struct SyntheticExample: Codable, Equatable, Identifiable {
    /// Unique identifier for the example
    public let exampleId: String
    
    /// Domain classification
    public let domain: SyntheticDomain
    
    /// The user's intent (synthetic, not real user data)
    public let userIntent: String
    
    /// Selected context pieces
    public let selectedContext: [SyntheticSelectedContext]
    
    /// Expected native outcome
    public let expectedNativeOutcome: SyntheticExpectedOutcome
    
    /// Safety gate configuration
    public let safetyGate: SyntheticSafetyGate
    
    /// Schema version
    public let schemaVersion: Int
    
    /// Metadata (optional)
    public let metadata: SyntheticExampleMetadata?
    
    public var id: String { exampleId }
    
    enum CodingKeys: String, CodingKey {
        case exampleId = "example_id"
        case domain
        case userIntent = "user_intent"
        case selectedContext = "selected_context"
        case expectedNativeOutcome = "expected_native_outcome"
        case safetyGate = "safety_gate"
        case schemaVersion = "schema_version"
        case metadata
    }
    
    public init(
        exampleId: String,
        domain: SyntheticDomain,
        userIntent: String,
        selectedContext: [SyntheticSelectedContext],
        expectedNativeOutcome: SyntheticExpectedOutcome,
        safetyGate: SyntheticSafetyGate,
        schemaVersion: Int = SyntheticDataSchemaVersion.current,
        metadata: SyntheticExampleMetadata? = nil
    ) {
        self.exampleId = exampleId
        self.domain = domain
        self.userIntent = userIntent
        self.selectedContext = selectedContext
        self.expectedNativeOutcome = expectedNativeOutcome
        self.safetyGate = safetyGate
        self.schemaVersion = schemaVersion
        self.metadata = metadata
    }
}

/// Metadata for synthetic examples
public struct SyntheticExampleMetadata: Codable, Equatable {
    /// Generation source (e.g., "hand_verified", "template_generated")
    public let generationSource: String?
    
    /// Category tags
    public let tags: [String]?
    
    /// Whether this is a negative example (should fail routing)
    public let isNegativeExample: Bool
    
    /// Expected failure reason for negative examples
    public let expectedFailureReason: String?
    
    enum CodingKeys: String, CodingKey {
        case generationSource = "generation_source"
        case tags
        case isNegativeExample = "is_negative_example"
        case expectedFailureReason = "expected_failure_reason"
    }
    
    public init(
        generationSource: String? = nil,
        tags: [String]? = nil,
        isNegativeExample: Bool = false,
        expectedFailureReason: String? = nil
    ) {
        self.generationSource = generationSource
        self.tags = tags
        self.isNegativeExample = isNegativeExample
        self.expectedFailureReason = expectedFailureReason
    }
}

// MARK: - Corpus Container

/// Container for a collection of synthetic examples
public struct SyntheticCorpus: Codable, Equatable {
    /// Corpus identifier
    public let corpusId: String
    
    /// Corpus version
    public let version: String
    
    /// Schema version
    public let schemaVersion: Int
    
    /// Creation date (ISO format)
    public let createdAt: String
    
    /// Examples in the corpus
    public let examples: [SyntheticExample]
    
    /// Corpus metadata
    public let corpusMetadata: SyntheticCorpusMetadata
    
    enum CodingKeys: String, CodingKey {
        case corpusId = "corpus_id"
        case version
        case schemaVersion = "schema_version"
        case createdAt = "created_at"
        case examples
        case corpusMetadata = "corpus_metadata"
    }
    
    public init(
        corpusId: String,
        version: String,
        schemaVersion: Int = SyntheticDataSchemaVersion.current,
        createdAt: String,
        examples: [SyntheticExample],
        corpusMetadata: SyntheticCorpusMetadata
    ) {
        self.corpusId = corpusId
        self.version = version
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.examples = examples
        self.corpusMetadata = corpusMetadata
    }
}

/// Metadata for a synthetic corpus
public struct SyntheticCorpusMetadata: Codable, Equatable {
    /// Purpose of the corpus
    public let purpose: String
    
    /// Domain distribution
    public let domainDistribution: [String: Int]
    
    /// Total example count
    public let totalExamples: Int
    
    /// Negative example count
    public let negativeExamples: Int
    
    /// Generation method
    public let generationMethod: String
    
    enum CodingKeys: String, CodingKey {
        case purpose
        case domainDistribution = "domain_distribution"
        case totalExamples = "total_examples"
        case negativeExamples = "negative_examples"
        case generationMethod = "generation_method"
    }
    
    public init(
        purpose: String,
        domainDistribution: [String: Int],
        totalExamples: Int,
        negativeExamples: Int,
        generationMethod: String
    ) {
        self.purpose = purpose
        self.domainDistribution = domainDistribution
        self.totalExamples = totalExamples
        self.negativeExamples = negativeExamples
        self.generationMethod = generationMethod
    }
}

// MARK: - Validation

extension SyntheticExample {
    
    /// Validate the example contains no forbidden content
    public func validate() -> [String] {
        var violations: [String] = []
        
        // Validate user intent
        violations.append(contentsOf: SyntheticForbiddenKeys.validate(userIntent).map { "userIntent: \($0)" })
        
        // Validate selected context
        for (index, context) in selectedContext.enumerated() {
            if let title = context.syntheticContent.syntheticTitle {
                violations.append(contentsOf: SyntheticForbiddenKeys.validate(title).map { "selectedContext[\(index)].title: \($0)" })
            }
            if let snippet = context.syntheticContent.syntheticSnippet {
                violations.append(contentsOf: SyntheticForbiddenKeys.validate(snippet).map { "selectedContext[\(index)].snippet: \($0)" })
            }
            if let participants = context.syntheticContent.syntheticParticipants {
                for participant in participants {
                    // Check if email is from allowed domains
                    if participant.contains("@") {
                        let domain = participant.components(separatedBy: "@").last ?? ""
                        if !SyntheticForbiddenKeys.allowedDomains.contains(domain) {
                            violations.append("selectedContext[\(index)].participant: Email domain '\(domain)' not in allowed list")
                        }
                    }
                }
            }
        }
        
        // Validate draft fields
        if let draftFields = expectedNativeOutcome.draftFields {
            if let recipient = draftFields.syntheticRecipient, recipient.contains("@") {
                let domain = recipient.components(separatedBy: "@").last ?? ""
                if !SyntheticForbiddenKeys.allowedDomains.contains(domain) {
                    violations.append("draftFields.recipient: Email domain '\(domain)' not in allowed list")
                }
            }
            if let subject = draftFields.syntheticSubject {
                violations.append(contentsOf: SyntheticForbiddenKeys.validate(subject).map { "draftFields.subject: \($0)" })
            }
        }
        
        return violations
    }
}

extension SyntheticCorpus {
    
    /// Validate the entire corpus
    public func validate() -> SyntheticCorpusValidationResult {
        var exampleViolations: [String: [String]] = [:]
        var totalViolations = 0
        
        for example in examples {
            let violations = example.validate()
            if !violations.isEmpty {
                exampleViolations[example.exampleId] = violations
                totalViolations += violations.count
            }
        }
        
        return SyntheticCorpusValidationResult(
            isValid: totalViolations == 0,
            totalExamples: examples.count,
            validExamples: examples.count - exampleViolations.count,
            totalViolations: totalViolations,
            violationsByExample: exampleViolations
        )
    }
}

/// Result of corpus validation
public struct SyntheticCorpusValidationResult: Equatable {
    public let isValid: Bool
    public let totalExamples: Int
    public let validExamples: Int
    public let totalViolations: Int
    public let violationsByExample: [String: [String]]
    
    public init(
        isValid: Bool,
        totalExamples: Int,
        validExamples: Int,
        totalViolations: Int,
        violationsByExample: [String: [String]]
    ) {
        self.isValid = isValid
        self.totalExamples = totalExamples
        self.validExamples = validExamples
        self.totalViolations = totalViolations
        self.violationsByExample = violationsByExample
    }
}
