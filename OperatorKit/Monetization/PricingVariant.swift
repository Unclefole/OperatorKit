import Foundation

// ============================================================================
// PRICING VARIANT (Phase 10L)
//
// Local-only pricing copy variants for conversion optimization.
// No analytics, no networking, no identifiers.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking
// ❌ No analytics SDKs
// ❌ No user identifiers
// ❌ No A/B testing services
// ✅ Local UserDefaults only
// ✅ Copy variants only
// ✅ User can select variant manually
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Pricing Variant

public enum PricingVariant: String, Codable, CaseIterable {
    case variantA = "variant_a"
    case variantB = "variant_b"
    case variantC = "variant_c"
    
    /// Display name for UI
    public var displayName: String {
        switch self {
        case .variantA: return "Variant A (Default)"
        case .variantB: return "Variant B (Value-focused)"
        case .variantC: return "Variant C (Privacy-focused)"
        }
    }
    
    /// Short identifier for exports
    public var id: String {
        rawValue
    }
    
    /// Schema version
    public static let schemaVersion = 1
}

// MARK: - Pricing Variant Store

@MainActor
public final class PricingVariantStore: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = PricingVariantStore()
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let storageKey = "com.operatorkit.pricing.variant"
    
    // MARK: - State
    
    @Published public private(set) var currentVariant: PricingVariant
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        
        // Load saved variant or default to A
        if let saved = defaults.string(forKey: storageKey),
           let variant = PricingVariant(rawValue: saved) {
            self.currentVariant = variant
        } else {
            self.currentVariant = .variantA
        }
    }
    
    // MARK: - Public API
    
    /// Sets the current variant (local-only)
    public func setVariant(_ variant: PricingVariant) {
        currentVariant = variant
        defaults.set(variant.rawValue, forKey: storageKey)
        
        logDebug("Pricing variant set to: \(variant.displayName)", category: .monetization)
    }
    
    /// Resets to default variant
    public func resetToDefault() {
        setVariant(.variantA)
    }
    
    /// Gets variant for a specific tier
    public func variantCopy(for tier: SubscriptionTier) -> PricingVariantCopy {
        PricingVariantsCopy.copy(for: currentVariant, tier: tier)
    }
}
