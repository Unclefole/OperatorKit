import SwiftUI

// ============================================================================
// QUALITY REPORT VIEW (Phase 8B)
//
// User-facing view for viewing eval runs and drift summary.
// INVARIANT: Read-only display of local data
// INVARIANT: No network transmission
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

struct QualityReportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var evalRunner = LocalEvalRunner.shared
    
    @State private var selectedRun: EvalRun?
    @State private var showDeleteAllConfirmation = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var driftSummary: DriftSummary {
        DriftSummaryComputer(evalRunner: evalRunner).computeSummary()
    }
    
    var body: some View {
        NavigationView {
            List {
                // Drift Summary Section
                driftSummarySection
                
                // Run History Section
                if !evalRunner.runs.isEmpty {
                    runHistorySection
                    
                    // Failure Breakdown Section
                    if driftSummary.failCount > 0 {
                        failureBreakdownSection
                    }
                }
                
                // Data Control Section
                dataControlSection
            }
            .scrollContentBackground(.hidden)
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Quality Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedRun) { run in
                EvalRunDetailView(run: run)
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Delete All Runs?", isPresented: $showDeleteAllConfirmation) {
                Button("Delete", role: .destructive) {
                    evalRunner.deleteAllRuns()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all \(evalRunner.runs.count) eval runs. This cannot be undone.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Drift Summary Section
    
    private var driftSummarySection: some View {
        Section("Drift Summary") {
            if evalRunner.runs.isEmpty {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundColor(OKColor.textSecondary)
                    Text("No eval runs yet")
                        .foregroundColor(OKColor.textSecondary)
                }
            } else {
                // Drift Level Badge
                HStack {
                    Image(systemName: driftSummary.driftLevel.systemImage)
                        .foregroundColor(driftLevelColor)
                    Text("Drift Level: \(driftSummary.driftLevel.rawValue)")
                        .fontWeight(.medium)
                    Spacer()
                }
                
                // Stats
                HStack {
                    Text("Total Runs")
                    Spacer()
                    Text("\(driftSummary.totalRuns)")
                        .foregroundColor(OKColor.textSecondary)
                }
                
                HStack {
                    Text("Total Cases Evaluated")
                    Spacer()
                    Text("\(driftSummary.totalCases)")
                        .foregroundColor(OKColor.textSecondary)
                }
                
                HStack {
                    Text("Pass Rate")
                    Spacer()
                    Text(String(format: "%.0f%%", driftSummary.passRate * 100))
                        .foregroundColor(driftSummary.passRate >= 0.8 ? OKColor.riskNominal : OKColor.riskWarning)
                }
                
                if let latestDate = driftSummary.latestRunDate {
                    HStack {
                        Text("Latest Run")
                        Spacer()
                        Text(latestDate.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(OKColor.textSecondary)
                    }
                }
            }
        }
    }
    
    private var driftLevelColor: Color {
        switch driftSummary.driftLevel {
        case .none: return OKColor.riskNominal
        case .low: return OKColor.riskWarning
        case .moderate: return OKColor.riskWarning
        case .high: return OKColor.riskCritical
        }
    }
    
    // MARK: - Run History Section
    
    private var runHistorySection: some View {
        Section("Run History") {
            ForEach(evalRunner.runs.sorted(by: { $0.startedAt > $1.startedAt })) { run in
                Button {
                    selectedRun = run
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(run.runType.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                            
                            Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Pass/Fail badge
                        HStack(spacing: 4) {
                            Text("\(run.passCount)/\(run.results.count)")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Image(systemName: run.passCount == run.results.count ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(run.passCount == run.results.count ? OKColor.riskNominal : OKColor.riskWarning)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                }
            }
            .onDelete { indexSet in
                let sortedRuns = evalRunner.runs.sorted(by: { $0.startedAt > $1.startedAt })
                for index in indexSet {
                    _ = evalRunner.deleteRun(id: sortedRuns[index].id)
                }
            }
        }
    }
    
    // MARK: - Failure Breakdown Section
    
    private var failureBreakdownSection: some View {
        Section("Failure Breakdown") {
            ForEach(DriftSummary.FailureCategory.allCases, id: \.self) { category in
                let count = driftSummary.failuresByCategory[category] ?? 0
                if count > 0 {
                    HStack {
                        Image(systemName: category.systemImage)
                            .foregroundColor(OKColor.riskWarning)
                            .frame(width: 24)
                        Text(category.rawValue)
                        Spacer()
                        Text("\(count)")
                            .foregroundColor(OKColor.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Data Control Section
    
    private var dataControlSection: some View {
        Section("Your Data") {
            Button {
                exportRuns()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Runs as JSON")
                }
            }
            .disabled(evalRunner.runs.isEmpty)
            
            Button(role: .destructive) {
                showDeleteAllConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete All Runs")
                }
            }
            .disabled(evalRunner.runs.isEmpty)
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(OKColor.textSecondary)
                Text("Eval runs contain metadata only, never your actual content.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
    }
    
    // MARK: - Export
    
    private func exportRuns() {
        do {
            let url = try evalRunner.exportToFile()
            exportURL = url
            showExportSheet = true
        } catch {
            errorMessage = "Failed to export: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Eval Run Detail View

struct EvalRunDetailView: View {
    let run: EvalRun
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Run Info Section
                Section("Run Info") {
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(run.runType.displayName)
                            .foregroundColor(OKColor.textSecondary)
                    }
                    
                    HStack {
                        Text("Started")
                        Spacer()
                        Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(OKColor.textSecondary)
                    }
                    
                    if let completed = run.completedAt {
                        HStack {
                            Text("Completed")
                            Spacer()
                            Text(completed.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(OKColor.textSecondary)
                        }
                    }
                    
                    HStack {
                        Text("Pass Rate")
                        Spacer()
                        Text(String(format: "%.0f%% (%d/%d)", run.passRate * 100, run.passCount, run.results.count))
                            .foregroundColor(run.passRate >= 0.8 ? OKColor.riskNominal : OKColor.riskWarning)
                    }
                }
                
                // Results Section
                Section("Case Results") {
                    ForEach(run.results) { result in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: result.pass ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.pass ? OKColor.riskNominal : OKColor.riskCritical)
                                
                                Text(result.pass ? "Pass" : "Fail")
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text("Case \(result.goldenCaseId.uuidString.prefix(8))...")
                                    .font(.caption)
                                    .foregroundColor(OKColor.textSecondary)
                            }
                            
                            // Failure reasons
                            if !result.failureReasons.isEmpty {
                                ForEach(result.failureReasons, id: \.self) { reason in
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.caption)
                                            .foregroundColor(OKColor.riskWarning)
                                        Text(reason.displayName)
                                            .font(.caption)
                                            .foregroundColor(OKColor.textSecondary)
                                    }
                                }
                            }
                            
                            // Notes
                            if !result.notes.isEmpty {
                                ForEach(result.notes, id: \.self) { note in
                                    Text(note)
                                        .font(.caption)
                                        .foregroundColor(OKColor.textSecondary)
                                        .padding(.leading, 20)
                                }
                            }
                            
                            // Metrics
                            HStack(spacing: 12) {
                                metricBadge("Backend", result.metrics.backendUsed.components(separatedBy: "Model").first ?? "?")
                                
                                if result.metrics.usedFallback {
                                    metricBadge("Fallback", "Yes", color: OKColor.riskWarning)
                                }
                                
                                if result.metrics.timeoutOccurred {
                                    metricBadge("Timeout", "Yes", color: OKColor.riskCritical)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Run Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func metricBadge(_ label: String, _ value: String, color: Color = OKColor.actionPrimary) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(OKColor.textSecondary)
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

// EvalRun already conforms to Identifiable

#Preview {
    QualityReportView()
}
