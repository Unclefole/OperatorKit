import Foundation
import SwiftData

// ============================================================================
// SECURITY INVARIANT — LOCAL-ONLY STORAGE
//
// PersistedMemoryItem intentionally stores user draft content (body, subject,
// recipient) for on-device memory/history features.
//
// GUARANTEES:
// 1. Content NEVER leaves the device (air-gap enforced)
// 2. Content is NEVER included in exports (forbiddenKeys validation)
// 3. Sync module uploads metadata only (content blocked)
// 4. User may delete memory at any time
//
// This does NOT violate "no draft persistence" rules, which apply to
// in-progress drafts, not completed operations.
// ============================================================================

/// Persisted memory item stored in SwiftData
/// This is the durable, on-device storage for all operations
@Model
final class PersistedMemoryItem {
    
    // MARK: - Core Properties
    
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var title: String
    var preview: String
    var createdAt: Date
    
    // MARK: - Audit Trail
    
    var intentSummary: String?
    var contextSummary: String?
    var approvalTimestamp: Date?
    
    // MARK: - Draft Content (Embedded)
    
    var draftTypeRaw: String?
    var draftTitle: String?
    var draftRecipient: String?
    var draftSubject: String?
    var draftBody: String?
    var draftSignature: String?
    var draftConfidence: Double?
    
    // MARK: - Model Metadata (Phase 2C + Phase 4A + Phase 4C)
    
    var modelBackendUsed: String?      // Backend type: "deterministic", "core_ml", "apple_on_device"
    var modelId: String?               // Unique model identifier
    var modelVersion: String?          // Model version string
    var confidenceAtDraft: Double?     // 0.0-1.0
    var citationsCount: Int?           // Number of citations used
    var safetyNotesJSON: Data?         // JSON array of safety notes
    var generationLatencyMs: Int?      // Time to generate draft in milliseconds
    var fallbackReason: String?        // Why fallback was used (if any)
    var usedFallback: Bool = false     // Whether fallback model was used
    
    // Phase 4C additions
    var validationPass: Bool = true    // Whether output passed validation
    var timeoutOccurred: Bool = false  // Whether generation timed out
    var citationValidityPass: Bool = true // Whether citations were valid
    var promptScaffoldHash: String?    // SHA256 hash of prompt scaffold (not content)
    
    // MARK: - Execution Result (Embedded)
    
    var executionStatusRaw: String?
    var executionMessage: String?
    var executionTimestamp: Date?
    
    // MARK: - Side Effects Executed (JSON)
    
    var sideEffectsJSON: Data?
    
    // MARK: - Attachments (JSON array of names)
    
    var attachmentsJSON: Data?
    
    // MARK: - Reminder Write Info (Phase 3B)
    
    var reminderWasCreated: Bool = false
    var reminderIdentifier: String?
    var reminderWriteConfirmedAt: Date?
    var reminderPayloadJSON: Data?
    
    // MARK: - Calendar Write Info (Phase 3C)
    
    var calendarWasWritten: Bool = false
    var calendarEventIdentifier: String?
    var calendarWriteConfirmedAt: Date?
    var calendarOperationRaw: String?   // "created" or "updated"
    var calendarPayloadJSON: Data?
    var calendarDiffSummary: String?
    
    // MARK: - Computed Properties
    
    var type: MemoryItemType {
        get { MemoryItemType(rawValue: typeRaw) ?? .summary }
        set { typeRaw = newValue.rawValue }
    }
    
    var draftType: DraftType? {
        get {
            guard let raw = draftTypeRaw else { return nil }
            return DraftType(rawValue: raw)
        }
        set { draftTypeRaw = newValue?.rawValue }
    }
    
    var executionStatus: ExecutionStatus? {
        get {
            guard let raw = executionStatusRaw else { return nil }
            return ExecutionStatus(rawValue: raw)
        }
        set { executionStatusRaw = newValue?.rawValue }
    }
    
    var attachments: [String] {
        get {
            guard let data = attachmentsJSON else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            attachmentsJSON = try? JSONEncoder().encode(newValue)
        }
    }
    
    var executedSideEffects: [PersistedSideEffect] {
        get {
            guard let data = sideEffectsJSON else { return [] }
            return (try? JSONDecoder().decode([PersistedSideEffect].self, from: data)) ?? []
        }
        set {
            sideEffectsJSON = try? JSONEncoder().encode(newValue)
        }
    }
    
    var safetyNotesAtDraft: [String]? {
        get {
            guard let data = safetyNotesJSON else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            safetyNotesJSON = newValue != nil ? try? JSONEncoder().encode(newValue) : nil
        }
    }
    
    var reminderPayload: ReminderPayload? {
        get {
            guard let data = reminderPayloadJSON else { return nil }
            return try? JSONDecoder().decode(ReminderPayload.self, from: data)
        }
        set {
            reminderPayloadJSON = newValue != nil ? try? JSONEncoder().encode(newValue) : nil
        }
    }
    
    // MARK: - Enums
    
    enum MemoryItemType: String, Codable {
        case draftedEmail = "Drafted Email"
        case sentEmail = "Sent Email"
        case summary = "Summary"
        case actionItems = "Action Items"
        case reminder = "Reminder"
        case createdReminder = "Created Reminder"  // Phase 3B: Actual reminder in Reminders app
        case calendarEvent = "Calendar Event"      // Phase 3C: Preview only
        case createdCalendarEvent = "Created Calendar Event"   // Phase 3C: Actually created
        case updatedCalendarEvent = "Updated Calendar Event"   // Phase 3C: Actually updated
        case documentReview = "Document Review"
    }
    
    enum DraftType: String, Codable {
        case email = "Email Draft"
        case summary = "Summary"
        case actionItems = "Action Items"
        case documentReview = "Document Review"
        case reminder = "Reminder"
    }
    
    enum ExecutionStatus: String, Codable {
        case success = "success"
        case partialSuccess = "partial_success"
        case failed = "failed"
        case savedDraftOnly = "saved_draft_only"
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        type: MemoryItemType,
        title: String,
        preview: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.title = title
        self.preview = preview
        self.createdAt = createdAt
    }
    
    // MARK: - Formatted Date
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var formattedReminderWriteConfirmedAt: String? {
        guard let date = reminderWriteConfirmedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - Factory from Execution Result
    
    /// Create from ExecutionResultModel with full audit trail
    static func from(
        result: ExecutionResultModel,
        intent: IntentRequest?,
        context: ContextPacket?
    ) -> PersistedMemoryItem {
        var itemType: MemoryItemType
        switch result.draft.type {
        case .email:
            itemType = result.status == .success ? .sentEmail : .draftedEmail
        case .summary:
            itemType = .summary
        case .actionItems:
            itemType = .actionItems
        case .reminder:
            // Phase 3B: Check if reminder was actually created
            if result.didCreateReminder {
                itemType = .createdReminder
            } else {
                itemType = .reminder
            }
        case .documentReview:
            itemType = .documentReview
        }
        
        // Phase 3C: Check if calendar event was created/updated
        if result.didWriteCalendarEvent {
            switch result.calendarOperation {
            case .created:
                itemType = .createdCalendarEvent
            case .updated:
                itemType = .updatedCalendarEvent
            case .none:
                break
            }
        }
        
        let item = PersistedMemoryItem(
            type: itemType,
            title: result.draft.title,
            preview: String(result.draft.content.body.prefix(100))
        )
        
        // Audit trail
        item.intentSummary = intent?.rawText
        item.contextSummary = result.auditTrail.contextSummary
        item.approvalTimestamp = result.auditTrail.approvalTimestamp
        item.executionTimestamp = result.auditTrail.executionTimestamp
        
        // Draft content
        item.draftTypeRaw = result.draft.type.rawValue
        item.draftTitle = result.draft.title
        item.draftRecipient = result.draft.content.recipient
        item.draftSubject = result.draft.content.subject
        item.draftBody = result.draft.content.body
        item.draftSignature = result.draft.content.signature
        item.draftConfidence = result.draft.confidence
        
        // Model metadata (Phase 2C)
        item.modelBackendUsed = result.auditTrail.modelBackendUsed
        item.confidenceAtDraft = result.auditTrail.confidenceAtDraft
        item.citationsCount = result.auditTrail.citationsCount
        item.safetyNotesAtDraft = result.draft.safetyNotes
        
        // Execution result
        item.executionStatusRaw = result.status.rawValue
        item.executionMessage = result.message
        
        // Reminder write info (Phase 3B)
        if let writeInfo = result.auditTrail.reminderWriteInfo {
            item.reminderWasCreated = writeInfo.wasCreated
            item.reminderIdentifier = writeInfo.reminderIdentifier
            item.reminderWriteConfirmedAt = writeInfo.confirmedAt
        }
        
        // Extract reminder payload from side effects
        if let reminderEffect = result.executedSideEffects.first(where: { $0.sideEffect.type == .createReminder }) {
            item.reminderPayload = reminderEffect.sideEffect.reminderPayload
        }
        
        // Calendar write info (Phase 3C)
        if let writeInfo = result.auditTrail.calendarWriteInfo {
            item.calendarWasWritten = writeInfo.wasWritten
            item.calendarEventIdentifier = writeInfo.eventIdentifier
            item.calendarWriteConfirmedAt = writeInfo.confirmedAt
            item.calendarOperationRaw = writeInfo.operation.rawValue
            item.calendarDiffSummary = writeInfo.diffSummary
        }
        
        // Extract calendar payload from side effects
        if let calendarEffect = result.executedSideEffects.first(where: { 
            $0.sideEffect.type == .createCalendarEvent || $0.sideEffect.type == .updateCalendarEvent 
        }) {
            item.calendarPayloadJSON = try? JSONEncoder().encode(calendarEffect.sideEffect.calendarEventPayload)
        }
        
        // Side effects
        item.executedSideEffects = result.executedSideEffects.map { executed in
            PersistedSideEffect(
                type: mapSideEffectType(executed.sideEffect.type),
                description: executed.sideEffect.description,
                wasExecuted: executed.wasExecuted,
                resultMessage: executed.resultMessage,
                reminderIdentifier: executed.reminderIdentifier,
                reminderWriteConfirmedAt: executed.reminderWriteConfirmedAt,
                calendarEventIdentifier: executed.calendarEventIdentifier,
                calendarWriteConfirmedAt: executed.calendarWriteConfirmedAt,
                calendarOperationRaw: executed.calendarOperation?.rawValue
            )
        }
        
        return item
    }
    
    private static func mapSideEffectType(_ type: SideEffect.SideEffectType) -> PersistedSideEffect.SideEffectType {
        switch type {
        case .sendEmail, .presentEmailDraft:
            return .sendEmail
        case .saveDraft:
            return .saveDraft
        case .createReminder:
            return .createReminder
        case .previewReminder:
            return .previewReminder
        case .previewCalendarEvent:
            return .previewCalendarEvent
        case .createCalendarEvent:
            return .createCalendarEvent
        case .updateCalendarEvent:
            return .updateCalendarEvent
        case .saveToMemory:
            return .saveToMemory
        }
    }
}

// MARK: - Persisted Side Effect

struct PersistedSideEffect: Codable, Identifiable {
    let id: UUID
    let typeRaw: String
    let description: String
    let wasExecuted: Bool
    let resultMessage: String?
    
    // Phase 3B: Reminder write details
    let reminderIdentifier: String?
    let reminderWriteConfirmedAt: Date?
    
    // Phase 3C: Calendar write details
    let calendarEventIdentifier: String?
    let calendarWriteConfirmedAt: Date?
    let calendarOperationRaw: String?
    
    var type: SideEffectType {
        SideEffectType(rawValue: typeRaw) ?? .saveToMemory
    }
    
    var calendarOperation: CalendarWriteInfo.CalendarOperation? {
        guard let raw = calendarOperationRaw else { return nil }
        return CalendarWriteInfo.CalendarOperation(rawValue: raw)
    }
    
    enum SideEffectType: String, Codable {
        case sendEmail = "send_email"
        case saveDraft = "save_draft"
        case createReminder = "create_reminder"
        case previewReminder = "preview_reminder"
        case previewCalendarEvent = "preview_calendar_event"
        case createCalendarEvent = "create_calendar_event"
        case updateCalendarEvent = "update_calendar_event"
        case saveToMemory = "save_to_memory"
    }
    
    init(
        id: UUID = UUID(),
        type: SideEffectType,
        description: String,
        wasExecuted: Bool,
        resultMessage: String?,
        reminderIdentifier: String? = nil,
        reminderWriteConfirmedAt: Date? = nil,
        calendarEventIdentifier: String? = nil,
        calendarWriteConfirmedAt: Date? = nil,
        calendarOperationRaw: String? = nil
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.description = description
        self.wasExecuted = wasExecuted
        self.resultMessage = resultMessage
        self.reminderIdentifier = reminderIdentifier
        self.reminderWriteConfirmedAt = reminderWriteConfirmedAt
        self.calendarEventIdentifier = calendarEventIdentifier
        self.calendarWriteConfirmedAt = calendarWriteConfirmedAt
        self.calendarOperationRaw = calendarOperationRaw
    }
}
