import Foundation

// ============================================================================
// SOVEREIGN EXPORT BUNDLE (Phase 13C)
//
// User-owned encrypted archive containing logic and metadata only.
//
// CONTAINS:
// - Procedure templates (logic-only)
// - Policy state
// - Pricing / entitlement metadata
// - Audit counts (aggregates only)
//
// CONTAINS NO:
// - Drafts, memory text, outputs, identifiers, context, user content
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No personal data
// ❌ No identifiers
// ✅ Logic and metadata only
// ✅ Deterministic serialization
// ============================================================================

// MARK: - Sovereign Export Bundle

public struct SovereignExportBundle: Codable {
    
    // MARK: - Fields (Strictly Limited)
    
    /// Schema version
    public let schemaVersion: Int
    
    /// Export date (day-rounded only)
    public let exportedAtDayRounded: String
    
    /// App version at export
    public let appVersion: String
    
    /// Procedure templates (logic-only)
    public let procedures: [ExportedProcedure]
    
    /// Policy summary (flags and limits only)
    public let policySummary: ExportedPolicySummary
    
    /// Entitlement state (tier and flags only)
    public let entitlementState: ExportedEntitlementState
    
    /// Audit counts (aggregates only, no content)
    public let auditCounts: ExportedAuditCounts
    
    // MARK: - Schema
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Init
    
    public init(
        procedures: [ExportedProcedure],
        policySummary: ExportedPolicySummary,
        entitlementState: ExportedEntitlementState,
        auditCounts: ExportedAuditCounts,
        appVersion: String
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAtDayRounded = Self.currentDayRounded()
        self.appVersion = appVersion
        self.procedures = procedures
        self.policySummary = policySummary
        self.entitlementState = entitlementState
        self.auditCounts = auditCounts
    }
    
    private static func currentDayRounded() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}

// MARK: - Exported Procedure

public struct ExportedProcedure: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let category: String
    public let intentType: String
    public let outputType: String
    public let promptScaffold: String
    public let requiresApproval: Bool
    public let createdAtDayRounded: String
    
    // NO: body, subject, content, draft, email, recipient, attendees, etc.
}

// MARK: - Exported Policy Summary

public struct ExportedPolicySummary: Codable {
    public let isCustomPolicyEnabled: Bool
    public let maxExecutionsPerDay: Int?
    public let allowedDaysOfWeek: [Int]?
    public let requiresTwoKeyApproval: Bool
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public init(
        isCustomPolicyEnabled: Bool = false,
        maxExecutionsPerDay: Int? = nil,
        allowedDaysOfWeek: [Int]? = nil,
        requiresTwoKeyApproval: Bool = true
    ) {
        self.isCustomPolicyEnabled = isCustomPolicyEnabled
        self.maxExecutionsPerDay = maxExecutionsPerDay
        self.allowedDaysOfWeek = allowedDaysOfWeek
        self.requiresTwoKeyApproval = requiresTwoKeyApproval
        self.schemaVersion = Self.currentSchemaVersion
    }
}

// MARK: - Exported Entitlement State

public struct ExportedEntitlementState: Codable {
    public let tier: String
    public let isLifetime: Bool
    public let teamSeatCount: Int?
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public init(
        tier: String,
        isLifetime: Bool = false,
        teamSeatCount: Int? = nil
    ) {
        self.tier = tier
        self.isLifetime = isLifetime
        self.teamSeatCount = teamSeatCount
        self.schemaVersion = Self.currentSchemaVersion
    }
}

// MARK: - Exported Audit Counts

public struct ExportedAuditCounts: Codable {
    public let totalDraftedOutcomes: Int
    public let totalApprovals: Int
    public let totalExecutions: Int
    public let totalFailures: Int
    public let exportedAtDayRounded: String
    public let schemaVersion: Int
    
    // NO: event details, timestamps, content, identifiers
    
    public static let currentSchemaVersion = 1
    
    public init(
        totalDraftedOutcomes: Int = 0,
        totalApprovals: Int = 0,
        totalExecutions: Int = 0,
        totalFailures: Int = 0
    ) {
        self.totalDraftedOutcomes = totalDraftedOutcomes
        self.totalApprovals = totalApprovals
        self.totalExecutions = totalExecutions
        self.totalFailures = totalFailures
        self.exportedAtDayRounded = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.string(from: Date())
        }()
        self.schemaVersion = Self.currentSchemaVersion
    }
}

// MARK: - Bundle Validation

public enum SovereignExportBundleValidator {
    
    /// Forbidden keys that must never appear in export
    public static let forbiddenKeys: Set<String> = [
        "body", "subject", "content", "draft", "prompt", "context",
        "email", "recipient", "attendees", "title", "description",
        "message", "text", "address", "company", "domain", "phone",
        "note", "notes", "memory", "output", "result", "userData",
        "userText", "userInput", "personalData", "identifier",
        "deviceId", "userId", "accountId", "sessionId"
    ]
    
    /// Validate a bundle before export
    public static func validate(_ bundle: SovereignExportBundle) -> ValidationResult {
        var errors: [String] = []
        
        // Validate schema version
        if bundle.schemaVersion < 1 {
            errors.append("Invalid schema version")
        }
        
        // Validate serialization contains no forbidden keys
        if let jsonData = try? JSONEncoder().encode(bundle),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let lowercased = jsonString.lowercased()
            for key in forbiddenKeys {
                if lowercased.contains("\"\(key)\"") {
                    errors.append("Bundle contains forbidden key: \(key)")
                }
            }
        }
        
        // Validate procedures
        for procedure in bundle.procedures {
            if procedure.name.isEmpty {
                errors.append("Procedure name cannot be empty")
            }
            
            // Check for forbidden patterns in prompt scaffold
            let forbiddenPatterns = ["@gmail.com", "@yahoo.com", "Dear ", "Hi "]
            for pattern in forbiddenPatterns {
                if procedure.promptScaffold.lowercased().contains(pattern.lowercased()) {
                    errors.append("Procedure contains forbidden pattern: \(pattern)")
                }
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    public struct ValidationResult {
        public let isValid: Bool
        public let errors: [String]
    }
}
