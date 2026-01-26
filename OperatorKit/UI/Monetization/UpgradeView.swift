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

struct UpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var purchaseController = PurchaseController.shared
    @StateObject private var entitlementManager = EntitlementManager.shared
    
    @State private var selectedProductId: String?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
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
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("OperatorKit Pro")
            .navigationBarTitleDisplayMode(.inline)
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
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                
                Image(systemName: "star.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            Text("OperatorKit Pro")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Remove limits and get more done")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
        .background(Color.white)
        .cornerRadius(12)
    }
    
    // MARK: - Products Section
    
    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a Plan")
                .font(.headline)
            
            if entitlementManager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if entitlementManager.products.isEmpty {
                Text("Unable to load subscription options. Please try again later.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
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
    
    // MARK: - Purchase Section
    
    private var purchaseSection: some View {
        VStack(spacing: 12) {
            // Subscribe button
            PurchaseButton(
                title: "Subscribe",
                isLoading: purchaseController.purchaseState == .purchasing,
                isDisabled: selectedProductId == nil || entitlementManager.products.isEmpty
            ) {
                Task {
                    await purchase()
                }
            }
            
            // Restore button
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
        .foregroundColor(.blue)
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
