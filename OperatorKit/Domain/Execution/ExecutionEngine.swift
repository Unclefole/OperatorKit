import Foundation

// ============================================================================
// SAFETY CONTRACT REFERENCE
// This file enforces: Guarantee #1 (No Autonomous Actions), #5 (Two-Key Writes)
// See: docs/SAFETY_CONTRACT.md
// Changes to execution logic require Safety Contract Change Approval
// ============================================================================

/// Executes approved drafts
/// Phase 3C: Supports controlled writes (reminders and calendar)
/// INVARIANT: No automatic sending - user must manually confirm
/// INVARIANT: Execution requires approval
/// INVARIANT: Write operations require two-key confirmation
/// INVARIANT: All executions are auditable
@MainActor
final class ExecutionEngine: ObservableObject {
    
    static let shared = ExecutionEngine()
    
    // MARK: - Dependencies
    
    private let mailService = MailComposerService.shared
    private let reminderService = ReminderService.shared
    private let calendarService = CalendarService.shared  // Phase 3C
    
    // MARK: - Published State
    
    @Published private(set) var isExecuting: Bool = false
    @Published private(set) var pendingMailComposer: Draft?
    @Published var showingMailComposer: Bool = false
    
    private init() {}
    
    // MARK: - Execution
    
    /// Executes an approved draft with full audit trail
    /// INVARIANT: Write operations (.createReminder, .createCalendarEvent, .updateCalendarEvent) require secondConfirmationGranted = true
    func execute(
        draft: Draft,
        sideEffects: [SideEffect],
        approvalGranted: Bool,
        intent: IntentRequest? = nil,
        context: ContextPacket? = nil,
        approvalTimestamp: Date = Date()
    ) -> ExecutionResultModel {
        // INVARIANT: Verify approval before any execution
        let validation = ApprovalGate.shared.canExecute(
            draft: draft,
            approvalGranted: approvalGranted,
            sideEffects: sideEffects,
            permissionState: PermissionManager.shared.currentState
        )
        
        guard validation.canProceed else {
            logError("Execution blocked: \(validation.reason ?? "Unknown")")
            
            return ExecutionResultModel(
                draft: draft,
                executedSideEffects: [],
                status: .failed,
                message: "Execution blocked: \(validation.reason ?? "Approval not granted")",
                auditTrail: AuditTrail.build(
                    intent: intent,
                    context: context,
                    draft: draft,
                    sideEffects: sideEffects,
                    permissionState: PermissionManager.shared.currentState,
                    approvalTimestamp: approvalTimestamp
                )
            )
        }
        
        // INVARIANT: Verify two-key confirmation for write operations
        for effect in sideEffects where effect.isEnabled && effect.type.requiresTwoKeyConfirmation {
            guard effect.secondConfirmationGranted else {
                logError("INVARIANT VIOLATION: Write operation without two-key confirmation")
                #if DEBUG
                assertionFailure("INVARIANT VIOLATION: Write operation \(effect.type) requires two-key confirmation")
                #endif
                
                return ExecutionResultModel(
                    draft: draft,
                    executedSideEffects: [],
                    status: .failed,
                    message: "Write operation requires second confirmation",
                    auditTrail: AuditTrail.build(
                        intent: intent,
                        context: context,
                        draft: draft,
                        sideEffects: sideEffects,
                        permissionState: PermissionManager.shared.currentState,
                        approvalTimestamp: approvalTimestamp
                    )
                )
            }
        }
        
        isExecuting = true
        defer { isExecuting = false }
        
        // Build audit trail BEFORE execution
        var auditTrail = AuditTrail.build(
            intent: intent,
            context: context,
            draft: draft,
            sideEffects: sideEffects,
            permissionState: PermissionManager.shared.currentState,
            approvalTimestamp: approvalTimestamp
        )
        
        // Execute side effects
        var executedEffects: [ExecutedSideEffect] = []
        var requiresUserAction: Bool = false
        
        for effect in sideEffects where effect.isEnabled {
            let executed = executeSideEffect(effect, draft: draft)
            executedEffects.append(executed)
            
            // Update audit trail with reminder write info
            if effect.type == .createReminder && executed.wasExecuted {
                auditTrail = auditTrail.withReminderWrite(
                    identifier: executed.reminderIdentifier,
                    confirmedAt: executed.reminderWriteConfirmedAt
                )
            }
            
            // Update audit trail with calendar write info (Phase 3C)
            if (effect.type == .createCalendarEvent || effect.type == .updateCalendarEvent) && executed.wasExecuted {
                auditTrail = auditTrail.withCalendarWrite(
                    identifier: executed.calendarEventIdentifier,
                    operation: executed.calendarOperation,
                    confirmedAt: executed.calendarWriteConfirmedAt
                )
            }
            
            // Check if we need user action (e.g., mail composer)
            if effect.type == .presentEmailDraft && executed.wasExecuted {
                requiresUserAction = true
                pendingMailComposer = draft
            }
        }
        
        // Determine overall status
        let allSucceeded = executedEffects.allSatisfy { $0.wasExecuted }
        let anySucceeded = executedEffects.contains { $0.wasExecuted }
        let hasReminderWrite = executedEffects.contains { $0.sideEffect.type == .createReminder && $0.wasExecuted }
        let hasCalendarWrite = executedEffects.contains { 
            ($0.sideEffect.type == .createCalendarEvent || $0.sideEffect.type == .updateCalendarEvent) && $0.wasExecuted 
        }
        
        let status: ExecutionResultModel.ExecutionStatus
        let message: String
        
        if requiresUserAction {
            status = .success
            message = "Email composer ready - tap to open and send"
        } else if hasReminderWrite {
            status = .success
            message = "Reminder created in Reminders app"
        } else if hasCalendarWrite {
            status = .success
            let isUpdate = executedEffects.contains { $0.sideEffect.type == .updateCalendarEvent && $0.wasExecuted }
            message = isUpdate ? "Calendar event updated" : "Calendar event created"
        } else if executedEffects.isEmpty || (executedEffects.count == 1 && executedEffects.first?.sideEffect.type == .saveDraft) {
            status = .savedDraftOnly
            message = "Draft saved successfully"
        } else if allSucceeded {
            status = .success
            message = generateSuccessMessage(for: draft, effects: executedEffects)
        } else if anySucceeded {
            status = .partialSuccess
            message = "Some actions completed successfully"
        } else {
            status = .failed
            message = "Execution failed"
        }
        
        log("Execution complete: \(status.rawValue) - \(message)")
        
        return ExecutionResultModel(
            draft: draft,
            executedSideEffects: executedEffects,
            status: status,
            message: message,
            auditTrail: auditTrail
        )
    }
    
    /// Simplified execute for backward compatibility
    func execute(
        draft: Draft,
        sideEffects: [SideEffect],
        approvalGranted: Bool
    ) -> ExecutionResultModel {
        execute(
            draft: draft,
            sideEffects: sideEffects,
            approvalGranted: approvalGranted,
            intent: nil,
            context: nil,
            approvalTimestamp: Date()
        )
    }
    
    // MARK: - Side Effect Execution
    
    private func executeSideEffect(_ effect: SideEffect, draft: Draft) -> ExecutedSideEffect {
        var resultMessage: String
        var wasExecuted = true
        var reminderIdentifier: String? = nil
        var reminderWriteConfirmedAt: Date? = nil
        var calendarEventIdentifier: String? = nil
        var calendarWriteConfirmedAt: Date? = nil
        var calendarOperation: ExecutedSideEffect.CalendarOperation? = nil
        
        switch effect.type {
        case .sendEmail:
            // Direct send not supported - use presentEmailDraft instead
            resultMessage = "Direct email sending not supported. Use Open Email Composer instead."
            wasExecuted = false
            
        case .presentEmailDraft:
            // Prepare for mail composer presentation
            // INVARIANT: User must manually tap Send in the composer
            if mailService.canSendMail {
                resultMessage = "Email composer ready - user must manually send"
                wasExecuted = true
            } else {
                resultMessage = "Mail not configured on this device"
                wasExecuted = false
            }
            
        case .saveDraft:
            resultMessage = "Draft saved to memory"
            
        case .createReminder:
            // Phase 3B: Real reminder write with two-key confirmation
            guard effect.secondConfirmationGranted else {
                resultMessage = "Reminder creation requires second confirmation"
                wasExecuted = false
                break
            }
            
            guard let payload = effect.reminderPayload else {
                resultMessage = "No reminder payload provided"
                wasExecuted = false
                break
            }
            
            guard reminderService.isAuthorized else {
                resultMessage = "Reminders permission not granted"
                wasExecuted = false
                break
            }
            
            // Perform synchronous wrapper around async reminder save
            let confirmationTime = effect.secondConfirmationTimestamp ?? Date()
            reminderWriteConfirmedAt = confirmationTime
            
            var saveResult: ReminderSaveResult?
            let semaphore = DispatchSemaphore(value: 0)
            
            Task {
                saveResult = await reminderService.saveReminder(
                    payload: payload,
                    secondConfirmationTimestamp: confirmationTime
                )
                semaphore.signal()
            }
            
            let waitResult = semaphore.wait(timeout: .now() + 5.0)
            
            if waitResult == .timedOut {
                resultMessage = "Reminder creation timed out"
                wasExecuted = false
            } else if let result = saveResult {
                switch result {
                case .success(let identifier, _, let confirmedAt):
                    reminderIdentifier = identifier
                    reminderWriteConfirmedAt = confirmedAt
                    resultMessage = "Reminder created successfully"
                    wasExecuted = true
                case .blocked(let reason):
                    resultMessage = reason
                    wasExecuted = false
                case .failed(let reason):
                    resultMessage = "Failed: \(reason)"
                    wasExecuted = false
                }
            } else {
                resultMessage = "Reminder creation failed"
                wasExecuted = false
            }
            
        case .previewReminder:
            // Preview only - no actual reminder created
            resultMessage = "Reminder preview generated (not saved to Reminders app)"
            
        case .previewCalendarEvent:
            // Phase 3C: Preview only - no actual calendar event created
            resultMessage = "Calendar event preview generated (not saved to Calendar app)"
            
        case .createCalendarEvent:
            // Phase 3C: Real calendar create with two-key confirmation
            guard effect.secondConfirmationGranted else {
                resultMessage = "Calendar event creation requires second confirmation"
                wasExecuted = false
                break
            }
            
            guard let payload = effect.calendarEventPayload else {
                resultMessage = "No calendar event payload provided"
                wasExecuted = false
                break
            }
            
            guard calendarService.canWrite else {
                resultMessage = "Calendar write permission not granted"
                wasExecuted = false
                break
            }
            
            // Perform synchronous wrapper around async calendar save
            let confirmationTime = effect.secondConfirmationTimestamp ?? Date()
            calendarWriteConfirmedAt = confirmationTime
            
            var writeResult: CalendarWriteResult?
            let semaphore = DispatchSemaphore(value: 0)
            
            Task {
                writeResult = await calendarService.createEvent(
                    payload: payload,
                    secondConfirmationTimestamp: confirmationTime
                )
                semaphore.signal()
            }
            
            let waitResult = semaphore.wait(timeout: .now() + 5.0)
            
            if waitResult == .timedOut {
                resultMessage = "Calendar event creation timed out"
                wasExecuted = false
            } else if let result = writeResult {
                switch result {
                case .success(let identifier, let operation, _, let confirmedAt):
                    calendarEventIdentifier = identifier
                    calendarWriteConfirmedAt = confirmedAt
                    calendarOperation = operation == .created ? .created : .updated
                    resultMessage = "Calendar event created successfully"
                    wasExecuted = true
                case .blocked(let reason):
                    resultMessage = reason
                    wasExecuted = false
                case .failed(let reason):
                    resultMessage = "Failed: \(reason)"
                    wasExecuted = false
                }
            } else {
                resultMessage = "Calendar event creation failed"
                wasExecuted = false
            }
            
        case .updateCalendarEvent:
            // Phase 3C: Real calendar update with two-key confirmation
            guard effect.secondConfirmationGranted else {
                resultMessage = "Calendar event update requires second confirmation"
                wasExecuted = false
                break
            }
            
            guard let payload = effect.calendarEventPayload else {
                resultMessage = "No calendar event payload provided"
                wasExecuted = false
                break
            }
            
            // INVARIANT: Must have originalEventIdentifier
            guard payload.originalEventIdentifier != nil else {
                resultMessage = "No original event identifier for update"
                wasExecuted = false
                #if DEBUG
                assertionFailure("INVARIANT VIOLATION: Update requires originalEventIdentifier")
                #endif
                break
            }
            
            guard calendarService.canWrite else {
                resultMessage = "Calendar write permission not granted"
                wasExecuted = false
                break
            }
            
            // Perform synchronous wrapper around async calendar update
            let confirmationTime = effect.secondConfirmationTimestamp ?? Date()
            calendarWriteConfirmedAt = confirmationTime
            
            var writeResult: CalendarWriteResult?
            let semaphore = DispatchSemaphore(value: 0)
            
            Task {
                writeResult = await calendarService.updateEvent(
                    payload: payload,
                    secondConfirmationTimestamp: confirmationTime
                )
                semaphore.signal()
            }
            
            let waitResult = semaphore.wait(timeout: .now() + 5.0)
            
            if waitResult == .timedOut {
                resultMessage = "Calendar event update timed out"
                wasExecuted = false
            } else if let result = writeResult {
                switch result {
                case .success(let identifier, let operation, _, let confirmedAt):
                    calendarEventIdentifier = identifier
                    calendarWriteConfirmedAt = confirmedAt
                    calendarOperation = operation == .updated ? .updated : .created
                    resultMessage = "Calendar event updated successfully"
                    wasExecuted = true
                case .blocked(let reason):
                    resultMessage = reason
                    wasExecuted = false
                case .failed(let reason):
                    resultMessage = "Failed: \(reason)"
                    wasExecuted = false
                }
            } else {
                resultMessage = "Calendar event update failed"
                wasExecuted = false
            }
            
        case .saveToMemory:
            resultMessage = "Saved to OperatorKit memory"
        }
        
        return ExecutedSideEffect(
            sideEffect: effect,
            wasExecuted: wasExecuted,
            resultMessage: resultMessage,
            reminderIdentifier: reminderIdentifier,
            reminderWriteConfirmedAt: reminderWriteConfirmedAt,
            calendarEventIdentifier: calendarEventIdentifier,
            calendarWriteConfirmedAt: calendarWriteConfirmedAt,
            calendarOperation: calendarOperation
        )
    }
    
    // MARK: - Mail Composer
    
    /// Present mail composer for a draft
    /// INVARIANT: User must manually tap Send - app cannot send automatically
    func presentMailComposer(completion: @escaping (MailComposeResult) -> Void) {
        guard let draft = pendingMailComposer else {
            completion(.failed(reason: "No pending email draft"))
            return
        }
        
        mailService.presentComposer(draft: draft) { [weak self] result in
            self?.pendingMailComposer = nil
            completion(result)
        }
    }
    
    /// Check if mail composer can be presented
    var canPresentMailComposer: Bool {
        mailService.canSendMail && pendingMailComposer != nil
    }
    
    // MARK: - Helpers
    
    private func generateSuccessMessage(for draft: Draft, effects: [ExecutedSideEffect]) -> String {
        let hasEmailComposer = effects.contains { $0.sideEffect.type == .presentEmailDraft && $0.wasExecuted }
        let hasReminderWrite = effects.contains { $0.sideEffect.type == .createReminder && $0.wasExecuted }
        let hasCalendarCreate = effects.contains { $0.sideEffect.type == .createCalendarEvent && $0.wasExecuted }
        let hasCalendarUpdate = effects.contains { $0.sideEffect.type == .updateCalendarEvent && $0.wasExecuted }
        
        if hasEmailComposer {
            if let recipient = draft.content.recipient {
                return "Email draft ready for \(recipient). Open composer to send."
            }
            return "Email draft ready. Open composer to send."
        }
        
        if hasReminderWrite {
            return "Reminder created in Reminders app."
        }
        
        if hasCalendarUpdate {
            return "Calendar event updated successfully."
        }
        
        if hasCalendarCreate {
            return "Calendar event created successfully."
        }
        
        switch draft.type {
        case .email:
            return "Email draft saved."
        case .reminder:
            let hasPreview = effects.contains { $0.sideEffect.type == .previewReminder && $0.wasExecuted }
            return hasPreview ? "Reminder preview ready." : "Reminder saved."
        case .summary:
            return "Summary saved to memory."
        case .actionItems:
            return "Action items extracted and saved."
        case .documentReview:
            return "Document review complete."
        }
    }
}
