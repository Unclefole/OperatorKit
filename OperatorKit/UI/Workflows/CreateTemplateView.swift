import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Create Template screen for building new workflow templates
/// Navigated from ManageTemplatesView "Create custom templates" row
struct CreateTemplateView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var templateStore: TemplateStoreObservable
    @Environment(\.dismiss) private var dismiss

    @State private var templateName: String = ""
    @State private var templateDescription: String = ""
    @State private var selectedIcon: String = "star.fill"
    @State private var selectedColor: TemplateColor = .blue
    @State private var isSaving: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    private let availableIcons = [
        "star.fill", "doc.text.fill", "envelope.fill",
        "calendar", "bell.fill", "checkmark.circle.fill",
        "folder.fill", "briefcase.fill", "lightbulb.fill"
    ]

    /// Validation: template name must be non-empty after trimming
    private var canSave: Bool {
        !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        Form {
            Section {
                TextField("Template name", text: $templateName)
                    .textContentType(.name)
                    .autocorrectionDisabled()

                TextField("Description (optional)", text: $templateDescription, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("Template Info")
            }

            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundColor(selectedIcon == icon ? selectedColor.swiftUIColor : OKColor.textMuted)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedIcon == icon ? selectedColor.swiftUIColor.opacity(0.15) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Icon")
            }

            Section {
                HStack(spacing: 12) {
                    ForEach(TemplateColor.allCases, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            Circle()
                                .fill(color.swiftUIColor)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                        .padding(-4)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Color")
            }

            Section {
                previewCard
            } header: {
                Text("Preview")
            }

            Section {
                Button {
                    Task {
                        await saveTemplate()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Save Template")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!canSave)
            }
        }
        .navigationTitle("Create Template")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isSaving)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .interactiveDismissDisabled(isSaving)
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedColor.swiftUIColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: selectedIcon)
                    .font(.system(size: 22))
                    .foregroundColor(selectedColor.swiftUIColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(templateName.isEmpty ? "Template Name" : templateName)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(templateName.isEmpty ? OKColor.textMuted : .primary)

                Text(templateDescription.isEmpty ? "Description" : templateDescription)
                    .font(.caption)
                    .foregroundColor(OKColor.textMuted)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Save Action

    private func saveTemplate() async {
        isSaving = true

        // Construct validated template (failable initializer enforces invariants)
        guard let template = CustomWorkflowTemplate(
            name: templateName,
            description: templateDescription.isEmpty ? nil : templateDescription,
            icon: selectedIcon,
            color: selectedColor
        ) else {
            errorMessage = "Invalid template configuration"
            showError = true
            isSaving = false
            return
        }

        // Persist to store (background thread via actor)
        let success = await templateStore.add(template)

        if success {
            dismiss()
        } else {
            errorMessage = templateStore.lastError?.localizedDescription ?? "Failed to save template"
            showError = true
        }

        isSaving = false
    }
}

#if DEBUG
struct CreateTemplateView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CreateTemplateView()
                .environmentObject(AppState())
                .environmentObject(TemplateStoreObservable.shared)
        }
    }
}
#endif
