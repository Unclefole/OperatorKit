import SwiftUI
import StoreKit

// ============================================================================
// PRICING VIEW (Phase 10H, Updated Phase 10L)
//
// Dedicated pricing screen showing all subscription options.
// Clear, factual presentation with no hype language.
// Supports pricing copy variants (Phase 10L).
//
// CONSTRAINTS:
// ❌ No hype or marketing language
// ❌ No "AI" anthropomorphism
// ❌ No security claims unless proven
// ✅ Factual feature comparison
// ✅ Clear pricing
// ✅ Restore purchases always available
// ✅ Variant copy support (Phase 10L)
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct PricingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var entitlementManager = EntitlementManager.shared
    @StateObject private var purchaseController = PurchaseController.shared
    @StateObject private var variantStore = PricingVariantStore.shared
    
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Current plan badge
                    if entitlementManager.currentTier != .free {
                        currentPlanBadge
                    }
                    
                    // Plan cards
                    planCardsSection
                    
                    // What you get
                    whatYouGetSection
                    
                    // Privacy promise
                    privacyPromiseSection
                    
                    // Actions
                    actionsSection
                    
                    // Footer
                    footerSection
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Pricing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { errorMessage = nil }
                Button("Restore Purchases") {
                    Task { await restorePurchases() }
                }
            } message: {
                Text(errorMessage ?? "An error occurred. Try again or restore your purchases.")
            }
            .alert("Purchase Complete", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Thank you! Your subscription is now active.")
            }
            .task {
                await entitlementManager.fetchProducts()
                // Record funnel step (Phase 10L)
                ConversionFunnelManager.shared.recordStep(.pricingViewed)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Choose Your Plan")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(PricingCopy.tagline)
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Current Plan Badge
    
    private var currentPlanBadge: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(OKColor.riskNominal)
            Text("You're on \(entitlementManager.currentTier.displayName)")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(OKColor.riskNominal.opacity(0.1))
        .cornerRadius(20)
    }
    
    // MARK: - Plan Cards
    
    private var planCardsSection: some View {
        VStack(spacing: 16) {
            ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                PlanCard(
                    tier: tier,
                    products: productsForTier(tier),
                    isCurrent: tier == entitlementManager.currentTier,
                    isLoading: isPurchasing,
                    onSelect: { product in
                        selectedProduct = product
                        Task { await purchase(product) }
                    }
                )
            }
            
            // Lifetime Sovereign Option (Phase 11C)
            lifetimeSovereignCard
        }
    }
    
    private func productsForTier(_ tier: SubscriptionTier) -> [Product] {
        entitlementManager.products.filter { product in
            StoreKitProductIDs.tier(for: product.id) == tier && !StoreKitProductIDs.isOneTimePurchase(product.id)
        }
    }
    
    // MARK: - Lifetime Sovereign Card (Phase 11C)
    
    private var lifetimeSovereignCard: some View {
        let lifetimeProduct = entitlementManager.products.first { StoreKitProductIDs.isLifetimeSovereign($0.id) }
        let isLifetimeOwner = entitlementManager.status.isLifetime
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Lifetime Sovereign")
                            .font(.headline)
                        
                        Text("One-Time")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(OKColor.riskExtreme.opacity(0.2))
                            .foregroundColor(OKColor.riskExtreme)
                            .cornerRadius(4)
                    }
                    
                    Text("Pro features forever. No subscription.")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
                
                Spacer()
                
                if isLifetimeOwner {
                    Label("Owned", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(OKColor.riskNominal)
                } else if let product = lifetimeProduct {
                    Button {
                        selectedProduct = product
                        Task { await purchase(product) }
                    } label: {
                        Text(product.displayPrice)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(OKColor.riskExtreme)
                            .foregroundColor(OKColor.textPrimary)
                            .cornerRadius(8)
                    }
                    .disabled(isPurchasing)
                } else {
                    Text(PricingPackageRegistry.lifetimeSovereignPrice)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
            
            // Feature list
            VStack(alignment: .leading, spacing: 4) {
                lifetimeFeatureRow("All Pro features included")
                lifetimeFeatureRow("Unlimited drafted outcomes")
                lifetimeFeatureRow("No recurring subscription")
            }
        }
        .padding()
        .background(OKColor.riskExtreme.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isLifetimeOwner ? OKColor.riskNominal : OKColor.riskExtreme.opacity(0.3), lineWidth: isLifetimeOwner ? 2 : 1)
        )
    }
    
    private func lifetimeFeatureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.caption)
                .foregroundColor(OKColor.riskExtreme)
            Text(text)
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
    }
    
    // MARK: - What You Get
    
    private var whatYouGetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What You Get")
                .font(.headline)
            
            ForEach(PricingCopy.valueProps, id: \.self) { prop in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(OKColor.riskNominal)
                    Text(prop)
                        .font(.subheadline)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(OKColor.textMuted.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Privacy Promise
    
    private var privacyPromiseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(OKColor.actionPrimary)
                Text("Our Promise")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                privacyRow("No ads", icon: "nosign")
                privacyRow("No tracking", icon: "eye.slash")
                privacyRow("On-device by default", icon: "iphone")
                privacyRow("Your data stays yours", icon: "lock.shield")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(OKColor.actionPrimary.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func privacyRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(OKColor.actionPrimary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
        }
    }
    
    // MARK: - Actions
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Restore purchases
            Button {
                Task { await restorePurchases() }
            } label: {
                HStack {
                    if purchaseController.purchaseState == .restoring {
                        ProgressView()
                            .padding(.trailing, 4)
                    }
                    Text("Restore Purchases")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(OKColor.textMuted.opacity(0.1))
                .foregroundColor(OKColor.actionPrimary)
                .cornerRadius(12)
            }
            .disabled(purchaseController.purchaseState == .restoring)
            
            // Manage subscription
            Button {
                openSubscriptionManagement()
            } label: {
                HStack {
                    Text("Manage Subscription")
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(OKColor.textSecondary)
            }
            
            // Not now
            Button {
                dismiss()
            } label: {
                Text("Not Now")
                    .foregroundColor(OKColor.textSecondary)
            }
        }
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text(PricingCopy.subscriptionDisclosure)
                .font(.caption2)
                .foregroundColor(OKColor.textSecondary)
                .multilineTextAlignment(.center)
            
            // Packaging status (Phase 11B)
            packagingStatusLine
            
            HStack(spacing: 16) {
                Button("Terms of Service") {
                    if let url = URL(string: "https://operatorkit.app/terms") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption2)

                Button("Privacy Policy") {
                    if let url = URL(string: "https://operatorkit.app/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption2)
            }
        }
        .padding(.top)
    }
    
    // MARK: - Packaging Status (Phase 11B)
    
    private var packagingStatusLine: some View {
        let result = PricingConsistencyValidator.shared.validate()
        
        return HStack(spacing: 4) {
            Image(systemName: result.status.icon)
                .font(.caption2)
                .foregroundColor(statusColor(for: result.status))
            
            Text("Pricing package: \(result.status.displayName)")
                .font(.caption2)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding(.vertical, 4)
    }
    
    private func statusColor(for status: PricingValidationStatus) -> Color {
        switch status {
        case .pass: return OKColor.riskNominal
        case .warn: return OKColor.riskWarning
        case .fail: return OKColor.riskCritical
        }
    }
    
    // MARK: - Actions
    
    private func purchase(_ product: Product) async {
        isPurchasing = true
        ConversionLedger.shared.recordEvent(.upgradeTapped)
        ConversionLedger.shared.recordEvent(.purchaseStarted)
        
        let success = await purchaseController.purchase(product)
        
        if success {
            ConversionLedger.shared.recordEvent(.purchaseSuccess)
            await entitlementManager.refreshStatus()
            showSuccess = true
        } else if let error = purchaseController.errorMessage {
            errorMessage = error
            showError = true
        }
        
        purchaseController.resetState()
        isPurchasing = false
    }
    
    private func restorePurchases() async {
        ConversionLedger.shared.recordEvent(.restoreTapped)
        
        let success = await purchaseController.restore()
        
        if success {
            ConversionLedger.shared.recordEvent(.restoreSuccess)
            await entitlementManager.refreshStatus()
            if entitlementManager.currentTier != .free {
                showSuccess = true
            }
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

// MARK: - Plan Card

private struct PlanCard: View {
    let tier: SubscriptionTier
    let products: [Product]
    let isCurrent: Bool
    let isLoading: Bool
    let onSelect: (Product) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: tierIcon)
                    .foregroundColor(tierColor)
                
                Text(tier.displayName)
                    .font(.headline)
                
                Spacer()
                
                if isCurrent {
                    Text("Current")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(OKColor.riskNominal.opacity(0.1))
                        .foregroundColor(OKColor.riskNominal)
                        .cornerRadius(6)
                }
                
                if tier == .pro && !isCurrent {
                    Text("Popular")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(OKColor.actionPrimary.opacity(0.1))
                        .foregroundColor(OKColor.actionPrimary)
                        .cornerRadius(6)
                }
            }
            
            // Description
            Text(TierMatrix.shortDescription(for: tier))
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
            
            // Features
            VStack(alignment: .leading, spacing: 4) {
                ForEach(PricingCopy.tierBullets(for: tier), id: \.self) { bullet in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundColor(OKColor.riskNominal)
                        Text(bullet)
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                }
            }
            
            // Products
            if tier == .free {
                Text("Free forever")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(OKColor.textSecondary)
            } else if products.isEmpty {
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            } else {
                ForEach(products, id: \.id) { product in
                    ProductButton(
                        product: product,
                        isLoading: isLoading,
                        isCurrent: isCurrent,
                        onSelect: { onSelect(product) }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrent ? OKColor.riskNominal.opacity(0.05) : OKColor.textMuted.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tier == .pro && !isCurrent ? OKColor.actionPrimary : Color.clear, lineWidth: 2)
        )
    }
    
    private var tierIcon: String {
        switch tier {
        case .free: return "person.circle"
        case .pro: return "star.circle"
        case .team: return "person.3.fill"
        }
    }
    
    private var tierColor: Color {
        switch tier {
        case .free: return OKColor.textMuted
        case .pro: return OKColor.actionPrimary
        case .team: return OKColor.riskWarning
        }
    }
}

// MARK: - Product Button

private struct ProductButton: View {
    let product: Product
    let isLoading: Bool
    let isCurrent: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let introOffer = product.subscription?.introductoryOffer {
                        Text(introOfferText(introOffer))
                            .font(.caption)
                            .foregroundColor(OKColor.riskNominal)
                    }
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                } else {
                    Text(product.displayPrice)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(OKColor.actionPrimary.opacity(0.1))
            .foregroundColor(OKColor.actionPrimary)
            .cornerRadius(8)
        }
        .disabled(isLoading || isCurrent)
    }
    
    private func introOfferText(_ offer: Product.SubscriptionOffer) -> String {
        // Handle all known payment modes
        if offer.paymentMode == .freeTrial {
            return "Free trial available"
        } else if offer.paymentMode == .payAsYouGo {
            return "Intro offer available"
        } else if offer.paymentMode == .payUpFront {
            return "Discounted first period"
        } else {
            return ""
        }
    }
}

// MARK: - Preview

#Preview {
    PricingView()
}
