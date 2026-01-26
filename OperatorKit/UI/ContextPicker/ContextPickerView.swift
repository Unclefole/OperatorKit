import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContextPickerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var contextAssembler = ContextAssembler.shared
    @StateObject private var calendarService = CalendarService.shared
    
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
            Color(UIColor.systemGroupedBackground)
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
            Button(action: {
                appState.navigateBack()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text("Select Context")
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
    
    // MARK: - Intent Summary Card
    private func intentSummaryCard(_ intent: IntentRequest) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Request")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(intent.rawText)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.blue.opacity(0.08))
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
                iconColor: .blue
            ) {
                ForEach(contextAssembler.availableEmails) { item in
                    ContextItemRow(
                        icon: "envelope.fill",
                        iconColor: .blue,
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
                iconColor: .orange
            ) {
                ForEach(contextAssembler.availableFiles) { item in
                    ContextItemRow(
                        icon: fileIcon(for: item.fileType),
                        iconColor: .orange,
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
                    .foregroundColor(.red)
                
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
                    .foregroundColor(.green)
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
                        .foregroundColor(.blue)
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
                                .foregroundColor(.gray)
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
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            } else {
                // Show permission request card
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    
                    Text("Calendar access not granted")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("Grant access to select calendar events as context")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        showingCalendarPermissionAlert = true
                    }) {
                        Text("Grant Calendar Access")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(isRequestingCalendarAccess)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                .foregroundColor(.blue)
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
                .foregroundColor(.orange)
                .padding(.horizontal, 20)
            }
            
            // Continue Button
            Button(action: {
                assembleContextAndContinue()
            }) {
                Text("Continue with \(totalSelectedCount) item\(totalSelectedCount == 1 ? "" : "s")")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(totalSelectedCount == 0 ? Color.gray.opacity(0.4) : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(totalSelectedCount == 0)
            .padding(.horizontal, 20)
            .accessibilityLabel(totalSelectedCount == 0 ? "Continue button, disabled. Select at least one item" : "Continue with \(totalSelectedCount) selected item\(totalSelectedCount == 1 ? "" : "s")")
            .accessibilityHint(totalSelectedCount > 0 ? "Tap to continue to plan generation" : "")
        }
        .padding(.vertical, 16)
        .background(
            Color.white
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Loading events...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Recovery Action Handler (Phase 5C)
    private func handleRecoveryAction(_ action: OperatorKitUserFacingError.RecoveryAction) {
        switch action {
        case .goHome:
            appState.returnHome()
        case .retryCurrentStep:
            appState.clearError()
            loadAvailableContext()
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
                
                appState.navigateTo(.planPreview)
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
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(event.formattedDateRange)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if !event.participants.isEmpty {
                        Text("\(event.participants.count) participant\(event.participants.count > 1 ? "s" : "")")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : .gray.opacity(0.3))
            }
            .padding(16)
        }
    }
    
    private var calendarColor: Color {
        if let hex = event.calendarColor {
            return Color(hex: hex)
        }
        return .red
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
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : .gray.opacity(0.3))
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
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(20)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContextPickerView()
        .environmentObject(AppState())
}
