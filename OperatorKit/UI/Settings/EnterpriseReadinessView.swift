import SwiftUI

// ============================================================================
// ENTERPRISE READINESS VIEW (Phase 10M, Updated Phase 10O)
//
// Read-only dashboard showing enterprise readiness status.
// Export via ShareSheet for procurement packets.
// Phase 10O: Added Pilot Mode entry point.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No behavior toggles
// ❌ No user content display
// ❌ No execution triggers
// ✅ Read-only status display
// ✅ Export via ShareSheet only
// ✅ User-initiated actions only
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct EnterpriseReadinessView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var packet: EnterpriseReadinessPacket?
    @State private var isLoading = true
    @State private var showingExport = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var showingPilotMode = false  // Phase 10O
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading readiness data...")
                } else if let packet = packet {
                    readinessContent(packet)
                } else {
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Could not load enterprise readiness data")
                    )
                }
            }
            .navigationTitle("Enterprise Readiness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadPacket()
            }
            .sheet(isPresented: $showingExport) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Export Error", isPresented: .constant(exportError != nil)) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "An error occurred")
            }
        }
    }
    
    // MARK: - Content
    
    private func readinessContent(_ packet: EnterpriseReadinessPacket) -> some View {
        List {
            // Readiness Overview
            overviewSection(packet)
            
            // Safety & Governance
            safetySection(packet)
            
            // Quality
            qualitySection(packet)
            
            // Team Governance
            teamSection(packet)
            
            // Export
            exportSection
            
            // Disclaimer
            disclaimerSection
        }
    }
    
    // MARK: - Overview Section
    
    private func overviewSection(_ packet: EnterpriseReadinessPacket) -> some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Readiness Score")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(packet.readinessScore)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor(packet.readinessScore))
                }
                
                Spacer()
                
                statusBadge(packet.readinessStatus)
            }
            .padding(.vertical, 8)
            
            LabeledContent("App Version", value: packet.appVersion)
            LabeledContent("Build", value: packet.buildNumber)
            LabeledContent("Mode", value: packet.releaseMode.capitalized)
            LabeledContent("Exported", value: packet.exportedAt)
        } header: {
            Text("Overview")
        }
    }
    
    // MARK: - Safety Section
    
    private func safetySection(_ packet: EnterpriseReadinessPacket) -> some View {
        Section {
            if let safety = packet.safetyContractStatus {
                HStack {
                    Label("Safety Contract", systemImage: "shield.checkered")
                    Spacer()
                    statusIcon(safety.status == "valid")
                }
                
                if safety.guaranteesCount > 0 {
                    LabeledContent("Guarantees", value: "\(safety.guaranteesCount)")
                }
            }
            
            if let docs = packet.docIntegritySummary {
                HStack {
                    Label("Documentation", systemImage: "doc.text")
                    Spacer()
                    Text("\(docs.presentCount)/\(docs.requiredDocsCount)")
                        .foregroundColor(docs.missingCount == 0 ? .green : .orange)
                }
            }
            
            if let claims = packet.claimRegistrySummary {
                HStack {
                    Label("Claims Registry", systemImage: "list.clipboard")
                    Spacer()
                    Text("\(claims.totalClaims) claims")
                        .foregroundColor(.secondary)
                }
            }
            
            if let risk = packet.appReviewRiskSummary {
                HStack {
                    Label("Review Risk", systemImage: "exclamationmark.triangle")
                    Spacer()
                    riskStatusBadge(risk.status)
                }
            }
        } header: {
            Text("Safety & Governance")
        }
    }
    
    // MARK: - Quality Section
    
    private func qualitySection(_ packet: EnterpriseReadinessPacket) -> some View {
        Section {
            if let quality = packet.qualitySummary {
                HStack {
                    Label("Quality Gate", systemImage: "checkmark.seal")
                    Spacer()
                    Text(quality.gateStatus.replacingOccurrences(of: "_", with: " ").capitalized)
                        .foregroundColor(quality.gateStatus == "passed" ? .green : .secondary)
                }
                
                LabeledContent("Coverage", value: "\(quality.coverageScore)%")
                LabeledContent("Trend", value: quality.trendDirection.capitalized)
                LabeledContent("Golden Cases", value: "\(quality.goldenCaseCount)")
            }
            
            if let diagnostics = packet.diagnosticsSummary {
                HStack {
                    Label("Invariants", systemImage: "checkmark.circle")
                    Spacer()
                    statusIcon(diagnostics.invariantsPassing)
                }
            }
        } header: {
            Text("Quality")
        }
    }
    
    // MARK: - Team Section
    
    private func teamSection(_ packet: EnterpriseReadinessPacket) -> some View {
        Section {
            if let team = packet.teamGovernanceSummary {
                HStack {
                    Label("Team Tier", systemImage: "person.3")
                    Spacer()
                    statusIcon(team.teamTierEnabled)
                }
                
                HStack {
                    Label("Cloud Sync", systemImage: "icloud")
                    Spacer()
                    Text(team.syncEnabled ? "Enabled" : "Off (opt-in)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("Policy Templates", systemImage: "doc.badge.gearshape")
                    Spacer()
                    statusIcon(team.policyTemplatesAvailable)
                }
            }
        } header: {
            Text("Team Governance")
        } footer: {
            Text("Team features require Team tier subscription")
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section {
            Button {
                exportPacket()
            } label: {
                Label("Export Procurement Packet (JSON)", systemImage: "square.and.arrow.up")
            }
            
            // Phase 10O: Pilot Mode entry point
            Button {
                showingPilotMode = true
            } label: {
                HStack {
                    Label("Pilot Mode", systemImage: "airplane")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .sheet(isPresented: $showingPilotMode) {
                PilotModeView()
            }
        } header: {
            Text("Export & Pilot")
        } footer: {
            Text("This export contains metadata only. No user content, no identifiers.")
        }
    }
    
    // MARK: - Disclaimer Section
    
    private var disclaimerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Procurement Ready", systemImage: "building.2")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("This packet provides evidence of safety, quality, and governance practices for enterprise procurement review. All data is metadata-only with no user content.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func statusBadge(_ status: EnterpriseReadinessStatus) -> some View {
        Text(status.rawValue.replacingOccurrences(of: "_", with: " "))
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusBackgroundColor(status))
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private func statusBackgroundColor(_ status: EnterpriseReadinessStatus) -> Color {
        switch status {
        case .ready: return .green
        case .partiallyReady: return .orange
        case .notReady: return .red
        case .unavailable: return .gray
        }
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
    
    private func statusIcon(_ passing: Bool) -> some View {
        Image(systemName: passing ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundColor(passing ? .green : .red)
    }
    
    private func riskStatusBadge(_ status: String) -> some View {
        Text(status)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(riskColor(status).opacity(0.2))
            .foregroundColor(riskColor(status))
            .cornerRadius(4)
    }
    
    private func riskColor(_ status: String) -> Color {
        switch status {
        case "PASS": return .green
        case "WARN": return .orange
        case "FAIL": return .red
        default: return .gray
        }
    }
    
    // MARK: - Actions
    
    @MainActor
    private func loadPacket() async {
        isLoading = true
        packet = EnterpriseReadinessBuilder.shared.build()
        isLoading = false
    }
    
    private func exportPacket() {
        Task { @MainActor in
            guard let packet = packet else { return }
            
            do {
                let exportPacket = EnterpriseReadinessExportPacket(packet: packet)
                let jsonData = try exportPacket.toJSONData()
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(exportPacket.filename)
                try jsonData.write(to: tempURL)
                
                exportURL = tempURL
                showingExport = true
            } catch {
                exportError = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EnterpriseReadinessView()
}
