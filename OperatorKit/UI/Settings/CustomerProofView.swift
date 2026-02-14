import SwiftUI

// ============================================================================
// CUSTOMER PROOF VIEW (Phase 10P)
//
// Customer-facing trust proof dashboard.
// Read-only. No behavior toggles. No background monitoring.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No behavior changes
// ❌ No background monitoring
// ❌ No user content display
// ✅ Read-only status
// ✅ Export via ShareSheet
// ✅ User-initiated only
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct CustomerProofView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var auditStore = CustomerAuditTrailStore.shared
    
    @State private var isLoading = true
    @State private var safetyContractMatch = false
    @State private var qualityGateStatus = "Unknown"
    @State private var coverageScore = 0
    @State private var policyCapabilities: [String] = []
    
    @State private var showingExport = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    
    @State private var showingPurgeConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                // Safety Contract
                safetyContractSection
                
                // Quality Gate
                qualityGateSection
                
                // Policy Summary
                policySummarySection
                
                // Audit Trail Summary
                auditTrailSection
                
                // Export Actions
                exportSection
                
                // Data Management
                dataManagementSection
            }
            .scrollContentBackground(.hidden)
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Proof & Trust")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadData()
            }
            .sheet(isPresented: $showingExport) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Export Error", isPresented: .constant(exportError != nil)) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
            .confirmationDialog(
                "Purge Audit Trail",
                isPresented: $showingPurgeConfirmation,
                titleVisibility: .visible
            ) {
                Button("Purge All Events", role: .destructive) {
                    auditStore.purgeAll()
                }
                Button("Keep Last 7 Days") {
                    auditStore.purgeOlderThan(days: 7)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete audit events. This cannot be undone.")
            }
        }
    }
    
    // MARK: - Safety Contract Section
    
    private var safetyContractSection: some View {
        Section {
            HStack {
                Image(systemName: safetyContractMatch ? "checkmark.shield.fill" : "exclamationmark.shield")
                    .foregroundColor(safetyContractMatch ? OKColor.riskNominal : OKColor.riskWarning)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Safety Contract")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(safetyContractMatch ? "Hash matches expected" : "Verification pending")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
                
                Spacer()
                
                StatusBadge(status: safetyContractMatch ? .passing : .warning)
            }
        } header: {
            Text("Safety Verification")
        } footer: {
            Text("Verifies safety contract integrity on-device.")
        }
    }
    
    // MARK: - Quality Gate Section
    
    private var qualityGateSection: some View {
        Section {
            HStack {
                Image(systemName: "gauge.with.needle")
                    .foregroundColor(OKColor.actionPrimary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quality Gate")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(qualityGateStatus)
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
                
                Spacer()
                
                Text("\(coverageScore)%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(OKColor.actionPrimary)
            }
        } header: {
            Text("Quality")
        }
    }
    
    // MARK: - Policy Summary Section
    
    private var policySummarySection: some View {
        Section {
            ForEach(policyCapabilities, id: \.self) { capability in
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(OKColor.riskNominal)
                        .font(.caption)
                    
                    Text(capability)
                        .font(.caption)
                }
            }
            
            if policyCapabilities.isEmpty {
                Text("Loading policy...")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
        } header: {
            Text("Policy Capabilities")
        } footer: {
            Text("Current policy settings for this device.")
        }
    }
    
    // MARK: - Audit Trail Section
    
    private var auditTrailSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Events")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                    
                    Text("\(auditStore.events.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last 7 Days")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                    
                    Text("\(auditStore.eventsFromLastDays(7).count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(OKColor.actionPrimary)
                }
            }
            
            // Recent event kinds
            if !auditStore.events.isEmpty {
                let summary = auditStore.currentSummary()
                let topKinds = summary.countByKind.sorted { $0.value > $1.value }.prefix(3)
                
                ForEach(Array(topKinds), id: \.key) { kind, count in
                    HStack {
                        Text(kind.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption)
                        
                        Spacer()
                        
                        Text("\(count)")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                }
            }
        } header: {
            Text("Audit Trail")
        } footer: {
            Text("Metadata-only event log. No user content stored.")
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section {
            Button {
                exportReproBundle()
            } label: {
                Label("Export Repro Bundle", systemImage: "square.and.arrow.up")
            }
            
            NavigationLink {
                PilotModeView()
            } label: {
                Label("Pilot Mode", systemImage: "airplane")
            }
        } header: {
            Text("Export & Diagnostics")
        } footer: {
            Text("Exports contain metadata only. No user content included.")
        }
    }
    
    // MARK: - Data Management Section
    
    private var dataManagementSection: some View {
        Section {
            Button(role: .destructive) {
                showingPurgeConfirmation = true
            } label: {
                Label("Purge Audit Trail", systemImage: "trash")
            }
        } header: {
            Text("Data Management")
        } footer: {
            Text("Permanently deletes audit events from this device.")
        }
    }
    
    // MARK: - Actions
    
    private func loadData() async {
        // Load safety contract status
        safetyContractMatch = SafetyContractValidator.shared.isValid
        
        // Load quality gate
        if let gate = QualityGate.shared.currentResult {
            qualityGateStatus = gate.status.rawValue.capitalized
            coverageScore = gate.coverageScore ?? 0
        }
        
        // Load policy
        let policy = OperatorPolicyStore.shared.currentPolicy
        var capabilities: [String] = []
        if policy.allowEmailDrafts { capabilities.append("Email Drafts") }
        if policy.allowCalendarWrites { capabilities.append("Calendar Writes") }
        if policy.allowTaskCreation { capabilities.append("Task Creation") }
        if policy.allowMemoryWrites { capabilities.append("Memory Writes") }
        policyCapabilities = capabilities
        
        isLoading = false
    }
    
    private func exportReproBundle() {
        Task { @MainActor in
            do {
                let builder = ReproBundleBuilder()
                let bundle = builder.build()
                let jsonData = try bundle.toJSONData()
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(bundle.filename)
                try jsonData.write(to: tempURL)
                
                exportURL = tempURL
                showingExport = true
            } catch {
                exportError = error.localizedDescription
            }
        }
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    enum Status {
        case passing, warning, failing
        
        var text: String {
            switch self {
            case .passing: return "PASS"
            case .warning: return "WARN"
            case .failing: return "FAIL"
            }
        }
        
        var color: Color {
            switch self {
            case .passing: return OKColor.riskNominal
            case .warning: return OKColor.riskWarning
            case .failing: return OKColor.riskCritical
            }
        }
    }
    
    let status: Status
    
    var body: some View {
        Text(status.text)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color)
            .foregroundColor(OKColor.textPrimary)
            .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    CustomerProofView()
}
