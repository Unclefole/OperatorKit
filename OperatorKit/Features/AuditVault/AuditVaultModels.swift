import Foundation
import CryptoKit

// ============================================================================
// AUDIT VAULT MODELS (Phase 13E)
//
// Zero-content event and lineage models.
// Store only hashes, counts, timestamps (day-rounded), and enum values.
//
// CONTAINS NO:
// - User text, drafts, prompts, context, titles, recipients, attendees, PII
// - Free-form strings (only enum rawValues and fixed literals)
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No free text fields
// ❌ No PII
// ✅ Enum-based only
// ✅ Hashes only
// ✅ Day-rounded timestamps
// ✅ Deterministic serialization
// ============================================================================

// MARK: - Forbidden Keys

public enum AuditVaultForbiddenKeys {
    
    /// Keys that must NEVER appear in Audit Vault models
    public static let all: Set<String> = [
        "body", "subject", "content", "draft", "prompt", "context",
        "message", "text", "title", "description", "recipient", "attendees",
        "email", "phone", "address", "name", "sender", "url", "token",
        "secret", "password", "note", "notes", "freeText", "userText",
        "userData", "personalData", "identifier", "deviceId", "userId"
    ]
    
    /// Patterns that must not appear in any string values
    public static let forbiddenPatterns: [String] = [
        "@gmail.com", "@yahoo.com", "@outlook.com", "@icloud.com",
        "+1", "555-", "(555)",
        "Dear ", "Hi ", "Hello "
    ]
    
    /// Validate a string contains no forbidden patterns
    public static func validate(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        for pattern in forbiddenPatterns {
            if lowercased.contains(pattern.lowercased()) {
                return false
            }
        }
        return true
    }
}

// MARK: - Audit Vault Event Kind

public enum AuditVaultEventKind: String, Codable, CaseIterable {
    case lineageCreated = "lineage_created"
    case lineageEdited = "lineage_edited"
    case lineageExported = "lineage_exported"
    case firewallVerified = "firewall_verified"
    case vaultPurged = "vault_purged"
    
    public var displayName: String {
        switch self {
        case .lineageCreated: return "Lineage Created"
        case .lineageEdited: return "Lineage Edited"
        case .lineageExported: return "Lineage Exported"
        case .firewallVerified: return "Firewall Verified"
        case .vaultPurged: return "Vault Purged"
        }
    }
    
    public var icon: String {
        switch self {
        case .lineageCreated: return "plus.circle"
        case .lineageEdited: return "pencil.circle"
        case .lineageExported: return "square.and.arrow.up"
        case .firewallVerified: return "checkmark.shield"
        case .vaultPurged: return "trash"
        }
    }
}

// MARK: - Audit Vault Outcome Type

public enum AuditVaultOutcomeType: String, Codable, CaseIterable {
    case emailDraft = "email_draft"
    case calendarEvent = "calendar_event"
    case reminder = "reminder"
    case task = "task"
    case summary = "summary"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .emailDraft: return "Email Draft"
        case .calendarEvent: return "Calendar Event"
        case .reminder: return "Reminder"
        case .task: return "Task"
        case .summary: return "Summary"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Audit Vault Policy Decision

public enum AuditVaultPolicyDecision: String, Codable, CaseIterable {
    case allowed = "allowed"
    case denied = "denied"
    case notApplicable = "not_applicable"
}

// MARK: - Audit Vault Tier

public enum AuditVaultTier: String, Codable, CaseIterable {
    case free = "free"
    case pro = "pro"
    case team = "team"
    case lifetimeSovereign = "lifetime_sovereign"
}

// MARK: - Audit Vault Context Slot

public enum AuditVaultContextSlot: String, Codable, CaseIterable {
    case slotA = "slot_a"
    case slotB = "slot_b"
    case slotC = "slot_c"
    case none = "none"
    
    public var displayName: String {
        switch self {
        case .slotA: return "Context A"
        case .slotB: return "Context B"
        case .slotC: return "Context C"
        case .none: return "No Context"
        }
    }
}

// MARK: - Audit Vault Event

public struct AuditVaultEvent: Identifiable, Codable, Equatable {
    
    /// Unique event ID
    public let id: UUID
    
    /// Monotonic sequence number for ordering
    public let sequenceNumber: Int
    
    /// Day-rounded creation date (yyyy-MM-dd)
    public let createdAtDayRounded: String
    
    /// Event kind
    public let kind: AuditVaultEventKind
    
    /// Associated lineage (if applicable)
    public let lineage: AuditVaultLineage?
    
    /// Schema version
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Init
    
    public init(
        id: UUID = UUID(),
        sequenceNumber: Int,
        createdAtDayRounded: String? = nil,
        kind: AuditVaultEventKind,
        lineage: AuditVaultLineage? = nil
    ) {
        self.id = id
        self.sequenceNumber = sequenceNumber
        self.createdAtDayRounded = createdAtDayRounded ?? Self.dayRoundedNow()
        self.kind = kind
        self.lineage = lineage
        self.schemaVersion = Self.currentSchemaVersion
    }
    
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
            "seq:\(sequenceNumber)",
            "date:\(createdAtDayRounded)",
            "kind:\(kind.rawValue)",
            "lineage:\(lineage?.deterministicHash ?? "none")",
            "schema:\(schemaVersion)"
        ]
        let combined = components.joined(separator: "|")
        let data = Data(combined.utf8)
        let hash = SHA256.hash(data: data)
        return hash.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Audit Vault Summary

public struct AuditVaultSummary: Codable, Equatable {
    public let totalEvents: Int
    public let eventsLast7Days: Int
    public let countByKind: [String: Int]
    public let editCount: Int
    public let exportCount: Int
    public let lastVerifiedDayRounded: String?
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public init(
        totalEvents: Int,
        eventsLast7Days: Int,
        countByKind: [String: Int],
        editCount: Int,
        exportCount: Int,
        lastVerifiedDayRounded: String?
    ) {
        self.totalEvents = totalEvents
        self.eventsLast7Days = eventsLast7Days
        self.countByKind = countByKind
        self.editCount = editCount
        self.exportCount = exportCount
        self.lastVerifiedDayRounded = lastVerifiedDayRounded
        self.schemaVersion = Self.currentSchemaVersion
    }
}
