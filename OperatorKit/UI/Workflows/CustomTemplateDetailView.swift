import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Detail view for user-created custom workflow templates.
/// Shows name, description, steps count, icon/color, and timestamps.
struct CustomTemplateDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState
    @EnvironmentObject var templateStore: TemplateStoreObservable
    @State private var showDeleteConfirmation = false

    private var template: CustomWorkflowTemplate? {
        appState.selectedCustomTemplate
    }

    var body: some View {
        ZStack {
            OKColor.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                if let template = template {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Hero Card
                            heroCard(template)

                            // Details Section
                            detailsSection(template)

                            // Steps Section
                            stepsSection(template)

                            // Timestamps Section
                            timestampsSection(template)

                            // Delete Button
                            deleteButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }

                    Spacer()

                    // Bottom Action Button
                    VStack {
                        Spacer()
                        runWorkflowButton(template)
                    }
                } else {
                    // Fallback if no template selected
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(OKColor.riskWarning)

                        Text("Template not found")
                            .font(.headline)
                            .foregroundColor(OKColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Delete Template?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let template = template {
                    Task { @MainActor in
                        await templateStore.delete(template.id)
                        appState.selectedCustomTemplate = nil
                        nav.goBack()
                    }
                }
            }
        } message: {
            if let template = template {
                Text("Are you sure you want to delete \"\(template.name)\"? This action cannot be undone.")
            }
        }
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

            Text(template?.name ?? "Custom Template")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Hero Card

    private func heroCard(_ template: CustomWorkflowTemplate) -> some View {
        VStack(spacing: 16) {
            // Large Icon
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(template.color.swiftUIColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: template.icon)
                    .font(.system(size: 36))
                    .foregroundColor(template.color.swiftUIColor)
            }

            // Name
            Text(template.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(OKColor.textPrimary)

            // Badge
            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.system(size: 10))

                Text("Custom Template")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(OKColor.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(template.color.swiftUIColor)
            .cornerRadius(12)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(16)
        .shadow(color: OKColor.shadow.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    // MARK: - Details Section

    private func detailsSection(_ template: CustomWorkflowTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                if let description = template.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundColor(OKColor.textPrimary)
                } else {
                    Text("No description provided")
                        .font(.body)
                        .foregroundColor(OKColor.textMuted)
                        .italic()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Steps Section

    private func stepsSection(_ template: CustomWorkflowTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Steps")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 0) {
                if template.steps.isEmpty {
                    // Empty steps state
                    VStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.system(size: 32))
                            .foregroundColor(OKColor.textMuted.opacity(0.5))

                        Text("No steps defined")
                            .font(.subheadline)
                            .foregroundColor(OKColor.textSecondary)

                        Text("Workflow steps will appear here")
                            .font(.caption)
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(Array(template.steps.enumerated()), id: \.element.id) { index, step in
                        customStepRow(step, index: index + 1, color: template.color.swiftUIColor)

                        if index < template.steps.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Custom Step Row

    private func customStepRow(_ step: TemplateStep, index: Int, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 28, height: 28)

                Text("\(index)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(OKColor.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(OKColor.textPrimary)

                if !step.instructions.isEmpty {
                    Text(step.instructions)
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(OKColor.textMuted.opacity(0.4))
        }
        .padding(16)
    }

    // MARK: - Timestamps Section

    private func timestampsSection(_ template: CustomWorkflowTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 0) {
                timestampRow(label: "Created", date: template.createdAt)

                Divider()
                    .padding(.leading, 16)

                timestampRow(label: "Last Updated", date: template.updatedAt)

                Divider()
                    .padding(.leading, 16)

                HStack {
                    Text("Steps Count")
                        .font(.body)
                        .foregroundColor(OKColor.textPrimary)

                    Spacer()

                    Text("\(template.steps.count)")
                        .font(.body)
                        .foregroundColor(OKColor.textSecondary)
                }
                .padding(16)

                Divider()
                    .padding(.leading, 16)

                HStack {
                    Text("Schema Version")
                        .font(.body)
                        .foregroundColor(OKColor.textPrimary)

                    Spacer()

                    Text("v\(template.schemaVersion)")
                        .font(.body)
                        .foregroundColor(OKColor.textSecondary)
                }
                .padding(16)
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    private func timestampRow(label: String, date: Date) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(OKColor.textPrimary)

            Spacer()

            Text(formatDate(date))
                .font(.body)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding(16)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(action: {
            showDeleteConfirmation = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                Text("Delete Template")
            }
            .font(.body)
            .foregroundColor(OKColor.riskCritical)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(OKColor.riskCritical.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - Run Workflow Button

    private func runWorkflowButton(_ template: CustomWorkflowTemplate) -> some View {
        Button(action: {
            // Start workflow execution with custom template
            let intent = IntentRequest(
                rawText: "Run \(template.name) workflow",
                intentType: .draftEmail
            )
            appState.selectedIntent = intent
            nav.navigate(to: .context)
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
            .background(template.color.swiftUIColor)
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

#if DEBUG
struct CustomTemplateDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState()
        // Create a sample custom template for preview
        appState.selectedCustomTemplate = CustomWorkflowTemplate(
            name: "Sample Template",
            description: "This is a sample custom workflow template for preview purposes.",
            icon: "star.fill",
            color: .purple,
            steps: [
                TemplateStep(order: 1, title: "First Step", instructions: "Do the first thing"),
                TemplateStep(order: 2, title: "Second Step", instructions: "Then do this")
            ]
        )

        return CustomTemplateDetailView()
            .environmentObject(appState)
            .environmentObject(TemplateStoreObservable.shared)
    }
}
#endif
