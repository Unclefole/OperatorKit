import SwiftUI
import StoreKit

// ============================================================================
// UPGRADE VIEW (Phase 10A)
//
// Paywall screen for OperatorKit Pro subscription.
// Apple-clean copy, no hype, accessible.
//
// CONSTRAINTS:
// ✅ No hype or "AI thinks" language
// ✅ Factual feature descriptions only
// ✅ Accessible (VoiceOver labels)
// ✅ Match existing UI styles
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

// MARK: - Paywall Feature Flag (Inlined)
// Paywall ENABLED for App Store release
private let _paywallEnabledInRelease = true

private var isPaywallEnabled: Bool {
    // Paywall enabled in both DEBUG and RELEASE
    return _paywallEnabledInRelease
}

struct UpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var purchaseController = PurchaseController.shared
    @StateObject private var entitlementManager = EntitlementManager.shared

    @State private var selectedProductId: String?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    @ViewBuilder
    var body: some View {
        // HARD GATE: If paywall is disabled, show nothing and dismiss
        if !isPaywallEnabled {
            Color.clear
                .onAppear { dismiss() }
        } else {
            paywallContent
        }
    }

    private var paywallContent: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Features
                    featuresSection

                    // Products
                    productsSection

                    // Purchase buttons
                    purchaseSection

                    // Privacy note
                    PrivacyNoteView()
                        .padding(.top, 8)

                    // Legal links
                    legalLinksSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(OKColor.backgroundPrimary)
            .navigationTitle("OperatorKit Pro")
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
        .task {
            await entitlementManager.fetchProducts()
            // Select annual by default (best value)
            if selectedProductId == nil && !entitlementManager.products.isEmpty {
                selectedProductId = StoreKitProductIDs.proAnnual
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: purchaseController.purchaseState) { newState in
            handlePurchaseStateChange(newState)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Pro badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [OKColor.actionPrimary, OKColor.riskExtreme],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                
                Image(systemName: "star.fill")
                    .font(.system(size: 28))
                    .foregroundColor(OKColor.textPrimary)
            }
            
            Text("OperatorKit Pro")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Remove limits and get more done")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("OperatorKit Pro. Remove limits and get more done.")
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("What's Included")
                .font(.headline)
                .padding(.bottom, 8)
            
            FeatureRow(
                icon: "infinity",
                title: "Unlimited Executions",
                description: "No weekly limit on requests (Free: \(UsageQuota.freeExecutionsPerWeek)/week)"
            )
            
            FeatureRow(
                icon: "folder",
                title: "Unlimited Storage",
                description: "Save as many items as you need (Free: \(UsageQuota.freeMemoryItemsMax) items)"
            )
            
            FeatureRow(
                icon: "lock.shield",
                title: "Same Privacy Guarantees",
                description: "No data leaves your device, same as Free"
            )
        }
        .padding(16)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(12)
    }
    
    // MARK: - Products Section

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if entitlementManager.isLoading {
                // Loading state - show spinner only
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(32)
                    Spacer()
                }
            } else if entitlementManager.products.isEmpty {
                // Failed/empty state - clean message, no broken UI
                subscriptionsUnavailableView
            } else {
                // Success - show plans
                Text("Choose a Plan")
                    .font(.headline)

                ForEach(entitlementManager.products, id: \.id) { product in
                    PriceBadge(
                        product: product,
                        isSelected: selectedProductId == product.id
                    )
                    .onTapGesture {
                        selectedProductId = product.id
                    }
                }
            }
        }
    }

    /// Clean fallback when products fail to load
    private var subscriptionsUnavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(OKColor.textSecondary)

            Text("Subscriptions temporarily unavailable.")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await entitlementManager.fetchProducts()
                }
            }
            .font(.subheadline)
            .foregroundColor(OKColor.actionPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Subscriptions temporarily unavailable. Tap to try again.")
    }
    
    // MARK: - Purchase Section

    @ViewBuilder
    private var purchaseSection: some View {
        VStack(spacing: 12) {
            // Only show Subscribe button if products loaded successfully
            if !entitlementManager.products.isEmpty {
                PurchaseButton(
                    title: "Subscribe",
                    isLoading: purchaseController.purchaseState == .purchasing,
                    isDisabled: selectedProductId == nil
                ) {
                    Task {
                        await purchase()
                    }
                }
            }

            // Restore button always available (might restore even if products fail to load)
            SecondaryButton(
                title: "Restore Purchases",
                icon: "arrow.clockwise",
                isLoading: purchaseController.purchaseState == .restoring
            ) {
                Task {
                    await restore()
                }
            }
        }
    }
    
    // MARK: - Legal Links Section
    
    private var legalLinksSection: some View {
        HStack(spacing: 16) {
            Link("Terms of Service", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                .font(.caption)
            
            Link("Privacy Policy", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
                .font(.caption)
        }
        .foregroundColor(OKColor.actionPrimary)
    }
    
    // MARK: - Actions
    
    private func purchase() async {
        guard let productId = selectedProductId else { return }
        await purchaseController.purchase(productId: productId)
    }
    
    private func restore() async {
        await purchaseController.restore()
    }
    
    private func handlePurchaseStateChange(_ state: PurchaseState) {
        switch state {
        case .success:
            // Refresh app state and dismiss
            Task {
                await appState.refreshSubscriptionStatus()
            }
            dismiss()
            
        case .failed(let message):
            errorMessage = message
            showError = true
            purchaseController.clearError()
            
        case .cancelled:
            // User cancelled, no action needed
            purchaseController.resetState()
            
        default:
            break
        }
    }
}

// MARK: - Preview

#Preview {
    UpgradeView()
        .environmentObject(AppState())
}
