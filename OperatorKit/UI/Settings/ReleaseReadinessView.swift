import SwiftUI

// ============================================================================
// RELEASE READINESS VIEW (Phase 8C, extended Phase 9C)
//
// Read-only dashboard showing release readiness status.
// This view is ADVISORY ONLY - it does NOT block any user actions.
//
// Phase 9C additions:
// - Integrity status indicators (read-only)
// - No warnings, alerts, or call-to-action for integrity
//
// Accessible from: Quality & Trust → "Release Readiness"
//
// See: docs/SAFETY_CONTRACT.md, docs/RELEASE_APPROVAL.md
// ============================================================================

struct ReleaseReadinessView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var safetyContractStatus: SafetyContractStatus?
    @State private var qualityGateResult: QualityGateResult?
    @State private var driftSummary: DriftSummary?
    @State private var isLoading = true
    
    // Phase 9C: Integrity status (read-only indicator)
    @State private var integrityStatus: IntegrityStatus = .unavailable
    @State private var currentPacket: ExportQualityPacket?
    
    @State private var showExportOptions = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    
    @StateObject private var acknowledgementStore = ReleaseAcknowledgementStore.shared
    @State private var showAcknowledgementConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                // Overview Section
                overviewSection
                
                // Integrity Status Section (Phase 9C)
                integrityStatusSection
                
                // Release Acknowledgement Section (Phase 9B)
                releaseAcknowledgementSection
                
                // Safety Contract Section
                safetyContractSection
                
                // Quality Gate Section
                qualityGateSection
                
                // Golden Cases Section
                goldenCasesSection
                
                // Latest Eval Section
                latestEvalSection
                
                // Release Comparison Section (Phase 9A)
                releaseComparisonSection
                
                // Export Section
                exportSection
            }
            .navigationTitle("Release Readiness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadData()
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        isLoading = true
        
        // Load safety contract status
        safetyContractStatus = SafetyContractSnapshot.getStatus()
        
        // Evaluate quality gate
        qualityGateResult = QualityGateEvaluator().evaluate()
        
        // Compute drift summary
        driftSummary = DriftSummaryComputer().computeSummary()
        
        // Create quality packet and verify integrity (Phase 9C)
        let exporter = QualityPacketExporter()
        let packet = exporter.createPacket()
        currentPacket = packet
        
        // Verify integrity (read-only, no side effects)
        let verifier = IntegrityVerifier()
        integrityStatus = verifier.verify(packet: packet)
        
        isLoading = false
    }
    
    // MARK: - Integrity Status Section (Phase 9C)
    
    /// Read-only integrity status indicator
    /// ❌ No warnings
    /// ❌ No alerts
    /// ❌ No call-to-action
    private var integrityStatusSection: some View {
        Section("Integrity") {
            HStack {
                Image(systemName: integrityStatus.systemImage)
                    .foregroundColor(integrityStatusColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(integrityStatus.displayText)
                        .font(.subheadline)
                    Text("Quality record integrity check")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Show seal details if available
            if let seal = currentPacket?.integritySeal, seal.isAvailable {
                HStack {
                    Text("Algorithm")
                        .font(.caption)
                    Spacer()
                    Text(seal.algorithm.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Sections")
                        .font(.caption)
                    Spacer()
                    Text("\(seal.inputsHashed.count) included")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Integrity checks are informational only and do not affect app behavior.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var integrityStatusColor: Color {
        switch integrityStatus {
        case .valid: return .green
        case .mismatch: return .orange
        case .unavailable: return .gray
        }
    }
    
    // MARK: - Release Acknowledgement Section (Phase 9B)
    
    private var releaseAcknowledgementSection: some View {
        Section("Release Acknowledgement") {
            // Current version acknowledgement status
            if acknowledgementStore.isCurrentVersionAcknowledged {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Acknowledged")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let ack = acknowledgementStore.latestAcknowledgement {
                            Text("on \(ack.acknowledgedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
            } else {
                HStack {
                    Image(systemName: "seal")
                        .foregroundColor(.orange)
                    Text("Not acknowledged")
                        .font(.subheadline)
                    Spacer()
                }
            }
            
            // Last acknowledgement details
            if let lastAck = acknowledgementStore.latestAcknowledgement {
                DisclosureGroup("Last Acknowledgement") {
                    lastAcknowledgementDetails(lastAck)
                }
            }
            
            // Record acknowledgement button
            Button {
                showAcknowledgementConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "checkmark.seal")
                    Text("Record Acknowledgement")
                }
            }
            .disabled(!acknowledgementStore.canRecordAcknowledgement)
            
            if let reason = acknowledgementStore.recordingBlockedReason {
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("This acknowledgement is a process record only. It does not affect app behavior or block releases.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .alert("Record Release Acknowledgement?", isPresented: $showAcknowledgementConfirmation) {
            Button("Record", role: .none) {
                _ = acknowledgementStore.recordAcknowledgement()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This records that you have reviewed the Safety Contract and Quality Gate status for this version. This is a process record only.")
        }
    }
    
    private func lastAcknowledgementDetails(_ ack: ReleaseAcknowledgement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Version")
                    .font(.caption)
                Spacer()
                Text("v\(ack.appVersion) (\(ack.buildNumber))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Quality Gate")
                    .font(.caption)
                Spacer()
                Text(ack.qualityGateStatus)
                    .font(.caption)
                    .foregroundColor(gateStatusColor(ack.qualityGateStatus))
            }
            
            HStack {
                Text("Golden Cases")
                    .font(.caption)
                Spacer()
                Text("\(ack.goldenCaseCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let passRate = ack.latestEvalPassRate {
                HStack {
                    Text("Pass Rate")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.0f%%", passRate * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("Preflight")
                    .font(.caption)
                Spacer()
                Text(ack.preflightPassed ? "Passed" : "Had Issues")
                    .font(.caption)
                    .foregroundColor(ack.preflightPassed ? .green : .orange)
            }
        }
    }
    
    private func gateStatusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "PASS": return .green
        case "WARN", "SKIPPED": return .orange
        case "FAIL": return .red
        default: return .secondary
        }
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        Section("Overview") {
            if isLoading {
                ProgressView("Loading...")
            } else {
                // Overall readiness badge
                HStack {
                    Image(systemName: overallReadinessIcon)
                        .font(.title2)
                        .foregroundColor(overallReadinessColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Release Status")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(overallReadinessText)
                            .font(.headline)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
                
                // App version
                HStack {
                    Text("App Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                        .foregroundColor(.secondary)
                }
                
                // Build
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var overallReadinessIcon: String {
        guard let gateResult = qualityGateResult,
              let safetyStatus = safetyContractStatus else {
            return "questionmark.circle"
        }
        
        if !safetyStatus.isValid {
            return "xmark.shield.fill"
        }
        
        switch gateResult.status {
        case .pass: return "checkmark.seal.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.seal.fill"
        case .skipped: return "minus.circle.fill"
        }
    }
    
    private var overallReadinessColor: Color {
        guard let gateResult = qualityGateResult,
              let safetyStatus = safetyContractStatus else {
            return .gray
        }
        
        if !safetyStatus.isValid {
            return .red
        }
        
        switch gateResult.status {
        case .pass: return .green
        case .warn: return .orange
        case .fail: return .red
        case .skipped: return .gray
        }
    }
    
    private var overallReadinessText: String {
        guard let gateResult = qualityGateResult,
              let safetyStatus = safetyContractStatus else {
            return "Loading..."
        }
        
        if !safetyStatus.isValid {
            return "Safety Contract Modified"
        }
        
        switch gateResult.status {
        case .pass: return "Ready for Release"
        case .warn: return "Review Warnings"
        case .fail: return "Issues Detected"
        case .skipped: return "Insufficient Data"
        }
    }
    
    // MARK: - Safety Contract Section
    
    private var safetyContractSection: some View {
        Section("Safety Contract") {
            if let status = safetyContractStatus {
                HStack {
                    Image(systemName: status.matchStatus.systemImage)
                        .foregroundColor(status.isValid ? .green : .red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.matchStatus.displayName)
                            .font(.subheadline)
                        Text("SAFETY_CONTRACT.md")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if status.isValid {
                        Text("✓")
                            .foregroundColor(.green)
                    } else {
                        Text("Modified")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                if !status.isValid {
                    Text("The safety contract has been modified. If this is intentional, update the expected hash.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                HStack {
                    Text("Last Update")
                    Spacer()
                    Text(SafetyContractSnapshot.lastUpdateReason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            } else {
                ProgressView()
            }
        }
    }
    
    // MARK: - Quality Gate Section
    
    private var qualityGateSection: some View {
        Section("Quality Gate") {
            if let result = qualityGateResult {
                HStack {
                    Image(systemName: result.status.systemImage)
                        .foregroundColor(gateStatusColor(result.status))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Status: \(result.status.displayName)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(result.summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Reasons
                if !result.reasons.isEmpty {
                    ForEach(result.reasons, id: \.self) { reason in
                        HStack(alignment: .top) {
                            Image(systemName: result.status == .pass ? "checkmark" : "exclamationmark.circle")
                                .font(.caption)
                                .foregroundColor(result.status == .pass ? .green : .orange)
                                .frame(width: 16)
                            
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
    }
    
    private func gateStatusColor(_ status: GateStatus) -> Color {
        switch status {
        case .pass: return .green
        case .warn: return .orange
        case .fail: return .red
        case .skipped: return .gray
        }
    }
    
    // MARK: - Golden Cases Section
    
    private var goldenCasesSection: some View {
        Section("Golden Cases") {
            if let result = qualityGateResult {
                HStack {
                    Text("Pinned Cases")
                    Spacer()
                    Text("\(result.metrics.goldenCaseCount)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Minimum Required")
                    Spacer()
                    Text("\(result.thresholds.minimumGoldenCases)")
                        .foregroundColor(.secondary)
                }
                
                if result.metrics.goldenCaseCount < result.thresholds.minimumGoldenCases {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.orange)
                        Text("Pin more memory items as golden cases to enable quality gate.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Latest Eval Section
    
    private var latestEvalSection: some View {
        Section("Latest Evaluation") {
            if let result = qualityGateResult {
                HStack {
                    Text("Total Runs")
                    Spacer()
                    Text("\(result.metrics.totalEvalRuns)")
                        .foregroundColor(.secondary)
                }
                
                if let passRate = result.metrics.latestPassRate {
                    HStack {
                        Text("Latest Pass Rate")
                        Spacer()
                        Text("\(Int(passRate * 100))%")
                            .foregroundColor(passRate >= 0.8 ? .green : .orange)
                    }
                }
                
                if let driftLevel = result.metrics.driftLevel {
                    HStack {
                        Text("Drift Level")
                        Spacer()
                        Text(driftLevel)
                            .foregroundColor(driftLevelColor(driftLevel))
                    }
                }
                
                if let daysSince = result.metrics.daysSinceLastEval {
                    HStack {
                        Text("Days Since Last Eval")
                        Spacer()
                        Text("\(daysSince)")
                            .foregroundColor(daysSince > 7 ? .orange : .secondary)
                    }
                }
                
                if result.metrics.totalEvalRuns == 0 {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Run golden case evaluations from Quality & Trust to generate data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func driftLevelColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "none": return .green
        case "low": return .yellow
        case "moderate": return .orange
        case "high": return .red
        default: return .secondary
        }
    }
    
    // MARK: - Release Comparison Section (Phase 9A)
    
    private var releaseComparisonSection: some View {
        Section("Channel Comparison") {
            let comparison = ReleaseComparisonComputer().compareDebugVsTestFlight()
            
            // Check if we have data
            if comparison.channelA.runCount == 0 && comparison.channelB.runCount == 0 {
                HStack {
                    Image(systemName: "square.split.2x1")
                        .foregroundColor(.secondary)
                    Text("Run evals in Debug and TestFlight to compare")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // Verdict
                HStack {
                    Image(systemName: comparison.verdict.systemImage)
                        .foregroundColor(verdictColor(comparison.verdict))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Comparison")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(comparison.verdict.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Spacer()
                }
                
                // Channel summaries
                HStack {
                    channelBadge(name: "Debug", runs: comparison.channelA.runCount)
                    Spacer()
                    Text("vs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    channelBadge(name: "TestFlight", runs: comparison.channelB.runCount)
                }
                
                // Metric comparisons
                ForEach(comparison.metricComparisons) { metric in
                    HStack {
                        Image(systemName: metric.status.systemImage)
                            .foregroundColor(metricStatusColor(metric.status))
                            .frame(width: 16)
                        Text(metric.metricName)
                            .font(.caption)
                        Spacer()
                        Text(metric.channelAValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("→")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(metric.channelBValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Signature diffs
                if !comparison.signatureDiffs.isEmpty {
                    DisclosureGroup("Configuration Changes") {
                        ForEach(comparison.signatureDiffs.indices, id: \.self) { index in
                            Text(comparison.signatureDiffs[index].description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func channelBadge(name: String, runs: Int) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
            Text("\(runs) runs")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
    
    private func verdictColor(_ verdict: ComparisonVerdict) -> Color {
        switch verdict {
        case .channelABetter, .channelBBetter: return .green
        case .equivalent: return .blue
        case .inconclusive, .insufficientData: return .gray
        }
    }
    
    private func metricStatusColor(_ status: MetricComparison.ComparisonStatus) -> Color {
        switch status {
        case .better: return .green
        case .same: return .blue
        case .worse: return .red
        case .inconclusive: return .gray
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section("Export") {
            Button {
                exportEvalSummary()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Eval Summary JSON")
                }
            }
            
            Button {
                exportSafetySnapshot()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Safety Snapshot JSON")
                }
            }
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Exports contain metadata only, no user content.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Export Actions
    
    private func exportEvalSummary() {
        guard let result = qualityGateResult else { return }
        
        do {
            let data = try result.toJSON()
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("operatorkit-eval-summary-\(dateStamp()).json")
            try data.write(to: tempURL)
            exportURL = tempURL
            showExportSheet = true
        } catch {
            errorMessage = "Failed to export: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func exportSafetySnapshot() {
        do {
            let export = SafetyContractExport()
            let data = try export.toJSON()
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("operatorkit-safety-snapshot-\(dateStamp()).json")
            try data.write(to: tempURL)
            exportURL = tempURL
            showExportSheet = true
        } catch {
            errorMessage = "Failed to export: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

#Preview {
    ReleaseReadinessView()
}
