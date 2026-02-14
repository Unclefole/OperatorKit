import Foundation

/// Input to the on-device draft generation model
/// INVARIANT: contextSummary constructed only from user-selected context
/// INVARIANT: constraints always include invariants (draft-first, no auto-send)
struct ModelInput: Equatable {
    let intentText: String
    let contextSummary: String
    let constraints: [String]
    let outputType: DraftOutput.OutputType
    let contextItems: ContextItems
    let timestamp: Date
    
    /// Detailed breakdown of context items for citation generation
    struct ContextItems: Equatable {
        let calendarItems: [CalendarContextItem]
        let emailItems: [EmailContextItem]
        let fileItems: [FileContextItem]
        
        var isEmpty: Bool {
            calendarItems.isEmpty && emailItems.isEmpty && fileItems.isEmpty
        }
        
        var totalCount: Int {
            calendarItems.count + emailItems.count + fileItems.count
        }
        
        var hasCalendar: Bool { !calendarItems.isEmpty }
        var hasEmail: Bool { !emailItems.isEmpty }
        var hasFiles: Bool { !fileItems.isEmpty }
    }
    
    init(
        intentText: String,
        contextSummary: String,
        constraints: [String] = ModelInput.defaultConstraints,
        outputType: DraftOutput.OutputType,
        contextItems: ContextItems,
        timestamp: Date = Date()
    ) {
        self.intentText = intentText
        self.contextSummary = contextSummary
        // Always include default constraints
        self.constraints = Array(Set(constraints + ModelInput.defaultConstraints))
        self.outputType = outputType
        self.contextItems = contextItems
        self.timestamp = timestamp
    }
    
    // MARK: - Default Constraints (Invariants)
    
    /// Invariants that must always be included
    static let defaultConstraints: [String] = [
        "Output must be a draft only - never auto-send",
        "User must review before any execution",
        "All side effects must be shown before execution",
        "No data beyond selected context may be used"
    ]
    
    // MARK: - Factory Methods
    
    /// Create model input from intent and context packet
    static func from(
        intent: IntentRequest,
        context: ContextPacket
    ) -> ModelInput {
        // Build context summary from selected items only
        var summaryParts: [String] = []
        
        if !context.calendarItems.isEmpty {
            let meetingTitles = context.calendarItems.map { $0.title }.joined(separator: ", ")
            summaryParts.append("Meetings: \(meetingTitles)")
            
            // Include attendees
            let allAttendees = context.calendarItems.flatMap { $0.attendees }
            if !allAttendees.isEmpty {
                let uniqueAttendees = Array(Set(allAttendees)).prefix(5)
                summaryParts.append("Participants: \(uniqueAttendees.joined(separator: ", "))")
            }
            
            // Include notes if available
            let notes = context.calendarItems.compactMap { $0.notes }.joined(separator: " ")
            if !notes.isEmpty {
                summaryParts.append("Notes: \(String(notes.prefix(200)))")
            }
        }
        
        if !context.emailItems.isEmpty {
            let subjects = context.emailItems.map { $0.subject }.joined(separator: ", ")
            summaryParts.append("Emails: \(subjects)")
            
            let previews = context.emailItems.map { $0.bodyPreview }.joined(separator: " ")
            if !previews.isEmpty {
                summaryParts.append("Content: \(String(previews.prefix(300)))")
            }
        }
        
        if !context.fileItems.isEmpty {
            let fileNames = context.fileItems.map { $0.name }.joined(separator: ", ")
            summaryParts.append("Files: \(fileNames)")
        }
        
        let contextSummary = summaryParts.isEmpty ? "No context selected" : summaryParts.joined(separator: "\n")
        
        // Determine output type from intent
        let outputType = mapIntentToOutputType(intent)
        
        return ModelInput(
            intentText: intent.rawText,
            contextSummary: contextSummary,
            outputType: outputType,
            contextItems: ContextItems(
                calendarItems: context.calendarItems,
                emailItems: context.emailItems,
                fileItems: context.fileItems
            )
        )
    }
    
    /// Map intent type to output type
    private static func mapIntentToOutputType(_ intent: IntentRequest) -> DraftOutput.OutputType {
        switch intent.intentType {
        case .draftEmail:
            return .emailDraft
        case .summarizeMeeting:
            return .meetingSummary
        case .extractActionItems:
            return .taskList
        case .reviewDocument:
            return .documentSummary
        case .createReminder:
            return .reminder
        case .researchBrief:
            return .researchBrief
        case .unknown:
            // Default to meeting summary if context has calendar items
            return .meetingSummary
        }
    }
    
    // MARK: - Validation
    
    /// Whether this input has sufficient context
    var hasSufficientContext: Bool {
        !contextItems.isEmpty || !intentText.isEmpty
    }
    
    /// Whether intent is ambiguous (cannot determine output type)
    var isAmbiguous: Bool {
        intentText.trimmingCharacters(in: .whitespacesAndNewlines).count < 5
    }
}
