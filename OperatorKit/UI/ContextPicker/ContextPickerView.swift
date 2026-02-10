import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContextPickerView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState
    @StateObject private var contextAssembler = ContextAssembler.shared
    @StateObject private var calendarService = CalendarService.shared  // Read-only access only (CalendarReadAccess)

    // User selections (using String IDs for calendar events from EventKit)
    @State private var selectedCalendarEventIds: Set<String> = []
    @State private var selectedEmailIds: Set<UUID> = []
    @State private var selectedFileIds: Set<UUID> = []

    // UI State
    @State private var showingCalendarPermissionAlert: Bool = false
    @State private var isRequestingCalendarAccess: Bool = false
    
    private var totalSelectedCount: Int {
        selectedCalendarEventIds.count + selectedEmailIds.count + selectedFileIds.count
    }
    
    var body: some View {
        ZStack {
            // Background
            OKColor.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Flow Step Header (Phase 5C)
                FlowStepHeaderView(
                    step: .context,
                    subtitle: "Select the information to include"
                )
                
                // Status Strip (Phase 5C)
                FlowStatusStripView(onRecoveryAction: handleRecoveryAction)
                
                // Header
                headerView
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Intent Summary
                        if let intent = appState.selectedIntent {
                            intentSummaryCard(intent)
                        }
                        
                        // Context Sections
                        contextSections
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
                
                Spacer()
            }
            
            // Bottom Section
            VStack {
                Spacer()
                bottomSection
            }
            
            // Loading Overlay
            if contextAssembler.isLoading {
                loadingOverlay
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadAvailableContext()
        }
        .alert("Calendar Access Required", isPresented: $showingCalendarPermissionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Grant Access") {
                requestCalendarAccess()
            }
        } message: {
            Text("OperatorKit needs calendar access to show your events. You can select which events to include.")
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { nav.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(OKColor.actionPrimary)
            }

            Spacer()

            OperatorKitLogoView(size: .small, showText: false)

            Spacer()

            Button(action: { nav.goHome() }) {
                Image(systemName: "house")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(OKColor.textMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(OKColor.backgroundPrimary)
    }
    
    // MARK: - Intent Summary Card
    private func intentSummaryCard(_ intent: IntentRequest) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundColor(OKColor.actionPrimary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Request")
                    .font(.caption)
                    .foregroundColor(OKColor.textMuted)
                
                Text(intent.rawText)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(OKColor.actionPrimary.opacity(0.08))
        .cornerRadius(12)
    }
    
    // MARK: - Context Sections
    private var contextSections: some View {
        VStack(spacing: 20) {
            // Calendar Section
            calendarSection
            
            // Email Section (mock data)
            ContextSection(
                title: "Email",
                icon: "envelope.fill",
                iconColor: OKColor.actionPrimary
            ) {
                ForEach(contextAssembler.availableEmails) { item in
                    ContextItemRow(
                        icon: "envelope.fill",
                        iconColor: OKColor.actionPrimary,
                        title: item.subject,
                        subtitle: "From: \(item.sender)",
                        isSelected: selectedEmailIds.contains(item.id),
                        onTap: {
                            toggleSelection(id: item.id, in: &selectedEmailIds)
                        }
                    )
                }
            }
            
            // Files Section (mock data)
            ContextSection(
                title: "Files",
                icon: "doc.fill",
                iconColor: OKColor.riskWarning
            ) {
                ForEach(contextAssembler.availableFiles) { item in
                    ContextItemRow(
                        icon: fileIcon(for: item.fileType),
                        iconColor: OKColor.riskWarning,
                        title: item.name,
                        subtitle: item.fileType.uppercased(),
                        isSelected: selectedFileIds.contains(item.id),
                        onTap: {
                            toggleSelection(id: item.id, in: &selectedFileIds)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Calendar Section
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(OKColor.riskCritical)
                
                Text("Calendar")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Authorization status
                if calendarService.isAuthorized {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Connected")
                            .font(.caption)
                    }
                    .foregroundColor(OKColor.riskNominal)
                } else {
                    Button(action: {
                        showingCalendarPermissionAlert = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                            Text("Grant Access")
                                .font(.caption)
                        }
                        .foregroundColor(OKColor.actionPrimary)
                    }
                }
            }
            
            if calendarService.isAuthorized {
                // Show real calendar events
                VStack(spacing: 0) {
                    if contextAssembler.availableCalendarEvents.isEmpty {
                        HStack {
                            Text("No events found in the last 7 days")
                                .font(.subheadline)
                                .foregroundColor(OKColor.textMuted)
                            Spacer()
                        }
                        .padding(16)
                    } else {
                        ForEach(contextAssembler.availableCalendarEvents) { event in
                            CalendarEventRow(
                                event: event,
                                isSelected: selectedCalendarEventIds.contains(event.id),
                                onTap: {
                                    if selectedCalendarEventIds.contains(event.id) {
                                        selectedCalendarEventIds.remove(event.id)
                                    } else {
                                        selectedCalendarEventIds.insert(event.id)
                                    }
                                }
                            )
                        }
                    }
                }
                .background(OKColor.backgroundPrimary)
                .cornerRadius(12)
                .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
            } else {
                // Show permission request card
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundColor(OKColor.textMuted)
                    
                    Text("Calendar access not granted")
                        .font(.subheadline)
                        .foregroundColor(OKColor.textMuted)
                    
                    Text("Grant access to select calendar events as context")
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        showingCalendarPermissionAlert = true
                    }) {
                        Text("Grant Calendar Access")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(OKColor.textPrimary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(OKColor.actionPrimary)
                            .cornerRadius(8)
                    }
                    .disabled(isRequestingCalendarAccess)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(OKColor.backgroundPrimary)
                .cornerRadius(12)
                .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        }
    }
    
    // MARK: - Bottom Section
    private var bottomSection: some View {
        VStack(spacing: 12) {
            // Selected Context Chips
            if totalSelectedCount > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedCalendarEventIds), id: \.self) { id in
                            if let event = contextAssembler.availableCalendarEvents.first(where: { $0.id == id }) {
                                ContextChip(title: event.title, icon: "calendar", onRemove: {
                                    selectedCalendarEventIds.remove(id)
                                })
                            }
                        }
                        ForEach(Array(selectedEmailIds), id: \.self) { id in
                            if let item = contextAssembler.availableEmails.first(where: { $0.id == id }) {
                                ContextChip(title: item.subject, icon: "envelope.fill", onRemove: {
                                    selectedEmailIds.remove(id)
                                })
                            }
                        }
                        ForEach(Array(selectedFileIds), id: \.self) { id in
                            if let item = contextAssembler.availableFiles.first(where: { $0.id == id }) {
                                ContextChip(title: item.name, icon: "doc.fill", onRemove: {
                                    selectedFileIds.remove(id)
                                })
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Why blocked explanation (Phase 5B)
            if totalSelectedCount == 0 {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text("Select at least one item to continue")
                        .font(.caption)
                }
                .foregroundColor(OKColor.actionPrimary)
                .padding(.horizontal, 20)
            }
            
            // Calendar permission hint (Phase 5B)
            if !calendarService.isAuthorized && contextAssembler.availableCalendarEvents.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 12))
                    Text("Calendar access is off. Allow access above to select events.")
                        .font(.caption)
                }
                .foregroundColor(OKColor.riskWarning)
                .padding(.horizontal, 20)
            }
            
            // Continue Button
            Button(action: {
                assembleContextAndContinue()
            }) {
                Text("Continue with \(totalSelectedCount) item\(totalSelectedCount == 1 ? "" : "s")")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(OKColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(totalSelectedCount == 0 ? OKColor.textMuted.opacity(0.4) : OKColor.actionPrimary)
                    .cornerRadius(12)
            }
            .disabled(totalSelectedCount == 0)
            .padding(.horizontal, 20)
            .accessibilityLabel(totalSelectedCount == 0 ? "Continue button, disabled. Select at least one item" : "Continue with \(totalSelectedCount) selected item\(totalSelectedCount == 1 ? "" : "s")")
            .accessibilityHint(totalSelectedCount > 0 ? "Tap to continue to plan generation" : "")
        }
        .padding(.vertical, 16)
        .background(
            OKColor.textPrimary
                .shadow(color: OKColor.shadow.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            OKColor.shadow.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Loading events...")
                    .font(.subheadline)
                    .foregroundColor(OKColor.textPrimary)
            }
            .padding(32)
            .background(OKColor.backgroundPrimary)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Recovery Action Handler (Phase 5C)
    private func handleRecoveryAction(_ action: OperatorKitUserFacingError.RecoveryAction) {
        switch action {
        case .goHome:
            nav.goHome()
        case .retryCurrentStep:
            appState.clearError()
            loadAvailableContext()
        case .editRequest:
            nav.navigate(to: .intent)
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        default:
            appState.clearError()
        }
    }
    
    // MARK: - Helpers
    
    private func loadAvailableContext() {
        Task {
            await contextAssembler.loadAllAvailableContext()
        }
    }
    
    private func requestCalendarAccess() {
        isRequestingCalendarAccess = true
        Task {
            let granted = await contextAssembler.requestCalendarAccess()
            isRequestingCalendarAccess = false
            if granted {
                await contextAssembler.loadAvailableCalendarEvents()
            }
        }
    }
    
    private func toggleSelection<T: Hashable>(id: T, in set: inout Set<T>) {
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
    }
    
    private func fileIcon(for type: String) -> String {
        switch type.lowercased() {
        case "pdf": return "doc.fill"
        case "docx", "doc": return "doc.text.fill"
        case "txt": return "doc.plaintext.fill"
        default: return "doc.fill"
        }
    }
    
    private func assembleContextAndContinue() {
        guard let intent = appState.selectedIntent else { return }
        
        Task {
            let context = await contextAssembler.assemble(
                selectedCalendarEventIds: selectedCalendarEventIds,
                selectedEmailIds: selectedEmailIds,
                selectedFileIds: selectedFileIds
            )
            
            // INVARIANT: Context must be explicitly selected
            #if DEBUG
            assert(context.wasExplicitlySelected, "Context must be explicitly selected by user")
            #endif
            
            await MainActor.run {
                appState.selectedContext = context
                
                // Generate plan
                let plan = Planner.shared.createPlan(intent: intent, context: context)
                appState.executionPlan = plan
                
                nav.navigate(to: .preview)
            }
        }
    }
}

// MARK: - Calendar Event Row
struct CalendarEventRow: View {
    let event: CalendarEventModel
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Calendar color indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(calendarColor)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(OKColor.textPrimary)
                        .lineLimit(1)
                    
                    Text(event.formattedDateRange)
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                    
                    if !event.participants.isEmpty {
                        Text("\(event.participants.count) participant\(event.participants.count > 1 ? "s" : "")")
                            .font(.caption2)
                            .foregroundColor(OKColor.textMuted.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? OKColor.actionPrimary : OKColor.textMuted.opacity(0.3))
            }
            .padding(16)
        }
    }
    
    private var calendarColor: Color {
        if let hex = event.calendarColor {
            return Color(hex: hex)
        }
        return OKColor.riskCritical
    }
}

// MARK: - Context Section
struct ContextSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                content
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - Context Item Row
struct ContextItemRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(OKColor.textPrimary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? OKColor.actionPrimary : OKColor.textMuted.opacity(0.3))
            }
            .padding(16)
        }
    }
}

// MARK: - Context Chip
struct ContextChip: View {
    let title: String
    let icon: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            
            Text(title)
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(OKColor.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(OKColor.actionPrimary.opacity(0.1))
        .foregroundColor(OKColor.actionPrimary)
        .cornerRadius(20)
    }
}

// MARK: - Color Extension moved to DesignTokens.swift

#Preview {
    ContextPickerView()
        .environmentObject(AppState())
}
