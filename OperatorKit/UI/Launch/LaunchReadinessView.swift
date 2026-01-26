import SwiftUI

// ============================================================================
// LAUNCH READINESS VIEW (Phase 10Q)
//
// Launch checklist and readiness dashboard.
// Advisory only. No actions except export.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No blocking behavior
// ❌ No runtime enforcement
// ✅ Advisory only
// ✅ Export via ShareSheet
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct LaunchReadinessView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var checklistResult: LaunchChecklistResult?
    @State private var isLoading = true
    
    @State private var showingExport = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    
    var body: some View {
        NavigationView {
            List {
                // Overview Section
                overviewSection
                
                // Check Items by Category
                if let result = checklistResult {
                    ForEach(LaunchCheckCategory.allCases, id: \.self) { category in
                        let items = result.checkItems.filter { $0.category == category }
                        if !items.isEmpty {
                            Section {
                                ForEach(items) { item in
                                    CheckItemRow(item: item)
                                }
                            } header: {
                                Label(category.displayName, systemImage: category.icon)
                            }
                        }
                    }
                }
                
                // Export Section
                exportSection
            }
            .navigationTitle("Launch Readiness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await runChecks()
            }
            .sheet(isPresented: $showingExport) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Export Error", isPresented: .constant(exportError != nil)) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        Section {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Running checks...")
                        .foregroundColor(.secondary)
                }
            } else if let result = checklistResult {
                VStack(alignment: .leading, spacing: 12) {
                    // Status Badge
                    HStack {
                        Image(systemName: result.overallStatus.icon)
                            .foregroundColor(statusColor(result.overallStatus))
                        
                        Text(result.isLaunchReady ? "Launch Ready" : "Review Required")
                            .font(.headline)
                    }
                    
                    // Counts
                    HStack(spacing: 16) {
                        CountBadge(count: result.passCount, label: "Pass", color: .green)
                        CountBadge(count: result.warnCount, label: "Warn", color: .orange)
                        CountBadge(count: result.failCount, label: "Fail", color: .red)
                    }
                    
                    // Advisory note
                    Text("This checklist is advisory only and does not affect app functionality.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Overview")
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section {
            Button {
                exportChecklist()
            } label: {
                Label("Export Checklist Report", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("Export")
        } footer: {
            Text("Export contains metadata only. No user content included.")
        }
    }
    
    // MARK: - Actions
    
    private func runChecks() async {
        isLoading = true
        
        // Run on main actor
        let validator = await LaunchChecklistValidator.shared
        checklistResult = await validator.validate()
        
        isLoading = false
    }
    
    private func exportChecklist() {
        guard let result = checklistResult else { return }
        
        Task { @MainActor in
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let jsonData = try encoder.encode(result)
                
                let filename = "OperatorKit_LaunchChecklist_\(result.checkedAt).json"
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(filename)
                try jsonData.write(to: tempURL)
                
                exportURL = tempURL
                showingExport = true
            } catch {
                exportError = error.localizedDescription
            }
        }
    }
    
    private func statusColor(_ status: LaunchCheckStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .passing: return .green
        case .warning: return .orange
        case .failing: return .red
        }
    }
}

// MARK: - Check Item Row

private struct CheckItemRow: View {
    let item: LaunchCheckItem
    
    var body: some View {
        HStack {
            Image(systemName: item.status.icon)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.subheadline)
                
                if let details = item.details {
                    Text(details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var statusColor: Color {
        switch item.status {
        case .pending: return .gray
        case .passing: return .green
        case .warning: return .orange
        case .failing: return .red
        }
    }
}

// MARK: - Count Badge

private struct CountBadge: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    LaunchReadinessView()
}
