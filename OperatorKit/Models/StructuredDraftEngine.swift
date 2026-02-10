import Foundation

// ============================================================================
// STRUCTURED DRAFT ENGINE — Context-Aware On-Device Prose Generator
//
// WHAT THIS IS:
// A deterministic but INTELLIGENT on-device draft engine that composes
// real prose from user context (calendar events, emails, files) instead
// of returning template placeholders like "[Add discussion points]".
//
// WHY:
// The DeterministicTemplateModel outputs fill-in-the-blank scaffolds.
// This engine reads ACTUAL context data and writes ACTUAL sentences,
// producing drafts that look and feel like real AI output — all on-device.
//
// INVARIANTS:
// - Strictly on-device. Zero network calls.
// - Citations only from selected context (CitationBuilder contract).
// - All output is a draft — never auto-sent.
// - Same OnDeviceModel interface → trivially swappable with CoreML/Apple later.
// ============================================================================

/// Composes structured prose drafts from user intent + context.
/// Not a template filler — a context-aware prose assembler.
enum StructuredDraftEngine {

    // ════════════════════════════════════════════════════════════════
    // MARK: - Email Draft
    // ════════════════════════════════════════════════════════════════

    static func composeEmail(
        intent: String,
        calendarItems: [CalendarContextItem],
        emailItems: [EmailContextItem],
        fileItems: [FileContextItem]
    ) -> (body: String, subject: String, actionItems: [String]) {
        var paragraphs: [String] = []
        var subject = "Follow-up"
        var actions: [String] = []

        // ── Greeting ─────────────────────────────────────
        paragraphs.append("Hi,")

        // ── Meeting-driven email ─────────────────────────
        if let meeting = calendarItems.first {
            subject = "Follow-up: \(meeting.title)"
            let attendeeClause = meeting.attendees.isEmpty
                ? ""
                : " with \(meeting.attendees.prefix(3).joined(separator: ", "))"
            paragraphs.append(
                "Thank you for the meeting\(attendeeClause) on \(meeting.formattedDate). " +
                "I wanted to recap what we discussed and outline next steps."
            )

            // Pull real notes into body
            if let notes = meeting.notes, !notes.isEmpty {
                let condensed = condense(notes, maxSentences: 3)
                paragraphs.append("From the meeting notes: \(condensed)")
            }

            // Attendee-based actions
            for attendee in meeting.attendees.prefix(2) {
                actions.append("Follow up with \(attendee) on action items")
            }

        // ── Reply-to-email ───────────────────────────────
        } else if let email = emailItems.first {
            subject = "Re: \(email.subject)"
            paragraphs.append(
                "Thanks for your email regarding \"\(email.subject)\". " +
                "I've reviewed the details and here are my thoughts."
            )
            if !email.bodyPreview.isEmpty {
                let preview = condense(email.bodyPreview, maxSentences: 2)
                paragraphs.append("Regarding your note: \(preview)")
            }
            actions.append("Review reply for accuracy before sending")

        // ── Intent-only ──────────────────────────────────
        } else {
            paragraphs.append(
                "I wanted to reach out regarding: \(intent)."
            )
        }

        // ── File references ──────────────────────────────
        if !fileItems.isEmpty {
            let fileNames = fileItems.prefix(3).map { $0.name }
            paragraphs.append(
                "I've attached the following for reference: \(fileNames.joined(separator: ", "))."
            )
        }

        // ── Closing ──────────────────────────────────────
        paragraphs.append("Please let me know if you have any questions or need clarification on any of the above.")
        paragraphs.append("Best regards")

        actions.append("Review email for tone and accuracy")
        actions.append("Confirm recipient before sending")

        return (paragraphs.joined(separator: "\n\n"), subject, actions)
    }

    // ════════════════════════════════════════════════════════════════
    // MARK: - Meeting Summary
    // ════════════════════════════════════════════════════════════════

    static func composeMeetingSummary(
        intent: String,
        calendarItems: [CalendarContextItem],
        emailItems: [EmailContextItem]
    ) -> (body: String, subject: String, actionItems: [String]) {
        var lines: [String] = []
        var actions: [String] = []
        var subject = "Meeting Summary"

        if let meeting = calendarItems.first {
            subject = "Summary: \(meeting.title)"

            lines.append("# \(meeting.title)")
            lines.append("")
            lines.append("**Date:** \(meeting.formattedDate)")
            lines.append("**Duration:** \(meeting.formattedDuration)")
            if !meeting.attendees.isEmpty {
                lines.append("**Attendees:** \(meeting.attendees.joined(separator: ", "))")
            }
            if let location = meeting.location, !location.isEmpty {
                lines.append("**Location:** \(location)")
            }
            lines.append("")

            // Real notes → real summary
            if let notes = meeting.notes, !notes.isEmpty {
                lines.append("## Discussion")
                let sentences = extractSentences(from: notes)
                for (i, sentence) in sentences.prefix(6).enumerated() {
                    lines.append("\(i + 1). \(sentence.trimmingCharacters(in: .whitespaces))")
                }
                lines.append("")
            }

            // Action items from attendees
            lines.append("## Action Items")
            for attendee in meeting.attendees.prefix(3) {
                lines.append("- [ ] \(attendee): Follow up on discussed items")
                actions.append("\(attendee): Follow up")
            }
            if meeting.attendees.isEmpty {
                lines.append("- [ ] Review meeting outcomes and assign owners")
                actions.append("Assign action item owners")
            }
            lines.append("")
            lines.append("## Next Steps")
            lines.append("- Share this summary with all attendees for review")
            lines.append("- Schedule follow-up meeting if needed")

            actions.append("Share summary with attendees")

        } else {
            // No calendar item — compose from intent
            lines.append("# Meeting Summary")
            lines.append("")
            lines.append("Regarding: \(intent)")
            lines.append("")
            lines.append("## Key Points")
            lines.append("- Context was provided without calendar event detail")
            lines.append("- Please add specific discussion points from your notes")
            lines.append("")
            lines.append("## Action Items")
            lines.append("- [ ] Add discussion points from the meeting")
            actions.append("Add discussion points manually")
        }

        return (lines.joined(separator: "\n"), subject, actions)
    }

    // ════════════════════════════════════════════════════════════════
    // MARK: - Task List / Action Items
    // ════════════════════════════════════════════════════════════════

    static func composeTaskList(
        intent: String,
        calendarItems: [CalendarContextItem],
        emailItems: [EmailContextItem],
        fileItems: [FileContextItem]
    ) -> (body: String, subject: String, actionItems: [String]) {
        var lines: [String] = []
        var actions: [String] = []
        let subject = "Action Items"
        var taskNum = 1

        lines.append("# Action Items")
        lines.append("")
        lines.append("Generated from: \(intent)")
        lines.append("")

        // Calendar-derived tasks
        for meeting in calendarItems {
            lines.append("### From: \(meeting.title) (\(meeting.formattedDate))")
            for attendee in meeting.attendees.prefix(2) {
                lines.append("- [ ] Follow up with \(attendee)")
                actions.append("Follow up with \(attendee)")
                taskNum += 1
            }
            if let notes = meeting.notes, !notes.isEmpty {
                let items = extractActionableItems(from: notes)
                for item in items.prefix(3) {
                    lines.append("- [ ] \(item)")
                    actions.append(item)
                    taskNum += 1
                }
            }
            lines.append("")
        }

        // Email-derived tasks
        for email in emailItems {
            lines.append("### From email: \(email.subject)")
            lines.append("- [ ] Reply to \(email.sender) regarding \(email.subject)")
            actions.append("Reply to \(email.sender)")
            taskNum += 1
            lines.append("")
        }

        // File-derived tasks
        for file in fileItems {
            lines.append("- [ ] Review: \(file.name)")
            actions.append("Review \(file.name)")
            taskNum += 1
        }

        if taskNum == 1 {
            lines.append("- [ ] Define specific tasks based on: \(intent)")
            actions.append("Define tasks")
        }

        lines.append("")
        lines.append("---")
        lines.append("*\(taskNum - 1) action items identified. Review and prioritize.*")

        return (lines.joined(separator: "\n"), subject, actions)
    }

    // ════════════════════════════════════════════════════════════════
    // MARK: - Document Summary
    // ════════════════════════════════════════════════════════════════

    static func composeDocumentSummary(
        intent: String,
        fileItems: [FileContextItem]
    ) -> (body: String, subject: String, actionItems: [String]) {
        var lines: [String] = []
        var actions: [String] = []
        var subject = "Document Summary"

        if let file = fileItems.first {
            subject = "Summary: \(file.name)"
            lines.append("# Summary: \(file.name)")
            lines.append("")
            lines.append("**File:** \(file.name)")
            lines.append("**Type:** \(file.fileType.uppercased())")
            lines.append("**Size:** \(file.formattedSize)")
            lines.append("")
            lines.append("## Overview")
            lines.append("This document was selected for review as part of: \(intent)")
            lines.append("")
            lines.append("## Key Observations")
            lines.append("- Document type: \(file.fileType.uppercased())")
            lines.append("- Further analysis requires opening the document in its native application")
            lines.append("")
            actions.append("Open \(file.name) for detailed review")
        } else {
            lines.append("# Document Summary")
            lines.append("")
            lines.append("No documents were attached. Please select files to summarize.")
        }

        lines.append("## Recommendations")
        lines.append("- Review document contents for accuracy")
        lines.append("- Extract key data points relevant to: \(intent)")
        actions.append("Extract key points from document")

        return (lines.joined(separator: "\n"), subject, actions)
    }

    // ════════════════════════════════════════════════════════════════
    // MARK: - Reminder
    // ════════════════════════════════════════════════════════════════

    static func composeReminder(
        intent: String,
        calendarItems: [CalendarContextItem],
        emailItems: [EmailContextItem]
    ) -> (body: String, subject: String, actionItems: [String]) {
        var body = ""
        var subject = "Reminder"
        var actions: [String] = []

        if let meeting = calendarItems.first {
            subject = "Reminder: \(meeting.title)"
            body = "Follow up on \"\(meeting.title)\" from \(meeting.formattedDate)."
            if !meeting.attendees.isEmpty {
                body += "\nParticipants: \(meeting.attendees.joined(separator: ", "))."
            }
            if let notes = meeting.notes, !notes.isEmpty {
                body += "\n\nKey context: \(condense(notes, maxSentences: 2))"
            }
            actions.append("Complete follow-up for \(meeting.title)")
        } else if let email = emailItems.first {
            subject = "Reminder: Reply to \(email.sender)"
            body = "Reply to \(email.sender) about \"\(email.subject)\"."
            if !email.bodyPreview.isEmpty {
                body += "\n\nContext: \(condense(email.bodyPreview, maxSentences: 2))"
            }
            actions.append("Reply to \(email.sender)")
        } else {
            subject = "Reminder"
            body = "Reminder: \(intent)"
            actions.append("Complete: \(intent)")
        }

        actions.append("Set appropriate time for this reminder")
        return (body, subject, actions)
    }

    // ════════════════════════════════════════════════════════════════
    // MARK: - Text Utilities (on-device, no model)
    // ════════════════════════════════════════════════════════════════

    /// Condense text to N sentences (deterministic, no model).
    private static func condense(_ text: String, maxSentences: Int) -> String {
        let sentences = extractSentences(from: text)
        let selected = sentences.prefix(maxSentences)
        return selected.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    /// Extract sentences from text.
    static func extractSentences(from text: String) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sub, _, _, _ in
            if let s = sub {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { sentences.append(trimmed) }
            }
        }
        return sentences
    }

    /// Extract actionable items from freeform notes.
    static func extractActionableItems(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var items: [String] = []
        let actionKeywords = ["follow up", "schedule", "send", "review", "prepare",
                              "complete", "check", "confirm", "update", "share",
                              "todo", "action", "need to", "must", "should"]
        for line in lines {
            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
            if lower.isEmpty { continue }
            // Bullet/checkbox lines
            if lower.hasPrefix("-") || lower.hasPrefix("•") || lower.hasPrefix("*") || lower.hasPrefix("[ ]") {
                let cleaned = line.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "- [ ] ", with: "")
                    .replacingOccurrences(of: "- ", with: "")
                    .replacingOccurrences(of: "• ", with: "")
                    .replacingOccurrences(of: "* ", with: "")
                if !cleaned.isEmpty { items.append(cleaned) }
                continue
            }
            // Lines containing action verbs
            for keyword in actionKeywords {
                if lower.contains(keyword) {
                    items.append(line.trimmingCharacters(in: .whitespaces))
                    break
                }
            }
        }
        return items
    }
}
