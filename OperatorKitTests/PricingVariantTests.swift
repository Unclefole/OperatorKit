import XCTest
@testable import OperatorKit

// ============================================================================
// PRICING VARIANT TESTS (Phase 10L)
//
// Tests for pricing copy variants:
// - Variants have no banned words
// - Variants are App Store safe
// - Default variant is A
// - All variants are complete
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class PricingVariantTests: XCTestCase {
    
    // MARK: - A) Variant Safety
    
    /// Verifies all variants have no banned words
    func testVariantsHaveNoBannedWords() {
        let errors = PricingVariantsCopy.validateAllVariants()
        
        XCTAssertTrue(
            errors.isEmpty,
            "Variant copy has banned words: \(errors.joined(separator: ", "))"
        )
    }
    
    /// Verifies variants are App Store safe (no anthropomorphic language)
    func testVariantsAreAppStoreSafe() {
        let anthropomorphicPatterns = [
            "ai thinks", "ai learns", "ai decides", "ai understands",
            "smart ai", "intelligent ai"
        ]
        
        for variant in PricingVariant.allCases {
            for tier in SubscriptionTier.allCases {
                let copy = PricingVariantsCopy.copy(for: variant, tier: tier)
                let allText = [copy.headline, copy.subheadline, copy.ctaLabel, copy.privacyNote]
                    .joined(separator: " ") + copy.bullets.joined(separator: " ")
                let lowercased = allText.lowercased()
                
                for pattern in anthropomorphicPatterns {
                    XCTAssertFalse(
                        lowercased.contains(pattern),
                        "Variant \(variant.id).\(tier.rawValue) contains '\(pattern)'"
                    )
                }
            }
        }
    }
    
    /// Verifies variants have no security claims
    func testVariantsHaveNoSecurityClaims() {
        let securityPatterns = ["secure", "encrypted", "protected", "unhackable"]
        
        for variant in PricingVariant.allCases {
            for tier in SubscriptionTier.allCases {
                let copy = PricingVariantsCopy.copy(for: variant, tier: tier)
                let allText = [copy.headline, copy.subheadline, copy.ctaLabel]
                    .joined(separator: " ") + copy.bullets.joined(separator: " ")
                let lowercased = allText.lowercased()
                
                for pattern in securityPatterns {
                    XCTAssertFalse(
                        lowercased.contains(pattern),
                        "Variant \(variant.id).\(tier.rawValue) contains security claim '\(pattern)'"
                    )
                }
            }
        }
    }
    
    /// Verifies variants have no background/tracking language
    func testVariantsHaveNoBackgroundLanguage() {
        let backgroundPatterns = [
            "monitors", "tracks", "runs in background", "watches",
            "automatically sends", "collects your"
        ]
        
        for variant in PricingVariant.allCases {
            for tier in SubscriptionTier.allCases {
                let copy = PricingVariantsCopy.copy(for: variant, tier: tier)
                let allText = [copy.headline, copy.subheadline, copy.privacyNote]
                    .joined(separator: " ") + copy.bullets.joined(separator: " ")
                let lowercased = allText.lowercased()
                
                for pattern in backgroundPatterns {
                    XCTAssertFalse(
                        lowercased.contains(pattern),
                        "Variant \(variant.id).\(tier.rawValue) contains background language '\(pattern)'"
                    )
                }
            }
        }
    }
    
    // MARK: - B) Default Variant
    
    /// Verifies default variant is A
    func testDefaultVariantIsA() async {
        let store = await PricingVariantStore.shared
        
        // Reset to ensure clean state
        await store.resetToDefault()
        
        let current = await store.currentVariant
        XCTAssertEqual(current, .variantA, "Default variant should be A")
    }
    
    // MARK: - C) Variant Completeness
    
    /// Verifies all variants have all tiers
    func testAllVariantsHaveAllTiers() {
        for variant in PricingVariant.allCases {
            let set = PricingVariantsCopy.copySet(for: variant)
            
            // Verify all fields are non-empty
            XCTAssertFalse(set.free.headline.isEmpty, "\(variant.id) free headline is empty")
            XCTAssertFalse(set.pro.headline.isEmpty, "\(variant.id) pro headline is empty")
            XCTAssertFalse(set.team.headline.isEmpty, "\(variant.id) team headline is empty")
            
            XCTAssertFalse(set.free.bullets.isEmpty, "\(variant.id) free bullets is empty")
            XCTAssertFalse(set.pro.bullets.isEmpty, "\(variant.id) pro bullets is empty")
            XCTAssertFalse(set.team.bullets.isEmpty, "\(variant.id) team bullets is empty")
        }
    }
    
    /// Verifies all variants have privacy notes
    func testAllVariantsHavePrivacyNotes() {
        for variant in PricingVariant.allCases {
            for tier in SubscriptionTier.allCases {
                let copy = PricingVariantsCopy.copy(for: variant, tier: tier)
                XCTAssertFalse(
                    copy.privacyNote.isEmpty,
                    "Variant \(variant.id).\(tier.rawValue) has no privacy note"
                )
            }
        }
    }
    
    // MARK: - D) Variant Storage
    
    /// Verifies variant can be changed and persisted
    func testVariantCanBeChanged() async {
        let store = await PricingVariantStore.shared
        
        await store.setVariant(.variantB)
        var current = await store.currentVariant
        XCTAssertEqual(current, .variantB)
        
        await store.setVariant(.variantC)
        current = await store.currentVariant
        XCTAssertEqual(current, .variantC)
        
        // Reset
        await store.resetToDefault()
    }
    
    // MARK: - E) Schema Version
    
    /// Verifies schema version is set
    func testSchemaVersionIsSet() {
        XCTAssertGreaterThan(
            PricingVariant.schemaVersion,
            0,
            "Schema version should be > 0"
        )
    }
}
