import Foundation
import EventKit

// ============================================================================
// SAFETY CONTRACT REFERENCE
// This file enforces: Guarantee #3 (No Background Access), #7 (User-Selected Context)
// See: docs/SAFETY_CONTRACT.md
// Changes to calendar access require Safety Contract Change Approval
// ============================================================================

/// Service for reading and writing calendar events
/// INVARIANT: No background calendar access
/// INVARIANT: No bulk reads or writes - only user-selected events
/// INVARIANT: Write operations require two-key confirmation
/// INVARIANT: Update only allowed for user-selected events
@MainActor
final class CalendarService: ObservableObject {
    
    static let shared = CalendarService()
    
    // MARK: - Dependencies
    
    private let authAdapter = CalendarAuthAdapter.shared
    
    // MARK: - Published State
    
    @Published private(set) var authorizationState: AuthorizationState = .notDetermined
    @Published private(set) var isLoadingEvents: Bool = false
    @Published private(set) var isWriting: Bool = false
    @Published private(set) var lastError: CalendarError?
    @Published private(set) var availableCalendars: [EKCalendar] = []
    @Published private(set) var defaultCalendar: EKCalendar?
    
    // MARK: - Private
    
    private let eventStore = EKEventStore()
    
    // Track user-selected event identifiers for update validation
    private var userSelectedEventIdentifiers: Set<String> = []
    
    // MARK: - Initialization
    
    private init() {
        refreshAuthorizationState()
    }
    
    // MARK: - Authorization (via Adapter)
    
    /// Refreshes the authorization state from the adapter
    /// Does NOT prompt the user - safe to call anytime
    func refreshAuthorizationState() {
        authorizationState = authAdapter.eventsAuthorizationStatus()
        log("Calendar authorization state: \(authorizationState.rawValue)")
        
        // Load available calendars if authorized
        if isAuthorized {
            loadAvailableCalendars()
        }
    }
    
    /// Check if calendar access is authorized for reading
    var isAuthorized: Bool {
        authAdapter.canReadEvents
    }
    
    /// Check if we can write to calendar
    var canWrite: Bool {
        authAdapter.canWriteEvents
    }
    
    /// Get current authorization state (passthrough to adapter)
    var currentAuthState: AuthorizationState {
        authAdapter.eventsAuthorizationStatus()
    }
    
    /// Request calendar access (ONLY when user explicitly triggers)
    /// INVARIANT: Never called automatically - always user-initiated
    func requestAccess() async -> Bool {
        log("User-initiated calendar access request (via adapter)")
        
        let newState = await authAdapter.requestEventsWriteAccess()
        
        await MainActor.run {
            authorizationState = newState
            if isAuthorized {
                loadAvailableCalendars()
            }
        }
        
        let granted = newState.canRead || newState.canWrite
        log("Calendar access \(granted ? "granted" : "denied"), state: \(newState.rawValue)")
        return granted
    }
    
    // MARK: - Available Calendars
    
    private func loadAvailableCalendars() {
        let calendars = eventStore.calendars(for: .event)
        availableCalendars = calendars.filter { $0.allowsContentModifications }
        defaultCalendar = eventStore.defaultCalendarForNewEvents
        
        log("Loaded \(availableCalendars.count) writable calendars")
    }
    
    /// Refresh available calendars (call after authorization changes)
    func refreshCalendars() {
        guard isAuthorized else { return }
        loadAvailableCalendars()
    }
    
    // MARK: - Event Fetching (User-Driven Only)
    
    /// Fetches events for display in picker
    /// INVARIANT: Only called when user opens ContextPicker
    /// INVARIANT: Limited date range to prevent bulk reads
    func fetchEventsForSelection(
        daysBack: Int = 7,
        daysForward: Int = 7,
        limit: Int = 50
    ) async -> [CalendarEventModel] {
        guard isAuthorized else {
            log("Calendar not authorized - returning empty")
            return []
        }
        
        await MainActor.run {
            isLoadingEvents = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isLoadingEvents = false
            }
        }
        
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let endDate = calendar.date(byAdding: .day, value: daysForward, to: Date()) ?? Date()
        
        log("Fetching calendar events from \(startDate) to \(endDate)")
        
        // Create predicate for date range
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil // All calendars user has access to
        )
        
        // Fetch events
        let events = eventStore.events(matching: predicate)
        
        // Convert to our model and limit results
        let models = events.prefix(limit).map { CalendarEventModel(from: $0) }
        
        log("Fetched \(models.count) calendar events")
        
        return Array(models)
    }
    
    /// Fetches a single event by identifier
    /// INVARIANT: Only fetches the specific event requested
    func fetchEvent(identifier: String) async -> CalendarEventModel? {
        guard isAuthorized else { return nil }
        
        guard let event = eventStore.event(withIdentifier: identifier) else {
            return nil
        }
        
        return CalendarEventModel(from: event)
    }
    
    /// Fetches specific events by identifiers (user-selected only)
    /// INVARIANT: Only fetches events the user has explicitly selected
    func fetchSelectedEvents(identifiers: Set<String>) async -> [CalendarEventModel] {
        guard isAuthorized else { return [] }
        
        var results: [CalendarEventModel] = []
        
        for identifier in identifiers {
            if let event = eventStore.event(withIdentifier: identifier) {
                results.append(CalendarEventModel(from: event))
            }
        }
        
        // Track these as user-selected for update validation
        userSelectedEventIdentifiers = userSelectedEventIdentifiers.union(identifiers)
        
        log("Fetched \(results.count) selected calendar events")
        return results
    }
    
    /// Register an event identifier as user-selected (for update validation)
    /// INVARIANT: Only call when user explicitly selects an event in UI
    func registerUserSelectedEvent(identifier: String) {
        userSelectedEventIdentifiers.insert(identifier)
        log("Registered user-selected event: \(identifier)")
    }
    
    /// Check if an event was user-selected (for update validation)
    /// INVARIANT: Update only allowed if this returns true
    func isEventUserSelected(identifier: String) -> Bool {
        userSelectedEventIdentifiers.contains(identifier)
    }
    
    /// Clear user-selected events (call when returning home)
    func clearUserSelectedEvents() {
        userSelectedEventIdentifiers.removeAll()
        log("Cleared user-selected events")
    }
    
    // MARK: - Event Writing (Phase 3C)
    
    /// Create a new calendar event
    /// INVARIANT: Only called after two-key confirmation
    /// INVARIANT: Single event per call - no bulk writes
    func createEvent(
        payload: CalendarEventPayload,
        secondConfirmationTimestamp: Date
    ) async -> CalendarWriteResult {
        // INVARIANT: Must be authorized for write
        guard canWrite else {
            logError("Attempted calendar write without authorization")
            return .failed(reason: "Calendar write access not granted")
        }
        
        // INVARIANT: Second confirmation must have occurred
        #if DEBUG
        assert(secondConfirmationTimestamp.timeIntervalSinceNow < 0, "INVARIANT VIOLATION: Second confirmation timestamp must be in the past")
        assert(Date().timeIntervalSince(secondConfirmationTimestamp) < 60, "INVARIANT VIOLATION: Second confirmation too old (>60 seconds)")
        #endif
        
        // Log the operation
        log("Creating calendar event: \(payload.title)")
        log("Second confirmation at: \(secondConfirmationTimestamp)")
        
        isWriting = true
        defer { isWriting = false }
        
        // Create the event
        let event = EKEvent(eventStore: eventStore)
        event.title = payload.title
        event.startDate = payload.startDate
        event.endDate = payload.endDate
        event.location = payload.location
        event.notes = payload.notes
        
        // Set timezone if provided
        if let tzIdentifier = payload.timeZoneIdentifier,
           let tz = TimeZone(identifier: tzIdentifier) {
            event.timeZone = tz
        }
        
        // Add attendees (email only - DO NOT lookup in Contacts)
        // Note: EKEvent doesn't allow direct attendee modification without calendar server support
        // We store them in notes for reference
        if !payload.attendeesEmails.isEmpty {
            let attendeeNote = "Attendees: " + payload.attendeesEmails.joined(separator: ", ")
            event.notes = (event.notes ?? "") + "\n\n" + attendeeNote
        }
        
        // Add alarms
        for offsetMinutes in payload.alarmOffsetsMinutes {
            let alarm = EKAlarm(relativeOffset: TimeInterval(offsetMinutes * 60))
            event.addAlarm(alarm)
        }
        
        // Set the target calendar
        if let calId = payload.calendarIdentifier,
           let targetCal = availableCalendars.first(where: { $0.calendarIdentifier == calId }) {
            event.calendar = targetCal
        } else if let defaultCal = defaultCalendar {
            event.calendar = defaultCal
        } else if let firstCal = availableCalendars.first {
            event.calendar = firstCal
        } else {
            logError("No calendars available for writing")
            return .failed(reason: "No calendars available on this device")
        }
        
        // Save the event
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            
            let identifier = event.eventIdentifier ?? "unknown"
            log("Calendar event created successfully: \(identifier)")
            
            return .success(
                eventIdentifier: identifier,
                operation: .created,
                payload: payload,
                confirmedAt: secondConfirmationTimestamp
            )
        } catch {
            logError("Failed to save calendar event: \(error.localizedDescription)")
            return .failed(reason: error.localizedDescription)
        }
    }
    
    /// Update an existing calendar event
    /// INVARIANT: Only called after two-key confirmation
    /// INVARIANT: originalEventIdentifier must be from user-selected context
    /// INVARIANT: Single event per call - no bulk writes
    func updateEvent(
        payload: CalendarEventPayload,
        secondConfirmationTimestamp: Date
    ) async -> CalendarWriteResult {
        // INVARIANT: Must have originalEventIdentifier
        guard let originalId = payload.originalEventIdentifier else {
            logError("Attempted update without originalEventIdentifier")
            #if DEBUG
            assertionFailure("INVARIANT VIOLATION: Update requires originalEventIdentifier")
            #endif
            return .failed(reason: "No original event identifier provided")
        }
        
        // INVARIANT: Original event must be user-selected
        guard isEventUserSelected(identifier: originalId) else {
            logError("Attempted update on non-user-selected event: \(originalId)")
            #if DEBUG
            assertionFailure("INVARIANT VIOLATION: Update only allowed for user-selected events")
            #endif
            return .failed(reason: "Event was not user-selected in context")
        }
        
        // INVARIANT: Must be authorized for write
        guard canWrite else {
            logError("Attempted calendar write without authorization")
            return .failed(reason: "Calendar write access not granted")
        }
        
        // INVARIANT: Second confirmation must have occurred
        #if DEBUG
        assert(secondConfirmationTimestamp.timeIntervalSinceNow < 0, "INVARIANT VIOLATION: Second confirmation timestamp must be in the past")
        assert(Date().timeIntervalSince(secondConfirmationTimestamp) < 60, "INVARIANT VIOLATION: Second confirmation too old")
        #endif
        
        // Fetch the original event
        guard let event = eventStore.event(withIdentifier: originalId) else {
            logError("Original event not found: \(originalId)")
            return .failed(reason: "Original event not found")
        }
        
        log("Updating calendar event: \(originalId)")
        log("Second confirmation at: \(secondConfirmationTimestamp)")
        
        isWriting = true
        defer { isWriting = false }
        
        // Apply updates
        event.title = payload.title
        event.startDate = payload.startDate
        event.endDate = payload.endDate
        event.location = payload.location
        event.notes = payload.notes
        
        // Set timezone if provided
        if let tzIdentifier = payload.timeZoneIdentifier,
           let tz = TimeZone(identifier: tzIdentifier) {
            event.timeZone = tz
        }
        
        // Update alarms - remove existing and add new
        if let existingAlarms = event.alarms {
            for alarm in existingAlarms {
                event.removeAlarm(alarm)
            }
        }
        for offsetMinutes in payload.alarmOffsetsMinutes {
            let alarm = EKAlarm(relativeOffset: TimeInterval(offsetMinutes * 60))
            event.addAlarm(alarm)
        }
        
        // Save the event
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            
            let identifier = event.eventIdentifier ?? originalId
            log("Calendar event updated successfully: \(identifier)")
            
            return .success(
                eventIdentifier: identifier,
                operation: .updated,
                payload: payload,
                confirmedAt: secondConfirmationTimestamp
            )
        } catch {
            logError("Failed to update calendar event: \(error.localizedDescription)")
            return .failed(reason: error.localizedDescription)
        }
    }
    
    // MARK: - Error Types
    
    enum CalendarError: Error, LocalizedError {
        case notAuthorized
        case accessRequestFailed(String)
        case fetchFailed(String)
        case writeFailed(String)
        case eventNotFound(String)
        case eventNotUserSelected(String)
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Calendar access not authorized"
            case .accessRequestFailed(let reason):
                return "Calendar access request failed: \(reason)"
            case .fetchFailed(let reason):
                return "Failed to fetch calendar events: \(reason)"
            case .writeFailed(let reason):
                return "Failed to write calendar event: \(reason)"
            case .eventNotFound(let id):
                return "Event not found: \(id)"
            case .eventNotUserSelected(let id):
                return "Event was not user-selected: \(id)"
            }
        }
    }
}

// MARK: - Calendar Write Result

enum CalendarWriteResult {
    case success(eventIdentifier: String, operation: CalendarOperation, payload: CalendarEventPayload, confirmedAt: Date)
    case blocked(reason: String)
    case failed(reason: String)
    
    enum CalendarOperation: String, Codable {
        case created = "created"
        case updated = "updated"
    }
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    var identifier: String? {
        if case .success(let id, _, _, _) = self { return id }
        return nil
    }
    
    var operation: CalendarOperation? {
        if case .success(_, let op, _, _) = self { return op }
        return nil
    }
    
    var confirmedAt: Date? {
        if case .success(_, _, _, let date) = self { return date }
        return nil
    }
    
    var message: String {
        switch self {
        case .success(_, let operation, _, _):
            return "Calendar event \(operation.rawValue) successfully"
        case .blocked(let reason):
            return reason
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }
}

// MARK: - Calendar Event Model

/// Read-only model representing a calendar event
/// Contains only the metadata needed for context
struct CalendarEventModel: Identifiable, Equatable {
    let id: String // Event identifier
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let participants: [ParticipantModel]
    let calendarTitle: String?
    let calendarColor: String? // Hex color
    let calendarIdentifier: String?
    
    init(from event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = event.title ?? "Untitled Event"
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.isAllDay = event.isAllDay
        self.location = event.location
        self.notes = event.notes
        self.participants = event.attendees?.compactMap { ParticipantModel(from: $0) } ?? []
        self.calendarTitle = event.calendar?.title
        self.calendarIdentifier = event.calendar?.calendarIdentifier
        
        // Convert calendar color to hex
        if let cgColor = event.calendar?.cgColor,
           let components = cgColor.components,
           components.count >= 3 {
            let r = Int(components[0] * 255)
            let g = Int(components[1] * 255)
            let b = Int(components[2] * 255)
            self.calendarColor = String(format: "#%02X%02X%02X", r, g, b)
        } else {
            self.calendarColor = nil
        }
    }
    
    // Formatted properties
    var formattedDateRange: String {
        let formatter = DateFormatter()
        
        if isAllDay {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: startDate)
        }
        
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let start = formatter.string(from: startDate)
        
        // If same day, only show time for end
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            formatter.dateStyle = .none
            let end = formatter.string(from: endDate)
            return "\(start) - \(end)"
        } else {
            let end = formatter.string(from: endDate)
            return "\(start) - \(end)"
        }
    }
    
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours) hour\(hours > 1 ? "s" : "")"
        } else {
            return "\(minutes) min"
        }
    }
    
    var participantNames: [String] {
        participants.map { $0.name }
    }
    
    var participantEmails: [String] {
        participants.compactMap { $0.email }
    }
    
    /// Convert to ContextPacket item
    func toContextItem() -> CalendarContextItem {
        CalendarContextItem(
            id: UUID(), // Generate new ID for context
            title: title,
            date: startDate,
            duration: duration,
            attendees: participantNames,
            notes: notes,
            eventIdentifier: id
        )
    }
    
    /// Convert to CalendarEventPayload (for update operations)
    func toPayload(withChanges: Bool = false) -> CalendarEventPayload {
        CalendarEventPayload(
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            notes: notes,
            calendarIdentifier: calendarIdentifier,
            attendeesEmails: participantEmails,
            alarmOffsetsMinutes: [], // Would need to read from EKEvent
            originalEventIdentifier: withChanges ? id : nil
        )
    }
    
    static func == (lhs: CalendarEventModel, rhs: CalendarEventModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Participant Model

struct ParticipantModel: Identifiable, Equatable {
    let id: UUID
    let name: String
    let email: String?
    let isOrganizer: Bool
    let status: ParticipantStatus
    
    enum ParticipantStatus: String {
        case accepted
        case declined
        case tentative
        case pending
        case unknown
    }
    
    init?(from attendee: EKParticipant) {
        guard let name = attendee.name ?? attendee.url?.absoluteString else {
            return nil
        }
        
        self.id = UUID()
        self.name = name
        self.email = attendee.url?.absoluteString.replacingOccurrences(of: "mailto:", with: "")
        self.isOrganizer = attendee.isCurrentUser
        
        switch attendee.participantStatus {
        case .accepted:
            self.status = .accepted
        case .declined:
            self.status = .declined
        case .tentative:
            self.status = .tentative
        case .pending:
            self.status = .pending
        default:
            self.status = .unknown
        }
    }
    
    static func == (lhs: ParticipantModel, rhs: ParticipantModel) -> Bool {
        lhs.id == rhs.id
    }
}
