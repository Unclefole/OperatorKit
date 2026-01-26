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
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundColor(.secondary)
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
                                .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
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
        OnboardingPageTemplate(
            icon: "app.badge.checkmark",
            iconColor: .blue,
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
            iconColor: .green,
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
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.green)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Page 3: Data Access

private struct DataAccessPage: View {
    var body: some View {
        OnboardingPageTemplate(
            icon: "lock.shield",
            iconColor: .orange,
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
                    .foregroundColor(.secondary)
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
                .foregroundColor(.orange)
                .frame(width: 24)
            
            Text(feature)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(access)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Page 4: Choose Plan

private struct ChoosePlanPage: View {
    @Binding var showPricing: Bool
    
    var body: some View {
        OnboardingPageTemplate(
            icon: "star.circle",
            iconColor: .purple,
            title: "Choose Your Plan",
            subtitle: "Start free, upgrade anytime"
        ) {
            VStack(spacing: 16) {
                PlanSummaryCard(
                    tier: .free,
                    highlight: "Start here"
                )
                
                PlanSummaryCard(
                    tier: .pro,
                    highlight: "Most popular"
                )
                
                PlanSummaryCard(
                    tier: .team,
                    highlight: "For teams"
                )
                
                Button {
                    showPricing = true
                    ConversionLedger.shared.recordEvent(.paywallShown)
                } label: {
                    Text("Compare All Plans")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }
        }
    }
}

private struct PlanSummaryCard: View {
    let tier: SubscriptionTier
    let highlight: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tier.displayName)
                        .font(.headline)
                    
                    Text(highlight)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tier == .pro ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .foregroundColor(tier == .pro ? .blue : .secondary)
                        .cornerRadius(4)
                }
                
                Text(TierMatrix.shortDescription(for: tier))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Page 5: Quick Start

private struct QuickStartPage: View {
    var body: some View {
        OnboardingPageTemplate(
            icon: "play.circle",
            iconColor: .blue,
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
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.blue)
                    .textCase(.uppercase)
                
                Text(intent)
                    .font(.subheadline)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.05))
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
                    .foregroundColor(.secondary)
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
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
}
