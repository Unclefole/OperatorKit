import SwiftUI
import UIKit

/// Two-key confirmation view for write operations
/// INVARIANT: This view MUST be shown before any real write (reminder, calendar, etc.)
/// INVARIANT: User must explicitly tap "Confirm Create" to proceed
/// INVARIANT: Cancel returns to ApprovalView without any write
struct ConfirmWriteView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    /// The side effect requiring confirmation
    let sideEffect: SideEffect
    
    /// Callback when user confirms the write
    let onConfirm: () -> Void
    
    /// Callback when user cancels
    let onCancel: () -> Void
    
    @State private var confirmationTimestamp: Date? = nil
    @State private var isConfirming: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Warning Header
                    warningHeader
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Safety Callout Block
                            safetyCalloutBlock
                            
                            // Write operation details
                            writeDetailsCard
                            
                            // Reminder payload (if applicable)
                            if let payload = sideEffect.reminderPayload {
                                reminderDetailsCard(payload)
                            }
                            
                            // Permission status
                            permissionStatusCard
                            
                            // Invariant reminder
                            invariantCard
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                    }
                    
                    // Bottom Actions
                    bottomActions
                }
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Warning Header
    
    private var warningHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    onCancel()
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(UIColor.systemGray5))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Confirm Write")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Placeholder for symmetry
                Color.clear
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Warning banner
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Final Review")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Confirm these details are correct. Nothing is created until you tap Confirm.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Safety Callout Block
    
    private var safetyCalloutBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                
                Text("You are about to make a change")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text("This action will create or modify data outside OperatorKit.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("You will be asked to confirm before anything is written.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Specific note for reminders
            HStack(spacing: 6) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Text("One reminder will be created. No bulk actions.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Write Details Card
    
    private var writeDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: sideEffect.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                Text("Action Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(label: "Type", value: sideEffect.type.displayName)
                DetailRow(label: "Description", value: sideEffect.description)
                
                if let permission = sideEffect.requiresPermission {
                    DetailRow(label: "Permission", value: permission.rawValue)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Reminder Details Card
    
    private func reminderDetailsCard(_ payload: ReminderPayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                Text("Reminder Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(payload.title)
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                // Notes
                if let notes = payload.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                
                // Due Date
                if let dueDate = payload.dueDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Due Date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(dueDate.formatted(date: .long, time: .shortened))
                            .font(.body)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Due Date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("No due date set")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Priority
                if let priority = payload.priority, priority != .none {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Priority")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            ForEach(0..<priorityLevel(priority), id: \.self) { _ in
                                Image(systemName: "exclamationmark")
                                    .font(.caption)
                                    .foregroundColor(priorityColor(priority))
                            }
                            Text(priority.displayName)
                                .font(.body)
                        }
                    }
                }
                
                // Target List
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target List")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let listId = payload.listIdentifier {
                        Text("Custom list: \(listId)")
                            .font(.body)
                    } else {
                        Text("Default Reminders list")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Permission Status Card
    
    private var permissionStatusCard: some View {
        let permissionGranted = checkPermission()
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: permissionGranted ? "checkmark.shield.fill" : "xmark.shield.fill")
                    .font(.system(size: 20))
                    .foregroundColor(permissionGranted ? .green : .red)
                Text("Permission Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if permissionGranted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Reminders access granted")
                        .font(.subheadline)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Reminders access required")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: openSettings) {
                        HStack(spacing: 4) {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Invariant Card
    
    private var invariantCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                Text("What OperatorKit Guarantees")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                InvariantRow(text: "Nothing happens in the background")
                InvariantRow(text: "Only this one reminder will be created")
                InvariantRow(text: "A record is saved for your reference")
                InvariantRow(text: "You can edit or delete it in Reminders anytime")
            }
        }
        .padding(16)
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Bottom Actions
    
    private var bottomActions: some View {
        let canConfirm = checkPermission()
        
        return VStack(spacing: 12) {
            // Cancel Button
            Button(action: {
                onCancel()
                dismiss()
            }) {
                Text("Cancel")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            
            // Confirm Button
            Button(action: confirmWrite) {
                HStack(spacing: 8) {
                    if isConfirming {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isConfirming ? "Creating..." : "Confirm Create")
                }
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canConfirm ? Color.red : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!canConfirm || isConfirming)
            
            if !canConfirm {
                Text("Open Settings to grant Reminders access, then return here.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            Color(UIColor.systemGroupedBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
    
    // MARK: - Actions
    
    private func confirmWrite() {
        guard checkPermission() else {
            errorMessage = "Reminders permission is required to create reminders."
            showingError = true
            return
        }
        
        isConfirming = true
        confirmationTimestamp = Date()
        
        // Log the confirmation
        log("ConfirmWriteView: User confirmed write at \(Date())")
        
        // Call the confirmation callback
        onConfirm()
        
        // Dismiss after a brief delay for UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isConfirming = false
            dismiss()
        }
    }
    
    private func checkPermission() -> Bool {
        guard sideEffect.requiresPermission == .reminders else { return true }
        return PermissionManager.shared.currentState.remindersGranted
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func priorityLevel(_ priority: ReminderPayload.Priority) -> Int {
        switch priority {
        case .none: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
    
    private func priorityColor(_ priority: ReminderPayload.Priority) -> Color {
        switch priority {
        case .none: return .gray
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - Supporting Views

private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
    }
}

private struct InvariantRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ConfirmWriteView_Previews: PreviewProvider {
    static var previews: some View {
        ConfirmWriteView(
            sideEffect: SideEffect(
                type: .createReminder,
                description: "Create reminder in Reminders app",
                requiresPermission: .reminders,
                reminderPayload: ReminderPayload(
                    title: "Follow up on meeting",
                    notes: "Send action items to the team",
                    dueDate: Date().addingTimeInterval(86400),
                    priority: .high
                )
            ),
            onConfirm: { },
            onCancel: { }
        )
        .environmentObject(AppState())
    }
}
#endif
