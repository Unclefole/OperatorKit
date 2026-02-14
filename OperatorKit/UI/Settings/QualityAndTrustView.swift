import SwiftUI

// ============================================================================
// QUALITY & TRUST VIEW (Phase 8A)
//
// User-facing view for viewing, exporting, and deleting local feedback.
// INVARIANT: No network transmission
// INVARIANT: User controls all data (view, export, delete)
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

struct QualityAndTrustView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var feedbackStore = QualityFeedbackStore.shared
    @StateObject private var goldenCaseStore = GoldenCaseStore.shared
    @StateObject private var evalRunner = LocalEvalRunner.shared
    
    @State private var showDeleteAllConfirmation = false
    @State private var showDeleteAllGoldenCases = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showQualityReport = false
    @State private var showReleaseReadiness = false
    @State private var isRunningEval = false
    @State private var editingGoldenCase: GoldenCase?
    @State private var newTitle = ""
    
    private var calibrationComputer: QualityCalibrationComputer {
        QualityCalibrationComputer(feedbackStore: feedbackStore)
    }
    
    private var summary: CalibrationSummary {
        calibrationComputer.computeSummary()
    }
    
    private var recommendations: CalibrationRecommendations {
        CalibrationRecommendations.generate(from: summary)
    }
    
    var body: some View {
        NavigationView {
            List {
                // Explanation Section
                explanationSection
                
                // Golden Cases Section (Phase 8B)
                goldenCasesSection
                
                // Coverage Section (Phase 9A)
                if !goldenCaseStore.cases.isEmpty {
                    coverageSection
                }
                
                // Trend Section (Phase 9A)
                trendSection
                
                // Calibration Recommendations Section (Phase 9B)
                calibrationRecommendationsSection
                
                // Summary Section
                if feedbackStore.totalCount > 0 {
                    summarySection
                    
                    // Breakdown Section
                    breakdownSection
                    
                    // Recommendations Section
                    if summary.hasEnoughData {
                        recommendationsSection
                    }
                    
                    // Top Issues Section
                    if !summary.topIssueTags.isEmpty {
                        topIssuesSection
                    }
                }
                
                // Data Control Section
                dataControlSection
            }
            .scrollContentBackground(.hidden)
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Quality & Trust")
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
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showQualityReport) {
                QualityReportView()
            }
            .sheet(isPresented: $showReleaseReadiness) {
                ReleaseReadinessView()
            }
            .alert("Delete All Feedback?", isPresented: $showDeleteAllConfirmation) {
                Button("Delete", role: .destructive) {
                    feedbackStore.deleteAllFeedback()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all \(feedbackStore.totalCount) feedback entries. This cannot be undone.")
            }
            .alert("Delete All Golden Cases?", isPresented: $showDeleteAllGoldenCases) {
                Button("Delete", role: .destructive) {
                    goldenCaseStore.deleteAllCases()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all \(goldenCaseStore.totalCount) golden cases. This cannot be undone.")
            }
            .alert("Rename Golden Case", isPresented: .init(
                get: { editingGoldenCase != nil },
                set: { if !$0 { editingGoldenCase = nil } }
            )) {
                TextField("Title", text: $newTitle)
                Button("Save") {
                    if let goldenCase = editingGoldenCase {
                        _ = goldenCaseStore.renameCase(id: goldenCase.id, newTitle: newTitle)
                    }
                    editingGoldenCase = nil
                }
                Button("Cancel", role: .cancel) {
                    editingGoldenCase = nil
                }
            } message: {
                Text("Enter a new title for this golden case.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Golden Cases Section (Phase 8B)
    
    private var goldenCasesSection: some View {
        Section("Golden Cases") {
            if goldenCaseStore.cases.isEmpty {
                HStack {
                    Image(systemName: "pin.slash")
                        .foregroundColor(OKColor.textSecondary)
                    Text("No golden cases pinned yet")
                        .foregroundColor(OKColor.textSecondary)
                }
                
                Text("Pin memory items as golden cases from the Memory detail view to use for quality evaluation.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            } else {
                // List of golden cases
                ForEach(goldenCaseStore.cases) { goldenCase in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(goldenCase.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            
                            Text(goldenCase.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Rename button
                        Button {
                            newTitle = goldenCase.title
                            editingGoldenCase = goldenCase
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(OKColor.actionPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        _ = goldenCaseStore.deleteCase(id: goldenCaseStore.cases[index].id)
                    }
                }
                
                // Run eval button
                Button {
                    runGoldenCaseEval()
                } label: {
                    HStack {
                        if isRunningEval {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.circle")
                        }
                        Text("Run Golden Case Eval")
                    }
                }
                .disabled(isRunningEval || goldenCaseStore.cases.isEmpty)
                
                // View quality report
                Button {
                    showQualityReport = true
                } label: {
                    HStack {
                        Image(systemName: "chart.bar.doc.horizontal")
                        Text("View Quality Report")
                    }
                }
                
                // Release readiness (Phase 8C)
                Button {
                    showReleaseReadiness = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.seal")
                        Text("Release Readiness")
                    }
                }
                
                // Delete all golden cases
                Button(role: .destructive) {
                    showDeleteAllGoldenCases = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete All Golden Cases")
                    }
                }
            }
        }
    }
    
    private func runGoldenCaseEval() {
        isRunningEval = true
        
        Task {
            let run = await evalRunner.runGoldenCaseEval(
                goldenCases: goldenCaseStore.cases,
                memoryStore: MemoryStore.shared
            )
            
            // Update history store (Phase 9A)
            let driftSummary = DriftSummaryComputer(evalRunner: evalRunner).computeSummary()
            QualityHistoryStore.shared.appendSummary(from: run, driftSummary: driftSummary)
            
            await MainActor.run {
                isRunningEval = false
            }
        }
    }
    
    // MARK: - Coverage Section (Phase 9A)
    
    private var coverageSection: some View {
        Section("Coverage") {
            let coverage = GoldenCaseCoverageComputer(goldenCaseStore: goldenCaseStore).computeCoverage()
            
            // Overall score
            HStack {
                Image(systemName: coverageIcon(score: coverage.overallScore))
                    .foregroundColor(coverageColor(score: coverage.overallScore))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Coverage Score")
                        .font(.subheadline)
                    Text("\(coverage.overallScore)%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(coverageColor(score: coverage.overallScore))
                }
                
                Spacer()
            }
            
            // Dimension breakdown
            coverageDimensionRow(dimension: coverage.intentTypeCoverage)
            coverageDimensionRow(dimension: coverage.confidenceBandCoverage)
            coverageDimensionRow(dimension: coverage.backendTypeCoverage)
            
            // Missing coverage suggestions
            if !coverage.missingCoverage.isEmpty {
                DisclosureGroup("Suggestions (\(coverage.missingCoverage.count))") {
                    ForEach(coverage.missingCoverage) { suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: suggestionIcon(priority: suggestion.priority))
                                .foregroundColor(suggestionColor(priority: suggestion.priority))
                                .frame(width: 16)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.category)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(suggestion.suggestion)
                                    .font(.caption2)
                                    .foregroundColor(OKColor.textSecondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
    
    private func coverageDimensionRow(dimension: CoverageDimension) -> some View {
        HStack {
            Text(dimension.name)
                .font(.caption)
            Spacer()
            Text("\(dimension.coveragePercent)%")
                .font(.caption)
                .foregroundColor(dimension.isFullyCovered ? OKColor.riskNominal : OKColor.riskWarning)
            Text("(\(dimension.coveredCategories.count)/\(dimension.categories.count))")
                .font(.caption2)
                .foregroundColor(OKColor.textSecondary)
        }
    }
    
    private func coverageIcon(score: Int) -> String {
        if score >= 80 { return "checkmark.seal.fill" }
        else if score >= 50 { return "exclamationmark.triangle.fill" }
        else { return "xmark.seal.fill" }
    }
    
    private func coverageColor(score: Int) -> Color {
        if score >= 80 { return OKColor.riskNominal }
        else if score >= 50 { return OKColor.riskWarning }
        else { return OKColor.riskCritical }
    }
    
    private func suggestionIcon(priority: CoverageSuggestion.Priority) -> String {
        switch priority {
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "info.circle.fill"
        case .low: return "circle"
        }
    }
    
    private func suggestionColor(priority: CoverageSuggestion.Priority) -> Color {
        switch priority {
        case .high: return OKColor.riskCritical
        case .medium: return OKColor.riskWarning
        case .low: return .secondary
        }
    }
    
    // MARK: - Trend Section (Phase 9A)
    
    private var trendSection: some View {
        Section("Quality Trend") {
            let trend = QualityTrendComputer().computeTrend(days: 30)
            
            if trend.dataPoints < 3 {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(OKColor.textSecondary)
                    Text("Run more evaluations to see trends")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
            } else {
                // Pass rate trend
                HStack {
                    Image(systemName: trend.passRateDirection.systemImage)
                        .foregroundColor(trendColor(direction: trend.passRateDirection))
                    Text("Pass Rate")
                        .font(.subheadline)
                    Spacer()
                    Text(trend.passRateDirection.rawValue)
                        .font(.caption)
                        .foregroundColor(trendColor(direction: trend.passRateDirection))
                }
                
                // Drift trend
                HStack {
                    Image(systemName: trend.driftDirection.systemImage)
                        .foregroundColor(trendColor(direction: trend.driftDirection))
                    Text("Drift Level")
                        .font(.subheadline)
                    Spacer()
                    Text(trend.driftDirection.rawValue)
                        .font(.caption)
                        .foregroundColor(trendColor(direction: trend.driftDirection))
                }
                
                // Freshness
                HStack {
                    Image(systemName: trend.isFresh ? "clock.badge.checkmark" : "clock.badge.exclamationmark")
                        .foregroundColor(trend.isFresh ? OKColor.riskNominal : OKColor.riskWarning)
                    Text("Data Freshness")
                        .font(.subheadline)
                    Spacer()
                    if let days = trend.daysSinceLastEval {
                        Text(days == 0 ? "Today" : "\(days) days ago")
                            .font(.caption)
                            .foregroundColor(trend.isFresh ? .secondary : OKColor.riskWarning)
                    }
                }
                
                // Streak
                if trend.passingStreak > 1 {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(OKColor.riskWarning)
                        Text("Passing Streak")
                            .font(.subheadline)
                        Spacer()
                        Text("\(trend.passingStreak) runs")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                }
                
                // Average
                HStack {
                    Text("Avg Pass Rate (30d)")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                    Spacer()
                    Text(String(format: "%.0f%%", trend.averagePassRate * 100))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    private func trendColor(direction: TrendDirection) -> Color {
        switch direction {
        case .improving: return OKColor.riskNominal
        case .stable: return OKColor.actionPrimary
        case .degrading: return OKColor.riskCritical
        case .insufficient: return OKColor.textMuted
        }
    }
    
    // MARK: - Calibration Recommendations Section (Phase 9B)
    
    private var calibrationRecommendationsSection: some View {
        Section("Recommendations") {
            let advisor = CalibrationAdvisor(
                goldenCaseStore: goldenCaseStore,
                evalRunner: evalRunner,
                historyStore: QualityHistoryStore.shared
            )
            let recommendations = advisor.generateRecommendations()
            
            if recommendations.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(OKColor.riskNominal)
                    Text("No recommendations at this time")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
            } else {
                ForEach(recommendations) { rec in
                    recommendationRow(rec)
                }
                
                Text("Recommendations are advisory only and do not affect app behavior.")
                    .font(.caption2)
                    .foregroundColor(OKColor.textSecondary)
                    .padding(.top, 4)
            }
        }
    }
    
    private func recommendationRow(_ rec: CalibrationRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: rec.severity.systemImage)
                    .foregroundColor(recommendationColor(rec.severity))
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(rec.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(rec.message)
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
            
            if !rec.suggestedNextSteps.isEmpty {
                DisclosureGroup("Next Steps") {
                    ForEach(rec.suggestedNextSteps.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                            Text(rec.suggestedNextSteps[index])
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                    }
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func recommendationColor(_ severity: RecommendationSeverity) -> Color {
        switch severity {
        case .info: return OKColor.actionPrimary
        case .caution: return OKColor.riskWarning
        case .action: return OKColor.riskCritical
        }
    }
    
    // MARK: - Explanation Section
    
    private var explanationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "hand.thumbsup.circle")
                        .font(.title2)
                        .foregroundColor(OKColor.actionPrimary)
                    Text("Local-Only Feedback")
                        .font(.headline)
                }
                
                Text("Your feedback helps calibrate OperatorKit for your use. All feedback is stored locally on your device and is never transmitted.")
                    .font(.subheadline)
                    .foregroundColor(OKColor.textSecondary)
                
                // Privacy guarantee
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(OKColor.riskNominal)
                    Text("No data leaves your device")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(8)
                .background(OKColor.riskNominal.opacity(0.1))
                .cornerRadius(6)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        Section("Overview") {
            HStack {
                Text("Total Ratings")
                Spacer()
                Text("\(summary.totalEntries)")
                    .foregroundColor(OKColor.textSecondary)
            }
            
            HStack {
                Text("Helpful")
                Spacer()
                Text("\(summary.helpfulCount)")
                    .foregroundColor(OKColor.riskNominal)
            }
            
            HStack {
                Text("Not Helpful")
                Spacer()
                Text("\(summary.notHelpfulCount)")
                    .foregroundColor(OKColor.riskWarning)
            }
            
            HStack {
                Text("Mixed")
                Spacer()
                Text("\(summary.mixedCount)")
                    .foregroundColor(OKColor.textSecondary)
            }
            
            HStack {
                Text("Trust Level")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: summary.overallTrustLevel.systemImage)
                    Text(summary.overallTrustLevel.rawValue)
                }
                .foregroundColor(trustLevelColor)
            }
        }
    }
    
    private var trustLevelColor: Color {
        switch summary.overallTrustLevel {
        case .insufficient: return OKColor.textMuted
        case .needsImprovement: return OKColor.riskWarning
        case .moderate: return OKColor.actionPrimary
        case .high: return OKColor.riskNominal
        }
    }
    
    // MARK: - Breakdown Section
    
    private var breakdownSection: some View {
        Section("By Confidence Level") {
            ForEach(CalibrationSummary.ConfidenceBand.allCases, id: \.self) { band in
                let rate = summary.helpfulRateByConfidenceBand[band] ?? 0.0
                HStack {
                    Text(band.displayName)
                    Spacer()
                    Text(String(format: "%.0f%% helpful", rate * 100))
                        .foregroundColor(OKColor.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Recommendations Section
    
    private var recommendationsSection: some View {
        Section("Recommendations") {
            if let tip = recommendations.generalTip {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb")
                        .foregroundColor(OKColor.riskWarning)
                    Text(tip)
                        .font(.subheadline)
                }
            }
            
            if let contextRec = recommendations.contextRecommendation {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(OKColor.actionPrimary)
                    Text(contextRec)
                        .font(.subheadline)
                }
            }
            
            if let confidenceRec = recommendations.confidenceRecommendation {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "gauge.medium")
                        .foregroundColor(OKColor.riskWarning)
                    Text(confidenceRec)
                        .font(.subheadline)
                }
            }
        }
    }
    
    // MARK: - Top Issues Section
    
    private var topIssuesSection: some View {
        Section("Common Feedback") {
            ForEach(summary.topIssueTags, id: \.tag) { item in
                HStack {
                    Text(item.tag.displayName)
                    Spacer()
                    Text("\(item.count)")
                        .foregroundColor(OKColor.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Data Control Section
    
    private var dataControlSection: some View {
        Section("Your Data") {
            // Export button
            Button {
                exportFeedback()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Feedback as JSON")
                }
            }
            .disabled(feedbackStore.totalCount == 0)
            
            // Delete all button
            Button(role: .destructive) {
                showDeleteAllConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete All Feedback")
                }
            }
            .disabled(feedbackStore.totalCount == 0)
            
            // Info row
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(OKColor.textSecondary)
                Text("Feedback contains only ratings and tags, never your actual content.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
    }
    
    // MARK: - Export Logic
    
    private func exportFeedback() {
        do {
            let url = try feedbackStore.exportToFile()
            exportURL = url
            showExportSheet = true
        } catch {
            errorMessage = "Failed to export feedback: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

// MARK: - Preview

#Preview {
    QualityAndTrustView()
}
