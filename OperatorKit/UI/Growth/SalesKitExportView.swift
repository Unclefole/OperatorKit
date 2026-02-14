import SwiftUI

// ============================================================================
// SALES KIT EXPORT VIEW (Phase 11B)
//
// Read-only preview + export for sales kit packet.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No editing
// ❌ No user content
// ✅ Read-only preview
// ✅ Export via ShareSheet
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct SalesKitExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var packet: SalesKitPacket?
    @State private var isLoading = true
    
    @State private var showingExport = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    
    var body: some View {
        NavigationView {
            List {
                // Overview
                overviewSection
                
                // Sections Status
                if let packet = packet {
                    sectionsStatusView(packet)
                }
                
                // Export
                exportSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Sales Kit Export")
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
                    Text("Building sales kit...")
                        .foregroundColor(OKColor.textSecondary)
                }
            } else if let packet = packet {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "briefcase.fill")
                            .foregroundColor(OKColor.actionPrimary)
                        
                        Text("Sales Kit Ready")
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
            Text("Combines pricing, playbook, pipeline, and proof artifacts. Metadata only.")
        }
    }
    
    // MARK: - Sections Status
    
    private func sectionsStatusView(_ packet: SalesKitPacket) -> some View {
        Group {
            // Pricing Package
            Section {
                StatusRow(
                    label: "Pricing Package",
                    isAvailable: packet.pricingPackageSnapshot != nil,
                    detail: packet.pricingPackageSnapshot.map { "\($0.packages.count) tiers" }
                )
                
                if let validation = packet.pricingValidationResult {
                    StatusRow(
                        label: "Pricing Validation",
                        isAvailable: true,
                        detail: validation.status.displayName,
                        status: validation.status
                    )
                }
            } header: {
                Label("Pricing", systemImage: "dollarsign.circle")
            }
            
            // Sales Tools
            Section {
                StatusRow(
                    label: "Playbook Sections",
                    isAvailable: packet.playbookMetadata != nil,
                    detail: packet.playbookMetadata.map { "\($0.sectionCount) sections" }
                )
                
                StatusRow(
                    label: "Pipeline Summary",
                    isAvailable: packet.pipelineSummary != nil,
                    detail: packet.pipelineSummary.map { "\($0.totalItems) opportunities" }
                )
            } header: {
                Label("Sales Tools", systemImage: "briefcase")
            }
            
            // Trust Artifacts
            Section {
                StatusRow(
                    label: "Buyer Proof",
                    isAvailable: packet.buyerProofStatus != nil,
                    detail: packet.buyerProofStatus.map { "\($0.availableSectionsCount) sections" }
                )
                
                if let enterprise = packet.enterpriseReadinessSummary {
                    StatusRow(
                        label: "Enterprise Readiness",
                        isAvailable: true,
                        detail: enterprise.overallStatus.capitalized,
                        status: statusFromReadiness(enterprise.overallStatus)
                    )
                }
            } header: {
                Label("Trust Artifacts", systemImage: "checkmark.seal")
            }
        }
    }
    
    private func statusFromReadiness(_ status: String) -> PricingValidationStatus {
        switch status {
        case "ready": return .pass
        case "partial": return .warn
        default: return .fail
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section {
            Button {
                exportPacket()
            } label: {
                Label("Export Sales Kit Packet", systemImage: "square.and.arrow.up")
            }
            .disabled(packet == nil)
        } header: {
            Text("Export")
        } footer: {
            Text("Share with prospects and procurement teams. No user content included.")
        }
    }
    
    // MARK: - Actions
    
    private func buildPacket() async {
        isLoading = true
        
        let builder = await SalesKitPacketBuilder.shared
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

// MARK: - Status Row

private struct StatusRow: View {
    let label: String
    let isAvailable: Bool
    var detail: String? = nil
    var status: PricingValidationStatus? = nil
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(OKColor.textSecondary)
            
            Spacer()
            
            if let detail = detail {
                Text(detail)
                    .fontWeight(.medium)
            }
            
            if let status = status {
                Image(systemName: status.icon)
                    .foregroundColor(statusColor(for: status))
                    .font(.caption)
            } else {
                Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(isAvailable ? OKColor.riskNominal : OKColor.textMuted)
                    .font(.caption)
            }
        }
    }
    
    private func statusColor(for status: PricingValidationStatus) -> Color {
        switch status {
        case .pass: return OKColor.riskNominal
        case .warn: return OKColor.riskWarning
        case .fail: return OKColor.riskCritical
        }
    }
}

// MARK: - Preview

#Preview {
    SalesKitExportView()
}
