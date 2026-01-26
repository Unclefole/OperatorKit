import SwiftUI

// ============================================================================
// UPGRADE PROMPT CARD (Phase 10I)
//
// Subtle upgrade prompt for conversion surfaces.
// Shows only to Free tier users after successful actions.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No forced upgrades
// ❌ No blocking behavior
// ❌ No deceptive copy
// ✅ Dismissible
// ✅ Records user-initiated taps only
// ✅ Factual benefits
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

// MARK: - Upgrade Prompt Card

struct UpgradePromptCard: View {
    @StateObject private var entitlementManager = EntitlementManager.shared
    @Binding var showPricing: Bool
    
    let context: UpgradeContext
    let onDismiss: (() -> Void)?
    
    init(
        context: UpgradeContext,
        showPricing: Binding<Bool>,
        onDismiss: (() -> Void)? = nil
    ) {
        self.context = context
        self._showPricing = showPricing
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        // Only show to free tier users
        if entitlementManager.currentTier == .free {
            cardContent
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: context.icon)
                    .foregroundColor(context.iconColor)
                
                Text(context.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Text(context.message)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button {
                ConversionLedger.shared.recordEvent(.upgradeTapped)
                showPricing = true
            } label: {
                Text(context.buttonText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            // Only record impression if actually shown
            if entitlementManager.currentTier == .free {
                ConversionLedger.shared.recordEvent(.paywallShown)
            }
        }
    }
}

// MARK: - Upgrade Context

enum UpgradeContext {
    case afterDraftCompletion
    case diagnosticsSection
    case qualityAndTrust
    case usageLimitApproaching
    
    var title: String {
        switch self {
        case .afterDraftCompletion:
            return "Unlock Unlimited"
        case .diagnosticsSection:
            return "See Plans"
        case .qualityAndTrust:
            return "Pro for Teams"
        case .usageLimitApproaching:
            return "Running Low"
        }
    }
    
    var message: String {
        switch self {
        case .afterDraftCompletion:
            return "Upgrade to Pro for unlimited drafted outcomes."
        case .diagnosticsSection:
            return "View all available plans and features."
        case .qualityAndTrust:
            return "Team tier includes governance features and shared policies."
        case .usageLimitApproaching:
            return "You're approaching your weekly limit. Upgrade for unlimited usage."
        }
    }
    
    var buttonText: String {
        switch self {
        case .afterDraftCompletion:
            return "View Pro"
        case .diagnosticsSection:
            return "Compare Plans"
        case .qualityAndTrust:
            return "Learn About Team"
        case .usageLimitApproaching:
            return "Upgrade Now"
        }
    }
    
    var icon: String {
        switch self {
        case .afterDraftCompletion:
            return "star.fill"
        case .diagnosticsSection:
            return "chart.bar"
        case .qualityAndTrust:
            return "person.3.fill"
        case .usageLimitApproaching:
            return "exclamationmark.triangle"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .afterDraftCompletion:
            return .blue
        case .diagnosticsSection:
            return .purple
        case .qualityAndTrust:
            return .orange
        case .usageLimitApproaching:
            return .yellow
        }
    }
}

// MARK: - Inline Upgrade Link

struct InlineUpgradeLink: View {
    @StateObject private var entitlementManager = EntitlementManager.shared
    @Binding var showPricing: Bool
    
    let text: String
    let targetTier: SubscriptionTier?
    
    init(
        text: String = "See plans",
        targetTier: SubscriptionTier? = nil,
        showPricing: Binding<Bool>
    ) {
        self.text = text
        self.targetTier = targetTier
        self._showPricing = showPricing
    }
    
    var body: some View {
        // Show to free users, or show team link to pro users
        if shouldShow {
            Button {
                ConversionLedger.shared.recordEvent(.upgradeTapped)
                showPricing = true
            } label: {
                HStack(spacing: 4) {
                    Text(text)
                        .font(.caption)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    private var shouldShow: Bool {
        switch entitlementManager.currentTier {
        case .free:
            return true
        case .pro:
            return targetTier == .team
        case .team:
            return false
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        UpgradePromptCard(
            context: .afterDraftCompletion,
            showPricing: .constant(false)
        )
        
        UpgradePromptCard(
            context: .diagnosticsSection,
            showPricing: .constant(false)
        )
        
        UpgradePromptCard(
            context: .qualityAndTrust,
            showPricing: .constant(false)
        )
    }
    .padding()
}
