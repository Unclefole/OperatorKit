import Foundation
import EventKit

// ============================================================================
// SAFETY CONTRACT REFERENCE
// This file enforces: Guarantee #5 (Two-Key Writes), #3 (No Background Access)
// See: docs/SAFETY_CONTRACT.md
// Changes to reminder access require Safety Contract Change Approval
// ============================================================================

/// Service for reminders with controlled write capability
/// INVARIANT: Reminder writes require explicit two-key confirmation
/// INVARIANT: No background writes - only user-driven saves
/// INVARIANT: Single reminder per action - no bulk writes
@MainActor
final class ReminderService: ObservableObject {
    
    static let shared = ReminderService()
    
    // MARK: - Dependencies
    
    private let authAdapter = RemindersAuthAdapter.shared
    
    // MARK: - Published State
    
    @Published private(set) var authorizationState: AuthorizationState = .notDetermined
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var availableLists: [EKCalendar] = []
    @Published private(set) var defaultList: EKCalendar?
    
    // MARK: - Private
    
    private let eventStore = EKEventStore()
    
    // MARK: - Initialization
    
    private init() {
        refreshAuthorizationState()
    }
    
    // MARK: - Authorization (via Adapter)
    
    /// Refreshes the authorization state from the adapter
    /// Does NOT prompt the user - safe to call anytime
    func refreshAuthorizationState() {
        authorizationState = authAdapter.remindersAuthorizationStatus()
        log("Reminders authorization state: \(authorizationState.rawValue)")
        
        // Load available lists if authorized
        if isAuthorized {
            loadAvailableLists()
        }
    }
    
    /// Check if reminders access is authorized
    var isAuthorized: Bool {
        authAdapter.canReadReminders
    }
    
    /// Check if we can write reminders
    var canWrite: Bool {
        authAdapter.canWriteReminders
    }
    
    /// Get current authorization state (passthrough to adapter)
    var currentAuthState: AuthorizationState {
        authAdapter.remindersAuthorizationStatus()
    }
    
    /// Request reminders access (ONLY when user explicitly triggers)
    /// INVARIANT: Never called automatically - only from user action
    func requestAccess() async -> Bool {
        log("User-initiated reminders access request (via adapter)")
        
        let newState = await authAdapter.requestRemindersWriteAccess()
        
        await MainActor.run {
            authorizationState = newState
            if isAuthorized {
                loadAvailableLists()
            }
        }
        
        let granted = newState.canRead || newState.canWrite
        log("Reminders access \(granted ? "granted" : "denied"), state: \(newState.rawValue)")
        return granted
    }
    
    // MARK: - Available Lists
    
    private func loadAvailableLists() {
        let calendars = eventStore.calendars(for: .reminder)
        availableLists = calendars.filter { $0.allowsContentModifications }
        defaultList = eventStore.defaultCalendarForNewReminders()
        
        log("Loaded \(availableLists.count) reminder lists")
    }
    
    /// Refresh available lists (call after authorization changes)
    func refreshLists() {
        guard isAuthorized else { return }
        loadAvailableLists()
    }
    
    // MARK: - Reminder Preview (No Write)
    
    /// Creates a preview of a reminder - DOES NOT SAVE
    /// INVARIANT: No reminder is created in Reminders app
    func createPreview(from draft: Draft) -> ReminderPreview {
        let title: String
        let notes: String?
        let dueDate: Date?
        
        switch draft.type {
        case .reminder:
            title = draft.title
            notes = draft.content.body
            // Default to tomorrow at 9 AM
            dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
            
        default:
            // For non-reminder drafts, suggest a follow-up reminder
            title = "Follow up: \(draft.title)"
            notes = "Follow up on: \(draft.content.body.prefix(100))..."
            dueDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        }
        
        return ReminderPreview(
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: .medium
        )
    }
    
    /// Creates a preview from intent and context
    func createPreview(
        intent: IntentRequest?,
        context: ContextPacket?
    ) -> ReminderPreview {
        var title = "Reminder"
        var notes: String?
        let dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        
        if let intent = intent {
            title = "Follow up: \(intent.rawText.prefix(50))"
        }
        
        if let context = context {
            var notesParts: [String] = []
            
            if !context.calendarItems.isEmpty {
                let meetings = context.calendarItems.map { $0.title }.joined(separator: ", ")
                notesParts.append("Related meetings: \(meetings)")
            }
            
            if !context.emailItems.isEmpty {
                let emails = context.emailItems.map { $0.subject }.joined(separator: ", ")
                notesParts.append("Related emails: \(emails)")
            }
            
            notes = notesParts.joined(separator: "\n")
        }
        
        return ReminderPreview(
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: .medium
        )
    }
    
    // MARK: - Save Reminder (Phase 3B - Controlled Write)
    
    /// Save a reminder to Reminders app
    /// INVARIANT: Only called after two-key confirmation (ConfirmWriteView)
    /// INVARIANT: Single reminder per call - no bulk writes
    /// INVARIANT: Must be called from main actor (user-driven)
    /// INVARIANT: Requires ServiceAccessToken — only ExecutionEngine.swift can construct one.
    func saveReminder(
        accessToken: ServiceAccessToken,
        payload: ReminderPayload,
        secondConfirmationTimestamp: Date
    ) async -> ReminderSaveResult {
        // INVARIANT: Must be authorized
        guard isAuthorized else {
            logError("Attempted reminder save without authorization")
            return .failed(reason: "Reminders access not granted")
        }
        
        // INVARIANT: Second confirmation must have occurred
        #if DEBUG
        assert(secondConfirmationTimestamp.timeIntervalSinceNow < 0, "INVARIANT VIOLATION: Second confirmation timestamp must be in the past")
        assert(Date().timeIntervalSince(secondConfirmationTimestamp) < 60, "INVARIANT VIOLATION: Second confirmation too old (>60 seconds)")
        #endif
        
        // Log the operation
        log("Creating reminder: \(payload.title)")
        log("Second confirmation at: \(secondConfirmationTimestamp)")
        
        isLoading = true
        defer { isLoading = false }
        
        // Create the reminder
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = payload.title
        reminder.notes = payload.notes
        
        // Set due date if provided
        if let dueDate = payload.dueDate {
            let calendar = Calendar.current
            reminder.dueDateComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }
        
        // Set priority if provided
        if let priority = payload.priority {
            reminder.priority = priority.rawValue
        }
        
        // Set the target list
        if let listId = payload.listIdentifier,
           let targetList = availableLists.first(where: { $0.calendarIdentifier == listId }) {
            reminder.calendar = targetList
        } else if let defaultList = defaultList {
            // Use default list if no specific list chosen
            reminder.calendar = defaultList
        } else if let firstList = availableLists.first {
            // Fallback to first available list
            reminder.calendar = firstList
        } else {
            logError("No reminder lists available")
            return .failed(reason: "No reminder lists available on this device")
        }
        
        // Save the reminder
        do {
            try eventStore.save(reminder, commit: true)
            
            let identifier = reminder.calendarItemIdentifier
            log("Reminder created successfully: \(identifier)")
            
            return .success(
                identifier: identifier,
                payload: payload,
                confirmedAt: secondConfirmationTimestamp
            )
        } catch {
            logError("Failed to save reminder: \(error.localizedDescription)")
            return .failed(reason: error.localizedDescription)
        }
    }
    
    /// Save a reminder from a ReminderPreview (converts to payload)
    /// INVARIANT: Requires ServiceAccessToken — only ExecutionEngine.swift can construct one.
    func saveReminder(
        accessToken: ServiceAccessToken,
        preview: ReminderPreview,
        listIdentifier: String?,
        secondConfirmationTimestamp: Date
    ) async -> ReminderSaveResult {
        let payload = ReminderPayload(
            title: preview.title,
            notes: preview.notes,
            dueDate: preview.dueDate,
            priority: mapPreviewPriority(preview.priority),
            listIdentifier: listIdentifier
        )
        
        return await saveReminder(
            accessToken: accessToken,
            payload: payload,
            secondConfirmationTimestamp: secondConfirmationTimestamp
        )
    }
    
    private func mapPreviewPriority(_ priority: ReminderPreview.Priority) -> ReminderPayload.Priority {
        switch priority {
        case .none: return .none
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }

    // MARK: - Delete (Undo support)

    /// Delete a previously created reminder by identifier.
    /// INVARIANT: Requires ServiceAccessToken — only ExecutionEngine.swift can call.
    func deleteReminder(
        accessToken: ServiceAccessToken,
        identifier: String
    ) async -> Bool {
        do {
            let predicate = eventStore.predicateForReminders(in: nil)
            let reminders = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[EKReminder], Error>) in
                eventStore.fetchReminders(matching: predicate) { result in
                    cont.resume(returning: result ?? [])
                }
            }
            guard let reminder = reminders.first(where: { $0.calendarItemIdentifier == identifier }) else {
                return false
            }
            try eventStore.remove(reminder, commit: true)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Reminder Preview Model

/// A preview of a reminder (not saved to Reminders app)
struct ReminderPreview: Identifiable {
    let id: UUID
    let title: String
    let notes: String?
    let dueDate: Date?
    let priority: Priority
    
    enum Priority: String {
        case none = "None"
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        
        var intValue: Int {
            switch self {
            case .none: return 0
            case .low: return 9
            case .medium: return 5
            case .high: return 1
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: Priority = .medium
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.priority = priority
    }
    
    var formattedDueDate: String? {
        guard let dueDate = dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }
}

// MARK: - Reminder Save Result

enum ReminderSaveResult {
    case success(identifier: String, payload: ReminderPayload, confirmedAt: Date)
    case blocked(reason: String)
    case failed(reason: String)
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    var identifier: String? {
        if case .success(let id, _, _) = self { return id }
        return nil
    }
    
    var confirmedAt: Date? {
        if case .success(_, _, let date) = self { return date }
        return nil
    }
    
    var message: String {
        switch self {
        case .success:
            return "Reminder created successfully"
        case .blocked(let reason):
            return reason
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }
}
