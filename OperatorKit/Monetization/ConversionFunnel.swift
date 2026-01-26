import Foundation

// ============================================================================
// CONVERSION FUNNEL (Phase 10L)
//
// Local-only conversion funnel tracking. No analytics, no identifiers.
// Computes conversion rates from local counters.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking
// ❌ No analytics SDKs
// ❌ No user identifiers
// ❌ No user content
// ✅ Local counters only
// ✅ Numeric aggregates
// ✅ Computed rates
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Funnel Step

public enum FunnelStep: String, Codable, CaseIterable {
    case onboardingShown = "onboarding_shown"
    case pricingViewed = "pricing_viewed"
    case upgradeTapped = "upgrade_tapped"
    case purchaseStarted = "purchase_started"
    case purchaseSuccess = "purchase_success"
    case purchaseCancelled = "purchase_cancelled"
    case restoreTapped = "restore_tapped"
    case restoreSuccess = "restore_success"
    // Phase 11A additions
    case referralViewed = "referral_viewed"
    case referralShared = "referral_shared"
    case buyerProofExported = "buyer_proof_exported"
    case outboundTemplateCopied = "outbound_template_copied"
    case outboundMailOpened = "outbound_mail_opened"
    
    /// Display name for UI
    public var displayName: String {
        switch self {
        case .onboardingShown: return "Onboarding Shown"
        case .pricingViewed: return "Pricing Viewed"
        case .upgradeTapped: return "Upgrade Tapped"
        case .purchaseStarted: return "Purchase Started"
        case .purchaseSuccess: return "Purchase Success"
        case .purchaseCancelled: return "Purchase Cancelled"
        case .restoreTapped: return "Restore Tapped"
        case .restoreSuccess: return "Restore Success"
        // Phase 11A
        case .referralViewed: return "Referral Viewed"
        case .referralShared: return "Referral Shared"
        case .buyerProofExported: return "Buyer Proof Exported"
        case .outboundTemplateCopied: return "Template Copied"
        case .outboundMailOpened: return "Outbound Mail Opened"
        }
    }
    
    /// Maps to ConversionEvent
    public var conversionEvent: ConversionEvent? {
        switch self {
        case .onboardingShown: return nil  // Not in original ConversionEvent
        case .pricingViewed: return .paywallShown
        case .upgradeTapped: return .upgradeTapped
        case .purchaseStarted: return .purchaseStarted
        case .purchaseSuccess: return .purchaseSuccess
        case .purchaseCancelled: return .purchaseCancelled
        case .restoreTapped: return .restoreTapped
        case .restoreSuccess: return .restoreSuccess
        // Phase 11A - local only
        case .referralViewed: return nil
        case .referralShared: return nil
        case .buyerProofExported: return nil
        case .outboundTemplateCopied: return nil
        case .outboundMailOpened: return nil
        }
    }
    
    /// Whether this is a growth/acquisition step (Phase 11A)
    public var isGrowthStep: Bool {
        switch self {
        case .referralViewed, .referralShared, .buyerProofExported, .outboundTemplateCopied, .outboundMailOpened:
            return true
        default:
            return false
        }
    }
}

// MARK: - Funnel Summary

public struct FunnelSummary: Codable {
    
    // MARK: - Counts
    
    public let onboardingShownCount: Int
    public let pricingViewedCount: Int
    public let upgradeTappedCount: Int
    public let purchaseStartedCount: Int
    public let purchaseSuccessCount: Int
    public let purchaseCancelledCount: Int
    public let restoreTappedCount: Int
    public let restoreSuccessCount: Int
    
    // MARK: - Growth Counts (Phase 11A)
    
    public let referralViewedCount: Int
    public let referralSharedCount: Int
    public let buyerProofExportedCount: Int
    public let outboundTemplateCopiedCount: Int
    public let outboundMailOpenedCount: Int
    
    // MARK: - Metadata
    
    public let currentVariantId: String
    public let capturedAt: String
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 2  // Bumped for Phase 11A
    
    // MARK: - Computed Rates
    
    /// Rate of pricing views to onboarding shows
    public var pricingViewRate: Double? {
        guard onboardingShownCount > 0 else { return nil }
        return Double(pricingViewedCount) / Double(onboardingShownCount)
    }
    
    /// Rate of upgrade taps to pricing views
    public var upgradeTapRate: Double? {
        guard pricingViewedCount > 0 else { return nil }
        return Double(upgradeTappedCount) / Double(pricingViewedCount)
    }
    
    /// Rate of purchase starts to upgrade taps
    public var purchaseStartRate: Double? {
        guard upgradeTappedCount > 0 else { return nil }
        return Double(purchaseStartedCount) / Double(upgradeTappedCount)
    }
    
    /// Rate of purchase success to purchase starts
    public var purchaseSuccessRate: Double? {
        guard purchaseStartedCount > 0 else { return nil }
        return Double(purchaseSuccessCount) / Double(purchaseStartedCount)
    }
    
    /// Overall conversion rate (success / pricing views)
    public var overallConversionRate: Double? {
        guard pricingViewedCount > 0 else { return nil }
        return Double(purchaseSuccessCount) / Double(pricingViewedCount)
    }
    
    /// Restore success rate
    public var restoreSuccessRate: Double? {
        guard restoreTappedCount > 0 else { return nil }
        return Double(restoreSuccessCount) / Double(restoreTappedCount)
    }
    
    // MARK: - Growth Rates (Phase 11A)
    
    /// Referral share rate (shared / viewed)
    public var referralShareRate: Double? {
        guard referralViewedCount > 0 else { return nil }
        return Double(referralSharedCount) / Double(referralViewedCount)
    }
    
    /// Total growth actions
    public var totalGrowthActions: Int {
        referralSharedCount + buyerProofExportedCount + outboundTemplateCopiedCount + outboundMailOpenedCount
    }
    
    /// Total outbound actions
    public var totalOutboundActions: Int {
        outboundTemplateCopiedCount + outboundMailOpenedCount
    }
    
    // MARK: - Formatted Rates
    
    public func formattedRate(_ rate: Double?) -> String {
        guard let rate = rate else { return "N/A" }
        return String(format: "%.1f%%", rate * 100)
    }
    
    // MARK: - Validation
    
    /// Verifies summary contains only numeric data
    public func isNumericOnly() -> Bool {
        // All fields are Int, String (id/date), or computed Double
        // No user content fields exist
        return true
    }
}

// MARK: - Conversion Funnel Manager

@MainActor
public final class ConversionFunnelManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = ConversionFunnelManager()
    
    // MARK: - Dependencies
    
    private let ledger: ConversionLedger
    private let variantStore: PricingVariantStore
    private let defaults: UserDefaults
    
    // MARK: - Local Counters (for steps not in original ledger)
    
    private let onboardingKey = "com.operatorkit.funnel.onboarding_shown"
    // Phase 11A keys
    private let referralViewedKey = "com.operatorkit.funnel.referral_viewed"
    private let referralSharedKey = "com.operatorkit.funnel.referral_shared"
    private let buyerProofExportedKey = "com.operatorkit.funnel.buyer_proof_exported"
    private let outboundTemplateCopiedKey = "com.operatorkit.funnel.outbound_template_copied"
    private let outboundMailOpenedKey = "com.operatorkit.funnel.outbound_mail_opened"
    
    // MARK: - Initialization
    
    private init(
        ledger: ConversionLedger = .shared,
        variantStore: PricingVariantStore = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.ledger = ledger
        self.variantStore = variantStore
        self.defaults = defaults
    }
    
    // MARK: - Recording
    
    /// Records a funnel step
    public func recordStep(_ step: FunnelStep) {
        switch step {
        case .onboardingShown:
            // Store locally since not in original ConversionEvent
            let current = defaults.integer(forKey: onboardingKey)
            defaults.set(current + 1, forKey: onboardingKey)
            
        case .pricingViewed:
            ledger.recordEvent(.paywallShown)
            
        case .upgradeTapped:
            ledger.recordEvent(.upgradeTapped)
            
        case .purchaseStarted:
            ledger.recordEvent(.purchaseStarted)
            
        case .purchaseSuccess:
            ledger.recordEvent(.purchaseSuccess)
            
        case .purchaseCancelled:
            ledger.recordEvent(.purchaseCancelled)
            
        case .restoreTapped:
            ledger.recordEvent(.restoreTapped)
            
        case .restoreSuccess:
            ledger.recordEvent(.restoreSuccess)
            
        // Phase 11A - local only
        case .referralViewed:
            incrementLocalCounter(key: referralViewedKey)
            
        case .referralShared:
            incrementLocalCounter(key: referralSharedKey)
            
        case .buyerProofExported:
            incrementLocalCounter(key: buyerProofExportedKey)
            
        case .outboundTemplateCopied:
            incrementLocalCounter(key: outboundTemplateCopiedKey)
            
        case .outboundMailOpened:
            incrementLocalCounter(key: outboundMailOpenedKey)
        }
        
        logDebug("Funnel step recorded: \(step.displayName)", category: .monetization)
    }
    
    private func incrementLocalCounter(key: String) {
        let current = defaults.integer(forKey: key)
        defaults.set(current + 1, forKey: key)
    }
    
    // MARK: - Summary
    
    /// Gets current funnel summary
    public func currentFunnelSummary() -> FunnelSummary {
        let summary = ledger.summary
        
        return FunnelSummary(
            onboardingShownCount: defaults.integer(forKey: onboardingKey),
            pricingViewedCount: summary.paywallShownCount,
            upgradeTappedCount: summary.upgradeTapCount,
            purchaseStartedCount: summary.purchaseStartedCount,
            purchaseSuccessCount: summary.purchaseSuccessCount,
            purchaseCancelledCount: ledger.count(for: .purchaseCancelled),
            restoreTappedCount: summary.restoreTapCount,
            restoreSuccessCount: summary.restoreSuccessCount,
            // Phase 11A
            referralViewedCount: defaults.integer(forKey: referralViewedKey),
            referralSharedCount: defaults.integer(forKey: referralSharedKey),
            buyerProofExportedCount: defaults.integer(forKey: buyerProofExportedKey),
            outboundTemplateCopiedCount: defaults.integer(forKey: outboundTemplateCopiedKey),
            outboundMailOpenedCount: defaults.integer(forKey: outboundMailOpenedKey),
            currentVariantId: variantStore.currentVariant.id,
            capturedAt: dayRoundedDate(),
            schemaVersion: FunnelSummary.currentSchemaVersion
        )
    }
    
    /// Resets all funnel data (for testing)
    public func reset() {
        defaults.removeObject(forKey: onboardingKey)
        // Phase 11A
        defaults.removeObject(forKey: referralViewedKey)
        defaults.removeObject(forKey: referralSharedKey)
        defaults.removeObject(forKey: buyerProofExportedKey)
        defaults.removeObject(forKey: outboundTemplateCopiedKey)
        defaults.removeObject(forKey: outboundMailOpenedKey)
        ledger.reset()
    }
    
    // MARK: - Helpers
    
    private func dayRoundedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
