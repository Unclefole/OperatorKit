import SwiftUI
import UIKit

/// Two-key confirmation view for calendar write operations
/// INVARIANT: This view MUST be shown before any calendar write (create/update)
/// INVARIANT: User must explicitly tap "Confirm Create" or "Confirm Update" to proceed
/// INVARIANT: Cancel returns to ApprovalView without any write
/// INVARIANT: For updates, originalEventIdentifier must be from user-selected context
struct ConfirmCalendarWriteView: View {
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
    
    private var payload: CalendarEventPayload? {
        sideEffect.calendarEventPayload
    }
    
    private var isUpdate: Bool {
        sideEffect.type == .updateCalendarEvent
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                OKColor.backgroundPrimary
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
                            
                            // Calendar event payload
                            if let payload = payload {
                                eventDetailsCard(payload)
                            }
                            
                            // Diff view for updates
                            if isUpdate, let diff = sideEffect.calendarEventDiff {
                                diffCard(diff)
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
                        .foregroundColor(OKColor.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color(UIColor.systemGray5))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text(isUpdate ? "Confirm Update" : "Confirm Create")
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
                    .foregroundColor(OKColor.actionPrimary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Final Review")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(isUpdate
                         ? "Confirm these changes are correct. The event won't be modified until you tap Confirm."
                         : "Confirm these details are correct. The event won't be created until you tap Confirm.")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(OKColor.actionPrimary.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
        .background(OKColor.backgroundPrimary)
    }
    
    // MARK: - Safety Callout Block
    
    private var safetyCalloutBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 18))
                    .foregroundColor(OKColor.actionPrimary)
                
                Text("You are about to make a change")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text("This action will create or modify data outside OperatorKit.")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
            
            Text("You will be asked to confirm before anything is written.")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
            
            // Specific note for calendar
            if isUpdate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12))
                        .foregroundColor(OKColor.textMuted)
                    Text("Only events you explicitly selected can be modified.")
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                }
                .padding(.top, 4)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 12))
                        .foregroundColor(OKColor.textMuted)
                    Text("One calendar event will be created.")
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(OKColor.actionPrimary.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(OKColor.actionPrimary.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Write Details Card
    
    private var writeDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: sideEffect.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.actionPrimary)
                Text(isUpdate ? "Event Update" : "New Event")
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
        .background(OKColor.backgroundPrimary)
        .cornerRadius(12)
        .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Event Details Card
    
    private func eventDetailsCard(_ payload: CalendarEventPayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.actionPrimary)
                Text("Event Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                    Text(payload.title)
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                // Time Range
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(OKColor.actionPrimary)
                        Text(payload.formattedTimeRange)
                            .font(.body)
                    }
                }
                
                // Duration
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                    Text("\(payload.durationMinutes) minutes")
                        .font(.body)
                }
                
                // Timezone
                if let tz = payload.timeZoneIdentifier {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Timezone")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                        Text(tz)
                            .font(.body)
                    }
                }
                
                // Location
                if let location = payload.location, !location.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption)
                                .foregroundColor(OKColor.riskCritical)
                            Text(location)
                                .font(.body)
                        }
                    }
                }
                
                // Notes
                if let notes = payload.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                        Text(notes)
                            .font(.body)
                            .foregroundColor(OKColor.textSecondary)
                            .lineLimit(3)
                    }
                }
                
                // Attendees
                if !payload.attendeesEmails.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Attendees")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(payload.attendeesEmails, id: \.self) { email in
                                HStack(spacing: 8) {
                                    Image(systemName: "person.circle")
                                        .font(.caption)
                                        .foregroundColor(OKColor.actionPrimary)
                                    Text(email)
                                        .font(.body)
                                }
                            }
                        }
                    }
                }
                
                // Alarms
                if !payload.alarmOffsetsMinutes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reminders")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(payload.alarmOffsetsMinutes, id: \.self) { offset in
                                HStack(spacing: 8) {
                                    Image(systemName: "bell")
                                        .font(.caption)
                                        .foregroundColor(OKColor.riskWarning)
                                    Text(formatAlarmOffset(offset))
                                        .font(.body)
                                }
                            }
                        }
                    }
                }
                
                // Target Calendar
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Calendar")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                    if let calId = payload.calendarIdentifier {
                        Text("Custom calendar: \(calId)")
                            .font(.body)
                    } else {
                        Text("Default Calendar")
                            .font(.body)
                            .foregroundColor(OKColor.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(12)
        .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Diff Card (For Updates)
    
    private func diffCard(_ diff: CalendarEventDiff) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.riskWarning)
                Text("Changes")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if !diff.hasChanges {
                Text("No changes detected")
                    .font(.subheadline)
                    .foregroundColor(OKColor.textSecondary)
            } else {
                VStack(spacing: 12) {
                    if let titleChange = diff.titleChanged {
                        DiffRow(field: "Title", oldValue: titleChange.old, newValue: titleChange.new)
                    }
                    
                    if let startChange = diff.startDateChanged {
                        DiffRow(field: "Start", oldValue: formatDate(startChange.old), newValue: formatDate(startChange.new))
                    }
                    
                    if let endChange = diff.endDateChanged {
                        DiffRow(field: "End", oldValue: formatDate(endChange.old), newValue: formatDate(endChange.new))
                    }
                    
                    if let locationChange = diff.locationChanged {
                        DiffRow(field: "Location", oldValue: locationChange.old ?? "None", newValue: locationChange.new ?? "None")
                    }
                    
                    if let notesChange = diff.notesChanged {
                        DiffRow(field: "Notes", oldValue: notesChange.old ?? "None", newValue: notesChange.new ?? "None")
                    }
                    
                    if let attendeesChange = diff.attendeesChanged {
                        if !attendeesChange.added.isEmpty {
                            HStack(alignment: .top) {
                                Text("Added:")
                                    .font(.caption)
                                    .foregroundColor(OKColor.textMuted)
                                    .frame(width: 60, alignment: .leading)
                                VStack(alignment: .leading) {
                                    ForEach(attendeesChange.added, id: \.self) { email in
                                        Text("+ \(email)")
                                            .font(.caption)
                                            .foregroundColor(OKColor.riskNominal)
                                    }
                                }
                                Spacer()
                            }
                        }
                        if !attendeesChange.removed.isEmpty {
                            HStack(alignment: .top) {
                                Text("Removed:")
                                    .font(.caption)
                                    .foregroundColor(OKColor.textMuted)
                                    .frame(width: 60, alignment: .leading)
                                VStack(alignment: .leading) {
                                    ForEach(attendeesChange.removed, id: \.self) { email in
                                        Text("- \(email)")
                                            .font(.caption)
                                            .foregroundColor(OKColor.riskCritical)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(OKColor.riskWarning.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Permission Status Card
    
    private var permissionStatusCard: some View {
        let permissionGranted = checkPermission()
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: permissionGranted ? "checkmark.shield.fill" : "xmark.shield.fill")
                    .font(.system(size: 20))
                    .foregroundColor(permissionGranted ? OKColor.riskNominal : OKColor.riskCritical)
                Text("Permission Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if permissionGranted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(OKColor.riskNominal)
                    Text("Calendar access granted")
                        .font(.subheadline)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(OKColor.riskCritical)
                        Text("Calendar access required")
                            .font(.subheadline)
                            .foregroundColor(OKColor.riskCritical)
                    }
                    
                    Button(action: openSettings) {
                        HStack(spacing: 4) {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(OKColor.actionPrimary)
                    }
                }
            }
        }
        .padding(16)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(12)
        .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Invariant Card
    
    private var invariantCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 16))
                    .foregroundColor(OKColor.riskNominal)
                Text("What OperatorKit Guarantees")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                InvariantRow(text: "Nothing happens in the background")
                InvariantRow(text: "Only this one event will be \(isUpdate ? "updated" : "created")")
                InvariantRow(text: "A record is saved for your reference")
                InvariantRow(text: "You can edit or delete it in Calendar anytime")
                if isUpdate {
                    InvariantRow(text: "Only events you selected can be modified")
                }
            }
        }
        .padding(16)
        .background(OKColor.riskNominal.opacity(0.05))
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
                    .foregroundColor(OKColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(OKColor.backgroundPrimary)
                    .cornerRadius(12)
                    .shadow(color: OKColor.shadow.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            
            // Confirm Button
            Button(action: confirmWrite) {
                HStack(spacing: 8) {
                    if isConfirming {
                        ProgressView()
                            .tint(OKColor.iconOnColor)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isConfirming ? (isUpdate ? "Updating..." : "Creating...") : (isUpdate ? "Confirm Update" : "Confirm Create"))
                }
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(OKColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canConfirm ? (isUpdate ? OKColor.riskWarning : OKColor.actionPrimary) : OKColor.textMuted)
                .cornerRadius(12)
            }
            .disabled(!canConfirm || isConfirming)
            
            if !canConfirm {
                Text("Open Settings to grant Calendar access, then return here.")
                    .font(.caption)
                    .foregroundColor(OKColor.riskWarning)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            OKColor.backgroundPrimary
                .shadow(color: OKColor.shadow.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
    
    // MARK: - Actions
    
    private func confirmWrite() {
        guard checkPermission() else {
            errorMessage = "Calendar permission is required to \(isUpdate ? "update" : "create") events."
            showingError = true
            return
        }
        
        // INVARIANT: For updates, must have originalEventIdentifier
        #if DEBUG
        if isUpdate {
            assert(payload?.originalEventIdentifier != nil, "INVARIANT VIOLATION: Update requires originalEventIdentifier from user-selected context")
        }
        #endif
        
        isConfirming = true
        confirmationTimestamp = Date()
        
        // Log the confirmation
        log("ConfirmCalendarWriteView: User confirmed \(isUpdate ? "update" : "create") at \(Date())")
        
        // Call the confirmation callback
        onConfirm()
        
        // Dismiss after a brief delay for UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isConfirming = false
            dismiss()
        }
    }
    
    private func checkPermission() -> Bool {
        guard sideEffect.requiresPermission == .calendar else { return true }
        return PermissionManager.shared.isCalendarAuthorized
    }
    
    private func openSettings() {
        PermissionManager.shared.openSettings()
    }
    
    private func formatAlarmOffset(_ minutes: Int) -> String {
        let absMinutes = abs(minutes)
        if absMinutes < 60 {
            return "\(absMinutes) minute\(absMinutes == 1 ? "" : "s") before"
        } else if absMinutes < 1440 {
            let hours = absMinutes / 60
            return "\(hours) hour\(hours == 1 ? "" : "s") before"
        } else {
            let days = absMinutes / 1440
            return "\(days) day\(days == 1 ? "" : "s") before"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
                .foregroundColor(OKColor.textSecondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
    }
}

private struct DiffRow: View {
    let field: String
    let oldValue: String
    let newValue: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(field)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(OKColor.textSecondary)
            
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading) {
                    Text("Before:")
                        .font(.caption2)
                        .foregroundColor(OKColor.textMuted)
                    Text(oldValue)
                        .font(.caption)
                        .foregroundColor(OKColor.riskCritical)
                        .strikethrough()
                }
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(OKColor.riskWarning)
                
                VStack(alignment: .leading) {
                    Text("After:")
                        .font(.caption2)
                        .foregroundColor(OKColor.textMuted)
                    Text(newValue)
                        .font(.caption)
                        .foregroundColor(OKColor.riskNominal)
                }
                
                Spacer()
            }
        }
        .padding(8)
        .background(OKColor.textMuted.opacity(0.05))
        .cornerRadius(6)
    }
}

private struct InvariantRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(OKColor.riskNominal)
            Text(text)
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ConfirmCalendarWriteView_Previews: PreviewProvider {
    static var previews: some View {
        ConfirmCalendarWriteView(
            sideEffect: SideEffect(
                type: .createCalendarEvent,
                description: "Create calendar event",
                requiresPermission: .calendar,
                calendarEventPayload: CalendarEventPayload(
                    title: "Team Meeting",
                    startDate: Date().addingTimeInterval(86400),
                    endDate: Date().addingTimeInterval(86400 + 3600),
                    location: "Conference Room A",
                    notes: "Discuss Q1 objectives",
                    attendeesEmails: ["alice@example.com", "bob@example.com"],
                    alarmOffsetsMinutes: [-15, -60]
                )
            ),
            onConfirm: { },
            onCancel: { }
        )
        .environmentObject(AppState())
    }
}
#endif
