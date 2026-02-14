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
            .scrollContentBackground(.hidden)
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Release Readiness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                        .foregroundColor(OKColor.textSecondary)
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
                        .foregroundColor(OKColor.textSecondary)
                }
                
                HStack {
                    Text("Sections")
                        .font(.caption)
                    Spacer()
                    Text("\(seal.inputsHashed.count) included")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
            
            Text("Integrity checks are informational only and do not affect app behavior.")
                .font(.caption2)
                .foregroundColor(OKColor.textSecondary)
        }
    }
    
    private var integrityStatusColor: Color {
        switch integrityStatus {
        case .valid: return OKColor.riskNominal
        case .mismatch: return OKColor.riskWarning
        case .unavailable: return OKColor.textMuted
        }
    }
    
    // MARK: - Release Acknowledgement Section (Phase 9B)
    
    private var releaseAcknowledgementSection: some View {
        Section("Release Acknowledgement") {
            // Current version acknowledgement status
            if acknowledgementStore.isCurrentVersionAcknowledged {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(OKColor.riskNominal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Acknowledged")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let ack = acknowledgementStore.latestAcknowledgement {
                            Text("on \(ack.acknowledgedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                    }
                    Spacer()
                }
            } else {
                HStack {
                    Image(systemName: "seal")
                        .foregroundColor(OKColor.riskWarning)
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
                    .foregroundColor(OKColor.textSecondary)
            }
            
            Text("This acknowledgement is a process record only. It does not affect app behavior or block releases.")
                .font(.caption2)
                .foregroundColor(OKColor.textSecondary)
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
                    .foregroundColor(OKColor.textSecondary)
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
                    .foregroundColor(OKColor.textSecondary)
            }
            
            if let passRate = ack.latestEvalPassRate {
                HStack {
                    Text("Pass Rate")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.0f%%", passRate * 100))
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
            
            HStack {
                Text("Preflight")
                    .font(.caption)
                Spacer()
                Text(ack.preflightPassed ? "Passed" : "Had Issues")
                    .font(.caption)
                    .foregroundColor(ack.preflightPassed ? OKColor.riskNominal : OKColor.riskWarning)
            }
        }
    }
    
    private func gateStatusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "PASS": return OKColor.riskNominal
        case "WARN", "SKIPPED": return OKColor.riskWarning
        case "FAIL": return OKColor.riskCritical
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
                            .foregroundColor(OKColor.textSecondary)
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
                        .foregroundColor(OKColor.textSecondary)
                }
                
                // Build
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                        .foregroundColor(OKColor.textSecondary)
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
            return OKColor.textMuted
        }
        
        if !safetyStatus.isValid {
            return OKColor.riskCritical
        }
        
        switch gateResult.status {
        case .pass: return OKColor.riskNominal
        case .warn: return OKColor.riskWarning
        case .fail: return OKColor.riskCritical
        case .skipped: return OKColor.textMuted
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
                        .foregroundColor(status.isValid ? OKColor.riskNominal : OKColor.riskCritical)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.matchStatus.displayName)
                            .font(.subheadline)
                        Text("SAFETY_CONTRACT.md")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                    
                    Spacer()
                    
                    if status.isValid {
                        Text("✓")
                            .foregroundColor(OKColor.riskNominal)
                    } else {
                        Text("Modified")
                            .font(.caption)
                            .foregroundColor(OKColor.riskCritical)
                    }
                }
                
                if !status.isValid {
                    Text("The safety contract has been modified. If this is intentional, update the expected hash.")
                        .font(.caption)
                        .foregroundColor(OKColor.riskWarning)
                }
                
                HStack {
                    Text("Last Update")
                    Spacer()
                    Text(SafetyContractSnapshot.lastUpdateReason)
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
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
                            .foregroundColor(OKColor.textSecondary)
                    }
                }
                
                // Reasons
                if !result.reasons.isEmpty {
                    ForEach(result.reasons, id: \.self) { reason in
                        HStack(alignment: .top) {
                            Image(systemName: result.status == .pass ? "checkmark" : "exclamationmark.circle")
                                .font(.caption)
                                .foregroundColor(result.status == .pass ? OKColor.riskNominal : OKColor.riskWarning)
                                .frame(width: 16)
                            
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
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
        case .pass: return OKColor.riskNominal
        case .warn: return OKColor.riskWarning
        case .fail: return OKColor.riskCritical
        case .skipped: return OKColor.textMuted
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
                        .foregroundColor(OKColor.textSecondary)
                }
                
                HStack {
                    Text("Minimum Required")
                    Spacer()
                    Text("\(result.thresholds.minimumGoldenCases)")
                        .foregroundColor(OKColor.textSecondary)
                }
                
                if result.metrics.goldenCaseCount < result.thresholds.minimumGoldenCases {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(OKColor.riskWarning)
                        Text("Pin more memory items as golden cases to enable quality gate.")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
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
                        .foregroundColor(OKColor.textSecondary)
                }
                
                if let passRate = result.metrics.latestPassRate {
                    HStack {
                        Text("Latest Pass Rate")
                        Spacer()
                        Text("\(Int(passRate * 100))%")
                            .foregroundColor(passRate >= 0.8 ? OKColor.riskNominal : OKColor.riskWarning)
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
                            .foregroundColor(daysSince > 7 ? OKColor.riskWarning : .secondary)
                    }
                }
                
                if result.metrics.totalEvalRuns == 0 {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(OKColor.actionPrimary)
                        Text("Run golden case evaluations from Quality & Trust to generate data.")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                }
            }
        }
    }
    
    private func driftLevelColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "none": return OKColor.riskNominal
        case "low": return OKColor.riskWarning
        case "moderate": return OKColor.riskWarning
        case "high": return OKColor.riskCritical
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
                        .foregroundColor(OKColor.textSecondary)
                    Text("Run evals in Debug and TestFlight to compare")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
            } else {
                // Verdict
                HStack {
                    Image(systemName: comparison.verdict.systemImage)
                        .foregroundColor(verdictColor(comparison.verdict))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Comparison")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
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
                        .foregroundColor(OKColor.textSecondary)
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
                            .foregroundColor(OKColor.textSecondary)
                        Text("→")
                            .font(.caption2)
                            .foregroundColor(OKColor.textSecondary)
                        Text(metric.channelBValue)
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                }
                
                // Signature diffs
                if !comparison.signatureDiffs.isEmpty {
                    DisclosureGroup("Configuration Changes") {
                        ForEach(comparison.signatureDiffs.indices, id: \.self) { index in
                            Text(comparison.signatureDiffs[index].description)
                                .font(.caption2)
                                .foregroundColor(OKColor.textSecondary)
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
                .foregroundColor(OKColor.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(OKColor.textMuted.opacity(0.1))
        .cornerRadius(6)
    }
    
    private func verdictColor(_ verdict: ComparisonVerdict) -> Color {
        switch verdict {
        case .channelABetter, .channelBBetter: return OKColor.riskNominal
        case .equivalent: return OKColor.actionPrimary
        case .inconclusive, .insufficientData: return OKColor.textMuted
        }
    }
    
    private func metricStatusColor(_ status: MetricComparison.ComparisonStatus) -> Color {
        switch status {
        case .better: return OKColor.riskNominal
        case .same: return OKColor.actionPrimary
        case .worse: return OKColor.riskCritical
        case .inconclusive: return OKColor.textMuted
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
                    .foregroundColor(OKColor.textSecondary)
                Text("Exports contain metadata only, no user content.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
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
            let export = SafetyContractSnapshotExport()
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
