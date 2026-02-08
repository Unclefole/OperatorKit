import Foundation

// ============================================================================
// APP STORE SUBMISSION PACKET (Phase 10J)
//
// Single exportable packet proving safety/quality/monetization claims.
// Aggregates metadata from all verification modules.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content (body, subject, draft, prompt, context, etc.)
// ❌ No networking
// ❌ No execution behavior changes
// ✅ Metadata-only
// ✅ Soft-fail for missing sections
// ✅ Forbidden-key validated
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - App Store Submission Packet

public struct AppStoreSubmissionPacket: Codable {
    
    // MARK: - Metadata
    
    /// Schema version for packet format
    public let schemaVersion: Int
    
    /// When exported (day-rounded for privacy)
    public let exportedAt: String
    
    /// App version
    public let appVersion: String
    
    /// Build number
    public let buildNumber: String
    
    /// Release mode (debug/release)
    public let releaseMode: String
    
    // MARK: - Safety
    
    /// Safety contract summary
    public let safetyContract: SafetyContractExport?
    
    /// Doc integrity status
    public let docIntegrity: DocIntegrityExport?
    
    /// Claim registry summary
    public let claimRegistry: SubmissionClaimRegistrySummaryExport?
    
    // MARK: - Quality
    
    /// Preflight summary
    public let preflight: SubmissionPreflightSummaryExport?
    
    /// Quality gate status
    public let qualityGate: SubmissionQualityGateExport?
    
    /// Regression sentinel status
    public let regressionSentinel: SubmissionRegressionSentinelExport?
    
    /// Coverage summary
    public let coverage: CoverageSummaryExport?
    
    // MARK: - Monetization
    
    /// Monetization disclosure
    public let monetization: MonetizationDisclosureExport?
    
    // MARK: - Features
    
    /// Policy summary (if available)
    public let policy: PolicySummaryExport?
    
    /// Sync status
    public let syncEnabled: Bool
    
    /// Team status
    public let teamEnabled: Bool
    
    // MARK: - Current Schema Version
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Export
    
    /// Exports to JSON data
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    
    /// Filename for export
    public var exportFilename: String {
        "OperatorKit_SubmissionPacket_\(appVersion)_\(buildNumber).json"
    }
}

// MARK: - Safety Contract Export

public struct SafetyContractExport: Codable {
    /// Hash of safety contract content (for verification)
    public let contentHash: String
    
    /// Status (valid/invalid)
    public let status: String
    
    /// Key guarantees present
    public let guaranteesCount: Int
    
    /// Last verified date
    public let lastVerified: String?
}

// MARK: - Doc Integrity Export

public struct DocIntegrityExport: Codable {
    /// Total required docs
    public let requiredDocsCount: Int
    
    /// Docs present
    public let presentCount: Int
    
    /// Missing docs (names only)
    public let missingDocs: [String]
    
    /// Section validation results
    public let sectionValidation: [String: Bool]
    
    /// Overall status
    public let status: String
}

// MARK: - Submission Claim Registry Summary Export

public struct SubmissionClaimRegistrySummaryExport: Codable {
    /// Schema version of claim registry
    public let registrySchemaVersion: Int
    
    /// Total claims
    public let totalClaims: Int
    
    /// Claim IDs (no content)
    public let claimIds: [String]
    
    /// Last updated phase
    public let lastUpdatedPhase: String
}

// MARK: - Submission Preflight Summary Export

public struct SubmissionPreflightSummaryExport: Codable {
    /// Overall status
    public let status: String
    
    /// Checks passed
    public let passedCount: Int
    
    /// Checks failed
    public let failedCount: Int
    
    /// Check categories
    public let categories: [String]
}

// MARK: - Submission Quality Gate Export

public struct SubmissionQualityGateExport: Codable {
    /// Gate status (passed/failed/not_run)
    public let status: String
    
    /// Criteria count
    public let criteriaCount: Int
    
    /// Passed criteria
    public let passedCriteria: Int
    
    /// Gate version
    public let gateVersion: Int?
}

// MARK: - Submission Regression Sentinel Export

public struct SubmissionRegressionSentinelExport: Codable {
    /// Status (clean/regressed/not_run)
    public let status: String
    
    /// Baseline version
    public let baselineVersion: String?
    
    /// Last run date
    public let lastRunDate: String?
}

// MARK: - Coverage Summary Export

public struct CoverageSummaryExport: Codable {
    /// Line coverage percentage
    public let lineCoverage: Double?
    
    /// Branch coverage percentage
    public let branchCoverage: Double?
    
    /// Trend direction (up/down/stable)
    public let trend: String
    
    /// Coverage source
    public let source: String
}

// MARK: - Monetization Disclosure Export

public struct MonetizationDisclosureExport: Codable {
    /// Available tiers
    public let tiers: [String]
    
    /// Restore purchases available
    public let restorePurchasesAvailable: Bool
    
    /// Local conversion counters (no values, just flag)
    public let localConversionCounters: Bool
    
    /// No tracking analytics
    public let noTrackingAnalytics: Bool
    
    /// Subscription disclosure included
    public let subscriptionDisclosureIncluded: Bool
    
    /// Free tier functional
    public let freeTierFunctional: Bool
}

// MARK: - Policy Summary Export

public struct PolicySummaryExport: Codable {
    /// Policy version
    public let version: Int?
    
    /// Policy enabled
    public let enabled: Bool
    
    /// Key settings (flags only, no content)
    public let approvalRequired: Bool
    public let localProcessingOnly: Bool
}

// MARK: - Forbidden Keys Validation

extension AppStoreSubmissionPacket {
    
    /// Forbidden keys that must never appear in exports
    public static let forbiddenKeys: [String] = [
        "body",
        "subject",
        "content",
        "draft",
        "prompt",
        "context",
        "note",
        "email",
        "attendees",
        "title",
        "description",
        "message",
        "text",
        "recipient",
        "sender"
    ]
    
    /// Validates packet contains no forbidden keys
    public func validateNoForbiddenKeys() throws -> [String] {
        let jsonData = try exportJSON()
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }
        
        return Self.findForbiddenKeys(in: json, path: "")
    }
    
    private static func findForbiddenKeys(in dict: [String: Any], path: String) -> [String] {
        var violations: [String] = []
        
        for (key, value) in dict {
            let fullPath = path.isEmpty ? key : "\(path).\(key)"
            
            // Check if key is forbidden
            if forbiddenKeys.contains(key.lowercased()) {
                violations.append("Forbidden key found: \(fullPath)")
            }
            
            // Recurse into nested objects
            if let nested = value as? [String: Any] {
                violations.append(contentsOf: findForbiddenKeys(in: nested, path: fullPath))
            }
            
            // Check arrays
            if let array = value as? [[String: Any]] {
                for (index, item) in array.enumerated() {
                    violations.append(contentsOf: findForbiddenKeys(in: item, path: "\(fullPath)[\(index)]"))
                }
            }
        }
        
        return violations
    }
}
