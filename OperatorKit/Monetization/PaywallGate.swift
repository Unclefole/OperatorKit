import SwiftUI

// ============================================================================
// PAYWALL GATE (Phase 10G)
//
// UI component that gates actions behind quota checks.
// Shows paywall when quota exceeded, allows action otherwise.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ Does NOT affect execution modules
// ❌ No silent blocking
// ✅ Shows clear paywall with upgrade option
// ✅ Always allows reviewing existing content
// ✅ Provides "Restore Purchases" option
//
// See: docs/SAFETY_CONTRACT.md (Section 16)
// ============================================================================

// MARK: - Paywall Gate View Modifier

/// View modifier that gates actions behind quota checks
public struct PaywallGateModifier: ViewModifier {
    @StateObject private var quotaEnforcer = QuotaEnforcer.shared
    @StateObject private var entitlementManager = EntitlementManager.shared
    
    let quotaType: QuotaType
    let checkQuota: () -> QuotaCheckResult
    @Binding var isBlocked: Bool
    @Binding var showPaywall: Bool
    
    public func body(content: Content) -> some View {
        content
            .onChange(of: isBlocked) { _, blocked in
                if blocked {
                    let result = checkQuota()
                    if !result.allowed {
                        showPaywall = true
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallSheet(
                    quotaType: quotaType,
                    quotaCheck: checkQuota()
                )
            }
    }
}

// MARK: - Paywall Sheet

/// Sheet displayed when quota is exceeded
struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var entitlementManager = EntitlementManager.shared
    @StateObject private var purchaseController = PurchaseController.shared
    
    let quotaType: QuotaType
    let quotaCheck: QuotaCheckResult
    
    @State private var isRestoring = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Quota info
                    quotaInfoSection
                    
                    // Plan comparison
                    PlanComparisonView(highlightedTier: recommendedTier)
                    
                    // Actions
                    actionButtons
                    
                    // Why we charge
                    whyWeChargeSection
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Upgrade Required")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: quotaIcon)
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Limit Reached")
                .font(.title2)
                .fontWeight(.bold)
            
            if let message = quotaCheck.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var quotaIcon: String {
        switch quotaType {
        case .weeklyExecutions: return "bolt.slash"
        case .memoryItems: return "brain.head.profile"
        case .teamSeats: return "person.3"
        case .teamArtifacts: return "square.and.arrow.up"
        }
    }
    
    // MARK: - Quota Info
    
    private var quotaInfoSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Current Usage")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(quotaCheck.currentUsage) / \(quotaCheck.limit ?? 0) \(quotaType.unitName)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: geometry.size.width * usagePercentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            Text("Resets weekly")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var usagePercentage: CGFloat {
        guard let limit = quotaCheck.limit, limit > 0 else { return 1.0 }
        return min(1.0, CGFloat(quotaCheck.currentUsage) / CGFloat(limit))
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Upgrade button
            Button {
                // Navigate to upgrade
            } label: {
                HStack {
                    Image(systemName: "star.fill")
                    Text("Upgrade to \(recommendedTier.displayName)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            // Restore purchases
            Button {
                Task { await restorePurchases() }
            } label: {
                HStack {
                    if isRestoring {
                        ProgressView()
                            .padding(.trailing, 4)
                    }
                    Text("Restore Purchases")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(12)
            }
            .disabled(isRestoring)
            
            // Continue with free
            if canContinueFree {
                Button {
                    dismiss()
                } label: {
                    Text("Continue with Free (Read Only)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var recommendedTier: SubscriptionTier {
        switch quotaType {
        case .weeklyExecutions, .memoryItems:
            return .pro
        case .teamSeats, .teamArtifacts:
            return .team
        }
    }
    
    private var canContinueFree: Bool {
        // Can continue free if they're just viewing, not creating
        quotaType == .weeklyExecutions || quotaType == .memoryItems
    }
    
    // MARK: - Why We Charge
    
    private var whyWeChargeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why we charge")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(WhyWeChargeText.shortExplanation)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func restorePurchases() async {
        isRestoring = true
        do {
            try await entitlementManager.restorePurchases()
            // Check if now allowed
            let newCheck = QuotaEnforcer.shared.canStartExecution()
            if newCheck.allowed {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isRestoring = false
    }
}

// MARK: - Why We Charge Text

/// Text explaining why we charge
public enum WhyWeChargeText {
    
    public static let shortExplanation = """
        OperatorKit runs entirely on your device. There are no ads, no tracking, \
        and no data collection. Your subscription supports ongoing development.
        """
    
    public static let longExplanation = """
        OperatorKit is a privacy-first productivity tool that runs entirely on your device:

        • No ads or tracking
        • No data collection
        • No cloud processing of your content
        • All AI runs locally on your device

        Your subscription directly supports ongoing development and allows us to keep \
        improving without compromising on privacy.
        """
}

// MARK: - View Extension

extension View {
    /// Gates an action behind a quota check
    public func paywallGate(
        quotaType: QuotaType,
        checkQuota: @escaping () -> QuotaCheckResult,
        isBlocked: Binding<Bool>,
        showPaywall: Binding<Bool>
    ) -> some View {
        modifier(PaywallGateModifier(
            quotaType: quotaType,
            checkQuota: checkQuota,
            isBlocked: isBlocked,
            showPaywall: showPaywall
        ))
    }
}
