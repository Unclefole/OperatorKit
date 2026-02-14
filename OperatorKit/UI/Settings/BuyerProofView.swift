import SwiftUI

// ============================================================================
// BUYER PROOF VIEW (Phase 11A)
//
// Read-only view for buyer trust verification.
// Export via ShareSheet.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No behavior changes
// ❌ No user content display
// ✅ Read-only status display
// ✅ Export via ShareSheet only
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct BuyerProofView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var packet: BuyerProofPacket?
    @State private var isLoading = true
    
    @State private var showingExport = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    
    var body: some View {
        NavigationView {
            List {
                // Overview Section
                overviewSection
                
                // Proof Sections
                if let packet = packet {
                    proofSectionsView(packet)
                }
                
                // Export Section
                exportSection
            }
            .scrollContentBackground(.hidden)
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Buyer Proof")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await buildPacket()
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
        }
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        Section {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Building proof packet...")
                        .foregroundColor(OKColor.textSecondary)
                }
            } else if let packet = packet {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(OKColor.riskNominal)
                        
                        Text("Proof Packet Ready")
                            .font(.headline)
                    }
                    
                    Text("\(packet.availableSections.count) sections available")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                    
                    if !packet.unavailableSections.isEmpty {
                        Text("\(packet.unavailableSections.count) sections unavailable")
                            .font(.caption)
                            .foregroundColor(OKColor.riskWarning)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Overview")
        } footer: {
            Text("This packet contains metadata only. No user content is included.")
        }
    }
    
    // MARK: - Proof Sections View
    
    private func proofSectionsView(_ packet: BuyerProofPacket) -> some View {
        Group {
            // Safety Contract
            if let safety = packet.safetyContractStatus {
                Section {
                    ProofRow(
                        label: "Contract Valid",
                        value: safety.isValid ? "Yes" : "No",
                        status: safety.isValid ? .pass : .fail
                    )
                    ProofRow(
                        label: "Hash Match",
                        value: safety.hashMatch ? "Yes" : "No",
                        status: safety.hashMatch ? .pass : .warn
                    )
                } header: {
                    Label("Safety Contract", systemImage: "shield.checkered")
                }
            }
            
            // Quality Gate
            if let quality = packet.qualityGateSummary {
                Section {
                    ProofRow(
                        label: "Status",
                        value: quality.status.capitalized,
                        status: quality.status == "passing" ? .pass : .warn
                    )
                    if let coverage = quality.coverageScore {
                        ProofRow(
                            label: "Coverage",
                            value: "\(coverage)%",
                            status: coverage >= 80 ? .pass : .warn
                        )
                    }
                    ProofRow(
                        label: "Invariants",
                        value: quality.invariantsPassing ? "Passing" : "Failing",
                        status: quality.invariantsPassing ? .pass : .fail
                    )
                } header: {
                    Label("Quality Gate", systemImage: "checkmark.seal")
                }
            }
            
            // Diagnostics
            if let diag = packet.diagnosticsSummary {
                Section {
                    ProofRow(label: "Total Executions", value: "\(diag.totalExecutions)")
                    ProofRow(label: "Successes", value: "\(diag.successCount)")
                    ProofRow(label: "Failures", value: "\(diag.failureCount)")
                    if let rate = diag.successRate {
                        ProofRow(
                            label: "Success Rate",
                            value: String(format: "%.1f%%", rate * 100),
                            status: rate >= 0.9 ? .pass : .warn
                        )
                    }
                } header: {
                    Label("Diagnostics", systemImage: "waveform.path.ecg")
                }
            }
            
            // Policy
            if let policy = packet.policySummary {
                Section {
                    ProofRow(label: "Policy Enabled", value: policy.policyEnabled ? "Yes" : "No")
                    ProofRow(label: "Capabilities Enabled", value: "\(policy.capabilitiesEnabled)")
                    ProofRow(label: "Requires Confirmation", value: policy.requiresConfirmation ? "Yes" : "No")
                } header: {
                    Label("Policy", systemImage: "shield.lefthalf.filled")
                }
            }
            
            // Launch Checklist
            if let launch = packet.launchChecklistSummary {
                Section {
                    ProofRow(
                        label: "Launch Ready",
                        value: launch.isLaunchReady ? "Yes" : "No",
                        status: launch.isLaunchReady ? .pass : .warn
                    )
                    ProofRow(label: "Checks Passed", value: "\(launch.passCount)")
                    ProofRow(label: "Warnings", value: "\(launch.warnCount)")
                    ProofRow(label: "Failures", value: "\(launch.failCount)")
                } header: {
                    Label("Launch Checklist", systemImage: "checklist")
                }
            }
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section {
            Button {
                exportPacket()
            } label: {
                Label("Export Buyer Proof Packet", systemImage: "square.and.arrow.up")
            }
            .disabled(packet == nil)
        } header: {
            Text("Export")
        } footer: {
            Text("Share this packet with buyers to demonstrate trust and quality.")
        }
    }
    
    // MARK: - Actions
    
    private func buildPacket() async {
        isLoading = true
        
        let builder = await BuyerProofPacketBuilder.shared
        packet = await builder.build()
        
        isLoading = false
    }
    
    private func exportPacket() {
        guard let packet = packet else { return }
        
        Task { @MainActor in
            do {
                let jsonData = try packet.toJSONData()
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(packet.filename)
                try jsonData.write(to: tempURL)
                
                exportURL = tempURL
                showingExport = true
            } catch {
                exportError = error.localizedDescription
            }
        }
    }
}

// MARK: - Proof Row

private struct ProofRow: View {
    enum Status {
        case none, pass, warn, fail
    }
    
    let label: String
    let value: String
    var status: Status = .none
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(OKColor.textSecondary)
            
            Spacer()
            
            HStack(spacing: 6) {
                Text(value)
                    .fontWeight(.medium)
                
                if status != .none {
                    Image(systemName: statusIcon)
                        .foregroundColor(statusColor)
                        .font(.caption)
                }
            }
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .none: return ""
        case .pass: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .none: return .secondary
        case .pass: return OKColor.riskNominal
        case .warn: return OKColor.riskWarning
        case .fail: return OKColor.riskCritical
        }
    }
}

// MARK: - Preview

#Preview {
    BuyerProofView()
}
