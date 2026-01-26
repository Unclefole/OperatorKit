import Foundation

/// A generated draft output (email, summary, etc.)
/// INVARIANT: All drafts require user review before execution
/// INVARIANT: Citations must only reference selected context
struct Draft: Identifiable, Equatable {
    let id: UUID
    let type: DraftType
    let title: String
    let content: DraftContent
    let confidence: Double
    let citations: [Citation]
    let safetyNotes: [String]
    let actionItems: [String]
    let attachments: [DraftAttachment]
    let modelMetadata: ModelMetadata?
    let createdAt: Date
    
    enum DraftType: String, Codable {
        case email = "Email Draft"
        case summary = "Summary"
        case actionItems = "Action Items"
        case documentReview = "Document Review"
        case reminder = "Reminder"
        
        var icon: String {
            switch self {
            case .email: return "envelope.fill"
            case .summary: return "doc.text.fill"
            case .actionItems: return "checklist"
            case .documentReview: return "doc.richtext.fill"
            case .reminder: return "bell.fill"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        type: DraftType,
        title: String,
        content: DraftContent,
        confidence: Double,
        citations: [Citation] = [],
        safetyNotes: [String] = [],
        actionItems: [String] = [],
        attachments: [DraftAttachment] = [],
        modelMetadata: ModelMetadata? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.content = content
        self.confidence = min(max(confidence, 0.0), 1.0)
        self.citations = citations
        self.safetyNotes = safetyNotes
        self.actionItems = actionItems
        self.attachments = attachments
        self.modelMetadata = modelMetadata
        self.createdAt = createdAt
    }
    
    // MARK: - Factory from DraftOutput
    
    /// Create Draft from DraftOutput (from model router)
    static func from(
        output: DraftOutput,
        recipient: String? = nil,
        modelMetadata: ModelMetadata? = nil
    ) -> Draft {
        let draftType = mapOutputType(output.outputType)
        
        return Draft(
            type: draftType,
            title: output.subject ?? "Draft",
            content: DraftContent(
                recipient: recipient,
                subject: output.subject,
                body: output.draftBody,
                signature: nil
            ),
            confidence: output.confidence,
            citations: output.citations,
            safetyNotes: output.safetyNotes,
            actionItems: output.actionItems,
            modelMetadata: modelMetadata
        )
    }
    
    private static func mapOutputType(_ outputType: DraftOutput.OutputType) -> DraftType {
        switch outputType {
        case .emailDraft: return .email
        case .meetingSummary: return .summary
        case .documentSummary: return .documentReview
        case .taskList: return .actionItems
        case .reminder: return .reminder
        }
    }
    
    // MARK: - Confidence Properties
    
    /// Confidence as percentage (0-100)
    var confidencePercentage: Int {
        Int(confidence * 100)
    }
    
    /// Confidence level category
    var confidenceLevel: DraftOutput.ConfidenceLevel {
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
    
    /// Whether this draft can proceed directly (no fallback)
    var canProceedDirectly: Bool {
        confidence >= DraftOutput.directProceedConfidence
    }
    
    /// Whether this draft requires fallback confirmation
    var requiresFallbackConfirmation: Bool {
        confidence < DraftOutput.directProceedConfidence && confidence >= DraftOutput.minimumExecutionConfidence
    }
    
    /// Whether this draft is blocked from execution
    var isBlocked: Bool {
        confidence < DraftOutput.minimumExecutionConfidence
    }
    
    static func == (lhs: Draft, rhs: Draft) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Draft Content

struct DraftContent: Equatable {
    let recipient: String?
    let subject: String?
    let body: String
    let signature: String?
    
    init(recipient: String? = nil, subject: String? = nil, body: String, signature: String? = nil) {
        self.recipient = recipient
        self.subject = subject
        self.body = body
        self.signature = signature
    }
}

// MARK: - Draft Attachment

struct DraftAttachment: Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: String
    
    init(id: UUID = UUID(), name: String, type: String) {
        self.id = id
        self.name = name
        self.type = type
    }
}
