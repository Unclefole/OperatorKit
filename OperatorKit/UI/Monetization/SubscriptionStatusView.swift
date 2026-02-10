import SwiftUI

// ============================================================================
// SUBSCRIPTION STATUS VIEW (Phase 10A, Updated Phase 10G)
//
// Shows current subscription tier, renewal info, and management options.
// Accessible from Settings. Includes plan comparison and upgrade prompts.
//
// CONSTRAINTS:
// ✅ No hype language
// ✅ Factual status display
// ✅ Accessible
// ✅ App Store-safe language
//
// See: docs/SAFETY_CONTRACT.md, docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Paywall Gate (Inlined)
// Paywall ENABLED for App Store release
private let _subscriptionPaywallEnabled: Bool = true

struct SubscriptionStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var purchaseController = PurchaseController.shared
    @StateObject private var entitlementManager = EntitlementManager.shared
    
    @State private var isRefreshing: Bool = false
    @State private var showUpgrade: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showingActivationPlaybook: Bool = false  // Phase 10N
    
    var body: some View {
        List {
            // Current Plan Section
            Section {
                currentPlanRow
                
                if appState.isPro {
                    renewalRow
                }
            } header: {
                Text("Current Plan")
            }
            
            // Usage Section (Free tier only)
            if !appState.isPro {
                Section {
                    executionUsageRow
                    memoryUsageRow
                } header: {
                    Text("Usage This Week")
                } footer: {
                    Text("Upgrade to Pro for unlimited usage.")
                }
            }
            
            // Actions Section
            Section {
                if !appState.isPro {
                    upgradeButton
                }
                restoreButton
                manageSubscriptionButton
            } header: {
                Text("Actions")
            }
            
            // Plan Comparison Section (Phase 10G)
            Section {
                PlanComparisonView(highlightedTier: recommendedUpgradeTier)
            } header: {
                Text("Compare Plans")
            }
            
            // Why We Charge Section (Phase 10G)
            Section {
                whyWeChargeRow
            } header: {
                Text("Why We Charge")
            }
            
            // Get Value Now Section (Phase 10N) - Pro/Team only
            if appState.isPro {
                Section {
                    activationPlaybookRow
                } header: {
                    Text("Get Value Now")
                }
            }
            
            // Info Section
            Section {
                privacyInfoRow
                dataUseInfoRow
            } header: {
                Text("About Subscriptions")
            } footer: {
                Text("Subscriptions are managed through your Apple ID. OperatorKit does not store any payment information.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(OKColor.backgroundPrimary)
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        .refreshable {
            await refresh()
        }
        .sheet(isPresented: $showUpgrade) {
            if _subscriptionPaywallEnabled {
                UpgradeView()
                    .environmentObject(appState)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Current Plan Row
    
    private var currentPlanRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan")
                    .font(.subheadline)
                    .foregroundColor(OKColor.textSecondary)
                
                HStack(spacing: 8) {
                    Text(appState.currentTier.displayName)
                        .font(.headline)
                    
                    SubscriptionTierBadge(tier: appState.currentTier)
                }
            }
            
            Spacer()
            
            if isRefreshing {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current plan: \(appState.currentTier.displayName)")
    }
    
    // MARK: - Renewal Row
    
    @ViewBuilder
    private var renewalRow: some View {
        if let renewalDate = appState.subscriptionStatus.formattedRenewalDate {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Renews")
                        .font(.subheadline)
                        .foregroundColor(OKColor.textSecondary)
                    
                    Text(renewalDate)
                        .font(.subheadline)
                }
                
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Subscription renews on \(renewalDate)")
        }
    }
    
    // MARK: - Usage Rows
    
    private var executionUsageRow: some View {
        let used = appState.usageLedger.data.executionsThisWindow
        let total = UsageQuota.freeExecutionsPerWeek
        let remaining = max(0, total - used)
        
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Executions")
                    .font(.subheadline)
                    .foregroundColor(OKColor.textSecondary)
                
                Text("\(remaining) remaining")
                    .font(.subheadline)
            }
            
            Spacer()
            
            Text("\(used)/\(total)")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Executions: \(remaining) of \(total) remaining this week")
    }
    
    private var memoryUsageRow: some View {
        let currentCount = MemoryStore.shared.items.count
        let limit = UsageQuota.freeMemoryItemsMax
        let remaining = max(0, limit - currentCount)
        
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Saved Items")
                    .font(.subheadline)
                    .foregroundColor(OKColor.textSecondary)
                
                Text("\(remaining) remaining")
                    .font(.subheadline)
            }
            
            Spacer()
            
            Text("\(currentCount)/\(limit)")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saved items: \(remaining) of \(limit) remaining")
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var upgradeButton: some View {
        if _subscriptionPaywallEnabled {
            Button {
                showUpgrade = true
            } label: {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(OKColor.actionPrimary)
                    Text("Upgrade to Pro")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
            .accessibilityLabel("Upgrade to Pro")
            .accessibilityHint("Opens subscription options")
        }
        // If _subscriptionPaywallEnabled == false, button is hidden entirely
    }
    
    private var restoreButton: some View {
        Button {
            Task {
                await restore()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(OKColor.actionPrimary)
                Text("Restore Purchases")
                Spacer()
                if purchaseController.purchaseState == .restoring {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .disabled(purchaseController.purchaseState == .restoring)
        .accessibilityLabel("Restore purchases")
        .accessibilityHint("Restores any previous subscriptions")
    }
    
    private var manageSubscriptionButton: some View {
        Button {
            openSubscriptionManagement()
        } label: {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(OKColor.actionPrimary)
                Text("Manage Subscription")
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
        .accessibilityLabel("Manage subscription")
        .accessibilityHint("Opens Apple subscription settings")
    }
    
    // MARK: - Info Rows
    
    private var privacyInfoRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .foregroundColor(OKColor.riskNominal)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Privacy Unchanged")
                    .font(.subheadline)
                Text("Pro and Free have identical privacy guarantees. No data leaves your device.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Privacy unchanged. Pro and Free have identical privacy guarantees.")
    }
    
    private var dataUseInfoRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "creditcard")
                .foregroundColor(OKColor.actionPrimary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Payments by Apple")
                    .font(.subheadline)
                Text("All payments are processed by Apple. OperatorKit never sees your payment information.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Payments processed by Apple. OperatorKit never sees your payment information.")
    }
    
    // MARK: - Activation Playbook Row (Phase 10N)
    
    private var activationPlaybookRow: some View {
        Button {
            showingActivationPlaybook = true
        } label: {
            HStack {
                Image(systemName: "star.circle")
                    .foregroundColor(OKColor.riskWarning)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("First 3 Wins")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(OKColor.textPrimary)
                    
                    Text("Quick tasks to get started")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(OKColor.textMuted)
            }
        }
        .sheet(isPresented: $showingActivationPlaybook) {
            ActivationPlaybookView()
        }
    }
    
    // MARK: - Why We Charge (Phase 10G)
    
    private var whyWeChargeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(WhyWeChargeText.shortExplanation)
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
    }
    
    /// Recommended tier for upgrade
    private var recommendedUpgradeTier: SubscriptionTier? {
        switch appState.currentTier {
        case .free: return .pro
        case .pro: return .team
        case .team: return nil
        }
    }
    
    // MARK: - Actions
    
    private func refresh() async {
        isRefreshing = true
        await appState.refreshSubscriptionStatus()
        isRefreshing = false
    }
    
    private func restore() async {
        let success = await purchaseController.restore()
        if success {
            await appState.refreshSubscriptionStatus()
        } else if let error = purchaseController.errorMessage {
            errorMessage = error
            showError = true
        }
        purchaseController.resetState()
    }
    
    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        SubscriptionStatusView()
            .environmentObject(AppState())
    }
}
