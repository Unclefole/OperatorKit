import SwiftUI
import UniformTypeIdentifiers

// ============================================================================
// PROCEDURE IMPORT VIEW (Phase 13B)
//
// UI for importing procedures from local files.
// Requires explicit confirmation. Validates against forbidden keys.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking
// ❌ No automatic import
// ✅ Local file picker only
// ✅ User confirmation required
// ✅ Forbidden key rejection
// ============================================================================

struct ProcedureImportView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = ProcedureStore.shared
    
    // MARK: - State
    
    @State private var showingFilePicker = false
    @State private var importedProcedures: [ProcedureTemplate] = []
    @State private var importError: String? = nil
    @State private var showingConfirmation = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                warningSection
                instructionsSection
                importSection
                
                if !importedProcedures.isEmpty {
                    previewSection
                }
                
                if let error = importError {
                    errorSection(error)
                }
            }
            .navigationTitle("Import Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .confirmationDialog(
                "Import Procedures?",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Import \(importedProcedures.count) Procedure(s)") {
                    confirmImport()
                }
                Button("Cancel", role: .cancel) {
                    importedProcedures = []
                }
            } message: {
                Text("These procedures have been validated. They contain logic only, no user data.")
            }
        }
    }
    
    // MARK: - Warning Section
    
    private var warningSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Validation Required")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Imported procedures are validated against forbidden content patterns before being accepted.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Instructions Section
    
    private var instructionsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Select a procedure file (.json)")
                Text("2. Review the imported procedure")
                Text("3. Confirm to add to your library")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        } header: {
            Text("How to Import")
        }
    }
    
    // MARK: - Import Section
    
    private var importSection: some View {
        Section {
            Button(action: { showingFilePicker = true }) {
                Label("Select File", systemImage: "doc.badge.plus")
            }
        } header: {
            Text("Select Procedure File")
        } footer: {
            Text("Only local files are supported. No network access.")
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        Section {
            ForEach(importedProcedures) { procedure in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: procedure.category.icon)
                            .foregroundColor(.green)
                        
                        Text(procedure.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    Text("Category: \(procedure.category.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Button(action: { showingConfirmation = true }) {
                Label("Confirm Import", systemImage: "square.and.arrow.down")
            }
            .disabled(store.remainingCapacity < importedProcedures.count)
        } header: {
            Text("Ready to Import")
        } footer: {
            if store.remainingCapacity < importedProcedures.count {
                Text("Not enough capacity. Delete some procedures first.")
                    .foregroundColor(.red)
            } else {
                Text("Procedures validated successfully. Tap to confirm.")
            }
        }
    }
    
    // MARK: - Error Section
    
    private func errorSection(_ error: String) -> some View {
        Section {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
        } header: {
            Text("Import Error")
        } footer: {
            Text("The file was rejected. It may contain forbidden content or invalid format.")
        }
    }
    
    // MARK: - Actions
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        importError = nil
        importedProcedures = []
        
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importError = "No file selected"
                return
            }
            
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Cannot access file"
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                let importResult = ProcedureImporter.importFromData(data, confirmed: true)
                
                switch importResult {
                case .success(let procedures):
                    importedProcedures = procedures
                case .rejectedForbiddenKeys(let errors):
                    importError = "Rejected: \(errors.joined(separator: ", "))"
                case .failure(let error):
                    importError = error
                case .requiresConfirmation:
                    break
                }
            } catch {
                importError = "Failed to read file: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            importError = "File selection failed: \(error.localizedDescription)"
        }
    }
    
    private func confirmImport() {
        for procedure in importedProcedures {
            _ = store.add(procedure, confirmed: true)
        }
        dismiss()
    }
}

// MARK: - Preview

#if DEBUG
struct ProcedureImportView_Previews: PreviewProvider {
    static var previews: some View {
        ProcedureImportView()
    }
}
#endif
