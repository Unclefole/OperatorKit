import Foundation

// ============================================================================
// PRICING VARIANTS COPY (Phase 10L)
//
// Copy variants for pricing screens. All variants must be App Store safe.
// No anthropomorphic, security, background, or tracking language.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No "AI learns/thinks/decides"
// ❌ No "secure/encrypted" (unproven)
// ❌ No "monitors/tracks/background"
// ❌ No hype language
// ✅ Factual descriptions
// ✅ Clear value propositions
// ✅ Banned word validated
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Pricing Variants Copy

public enum PricingVariantsCopy {
    
    // MARK: - Variant A (Default - Balanced)
    
    public static let variantA = VariantCopySet(
        id: "variant_a",
        name: "Default",
        free: PricingVariantCopy(
            headline: "Start Free",
            subheadline: "No payment required",
            bullets: [
                "25 executions per week",
                "10 saved items",
                "On-device processing",
                "Full privacy guarantees"
            ],
            ctaLabel: "Continue Free",
            privacyNote: "Same privacy as paid tiers"
        ),
        pro: PricingVariantCopy(
            headline: "Go Unlimited",
            subheadline: "Remove all limits",
            bullets: [
                "Unlimited executions",
                "Unlimited saved items",
                "Optional cloud sync",
                "Priority support"
            ],
            ctaLabel: "Upgrade to Pro",
            privacyNote: "On-device by default"
        ),
        team: PricingVariantCopy(
            headline: "For Teams",
            subheadline: "Governance and sharing",
            bullets: [
                "Everything in Pro",
                "Team governance",
                "Shared policy templates",
                "Team diagnostics"
            ],
            ctaLabel: "Upgrade to Team",
            privacyNote: "Team-controlled policies"
        )
    )
    
    // MARK: - Variant B (Value-focused)
    
    public static let variantB = VariantCopySet(
        id: "variant_b",
        name: "Value-focused",
        free: PricingVariantCopy(
            headline: "Try It Out",
            subheadline: "See what you can do",
            bullets: [
                "Draft emails and messages",
                "Create calendar events",
                "Set reminders",
                "Works offline"
            ],
            ctaLabel: "Start Free",
            privacyNote: "No account needed"
        ),
        pro: PricingVariantCopy(
            headline: "Do More",
            subheadline: "No weekly limits",
            bullets: [
                "Draft as many as you need",
                "Save unlimited preferences",
                "Sync across devices (optional)",
                "Export quality reports"
            ],
            ctaLabel: "Get Pro",
            privacyNote: "Cancel anytime"
        ),
        team: PricingVariantCopy(
            headline: "Work Together",
            subheadline: "Shared standards",
            bullets: [
                "All Pro features",
                "Share policies with team",
                "Review team diagnostics",
                "Coordinate quality standards"
            ],
            ctaLabel: "Get Team",
            privacyNote: "Per-seat billing"
        )
    )
    
    // MARK: - Variant C (Privacy-focused)
    
    public static let variantC = VariantCopySet(
        id: "variant_c",
        name: "Privacy-focused",
        free: PricingVariantCopy(
            headline: "Private by Default",
            subheadline: "Your data stays yours",
            bullets: [
                "On-device processing",
                "No data collection",
                "No ads or tracking",
                "Works without internet"
            ],
            ctaLabel: "Try Free",
            privacyNote: "Zero data sent externally"
        ),
        pro: PricingVariantCopy(
            headline: "Private + Powerful",
            subheadline: "Unlimited, still private",
            bullets: [
                "Same privacy guarantees",
                "No usage limits",
                "Optional sync (you control)",
                "Export your data anytime"
            ],
            ctaLabel: "Upgrade for Privacy",
            privacyNote: "Sync is opt-in only"
        ),
        team: PricingVariantCopy(
            headline: "Team Privacy",
            subheadline: "Organizational control",
            bullets: [
                "Privacy at team scale",
                "Shared governance policies",
                "Team diagnostics (no content)",
                "Audit-ready exports"
            ],
            ctaLabel: "Team Privacy Plan",
            privacyNote: "Metadata only, never content"
        )
    )
    
    // MARK: - Copy Access
    
    /// Gets copy for a variant and tier
    public static func copy(for variant: PricingVariant, tier: SubscriptionTier) -> PricingVariantCopy {
        let set = copySet(for: variant)
        switch tier {
        case .free: return set.free
        case .pro: return set.pro
        case .team: return set.team
        }
    }
    
    /// Gets full copy set for a variant
    public static func copySet(for variant: PricingVariant) -> VariantCopySet {
        switch variant {
        case .variantA: return variantA
        case .variantB: return variantB
        case .variantC: return variantC
        }
    }
    
    // MARK: - Validation
    
    /// Validates all variants have no banned words
    public static func validateAllVariants() -> [String] {
        var errors: [String] = []
        
        for variant in PricingVariant.allCases {
            let set = copySet(for: variant)
            
            for tier in SubscriptionTier.allCases {
                let copy = self.copy(for: variant, tier: tier)
                let copyErrors = copy.validate()
                
                errors.append(contentsOf: copyErrors.map { "\(variant.id).\(tier.rawValue): \($0)" })
            }
        }
        
        return errors
    }
}

// MARK: - Variant Copy Set

public struct VariantCopySet {
    public let id: String
    public let name: String
    public let free: PricingVariantCopy
    public let pro: PricingVariantCopy
    public let team: PricingVariantCopy
}

// MARK: - Pricing Variant Copy

public struct PricingVariantCopy {
    public let headline: String
    public let subheadline: String
    public let bullets: [String]
    public let ctaLabel: String
    public let privacyNote: String
    
    /// Validates copy for banned words
    public func validate() -> [String] {
        var errors: [String] = []
        
        let allText = [headline, subheadline, ctaLabel, privacyNote] + bullets
        
        for text in allText {
            // Check PricingCopy banned words
            let violations = PricingCopy.validate(text)
            errors.append(contentsOf: violations)
            
            // Additional checks for variants
            let additionalBanned = [
                "ai learns", "ai thinks", "ai decides", "ai understands",
                "monitors", "tracks", "watches", "collects your",
                "secure", "encrypted", "protected",
                "automatically sends", "background"
            ]
            
            let lowercased = text.lowercased()
            for banned in additionalBanned {
                if lowercased.contains(banned) {
                    errors.append("Contains banned phrase: '\(banned)'")
                }
            }
        }
        
        return errors
    }
}
