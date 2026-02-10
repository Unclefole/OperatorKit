import SwiftUI

// ============================================================================
// PROCEDURE SHARING VIEW (Phase 13B)
//
// Main UI for procedure management.
// All operations require explicit user confirmation.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No execution triggers
// ❌ No automatic operations
// ❌ No networking
// ✅ User-initiated only
// ✅ Explicit confirmation required
// ✅ Feature-flagged
// ============================================================================

public struct ProcedureSharingView: View {
    
    // MARK: - State
    
    @StateObject private var store = ProcedureStore.shared
    @State private var selectedCategory: ProcedureCategory? = nil
    @State private var showingCreateSheet = false
    @State private var showingImportSheet = false
    @State private var showingExportSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var procedureToDelete: ProcedureTemplate? = nil
    @State private var alertMessage: String? = nil
    @State private var showingAlert = false
    
    // MARK: - Body
    
    public var body: some View {
        if ProcedureSharingFeatureFlag.isEnabled {
            mainContent
        } else {
            featureDisabledView
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        List {
            warningSection
            statsSection
            proceduresSection
            actionsSection
        }
        .navigationTitle("Procedures")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingCreateSheet = true }) {
                    Image(systemName: "plus")
                }
                .disabled(store.isAtCapacity)
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            ProcedureCreateView()
        }
        .sheet(isPresented: $showingImportSheet) {
            ProcedureImportView()
        }
        .alert("Procedure Sharing", isPresented: $showingAlert) {
            Button("OK") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .confirmationDialog(
            "Delete Procedure?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let procedure = procedureToDelete {
                    _ = store.remove(id: procedure.id, confirmed: true)
                }
                procedureToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                procedureToDelete = nil
            }
        } message: {
            Text("This procedure will be permanently deleted from this device.")
        }
    }
    
    // MARK: - Warning Section
    
    private var warningSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(OKColor.actionPrimary)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Logic Only")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Procedures contain workflow logic only. No user data, drafts, or personal information is ever included.")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        Section {
            HStack {
                Text("Stored Procedures")
                Spacer()
                Text("\(store.count) / \(ProcedureStore.maxProcedureCount)")
                    .foregroundColor(OKColor.textSecondary)
            }
            
            HStack {
                Text("Remaining Capacity")
                Spacer()
                Text("\(store.remainingCapacity)")
                    .foregroundColor(store.isAtCapacity ? OKColor.riskCritical : .secondary)
            }
        } header: {
            Text("Storage")
        }
    }
    
    // MARK: - Procedures Section
    
    private var proceduresSection: some View {
        Section {
            if store.procedures.isEmpty {
                Text("No procedures yet")
                    .foregroundColor(OKColor.textSecondary)
                    .italic()
            } else {
                ForEach(store.procedures) { procedure in
                    ProcedureRow(
                        procedure: procedure,
                        onDelete: {
                            procedureToDelete = procedure
                            showingDeleteConfirmation = true
                        },
                        onExport: {
                            exportProcedure(procedure)
                        }
                    )
                }
            }
        } header: {
            Text("Procedures")
        } footer: {
            Text("Tap a procedure to apply it (prefills intent, does not execute).")
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        Section {
            Button(action: { showingImportSheet = true }) {
                Label("Import Procedure", systemImage: "square.and.arrow.down")
            }
            
            Button(action: { exportAllProcedures() }) {
                Label("Export All Procedures", systemImage: "square.and.arrow.up")
            }
            .disabled(store.procedures.isEmpty)
        } header: {
            Text("Actions")
        } footer: {
            Text("Import and export use local files only. No network access.")
        }
    }
    
    // MARK: - Feature Disabled View
    
    private var featureDisabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundColor(OKColor.textSecondary)
            
            Text("Procedure Sharing")
                .font(.headline)
            
            Text("This feature is not enabled.")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func exportProcedure(_ procedure: ProcedureTemplate) {
        let result = ProcedureExporter.export(procedure)
        switch result {
        case .success:
            alertMessage = "Procedure ready for export"
            showingAlert = true
        case .failure(let error):
            alertMessage = "Export failed: \(error)"
            showingAlert = true
        }
    }
    
    private func exportAllProcedures() {
        let result = ProcedureExporter.exportMultiple(store.procedures)
        switch result {
        case .success:
            alertMessage = "All procedures ready for export"
            showingAlert = true
        case .failure(let error):
            alertMessage = "Export failed: \(error)"
            showingAlert = true
        }
    }
    
    // MARK: - Init
    
    public init() {}
}

// MARK: - Procedure Row

private struct ProcedureRow: View {
    let procedure: ProcedureTemplate
    let onDelete: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: procedure.category.icon)
                    .foregroundColor(OKColor.actionPrimary)
                    .frame(width: 24)
                
                Text(procedure.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Menu {
                    Button(action: onExport) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(OKColor.textSecondary)
                }
            }
            
            HStack {
                Text(procedure.category.displayName)
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
                
                Text("•")
                    .foregroundColor(OKColor.textSecondary)
                
                Text(procedure.outputType.displayName)
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
struct ProcedureSharingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProcedureSharingView()
        }
    }
}
#endif
