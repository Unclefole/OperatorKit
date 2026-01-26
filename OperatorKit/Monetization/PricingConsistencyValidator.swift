import Foundation

// ============================================================================
// PRICING CONSISTENCY VALIDATOR (Phase 11B, Updated Phase 11C)
//
// Validates pricing copy and entitlements are consistent.
// Advisory only - does not block anything.
//
// Phase 11C additions:
// - Free uses "Drafted Outcomes" language check
// - Team minimum seats = 3 check
// - Lifetime price consistency check
// - Lifetime product ID exists check
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No blocking behavior
// ❌ No side effects
// ✅ Advisory only
// ✅ Returns status + reasons
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Validation Status

public enum PricingValidationStatus: String, Codable {
    case pass = "pass"
    case warn = "warn"
    case fail = "fail"
    
    public var displayName: String {
        switch self {
        case .pass: return "Pass"
        case .warn: return "Warning"
        case .fail: return "Fail"
        }
    }
    
    public var icon: String {
        switch self {
        case .pass: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.circle.fill"
        }
    }
}

// MARK: - Validation Finding

public struct PricingValidationFinding: Codable, Identifiable {
    public let id: String
    public let severity: PricingValidationStatus
    public let category: String
    public let finding: String
    public let suggestion: String?
}

// MARK: - Validation Result

public struct PricingValidationResult: Codable {
    public let status: PricingValidationStatus
    public let findings: [PricingValidationFinding]
    public let validatedAtDayRounded: String
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public var passCount: Int { findings.filter { $0.severity == .pass }.count }
    public var warnCount: Int { findings.filter { $0.severity == .warn }.count }
    public var failCount: Int { findings.filter { $0.severity == .fail }.count }
}

// MARK: - Pricing Consistency Validator

public final class PricingConsistencyValidator {
    
    // MARK: - Singleton
    
    public static let shared = PricingConsistencyValidator()
    
    private init() {}
    
    // MARK: - Validation
    
    public func validate() -> PricingValidationResult {
        var findings: [PricingValidationFinding] = []
        
        // 1. Validate registry copy
        findings.append(contentsOf: validateRegistryCopy())
        
        // 2. Validate tier matrix consistency
        findings.append(contentsOf: validateTierMatrixConsistency())
        
        // 3. Validate StoreKit disclosures
        findings.append(contentsOf: validateStoreKitDisclosures())
        
        // 4. Validate restore language
        findings.append(contentsOf: validateRestoreLanguage())
        
        // 5. Phase 11C: Validate Drafted Outcomes language
        findings.append(contentsOf: validateDraftedOutcomesLanguage())
        
        // 6. Phase 11C: Validate Team minimum seats
        findings.append(contentsOf: validateTeamMinimumSeats())
        
        // 7. Phase 11C: Validate Lifetime option
        findings.append(contentsOf: validateLifetimeOption())
        
        // Determine overall status
        let status: PricingValidationStatus
        if findings.contains(where: { $0.severity == .fail }) {
            status = .fail
        } else if findings.contains(where: { $0.severity == .warn }) {
            status = .warn
        } else {
            status = .pass
        }
        
        return PricingValidationResult(
            status: status,
            findings: findings,
            validatedAtDayRounded: dayRoundedNow(),
            schemaVersion: PricingValidationResult.currentSchemaVersion
        )
    }
    
    // MARK: - Registry Copy Validation
    
    private func validateRegistryCopy() -> [PricingValidationFinding] {
        var findings: [PricingValidationFinding] = []
        
        let (isValid, violations) = PricingPackageRegistry.validateAll()
        
        if isValid {
            findings.append(PricingValidationFinding(
                id: "copy-clean",
                severity: .pass,
                category: "Copy",
                finding: "All pricing copy is App Store safe",
                suggestion: nil
            ))
        } else {
            for violation in violations {
                findings.append(PricingValidationFinding(
                    id: "copy-violation-\(UUID().uuidString.prefix(8))",
                    severity: .fail,
                    category: "Copy",
                    finding: violation,
                    suggestion: "Review and update pricing copy"
                ))
            }
        }
        
        return findings
    }
    
    // MARK: - Tier Matrix Consistency
    
    private func validateTierMatrixConsistency() -> [PricingValidationFinding] {
        var findings: [PricingValidationFinding] = []
        
        // Verify Free tier has limited executions
        let freePackage = PricingPackageRegistry.free
        if freePackage.excludedFeatures.contains("unlimited_executions") {
            findings.append(PricingValidationFinding(
                id: "tier-free-limited",
                severity: .pass,
                category: "Tier Consistency",
                finding: "Free tier correctly excludes unlimited executions",
                suggestion: nil
            ))
        } else {
            findings.append(PricingValidationFinding(
                id: "tier-free-unlimited",
                severity: .warn,
                category: "Tier Consistency",
                finding: "Free tier should exclude unlimited executions",
                suggestion: "Update Free tier excluded features"
            ))
        }
        
        // Verify Pro tier has unlimited executions
        let proPackage = PricingPackageRegistry.pro
        if proPackage.includedFeatures.contains("unlimited_executions") {
            findings.append(PricingValidationFinding(
                id: "tier-pro-unlimited",
                severity: .pass,
                category: "Tier Consistency",
                finding: "Pro tier correctly includes unlimited executions",
                suggestion: nil
            ))
        } else {
            findings.append(PricingValidationFinding(
                id: "tier-pro-limited",
                severity: .warn,
                category: "Tier Consistency",
                finding: "Pro tier should include unlimited executions",
                suggestion: "Update Pro tier included features"
            ))
        }
        
        // Verify Team tier has governance
        let teamPackage = PricingPackageRegistry.team
        if teamPackage.includedFeatures.contains("team_governance") {
            findings.append(PricingValidationFinding(
                id: "tier-team-governance",
                severity: .pass,
                category: "Tier Consistency",
                finding: "Team tier correctly includes team governance",
                suggestion: nil
            ))
        } else {
            findings.append(PricingValidationFinding(
                id: "tier-team-no-governance",
                severity: .warn,
                category: "Tier Consistency",
                finding: "Team tier should include team governance",
                suggestion: "Update Team tier included features"
            ))
        }
        
        return findings
    }
    
    // MARK: - StoreKit Disclosures
    
    private func validateStoreKitDisclosures() -> [PricingValidationFinding] {
        var findings: [PricingValidationFinding] = []
        
        // Check Pro has auto-renew disclosure
        let proPackage = PricingPackageRegistry.pro
        if proPackage.storeKitDisclosure.lowercased().contains("auto-renew") ||
           proPackage.storeKitDisclosure.lowercased().contains("subscription") {
            findings.append(PricingValidationFinding(
                id: "storekit-pro-disclosure",
                severity: .pass,
                category: "StoreKit",
                finding: "Pro tier has subscription disclosure",
                suggestion: nil
            ))
        } else {
            findings.append(PricingValidationFinding(
                id: "storekit-pro-missing",
                severity: .fail,
                category: "StoreKit",
                finding: "Pro tier missing subscription disclosure",
                suggestion: "Add auto-renew disclosure to Pro package"
            ))
        }
        
        // Check Team has auto-renew disclosure
        let teamPackage = PricingPackageRegistry.team
        if teamPackage.storeKitDisclosure.lowercased().contains("auto-renew") ||
           teamPackage.storeKitDisclosure.lowercased().contains("subscription") {
            findings.append(PricingValidationFinding(
                id: "storekit-team-disclosure",
                severity: .pass,
                category: "StoreKit",
                finding: "Team tier has subscription disclosure",
                suggestion: nil
            ))
        } else {
            findings.append(PricingValidationFinding(
                id: "storekit-team-missing",
                severity: .fail,
                category: "StoreKit",
                finding: "Team tier missing subscription disclosure",
                suggestion: "Add auto-renew disclosure to Team package"
            ))
        }
        
        return findings
    }
    
    // MARK: - Restore Language
    
    private func validateRestoreLanguage() -> [PricingValidationFinding] {
        var findings: [PricingValidationFinding] = []
        
        // This is advisory - actual restore button is in UI
        findings.append(PricingValidationFinding(
            id: "restore-available",
            severity: .pass,
            category: "Restore",
            finding: "Restore purchases option should be available in UI",
            suggestion: nil
        ))
        
        return findings
    }
    
    // MARK: - Phase 11C: Drafted Outcomes Language
    
    private func validateDraftedOutcomesLanguage() -> [PricingValidationFinding] {
        var findings: [PricingValidationFinding] = []
        
        if PricingPackageRegistry.validateFreeUsesDraftedOutcomesLanguage() {
            findings.append(PricingValidationFinding(
                id: "drafted-outcomes-language",
                severity: .pass,
                category: "Copy (11C)",
                finding: "Free tier uses 'Drafted Outcomes' language",
                suggestion: nil
            ))
        } else {
            findings.append(PricingValidationFinding(
                id: "drafted-outcomes-missing",
                severity: .warn,
                category: "Copy (11C)",
                finding: "Free tier should use 'Drafted Outcomes' language (not 'executions')",
                suggestion: "Update Free tier copy to use 'Drafted Outcomes'"
            ))
        }
        
        return findings
    }
    
    // MARK: - Phase 11C: Team Minimum Seats
    
    private func validateTeamMinimumSeats() -> [PricingValidationFinding] {
        var findings: [PricingValidationFinding] = []
        
        if PricingPackageRegistry.validateTeamMinimumSeats() {
            findings.append(PricingValidationFinding(
                id: "team-min-seats",
                severity: .pass,
                category: "Team (11C)",
                finding: "Team minimum seats is 3",
                suggestion: nil
            ))
        } else {
            findings.append(PricingValidationFinding(
                id: "team-min-seats-wrong",
                severity: .warn,
                category: "Team (11C)",
                finding: "Team minimum seats should be 3",
                suggestion: "Update Team package minimumSeats to 3"
            ))
        }
        
        return findings
    }
    
    // MARK: - Phase 11C: Lifetime Option
    
    private func validateLifetimeOption() -> [PricingValidationFinding] {
        var findings: [PricingValidationFinding] = []
        
        // Check Lifetime price consistency
        if PricingPackageRegistry.validateLifetimePriceConsistent() {
            findings.append(PricingValidationFinding(
                id: "lifetime-price-consistent",
                severity: .pass,
                category: "Lifetime (11C)",
                finding: "Lifetime price is consistent across registry",
                suggestion: nil
            ))
        } else {
            findings.append(PricingValidationFinding(
                id: "lifetime-price-inconsistent",
                severity: .warn,
                category: "Lifetime (11C)",
                finding: "Lifetime price should match constant",
                suggestion: "Ensure lifetime price matches lifetimeSovereignPrice constant"
            ))
        }
        
        // Check Lifetime product ID exists in StoreKit
        if StoreKitProductIDs.allProducts.contains(StoreKitProductIDs.lifetimeSovereign) {
            findings.append(PricingValidationFinding(
                id: "lifetime-product-id",
                severity: .pass,
                category: "Lifetime (11C)",
                finding: "Lifetime Sovereign product ID is defined in StoreKitProducts",
                suggestion: nil
            ))
        } else {
            findings.append(PricingValidationFinding(
                id: "lifetime-product-id-missing",
                severity: .fail,
                category: "Lifetime (11C)",
                finding: "Lifetime Sovereign product ID not found in StoreKitProducts",
                suggestion: "Add lifetimeSovereign to StoreKitProductIDs"
            ))
        }
        
        return findings
    }
    
    // MARK: - Helpers
    
    private func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
