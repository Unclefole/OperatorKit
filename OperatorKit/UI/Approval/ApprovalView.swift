import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ApprovalView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var sideEffects: [SideEffect] = []
    @State private var allAcknowledged: Bool = false
    @State private var permissionCheck: PermissionCheckResult?
    
    // MARK: - Two-Key Confirmation State
    @State private var showingConfirmWrite: Bool = false
    @State private var showingConfirmCalendarWrite: Bool = false  // Phase 3C
    @State private var pendingWriteEffectIndex: Int? = nil
    @State private var approvalTimestamp: Date? = nil
    @State private var isExecuting: Bool = false  // Phase 5B: Double-tap prevention
    
    private var canExecute: Bool {
        allAcknowledged && (permissionCheck?.canProceed ?? true) && !isExecuting
    }
    
    /// Why the button is disabled (Phase 5B)
    private var disabledReason: String? {
        if isExecuting {
            return nil // Shows loading state
        }
        if !allAcknowledged {
            let unackCount = sideEffects.filter { $0.isEnabled && !$0.isAcknowledged }.count
            if unackCount > 0 {
                return "Acknowledge \(unackCount) side effect\(unackCount == 1 ? "" : "s") to continue"
            }
            return "Review and acknowledge all enabled actions"
        }
        if let check = permissionCheck, !check.canProceed {
            let missing = check.missingPermissions.first?.rawValue ?? "required"
            return "\(missing) access is currently off"
        }
        return nil
    }
    
    /// Accessibility label for approve button (Phase 5C)
    private var approveButtonAccessibilityLabel: String {
        if isExecuting {
            return "Processing execution"
        }
        if !canExecute {
            return "Approve button, disabled. \(disabledReason ?? "")"
        }
        if requiresTwoKeyConfirmation {
            return "Continue to confirmation"
        }
        return "Approve and execute"
    }
    
    /// Check if any enabled side effects require two-key confirmation
    private var requiresTwoKeyConfirmation: Bool {
        sideEffects.contains { $0.needsTwoKeyConfirmation }
    }
    
    /// Get the side effect that needs two-key confirmation
    private var pendingTwoKeyEffect: SideEffect? {
        sideEffects.first { $0.needsTwoKeyConfirmation }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Flow Step Header (Phase 5C)
                FlowStepHeaderView(
                    step: .approval,
                    subtitle: "Review and approve execution"
                )
                
                // Status Strip (Phase 5C)
                FlowStatusStripView(onRecoveryAction: handleRecoveryAction)
                
                // Header
                headerView
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Context Summary Chips (Phase 5C)
                        ContextSummaryChipsView()
                        
                        // Warning Banner
                        warningBanner
                        
                        // Permission Warning (if needed)
                        if let check = permissionCheck, !check.canProceed {
                            permissionWarningCard(check)
                        }
                        
                        // Draft Preview
                        if let draft = appState.currentDraft {
                            draftPreviewCard(draft)
                        }
                        
                        // Side Effects
                        sideEffectsSection
                        
                        // Reminder Write Option
                        if appState.currentDraft?.type == .reminder {
                            reminderWriteOptionCard
                        }
                        
                        // Calendar Write Option (Phase 3C)
                        if hasCalendarPreview {
                            calendarWriteOptionCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 160)
                }
                
                Spacer()
            }
            
            // Bottom Actions
            VStack {
                Spacer()
                bottomActions
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadSideEffects()
        }
        .sheet(isPresented: $showingConfirmWrite) {
            if let index = pendingWriteEffectIndex {
                ConfirmWriteView(
                    sideEffect: sideEffects[index],
                    onConfirm: {
                        // Grant second confirmation
                        sideEffects[index].grantSecondConfirmation()
                        pendingWriteEffectIndex = nil
                        
                        // Now proceed with execution
                        executeAfterTwoKey()
                    },
                    onCancel: {
                        pendingWriteEffectIndex = nil
                        // Reset approval timestamp since we're not proceeding
                        approvalTimestamp = nil
                    }
                )
                .environmentObject(appState)
            }
        }
        // Phase 3C: Calendar write confirmation
        .sheet(isPresented: $showingConfirmCalendarWrite) {
            if let index = pendingWriteEffectIndex {
                ConfirmCalendarWriteView(
                    sideEffect: sideEffects[index],
                    onConfirm: {
                        // Grant second confirmation
                        sideEffects[index].grantSecondConfirmation()
                        pendingWriteEffectIndex = nil
                        
                        // Now proceed with execution
                        executeAfterTwoKey()
                    },
                    onCancel: {
                        pendingWriteEffectIndex = nil
                        // Reset approval timestamp since we're not proceeding
                        approvalTimestamp = nil
                    }
                )
                .environmentObject(appState)
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: {
                appState.navigateBack()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text("Approve Execution")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: {
                appState.returnHome()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Warning Banner
    private var warningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Review Before Continuing")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Nothing happens until you approve. Review each action below.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Permission Warning Card
    private func permissionWarningCard(_ check: PermissionCheckResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                Text("Permissions Needed")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text("OperatorKit needs access to complete these actions. Grant permissions in Settings.")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                ForEach(check.missingPermissions, id: \.self) { permission in
                    HStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        
                        Text(permission.rawValue)
                            .font(.body)
                        
                        Spacer()
                        
                        Text("Not Granted")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            
            Text("You can grant permissions in Settings, then return here to continue.")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Draft Preview Card
    private func draftPreviewCard(_ draft: Draft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Draft Preview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    appState.navigateBack()
                }) {
                    Text("Edit")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            Divider()
            
            // Email metadata (if email)
            if draft.type == .email {
                VStack(spacing: 8) {
                    HStack {
                        Text("To:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(draft.content.recipient ?? "")
                            .font(.subheadline)
                        Spacer()
                    }
                    HStack {
                        Text("Subject:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(draft.content.subject ?? "")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                
                Divider()
            }
            
            // Reminder metadata (if reminder)
            if draft.type == .reminder {
                VStack(spacing: 8) {
                    HStack {
                        Text("Title:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(draft.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                
                Divider()
            }
            
            // Content preview
            Text(draft.content.body)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(6)
            
            if draft.content.body.count > 300 {
                Text("...")
                    .font(.body)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Reminder Write Option Card
    private var reminderWriteOptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                Text("Create Real Reminder?")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text("By default, OperatorKit only shows a preview. Enable below to create a real reminder in your Reminders app.")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Check if createReminder already exists
            let hasCreateReminder = sideEffects.contains { $0.type == .createReminder }
            
            if !hasCreateReminder {
                Button(action: addReminderWriteEffect) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add \"Create Reminder\" option")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Create Reminder option available")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Two-key confirmation notice
            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 12))
                Text("You'll confirm the exact details before anything is created.")
                    .font(.caption)
            }
            .foregroundColor(.blue)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Calendar Write Option Card (Phase 3C)
    
    /// Check if there's a calendar preview effect that could be upgraded
    private var hasCalendarPreview: Bool {
        sideEffects.contains { $0.type == .previewCalendarEvent }
    }
    
    private var calendarWriteOptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                Text("Create Calendar Event?")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text("By default, OperatorKit only shows a preview. Enable below to create a real event in your Calendar app.")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Check if createCalendarEvent already exists
            let hasCreateCalendar = sideEffects.contains { $0.type == .createCalendarEvent || $0.type == .updateCalendarEvent }
            
            if !hasCreateCalendar {
                // Check if this would be an update (has originalEventIdentifier)
                let isUpdate = sideEffects.first(where: { $0.type == .previewCalendarEvent })?.calendarEventPayload?.isUpdate ?? false
                
                Button(action: addCalendarWriteEffect) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text(isUpdate ? "Add \"Update Event\" option" : "Add \"Create Event\" option")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                let isUpdate = sideEffects.contains { $0.type == .updateCalendarEvent }
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(isUpdate ? "Update Event option available" : "Create Event option available")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Two-key confirmation notice
            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 12))
                Text("You'll confirm the exact details before anything is created.")
                    .font(.caption)
            }
            .foregroundColor(.blue)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Side Effects Section
    private var sideEffectsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Text("What Will Happen")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Show count
                Text("\(sideEffects.filter { $0.isEnabled }.count) action\(sideEffects.filter { $0.isEnabled }.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 0) {
                ForEach(Array(sideEffects.enumerated()), id: \.element.id) { index, effect in
                    SideEffectRow(
                        effect: effect,
                        permissionGranted: effect.requiresPermission.map { permissionManager.hasPermission($0) } ?? true,
                        onToggle: {
                            sideEffects[index].toggle()
                            updateState()
                        },
                        onAcknowledge: {
                            sideEffects[index].acknowledge()
                            updateState()
                        }
                    )
                    
                    if index < sideEffects.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
    
    // MARK: - Bottom Actions
    private var bottomActions: some View {
        VStack(spacing: 12) {
            // Why blocked explanation (Phase 5B)
            if let reason = disabledReason {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                    Text(reason)
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            
            // Two-key warning
            if requiresTwoKeyConfirmation && canExecute {
                HStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 14))
                    Text("Write actions require one more confirmation step")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            
            // Approve Button
            Button(action: {
                initiateExecution()
            }) {
                HStack(spacing: 8) {
                    if isExecuting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Processing...")
                            .font(.body)
                            .fontWeight(.semibold)
                    } else {
                        Image(systemName: requiresTwoKeyConfirmation ? "lock.open.fill" : "checkmark.shield.fill")
                            .font(.system(size: 16))
                        Text(requiresTwoKeyConfirmation ? "Continue to Confirm" : "Approve & Execute")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(canExecute ? Color.green : Color.gray.opacity(0.4))
                .cornerRadius(14)
            }
            .accessibilityLabel(approveButtonAccessibilityLabel)
            .accessibilityHint(canExecute ? "Tap to execute the approved actions" : disabledReason ?? "")
            .disabled(!canExecute)
            
            // Cancel Button
            Button(action: {
                appState.returnHome()
            }) {
                Text("Cancel")
                    .font(.body)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            Color.white
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
    
    // MARK: - Recovery Action Handler (Phase 5C)
    private func handleRecoveryAction(_ action: OperatorKitUserFacingError.RecoveryAction) {
        switch action {
        case .goHome:
            appState.returnHome()
        case .retryCurrentStep:
            appState.clearError()
            isExecuting = false
        case .addMoreContext:
            appState.navigateTo(.contextPicker)
        case .editRequest:
            appState.navigateTo(.intentInput)
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        default:
            appState.clearError()
        }
    }
    
    // MARK: - Helpers
    private func loadSideEffects() {
        // Get side effects from execution plan if available, otherwise from draft
        if let plan = appState.executionPlan {
            sideEffects = plan.declaredSideEffects
        } else if let draft = appState.currentDraft {
            // Phase 3B: Include reminder write option for reminder drafts
            sideEffects = SideEffectBuilder.build(for: draft, includeReminderWrite: draft.type == .reminder)
        }
        updateState()
    }
    
    private func updateState() {
        allAcknowledged = sideEffects.filter { $0.isEnabled }.allSatisfy { $0.isAcknowledged }
        permissionCheck = permissionManager.canExecuteSideEffects(sideEffects)
    }
    
    private func addReminderWriteEffect() {
        guard let previewIndex = sideEffects.firstIndex(where: { $0.type == .previewReminder }) else {
            // No preview to upgrade, create new
            if let draft = appState.currentDraft {
                let payload = ReminderPayload(
                    title: draft.title,
                    notes: draft.content.body
                )
                sideEffects.append(SideEffect(
                    type: .createReminder,
                    description: "Create reminder in Reminders app",
                    requiresPermission: .reminders,
                    isEnabled: false,
                    isAcknowledged: false,
                    reminderPayload: payload
                ))
            }
            return
        }
        
        // Upgrade the preview to include a write option
        let upgraded = SideEffectBuilder.upgradeToReminderWrite(sideEffects[previewIndex])
        sideEffects.append(upgraded)
        updateState()
    }
    
    // Phase 3C: Add calendar write effect
    private func addCalendarWriteEffect() {
        guard let previewIndex = sideEffects.firstIndex(where: { $0.type == .previewCalendarEvent }),
              let payload = sideEffects[previewIndex].calendarEventPayload else {
            // No preview to upgrade
            return
        }
        
        // Determine if this is a create or update based on originalEventIdentifier
        // INVARIANT: Update only allowed if originalEventIdentifier is from user-selected context
        if payload.isUpdate {
            #if DEBUG
            assert(payload.originalEventIdentifier != nil, "INVARIANT VIOLATION: Update requires originalEventIdentifier from user-selected context")
            #endif
            
            // Upgrade to update
            let upgraded = SideEffectBuilder.upgradeToCalendarUpdate(
                sideEffects[previewIndex],
                diff: sideEffects[previewIndex].calendarEventDiff
            )
            sideEffects.append(upgraded)
        } else {
            // Upgrade to create
            let upgraded = SideEffectBuilder.upgradeToCalendarCreate(sideEffects[previewIndex])
            sideEffects.append(upgraded)
        }
        
        updateState()
    }
    
    private func initiateExecution() {
        // Prevent double-tap (Phase 5B)
        guard !isExecuting else { return }
        guard let _ = appState.currentDraft else { return }
        
        // Record approval timestamp
        approvalTimestamp = Date()
        
        // Check for two-key confirmation requirement
        if let twoKeyEffect = pendingTwoKeyEffect,
           let index = sideEffects.firstIndex(where: { $0.id == twoKeyEffect.id }) {
            pendingWriteEffectIndex = index
            
            // Phase 3C: Route to appropriate confirmation view based on type
            if twoKeyEffect.type.isCalendarOperation {
                showingConfirmCalendarWrite = true
            } else {
                showingConfirmWrite = true
            }
            return
        }
        
        // Set executing state (Phase 5B)
        isExecuting = true
        appState.setWorking(.awaitingApproval)
        
        // No two-key needed, proceed directly
        executeApproved()
    }
    
    private func executeAfterTwoKey() {
        // Called after ConfirmWriteView confirms
        // INVARIANT: Two-key confirmation must be granted
        #if DEBUG
        if let index = pendingWriteEffectIndex {
            assert(sideEffects[index].secondConfirmationGranted, "INVARIANT VIOLATION: Executing after two-key without confirmation")
        }
        #endif
        
        executeApproved()
    }
    
    private func executeApproved() {
        guard let draft = appState.currentDraft else { return }
        
        // Use stored approval timestamp or current time
        let timestamp = approvalTimestamp ?? Date()
        
        // Grant approval in AppState
        appState.grantApproval()
        
        // INVARIANT CHECK: Full validation
        let validation = ApprovalGate.shared.canExecute(
            draft: draft,
            approvalGranted: appState.approvalGranted,
            sideEffects: sideEffects,
            permissionState: permissionManager.currentState
        )
        
        #if DEBUG
        assert(validation.canProceed, "INVARIANT VIOLATION: \(validation.reason ?? "Unknown")")
        #endif
        
        guard validation.canProceed else {
            logError("Execution blocked: \(validation.reason ?? "Unknown")")
            return
        }
        
        // Execute
        let result = ExecutionEngine.shared.execute(
            draft: draft,
            sideEffects: sideEffects,
            approvalGranted: appState.approvalGranted
        )
        
        // Save to persistent memory with full audit trail
        MemoryStore.shared.addFromExecution(
            result: result,
            intent: appState.selectedIntent,
            context: appState.selectedContext,
            approvalTimestamp: timestamp
        )
        
        // Phase 10A: Record execution for usage tracking
        // IMPORTANT: This happens at UI layer ONLY, not in ExecutionEngine
        if result.status == .success || result.status == .savedDraftOnly || result.status == .partialSuccess {
            appState.recordExecution()
        }
        
        // Update state and navigate
        appState.executionResult = result
        appState.navigateTo(.executionProgress)
    }
}

// MARK: - Side Effect Row
struct SideEffectRow: View {
    let effect: SideEffect
    let permissionGranted: Bool
    let onToggle: () -> Void
    let onAcknowledge: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: effect.type.icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(effect.description)
                        .font(.body)
                        .foregroundColor(effect.isEnabled ? .primary : .gray)
                    
                    // Permission indicator
                    if let permission = effect.requiresPermission {
                        HStack(spacing: 2) {
                            Image(systemName: permissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 10))
                            Text(permission.rawValue)
                                .font(.caption2)
                        }
                        .foregroundColor(permissionGranted ? .green : .red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((permissionGranted ? Color.green : Color.red).opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                
                Text(effect.type.displayName)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Two-key confirmation badge
                if effect.type.requiresTwoKeyConfirmation && effect.isEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 10))
                        Text("You'll confirm details before this happens")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                    .padding(.top, 4)
                }
                
                // User action required badge for draft-only modes
                if effect.type.requiresUserAction && effect.isEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 10))
                        Text(userActionDescription(for: effect.type))
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                    .padding(.top, 4)
                }
                
                // Write operation warning
                if effect.type.isWriteOperation && effect.isEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 10))
                        Text("Creates data on your device")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                    .padding(.top, 4)
                }
                
                // Acknowledgement status
                if effect.isEnabled && !effect.isAcknowledged {
                    Button(action: onAcknowledge) {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.tap")
                                .font(.system(size: 10))
                            Text("Tap to confirm you've reviewed this")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { effect.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture {
            if effect.isEnabled && !effect.isAcknowledged {
                onAcknowledge()
            }
        }
    }
    
    private var iconColor: Color {
        if !effect.isEnabled {
            return .gray
        }
        if effect.type.isWriteOperation {
            return .red
        }
        return .blue
    }
    
    private func userActionDescription(for type: SideEffect.SideEffectType) -> String {
        switch type {
        case .presentEmailDraft:
            return "You send manually in Mail"
        case .previewReminder:
            return "Preview only - not saved to Reminders"
        default:
            return "Requires your action"
        }
    }
}

#Preview {
    ApprovalView()
        .environmentObject(AppState())
}
