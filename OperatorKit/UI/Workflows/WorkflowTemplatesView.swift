import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WorkflowTemplatesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState
    @EnvironmentObject var templateStore: TemplateStoreObservable
    @State private var searchText: String = ""

    /// Unified list of static + custom templates with deterministic sorting
    private var unifiedTemplates: [UnifiedWorkflowItem] {
        UnifiedWorkflowItem.unifiedList(
            staticTemplates: WorkflowTemplate.allTemplates,
            customTemplates: templateStore.templates
        )
    }

    /// Filtered list based on search text
    private var filteredTemplates: [UnifiedWorkflowItem] {
        if searchText.isEmpty {
            return unifiedTemplates
        }
        let query = searchText.lowercased()
        return unifiedTemplates.filter {
            $0.name.lowercased().contains(query) ||
            $0.descriptionText.lowercased().contains(query)
        }
    }

    var body: some View {
        ZStack {
            OKColor.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                searchBar

                ScrollView {
                    VStack(spacing: 16) {
                        // Error banner if load failed
                        if let error = templateStore.lastError {
                            errorBanner(error)
                        }

                        // Loading indicator
                        if templateStore.isLoading {
                            loadingRow
                        }

                        // Templates list
                        ForEach(filteredTemplates) { item in
                            UnifiedTemplateCard(item: item) {
                                handleTemplateSelection(item)
                            }
                        }

                        // Empty state for search
                        if filteredTemplates.isEmpty && !searchText.isEmpty {
                            emptySearchState
                        }

                        // Manage Templates Button
                        manageTemplatesButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            // Load custom templates on appear
            await templateStore.load()
        }
    }

    // MARK: - Template Selection

    private func handleTemplateSelection(_ item: UnifiedWorkflowItem) {
        switch item {
        case .staticTemplate(let template):
            appState.selectedWorkflowTemplate = template
            appState.selectedCustomTemplate = nil
            nav.navigate(to: .templates)
        case .customTemplate(let template):
            appState.selectedCustomTemplate = template
            appState.selectedWorkflowTemplate = nil
            nav.navigate(to: .templates)
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

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(OKColor.textMuted)

            TextField("Search workflows...", text: $searchText)
                .font(.body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(12)
        .shadow(color: OKColor.shadow.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: Error) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(OKColor.riskWarning)

            VStack(alignment: .leading, spacing: 2) {
                Text("Failed to load custom templates")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(OKColor.textPrimary)

                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: {
                Task {
                    await templateStore.load()
                }
            }) {
                Text("Retry")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(OKColor.actionPrimary)
            }
        }
        .padding(16)
        .background(OKColor.riskWarning.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Loading Row

    private var loadingRow: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())

            Text("Loading custom templates...")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)

            Spacer()
        }
        .padding(16)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(12)
        .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Empty Search State

    private var emptySearchState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(OKColor.textMuted.opacity(0.5))

            Text("No workflows found")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)

            Text("Try a different search term")
                .font(.caption)
                .foregroundColor(OKColor.textMuted)
        }
        .padding(32)
    }

    // MARK: - Manage Templates Button

    private var manageTemplatesButton: some View {
        Button(action: {
            nav.navigate(to: .manageTemplates)
        }) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(OKColor.textMuted)

                Text("Manage Templates")
                    .font(.body)
                    .foregroundColor(OKColor.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OKColor.textMuted.opacity(0.4))
            }
            .padding(16)
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - Unified Template Card

struct UnifiedTemplateCard: View {
    let item: UnifiedWorkflowItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(item.iconColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: item.icon)
                        .font(.system(size: 20))
                        .foregroundColor(item.iconColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(OKColor.textPrimary)

                        if item.isCustom {
                            Text("Custom")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.iconColor)
                                .cornerRadius(4)
                        }
                    }

                    Text(item.descriptionText)
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OKColor.textMuted.opacity(0.4))
            }
            .padding(16)
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - Legacy Workflow Template Card (for compatibility)

struct WorkflowTemplateCard: View {
    let template: WorkflowTemplate
    let onTap: () -> Void

    private var iconBackgroundColor: Color {
        switch template.iconColor {
        case .blue: return OKColor.actionPrimary
        case .pink: return OKColor.riskCritical
        case .green: return OKColor.riskNominal
        case .orange: return OKColor.riskWarning
        case .purple: return OKColor.riskExtreme
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBackgroundColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: template.icon)
                        .font(.system(size: 20))
                        .foregroundColor(iconBackgroundColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(OKColor.textPrimary)

                    Text(template.description)
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OKColor.textMuted.opacity(0.4))
            }
            .padding(16)
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - Workflow Detail View

struct WorkflowDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState
    @State private var showingEditSheet: Bool = false
    @State private var editingStep: WorkflowStep?

    var body: some View {
        ZStack {
            OKColor.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(spacing: 20) {
                        if let template = appState.selectedWorkflowTemplate {
                            instructionsSection(template)
                            stepsSection(template)
                            settingsSection(template)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }

                Spacer()
            }

            VStack {
                Spacer()
                runWorkflowButton
            }

            if showingEditSheet, let step = editingStep {
                EditStepSheet(
                    step: step,
                    isPresented: $showingEditSheet,
                    onSave: { _ in
                        showingEditSheet = false
                    }
                )
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: {
                nav.goBack()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(OKColor.actionPrimary)
            }

            Spacer()

            Text(appState.selectedWorkflowTemplate?.name ?? "Workflow")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Instructions Section

    private func instructionsSection(_ template: WorkflowTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.headline)
                .fontWeight(.semibold)

            Text(template.description)
                .font(.body)
                .foregroundColor(OKColor.textMuted)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(OKColor.backgroundPrimary)
                .cornerRadius(12)
                .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Steps Section

    private func stepsSection(_ template: WorkflowTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Steps")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 0) {
                ForEach(Array(template.steps.enumerated()), id: \.element.id) { index, step in
                    WorkflowStepRow(step: step) {
                        editingStep = step
                        showingEditSheet = true
                    }

                    if index < template.steps.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Settings Section

    private func settingsSection(_ template: WorkflowTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 0) {
                HStack {
                    Text("Confidence Required")
                        .font(.body)

                    Spacer()

                    Text(template.settings.confidenceRequired.rawValue)
                        .font(.body)
                        .foregroundColor(OKColor.textMuted)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(OKColor.textMuted.opacity(0.4))
                }
                .padding(16)

                Divider()
                    .padding(.leading, 16)

                HStack {
                    Text("Verify before execution")
                        .font(.body)

                    Spacer()

                    Toggle("", isOn: .constant(template.settings.verifyBeforeExecution))
                        .labelsHidden()
                }
                .padding(16)
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Run Workflow Button

    private var runWorkflowButton: some View {
        Button(action: {
            if let template = appState.selectedWorkflowTemplate {
                let intent = IntentRequest(
                    rawText: "Run \(template.name) workflow",
                    intentType: .draftEmail
                )
                appState.selectedIntent = intent
                nav.navigate(to: .context)
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                Text("Run Workflow")
            }
            .font(.body)
            .fontWeight(.semibold)
            .foregroundColor(OKColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(OKColor.actionPrimary)
            .cornerRadius(14)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            OKColor.backgroundPrimary
                .shadow(color: OKColor.shadow.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
}

// MARK: - Workflow Step Row

struct WorkflowStepRow: View {
    let step: WorkflowStep
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(OKColor.actionPrimary)
                        .frame(width: 28, height: 28)

                    Text("\(step.stepNumber)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(OKColor.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(OKColor.textPrimary)

                    Text(step.instructions)
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                        .lineLimit(2)

                    if let attachment = step.attachmentName {
                        HStack(spacing: 4) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 10))
                            Text(attachment)
                                .font(.caption2)
                        }
                        .foregroundColor(OKColor.actionPrimary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OKColor.textMuted.opacity(0.4))
            }
            .padding(16)
        }
    }
}

// MARK: - Edit Step Sheet

struct EditStepSheet: View {
    let step: WorkflowStep
    @Binding var isPresented: Bool
    let onSave: (WorkflowStep) -> Void

    @State private var editedName: String = ""
    @State private var editedInstructions: String = ""
    @State private var includeTimelineChanges: Bool = true

    var body: some View {
        ZStack {
            OKColor.shadow.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(OKColor.textMuted.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)

                    HStack {
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Cancel")
                                .font(.body)
                                .foregroundColor(OKColor.actionPrimary)
                        }

                        Spacer()

                        Text("Edit Step")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Spacer()

                        Button(action: {
                            var updated = step
                            updated.title = editedName
                            updated.instructions = editedInstructions
                            onSave(updated)
                        }) {
                            Text("Save")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(OKColor.actionPrimary)
                        }
                    }
                    .padding(.horizontal, 20)

                    Divider()

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Step Name")
                                .font(.subheadline)
                                .foregroundColor(OKColor.textMuted)

                            TextField("Step name", text: $editedName)
                                .font(.body)
                                .padding(12)
                                .background(OKColor.textMuted.opacity(0.1))
                                .cornerRadius(8)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Instructions")
                                .font(.subheadline)
                                .foregroundColor(OKColor.textMuted)

                            TextEditor(text: $editedInstructions)
                                .font(.body)
                                .frame(height: 100)
                                .padding(8)
                                .background(OKColor.textMuted.opacity(0.1))
                                .cornerRadius(8)
                        }

                        HStack {
                            Text("Include timeline changes")
                                .font(.body)

                            Spacer()

                            Toggle("", isOn: $includeTimelineChanges)
                                .labelsHidden()
                        }
                        .padding(12)
                        .background(OKColor.textMuted.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .background(OKColor.backgroundPrimary)
                .cornerRadius(20, corners: [.topLeft, .topRight])
            }
        }
        .onAppear {
            editedName = step.title
            editedInstructions = step.instructions
        }
    }
}

// MARK: - Corner Radius Extension

#if canImport(UIKit)
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#endif

#Preview {
    WorkflowTemplatesView()
        .environmentObject(AppState())
        .environmentObject(AppNavigationState())
        .environmentObject(TemplateStoreObservable.shared)
}
