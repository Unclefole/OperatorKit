import Foundation

/// Output from the on-device draft generation model
/// INVARIANT: All outputs are drafts first - never auto-sent
/// INVARIANT: Citations must reference only user-selected context
struct DraftOutput: Identifiable, Equatable {
    let id: UUID
    let draftBody: String
    let subject: String?
    let actionItems: [String]
    let confidence: Double  // 0.0–1.0
    let citations: [Citation]
    let safetyNotes: [String]
    let outputType: OutputType
    let generatedAt: Date
    
    /// The type of output generated
    enum OutputType: String, Codable, CaseIterable {
        case emailDraft = "email_draft"
        case meetingSummary = "meeting_summary"
        case documentSummary = "document_summary"
        case taskList = "task_list"
        case reminder = "reminder"
        case researchBrief = "research_brief"
        
        var displayName: String {
            switch self {
            case .emailDraft: return "Email Draft"
            case .meetingSummary: return "Meeting Summary"
            case .documentSummary: return "Document Summary"
            case .taskList: return "Task List"
            case .reminder: return "Reminder"
            case .researchBrief: return "Research Brief"
            }
        }
        
        var icon: String {
            switch self {
            case .emailDraft: return "envelope.fill"
            case .meetingSummary: return "person.3.fill"
            case .documentSummary: return "doc.text.fill"
            case .taskList: return "checklist"
            case .reminder: return "bell.fill"
            case .researchBrief: return "magnifyingglass.circle.fill"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        draftBody: String,
        subject: String? = nil,
        actionItems: [String] = [],
        confidence: Double,
        citations: [Citation] = [],
        safetyNotes: [String] = [],
        outputType: OutputType,
        generatedAt: Date = Date()
    ) {
        // Clamp confidence to valid range
        self.id = id
        self.draftBody = draftBody
        self.subject = subject
        self.actionItems = actionItems
        self.confidence = min(max(confidence, 0.0), 1.0)
        self.citations = citations
        self.safetyNotes = safetyNotes
        self.outputType = outputType
        self.generatedAt = generatedAt
    }
    
    // MARK: - Confidence Thresholds
    
    /// Minimum confidence for allowing execution path
    static let minimumExecutionConfidence: Double = 0.35
    
    /// Minimum confidence for direct proceed (no fallback)
    static let directProceedConfidence: Double = 0.65
    
    /// Whether this output can proceed to draft preview
    var canProceedToDraft: Bool {
        confidence >= Self.minimumExecutionConfidence
    }
    
    /// Whether this output requires fallback confirmation
    var requiresFallbackConfirmation: Bool {
        confidence < Self.directProceedConfidence && confidence >= Self.minimumExecutionConfidence
    }
    
    /// Whether this output is blocked entirely
    var isBlocked: Bool {
        confidence < Self.minimumExecutionConfidence
    }
    
    // MARK: - Display Helpers
    
    var confidencePercentage: Int {
        Int(confidence * 100)
    }
    
    var confidenceLevel: ConfidenceLevel {
        if confidence >= 0.85 {
            return .high
        } else if confidence >= 0.65 {
            return .medium
        } else if confidence >= 0.35 {
            return .low
        } else {
            return .veryLow
        }
    }
    
    enum ConfidenceLevel: String {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case veryLow = "Very Low"
        
        var color: String {
            switch self {
            case .high: return "green"
            case .medium: return "blue"
            case .low: return "orange"
            case .veryLow: return "red"
            }
        }
        
        var icon: String {
            switch self {
            case .high: return "checkmark.shield.fill"
            case .medium: return "shield.fill"
            case .low: return "exclamationmark.shield.fill"
            case .veryLow: return "xmark.shield.fill"
            }
        }
    }
    
    static func == (lhs: DraftOutput, rhs: DraftOutput) -> Bool {
        lhs.id == rhs.id
    }
}
