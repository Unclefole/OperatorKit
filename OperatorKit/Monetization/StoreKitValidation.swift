import Foundation

// ============================================================================
// STOREKIT VALIDATION (Phase 10H)
//
// Validates StoreKit product IDs and tier mappings.
// Ensures consistency between TierMatrix and StoreKit.
//
// CONSTRAINTS:
// ✅ Single source of truth validation
// ✅ Compile-time and runtime checks
// ✅ No hardcoded pricing (comes from StoreKit)
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - StoreKit Validation

/// Validates StoreKit product configuration
public enum StoreKitValidation {
    
    // MARK: - Product ID Validation
    
    /// Validates that all tiers have corresponding product IDs
    public static func validateTierProductMapping() -> [String] {
        var errors: [String] = []
        
        // Pro tier should have products
        let proProducts = StoreKitProductIDs.proSubscriptions
        if proProducts.isEmpty {
            errors.append("Pro tier has no product IDs defined")
        }
        
        // Team tier should have products
        let teamProducts = StoreKitProductIDs.teamSubscriptions
        if teamProducts.isEmpty {
            errors.append("Team tier has no product IDs defined")
        }
        
        // Verify tier mapping is correct
        for productId in proProducts {
            let tier = StoreKitProductIDs.tier(for: productId)
            if tier != .pro {
                errors.append("Product \(productId) should map to Pro tier, but maps to \(tier)")
            }
        }
        
        for productId in teamProducts {
            let tier = StoreKitProductIDs.tier(for: productId)
            if tier != .team {
                errors.append("Product \(productId) should map to Team tier, but maps to \(tier)")
            }
        }
        
        return errors
    }
    
    /// Validates product ID format
    public static func validateProductIdFormat(_ productId: String) -> [String] {
        var errors: [String] = []
        
        // Should start with bundle ID prefix
        let expectedPrefix = "com.operatorkit."
        if !productId.hasPrefix(expectedPrefix) {
            errors.append("Product ID should start with '\(expectedPrefix)'")
        }
        
        // Should only contain valid characters
        let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._"))
        if productId.unicodeScalars.contains(where: { !validChars.contains($0) }) {
            errors.append("Product ID contains invalid characters")
        }
        
        // Should not be too long
        if productId.count > 100 {
            errors.append("Product ID is too long (max 100 characters)")
        }
        
        return errors
    }
    
    /// Validates all product IDs
    public static func validateAllProductIds() -> [String] {
        var errors: [String] = []
        
        for productId in StoreKitProductIDs.allProducts {
            let idErrors = validateProductIdFormat(productId)
            errors.append(contentsOf: idErrors.map { "\(productId): \($0)" })
        }
        
        return errors
    }
    
    // MARK: - Display Order Validation
    
    /// Validates that display order is stable and complete
    public static func validateDisplayOrder() -> [String] {
        var errors: [String] = []
        
        let displayOrder = StoreKitProductIDs.displayOrder
        let allProducts = Set(StoreKitProductIDs.allProducts)
        let orderedProducts = Set(displayOrder)
        
        // All products should be in display order
        let missing = allProducts.subtracting(orderedProducts)
        if !missing.isEmpty {
            errors.append("Products missing from display order: \(missing.joined(separator: ", "))")
        }
        
        // No duplicates in display order
        if displayOrder.count != orderedProducts.count {
            errors.append("Display order contains duplicates")
        }
        
        // Display order should not have extra products
        let extra = orderedProducts.subtracting(allProducts)
        if !extra.isEmpty {
            errors.append("Display order contains unknown products: \(extra.joined(separator: ", "))")
        }
        
        return errors
    }
    
    // MARK: - Tier Matrix Validation
    
    /// Validates TierMatrix consistency
    public static func validateTierMatrix() -> [String] {
        var errors: [String] = []
        
        // Free tier should have limits
        if TierMatrix.weeklyExecutionLimit(for: .free) == nil {
            errors.append("Free tier should have weekly execution limit")
        }
        if TierMatrix.memoryItemLimit(for: .free) == nil {
            errors.append("Free tier should have memory item limit")
        }
        
        // Pro/Team should be unlimited
        if TierMatrix.weeklyExecutionLimit(for: .pro) != nil {
            errors.append("Pro tier should have unlimited executions")
        }
        if TierMatrix.weeklyExecutionLimit(for: .team) != nil {
            errors.append("Team tier should have unlimited executions")
        }
        
        // Feature access should be hierarchical
        if TierMatrix.canSync(tier: .free) {
            errors.append("Free tier should not have sync access")
        }
        if !TierMatrix.canSync(tier: .pro) {
            errors.append("Pro tier should have sync access")
        }
        if !TierMatrix.canSync(tier: .team) {
            errors.append("Team tier should have sync access")
        }
        
        // Only Team should have team features
        if TierMatrix.canUseTeam(tier: .free) {
            errors.append("Free tier should not have team access")
        }
        if TierMatrix.canUseTeam(tier: .pro) {
            errors.append("Pro tier should not have team access")
        }
        if !TierMatrix.canUseTeam(tier: .team) {
            errors.append("Team tier should have team access")
        }
        
        return errors
    }
    
    // MARK: - Quota Consistency
    
    /// Validates that quotas are defined in one place only
    public static func validateQuotaConsistency() -> [String] {
        var errors: [String] = []
        
        // TierMatrix and TierQuotas should agree
        let matrixFreeExec = TierMatrix.weeklyExecutionLimit(for: .free)
        let quotasFreeExec = TierQuotas.weeklyExecutionLimit(for: .free)
        
        if matrixFreeExec != quotasFreeExec {
            errors.append("TierMatrix and TierQuotas have different Free tier execution limits")
        }
        
        let matrixFreeMem = TierMatrix.memoryItemLimit(for: .free)
        let quotasFreeMem = TierQuotas.memoryItemLimit(for: .free)
        
        if matrixFreeMem != quotasFreeMem {
            errors.append("TierMatrix and TierQuotas have different Free tier memory limits")
        }
        
        return errors
    }
    
    // MARK: - Full Validation
    
    /// Runs all validations
    public static func runAllValidations() -> StoreKitValidationResult {
        var allErrors: [String] = []
        
        allErrors.append(contentsOf: validateTierProductMapping())
        allErrors.append(contentsOf: validateAllProductIds())
        allErrors.append(contentsOf: validateDisplayOrder())
        allErrors.append(contentsOf: validateTierMatrix())
        allErrors.append(contentsOf: validateQuotaConsistency())
        
        return StoreKitValidationResult(
            isValid: allErrors.isEmpty,
            errors: allErrors
        )
    }
}

// MARK: - Validation Result

/// Result of StoreKit validation
public struct StoreKitValidationResult {
    public let isValid: Bool
    public let errors: [String]
    
    public var errorSummary: String {
        errors.joined(separator: "\n")
    }
}
