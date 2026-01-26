import Foundation

// ============================================================================
// SUBSCRIPTION STATE (Phase 10A)
//
// Defines subscription tiers and status structures.
// Content-free metadata only — no user data.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content storage
// ❌ Does not affect execution behavior
// ✅ Metadata-only
// ✅ Local resolution
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

// MARK: - Subscription Tier

/// Subscription tier levels
public enum SubscriptionTier: String, Codable, Equatable {
    /// Free tier with usage limits
    case free = "free"
    
    /// Pro tier with unlimited usage
    case pro = "pro"
    
    /// Team tier with governance sharing (Phase 10E)
    case team = "team"
    
    /// Display name for the tier
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .team: return "Team"
        }
    }
    
    /// Whether this tier has unlimited executions
    public var hasUnlimitedExecutions: Bool {
        self == .pro || self == .team
    }
    
    /// Whether this tier has unlimited memory storage
    public var hasUnlimitedMemory: Bool {
        self == .pro || self == .team
    }
    
    /// Whether this tier has team features (Phase 10E)
    public var hasTeamFeatures: Bool {
        self == .team
    }
    
    /// Whether this tier has cloud sync (Phase 10D)
    public var hasCloudSync: Bool {
        self == .pro || self == .team
    }
}

// MARK: - Subscription Status

/// Current subscription status (content-free metadata)
public struct SubscriptionStatus: Codable, Equatable {
    
    /// Current tier
    public let tier: SubscriptionTier
    
    /// Whether subscription is currently active
    public let isActive: Bool
    
    /// Renewal date (if subscribed, nil for lifetime)
    public let renewalDate: Date?
    
    /// Product ID of current subscription (if any)
    public let productId: String?
    
    /// When this status was last verified
    public let lastCheckedAt: Date
    
    /// Whether this is a lifetime purchase (Phase 11C)
    public let isLifetime: Bool
    
    /// Schema version for migration
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 2  // Bumped for Phase 11C
    
    // MARK: - Initialization
    
    public init(
        tier: SubscriptionTier,
        isActive: Bool,
        renewalDate: Date?,
        productId: String?,
        lastCheckedAt: Date = Date(),
        isLifetime: Bool = false
    ) {
        self.tier = tier
        self.isActive = isActive
        self.renewalDate = renewalDate
        self.productId = productId
        self.lastCheckedAt = lastCheckedAt
        self.isLifetime = isLifetime
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    /// Default free status
    public static var free: SubscriptionStatus {
        SubscriptionStatus(
            tier: .free,
            isActive: false,
            renewalDate: nil,
            productId: nil
        )
    }
    
    /// Create Pro status from StoreKit data
    public static func pro(productId: String, renewalDate: Date?) -> SubscriptionStatus {
        SubscriptionStatus(
            tier: .pro,
            isActive: true,
            renewalDate: renewalDate,
            productId: productId
        )
    }
    
    /// Create Lifetime Sovereign status (Phase 11C)
    public static func lifetimeSovereign(productId: String) -> SubscriptionStatus {
        SubscriptionStatus(
            tier: .pro,  // Grants Pro tier
            isActive: true,
            renewalDate: nil,  // No renewal for lifetime
            productId: productId,
            isLifetime: true
        )
    }
    
    /// Create Team status from StoreKit data (Phase 10E)
    public static func team(productId: String, renewalDate: Date?) -> SubscriptionStatus {
        SubscriptionStatus(
            tier: .team,
            isActive: true,
            renewalDate: renewalDate,
            productId: productId
        )
    }
    
    // MARK: - Display Helpers
    
    /// Formatted renewal date for display
    public var formattedRenewalDate: String? {
        guard let date = renewalDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Subscription period description (monthly/annual/lifetime)
    public var periodDescription: String? {
        guard let productId = productId else { return nil }
        switch productId {
        case StoreKitProductIDs.proMonthly, StoreKitProductIDs.teamMonthly:
            return "Monthly"
        case StoreKitProductIDs.proAnnual, StoreKitProductIDs.teamAnnual:
            return "Annual"
        case StoreKitProductIDs.lifetimeSovereign:
            return "Lifetime"
        default:
            return nil
        }
    }
    
    /// Display label for subscription type (Phase 11C)
    public var subscriptionTypeLabel: String {
        if isLifetime {
            return "Lifetime Sovereign"
        } else if isActive {
            return tier.displayName
        } else {
            return "Free"
        }
    }
    
    /// Whether the status needs refresh (older than 1 hour)
    public var needsRefresh: Bool {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return lastCheckedAt < oneHourAgo
    }
}

// MARK: - Purchase State

/// State of a purchase operation
public enum PurchaseState: Equatable {
    case idle
    case purchasing
    case restoring
    case success(productId: String)
    case failed(message: String)
    case cancelled
    
    public var isLoading: Bool {
        switch self {
        case .purchasing, .restoring:
            return true
        default:
            return false
        }
    }
    
    public var errorMessage: String? {
        if case .failed(let message) = self {
            return message
        }
        return nil
    }
}

// MARK: - Subscription Error

/// Errors that can occur during subscription operations
public enum SubscriptionError: Error, LocalizedError {
    case productNotFound
    case purchaseFailed(underlying: Error?)
    case verificationFailed
    case userCancelled
    case storeKitUnavailable
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not available. Please try again later."
        case .purchaseFailed:
            return "Purchase could not be completed."
        case .verificationFailed:
            return "Could not verify purchase. Please try again."
        case .userCancelled:
            return nil // Not an error to show
        case .storeKitUnavailable:
            return "App Store is not available."
        case .unknown:
            return "An unexpected error occurred."
        }
    }
    
    /// User-facing message (plain, no hype)
    public var userMessage: String {
        errorDescription ?? "An error occurred."
    }
}
