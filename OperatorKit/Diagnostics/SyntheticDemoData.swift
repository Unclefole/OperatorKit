import Foundation

#if DEBUG
/// Provides synthetic demo data for testing without accessing real user data (Phase 6B)
/// This data is used when "Use Synthetic Demo Data" is enabled in Privacy Controls
///
/// Rules:
/// - DEBUG builds only
/// - Clearly labeled as synthetic
/// - Does not access real EventKit
/// - Audit trail marked as synthetic
enum SyntheticDemoData {
    
    // MARK: - Calendar Events
    
    /// Synthetic calendar events for demo mode
    static var calendarEvents: [SyntheticCalendarEvent] {
        let now = Date()
        let calendar = Calendar.current
        
        return [
            SyntheticCalendarEvent(
                id: "synthetic-cal-001",
                title: "Team Sync Meeting",
                startDate: calendar.date(byAdding: .hour, value: -2, to: now)!,
                endDate: calendar.date(byAdding: .hour, value: -1, to: now)!,
                location: "Conference Room A",
                participants: ["alice@example.com", "bob@example.com"]
            ),
            SyntheticCalendarEvent(
                id: "synthetic-cal-002",
                title: "Project Planning",
                startDate: calendar.date(byAdding: .day, value: -1, to: now)!,
                endDate: calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .hour, value: 1, to: now)!)!,
                location: "Virtual",
                participants: ["team@example.com"]
            ),
            SyntheticCalendarEvent(
                id: "synthetic-cal-003",
                title: "Client Call - Q1 Review",
                startDate: calendar.date(byAdding: .day, value: 1, to: now)!,
                endDate: calendar.date(byAdding: .day, value: 1, to: calendar.date(byAdding: .minute, value: 30, to: now)!)!,
                location: nil,
                participants: ["client@example.com", "sales@example.com"]
            ),
            SyntheticCalendarEvent(
                id: "synthetic-cal-004",
                title: "Weekly 1:1",
                startDate: calendar.date(byAdding: .day, value: 2, to: now)!,
                endDate: calendar.date(byAdding: .day, value: 2, to: calendar.date(byAdding: .minute, value: 45, to: now)!)!,
                location: "Manager's Office",
                participants: ["manager@example.com"]
            ),
            SyntheticCalendarEvent(
                id: "synthetic-cal-005",
                title: "Product Demo",
                startDate: calendar.date(byAdding: .day, value: 3, to: now)!,
                endDate: calendar.date(byAdding: .day, value: 3, to: calendar.date(byAdding: .hour, value: 1, to: now)!)!,
                location: "Demo Room",
                participants: ["product@example.com", "engineering@example.com", "design@example.com"]
            )
        ]
    }
    
    // MARK: - Reminders
    
    /// Synthetic reminders for demo mode
    static var reminders: [SyntheticReminder] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            SyntheticReminder(
                id: "synthetic-rem-001",
                title: "Follow up with client",
                notes: "Send proposal by end of week",
                dueDate: calendar.date(byAdding: .day, value: 2, to: now)
            ),
            SyntheticReminder(
                id: "synthetic-rem-002",
                title: "Review quarterly report",
                notes: nil,
                dueDate: calendar.date(byAdding: .day, value: 5, to: now)
            ),
            SyntheticReminder(
                id: "synthetic-rem-003",
                title: "Schedule team offsite",
                notes: "Book venue and send calendar invites",
                dueDate: nil
            )
        ]
    }
    
    // MARK: - Email Threads
    
    /// Synthetic email threads for demo mode
    static var emailThreads: [SyntheticEmailThread] {
        [
            SyntheticEmailThread(
                id: "synthetic-email-001",
                subject: "Re: Project Timeline Update",
                sender: "alice@example.com",
                snippet: "Thanks for the update. Can we discuss the new timeline...",
                date: Date().addingTimeInterval(-3600 * 2)
            ),
            SyntheticEmailThread(
                id: "synthetic-email-002",
                subject: "Meeting Notes - Team Sync",
                sender: "bob@example.com",
                snippet: "Here are the notes from today's meeting. Action items...",
                date: Date().addingTimeInterval(-3600 * 24)
            ),
            SyntheticEmailThread(
                id: "synthetic-email-003",
                subject: "Q1 Planning Document",
                sender: "manager@example.com",
                snippet: "Please review the attached planning document before...",
                date: Date().addingTimeInterval(-3600 * 48)
            )
        ]
    }
    
    // MARK: - Files
    
    /// Synthetic files for demo mode
    static var files: [SyntheticFile] {
        [
            SyntheticFile(
                id: "synthetic-file-001",
                name: "Q1_Report_Draft.pdf",
                type: "PDF",
                size: "2.4 MB"
            ),
            SyntheticFile(
                id: "synthetic-file-002",
                name: "Meeting_Notes_Jan.txt",
                type: "Text",
                size: "12 KB"
            ),
            SyntheticFile(
                id: "synthetic-file-003",
                name: "Project_Timeline.xlsx",
                type: "Spreadsheet",
                size: "156 KB"
            )
        ]
    }
    
    // MARK: - Context Summary for Audit
    
    /// Returns a context summary marked as synthetic for audit trail
    static func syntheticContextSummary(selectedIds: [String]) -> String {
        "[SYNTHETIC DATA] Selected \(selectedIds.count) demo item(s) for testing. No real user data was accessed."
    }
    
    /// Check if an ID is synthetic
    static func isSyntheticId(_ id: String) -> Bool {
        id.hasPrefix("synthetic-")
    }
}

// MARK: - Synthetic Data Models

struct SyntheticCalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let participants: [String]
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }
    
    var formattedParticipants: String {
        if participants.isEmpty {
            return "No participants"
        }
        return participants.joined(separator: ", ")
    }
}

struct SyntheticReminder: Identifiable {
    let id: String
    let title: String
    let notes: String?
    let dueDate: Date?
    
    var formattedDueDate: String? {
        guard let dueDate = dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dueDate)
    }
}

struct SyntheticEmailThread: Identifiable {
    let id: String
    let subject: String
    let sender: String
    let snippet: String
    let date: Date
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SyntheticFile: Identifiable {
    let id: String
    let name: String
    let type: String
    let size: String
}

// MARK: - Conversion to Context Items

extension SyntheticDemoData {

    /// Convert synthetic calendar event to CalendarContextItem
    static func toCalendarContextItem(_ event: SyntheticCalendarEvent) -> CalendarContextItem {
        CalendarContextItem(
            title: event.title,
            date: event.startDate,
            endDate: event.endDate,
            attendees: event.participants,
            location: event.location,
            eventIdentifier: event.id
        )
    }

    /// Convert synthetic email to EmailContextItem
    static func toEmailContextItem(_ email: SyntheticEmailThread) -> EmailContextItem {
        EmailContextItem(
            subject: email.subject,
            sender: email.sender,
            date: email.date,
            bodyPreview: email.snippet,
            messageIdentifier: email.id
        )
    }

    /// Convert synthetic file to FileContextItem
    static func toFileContextItem(_ file: SyntheticFile) -> FileContextItem {
        FileContextItem(
            name: file.name,
            fileType: file.type,
            path: "/synthetic/\(file.name)"
        )
    }
}

#endif
