import Foundation

/// Result of an execution with full audit trail
/// INVARIANT: Every execution must be auditable
struct ExecutionResultModel: Identifiable, Equatable {
    let id: UUID
    
    // MARK: - Core Result
    let draft: Draft
    let executedSideEffects: [ExecutedSideEffect]
    let status: ExecutionStatus
    let message: String
    let timestamp: Date
    
    // MARK: - Audit Trail
    let auditTrail: AuditTrail
    
    enum ExecutionStatus: String, Codable {
        case success = "success"
        case partialSuccess = "partial_success"
        case failed = "failed"
        case savedDraftOnly = "saved_draft_only"
    }
    
    init(
        id: UUID = UUID(),
        draft: Draft,
        executedSideEffects: [ExecutedSideEffect],
        status: ExecutionStatus,
        message: String,
        timestamp: Date = Date(),
        auditTrail: AuditTrail
    ) {
        self.id = id
        self.draft = draft
        self.executedSideEffects = executedSideEffects
        self.status = status
        self.message = message
        self.timestamp = timestamp
        self.auditTrail = auditTrail
    }
    
    /// Convenience initializer without explicit audit trail (creates minimal trail)
    @MainActor
    init(
        id: UUID = UUID(),
        draft: Draft,
        executedSideEffects: [ExecutedSideEffect],
        status: ExecutionStatus,
        message: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.draft = draft
        self.executedSideEffects = executedSideEffects
        self.status = status
        self.message = message
        self.timestamp = timestamp
        self.auditTrail = AuditTrail(
            executionTimestamp: timestamp,
            approvalTimestamp: timestamp,
            intentSummary: nil,
            contextSummary: nil,
            sideEffectsAtApproval: [],
            permissionStateAtApproval: PermissionManager.shared.currentState,
            modelMetadata: draft.modelMetadata,
            confidenceSnapshot: ConfidenceSnapshot(
                confidence: draft.confidence,
                threshold: DraftOutput.directProceedConfidence,
                minimumThreshold: DraftOutput.minimumExecutionConfidence,
                modelId: draft.modelMetadata?.modelId ?? "unknown",
                citationsCount: draft.citations.count,
                wasLowConfidenceConfirmed: true
            ),
            reminderWriteInfo: nil,
            calendarWriteInfo: nil,
            validationPass: true,
            timeoutOccurred: false,
            citationValidityPass: true,
            promptScaffoldHash: nil
        )
    }
    
    var isSuccess: Bool {
        status == .success || status == .savedDraftOnly
    }
    
    /// Check if a reminder was created during execution
    var didCreateReminder: Bool {
        auditTrail.reminderWriteInfo?.wasCreated ?? false
    }
    
    /// Get the reminder identifier if one was created
    var createdReminderIdentifier: String? {
        auditTrail.reminderWriteInfo?.reminderIdentifier
    }
    
    /// Check if a calendar event was created/updated during execution (Phase 3C)
    var didWriteCalendarEvent: Bool {
        auditTrail.calendarWriteInfo?.wasWritten ?? false
    }
    
    /// Get the calendar event identifier if one was created/updated
    var calendarEventIdentifier: String? {
        auditTrail.calendarWriteInfo?.eventIdentifier
    }
    
    /// Get the calendar operation type
    var calendarOperation: CalendarWriteInfo.CalendarOperation? {
        auditTrail.calendarWriteInfo?.operation
    }
    
    static func == (lhs: ExecutionResultModel, rhs: ExecutionResultModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Audit Trail

/// Complete audit trail for an execution
/// Records everything needed to understand what was approved and executed
/// INVARIANT: All executions must have complete audit trail
struct AuditTrail: Equatable {
    // MARK: - Timestamps
    let executionTimestamp: Date
    let approvalTimestamp: Date
    
    // MARK: - Context at Approval Time
    let intentSummary: String?
    let contextSummary: String?
    
    // MARK: - Side Effects at Approval Time
    let sideEffectsAtApproval: [SideEffectSnapshot]
    
    // MARK: - Permission State at Approval Time
    let permissionStateAtApproval: PermissionState
    
    // MARK: - Model Metadata (Phase 2C)
    let modelMetadata: ModelMetadata?
    
    // MARK: - Confidence Snapshot (Phase 2C)
    let confidenceSnapshot: ConfidenceSnapshot?
    
    // MARK: - Reminder Write Info (Phase 3B)
    let reminderWriteInfo: ReminderWriteInfo?
    
    // MARK: - Calendar Write Info (Phase 3C)
    let calendarWriteInfo: CalendarWriteInfo?
    
    // MARK: - Quality Hardening (Phase 4C)
    let validationPass: Bool
    let timeoutOccurred: Bool
    let citationValidityPass: Bool
    let promptScaffoldHash: String?
    
    // MARK: - Computed Properties
    
    var modelBackendUsed: String {
        modelMetadata?.displayName ?? "Unknown"
    }
    
    var confidenceAtDraft: Double {
        confidenceSnapshot?.confidence ?? 0.0
    }
    
    var citationsCount: Int {
        confidenceSnapshot?.citationsCount ?? 0
    }
    
    // MARK: - Builder
    
    static func build(
        intent: IntentRequest?,
        context: ContextPacket?,
        draft: Draft?,
        sideEffects: [SideEffect],
        permissionState: PermissionState,
        approvalTimestamp: Date,
        modelMetadata: ModelMetadata? = nil,
        confidenceSnapshot: ConfidenceSnapshot? = nil,
        reminderWriteInfo: ReminderWriteInfo? = nil,
        calendarWriteInfo: CalendarWriteInfo? = nil,
        validationPass: Bool = true,
        timeoutOccurred: Bool = false,
        citationValidityPass: Bool = true,
        promptScaffoldHash: String? = nil
    ) -> AuditTrail {
        // Build confidence snapshot from draft if not provided
        var snapshot = confidenceSnapshot
        if snapshot == nil, let draft = draft {
            snapshot = ConfidenceSnapshot(
                confidence: draft.confidence,
                threshold: DraftOutput.directProceedConfidence,
                minimumThreshold: DraftOutput.minimumExecutionConfidence,
                modelId: draft.modelMetadata?.modelId ?? "unknown",
                citationsCount: draft.citations.count,
                wasLowConfidenceConfirmed: true
            )
        }
        
        return AuditTrail(
            executionTimestamp: Date(),
            approvalTimestamp: approvalTimestamp,
            intentSummary: intent?.rawText,
            contextSummary: buildContextSummary(context),
            sideEffectsAtApproval: sideEffects.map { SideEffectSnapshot(from: $0) },
            permissionStateAtApproval: permissionState,
            modelMetadata: draft?.modelMetadata ?? modelMetadata,
            confidenceSnapshot: snapshot,
            reminderWriteInfo: reminderWriteInfo,
            calendarWriteInfo: calendarWriteInfo,
            validationPass: validationPass,
            timeoutOccurred: timeoutOccurred,
            citationValidityPass: citationValidityPass,
            promptScaffoldHash: promptScaffoldHash
        )
    }
    
    /// Build from draft (Phase 2C - includes model info)
    static func buildFromDraft(
        draft: Draft,
        intent: IntentRequest?,
        context: ContextPacket?,
        sideEffects: [SideEffect],
        permissionState: PermissionState,
        approvalTimestamp: Date,
        wasLowConfidenceConfirmed: Bool = true
    ) -> AuditTrail {
        let snapshot = ConfidenceSnapshot(
            confidence: draft.confidence,
            threshold: DraftOutput.directProceedConfidence,
            minimumThreshold: DraftOutput.minimumExecutionConfidence,
            modelId: draft.modelMetadata?.modelId ?? "unknown",
            citationsCount: draft.citations.count,
            wasLowConfidenceConfirmed: wasLowConfidenceConfirmed
        )
        
        return AuditTrail(
            executionTimestamp: Date(),
            approvalTimestamp: approvalTimestamp,
            intentSummary: intent?.rawText,
            contextSummary: buildContextSummary(context),
            sideEffectsAtApproval: sideEffects.map { SideEffectSnapshot(from: $0) },
            permissionStateAtApproval: permissionState,
            modelMetadata: draft.modelMetadata,
            confidenceSnapshot: snapshot,
            reminderWriteInfo: nil,
            calendarWriteInfo: nil,
            validationPass: true,
            timeoutOccurred: false,
            citationValidityPass: true,
            promptScaffoldHash: nil
        )
    }
    
    /// Create a copy with reminder write info added
    /// INVARIANT: Only called after successful reminder creation
    func withReminderWrite(identifier: String?, confirmedAt: Date?) -> AuditTrail {
        let writeInfo: ReminderWriteInfo?
        if let identifier = identifier {
            writeInfo = ReminderWriteInfo(
                wasCreated: true,
                reminderIdentifier: identifier,
                confirmedAt: confirmedAt ?? Date(),
                payload: extractReminderPayload()
            )
        } else {
            writeInfo = nil
        }
        
        return AuditTrail(
            executionTimestamp: executionTimestamp,
            approvalTimestamp: approvalTimestamp,
            intentSummary: intentSummary,
            contextSummary: contextSummary,
            sideEffectsAtApproval: sideEffectsAtApproval,
            permissionStateAtApproval: permissionStateAtApproval,
            modelMetadata: modelMetadata,
            confidenceSnapshot: confidenceSnapshot,
            reminderWriteInfo: writeInfo,
            calendarWriteInfo: calendarWriteInfo,
            validationPass: validationPass,
            timeoutOccurred: timeoutOccurred,
            citationValidityPass: citationValidityPass,
            promptScaffoldHash: promptScaffoldHash
        )
    }
    
    /// Create a copy with calendar write info added (Phase 3C)
    /// INVARIANT: Only called after successful calendar create/update
    func withCalendarWrite(
        identifier: String?,
        operation: ExecutedSideEffect.CalendarOperation?,
        confirmedAt: Date?
    ) -> AuditTrail {
        let writeInfo: CalendarWriteInfo?
        if let identifier = identifier, let operation = operation {
            writeInfo = CalendarWriteInfo(
                wasWritten: true,
                eventIdentifier: identifier,
                operation: operation == .created ? .created : .updated,
                confirmedAt: confirmedAt ?? Date(),
                payload: extractCalendarPayload(),
                diffSummary: extractCalendarDiffSummary()
            )
        } else {
            writeInfo = nil
        }
        
        return AuditTrail(
            executionTimestamp: executionTimestamp,
            approvalTimestamp: approvalTimestamp,
            intentSummary: intentSummary,
            contextSummary: contextSummary,
            sideEffectsAtApproval: sideEffectsAtApproval,
            permissionStateAtApproval: permissionStateAtApproval,
            modelMetadata: modelMetadata,
            confidenceSnapshot: confidenceSnapshot,
            reminderWriteInfo: reminderWriteInfo,
            calendarWriteInfo: writeInfo,
            validationPass: validationPass,
            timeoutOccurred: timeoutOccurred,
            citationValidityPass: citationValidityPass,
            promptScaffoldHash: promptScaffoldHash
        )
    }
    
    private func extractReminderPayload() -> ReminderPayloadSnapshot? {
        guard let reminderEffect = sideEffectsAtApproval.first(where: { $0.type == SideEffect.SideEffectType.createReminder.rawValue }) else {
            return nil
        }
        
        return ReminderPayloadSnapshot(
            title: reminderEffect.description,
            hasNotes: false,
            hasDueDate: false
        )
    }
    
    private func extractCalendarPayload() -> CalendarPayloadSnapshot? {
        // Find calendar side effect from snapshots
        let calendarEffectTypes = [
            SideEffect.SideEffectType.createCalendarEvent.rawValue,
            SideEffect.SideEffectType.updateCalendarEvent.rawValue
        ]
        guard let calendarEffect = sideEffectsAtApproval.first(where: { calendarEffectTypes.contains($0.type) }) else {
            return nil
        }
        
        return CalendarPayloadSnapshot(
            title: calendarEffect.description,
            hasLocation: false,
            hasAttendees: false,
            hasAlarms: false
        )
    }
    
    private func extractCalendarDiffSummary() -> String? {
        // For updates, extract diff summary if available
        guard let updateEffect = sideEffectsAtApproval.first(where: { $0.type == SideEffect.SideEffectType.updateCalendarEvent.rawValue }) else {
            return nil
        }
        return "Updated: \(updateEffect.description)"
    }
    
    private static func buildContextSummary(_ context: ContextPacket?) -> String? {
        guard let context = context else { return nil }
        
        var parts: [String] = []
        
        if !context.calendarItems.isEmpty {
            let names = context.calendarItems.map { $0.title }.prefix(3).joined(separator: ", ")
            let suffix = context.calendarItems.count > 3 ? " (+\(context.calendarItems.count - 3) more)" : ""
            parts.append("Calendar: \(names)\(suffix)")
        }
        
        if !context.emailItems.isEmpty {
            let subjects = context.emailItems.map { $0.subject }.prefix(3).joined(separator: ", ")
            let suffix = context.emailItems.count > 3 ? " (+\(context.emailItems.count - 3) more)" : ""
            parts.append("Email: \(subjects)\(suffix)")
        }
        
        if !context.fileItems.isEmpty {
            let files = context.fileItems.map { $0.name }.prefix(3).joined(separator: ", ")
            let suffix = context.fileItems.count > 3 ? " (+\(context.fileItems.count - 3) more)" : ""
            parts.append("Files: \(files)\(suffix)")
        }
        
        return parts.isEmpty ? nil : parts.joined(separator: " | ")
    }
    
    // MARK: - Formatted for Display
    
    var formattedApprovalTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: approvalTimestamp)
    }
    
    var formattedExecutionTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: executionTimestamp)
    }
    
    var timeBetweenApprovalAndExecution: TimeInterval {
        executionTimestamp.timeIntervalSince(approvalTimestamp)
    }
    
    var confidencePercentage: Int {
        Int(confidenceAtDraft * 100)
    }
    
    /// Safety notes that were shown with the draft
    var safetyNotesAtDraft: [String] {
        confidenceSnapshot?.safetyNotes ?? []
    }
    
    /// Generation latency in milliseconds
    var generationLatencyMs: Int? {
        confidenceSnapshot?.latencyMs ?? modelMetadata?.latencyMs
    }
    
    /// Formatted latency for display
    var formattedLatency: String? {
        confidenceSnapshot?.formattedLatency
    }
    
    /// Whether a fallback model was used
    var usedFallback: Bool {
        confidenceSnapshot?.fallbackReason != nil
    }
    
    /// Reason for fallback (if any)
    var fallbackReason: String? {
        confidenceSnapshot?.fallbackReason ?? modelMetadata?.fallbackReason
    }
}

// MARK: - Side Effect Snapshot

/// Snapshot of a side effect at approval time
/// Captures the exact state when user approved
struct SideEffectSnapshot: Equatable, Codable {
    let id: UUID
    let type: String
    let description: String
    let requiresPermission: String?
    let wasEnabled: Bool
    let wasAcknowledged: Bool
    let hadSecondConfirmation: Bool
    
    init(from effect: SideEffect) {
        self.id = effect.id
        self.type = effect.type.rawValue
        self.description = effect.description
        self.requiresPermission = effect.requiresPermission?.rawValue
        self.wasEnabled = effect.isEnabled
        self.wasAcknowledged = effect.isAcknowledged
        self.hadSecondConfirmation = effect.secondConfirmationGranted
    }
}

// MARK: - Reminder Write Info (Phase 3B)

/// Information about a reminder write operation
/// INVARIANT: Only populated if reminder was actually created
struct ReminderWriteInfo: Equatable {
    let wasCreated: Bool
    let reminderIdentifier: String?
    let confirmedAt: Date
    let payload: ReminderPayloadSnapshot?
    
    var formattedConfirmationTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: confirmedAt)
    }
}

/// Snapshot of reminder payload at write time
struct ReminderPayloadSnapshot: Equatable, Codable {
    let title: String
    let hasNotes: Bool
    let hasDueDate: Bool
}

// MARK: - Calendar Write Info (Phase 3C)

/// Information about a calendar write operation
/// INVARIANT: Only populated if calendar event was actually created/updated
struct CalendarWriteInfo: Equatable {
    let wasWritten: Bool
    let eventIdentifier: String?
    let operation: CalendarOperation
    let confirmedAt: Date
    let payload: CalendarPayloadSnapshot?
    let diffSummary: String? // For updates
    
    enum CalendarOperation: String, Codable {
        case created = "created"
        case updated = "updated"
    }
    
    var formattedConfirmationTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: confirmedAt)
    }
    
    var operationDisplayName: String {
        switch operation {
        case .created: return "Created"
        case .updated: return "Updated"
        }
    }
}

/// Snapshot of calendar payload at write time
struct CalendarPayloadSnapshot: Equatable, Codable {
    let title: String
    let hasLocation: Bool
    let hasAttendees: Bool
    let hasAlarms: Bool
}
