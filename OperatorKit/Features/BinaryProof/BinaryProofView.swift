import SwiftUI

// ============================================================================
// BINARY PROOF VIEW (Phase 13G)
//
// Read-only view displaying binary inspection results.
// Shows linked frameworks and sensitive framework checks.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No toggles that alter behavior
// ❌ No "repair" or "fix" actions
// ❌ No auto-export (user-initiated only)
// ❌ No user content
// ✅ Read-only inspection display
// ✅ Feature-flagged
// ✅ Export via ShareSheet only
// ============================================================================

public struct BinaryProofView: View {
    
    // MARK: - State
    
    @State private var inspectionResult: BinaryInspectionResult? = nil
    @State private var isInspecting = false
    @State private var showingExportSheet = false
    @State private var exportPacket: BinaryProofPacket? = nil
    @State private var showFrameworks = false
    
    // MARK: - Body
    
    public var body: some View {
        if BinaryProofFeatureFlag.isEnabled {
            proofContent
                .onAppear { runInspection() }
        } else {
            featureDisabledView
        }
    }
    
    // MARK: - Proof Content
    
    private var proofContent: some View {
        List {
            headerSection
            
            if let result = inspectionResult {
                statusSection(result)
                sensitiveChecksSection(result)
                frameworksSection(result)
                exportSection(result)
            } else if isInspecting {
                loadingSection
            }
            
            footerSection
        }
        .navigationTitle("Binary Proof")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExportSheet) {
            if let packet = exportPacket {
                BinaryProofExportSheet(packet: packet)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "cpu")
                        .font(.title)
                        .foregroundColor(.purple)
                    
                    Text("Binary Proof")
                        .font(.headline)
                }
                
                Text("Inspects linked frameworks in the app binary using dyld APIs. Verifies absence of WebKit/JavaScriptCore at the Mach-O level.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Status Section
    
    private func statusSection(_ result: BinaryInspectionResult) -> some View {
        Section {
            HStack {
                Image(systemName: result.status.icon)
                    .font(.title)
                    .foregroundColor(colorForStatus(result.status))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.status.displayName)
                        .font(.headline)
                    
                    Text("\(result.linkedFrameworks.count) frameworks linked")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            ForEach(result.notes, id: \.self) { note in
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Inspection Status")
        }
    }
    
    // MARK: - Sensitive Checks Section
    
    private func sensitiveChecksSection(_ result: BinaryInspectionResult) -> some View {
        Section {
            ForEach(result.sensitiveChecks, id: \.framework) { check in
                HStack {
                    Image(systemName: check.isPresent ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(check.isPresent ? .red : .green)
                        .frame(width: 24)
                    
                    Text(check.framework)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(check.statusText)
                        .font(.caption)
                        .foregroundColor(check.isPresent ? .red : .green)
                }
            }
        } header: {
            Label("SENSITIVE FRAMEWORK CHECKS", systemImage: "shield.lefthalf.filled")
        } footer: {
            Text("Verifies absence of web-related frameworks that could enable JavaScript execution.")
        }
    }
    
    // MARK: - Frameworks Section
    
    private func frameworksSection(_ result: BinaryInspectionResult) -> some View {
        Section {
            DisclosureGroup(
                isExpanded: $showFrameworks,
                content: {
                    ForEach(result.linkedFrameworks, id: \.self) { framework in
                        HStack {
                            Image(systemName: "shippingbox")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            Text(framework)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                },
                label: {
                    HStack {
                        Text("Linked Frameworks")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(result.linkedFrameworks.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            )
        } header: {
            Text("All Frameworks")
        } footer: {
            Text("Sanitized framework identifiers only. No full filesystem paths are displayed.")
        }
    }
    
    // MARK: - Export Section
    
    private func exportSection(_ result: BinaryInspectionResult) -> some View {
        Section {
            Button(action: { prepareExport(result) }) {
                Label("Export Proof Packet", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("Export")
        } footer: {
            Text("Exports metadata-only JSON. No user content, no full paths.")
        }
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        Section {
            HStack {
                ProgressView()
                    .padding(.trailing, 8)
                
                Text("Inspecting binary...")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verification Method")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Uses public dyld APIs (_dyld_image_count, _dyld_get_image_name) to enumerate loaded Mach-O images. Results are deterministic for a given build.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("This is a read-only inspection. No behavior changes, no repairs, no monitoring.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Feature Disabled View
    
    private var featureDisabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("Binary Proof")
                .font(.headline)
            
            Text("This feature is not enabled.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func runInspection() {
        isInspecting = true
        
        // Run on background queue for responsiveness
        DispatchQueue.global(qos: .userInitiated).async {
            let result = BinaryImageInspector.inspect()
            
            DispatchQueue.main.async {
                self.inspectionResult = result
                self.isInspecting = false
            }
        }
    }
    
    private func prepareExport(_ result: BinaryInspectionResult) {
        exportPacket = BinaryProofPacket(from: result)
        showingExportSheet = true
    }
    
    private func colorForStatus(_ status: BinaryProofStatus) -> Color {
        switch status {
        case .pass: return .green
        case .warn: return .orange
        case .fail: return .red
        case .disabled: return .gray
        }
    }
    
    // MARK: - Init
    
    public init() {}
}

// MARK: - Export Sheet

private struct BinaryProofExportSheet: View {
    let packet: BinaryProofPacket
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    DetailRow(label: "Status", value: packet.overallStatus.rawValue)
                    DetailRow(label: "Frameworks", value: "\(packet.frameworkCount)")
                    DetailRow(label: "App Version", value: packet.appVersion)
                    DetailRow(label: "Date", value: packet.createdAtDayRounded)
                } header: {
                    Text("Export Summary")
                }
                
                Section {
                    ForEach(packet.sensitiveFrameworkChecks, id: \.framework) { check in
                        HStack {
                            Text(check.framework)
                            Spacer()
                            Text(check.statusText)
                                .foregroundColor(check.isPresent ? .red : .green)
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("Sensitive Checks")
                }
                
                Section {
                    Text("This export contains metadata only. No user content, no full filesystem paths, no personal data.")
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
                        item: packet.toJSON() ?? "{}",
                        preview: SharePreview("Binary Proof", image: Image(systemName: "cpu"))
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
struct BinaryProofView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BinaryProofView()
        }
    }
}
#endif
