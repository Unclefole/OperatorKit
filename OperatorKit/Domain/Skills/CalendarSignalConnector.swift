import Foundation
import EventKit

// ============================================================================
// CALENDAR SIGNAL CONNECTOR — LIVE READ-ONLY DATA SOURCE FOR SKILLS
//
// Reads upcoming calendar events and produces SkillInput for Micro-Operators.
// This is a READ-ONLY connector. It does NOT create, update, or delete events.
//
// INVARIANT: Uses CalendarReadAccess protocol ONLY (no write methods).
// INVARIANT: MUST NOT reference ExecutionEngine, ServiceAccessToken.
// INVARIANT: MUST NOT reference CalendarService write methods.
// INVARIANT: Produces SkillInput only — no side effects.
// ============================================================================

@MainActor
public final class CalendarSignalConnector: ObservableObject {

    public static let shared = CalendarSignalConnector()

    @Published public private(set) var isAuthorized: Bool = false
    @Published public private(set) var lastFetchDate: Date?
    @Published public private(set) var eventCount: Int = 0

    /// Read-only access — explicitly typed to prevent write access
    private let calendarReader: any CalendarReadAccess = CalendarService.readOnly

    private init() {
        refreshAuthorization()
    }

    // MARK: - Authorization

    public func refreshAuthorization() {
        isAuthorized = calendarReader.isAuthorized
    }

    public func requestAccess() async -> Bool {
        let granted = await calendarReader.requestAccess()
        isAuthorized = granted
        return granted
    }

    // MARK: - Fetch & Build SkillInput

    /// Fetch upcoming events and produce a SkillInput for skill processing.
    /// Returns nil if not authorized or no events found.
    public func fetchUpcomingEventsInput(daysForward: Int = 7) async -> SkillInput? {
        guard isAuthorized else {
            log("[CALENDAR_CONNECTOR] Not authorized — cannot fetch events")
            return nil
        }

        let events = await calendarReader.fetchEventsForSelection(
            daysBack: 1,
            daysForward: daysForward,
            limit: 20
        )

        guard !events.isEmpty else {
            log("[CALENDAR_CONNECTOR] No events found in range")
            return nil
        }

        eventCount = events.count
        lastFetchDate = Date()

        // Build a structured text representation for skill consumption
        let textContent = buildEventSummary(events: events)

        return SkillInput(
            inputType: .emailThread, // Closest match — reuse for "inbound signals"
            textContent: textContent,
            metadata: [
                "source": "calendar_connector",
                "event_count": "\(events.count)",
                "days_forward": "\(daysForward)",
                "fetched_at": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    /// Fetch today's events specifically for meeting action extraction.
    public func fetchTodaysMeetingsInput() async -> SkillInput? {
        guard isAuthorized else { return nil }

        let events = await calendarReader.fetchEventsForSelection(
            daysBack: 0,
            daysForward: 1,
            limit: 15
        )

        let meetings = events.filter { event in
            // Filter for meetings (longer than 15 min)
            let duration = event.endDate.timeIntervalSince(event.startDate)
            return duration >= 900 // 15 minutes
        }

        guard !meetings.isEmpty else { return nil }

        let textContent = buildMeetingSummary(events: meetings)

        return SkillInput(
            inputType: .meetingTranscript,
            textContent: textContent,
            metadata: [
                "source": "calendar_connector",
                "meeting_count": "\(meetings.count)",
                "scope": "today"
            ]
        )
    }

    // MARK: - Private Helpers

    private func buildEventSummary(events: [CalendarEventModel]) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short

        var lines: [String] = ["Calendar Summary — \(events.count) upcoming events:\n"]

        for event in events {
            var line = "- \(event.title)"
            line += " | \(df.string(from: event.startDate))"
            if let location = event.location, !location.isEmpty {
                line += " | Location: \(location)"
            }
            if let notes = event.notes, !notes.isEmpty {
                let truncated = String(notes.prefix(120))
                line += " | Notes: \(truncated)"
            }
            if event.isAllDay {
                line += " [All Day]"
            }
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    private func buildMeetingSummary(events: [CalendarEventModel]) -> String {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short

        var lines: [String] = ["Today's Meetings — \(events.count) scheduled:\n"]

        for event in events {
            var line = "Meeting: \(event.title)"
            line += " (\(df.string(from: event.startDate)) – \(df.string(from: event.endDate)))"
            if let notes = event.notes, !notes.isEmpty {
                line += "\nNotes: \(String(notes.prefix(200)))"
            }
            lines.append(line)
        }

        return lines.joined(separator: "\n\n")
    }
}
