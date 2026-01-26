import Foundation

// ============================================================================
// PROOF PACK MODEL (Phase 13H)
//
// Metadata-only bundle schema for unified trust evidence.
// Contains ONLY aggregates, hashes, booleans, and counts.
//
// MUST NEVER CONTAIN:
// - Drafts, prompts, context, memory text
// - User identifiers, device IDs
// - Emails, events, reminders
// - Paths or filesystem locations
// - Free-text strings
// - Anything not visible in Trust Surfaces
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No PII
// ❌ No free-text fields
// ✅ Metadata only
// ✅ Schema versioned
// ✅ Deterministic serialization
// ============================================================================

// MARK: - Forbidden Keys

public enum ProofPackForbiddenKeys {
    
    /// Keys that must NEVER appear in Proof Pack
    public static let all: Set<String> = [
        "body", "subject", "content", "draft", "prompt", "context",
        "message", "text", "recipient", "sender", "title", "description",
        "attendees", "email", "phone", "address", "name", "note", "notes",
        "userData", "personalData", "identifier", "deviceId", "userId",
        "path", "fullPath", "absolutePath", "homeDirectory", "userDirectory",
        "memory", "memoryText", "contextText", "draftText", "output", "result",
        "calendar", "reminder", "event", "freeText", "userInput"
    ]
    
    /// Validate a JSON string contains no forbidden keys
    public static func validate(_ jsonString: String) -> [String] {
        var violations: [String] = []
        let lowercased = jsonString.lowercased()
        
        for key in all {
            if lowercased.contains("\"\(key)\"") {
                violations.append("Contains forbidden key: \(key)")
            }
        }
        
        return violations
    }
}

// MARK: - Proof Pack

public struct ProofPack: Codable, Equatable {
    
    // MARK: - Identity
    
    /// Schema version for forward compatibility
    public let schemaVersion: Int
    
    /// App version
    public let appVersion: String
    
    /// Build number
    public let buildNumber: String
    
    /// Day-rounded creation date
    public let createdAtDayRounded: String
    
    // MARK: - Release Seals
    
    /// Release seal verification results
    public let releaseSeals: ReleaseSealSummary
    
    // MARK: - Security Manifest
    
    /// Security manifest boolean claims
    public let securityManifest: SecurityManifestSummary
    
    // MARK: - Binary Proof
    
    /// Binary proof summary
    public let binaryProof: BinaryProofSummary
    
    // MARK: - Regression Firewall
    
    /// Regression firewall summary
    public let regressionFirewall: RegressionFirewallSummary
    
    // MARK: - Audit Vault
    
    /// Audit vault aggregate counts
    public let auditVault: AuditVaultAggregate
    
    // MARK: - Offline Certification
    
    /// Offline certification summary
    public let offlineCertification: OfflineCertificationSummary
    
    // MARK: - Build Seals (Phase 13J)
    
    /// Build-time proof seals summary
    public let buildSeals: BuildSealsSummary
    
    // MARK: - Feature Flags
    
    /// Feature flag states (enabled/disabled only)
    public let featureFlags: FeatureFlagSummary
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Validation
    
    public func validate() -> [String] {
        var errors: [String] = []
        
        // Validate no forbidden keys in serialization
        if let jsonData = try? JSONEncoder().encode(self),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            errors.append(contentsOf: ProofPackForbiddenKeys.validate(jsonString))
        }
        
        return errors
    }
    
    // MARK: - Export
    
    public func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
}

// MARK: - Release Seal Summary

public struct ReleaseSealSummary: Codable, Equatable {
    public let terminologyCanon: SealStatus
    public let claimRegistry: SealStatus
    public let safetyContract: SealStatus
    public let pricingRegistry: SealStatus
    public let storeListing: SealStatus
    
    public var allPassed: Bool {
        terminologyCanon == .pass &&
        claimRegistry == .pass &&
        safetyContract == .pass &&
        pricingRegistry == .pass &&
        storeListing == .pass
    }
    
    public var passCount: Int {
        [terminologyCanon, claimRegistry, safetyContract, pricingRegistry, storeListing]
            .filter { $0 == .pass }
            .count
    }
}

public enum SealStatus: String, Codable {
    case pass = "PASS"
    case fail = "FAIL"
    case unavailable = "UNAVAILABLE"
}

// MARK: - Security Manifest Summary

public struct SecurityManifestSummary: Codable, Equatable {
    public let webkitPresent: Bool
    public let javascriptPresent: Bool
    public let embeddedBrowserPresent: Bool
    public let remoteCodeExecutionPresent: Bool
    
    public var allClear: Bool {
        !webkitPresent && !javascriptPresent && !embeddedBrowserPresent && !remoteCodeExecutionPresent
    }
}

// MARK: - Binary Proof Summary

public struct BinaryProofSummary: Codable, Equatable {
    public let frameworkCount: Int
    public let sensitiveFrameworks: SensitiveFrameworksSummary
    public let overallStatus: String
}

public struct SensitiveFrameworksSummary: Codable, Equatable {
    public let webKit: Bool
    public let javaScriptCore: Bool
    public let safariServices: Bool
    public let webKitLegacy: Bool
    
    public var anyCriticalPresent: Bool {
        webKit || javaScriptCore
    }
}

// MARK: - Regression Firewall Summary

public struct RegressionFirewallSummary: Codable, Equatable {
    public let ruleCount: Int
    public let passed: Int
    public let failed: Int
    public let overallStatus: String
    
    public var allPassed: Bool { failed == 0 }
}

// MARK: - Audit Vault Aggregate

public struct AuditVaultAggregate: Codable, Equatable {
    public let eventCount: Int
    public let maxCapacity: Int
    public let editCount: Int
    public let exportCount: Int
}

// MARK: - Offline Certification Summary

public struct OfflineCertificationSummary: Codable, Equatable {
    public let overallStatus: String
    public let ruleCount: Int
    public let passedCount: Int
    public let failedCount: Int
    
    public var allPassed: Bool { failedCount == 0 }
}

// MARK: - Feature Flag Summary

public struct FeatureFlagSummary: Codable, Equatable {
    public let trustSurfaces: Bool
    public let auditVault: Bool
    public let securityManifest: Bool
    public let binaryProof: Bool
    public let regressionFirewall: Bool
    public let procedureSharing: Bool
    public let sovereignExport: Bool
    public let proofPack: Bool
    public let offlineCertification: Bool
    public let buildSeals: Bool
}
