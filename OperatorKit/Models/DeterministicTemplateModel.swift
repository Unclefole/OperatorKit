import Foundation

/// Deterministic template-based draft generation model
/// INVARIANT: On-device only (no network calls)
/// INVARIANT: All outputs are drafts first
/// INVARIANT: Citations must only reference selected context
/// INVARIANT: Snippets derived only from selected context (never unselected data)
/// 
/// This model is the ALWAYS AVAILABLE fallback when ML backends fail or are unavailable.
final class DeterministicTemplateModel: OnDeviceModel {
    
    // MARK: - OnDeviceModel Protocol
    
    let modelId = "deterministic_template_v1"
    let displayName = "Deterministic Templates"
    let version = "1.1.0"
    let backend: ModelBackend = .deterministic
    
    let capabilities = ModelCapabilities(
        canSummarize: true,
        canDraftEmail: true,
        canExtractActions: true,
        canGenerateReminder: true,
        maxInputTokens: nil,  // No limit for templates
        maxOutputTokens: nil
    )
    
    var maxOutputChars: Int? { nil }  // No limit
    
    /// Always available - this is the fallback
    var isAvailable: Bool { true }
    
    func checkAvailability() -> ModelAvailabilityResult {
        .available  // Always available
    }
    
    // MARK: - Confidence Rules
    
    /// Confidence when context includes >=1 calendar event OR >=1 file OR >=1 email
    private let highContextConfidence: Double = 0.85
    
    /// Confidence when intent only (no context)
    private let intentOnlyConfidence: Double = 0.55
    
    /// Confidence when intent is ambiguous (cannot classify)
    private let ambiguousConfidence: Double = 0.35
    
    // MARK: - Generation
    
    func generate(input: ModelInput) async throws -> DraftOutput {
        log("DeterministicTemplateModel: Generating \(input.outputType.displayName)")
        
        // Calculate confidence
        let confidence = calculateConfidence(for: input)
        
        // Generate citations from selected context only
        let citations = generateCitations(from: input)
        
        // Generate safety notes
        let safetyNotes = generateSafetyNotes(for: input)
        
        // Generate draft based on output type
        let (body, subject, actionItems) = generateDraftContent(for: input, citations: citations)
        
        return DraftOutput(
            draftBody: body,
            subject: subject,
            actionItems: actionItems,
            confidence: confidence,
            citations: citations,
            safetyNotes: safetyNotes,
            outputType: input.outputType
        )
    }
    
    func canHandle(input: ModelInput) -> Bool {
        // Deterministic model can handle any input
        true
    }
    
    // MARK: - Confidence Calculation
    
    private func calculateConfidence(for input: ModelInput) -> Double {
        // Rule: 0.35 if intent is ambiguous
        if input.isAmbiguous {
            log("DeterministicTemplateModel: Ambiguous intent, confidence = 0.35")
            return ambiguousConfidence
        }
        
        // Rule: 0.85 if context includes >=1 calendar event OR >=1 file OR >=1 email
        if input.contextItems.hasCalendar || input.contextItems.hasEmail || input.contextItems.hasFiles {
            log("DeterministicTemplateModel: Has context (\(input.contextItems.totalCount) items), confidence = 0.85")
            return highContextConfidence
        }
        
        // Rule: 0.55 if intent only (no context)
        log("DeterministicTemplateModel: Intent only, confidence = 0.55")
        return intentOnlyConfidence
    }
    
    // MARK: - Citation Generation
    
    /// Generate citations from selected context only
    /// INVARIANT: Only reference explicitly selected context
    private func generateCitations(from input: ModelInput) -> [Citation] {
        var citations: [Citation] = []
        
        // Calendar items → citations
        for item in input.contextItems.calendarItems {
            citations.append(Citation.fromCalendarItem(item))
        }
        
        // Email items → citations
        for item in input.contextItems.emailItems {
            citations.append(Citation.fromEmailItem(item))
        }
        
        // File items → citations
        for item in input.contextItems.fileItems {
            citations.append(Citation.fromFileItem(item))
        }
        
        log("DeterministicTemplateModel: Generated \(citations.count) citations")
        return citations
    }
    
    // MARK: - Safety Notes Generation
    
    /// Generate safety notes
    /// INVARIANT: Always include "You must review before sending"
    private func generateSafetyNotes(for input: ModelInput) -> [String] {
        var notes: [String] = []
        
        // Always include review warning
        notes.append("You must review before sending.")
        
        // Output-type specific warnings
        switch input.outputType {
        case .emailDraft:
            notes.append("Recipients not verified until you confirm.")
            notes.append("Email will not send automatically - you control when to send.")
            
        case .meetingSummary:
            notes.append("Summary may not capture all discussion points.")
            notes.append("Review for accuracy before sharing.")
            
        case .documentSummary:
            notes.append("Summary is AI-generated and may miss nuances.")
            
        case .taskList:
            notes.append("Task priorities and deadlines are suggestions only.")
            notes.append("Review and adjust as needed.")
            
        case .reminder:
            notes.append("Reminder timing is a suggestion - adjust as needed.")
        }
        
        // Context-based warnings
        if input.contextItems.isEmpty {
            notes.append("Generated without context - accuracy may be limited.")
        }
        
        if input.contextItems.calendarItems.count > 3 {
            notes.append("Multiple meetings referenced - verify correct meeting is summarized.")
        }
        
        return notes
    }
    
    // MARK: - Draft Content Generation
    
    private func generateDraftContent(
        for input: ModelInput,
        citations: [Citation]
    ) -> (body: String, subject: String?, actionItems: [String]) {
        switch input.outputType {
        case .emailDraft:
            return generateEmailDraft(input: input, citations: citations)
        case .meetingSummary:
            return generateMeetingSummary(input: input, citations: citations)
        case .documentSummary:
            return generateDocumentSummary(input: input, citations: citations)
        case .taskList:
            return generateTaskList(input: input, citations: citations)
        case .reminder:
            return generateReminder(input: input, citations: citations)
        }
    }
    
    // MARK: - Email Draft Template
    
    private func generateEmailDraft(
        input: ModelInput,
        citations: [Citation]
    ) -> (body: String, subject: String?, actionItems: [String]) {
        var body = ""
        var subject = "Follow-up"
        var actionItems: [String] = []
        
        // Extract meeting info from citations
        let meetingCitations = citations.filter { $0.sourceType == .calendarEvent }
        let emailCitations = citations.filter { $0.sourceType == .emailThread }
        
        if let meeting = meetingCitations.first {
            subject = "Follow-up: \(meeting.label.replacingOccurrences(of: "Meeting: ", with: ""))"
            body += "Hi,\n\n"
            body += "Thank you for taking the time to meet. Here's a follow-up on our discussion:\n\n"
            body += "**Meeting:** \(meeting.snippet)\n\n"
        } else if let email = emailCitations.first {
            subject = "Re: \(email.label.replacingOccurrences(of: "Email from ", with: ""))"
            body += "Hi,\n\n"
            body += "Following up on the email thread below:\n\n"
        } else {
            body += "Hi,\n\n"
            body += "I wanted to follow up regarding: \(input.intentText)\n\n"
        }
        
        // Add action items section
        body += "**Key Points:**\n"
        if input.contextItems.hasCalendar {
            let attendees = input.contextItems.calendarItems.flatMap { $0.attendees }
            if !attendees.isEmpty {
                body += "- Discussed with: \(attendees.prefix(3).joined(separator: ", "))\n"
                actionItems.append("Follow up with \(attendees.first ?? "attendees")")
            }
        }
        body += "- [Review and add specific discussion points]\n"
        body += "- [Add any decisions made]\n\n"
        
        // Add next steps
        body += "**Next Steps:**\n"
        body += "- [Add action items here]\n\n"
        
        body += "Please let me know if you have any questions.\n\n"
        body += "Best regards"
        
        actionItems.append("Review and personalize email")
        actionItems.append("Add specific discussion points")
        actionItems.append("Confirm recipient before sending")
        
        return (body, subject, actionItems)
    }
    
    // MARK: - Meeting Summary Template
    
    private func generateMeetingSummary(
        input: ModelInput,
        citations: [Citation]
    ) -> (body: String, subject: String?, actionItems: [String]) {
        var body = ""
        var actionItems: [String] = []
        var subject = "Meeting Summary"
        
        let meetingCitations = citations.filter { $0.sourceType == .calendarEvent }
        
        if let meeting = meetingCitations.first {
            subject = "Summary: \(meeting.label.replacingOccurrences(of: "Meeting: ", with: ""))"
        }
        
        body += "# Meeting Summary\n\n"
        
        // Meeting details
        body += "## Details\n"
        for citation in meetingCitations {
            body += "- **Meeting:** \(citation.snippet)\n"
        }
        if let firstMeeting = input.contextItems.calendarItems.first {
            body += "- **Date:** \(firstMeeting.formattedDate)\n"
            body += "- **Duration:** \(firstMeeting.formattedDuration)\n"
            if !firstMeeting.attendees.isEmpty {
                body += "- **Attendees:** \(firstMeeting.attendees.joined(separator: ", "))\n"
            }
        }
        body += "\n"
        
        // Key discussion points
        body += "## Key Discussion Points\n"
        body += "1. [Add main topic discussed]\n"
        body += "2. [Add secondary topics]\n"
        body += "3. [Add any decisions made]\n\n"
        
        // Notes from context
        if let notes = input.contextItems.calendarItems.first?.notes, !notes.isEmpty {
            body += "## Notes\n"
            body += "\(notes)\n\n"
        }
        
        // Action items
        body += "## Action Items\n"
        body += "- [ ] [Add action item and owner]\n"
        body += "- [ ] [Add action item and deadline]\n\n"
        
        // Next meeting
        body += "## Next Steps\n"
        body += "- Schedule follow-up if needed\n"
        body += "- Share summary with attendees\n"
        
        actionItems.append("Add specific discussion points")
        actionItems.append("Identify action item owners")
        actionItems.append("Share with attendees for review")
        
        return (body, subject, actionItems)
    }
    
    // MARK: - Document Summary Template
    
    private func generateDocumentSummary(
        input: ModelInput,
        citations: [Citation]
    ) -> (body: String, subject: String?, actionItems: [String]) {
        var body = ""
        var actionItems: [String] = []
        var subject = "Document Summary"
        
        let fileCitations = citations.filter { $0.sourceType == .file }
        
        if let file = fileCitations.first {
            subject = "Summary: \(file.label.replacingOccurrences(of: "File: ", with: ""))"
        }
        
        body += "# Document Summary\n\n"
        
        // Document info
        body += "## Document\n"
        for citation in fileCitations {
            body += "- \(citation.snippet)\n"
        }
        body += "\n"
        
        // Summary sections
        body += "## Overview\n"
        body += "[Add high-level summary of the document]\n\n"
        
        body += "## Key Points\n"
        body += "1. [Main point]\n"
        body += "2. [Supporting details]\n"
        body += "3. [Important findings]\n\n"
        
        body += "## Recommendations\n"
        body += "- [Add any recommendations]\n\n"
        
        actionItems.append("Add specific document details")
        actionItems.append("Verify key points are accurate")
        
        return (body, subject, actionItems)
    }
    
    // MARK: - Task List Template
    
    private func generateTaskList(
        input: ModelInput,
        citations: [Citation]
    ) -> (body: String, subject: String?, actionItems: [String]) {
        var body = ""
        var actionItems: [String] = []
        let subject = "Action Items"
        
        body += "# Action Items\n\n"
        body += "Generated from: \(input.intentText)\n\n"
        
        // Tasks from context
        body += "## Tasks\n"
        
        var taskNumber = 1
        
        // From calendar
        for meeting in input.contextItems.calendarItems {
            body += "\(taskNumber). Follow up on: \(meeting.title)\n"
            body += "   - Due: [Set deadline]\n"
            body += "   - Owner: [Assign owner]\n\n"
            actionItems.append("Follow up on \(meeting.title)")
            taskNumber += 1
        }
        
        // From emails
        for email in input.contextItems.emailItems {
            body += "\(taskNumber). Respond to: \(email.subject)\n"
            body += "   - From: \(email.sender)\n"
            body += "   - Due: [Set deadline]\n\n"
            actionItems.append("Respond to \(email.sender)")
            taskNumber += 1
        }
        
        // Placeholder tasks
        if taskNumber == 1 {
            body += "1. [Add task description]\n"
            body += "   - Due: [Set deadline]\n"
            body += "   - Owner: [Assign owner]\n\n"
        }
        
        body += "## Notes\n"
        body += "- Review and prioritize tasks\n"
        body += "- Assign deadlines and owners\n"
        
        if actionItems.isEmpty {
            actionItems.append("Define specific tasks")
        }
        actionItems.append("Prioritize and assign deadlines")
        
        return (body, subject, actionItems)
    }
    
    // MARK: - Reminder Template
    
    private func generateReminder(
        input: ModelInput,
        citations: [Citation]
    ) -> (body: String, subject: String?, actionItems: [String]) {
        var body = ""
        var actionItems: [String] = []
        var subject = "Reminder"
        
        // Build reminder from context
        if let meeting = input.contextItems.calendarItems.first {
            subject = "Reminder: \(meeting.title)"
            body += "Follow up on meeting: \(meeting.title)\n\n"
            body += "Attendees: \(meeting.attendees.joined(separator: ", "))\n"
            if let notes = meeting.notes {
                body += "Notes: \(notes)\n"
            }
        } else if let email = input.contextItems.emailItems.first {
            subject = "Reminder: Reply to \(email.sender)"
            body += "Reply to email: \(email.subject)\n\n"
            body += "From: \(email.sender)\n"
            body += "Preview: \(email.bodyPreview)\n"
        } else {
            body += "Reminder: \(input.intentText)\n\n"
            body += "[Add details for this reminder]"
        }
        
        actionItems.append("Review reminder timing")
        actionItems.append("Add specific details if needed")
        
        return (body, subject, actionItems)
    }
}
