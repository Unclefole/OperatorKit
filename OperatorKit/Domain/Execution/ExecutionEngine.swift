import Foundation
import MessageUI

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                      OPERATORKIT EXECUTION SEAL                          ║
// ╠═══════════════════════════════════════════════════════════════════════════╣
// ║  This system is a GOVERNED EXECUTION RUNTIME.                            ║
// ║                                                                           ║
// ║  IMMUTABLE INVARIANTS:                                                    ║
// ║  ━━━━━━━━━━━━━━━━━━━━                                                    ║
// ║  1. NO side effects without explicit foreground human approval           ║
// ║  2. NO background execution - all execution is @MainActor                ║
// ║  3. NO silent automation - Siri only prepares drafts                     ║
// ║  4. ALL actions are auditable via AuditTrail                             ║
// ║  5. Permissions are revalidated at EXECUTION TIME, not cached            ║
// ║  6. Confidence gates prevent low-quality proactive learning (>= 0.65)    ║
// ║  7. NO concurrent executions - atomicity enforced                        ║
// ║  8. Write operations require TWO-KEY confirmation                        ║
// ║                                                                           ║
// ║  GLOBAL INVARIANT:                                                        ║
// ║  "No AI-generated side effect may execute without explicit               ║
// ║   foreground human approval."                                             ║
// ║                                                                           ║
// ║  If modifying this engine, preserve ALL invariants or FAIL THE BUILD.    ║
// ║                                                                           ║
// ║  See: docs/SAFETY_CONTRACT.md                                             ║
// ║  Changes to execution logic require Safety Contract Change Approval       ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

/// DUMB ACTUATOR — Executes side effects ONLY with a valid KernelAuthorizationToken.
///
/// ╔═══════════════════════════════════════════════════════════════════════════╗
/// ║  CONTROL-PLANE REFACTOR: AUTHORITY INVERSION                            ║
/// ╠═══════════════════════════════════════════════════════════════════════════╣
/// ║  ExecutionEngine does NOT decide policy.                                ║
/// ║  ExecutionEngine does NOT validate approval.                            ║
/// ║  ExecutionEngine does NOT assess risk.                                  ║
/// ║                                                                         ║
/// ║  ExecutionEngine REQUIRES a KernelAuthorizationToken.                   ║
/// ║  If token is missing or invalid → HARD FAIL.                           ║
/// ║  ZERO fallback paths.                                                   ║
/// ║                                                                         ║
/// ║  Policy authority: CapabilityKernel (sole)                              ║
/// ║  Approval authority: CapabilityKernel (sole)                            ║
/// ║  Audit authority: EvidenceEngine (sole)                                 ║
/// ╚═══════════════════════════════════════════════════════════════════════════╝
@MainActor
final class ExecutionEngine: ObservableObject {
    
    static let shared = ExecutionEngine()
    
    // MARK: - Dependencies
    
    private let mailService = MailComposerService.shared
    private let reminderService = ReminderService.shared
    private let calendarService = CalendarService.shared
    
    // MARK: - Published State
    
    @Published private(set) var isExecuting: Bool = false
    @Published private(set) var pendingMailComposer: Draft?
    @Published var showingMailComposer: Bool = false
    
    private init() {}
    
    // MARK: - Execution (Token-Gated)

    /// Execute side effects with a valid KernelAuthorizationToken.
    ///
    /// INVARIANT: Token MUST be valid or execution HARD FAILs.
    /// INVARIANT: No concurrent executions allowed.
    /// INVARIANT: Write operations require two-key confirmation.
    /// INVARIANT: All evidence logged through EvidenceEngine.
    func execute(
        draft: Draft,
        sideEffects: [SideEffect],
        token: KernelAuthorizationToken,
        intent: IntentRequest? = nil,
        context: ContextPacket? = nil,
        approvalTimestamp: Date = Date()
    ) async -> ExecutionResultModel {
        log("[EXECUTION_START] Draft: \(draft.title)")
        let executionStartTime = Date()
        log("ExecutionEngine.execute() called - Draft: \(draft.title), Type: \(draft.type.rawValue)")
        log("  → Token planId: \(token.planId.uuidString)")
        log("  → Token riskTier: \(token.riskTier.rawValue)")
        log("  → Token valid: \(token.isValid)")
        log("  → Side effects count: \(sideEffects.count)")
        log("  → Enabled side effects: \(sideEffects.filter { $0.isEnabled }.map { $0.type.rawValue }.joined(separator: ", "))")

        // ═══════════════════════════════════════════════════════════════════════
        // HARD GATE 1: Token must not be expired and must have a signature.
        // ═══════════════════════════════════════════════════════════════════════
        guard token.isValid else {
            logError("HARD FAIL: Token expired or empty signature. Execution denied.")
            return ExecutionResultModel(
                draft: draft,
                executedSideEffects: [],
                status: .failed,
                message: "Kernel authorization required — token invalid or expired",
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

        // ═══════════════════════════════════════════════════════════════════════
        // HARD GATE 2: Cryptographic signature verification.
        // Recomputes HMAC and compares. Forged signatures FAIL here.
        // ═══════════════════════════════════════════════════════════════════════
        guard token.verifySignature() else {
            logError("HARD FAIL: Token signature verification failed. Possible forgery. Execution denied.")
            return ExecutionResultModel(
                draft: draft,
                executedSideEffects: [],
                status: .failed,
                message: "Kernel authorization failed — signature verification failed",
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

        // ═══════════════════════════════════════════════════════════════════════
        // HARD GATE 3: One-use enforcement. Replay attacks FAIL here.
        // A token can only be consumed ONCE. Second use is rejected.
        // ═══════════════════════════════════════════════════════════════════════
        guard CapabilityKernel.consumeToken(token) else {
            logError("HARD FAIL: Token already consumed (replay attempt). Execution denied.")
            return ExecutionResultModel(
                draft: draft,
                executedSideEffects: [],
                status: .failed,
                message: "Kernel authorization failed — token already used",
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

        // SECURITY: Prevent concurrent execution
        guard !isExecuting else {
            logError("SECURITY: Concurrent execution blocked - already executing")
            return ExecutionResultModel(
                draft: draft,
                executedSideEffects: [],
                status: .failed,
                message: "Execution already in progress",
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
            let executed = await executeSideEffect(effect, draft: draft)
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
                log("ExecutionEngine: pendingMailComposer SET - email composer will auto-present")
                log("  → canPresentMailComposer will be: \(mailService.canSendMail && pendingMailComposer != nil)")
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
        
        let executionDuration = Date().timeIntervalSince(executionStartTime)
        log("[EXECUTION_COMPLETE] Status: \(status.rawValue) - \(message) (Duration: \(String(format: "%.2f", executionDuration))s)")

        // DONATION: Only donate successful, high-confidence workflows
        // INVARIANT: Never donate drafts, failures, or low-confidence results
        if status == .success, let intentType = intent?.intentType {
            IntentDonationManager.shared.donateCompletedWorkflow(
                intentType: intentType,
                requestText: intent?.rawText ?? "",
                confidence: draft.confidence
            )
        }

        return ExecutionResultModel(
            draft: draft,
            executedSideEffects: executedEffects,
            status: status,
            message: message,
            auditTrail: auditTrail
        )
    }
    
    // REMOVED: Convenience overload without token.
    // There is ZERO fallback path. Every call MUST provide a KernelAuthorizationToken.
    
    // MARK: - Side Effect Execution

    private func executeSideEffect(_ effect: SideEffect, draft: Draft) async -> ExecutedSideEffect {
        log("[EXECUTION_STEP] Executing side effect: \(effect.type.rawValue)")
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
            // SECURITY: Check LIVE mail availability at execution time, not cached value
            let liveCanSendMail = MFMailComposeViewController.canSendMail()

            log("ExecutionEngine: Handling presentEmailDraft side effect")
            log("  → LIVE canSendMail check: \(liveCanSendMail)")
            log("  → Draft recipient: \(draft.content.recipient ?? "none")")

            if liveCanSendMail {
                resultMessage = "Email composer ready - user must manually send"
                wasExecuted = true
                log("  → ✅ Email composer will be presented")
            } else {
                resultMessage = "Mail not configured on this device"
                wasExecuted = false
                logWarning("  → ❌ Mail not configured - cannot present composer")
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
            
            // Direct async reminder save (no semaphore deadlock)
            let confirmationTime = effect.secondConfirmationTimestamp ?? Date()
            reminderWriteConfirmedAt = confirmationTime

            let saveResult = await reminderService.saveReminder(
                payload: payload,
                secondConfirmationTimestamp: confirmationTime
            )

            switch saveResult {
            case .success(let identifier, _, let confirmedAt):
                reminderIdentifier = identifier
                reminderWriteConfirmedAt = confirmedAt
                resultMessage = "Reminder created successfully"
                wasExecuted = true
                log("[EXECUTION_STEP] Reminder created: \(identifier)")
            case .blocked(let reason):
                resultMessage = reason
                wasExecuted = false
                log("[EXECUTION_STEP] Reminder blocked: \(reason)")
            case .failed(let reason):
                resultMessage = "Failed: \(reason)"
                wasExecuted = false
                logError("[EXECUTION_STEP] Reminder failed: \(reason)")
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
            
            // Direct async calendar save (no semaphore deadlock)
            let confirmationTime = effect.secondConfirmationTimestamp ?? Date()
            calendarWriteConfirmedAt = confirmationTime

            let writeResult = await calendarService.createEvent(
                payload: payload,
                secondConfirmationTimestamp: confirmationTime
            )

            switch writeResult {
            case .success(let identifier, let operation, _, let confirmedAt):
                calendarEventIdentifier = identifier
                calendarWriteConfirmedAt = confirmedAt
                calendarOperation = operation == .created ? .created : .updated
                resultMessage = "Calendar event created successfully"
                wasExecuted = true
                log("[EXECUTION_STEP] Calendar event created: \(identifier)")
            case .blocked(let reason):
                resultMessage = reason
                wasExecuted = false
                log("[EXECUTION_STEP] Calendar create blocked: \(reason)")
            case .failed(let reason):
                resultMessage = "Failed: \(reason)"
                wasExecuted = false
                logError("[EXECUTION_STEP] Calendar create failed: \(reason)")
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
            
            // Direct async calendar update (no semaphore deadlock)
            let confirmationTime = effect.secondConfirmationTimestamp ?? Date()
            calendarWriteConfirmedAt = confirmationTime

            let writeResult = await calendarService.updateEvent(
                payload: payload,
                secondConfirmationTimestamp: confirmationTime
            )

            switch writeResult {
            case .success(let identifier, let operation, _, let confirmedAt):
                calendarEventIdentifier = identifier
                calendarWriteConfirmedAt = confirmedAt
                calendarOperation = operation == .updated ? .updated : .created
                resultMessage = "Calendar event updated successfully"
                wasExecuted = true
                log("[EXECUTION_STEP] Calendar event updated: \(identifier)")
            case .blocked(let reason):
                resultMessage = reason
                wasExecuted = false
                log("[EXECUTION_STEP] Calendar update blocked: \(reason)")
            case .failed(let reason):
                resultMessage = "Failed: \(reason)"
                wasExecuted = false
                logError("[EXECUTION_STEP] Calendar update failed: \(reason)")
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
