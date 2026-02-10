import SwiftUI

// ============================================================================
// AUDIT VAULT DASHBOARD VIEW (Phase 13E)
//
// Read-only dashboard displaying Audit Vault lineage and stats.
// Zero-content display - shows only hashes, enums, counts.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content display
// ❌ No execution triggers
// ❌ No networking
// ✅ Read-only display
// ✅ Feature-flagged
// ============================================================================

public struct AuditVaultDashboardView: View {
    
    // MARK: - State
    
    @StateObject private var store = AuditVaultStore.shared
    @State private var summary: AuditVaultSummary? = nil
    @State private var recentEvents: [AuditVaultEvent] = []
    @State private var showingPurgeConfirmation = false
    @State private var purgeResult: String? = nil
    @State private var showingPurgeResult = false
    @State private var showingExportSheet = false
    @State private var exportPacket: AuditVaultExportPacket? = nil
    
    // MARK: - Body
    
    public var body: some View {
        if AuditVaultFeatureFlag.isEnabled {
            dashboardContent
                .onAppear { refresh() }
        } else {
            featureDisabledView
        }
    }
    
    // MARK: - Dashboard Content
    
    private var dashboardContent: some View {
        List {
            headerSection
            summarySection
            recentEventsSection
            actionsSection
            footerSection
        }
        .navigationTitle("Audit Vault")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        .refreshable { refresh() }
        .confirmationDialog(
            "Purge Audit Vault?",
            isPresented: $showingPurgeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Purge All Events", role: .destructive) {
                performPurge()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all audit vault events from this device. This cannot be undone.")
        }
        .alert("Purge Complete", isPresented: $showingPurgeResult) {
            Button("OK") { purgeResult = nil }
        } message: {
            Text(purgeResult ?? "")
        }
        .sheet(isPresented: $showingExportSheet) {
            if let packet = exportPacket {
                AuditVaultExportSheet(packet: packet)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "archivebox.fill")
                        .font(.title)
                        .foregroundColor(OKColor.riskExtreme)
                    
                    Text("Audit Vault Lineage")
                        .font(.headline)
                }
                
                Text("Zero-content provenance tracking. Shows only hashes, counts, and timestamps - never user content.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        Section {
            if let summary = summary {
                SummaryRow(label: "Total Events", value: "\(summary.totalEvents)")
                SummaryRow(label: "Events (7 days)", value: "\(summary.eventsLast7Days)")
                SummaryRow(label: "Edit Count", value: "\(summary.editCount)")
                SummaryRow(label: "Export Count", value: "\(summary.exportCount)")
                
                if let lastVerified = summary.lastVerifiedDayRounded {
                    SummaryRow(label: "Last Verified", value: lastVerified)
                }
            } else {
                Text("Loading...")
                    .foregroundColor(OKColor.textSecondary)
            }
        } header: {
            Text("Summary")
        } footer: {
            Text("Ring buffer: max \(AuditVaultStore.maxEventCount) events")
        }
    }
    
    // MARK: - Recent Events Section
    
    private var recentEventsSection: some View {
        Section {
            if recentEvents.isEmpty {
                Text("No events yet")
                    .foregroundColor(OKColor.textSecondary)
                    .italic()
            } else {
                ForEach(recentEvents.prefix(10)) { event in
                    NavigationLink(destination: AuditVaultEventDetailView(event: event)) {
                        EventRow(event: event)
                    }
                }
            }
        } header: {
            Text("Recent Events")
        } footer: {
            if recentEvents.count > 10 {
                Text("Showing 10 of \(recentEvents.count) events")
            }
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        Section {
            Button(action: { prepareExport() }) {
                Label("Export Summary", systemImage: "square.and.arrow.up")
            }
            .disabled(store.events.isEmpty)
            
            Button(role: .destructive, action: { showingPurgeConfirmation = true }) {
                Label("Purge Vault", systemImage: "trash")
            }
            .disabled(store.events.isEmpty)
        } header: {
            Text("Actions")
        } footer: {
            Text("Export produces metadata-only JSON. Purge requires explicit confirmation.")
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Content-Free Guarantee")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("This vault stores only hashes, enum values, counts, and day-rounded timestamps. User text, drafts, emails, and personal data are never stored.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Feature Disabled View
    
    private var featureDisabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox.fill")
                .font(.largeTitle)
                .foregroundColor(OKColor.textSecondary)
            
            Text("Audit Vault")
                .font(.headline)
            
            Text("This feature is not enabled.")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func refresh() {
        summary = store.summary()
        recentEvents = store.list(limit: 50)
    }
    
    private func performPurge() {
        let result = store.purge(confirmed: true)
        switch result {
        case .success(let count):
            purgeResult = "Purged \(count) events"
            showingPurgeResult = true
            refresh()
        case .requiresConfirmation:
            break
        case .notEnabled:
            purgeResult = "Feature not enabled"
            showingPurgeResult = true
        }
    }
    
    private func prepareExport() {
        exportPacket = store.exportSummary()
        if exportPacket != nil {
            // Record export event
            store.addEvent(kind: .lineageExported, lineage: nil)
            showingExportSheet = true
        }
    }
    
    // MARK: - Init
    
    public init() {}
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
        }
    }
}

// MARK: - Event Row

private struct EventRow: View {
    let event: AuditVaultEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: event.kind.icon)
                    .foregroundColor(OKColor.riskExtreme)
                    .frame(width: 20)
                
                Text(event.kind.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("#\(event.sequenceNumber)")
                    .font(.caption2)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            HStack {
                Text(event.createdAtDayRounded)
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
                
                if let lineage = event.lineage {
                    Text("•")
                        .foregroundColor(OKColor.textSecondary)
                    Text(lineage.outcomeType.displayName)
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Export Sheet

private struct AuditVaultExportSheet: View {
    let packet: AuditVaultExportPacket
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Total Events: \(packet.summary.totalEvents)")
                    Text("Edit Count: \(packet.summary.editCount)")
                    Text("Export Count: \(packet.summary.exportCount)")
                    Text("Exported: \(packet.exportedAtDayRounded)")
                } header: {
                    Text("Export Summary")
                }
                
                Section {
                    Text("This export contains metadata only. No user content, no drafts, no personal data.")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                } footer: {
                    Text("Share via the system share sheet")
                }
            }
            .navigationTitle("Export Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(
                        item: exportJSON(),
                        preview: SharePreview("Audit Vault Export", image: Image(systemName: "archivebox"))
                    )
                }
            }
        }
    }
    
    private func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(packet),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }
}

// MARK: - Preview

#if DEBUG
struct AuditVaultDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AuditVaultDashboardView()
        }
    }
}
#endif
