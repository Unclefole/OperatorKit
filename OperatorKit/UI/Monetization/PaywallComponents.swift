import SwiftUI
import StoreKit

// ============================================================================
// PAYWALL COMPONENTS (Phase 10A)
//
// Reusable UI components for paywall and subscription screens.
// Apple-clean copy, no hype, no "AI thinks" language.
//
// CONSTRAINTS:
// ✅ Accessible (VoiceOver labels)
// ✅ Match existing UI component styles
// ✅ Plain factual copy
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

// MARK: - Feature Row

/// Displays a single feature/benefit row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let isIncluded: Bool
    
    init(icon: String, title: String, description: String, isIncluded: Bool = true) {
        self.icon = icon
        self.title = title
        self.description = description
        self.isIncluded = isIncluded
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isIncluded ? .blue : .gray)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isIncluded ? .primary : .secondary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isIncluded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description). \(isIncluded ? "Included" : "Not included")")
    }
}

// MARK: - Price Badge

/// Displays a product price with optional badge
struct PriceBadge: View {
    let product: Product
    let isSelected: Bool
    let badgeText: String?
    
    init(product: Product, isSelected: Bool = false, badgeText: String? = nil) {
        self.product = product
        self.isSelected = isSelected
        self.badgeText = badgeText ?? product.badgeText
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Badge (if any)
            if let badge = badgeText {
                Text(badge)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(4)
            }
            
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(product.subscriptionPeriodDescription.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(product.displayPrice)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .padding(16)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.displayName), \(product.displayPrice) \(product.subscriptionPeriodDescription). \(badgeText ?? "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Purchase Button

/// Purchase button with loading/disabled/error states
struct PurchaseButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    init(title: String, isLoading: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(isLoading ? "Processing..." : title)
                    .font(.body)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(buttonBackground)
            .cornerRadius(12)
        }
        .disabled(isLoading || isDisabled)
        .accessibilityLabel(isLoading ? "Processing purchase" : title)
        .accessibilityHint(isDisabled ? "Button disabled" : "Double tap to \(title.lowercased())")
    }
    
    private var buttonBackground: Color {
        if isLoading || isDisabled {
            return Color.gray.opacity(0.4)
        }
        return Color.blue
    }
}

// MARK: - Secondary Button

/// Secondary action button (restore, etc.)
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void
    
    init(title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.7)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                }
                
                Text(isLoading ? "Restoring..." : title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.blue)
        }
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? "Restoring purchases" : title)
    }
}

// MARK: - Limit Callout

/// Inline callout when a limit is reached
struct LimitCalloutView: View {
    let decision: LimitDecision
    let onUpgradeTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let reason = decision.reason {
                        Text(reason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let resetTime = decision.formattedResetTime {
                        Text("Resets \(resetTime)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
            
            Button(action: onUpgradeTapped) {
                Text("Upgrade to Pro")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .accessibilityLabel("Upgrade to Pro for unlimited usage")
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var headerText: String {
        switch decision.limitType {
        case .executionsWeekly:
            return "Weekly Limit Reached"
        case .memoryItems:
            return "Storage Limit Reached"
        }
    }
}

// MARK: - Subscription Tier Badge

/// Badge showing current subscription tier
struct SubscriptionTierBadge: View {
    let tier: SubscriptionTier
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tier == .pro ? "star.fill" : "person.fill")
                .font(.system(size: 10))
            
            Text(tier.displayName)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(tier == .pro ? .white : .primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tier == .pro ? Color.blue : Color.gray.opacity(0.2))
        .cornerRadius(4)
        .accessibilityLabel("Current plan: \(tier.displayName)")
    }
}

// MARK: - Privacy Note

/// Privacy disclosure note for paywall
struct PrivacyNoteView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 14))
                .foregroundColor(.green)
            
            Text("No data leaves your device. Payments processed by Apple.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No data leaves your device. Payments processed by Apple.")
    }
}

// MARK: - Preview

#Preview("Feature Row") {
    VStack(spacing: 8) {
        FeatureRow(
            icon: "infinity",
            title: "Unlimited Executions",
            description: "No weekly limits on requests"
        )
        FeatureRow(
            icon: "folder",
            title: "Unlimited Storage",
            description: "Save as many items as you need"
        )
        FeatureRow(
            icon: "star",
            title: "Priority Support",
            description: "Get help faster",
            isIncluded: false
        )
    }
    .padding()
}

#Preview("Purchase Button States") {
    VStack(spacing: 16) {
        PurchaseButton(title: "Subscribe") {}
        PurchaseButton(title: "Subscribe", isLoading: true) {}
        PurchaseButton(title: "Subscribe", isDisabled: true) {}
    }
    .padding()
}

#Preview("Limit Callout") {
    LimitCalloutView(
        decision: .executionLimitReached(resetsAt: Date().addingTimeInterval(86400 * 3)),
        onUpgradeTapped: {}
    )
    .padding()
}
