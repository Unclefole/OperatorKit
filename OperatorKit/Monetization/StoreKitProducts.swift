import Foundation
import StoreKit

// ============================================================================
// STOREKIT PRODUCTS (Phase 10A)
//
// Single source of truth for product identifiers and display ordering.
// No scattered strings — all product IDs defined here.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking beyond StoreKit
// ❌ No accounts or server receipts
// ❌ Does not affect execution behavior
// ✅ Local-only entitlement resolution
// ✅ StoreKit 2 on-device verification
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

/// Product identifiers for OperatorKit subscriptions
public enum StoreKitProductIDs {
    
    // MARK: - Pro Tier
    
    /// Monthly Pro subscription product ID
    public static let proMonthly = "com.operatorkit.pro.monthly"
    
    /// Annual Pro subscription product ID
    public static let proAnnual = "com.operatorkit.pro.annual"
    
    // MARK: - Lifetime Sovereign (Phase 11C)
    
    /// Lifetime Sovereign one-time purchase product ID
    public static let lifetimeSovereign = "com.operatorkit.lifetime.sovereign"
    
    // MARK: - Team Tier (Phase 10E)
    
    /// Monthly Team subscription product ID
    public static let teamMonthly = "com.operatorkit.team.monthly"
    
    /// Annual Team subscription product ID
    public static let teamAnnual = "com.operatorkit.team.annual"
    
    // MARK: - Product Lists
    
    /// All Pro subscription product IDs
    public static let proSubscriptions: [String] = [
        proMonthly,
        proAnnual
    ]
    
    /// All Team subscription product IDs
    public static let teamSubscriptions: [String] = [
        teamMonthly,
        teamAnnual
    ]
    
    /// All one-time purchase product IDs (Phase 11C)
    public static let oneTimePurchases: [String] = [
        lifetimeSovereign
    ]
    
    /// All subscription product IDs (for fetching)
    public static let allSubscriptions: [String] = proSubscriptions + teamSubscriptions
    
    /// All product IDs (subscriptions + one-time purchases)
    public static let allProducts: [String] = allSubscriptions + oneTimePurchases
    
    /// Display order for subscription options
    public static let displayOrder: [String] = [
        teamAnnual,  // Team best value
        teamMonthly,
        proAnnual,   // Pro best value
        proMonthly,
        lifetimeSovereign  // One-time option at end
    ]
    
    // MARK: - Tier Checking
    
    /// Check if a product ID is a Pro subscription
    public static func isProSubscription(_ productId: String) -> Bool {
        proSubscriptions.contains(productId)
    }
    
    /// Check if a product ID is a Team subscription
    public static func isTeamSubscription(_ productId: String) -> Bool {
        teamSubscriptions.contains(productId)
    }
    
    /// Check if a product ID is a one-time purchase (Phase 11C)
    public static func isOneTimePurchase(_ productId: String) -> Bool {
        oneTimePurchases.contains(productId)
    }
    
    /// Check if a product ID is the Lifetime Sovereign purchase (Phase 11C)
    public static func isLifetimeSovereign(_ productId: String) -> Bool {
        productId == lifetimeSovereign
    }
    
    /// Get the tier for a product ID
    public static func tier(for productId: String) -> SubscriptionTier {
        if isTeamSubscription(productId) {
            return .team
        } else if isProSubscription(productId) || isLifetimeSovereign(productId) {
            return .pro  // Lifetime Sovereign grants Pro tier
        } else {
            return .free
        }
    }
}

// MARK: - Product Display Info

/// Display information for a product
public struct ProductDisplayInfo: Identifiable {
    public let id: String
    public let displayName: String
    public let shortDescription: String
    public let badgeText: String?
    
    public init(id: String, displayName: String, shortDescription: String, badgeText: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.shortDescription = shortDescription
        self.badgeText = badgeText
    }
    
    /// Default display info for known products (fallback if StoreKit unavailable)
    public static func defaultInfo(for productId: String) -> ProductDisplayInfo {
        switch productId {
        case StoreKitProductIDs.proAnnual:
            return ProductDisplayInfo(
                id: productId,
                displayName: "Pro Annual",
                shortDescription: "Billed yearly",
                badgeText: "Best Value"
            )
        case StoreKitProductIDs.proMonthly:
            return ProductDisplayInfo(
                id: productId,
                displayName: "Pro Monthly",
                shortDescription: "Billed monthly",
                badgeText: nil
            )
        case StoreKitProductIDs.lifetimeSovereign:
            return ProductDisplayInfo(
                id: productId,
                displayName: "Lifetime Sovereign",
                shortDescription: "One-time purchase",
                badgeText: "No Subscription"
            )
        case StoreKitProductIDs.teamAnnual:
            return ProductDisplayInfo(
                id: productId,
                displayName: "Team Annual",
                shortDescription: "Procedure sharing, billed yearly",
                badgeText: "Team Best Value"
            )
        case StoreKitProductIDs.teamMonthly:
            return ProductDisplayInfo(
                id: productId,
                displayName: "Team Monthly",
                shortDescription: "Procedure sharing, billed monthly",
                badgeText: nil
            )
        default:
            return ProductDisplayInfo(
                id: productId,
                displayName: "Unknown Product",
                shortDescription: "",
                badgeText: nil
            )
        }
    }
}

// MARK: - StoreKit Product Extensions

@available(iOS 15.0, *)
extension Product {
    
    /// Display name for the subscription period
    var subscriptionPeriodDescription: String {
        guard let period = subscription?.subscriptionPeriod else {
            return ""
        }
        
        switch period.unit {
        case .day:
            return period.value == 1 ? "daily" : "every \(period.value) days"
        case .week:
            return period.value == 1 ? "weekly" : "every \(period.value) weeks"
        case .month:
            return period.value == 1 ? "monthly" : "every \(period.value) months"
        case .year:
            return period.value == 1 ? "annually" : "every \(period.value) years"
        @unknown default:
            return ""
        }
    }
    
    /// Whether this is the annual subscription (for badge display)
    var isAnnualSubscription: Bool {
        id == StoreKitProductIDs.proAnnual
    }
    
    /// Badge text for this product
    var badgeText: String? {
        isAnnualSubscription ? "Best Value" : nil
    }
}
