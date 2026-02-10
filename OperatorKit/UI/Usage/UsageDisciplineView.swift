import SwiftUI

// ============================================================================
// USAGE DISCIPLINE VIEW (Phase 10F)
//
// User-facing view for usage patterns, limits, and rate shaping feedback.
// Honest, non-punitive messaging.
//
// CONSTRAINTS:
// ❌ No moralizing
// ❌ No threats
// ❌ No blame language
// ✅ Factual information
// ✅ Clear limits
// ✅ Helpful suggestions
//
// See: docs/SAFETY_CONTRACT.md (Section 15)
// ============================================================================

// MARK: - Paywall Gate (Inlined)
// Paywall ENABLED for App Store release
private let _usagePaywallEnabled: Bool = true

struct UsageDisciplineView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rateShaper = RateShaper.shared
    @StateObject private var costIndicator = CostIndicator.shared
    @StateObject private var entitlementManager = EntitlementManager.shared
    
    var body: some View {
        NavigationView {
            List {
                // Current intensity
                intensitySection
                
                // Usage summary
                usageSummarySection
                
                // Rate shaping info
                rateShapingSection
                
                // Tier info
                tierInfoSection
                
                // Guidance
                guidanceSection
                
                // Upgrade (Phase 10G)
                if entitlementManager.currentTier == .free {
                    upgradeSection
                }
            }
            .navigationTitle("Usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingUpgrade) {
                if _usagePaywallEnabled {
                    UpgradeView()
                } else {
                    // Fallback: Never show blank screen
                    ProComingSoonView(isPresented: $showingUpgrade)
                }
            }
        }
    }
    
    // MARK: - Intensity Section
    
    private var intensitySection: some View {
        Section {
            HStack(spacing: 16) {
                intensityIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Intensity")
                        .font(.headline)
                    Text(rateShaper.currentIntensity.description)
                        .font(.subheadline)
                        .foregroundColor(OKColor.textSecondary)
                }
                
                Spacer()
                
                Text(rateShaper.currentIntensity.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(intensityColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(intensityColor.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.vertical, 8)
        }
    }
    
    private var intensityIcon: some View {
        Image(systemName: intensityIconName)
            .font(.system(size: 28))
            .foregroundColor(intensityColor)
            .frame(width: 44, height: 44)
            .background(intensityColor.opacity(0.1))
            .cornerRadius(12)
    }
    
    private var intensityIconName: String {
        switch rateShaper.currentIntensity {
        case .low: return "leaf"
        case .normal: return "chart.bar"
        case .elevated: return "chart.bar.fill"
        case .heavy: return "flame"
        }
    }
    
    private var intensityColor: Color {
        switch rateShaper.currentIntensity {
        case .low: return OKColor.riskNominal
        case .normal: return OKColor.actionPrimary
        case .elevated: return OKColor.riskWarning
        case .heavy: return OKColor.riskCritical
        }
    }
    
    // MARK: - Usage Summary
    
    private var usageSummarySection: some View {
        Section {
            usageRow(
                label: "Executions today",
                value: "\(rateShaper.executionsToday)"
            )
            
            usageRow(
                label: "Executions this hour",
                value: "\(rateShaper.executionsLastHour)"
            )
            
            usageRow(
                label: "Usage units today",
                value: costIndicator.unitsToday.displayString
            )
            
            usageRow(
                label: "Usage units this week",
                value: costIndicator.unitsThisWeek.displayString
            )
        } header: {
            Text("Usage Summary")
        } footer: {
            Text("Usage units are approximate and for your reference only.")
        }
    }
    
    private func usageRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(OKColor.textSecondary)
        }
    }
    
    // MARK: - Rate Shaping Section
    
    private var rateShapingSection: some View {
        Section {
            if let cooldown = rateShaper.cooldownRemaining {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(OKColor.riskWarning)
                    Text("Cooldown")
                    Spacer()
                    Text("\(Int(cooldown))s remaining")
                        .foregroundColor(OKColor.riskWarning)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(OKColor.riskNominal)
                    Text("Ready")
                    Spacer()
                    Text("No cooldown")
                        .foregroundColor(OKColor.riskNominal)
                }
            }
            
            if let message = rateShaper.lastRateShapeMessage {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundColor(OKColor.actionPrimary)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
        } header: {
            Text("Rate Shaping")
        } footer: {
            Text("Rate shaping helps maintain consistent performance and prevents accidental overuse.")
        }
    }
    
    // MARK: - Tier Info Section
    
    private var tierInfoSection: some View {
        Section {
            HStack {
                Image(systemName: tierIcon)
                    .foregroundColor(tierColor)
                Text("Current Tier")
                Spacer()
                Text(entitlementManager.currentTier.displayName)
                    .fontWeight(.medium)
                    .foregroundColor(tierColor)
            }
            
            if let limit = TierBoundaryChecker.TierLimits.limit(for: entitlementManager.currentTier) {
                HStack {
                    Image(systemName: "number.circle")
                        .foregroundColor(OKColor.textSecondary)
                    Text("Weekly Limit")
                    Spacer()
                    Text("\(limit) executions")
                        .foregroundColor(OKColor.textSecondary)
                }
            } else {
                HStack {
                    Image(systemName: "infinity.circle")
                        .foregroundColor(OKColor.actionPrimary)
                    Text("Weekly Limit")
                    Spacer()
                    Text("Unlimited")
                        .foregroundColor(OKColor.actionPrimary)
                }
            }
        } header: {
            Text("Subscription")
        }
    }
    
    private var tierIcon: String {
        switch entitlementManager.currentTier {
        case .free: return "person.circle"
        case .pro: return "star.circle"
        case .team: return "person.3.fill"
        }
    }
    
    private var tierColor: Color {
        switch entitlementManager.currentTier {
        case .free: return OKColor.textMuted
        case .pro: return OKColor.actionPrimary
        case .team: return OKColor.riskWarning
        }
    }
    
    // MARK: - Guidance Section
    
    private var guidanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                guidanceRow(
                    icon: "lightbulb",
                    text: "Take breaks between complex actions"
                )
                guidanceRow(
                    icon: "arrow.triangle.branch",
                    text: "Vary your requests to explore different outcomes"
                )
                guidanceRow(
                    icon: "clock.arrow.circlepath",
                    text: "Rate limits reset weekly"
                )
            }
            .padding(.vertical, 4)
        } header: {
            Text("Suggestions")
        } footer: {
            Text("These are suggestions to help you get the most out of OperatorKit.")
        }
    }
    
    // MARK: - Upgrade Section (Phase 10G)
    
    private var upgradeSection: some View {
        Section {
            if entitlementManager.currentTier == .free {
                Button {
                    showingUpgrade = true
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(OKColor.actionPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Pro")
                                .foregroundColor(OKColor.textPrimary)
                            Text("Unlimited executions and memory")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(OKColor.textMuted)
                    }
                }
            }
        } header: {
            Text("Subscription")
        } footer: {
            Text(WhyWeChargeText.shortExplanation)
        }
    }
    
    @State private var showingUpgrade = false
    
    private func guidanceRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(OKColor.actionPrimary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    UsageDisciplineView()
}
