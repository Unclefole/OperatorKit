import SwiftUI

// ============================================================================
// OFFLINE CERTIFICATION VIEW (Phase 13I)
//
// Read-only UI for offline certification verification.
// User explicitly taps to verify - never automatic.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No toggles
// ❌ No "Run automatically"
// ❌ No auto-export
// ❌ No behavior changes
// ✅ Read-only display
// ✅ User-initiated verification only
// ✅ Feature-flagged
// ============================================================================

public struct OfflineCertificationView: View {
    
    // MARK: - State
    
    @State private var report: OfflineCertificationReport? = nil
    @State private var isVerifying = false
    @State private var showingExportSheet = false
    @State private var exportPacket: OfflineCertificationPacket? = nil
    
    // MARK: - Body
    
    public var body: some View {
        if OfflineCertificationFeatureFlag.isEnabled {
            certificationContent
        } else {
            featureDisabledView
        }
    }
    
    // MARK: - Certification Content
    
    private var certificationContent: some View {
        List {
            headerSection
            
            if let report = report {
                statusSection(report)
                categorySummarySection(report)
                checkResultsSection(report)
                exportSection(report)
            } else if isVerifying {
                loadingSection
            } else {
                verifySection
            }
            
            footerSection
        }
        .navigationTitle("Offline Certification")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExportSheet) {
            if let packet = exportPacket {
                OfflineCertificationExportSheet(packet: packet)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "airplane")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    Text("Offline Certification")
                        .font(.headline)
                }
                
                Text("Certifies that the Intent → Draft pipeline operates fully offline with zero network activity. This is verification, not enforcement.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Verify Section
    
    private var verifySection: some View {
        Section {
            Button(action: { runVerification() }) {
                Label("Verify Offline Status", systemImage: "checkmark.seal")
            }
        } footer: {
            Text("Tap to run certification checks. This is user-initiated only, never automatic.")
        }
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        Section {
            HStack {
                ProgressView()
                    .padding(.trailing, 8)
                
                Text("Verifying offline status...")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Status Section
    
    private func statusSection(_ report: OfflineCertificationReport) -> some View {
        Section {
            HStack {
                Image(systemName: report.status.icon)
                    .font(.title)
                    .foregroundColor(colorForStatus(report.status))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.status.displayName)
                        .font(.headline)
                    
                    Text("\(report.passedCount)/\(report.ruleCount) checks passed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            HStack {
                Text("Timestamp")
                Spacer()
                Text(report.timestamp)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
        } header: {
            Text("Certification Status")
        }
    }
    
    // MARK: - Category Summary Section
    
    private func categorySummarySection(_ report: OfflineCertificationReport) -> some View {
        Section {
            ForEach(OfflineCertificationCategory.allCases, id: \.self) { category in
                let results = report.checkResults.filter { $0.category == category.rawValue }
                let passed = results.filter { $0.passed }.count
                let total = results.count
                
                if total > 0 {
                    HStack {
                        Text(category.displayName)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(passed)/\(total)")
                            .font(.subheadline)
                            .foregroundColor(passed == total ? .green : .orange)
                    }
                }
            }
        } header: {
            Text("By Category")
        }
    }
    
    // MARK: - Check Results Section
    
    private func checkResultsSection(_ report: OfflineCertificationReport) -> some View {
        Section {
            ForEach(report.checkResults, id: \.checkId) { result in
                HStack {
                    Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.passed ? .green : .red)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.checkName)
                            .font(.subheadline)
                        
                        Text(result.checkId)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if result.severity == "critical" {
                        Text("Critical")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
        } header: {
            Text("All Checks (\(report.ruleCount))")
        }
    }
    
    // MARK: - Export Section
    
    private func exportSection(_ report: OfflineCertificationReport) -> some View {
        Section {
            Button(action: { prepareExport(report) }) {
                Label("Export Certification", systemImage: "square.and.arrow.up")
            }
            
            Button(action: { runVerification() }) {
                Label("Re-verify", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Actions")
        } footer: {
            Text("Export produces metadata-only JSON. No user content is included.")
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Certification, Not Enforcement")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("This feature certifies offline capability. It does not enforce or modify behavior. The app's core pipeline is designed to work offline by default.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Feature Disabled View
    
    private var featureDisabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("Offline Certification")
                .font(.headline)
            
            Text("This feature is not enabled.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func runVerification() {
        isVerifying = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let newReport = OfflineCertificationRunner.shared.runAllChecks()
            
            DispatchQueue.main.async {
                self.report = newReport
                self.isVerifying = false
            }
        }
    }
    
    private func prepareExport(_ report: OfflineCertificationReport) {
        exportPacket = OfflineCertificationPacket(from: report)
        showingExportSheet = true
    }
    
    private func colorForStatus(_ status: OfflineCertificationStatus) -> Color {
        switch status {
        case .certified: return .green
        case .partiallyVerified: return .orange
        case .failed: return .red
        case .disabled: return .gray
        }
    }
    
    // MARK: - Init
    
    public init() {}
}

// MARK: - Export Sheet

private struct OfflineCertificationExportSheet: View {
    let packet: OfflineCertificationPacket
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    DetailRow(label: "Status", value: packet.overallStatus)
                    DetailRow(label: "Rules", value: "\(packet.passedCount)/\(packet.ruleCount) passed")
                    DetailRow(label: "App Version", value: packet.appVersion)
                    DetailRow(label: "Date", value: packet.createdAtDayRounded)
                } header: {
                    Text("Export Summary")
                }
                
                Section {
                    ForEach(packet.categoryResults, id: \.category) { result in
                        HStack {
                            Text(result.category.replacingOccurrences(of: "_", with: " ").capitalized)
                            Spacer()
                            Text("\(result.passed)/\(result.total)")
                                .foregroundColor(result.allPassed ? .green : .orange)
                        }
                        .font(.subheadline)
                    }
                } header: {
                    Text("By Category")
                }
                
                Section {
                    Text("This export contains metadata only. No user content, no identifiers, no paths.")
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
                        preview: SharePreview("Offline Certification", image: Image(systemName: "airplane"))
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
struct OfflineCertificationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OfflineCertificationView()
        }
    }
}
#endif
