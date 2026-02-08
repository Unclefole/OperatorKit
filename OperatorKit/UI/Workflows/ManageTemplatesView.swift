import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Manage Templates screen for creating, editing, and organizing workflow templates
struct ManageTemplatesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState
    @EnvironmentObject var templateStore: TemplateStoreObservable
    @State private var showingCreateTemplate = false
    @State private var showDeleteConfirmation = false
    @State private var templateToDelete: CustomWorkflowTemplate?

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(spacing: 24) {
                        heroSection
                        actionsList

                        // Custom Templates List
                        if !templateStore.templates.isEmpty {
                            customTemplatesSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingCreateTemplate) {
            NavigationStack {
                CreateTemplateView()
                    .environmentObject(appState)
                    .environmentObject(templateStore)
            }
        }
        .alert("Delete Template?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                templateToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let template = templateToDelete {
                    Task {
                        await templateStore.delete(template.id)
                    }
                }
                templateToDelete = nil
            }
        } message: {
            if let template = templateToDelete {
                Text("Are you sure you want to delete \"\(template.name)\"? This action cannot be undone.")
            }
        }
        .task {
            await templateStore.load()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { nav.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }

            Spacer()

            OperatorKitLogoView(size: .small, showText: false)

            Spacer()

            Button(action: { nav.goHome() }) {
                Image(systemName: "house")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.4))

            Text("Template Management")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("Create custom templates, edit existing ones, and organize your workflow library.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    // MARK: - Actions List
    private var actionsList: some View {
        VStack(spacing: 0) {
            // Create custom templates - ACTIVE
            Button {
                showingCreateTemplate = true
            } label: {
                actionRow(
                    icon: "plus.circle.fill",
                    iconColor: .blue,
                    text: "Create custom templates",
                    showChevron: true
                )
            }

            Divider().padding(.leading, 52)

            // Edit template details - DISABLED
            actionRow(
                icon: "pencil.circle.fill",
                iconColor: .gray,
                text: "Edit template details",
                showChevron: true
            )
            .opacity(0.5)

            Divider().padding(.leading, 52)

            // Organize by category - DISABLED
            actionRow(
                icon: "folder.fill",
                iconColor: .gray,
                text: "Organize by category",
                showChevron: true
            )
            .opacity(0.5)

            Divider().padding(.leading, 52)

            // Export & share - DISABLED
            actionRow(
                icon: "square.and.arrow.up",
                iconColor: .gray,
                text: "Export & share templates",
                showChevron: true
            )
            .opacity(0.5)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    // MARK: - Custom Templates Section
    private var customTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Templates")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(templateStore.templateCount)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(templateStore.templates.enumerated()), id: \.element.id) { index, template in
                    templateRow(template)

                    if index < templateStore.templates.count - 1 {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Template Row
    private func templateRow(_ template: CustomWorkflowTemplate) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(template.color.swiftUIColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: template.icon)
                    .font(.system(size: 18))
                    .foregroundColor(template.color.swiftUIColor)
            }

            // Name and Description
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                if let description = template.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Delete Button
            Button {
                templateToDelete = template
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.7))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func actionRow(
        icon: String,
        iconColor: Color,
        text: String,
        showChevron: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

#if DEBUG
struct ManageTemplatesView_Previews: PreviewProvider {
    static var previews: some View {
        ManageTemplatesView()
            .environmentObject(AppState())
            .environmentObject(TemplateStoreObservable.shared)
    }
}
#endif
