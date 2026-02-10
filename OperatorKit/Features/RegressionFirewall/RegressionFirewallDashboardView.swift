import SwiftUI

// ============================================================================
// REGRESSION FIREWALL DASHBOARD VIEW (Phase 13D)
//
// Read-only evidence surface for firewall verification.
// No buttons that alter state. Pure visibility.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No state mutation
// ❌ No repair actions
// ❌ No auto-disable
// ✅ Read-only display
// ✅ Evidence surface only
// ============================================================================

public struct RegressionFirewallDashboardView: View {
    
    // MARK: - State
    
    @State private var report: FirewallVerificationReport? = nil
    @State private var isVerifying = false
    
    // MARK: - Body
    
    public var body: some View {
        if RegressionFirewallFeatureFlag.isEnabled {
            dashboardContent
                .onAppear { runVerification() }
        } else {
            featureDisabledView
        }
    }
    
    // MARK: - Dashboard Content
    
    private var dashboardContent: some View {
        List {
            if let report = report {
                statusSection(report)
                summarySection(report)
                
                ForEach(RuleCategory.allCases, id: \.self) { category in
                    categorySection(category, report: report)
                }
                
                footerSection(report)
            } else if isVerifying {
                verifyingSection
            }
        }
        .navigationTitle("Regression Firewall")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        .refreshable {
            runVerification()
        }
    }
    
    // MARK: - Status Section
    
    private func statusSection(_ report: FirewallVerificationReport) -> some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: report.status.icon)
                    .font(.system(size: 48))
                    .foregroundColor(statusColor(report.status))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.status.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor(report.status))
                    
                    Text(report.summaryText)
                        .font(.subheadline)
                        .foregroundColor(OKColor.textSecondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Summary Section
    
    private func summarySection(_ report: FirewallVerificationReport) -> some View {
        Section {
            HStack {
                Text("Total Rules")
                Spacer()
                Text("\(report.ruleCount)")
                    .foregroundColor(OKColor.textSecondary)
            }
            
            HStack {
                Text("Passed")
                Spacer()
                Text("\(report.passedCount)")
                    .foregroundColor(OKColor.riskNominal)
            }
            
            HStack {
                Text("Failed")
                Spacer()
                Text("\(report.failedCount)")
                    .foregroundColor(report.failedCount > 0 ? OKColor.riskCritical : .secondary)
            }
            
            HStack {
                Text("Last Verified")
                Spacer()
                Text(report.formattedVerifiedAt)
                    .foregroundColor(OKColor.textSecondary)
            }
        } header: {
            Text("Verification Summary")
        }
    }
    
    // MARK: - Category Section
    
    private func categorySection(_ category: RuleCategory, report: FirewallVerificationReport) -> some View {
        let categoryResults = report.results.filter { $0.category == category }
        let allPassed = categoryResults.allSatisfy { $0.passed }
        
        return Section {
            ForEach(categoryResults) { result in
                RuleResultRow(result: result)
            }
        } header: {
            HStack {
                Image(systemName: category.icon)
                Text(category.rawValue)
                Spacer()
                Image(systemName: allPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(allPassed ? OKColor.riskNominal : OKColor.riskCritical)
            }
        }
    }
    
    // MARK: - Footer Section
    
    private func footerSection(_ report: FirewallVerificationReport) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("About This Verification")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("This firewall verifies that safety guarantees are intact. All checks run locally on your device. No data is sent anywhere.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
                
                if report.status == .failed {
                    Text("If verification fails, the app should be updated or reinstalled. Do not attempt manual repairs.")
                        .font(.caption)
                        .foregroundColor(OKColor.riskCritical)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Verifying Section
    
    private var verifyingSection: some View {
        Section {
            HStack {
                ProgressView()
                    .padding(.trailing, 8)
                Text("Verifying...")
                    .foregroundColor(OKColor.textSecondary)
            }
        }
    }
    
    // MARK: - Feature Disabled View
    
    private var featureDisabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.slash")
                .font(.largeTitle)
                .foregroundColor(OKColor.textSecondary)
            
            Text("Regression Firewall")
                .font(.headline)
            
            Text("Verification is not enabled.")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func runVerification() {
        isVerifying = true
        
        // Run verification asynchronously to not block UI
        DispatchQueue.global(qos: .userInitiated).async {
            let newReport = RegressionFirewallRunner.shared.runAllRules()
            
            DispatchQueue.main.async {
                self.report = newReport
                self.isVerifying = false
            }
        }
    }
    
    private func statusColor(_ status: FirewallStatus) -> Color {
        switch status {
        case .passed: return OKColor.riskNominal
        case .failed: return OKColor.riskCritical
        case .disabled: return OKColor.textMuted
        }
    }
    
    // MARK: - Init
    
    public init() {}
}

// MARK: - Rule Result Row

private struct RuleResultRow: View {
    let result: RuleResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.passed ? OKColor.riskNominal : OKColor.riskCritical)
                
                Text(result.ruleName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(result.ruleId)
                    .font(.caption2)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            Text(result.evidence)
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
struct RegressionFirewallDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RegressionFirewallDashboardView()
        }
    }
}
#endif
