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
            Color(UIColor.systemGroupedBackground)
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
                            .foregroundColor(.orange)

                        Text("Template not found")
                            .font(.headline)
                            .foregroundColor(.secondary)
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
                    .foregroundColor(.blue)
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
                .foregroundColor(.primary)

            // Badge
            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.system(size: 10))

                Text("Custom Template")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(template.color.swiftUIColor)
            .cornerRadius(12)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
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
                        .foregroundColor(.primary)
                } else {
                    Text("No description provided")
                        .font(.body)
                        .foregroundColor(.gray)
                        .italic()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                            .foregroundColor(.gray.opacity(0.5))

                        Text("No steps defined")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Workflow steps will appear here")
                            .font(.caption)
                            .foregroundColor(.gray)
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
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                if !step.instructions.isEmpty {
                    Text(step.instructions)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray.opacity(0.4))
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
                        .foregroundColor(.primary)

                    Spacer()

                    Text("\(template.steps.count)")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(16)

                Divider()
                    .padding(.leading, 16)

                HStack {
                    Text("Schema Version")
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("v\(template.schemaVersion)")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(16)
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    private func timestampRow(label: String, date: Date) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Text(formatDate(date))
                .font(.body)
                .foregroundColor(.secondary)
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
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.red.opacity(0.1))
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
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(template.color.swiftUIColor)
            .cornerRadius(14)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            Color(UIColor.systemGroupedBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
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
