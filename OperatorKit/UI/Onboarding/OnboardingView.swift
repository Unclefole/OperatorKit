import SwiftUI

// ============================================================================
// ONBOARDING VIEW (Phase 10I)
//
// First-run onboarding that establishes trust and explains the safety model.
// Runs once on first launch, can be re-run from Settings.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No synthetic demo content that looks like real user data
// ❌ No auto-advancing screens
// ❌ No forced purchases
// ✅ Factual explanations only
// ✅ User controls pace
// ✅ Can skip at any point
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var stateStore = OnboardingStateStore.shared
    
    @State private var currentPage: Int = 0
    @State private var showPricing: Bool = false
    
    let onComplete: () -> Void
    
    private let totalPages = 5
    
    var body: some View {
        ZStack {
            // Background - using design system
            OKBackgroundView()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundColor(OKColor.textSecondary)
                    .padding()
                }
                
                // Content
                TabView(selection: $currentPage) {
                    WhatItDoesPage()
                        .tag(0)
                    
                    SafetyModelPage()
                        .tag(1)
                    
                    DataAccessPage()
                        .tag(2)
                    
                    ChoosePlanPage(showPricing: $showPricing)
                        .tag(3)
                    
                    QuickStartPage()
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Navigation
                VStack(spacing: 16) {
                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? OKColor.actionPrimary : OKColor.textMuted.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    // Buttons
                    HStack(spacing: 16) {
                        if currentPage > 0 {
                            Button("Back") {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Spacer()
                        
                        if currentPage < totalPages - 1 {
                            Button("Next") {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Get Started") {
                                completeOnboarding()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showPricing) {
            PricingView()
        }
        .onAppear {
            // Record funnel step (Phase 10L)
            ConversionFunnelManager.shared.recordStep(.onboardingShown)
        }
    }
    
    private func completeOnboarding() {
        stateStore.markCompleted()
        onComplete()
        dismiss()
    }
}

// MARK: - Page 1: What It Does

private struct WhatItDoesPage: View {
    var body: some View {
        OnboardingPageTemplateWithLogo(
            title: "Welcome to OperatorKit",
            subtitle: "Your on-device productivity assistant"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                BulletPoint(
                    icon: "envelope",
                    text: "Draft emails and messages"
                )
                
                BulletPoint(
                    icon: "calendar",
                    text: "Create calendar events"
                )
                
                BulletPoint(
                    icon: "checklist",
                    text: "Set reminders and tasks"
                )
                
                BulletPoint(
                    icon: "iphone",
                    text: "Everything runs on your device"
                )
            }
        }
    }
}

// MARK: - Page 2: Safety Model

private struct SafetyModelPage: View {
    var body: some View {
        OnboardingPageTemplate(
            icon: "shield.checkered",
            iconColor: OKColor.riskNominal,
            title: "You're Always in Control",
            subtitle: "Nothing happens without your approval"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                SafetyRow(
                    number: 1,
                    title: "Draft First",
                    description: "Every action is prepared as a draft for you to review"
                )
                
                SafetyRow(
                    number: 2,
                    title: "Approval Required",
                    description: "You must approve each draft before it runs"
                )
                
                SafetyRow(
                    number: 3,
                    title: "No Autonomous Actions",
                    description: "OperatorKit never acts without your explicit OK"
                )
            }
        }
    }
}

private struct SafetyRow: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(OKColor.textPrimary)
                .frame(width: 28, height: 28)
                .background(OKColor.riskNominal)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
    }
}

// MARK: - Page 3: Data Access

private struct DataAccessPage: View {
    var body: some View {
        OnboardingPageTemplate(
            icon: "lock.shield",
            iconColor: OKColor.riskWarning,
            title: "Data Access",
            subtitle: "You choose what OperatorKit can access"
        ) {
            VStack(spacing: 12) {
                DataAccessRow(
                    feature: "Calendar",
                    access: "Only when you create an event",
                    icon: "calendar"
                )
                
                DataAccessRow(
                    feature: "Reminders",
                    access: "Only when you create a task",
                    icon: "checklist"
                )
                
                DataAccessRow(
                    feature: "Siri",
                    access: "Only if you enable Shortcuts",
                    icon: "mic"
                )
                
                DataAccessRow(
                    feature: "Network",
                    access: "Only for optional cloud sync",
                    icon: "network"
                )
                
                Text("Permissions are requested only when needed, never upfront.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
                    .padding(.top, 8)
            }
        }
    }
}

private struct DataAccessRow: View {
    let feature: String
    let access: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(OKColor.riskWarning)
                .frame(width: 24)
            
            Text(feature)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(access)
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(OKColor.textMuted.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Page 4: Choose Plan

private struct ChoosePlanPage: View {
    @Binding var showPricing: Bool
    @State private var selectedPlan: SubscriptionTier = .free

    var body: some View {
        OnboardingPageTemplate(
            icon: "star.circle",
            iconColor: OKColor.riskExtreme,
            title: "Choose Your Plan",
            subtitle: "Start free, upgrade anytime"
        ) {
            VStack(spacing: 16) {
                // Free - always tappable, no StoreKit dependency
                Button {
                    selectedPlan = .free
                    #if DEBUG
                    print("[Onboarding] ✅ Selected plan: Free")
                    #endif
                } label: {
                    PlanSummaryCard(
                        tier: .free,
                        highlight: "Start here",
                        isSelected: selectedPlan == .free
                    )
                }
                .buttonStyle(.plain)

                // Pro
                Button {
                    selectedPlan = .pro
                    #if DEBUG
                    print("[Onboarding] ✅ Selected plan: Pro")
                    #endif
                } label: {
                    PlanSummaryCard(
                        tier: .pro,
                        highlight: "Most popular",
                        isSelected: selectedPlan == .pro
                    )
                }
                .buttonStyle(.plain)

                // Team
                Button {
                    selectedPlan = .team
                    #if DEBUG
                    print("[Onboarding] ✅ Selected plan: Team")
                    #endif
                } label: {
                    PlanSummaryCard(
                        tier: .team,
                        highlight: "For teams",
                        isSelected: selectedPlan == .team
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showPricing = true
                    ConversionLedger.shared.recordEvent(.paywallShown)
                } label: {
                    Text("Compare All Plans")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)

                // Info text
                if selectedPlan == .free {
                    Text("Free includes 5 drafted outcomes per week. Upgrade anytime.")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("You can complete purchase after onboarding.")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

private struct PlanSummaryCard: View {
    let tier: SubscriptionTier
    let highlight: String
    let isSelected: Bool

    var body: some View {
        HStack {
            // Selection indicator
            ZStack {
                Circle()
                    .stroke(isSelected ? OKColor.actionPrimary : OKColor.textMuted.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)

                if isSelected {
                    Circle()
                        .fill(OKColor.actionPrimary)
                        .frame(width: 14, height: 14)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tier.displayName)
                        .font(.headline)
                        .foregroundColor(OKColor.textPrimary)

                    Text(highlight)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tier == .pro ? OKColor.actionPrimary.opacity(0.1) : OKColor.textMuted.opacity(0.1))
                        .foregroundColor(tier == .pro ? OKColor.actionPrimary : .secondary)
                        .cornerRadius(4)
                }

                Text(TierMatrix.shortDescription(for: tier))
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(OKColor.actionPrimary)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(OKColor.textMuted)
            }
        }
        .padding()
        .background(isSelected ? OKColor.actionPrimary.opacity(0.05) : OKColor.textMuted.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? OKColor.actionPrimary : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Page 5: Quick Start

private struct QuickStartPage: View {
    var body: some View {
        OnboardingPageTemplate(
            icon: "play.circle",
            iconColor: OKColor.actionPrimary,
            title: "Quick Start",
            subtitle: "Try these sample requests"
        ) {
            VStack(spacing: 12) {
                SampleIntentCard(
                    intent: "Draft an email to schedule a meeting tomorrow",
                    category: "Email"
                )
                
                SampleIntentCard(
                    intent: "Create a reminder to call back in 2 hours",
                    category: "Reminder"
                )
                
                SampleIntentCard(
                    intent: "Add lunch with Sarah to my calendar Friday",
                    category: "Calendar"
                )
                
                Text("Type any request in plain language. You'll always review before it runs.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
    }
}

private struct SampleIntentCard: View {
    let intent: String
    let category: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category)
                    .font(.caption)
                    .foregroundColor(OKColor.actionPrimary)
                    .textCase(.uppercase)
                
                Text(intent)
                    .font(.subheadline)
            }
            
            Spacer()
        }
        .padding()
        .background(OKColor.actionPrimary.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Template

private struct OnboardingPageTemplate<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(iconColor)
            
            // Text
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            // Content
            content
                .padding(.horizontal)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

private struct BulletPoint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(OKColors.operatorGradient)
                .frame(width: 24)

            Text(text)
                .font(OKTypography.subheadline())
                .foregroundColor(OKColors.textPrimary)
        }
    }
}

// MARK: - Template with Logo (Welcome Page)

private struct OnboardingPageTemplateWithLogo<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // OperatorKit Logo
            OperatorKitLogoView(size: .extraLarge, showText: true)

            // Text
            VStack(spacing: 8) {
                Text(title)
                    .font(OKTypography.title())
                    .foregroundColor(OKColors.textPrimary)

                Text(subtitle)
                    .font(OKTypography.subheadline())
                    .foregroundColor(OKColors.textSecondary)
            }

            // Content
            content
                .padding(.horizontal)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
}
