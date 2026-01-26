import Foundation

// ============================================================================
// QUALITY FEEDBACK (Phase 8A)
//
// Local-only feedback system for trust calibration.
// INVARIANT: No raw user content stored (only metadata and tags)
// INVARIANT: No network transmission
// INVARIANT: User-initiated only
// INVARIANT: Append-only, immutable after finalization
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

// MARK: - Quality Rating

/// User's overall rating of draft quality
public enum QualityRating: String, Codable, CaseIterable {
    case helpful = "helpful"
    case notHelpful = "not_helpful"
    case mixed = "mixed"
    
    public var displayName: String {
        switch self {
        case .helpful: return "Helpful"
        case .notHelpful: return "Not Helpful"
        case .mixed: return "Mixed"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .helpful: return "hand.thumbsup"
        case .notHelpful: return "hand.thumbsdown"
        case .mixed: return "hand.raised"
        }
    }
}

// MARK: - Quality Issue Tags

/// Predefined issue tags for feedback (no free text required)
/// INVARIANT: Finite list, no user-generated tags
public enum QualityIssueTag: String, Codable, CaseIterable, Identifiable {
    case missingContext = "missing_context"
    case incorrectFacts = "incorrect_facts"
    case wrongTone = "wrong_tone"
    case tooLong = "too_long"
    case tooShort = "too_short"
    case wrongTaskType = "wrong_task_type"
    case unclearNextSteps = "unclear_next_steps"
    case citationsWrong = "citations_wrong"
    case timedOutFallback = "timed_out_fallback"
    case other = "other"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .missingContext: return "Missing context"
        case .incorrectFacts: return "Incorrect information"
        case .wrongTone: return "Wrong tone"
        case .tooLong: return "Too long"
        case .tooShort: return "Too short"
        case .wrongTaskType: return "Wrong task type"
        case .unclearNextSteps: return "Unclear next steps"
        case .citationsWrong: return "Citations incorrect"
        case .timedOutFallback: return "Fallback was used"
        case .other: return "Other"
        }
    }
    
    public var description: String {
        switch self {
        case .missingContext: return "The draft was missing important context I provided"
        case .incorrectFacts: return "The draft contained incorrect or outdated information"
        case .wrongTone: return "The tone didn't match what I needed"
        case .tooLong: return "The draft was longer than necessary"
        case .tooShort: return "The draft was too brief"
        case .wrongTaskType: return "The draft type didn't match my request"
        case .unclearNextSteps: return "Action items or next steps were unclear"
        case .citationsWrong: return "The cited context was incorrect"
        case .timedOutFallback: return "A simpler method was used due to timeout"
        case .other: return "Something else"
        }
    }
}

// MARK: - Quality Feedback Entry

/// A single feedback entry linked to a memory item
/// INVARIANT: No raw calendar/email content - only metadata and tags
public struct QualityFeedbackEntry: Identifiable, Codable {
    public let id: UUID
    public let memoryItemId: UUID
    public let rating: QualityRating
    public let issueTags: [QualityIssueTag]
    public let optionalNote: String?
    public let createdAt: Date
    
    // Metadata captured at feedback time (not raw content)
    public let appVersion: String?
    public let modelBackend: String?
    public let confidence: Double?
    public let usedFallback: Bool
    public let timeoutOccurred: Bool
    public let validationPass: Bool?
    public let citationValidityPass: Bool?
    
    /// Maximum allowed note length
    public static let maxNoteLength = 240
    
    /// Schema version for export compatibility
    public static let schemaVersion = "1.0"
    
    public init(
        id: UUID = UUID(),
        memoryItemId: UUID,
        rating: QualityRating,
        issueTags: [QualityIssueTag] = [],
        optionalNote: String? = nil,
        createdAt: Date = Date(),
        appVersion: String? = nil,
        modelBackend: String? = nil,
        confidence: Double? = nil,
        usedFallback: Bool = false,
        timeoutOccurred: Bool = false,
        validationPass: Bool? = nil,
        citationValidityPass: Bool? = nil
    ) {
        self.id = id
        self.memoryItemId = memoryItemId
        self.rating = rating
        self.issueTags = issueTags
        
        // Enforce max note length
        if let note = optionalNote {
            self.optionalNote = String(note.prefix(Self.maxNoteLength))
        } else {
            self.optionalNote = nil
        }
        
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.modelBackend = modelBackend
        self.confidence = confidence
        self.usedFallback = usedFallback
        self.timeoutOccurred = timeoutOccurred
        self.validationPass = validationPass
        self.citationValidityPass = citationValidityPass
    }
}

// MARK: - Validation

extension QualityFeedbackEntry {
    
    /// Validates that the feedback entry contains no raw user content
    /// INVARIANT: Must pass before storage
    public func validateNoRawContent() -> Bool {
        // Note must not contain email addresses, phone numbers, or long strings
        // that could be user content
        if let note = optionalNote {
            // Check for potential PII patterns
            let emailPattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
            let phonePattern = "\\d{3}[-.\\s]?\\d{3}[-.\\s]?\\d{4}"
            
            if note.range(of: emailPattern, options: .regularExpression) != nil {
                return false
            }
            if note.range(of: phonePattern, options: .regularExpression) != nil {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Export Format

/// Export-safe representation of feedback
/// INVARIANT: Contains only metadata, never raw user content
public struct QualityFeedbackExport: Codable {
    public let schemaVersion: String
    public let exportedAt: Date
    public let totalEntries: Int
    public let entries: [QualityFeedbackExportEntry]
    
    public struct QualityFeedbackExportEntry: Codable {
        public let id: String
        public let memoryItemId: String
        public let rating: String
        public let issueTags: [String]
        public let hasNote: Bool  // Note: NOT the actual note content for privacy
        public let createdAt: Date
        public let modelBackend: String?
        public let confidence: Double?
        public let usedFallback: Bool
        public let timeoutOccurred: Bool
        public let validationPass: Bool?
        public let citationValidityPass: Bool?
    }
    
    public init(entries: [QualityFeedbackEntry]) {
        self.schemaVersion = QualityFeedbackEntry.schemaVersion
        self.exportedAt = Date()
        self.totalEntries = entries.count
        self.entries = entries.map { entry in
            QualityFeedbackExportEntry(
                id: entry.id.uuidString,
                memoryItemId: entry.memoryItemId.uuidString,
                rating: entry.rating.rawValue,
                issueTags: entry.issueTags.map { $0.rawValue },
                hasNote: entry.optionalNote != nil,
                createdAt: entry.createdAt,
                modelBackend: entry.modelBackend,
                confidence: entry.confidence,
                usedFallback: entry.usedFallback,
                timeoutOccurred: entry.timeoutOccurred,
                validationPass: entry.validationPass,
                citationValidityPass: entry.citationValidityPass
            )
        }
    }
    
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
