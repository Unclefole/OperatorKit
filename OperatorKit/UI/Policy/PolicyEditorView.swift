import SwiftUI

// ============================================================================
// POLICY EDITOR VIEW (Phase 10C)
//
// User interface for editing operator policies.
// Explicit toggles, plain copy, no automation language.
//
// CONSTRAINTS:
// ✅ Explicit toggles
// ✅ Plain copy
// ✅ Changes require explicit Save
// ❌ No "AI" or "smart" language
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

struct PolicyEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var policyStore = OperatorPolicyStore.shared
    
    // Local state for editing (committed on Save)
    @State private var editedPolicy: OperatorPolicy = .defaultPolicy
    @State private var hasUnsavedChanges: Bool = false
    @State private var showingResetConfirmation: Bool = false
    @State private var showingDiscardConfirmation: Bool = false
    @State private var exportURL: URL?
    @State private var showingShareSheet: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                // Policy Status
                policyStatusSection
                
                // Capabilities
                capabilitiesSection
                
                // Limits
                limitsSection
                
                // Safety Mode
                safetyModeSection
                
                // Actions
                actionsSection
            }
            .navigationTitle("Execution Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showingDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePolicy()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasUnsavedChanges)
                }
            }
            .onAppear {
                loadCurrentPolicy()
            }
            .alert("Discard Changes?", isPresented: $showingDiscardConfirmation) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .alert("Reset to Defaults?", isPresented: $showingResetConfirmation) {
                Button("Reset", role: .destructive) {
                    resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all policy settings to their default values.")
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    // MARK: - Policy Status Section
    
    private var policyStatusSection: some View {
        Section {
            Toggle(isOn: $editedPolicy.enabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Policy Enabled")
                        .font(.body)
                    Text("When disabled, all capabilities are allowed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: editedPolicy.enabled) { _ in
                hasUnsavedChanges = true
            }
            
            if editedPolicy.enabled {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text(editedPolicy.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Status")
        } footer: {
            Text("Policies constrain what OperatorKit can do. They are enforced before any action is taken.")
        }
    }
    
    // MARK: - Capabilities Section
    
    private var capabilitiesSection: some View {
        Section {
            ForEach(PolicyCapability.allCases, id: \.self) { capability in
                capabilityToggle(capability)
            }
        } header: {
            Text("Capabilities")
        } footer: {
            Text("Disable capabilities to prevent specific types of actions.")
        }
        .disabled(!editedPolicy.enabled)
    }
    
    private func capabilityToggle(_ capability: PolicyCapability) -> some View {
        Toggle(isOn: binding(for: capability)) {
            HStack(spacing: 12) {
                Image(systemName: capability.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isCapabilityAllowed(capability) ? .blue : .gray)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(capability.displayName)
                        .font(.body)
                    Text(capability.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: isCapabilityAllowed(capability)) { _ in
            hasUnsavedChanges = true
        }
    }
    
    private func binding(for capability: PolicyCapability) -> Binding<Bool> {
        switch capability {
        case .emailDrafts:
            return $editedPolicy.allowEmailDrafts
        case .calendarWrites:
            return $editedPolicy.allowCalendarWrites
        case .taskCreation:
            return $editedPolicy.allowTaskCreation
        case .memoryWrites:
            return $editedPolicy.allowMemoryWrites
        }
    }
    
    private func isCapabilityAllowed(_ capability: PolicyCapability) -> Bool {
        switch capability {
        case .emailDrafts:
            return editedPolicy.allowEmailDrafts
        case .calendarWrites:
            return editedPolicy.allowCalendarWrites
        case .taskCreation:
            return editedPolicy.allowTaskCreation
        case .memoryWrites:
            return editedPolicy.allowMemoryWrites
        }
    }
    
    // MARK: - Limits Section
    
    private var limitsSection: some View {
        Section {
            // Daily execution limit
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily Execution Limit")
                    .font(.body)
                
                HStack {
                    if let limit = editedPolicy.maxExecutionsPerDay {
                        Text("\(limit) per day")
                            .foregroundColor(.primary)
                    } else {
                        Text("No limit")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Stepper(
                        "",
                        value: Binding(
                            get: { editedPolicy.maxExecutionsPerDay ?? 0 },
                            set: { newValue in
                                editedPolicy.maxExecutionsPerDay = newValue > 0 ? newValue : nil
                                hasUnsavedChanges = true
                            }
                        ),
                        in: 0...100
                    )
                    .labelsHidden()
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Limits")
        } footer: {
            Text("Set to 0 for no limit. This is separate from subscription limits.")
        }
        .disabled(!editedPolicy.enabled)
    }
    
    // MARK: - Safety Mode Section
    
    private var safetyModeSection: some View {
        Section {
            Toggle(isOn: $editedPolicy.requireExplicitConfirmation) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Require Explicit Confirmation")
                        .font(.body)
                    Text("Always show confirmation before executing actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: editedPolicy.requireExplicitConfirmation) { _ in
                hasUnsavedChanges = true
            }
        } header: {
            Text("Safety")
        } footer: {
            Text("This setting is always enabled by default for your protection.")
        }
        .disabled(!editedPolicy.enabled)
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        Section {
            // Export policy
            Button {
                exportPolicy()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                    Text("Export Policy")
                    Spacer()
                }
            }
            
            // Reset to defaults
            Button(role: .destructive) {
                showingResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.red)
                    Text("Reset to Defaults")
                    Spacer()
                }
            }
        } header: {
            Text("Actions")
        }
    }
    
    // MARK: - Actions
    
    private func loadCurrentPolicy() {
        editedPolicy = policyStore.currentPolicy
        hasUnsavedChanges = false
    }
    
    private func savePolicy() {
        policyStore.updatePolicy(editedPolicy)
        hasUnsavedChanges = false
        dismiss()
    }
    
    private func resetToDefaults() {
        editedPolicy = .defaultPolicy
        hasUnsavedChanges = true
    }
    
    private func exportPolicy() {
        let builder = PolicyExportBuilder(policyStore: policyStore)
        let packet = builder.buildPacket()
        
        do {
            let url = try packet.exportToFile()
            exportURL = url
            showingShareSheet = true
        } catch {
            // Handle error silently for now
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    PolicyEditorView()
}
