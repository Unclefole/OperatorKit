import SwiftUI

// ============================================================================
// AUDIT VAULT EVENT DETAIL VIEW (Phase 13E)
//
// Read-only detail view for a single Audit Vault event.
// Shows lineage fields only - never user content.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content display
// ❌ No execution triggers
// ✅ Read-only display
// ✅ Lineage fields only
// ============================================================================

public struct AuditVaultEventDetailView: View {
    
    // MARK: - Properties
    
    let event: AuditVaultEvent
    
    // MARK: - Body
    
    public var body: some View {
        List {
            eventSection
            
            if let lineage = event.lineage {
                lineageSection(lineage)
                lineageHashSection(lineage)
            }
            
            metadataSection
            footerSection
        }
        .navigationTitle("Event Detail")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
    
    // MARK: - Event Section
    
    private var eventSection: some View {
        Section {
            DetailRow(label: "Event Kind", value: event.kind.displayName, icon: event.kind.icon)
            DetailRow(label: "Sequence", value: "#\(event.sequenceNumber)", icon: "number")
            DetailRow(label: "Date", value: event.createdAtDayRounded, icon: "calendar")
            DetailRow(label: "Event Hash", value: event.deterministicHash, icon: "number.circle")
        } header: {
            Text("Event")
        }
    }
    
    // MARK: - Lineage Section
    
    private func lineageSection(_ lineage: AuditVaultLineage) -> some View {
        Section {
            DetailRow(label: "Outcome Type", value: lineage.outcomeType.displayName, icon: "doc")
            DetailRow(label: "Context Slot", value: lineage.contextSlot.displayName, icon: "square.stack")
            DetailRow(label: "Policy Decision", value: lineage.policyDecision.rawValue.capitalized, icon: "shield")
            DetailRow(label: "Tier", value: lineage.tierAtTime.rawValue.capitalized, icon: "star")
            DetailRow(label: "Edit Count", value: "\(lineage.editCount)", icon: "pencil")
            DetailRow(label: "Created", value: lineage.createdAtDayRounded, icon: "calendar.badge.plus")
            DetailRow(label: "Last Modified", value: lineage.lastModifiedDayRounded, icon: "calendar.badge.clock")
        } header: {
            Text("Lineage")
        } footer: {
            Text(lineage.displaySummary)
        }
    }
    
    // MARK: - Lineage Hash Section
    
    private func lineageHashSection(_ lineage: AuditVaultLineage) -> some View {
        Section {
            if let procHash = lineage.procedureHash {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Procedure Hash")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                    Text(procHash)
                        .font(.system(.caption, design: .monospaced))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Lineage Hash")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
                Text(lineage.deterministicHash)
                    .font(.system(.caption, design: .monospaced))
            }
        } header: {
            Text("Hashes")
        } footer: {
            Text("Deterministic hashes computed from metadata only")
        }
    }
    
    // MARK: - Metadata Section
    
    private var metadataSection: some View {
        Section {
            DetailRow(label: "Event ID", value: event.id.uuidString.prefix(8) + "...", icon: "number.square")
            DetailRow(label: "Schema Version", value: "v\(event.schemaVersion)", icon: "doc.badge.gearshape")
        } header: {
            Text("Metadata")
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Zero-Content Guarantee")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("This event contains only hashes, enum values, counts, and day-rounded timestamps. No user text, drafts, emails, or personal data is stored or displayed.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Init
    
    public init(event: AuditVaultEvent) {
        self.event = event
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(OKColor.riskExtreme)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AuditVaultEventDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AuditVaultEventDetailView(
                event: AuditVaultEvent(
                    sequenceNumber: 1,
                    kind: .lineageCreated,
                    lineage: SyntheticAuditVaultLineage.generate(index: 0)
                )
            )
        }
    }
}
#endif
