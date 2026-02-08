import Foundation

// MARK: - Reminder Payload

/// Payload for reminder-related side effects
/// INVARIANT: Payload must be populated before any reminder write
struct ReminderPayload: Equatable, Codable {
    let title: String
    let notes: String?
    let dueDate: Date?
    let priority: Priority?
    let listIdentifier: String? // EKCalendar identifier for reminders list
    
    enum Priority: Int, Codable, CaseIterable {
        case none = 0
        case low = 9
        case medium = 5
        case high = 1
        
        var displayName: String {
            switch self {
            case .none: return "None"
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
    }
    
    init(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: Priority? = nil,
        listIdentifier: String? = nil
    ) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.priority = priority
        self.listIdentifier = listIdentifier
    }
    
    /// Summary for display
    var displaySummary: String {
        var parts: [String] = [title]
        if let dueDate = dueDate {
            parts.append("Due: \(dueDate.formatted(date: .abbreviated, time: .shortened))")
        }
        if let priority = priority, priority != .none {
            parts.append("Priority: \(priority.displayName)")
        }
        return parts.joined(separator: " • ")
    }
}

// MARK: - Calendar Event Payload (Phase 3C)

/// Payload for calendar event side effects
/// INVARIANT: Payload must be populated before any calendar write
/// INVARIANT: For updates, originalEventIdentifier must be from user-selected context
struct CalendarEventPayload: Equatable, Codable {
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let calendarIdentifier: String? // If nil, use user's default calendar
    let attendeesEmails: [String] // DO NOT auto-fetch from Contacts
    let alarmOffsetsMinutes: [Int] // e.g., [-15, -60] for 15min and 1hr before
    let timeZoneIdentifier: String?
    
    // For UPDATE operations only
    let originalEventIdentifier: String? // INVARIANT: Must be from user-selected context
    
    init(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String? = nil,
        calendarIdentifier: String? = nil,
        attendeesEmails: [String] = [],
        alarmOffsetsMinutes: [Int] = [],
        timeZoneIdentifier: String? = nil,
        originalEventIdentifier: String? = nil
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.calendarIdentifier = calendarIdentifier
        self.attendeesEmails = attendeesEmails
        self.alarmOffsetsMinutes = alarmOffsetsMinutes
        self.timeZoneIdentifier = timeZoneIdentifier
        self.originalEventIdentifier = originalEventIdentifier
    }
    
    /// Duration in minutes
    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }
    
    /// Formatted time range
    var formattedTimeRange: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        let sameDay = Calendar.current.isDate(startDate, inSameDayAs: endDate)
        
        if sameDay {
            return "\(dateFormatter.string(from: startDate)) – \(timeFormatter.string(from: endDate))"
        } else {
            return "\(dateFormatter.string(from: startDate)) – \(dateFormatter.string(from: endDate))"
        }
    }
    
    /// Summary for display
    var displaySummary: String {
        var parts: [String] = [title, formattedTimeRange]
        if let location = location, !location.isEmpty {
            parts.append("📍 \(location)")
        }
        if !attendeesEmails.isEmpty {
            parts.append("👥 \(attendeesEmails.count) attendee\(attendeesEmails.count == 1 ? "" : "s")")
        }
        return parts.joined(separator: " • ")
    }
    
    /// Whether this is an update operation
    var isUpdate: Bool {
        originalEventIdentifier != nil
    }
}

// MARK: - Calendar Event Diff (For Updates)

/// Represents changes between original and updated event
/// INVARIANT: Only generated when originalEventIdentifier is present
/// Note: Tuple properties prevent automatic Codable conformance
struct CalendarEventDiff: Equatable {
    let titleChanged: (old: String, new: String)?
    let startDateChanged: (old: Date, new: Date)?
    let endDateChanged: (old: Date, new: Date)?
    let locationChanged: (old: String?, new: String?)?
    let notesChanged: (old: String?, new: String?)?
    let attendeesChanged: (added: [String], removed: [String])?
    
    var hasChanges: Bool {
        titleChanged != nil ||
        startDateChanged != nil ||
        endDateChanged != nil ||
        locationChanged != nil ||
        notesChanged != nil ||
        attendeesChanged != nil
    }
    
    var summary: String {
        var changes: [String] = []
        if titleChanged != nil { changes.append("title") }
        if startDateChanged != nil { changes.append("start time") }
        if endDateChanged != nil { changes.append("end time") }
        if locationChanged != nil { changes.append("location") }
        if notesChanged != nil { changes.append("notes") }
        if attendeesChanged != nil { changes.append("attendees") }
        return changes.isEmpty ? "No changes" : "Changed: \(changes.joined(separator: ", "))"
    }
    
    // Equatable conformance for tuples
    static func == (lhs: CalendarEventDiff, rhs: CalendarEventDiff) -> Bool {
        lhs.summary == rhs.summary
    }
}

// MARK: - Side Effect

/// Represents a side effect that will occur upon execution
/// INVARIANT: All side effects must be declared before approval
/// INVARIANT: All enabled side effects must be acknowledged before execution
/// INVARIANT: Write operations (.createReminder, .createCalendarEvent, .updateCalendarEvent) require two-key confirmation
struct SideEffect: Identifiable, Equatable {
    let id: UUID
    let type: SideEffectType
    let description: String
    let requiresPermission: PermissionType?
    var isEnabled: Bool
    var isAcknowledged: Bool
    
    // MARK: - Reminder-specific payload
    /// Payload for reminder side effects
    /// INVARIANT: Must be non-nil for .previewReminder and .createReminder
    var reminderPayload: ReminderPayload?
    
    // MARK: - Calendar-specific payload (Phase 3C)
    /// Payload for calendar event side effects
    /// INVARIANT: Must be non-nil for .previewCalendarEvent, .createCalendarEvent, .updateCalendarEvent
    var calendarEventPayload: CalendarEventPayload?
    
    /// Diff for calendar update operations
    /// INVARIANT: Must be non-nil for .updateCalendarEvent
    var calendarEventDiff: CalendarEventDiff?
    
    // MARK: - Two-key confirmation tracking
    /// Whether the second confirmation (ConfirmWriteView/ConfirmCalendarWriteView) has been completed
    /// INVARIANT: Write operations cannot execute unless this is true
    var secondConfirmationGranted: Bool = false
    
    /// Timestamp when second confirmation was granted
    var secondConfirmationTimestamp: Date?
    
    /// Type of side effect
    enum SideEffectType: String, Codable, CaseIterable {
        case sendEmail = "send_email"
        case presentEmailDraft = "present_email_draft"      // Opens composer, user sends manually
        case saveDraft = "save_draft"
        case createReminder = "create_reminder"             // WRITES to Reminders (requires two-key)
        case previewReminder = "preview_reminder"           // Shows preview, does NOT write
        case previewCalendarEvent = "preview_calendar_event" // Phase 3C: Shows preview, does NOT write
        case createCalendarEvent = "create_calendar_event"   // Phase 3C: WRITES to Calendar (requires two-key)
        case updateCalendarEvent = "update_calendar_event"   // Phase 3C: UPDATES Calendar (requires two-key)
        case saveToMemory = "save_to_memory"
        
        var displayName: String {
            switch self {
            case .sendEmail: return "Send Email"
            case .presentEmailDraft: return "Open Email Composer"
            case .saveDraft: return "Save Draft"
            case .createReminder: return "Create Reminder in Reminders App"
            case .previewReminder: return "Preview Reminder (no write)"
            case .previewCalendarEvent: return "Preview Calendar Event (no write)"
            case .createCalendarEvent: return "Create Calendar Event"
            case .updateCalendarEvent: return "Update Calendar Event"
            case .saveToMemory: return "Save to Memory"
            }
        }
        
        var icon: String {
            switch self {
            case .sendEmail, .presentEmailDraft: return "envelope.fill"
            case .saveDraft: return "doc.fill"
            case .createReminder: return "bell.badge.fill"
            case .previewReminder: return "bell"
            case .previewCalendarEvent: return "calendar"
            case .createCalendarEvent: return "calendar.badge.plus"
            case .updateCalendarEvent: return "calendar.badge.clock"
            case .saveToMemory: return "brain"
            }
        }
        
        /// Whether this side effect requires user interaction to complete
        var requiresUserAction: Bool {
            switch self {
            case .presentEmailDraft:
                return true // User must manually send
            default:
                return false
            }
        }
        
        /// Whether this side effect performs a real write operation
        var isWriteOperation: Bool {
            switch self {
            case .createReminder, .createCalendarEvent, .updateCalendarEvent, .sendEmail:
                return true
            default:
                return false
            }
        }
        
        /// Whether this side effect requires two-key confirmation
        var requiresTwoKeyConfirmation: Bool {
            switch self {
            case .createReminder, .createCalendarEvent, .updateCalendarEvent:
                return true // INVARIANT: All writes require second confirmation
            default:
                return false
            }
        }
        
        /// Whether this is a calendar-related type
        var isCalendarOperation: Bool {
            switch self {
            case .previewCalendarEvent, .createCalendarEvent, .updateCalendarEvent:
                return true
            default:
                return false
            }
        }
    }
    
    /// Permission required for this side effect (if any)
    enum PermissionType: String, Codable, CaseIterable {
        case calendar = "Calendar Access"
        case mail = "Mail Access"
        case reminders = "Reminders Access"
        
        var systemFramework: String {
            switch self {
            case .calendar: return "EventKit"
            case .mail: return "MessageUI"
            case .reminders: return "EventKit"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        type: SideEffectType,
        description: String,
        requiresPermission: PermissionType? = nil,
        isEnabled: Bool = true,
        isAcknowledged: Bool = false,
        reminderPayload: ReminderPayload? = nil,
        calendarEventPayload: CalendarEventPayload? = nil,
        calendarEventDiff: CalendarEventDiff? = nil
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.requiresPermission = requiresPermission
        self.isEnabled = isEnabled
        self.isAcknowledged = isAcknowledged
        self.reminderPayload = reminderPayload
        self.calendarEventPayload = calendarEventPayload
        self.calendarEventDiff = calendarEventDiff
        
        // INVARIANT: Enabled reminder side effects must have payload
        // Note: Disabled effects may be placeholders during planning phase
        #if DEBUG
        if isEnabled && (type == .createReminder || type == .previewReminder) {
            assert(reminderPayload != nil, "INVARIANT VIOLATION: Enabled reminder side effect requires payload")
        }
        // INVARIANT: Enabled calendar side effects must have payload
        if isEnabled && (type == .previewCalendarEvent || type == .createCalendarEvent || type == .updateCalendarEvent) {
            assert(calendarEventPayload != nil, "INVARIANT VIOLATION: Enabled calendar side effect requires payload")
        }
        // INVARIANT: Update calendar must have originalEventIdentifier
        if isEnabled && type == .updateCalendarEvent {
            assert(calendarEventPayload?.originalEventIdentifier != nil, "INVARIANT VIOLATION: Update calendar requires originalEventIdentifier from user-selected context")
        }
        #endif
    }
    
    /// Mark this side effect as acknowledged by the user
    mutating func acknowledge() {
        isAcknowledged = true
    }
    
    /// Toggle enabled state (disabled effects are auto-acknowledged)
    mutating func toggle() {
        isEnabled.toggle()
        if !isEnabled {
            isAcknowledged = true
            secondConfirmationGranted = false // Reset second confirmation when disabled
            secondConfirmationTimestamp = nil
        }
    }
    
    /// Grant second confirmation (two-key turn)
    /// INVARIANT: Only call this from ConfirmWriteView/ConfirmCalendarWriteView
    mutating func grantSecondConfirmation() {
        #if DEBUG
        assert(type.requiresTwoKeyConfirmation, "INVARIANT VIOLATION: Second confirmation only valid for two-key operations")
        assert(isEnabled, "INVARIANT VIOLATION: Cannot grant second confirmation for disabled effect")
        assert(isAcknowledged, "INVARIANT VIOLATION: Must acknowledge before second confirmation")
        #endif
        secondConfirmationGranted = true
        secondConfirmationTimestamp = Date()
    }
    
    /// Returns true if this side effect can be executed
    var canExecute: Bool {
        guard isEnabled else { return true } // Disabled effects don't block
        guard isAcknowledged else { return false }
        
        // INVARIANT: Two-key operations require second confirmation
        if type.requiresTwoKeyConfirmation {
            return secondConfirmationGranted
        }
        
        return true
    }
    
    /// Returns true if this side effect needs two-key confirmation before execution
    var needsTwoKeyConfirmation: Bool {
        isEnabled && isAcknowledged && type.requiresTwoKeyConfirmation && !secondConfirmationGranted
    }
    
    /// Check if second confirmation is still fresh (within 60 seconds)
    var isSecondConfirmationFresh: Bool {
        guard let timestamp = secondConfirmationTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) < 60
    }
    
    static func == (lhs: SideEffect, rhs: SideEffect) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Side Effect Builder

/// Builds side effects based on draft type
struct SideEffectBuilder {
    
    /// Build side effects for a draft
    /// Phase 3C: Supports preview AND create for calendar events
    static func build(
        for draft: Draft,
        includeReminderWrite: Bool = false,
        includeCalendarWrite: Bool = false,
        calendarEventPayload: CalendarEventPayload? = nil
    ) -> [SideEffect] {
        var effects: [SideEffect] = []
        
        switch draft.type {
        case .email:
            // Primary: Open email composer (user must manually send)
            // INVARIANT: App cannot send automatically
            if let recipient = draft.content.recipient {
                effects.append(SideEffect(
                    type: .presentEmailDraft,
                    description: "Open email composer for \(recipient) (you send manually)",
                    requiresPermission: .mail,
                    isEnabled: true,
                    isAcknowledged: false
                ))
            }
            
            // Alternative: Save draft only (to OperatorKit memory)
            effects.append(SideEffect(
                type: .saveDraft,
                description: "Save email draft to OperatorKit only",
                requiresPermission: nil,
                isEnabled: false,
                isAcknowledged: true
            ))
            
        case .reminder:
            let payload = ReminderPayload(
                title: draft.title,
                notes: draft.content.body,
                dueDate: nil,
                priority: nil
            )
            
            // Always show preview first (default enabled)
            effects.append(SideEffect(
                type: .previewReminder,
                description: "Preview reminder: \"\(draft.title)\"",
                requiresPermission: nil,
                isEnabled: true,
                isAcknowledged: false,
                reminderPayload: payload
            ))
            
            // Option to actually create reminder (disabled by default)
            if includeReminderWrite {
                effects.append(SideEffect(
                    type: .createReminder,
                    description: "Create reminder in Reminders app (requires confirmation)",
                    requiresPermission: .reminders,
                    isEnabled: false,
                    isAcknowledged: false,
                    reminderPayload: payload
                ))
            }
            
        case .summary, .actionItems, .documentReview:
            // These only save to memory
            effects.append(SideEffect(
                type: .saveToMemory,
                description: "Save to OperatorKit memory",
                requiresPermission: nil,
                isEnabled: true,
                isAcknowledged: true
            ))
            
            // Phase 3C: Option to create follow-up calendar event
            if includeCalendarWrite, let payload = calendarEventPayload {
                effects.append(SideEffect(
                    type: .previewCalendarEvent,
                    description: "Preview calendar event: \"\(payload.title)\"",
                    requiresPermission: nil,
                    isEnabled: false,
                    isAcknowledged: true,
                    calendarEventPayload: payload
                ))
            }
        }
        
        return effects
    }
    
    /// Build side effects from an execution plan
    static func build(from plan: ExecutionPlan) -> [SideEffect] {
        var effects: [SideEffect] = []
        
        // Derive side effects from plan steps
        for step in plan.steps {
            if let permission = step.requiresPermission {
                let effect = mapStepToSideEffect(step: step, permission: permission)
                if !effects.contains(where: { $0.type == effect.type }) {
                    effects.append(effect)
                }
            }
        }
        
        // Always include memory save
        if !effects.contains(where: { $0.type == .saveToMemory }) {
            effects.append(SideEffect(
                type: .saveToMemory,
                description: "Save result to OperatorKit memory",
                isEnabled: true,
                isAcknowledged: true
            ))
        }
        
        return effects
    }
    
    private static func mapStepToSideEffect(step: PlanStep, permission: PlanStep.PermissionType) -> SideEffect {
        switch permission {
        case .email:
            return SideEffect(
                type: .presentEmailDraft,
                description: "Open email composer for '\(step.title)' (you send manually)",
                requiresPermission: .mail
            )
        case .calendar:
            // Default to preview - user can enable write
            let payload = CalendarEventPayload(
                title: "Follow-up: \(step.title)",
                startDate: Date().addingTimeInterval(86400), // Tomorrow
                endDate: Date().addingTimeInterval(86400 + 3600), // Tomorrow + 1 hour
                notes: step.description
            )
            return SideEffect(
                type: .previewCalendarEvent,
                description: "Preview calendar event for '\(step.title)'",
                requiresPermission: nil,
                calendarEventPayload: payload
            )
        case .reminders:
            let payload = ReminderPayload(
                title: "Reminder from: \(step.title)",
                notes: step.description
            )
            return SideEffect(
                type: .previewReminder,
                description: "Preview reminder for '\(step.title)'",
                requiresPermission: nil,
                reminderPayload: payload
            )
        case .files, .contacts:
            return SideEffect(
                type: .saveToMemory,
                description: "Save result of '\(step.title)'"
            )
        }
    }
    
    /// Upgrade a preview reminder to a create reminder
    /// INVARIANT: User must explicitly request this upgrade
    static func upgradeToReminderWrite(_ previewEffect: SideEffect) -> SideEffect {
        guard previewEffect.type == .previewReminder,
              let payload = previewEffect.reminderPayload else {
            #if DEBUG
            assertionFailure("INVARIANT VIOLATION: Can only upgrade previewReminder to createReminder")
            #endif
            return previewEffect
        }
        
        return SideEffect(
            type: .createReminder,
            description: "Create reminder in Reminders app: \"\(payload.title)\"",
            requiresPermission: .reminders,
            isEnabled: true,
            isAcknowledged: false,
            reminderPayload: payload
        )
    }
    
    /// Upgrade a preview calendar event to a create calendar event
    /// INVARIANT: User must explicitly request this upgrade
    static func upgradeToCalendarCreate(_ previewEffect: SideEffect) -> SideEffect {
        guard previewEffect.type == .previewCalendarEvent,
              let payload = previewEffect.calendarEventPayload else {
            #if DEBUG
            assertionFailure("INVARIANT VIOLATION: Can only upgrade previewCalendarEvent to createCalendarEvent")
            #endif
            return previewEffect
        }
        
        #if DEBUG
        // INVARIANT: Cannot create if this was meant to be an update
        assert(payload.originalEventIdentifier == nil, "INVARIANT VIOLATION: Use upgradeToCalendarUpdate for events with originalEventIdentifier")
        #endif
        
        return SideEffect(
            type: .createCalendarEvent,
            description: "Create calendar event: \"\(payload.title)\"",
            requiresPermission: .calendar,
            isEnabled: true,
            isAcknowledged: false,
            calendarEventPayload: payload
        )
    }
    
    /// Upgrade a preview calendar event to an update calendar event
    /// INVARIANT: originalEventIdentifier must be from user-selected context
    static func upgradeToCalendarUpdate(_ previewEffect: SideEffect, diff: CalendarEventDiff?) -> SideEffect {
        guard previewEffect.type == .previewCalendarEvent,
              let payload = previewEffect.calendarEventPayload else {
            #if DEBUG
            assertionFailure("INVARIANT VIOLATION: Can only upgrade previewCalendarEvent to updateCalendarEvent")
            #endif
            return previewEffect
        }
        
        #if DEBUG
        // INVARIANT: Must have originalEventIdentifier from user-selected context
        assert(payload.originalEventIdentifier != nil, "INVARIANT VIOLATION: Update requires originalEventIdentifier from user-selected context")
        #endif
        
        return SideEffect(
            type: .updateCalendarEvent,
            description: "Update calendar event: \"\(payload.title)\"",
            requiresPermission: .calendar,
            isEnabled: true,
            isAcknowledged: false,
            calendarEventPayload: payload,
            calendarEventDiff: diff
        )
    }
    
    /// Create a calendar event side effect from context
    /// INVARIANT: For updates, eventIdentifier must come from user-selected context
    static func createCalendarEventEffect(
        from contextItem: CalendarContextItem,
        updatedPayload: CalendarEventPayload
    ) -> SideEffect {
        #if DEBUG
        assert(updatedPayload.originalEventIdentifier == contextItem.eventIdentifier,
               "INVARIANT VIOLATION: originalEventIdentifier must match context item")
        #endif
        
        return SideEffect(
            type: .previewCalendarEvent,
            description: "Preview changes to: \"\(updatedPayload.title)\"",
            requiresPermission: nil,
            calendarEventPayload: updatedPayload
        )
    }
}

// MARK: - Executed Side Effect

/// Records what happened when a side effect was executed
struct ExecutedSideEffect: Identifiable {
    let id: UUID
    let sideEffect: SideEffect
    let wasExecuted: Bool
    let resultMessage: String?
    let timestamp: Date
    
    // MARK: - Reminder-specific results
    let reminderIdentifier: String?
    let reminderWriteConfirmedAt: Date?
    
    // MARK: - Calendar-specific results (Phase 3C)
    let calendarEventIdentifier: String?
    let calendarWriteConfirmedAt: Date?
    let calendarOperation: CalendarOperation?
    
    enum CalendarOperation: String, Codable {
        case created = "created"
        case updated = "updated"
    }
    
    init(
        id: UUID = UUID(),
        sideEffect: SideEffect,
        wasExecuted: Bool,
        resultMessage: String?,
        timestamp: Date = Date(),
        reminderIdentifier: String? = nil,
        reminderWriteConfirmedAt: Date? = nil,
        calendarEventIdentifier: String? = nil,
        calendarWriteConfirmedAt: Date? = nil,
        calendarOperation: CalendarOperation? = nil
    ) {
        self.id = id
        self.sideEffect = sideEffect
        self.wasExecuted = wasExecuted
        self.resultMessage = resultMessage
        self.timestamp = timestamp
        self.reminderIdentifier = reminderIdentifier
        self.reminderWriteConfirmedAt = reminderWriteConfirmedAt
        self.calendarEventIdentifier = calendarEventIdentifier
        self.calendarWriteConfirmedAt = calendarWriteConfirmedAt
        self.calendarOperation = calendarOperation
    }
}
