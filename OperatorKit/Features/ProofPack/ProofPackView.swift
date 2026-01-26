import SwiftUI

// ============================================================================
// PROOF PACK VIEW (Phase 13H)
//
// Read-only view for Proof Pack assembly and export.
// User-initiated export only via ShareSheet.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No auto-generation
// ❌ No auto-export
// ❌ No behavior changes
// ❌ No user content display
// ✅ Read-only summary
// ✅ User-initiated export only
// ✅ Feature-flagged
// ============================================================================

public struct ProofPackView: View {
    
    // MARK: - State
    
    @State private var proofPack: ProofPack? = nil
    @State private var isAssembling = false
    @State private var showingExportSheet = false
    
    // MARK: - Body
    
    public var body: some View {
        if ProofPackFeatureFlag.isEnabled {
            packContent
        } else {
            featureDisabledView
        }
    }
    
    // MARK: - Pack Content
    
    private var packContent: some View {
        List {
            headerSection
            
            if let pack = proofPack {
                sealsSummarySection(pack)
                securitySummarySection(pack)
                binarySummarySection(pack)
                firewallSummarySection(pack)
                auditSummarySection(pack)
                flagsSummarySection(pack)
                exportSection(pack)
            } else if isAssembling {
                loadingSection
            } else {
                assembleSection
            }
            
            footerSection
        }
        .navigationTitle("Proof Pack")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExportSheet) {
            if let pack = proofPack {
                ProofPackExportSheet(pack: pack)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "shippingbox.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    Text("Proof Pack")
                        .font(.headline)
                }
                
                Text("Unified trust evidence bundle. Contains metadata only — no user data, no drafts, no personal information.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Assemble Section
    
    private var assembleSection: some View {
        Section {
            Button(action: { assembleProofPack() }) {
                Label("Assemble Proof Pack", systemImage: "square.stack.3d.up")
            }
        } footer: {
            Text("Tap to collect trust evidence from all surfaces. No data is sent anywhere.")
        }
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        Section {
            HStack {
                ProgressView()
                    .padding(.trailing, 8)
                
                Text("Assembling proof pack...")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Seals Summary Section
    
    private func sealsSummarySection(_ pack: ProofPack) -> some View {
        Section {
            SummaryRow(label: "Terminology Canon", status: pack.releaseSeals.terminologyCanon)
            SummaryRow(label: "Claim Registry", status: pack.releaseSeals.claimRegistry)
            SummaryRow(label: "Safety Contract", status: pack.releaseSeals.safetyContract)
            SummaryRow(label: "Pricing Registry", status: pack.releaseSeals.pricingRegistry)
            SummaryRow(label: "Store Listing", status: pack.releaseSeals.storeListing)
        } header: {
            Label("Release Seals (\(pack.releaseSeals.passCount)/5)", systemImage: "seal.fill")
        }
    }
    
    // MARK: - Security Summary Section
    
    private func securitySummarySection(_ pack: ProofPack) -> some View {
        Section {
            BooleanRow(label: "WebKit", isPresent: pack.securityManifest.webkitPresent)
            BooleanRow(label: "JavaScript", isPresent: pack.securityManifest.javascriptPresent)
            BooleanRow(label: "Embedded Browser", isPresent: pack.securityManifest.embeddedBrowserPresent)
            BooleanRow(label: "Remote Code Exec", isPresent: pack.securityManifest.remoteCodeExecutionPresent)
        } header: {
            Label("Security Manifest", systemImage: "lock.shield")
        }
    }
    
    // MARK: - Binary Summary Section
    
    private func binarySummarySection(_ pack: ProofPack) -> some View {
        Section {
            HStack {
                Text("Status")
                Spacer()
                Text(pack.binaryProof.overallStatus)
                    .foregroundColor(pack.binaryProof.overallStatus == "PASS" ? .green : .orange)
            }
            
            HStack {
                Text("Framework Count")
                Spacer()
                Text("\(pack.binaryProof.frameworkCount)")
                    .foregroundColor(.secondary)
            }
        } header: {
            Label("Binary Proof", systemImage: "cpu")
        }
    }
    
    // MARK: - Firewall Summary Section
    
    private func firewallSummarySection(_ pack: ProofPack) -> some View {
        Section {
            HStack {
                Text("Status")
                Spacer()
                Text(pack.regressionFirewall.overallStatus)
                    .foregroundColor(pack.regressionFirewall.allPassed ? .green : .red)
            }
            
            HStack {
                Text("Rules")
                Spacer()
                Text("\(pack.regressionFirewall.passed)/\(pack.regressionFirewall.ruleCount) passed")
                    .foregroundColor(.secondary)
            }
        } header: {
            Label("Regression Firewall", systemImage: "flame.fill")
        }
    }
    
    // MARK: - Audit Summary Section
    
    private func auditSummarySection(_ pack: ProofPack) -> some View {
        Section {
            HStack {
                Text("Events")
                Spacer()
                Text("\(pack.auditVault.eventCount)/\(pack.auditVault.maxCapacity)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Edits Tracked")
                Spacer()
                Text("\(pack.auditVault.editCount)")
                    .foregroundColor(.secondary)
            }
        } header: {
            Label("Audit Vault", systemImage: "archivebox")
        }
    }
    
    // MARK: - Flags Summary Section
    
    private func flagsSummarySection(_ pack: ProofPack) -> some View {
        Section {
            FlagRow(label: "Trust Surfaces", enabled: pack.featureFlags.trustSurfaces)
            FlagRow(label: "Audit Vault", enabled: pack.featureFlags.auditVault)
            FlagRow(label: "Security Manifest", enabled: pack.featureFlags.securityManifest)
            FlagRow(label: "Binary Proof", enabled: pack.featureFlags.binaryProof)
            FlagRow(label: "Regression Firewall", enabled: pack.featureFlags.regressionFirewall)
        } header: {
            Label("Feature Flags", systemImage: "flag")
        }
    }
    
    // MARK: - Export Section
    
    private func exportSection(_ pack: ProofPack) -> some View {
        Section {
            Button(action: { showingExportSheet = true }) {
                Label("Export Proof Pack", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("Export")
        } footer: {
            Text("Exports metadata-only JSON via ShareSheet. No user content is included.")
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("This export contains NO user data")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("Proof Pack is a verification artifact for auditors and enterprises. It is not telemetry, monitoring, diagnostics, or analytics.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Feature Disabled View
    
    private var featureDisabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("Proof Pack")
                .font(.headline)
            
            Text("This feature is not enabled.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func assembleProofPack() {
        isAssembling = true
        
        Task { @MainActor in
            proofPack = ProofPackAssembler.assemble()
            isAssembling = false
        }
    }
    
    // MARK: - Init
    
    public init() {}
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let label: String
    let status: SealStatus
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Image(systemName: status == .pass ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(status == .pass ? .green : .red)
            
            Text(status.rawValue)
                .font(.caption)
                .foregroundColor(status == .pass ? .green : .red)
        }
    }
}

// MARK: - Boolean Row

private struct BooleanRow: View {
    let label: String
    let isPresent: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Image(systemName: isPresent ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(isPresent ? .red : .green)
            
            Text(isPresent ? "Present" : "Absent")
                .font(.caption)
                .foregroundColor(isPresent ? .red : .green)
        }
    }
}

// MARK: - Flag Row

private struct FlagRow: View {
    let label: String
    let enabled: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Text(enabled ? "Enabled" : "Disabled")
                .font(.caption)
                .foregroundColor(enabled ? .green : .secondary)
        }
    }
}

// MARK: - Export Sheet

private struct ProofPackExportSheet: View {
    let pack: ProofPack
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    DetailRow(label: "Schema Version", value: "\(pack.schemaVersion)")
                    DetailRow(label: "App Version", value: pack.appVersion)
                    DetailRow(label: "Build", value: pack.buildNumber)
                    DetailRow(label: "Date", value: pack.createdAtDayRounded)
                } header: {
                    Text("Export Summary")
                }
                
                Section {
                    DetailRow(label: "Release Seals", value: "\(pack.releaseSeals.passCount)/5 passed")
                    DetailRow(label: "Security Manifest", value: pack.securityManifest.allClear ? "Clear" : "Review")
                    DetailRow(label: "Binary Proof", value: pack.binaryProof.overallStatus)
                    DetailRow(label: "Firewall", value: "\(pack.regressionFirewall.passed)/\(pack.regressionFirewall.ruleCount)")
                } header: {
                    Text("Trust Summary")
                }
                
                Section {
                    Text("This export contains metadata only. No user content, no drafts, no personal data, no telemetry.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Export Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(
                        item: pack.toJSON() ?? "{}",
                        preview: SharePreview("Proof Pack", image: Image(systemName: "shippingbox"))
                    )
                }
            }
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProofPackView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProofPackView()
        }
    }
}
#endif
