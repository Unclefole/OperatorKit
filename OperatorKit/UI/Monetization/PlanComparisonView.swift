import SwiftUI

// ============================================================================
// PLAN COMPARISON VIEW (Phase 10G)
//
// Displays feature comparison across Free, Pro, and Team tiers.
// Single source of truth for tier features.
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct PlanComparisonView: View {
    @StateObject private var entitlementManager = EntitlementManager.shared
    @State private var showPricing = false

    let highlightedTier: SubscriptionTier?
    let onSelectTier: ((SubscriptionTier) -> Void)?

    init(highlightedTier: SubscriptionTier? = nil, onSelectTier: ((SubscriptionTier) -> Void)? = nil) {
        self.highlightedTier = highlightedTier
        self.onSelectTier = onSelectTier
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Compare Plans")
                .font(.headline)

            // Tier cards - interactive
            VStack(spacing: 12) {
                ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                    Button {
                        selectTier(tier)
                    } label: {
                        TierCard(
                            tier: tier,
                            isHighlighted: tier == highlightedTier,
                            isCurrent: tier == entitlementManager.currentTier
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(tier == entitlementManager.currentTier)
                }
            }
        }
        .sheet(isPresented: $showPricing) {
            PricingView()
        }
    }

    private func selectTier(_ tier: SubscriptionTier) {
        #if DEBUG
        print("[PlanComparisonView] ✅ Tier selected: \(tier.displayName)")
        #endif

        if let handler = onSelectTier {
            handler(tier)
        } else if tier != .free {
            // Default: open pricing for upgrades
            showPricing = true
        }
    }
}

// MARK: - Tier Card

private struct TierCard: View {
    let tier: SubscriptionTier
    let isHighlighted: Bool
    let isCurrent: Bool
    
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
                
                if isHighlighted && !isCurrent {
                    Text("Recommended")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(OKColor.actionPrimary.opacity(0.1))
                        .foregroundColor(OKColor.actionPrimary)
                        .cornerRadius(6)
                }
            }
            
            // Features
            VStack(alignment: .leading, spacing: 6) {
                ForEach(TierFeatures.features(for: tier), id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(OKColor.riskNominal)
                            .font(.caption)
                        Text(feature)
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                }
            }
            
            // Limits
            if let executionLimit = TierQuotas.weeklyExecutionLimit(for: tier) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt")
                        .foregroundColor(OKColor.riskWarning)
                        .font(.caption)
                    Text("\(executionLimit) drafted outcomes/week")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "infinity")
                        .foregroundColor(OKColor.actionPrimary)
                        .font(.caption)
                    Text("Unlimited drafted outcomes")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrent ? OKColor.riskNominal.opacity(0.05) : (isHighlighted ? OKColor.actionPrimary.opacity(0.05) : OKColor.textMuted.opacity(0.05)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrent ? OKColor.riskNominal : (isHighlighted ? OKColor.actionPrimary : Color.clear), lineWidth: isCurrent ? 2 : (isHighlighted ? 2 : 0))
        )
        .opacity(isCurrent ? 0.8 : 1.0)
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

// MARK: - Tier Features

/// Single source of truth for tier features
public enum TierFeatures {
    
    /// Features for each tier
    public static func features(for tier: SubscriptionTier) -> [String] {
        switch tier {
        case .free:
            return [
                "On-device execution",
                "Approval required",
                "Export diagnostics",
                "Basic policy controls"
            ]
            
        case .pro:
            return [
                "Unlimited drafted outcomes",
                "Unlimited memory",
                "Cloud sync (optional)",
                "Quality exports",
                "Advanced diagnostics"
            ]
            
        case .team:
            return [
                "All Pro features",
                "Team governance",
                "Shared policy templates",
                "Shared diagnostics",
                "Team release sign-off"
            ]
        }
    }
    
    /// What's NOT included (for clarity)
    public static func notIncluded(for tier: SubscriptionTier) -> [String] {
        switch tier {
        case .free:
            return [
                "Cloud sync",
                "Team features",
                "Unlimited usage"
            ]
            
        case .pro:
            return [
                "Team governance",
                "Shared artifacts"
            ]
            
        case .team:
            return []  // Team has everything
        }
    }
}

// MARK: - All Cases Extension

extension SubscriptionTier: CaseIterable {
    public static var allCases: [SubscriptionTier] {
        [.free, .pro, .team]
    }
}

// MARK: - Preview

#Preview {
    PlanComparisonView(highlightedTier: .pro)
        .padding()
}
