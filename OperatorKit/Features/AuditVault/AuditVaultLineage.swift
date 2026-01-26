import Foundation
import CryptoKit

// ============================================================================
// AUDIT VAULT LINEAGE (Phase 13E)
//
// Zero-content provenance model.
// Contains only hashes, enums, counts - never user content.
//
// Example display:
// "Drafted Outcome edited 3 times. Lineage: Procedure <hash>, ContextSlot <id>, OutcomeType <type>."
//
// CONTAINS NO:
// - User text, drafts, prompts, context, titles, recipients, PII
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No free text
// ✅ Hashes only
// ✅ Enums only
// ✅ Counts only
// ✅ Deterministic
// ============================================================================

// MARK: - Audit Vault Lineage

public struct AuditVaultLineage: Codable, Equatable {
    
    // MARK: - Lineage Fields (All Content-Free)
    
    /// Unique lineage ID
    public let id: UUID
    
    /// Procedure hash (from ProcedureTemplate.deterministicHash, if applicable)
    public let procedureHash: String?
    
    /// Context slot identifier (enum-based, not content)
    public let contextSlot: AuditVaultContextSlot
    
    /// Outcome type
    public let outcomeType: AuditVaultOutcomeType
    
    /// Policy decision at creation
    public let policyDecision: AuditVaultPolicyDecision
    
    /// Tier at time of creation
    public let tierAtTime: AuditVaultTier
    
    /// Edit count (number of times edited)
    public let editCount: Int
    
    /// Day-rounded creation date
    public let createdAtDayRounded: String
    
    /// Day-rounded last modified date
    public let lastModifiedDayRounded: String
    
    /// Schema version
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Init
    
    public init(
        id: UUID = UUID(),
        procedureHash: String? = nil,
        contextSlot: AuditVaultContextSlot = .none,
        outcomeType: AuditVaultOutcomeType,
        policyDecision: AuditVaultPolicyDecision = .allowed,
        tierAtTime: AuditVaultTier = .free,
        editCount: Int = 0,
        createdAtDayRounded: String? = nil,
        lastModifiedDayRounded: String? = nil
    ) {
        self.id = id
        self.procedureHash = procedureHash
        self.contextSlot = contextSlot
        self.outcomeType = outcomeType
        self.policyDecision = policyDecision
        self.tierAtTime = tierAtTime
        self.editCount = editCount
        
        let now = Self.dayRoundedNow()
        self.createdAtDayRounded = createdAtDayRounded ?? now
        self.lastModifiedDayRounded = lastModifiedDayRounded ?? now
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    // MARK: - Day Rounding
    
    private static func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
    
    // MARK: - Deterministic Hash
    
    public var deterministicHash: String {
        let components = [
            "id:\(id.uuidString)",
            "proc:\(procedureHash ?? "none")",
            "slot:\(contextSlot.rawValue)",
            "outcome:\(outcomeType.rawValue)",
            "policy:\(policyDecision.rawValue)",
            "tier:\(tierAtTime.rawValue)",
            "edits:\(editCount)",
            "created:\(createdAtDayRounded)",
            "schema:\(schemaVersion)"
        ]
        let combined = components.joined(separator: "|")
        let data = Data(combined.utf8)
        let hash = SHA256.hash(data: data)
        return hash.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Display
    
    public var displaySummary: String {
        var parts: [String] = []
        
        parts.append("\(outcomeType.displayName)")
        
        if editCount > 0 {
            parts.append("edited \(editCount) time\(editCount == 1 ? "" : "s")")
        }
        
        if let procHash = procedureHash {
            parts.append("Procedure: \(procHash.prefix(8))")
        }
        
        parts.append("Context: \(contextSlot.displayName)")
        
        return parts.joined(separator: " • ")
    }
    
    // MARK: - Increment Edit
    
    public func withIncrementedEditCount() -> AuditVaultLineage {
        AuditVaultLineage(
            id: self.id,
            procedureHash: self.procedureHash,
            contextSlot: self.contextSlot,
            outcomeType: self.outcomeType,
            policyDecision: self.policyDecision,
            tierAtTime: self.tierAtTime,
            editCount: self.editCount + 1,
            createdAtDayRounded: self.createdAtDayRounded,
            lastModifiedDayRounded: Self.dayRoundedNow()
        )
    }
}

// MARK: - Lineage Validation

extension AuditVaultLineage {
    
    /// Validate lineage contains no forbidden content
    public func validate() -> [String] {
        var errors: [String] = []
        
        // Validate procedure hash if present (should only contain hex chars)
        if let procHash = procedureHash {
            let allowedChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
            if procHash.unicodeScalars.contains(where: { !allowedChars.contains($0) }) {
                errors.append("Procedure hash contains invalid characters")
            }
        }
        
        // Validate no forbidden patterns in any string representation
        let jsonData = try? JSONEncoder().encode(self)
        if let data = jsonData, let jsonString = String(data: data, encoding: .utf8) {
            if !AuditVaultForbiddenKeys.validate(jsonString) {
                errors.append("Lineage contains forbidden patterns")
            }
        }
        
        return errors
    }
}

// MARK: - Synthetic Lineage Generator (DEBUG only)

#if DEBUG
public enum SyntheticAuditVaultLineage {
    
    /// Generate a synthetic lineage for testing/demo
    public static func generate(index: Int) -> AuditVaultLineage {
        let outcomes = AuditVaultOutcomeType.allCases
        let slots = AuditVaultContextSlot.allCases
        let tiers = AuditVaultTier.allCases
        
        return AuditVaultLineage(
            id: UUID(),
            procedureHash: String(format: "%016x", index * 12345),
            contextSlot: slots[index % slots.count],
            outcomeType: outcomes[index % outcomes.count],
            policyDecision: .allowed,
            tierAtTime: tiers[index % tiers.count],
            editCount: index % 5,
            createdAtDayRounded: "2099-01-\(String(format: "%02d", (index % 28) + 1))"
        )
    }
}
#endif
