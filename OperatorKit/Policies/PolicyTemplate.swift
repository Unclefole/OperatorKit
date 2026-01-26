import Foundation

// ============================================================================
// POLICY TEMPLATE (Phase 10M)
//
// Predefined policy templates for team governance.
// Metadata-only, no user content fields.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content fields
// ❌ No execution enforcement
// ✅ Metadata-only policy settings
// ✅ Local-only storage
// ✅ User-initiated apply with confirmation
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

// MARK: - Policy Template

public struct PolicyTemplate: Codable, Identifiable, Equatable {
    
    /// Unique identifier
    public let id: String
    
    /// Template name
    public let name: String
    
    /// Template description
    public let templateDescription: String
    
    /// Policy payload (capabilities + limits)
    public let policyPayload: PolicyPayload
    
    /// Schema version
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Initialization
    
    public init(
        id: String,
        name: String,
        templateDescription: String,
        policyPayload: PolicyPayload
    ) {
        self.id = id
        self.name = name
        self.templateDescription = templateDescription
        self.policyPayload = policyPayload
        self.schemaVersion = Self.currentSchemaVersion
    }
}

// MARK: - Policy Payload

public struct PolicyPayload: Codable, Equatable {
    
    // MARK: - Capabilities
    
    /// Allow email drafts
    public let allowEmailDrafts: Bool
    
    /// Allow calendar writes
    public let allowCalendarWrites: Bool
    
    /// Allow task creation
    public let allowTaskCreation: Bool
    
    /// Allow memory writes
    public let allowMemoryWrites: Bool
    
    // MARK: - Limits
    
    /// Max executions per day (nil = unlimited)
    public let maxExecutionsPerDay: Int?
    
    /// Max memory items (nil = unlimited)
    public let maxMemoryItems: Int?
    
    // MARK: - Safety
    
    /// Require explicit confirmation for all actions
    public let requireExplicitConfirmation: Bool
    
    /// Allow only local processing (no sync)
    public let localProcessingOnly: Bool
    
    // MARK: - Factory
    
    /// Creates a conservative payload (all features limited)
    public static func conservative() -> PolicyPayload {
        PolicyPayload(
            allowEmailDrafts: true,
            allowCalendarWrites: false,
            allowTaskCreation: false,
            allowMemoryWrites: true,
            maxExecutionsPerDay: 25,
            maxMemoryItems: 10,
            requireExplicitConfirmation: true,
            localProcessingOnly: true
        )
    }
    
    /// Creates a standard payload (balanced)
    public static func standard() -> PolicyPayload {
        PolicyPayload(
            allowEmailDrafts: true,
            allowCalendarWrites: true,
            allowTaskCreation: true,
            allowMemoryWrites: true,
            maxExecutionsPerDay: 100,
            maxMemoryItems: 50,
            requireExplicitConfirmation: true,
            localProcessingOnly: true
        )
    }
    
    /// Creates a permissive payload (all features enabled)
    public static func permissive() -> PolicyPayload {
        PolicyPayload(
            allowEmailDrafts: true,
            allowCalendarWrites: true,
            allowTaskCreation: true,
            allowMemoryWrites: true,
            maxExecutionsPerDay: nil,
            maxMemoryItems: nil,
            requireExplicitConfirmation: true,
            localProcessingOnly: false
        )
    }
}

// MARK: - Convert to OperatorPolicy

extension PolicyTemplate {
    
    /// Converts template to OperatorPolicy for application
    public func toOperatorPolicy() -> OperatorPolicy {
        OperatorPolicy(
            enabled: true,
            allowEmailDrafts: policyPayload.allowEmailDrafts,
            allowCalendarWrites: policyPayload.allowCalendarWrites,
            allowTaskCreation: policyPayload.allowTaskCreation,
            allowMemoryWrites: policyPayload.allowMemoryWrites,
            maxExecutionsPerDay: policyPayload.maxExecutionsPerDay,
            requireExplicitConfirmation: policyPayload.requireExplicitConfirmation
        )
    }
}

// MARK: - Forbidden Keys Validation

extension PolicyTemplate {
    
    /// Forbidden keys that must never appear in policy
    public static let forbiddenKeys: [String] = [
        "body", "subject", "content", "draft", "prompt",
        "context", "note", "email", "attendees", "title",
        "description", "message", "text", "recipient", "sender"
    ]
    
    /// Validates template contains no forbidden keys
    public func validateNoForbiddenKeys() throws -> [String] {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(self)
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }
        
        return Self.findForbiddenKeys(in: json, path: "")
    }
    
    private static func findForbiddenKeys(in dict: [String: Any], path: String) -> [String] {
        var violations: [String] = []
        
        for (key, value) in dict {
            let fullPath = path.isEmpty ? key : "\(path).\(key)"
            
            if forbiddenKeys.contains(key.lowercased()) {
                violations.append("Forbidden key: \(fullPath)")
            }
            
            if let nested = value as? [String: Any] {
                violations.append(contentsOf: findForbiddenKeys(in: nested, path: fullPath))
            }
        }
        
        return violations
    }
}
