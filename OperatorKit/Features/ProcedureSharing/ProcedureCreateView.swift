import SwiftUI

// ============================================================================
// PROCEDURE CREATE VIEW (Phase 13B)
//
// UI for creating new procedures from logic templates.
// Requires explicit confirmation. No user content captured.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content capture
// ❌ No draft inclusion
// ❌ No memory linkage
// ✅ Logic-only templates
// ✅ Explicit confirmation required
// ============================================================================

struct ProcedureCreateView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = ProcedureStore.shared
    
    // MARK: - State
    
    @State private var name: String = ""
    @State private var category: ProcedureCategory = .general
    @State private var outputType: ProcedureOutputType = .textSummary
    @State private var intentType: String = "general_request"
    @State private var promptScaffold: String = "{action} for {context}"
    @State private var requiresApproval: Bool = true
    @State private var showingConfirmation = false
    @State private var validationErrors: [String] = []
    @State private var showingValidationAlert = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                warningSection
                basicInfoSection
                intentSection
                constraintsSection
            }
            .navigationTitle("Create Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { validateAndConfirm() }
                        .disabled(name.isEmpty)
                }
            }
            .confirmationDialog(
                "Create Procedure?",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Create Procedure") { createProcedure() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This procedure contains logic only. No user data will be stored.")
            }
            .alert("Validation Error", isPresented: $showingValidationAlert) {
                Button("OK") {}
            } message: {
                Text(validationErrors.joined(separator: "\n"))
            }
        }
    }
    
    // MARK: - Warning Section
    
    private var warningSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("Procedures contain logic only. Do not enter personal information, emails, names, or any user content.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Basic Info Section
    
    private var basicInfoSection: some View {
        Section {
            TextField("Procedure Name", text: $name)
                .textContentType(.none)
                .autocorrectionDisabled()
            
            Picker("Category", selection: $category) {
                ForEach(ProcedureCategory.allCases, id: \.self) { cat in
                    Label(cat.displayName, systemImage: cat.icon)
                        .tag(cat)
                }
            }
            
            Picker("Output Type", selection: $outputType) {
                ForEach(ProcedureOutputType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
        } header: {
            Text("Basic Information")
        } footer: {
            Text("Use generic names like 'Weekly Summary' not 'John's Report'")
        }
    }
    
    // MARK: - Intent Section
    
    private var intentSection: some View {
        Section {
            TextField("Intent Type", text: $intentType)
                .textContentType(.none)
                .autocorrectionDisabled()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt Scaffold")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $promptScaffold)
                    .frame(minHeight: 80)
                    .font(.system(.body, design: .monospaced))
            }
        } header: {
            Text("Intent Structure")
        } footer: {
            Text("Use placeholders like {action}, {context}, {format}. Do not include actual content.")
        }
    }
    
    // MARK: - Constraints Section
    
    private var constraintsSection: some View {
        Section {
            Toggle("Requires Approval", isOn: $requiresApproval)
                .disabled(true) // Always required
        } header: {
            Text("Constraints")
        } footer: {
            Text("All procedures require user approval before execution. This cannot be disabled.")
        }
    }
    
    // MARK: - Actions
    
    private func validateAndConfirm() {
        let skeleton = IntentSkeleton(
            intentType: intentType,
            requiredContextTypes: [],
            promptScaffold: promptScaffold
        )
        
        let procedure = ProcedureTemplate(
            name: name,
            category: category,
            intentSkeleton: skeleton,
            constraints: ProcedureConstraints(requiresApproval: true),
            outputType: outputType
        )
        
        let validation = ProcedureTemplateValidator.validate(procedure)
        
        if validation.isValid {
            showingConfirmation = true
        } else {
            validationErrors = validation.errors
            showingValidationAlert = true
        }
    }
    
    private func createProcedure() {
        let skeleton = IntentSkeleton(
            intentType: intentType,
            requiredContextTypes: [],
            promptScaffold: promptScaffold
        )
        
        let procedure = ProcedureTemplate(
            name: name,
            category: category,
            intentSkeleton: skeleton,
            constraints: ProcedureConstraints(requiresApproval: true),
            outputType: outputType
        )
        
        let result = store.add(procedure, confirmed: true)
        
        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            validationErrors = [error]
            showingValidationAlert = true
        case .requiresConfirmation:
            break // Should not happen since we passed confirmed: true
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProcedureCreateView_Previews: PreviewProvider {
    static var previews: some View {
        ProcedureCreateView()
    }
}
#endif
