import Foundation

// ============================================================================
// CUSTOMER AUDIT TRAIL (Phase 10P)
//
// Zero-content audit trail for customer proof and reproducibility.
// Metadata only: counts, enums, hashes, day-rounded timestamps.
//
// NOTE: This is separate from the execution-level AuditTrail in ExecutionResult.
// This is for customer-facing diagnostics and support reproducibility.
// Type names use "Customer" prefix to avoid conflict with existing AuditTrail.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content (drafts, subjects, bodies, event titles, recipients)
// ❌ No free-text notes
// ❌ No raw timestamps (day-rounded only)
// ❌ No networking
// ✅ Enum-based only
// ✅ Day-rounded timestamps
// ✅ Ring buffer (max 500 events)
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

// MARK: - Customer Audit Event Kind

public enum CustomerAuditEventKind: String, Codable, CaseIterable {
    case intentSubmitted = "intent_submitted"
    case approvalGranted = "approval_granted"
    case approvalDenied = "approval_denied"
    case executionStarted = "execution_started"
    case executionSucceeded = "execution_succeeded"
    case executionFailed = "execution_failed"
    case executionCancelled = "execution_cancelled"
    case draftSaved = "draft_saved"
    case templateUsed = "template_used"
    case templateCompleted = "template_completed"
    case policyChecked = "policy_checked"
    case policyDenied = "policy_denied"
    
    public var displayName: String {
        switch self {
        case .intentSubmitted: return "Intent Submitted"
        case .approvalGranted: return "Approval Granted"
        case .approvalDenied: return "Approval Denied"
        case .executionStarted: return "Execution Started"
        case .executionSucceeded: return "Execution Succeeded"
        case .executionFailed: return "Execution Failed"
        case .executionCancelled: return "Execution Cancelled"
        case .draftSaved: return "Draft Saved"
        case .templateUsed: return "Template Used"
        case .templateCompleted: return "Template Completed"
        case .policyChecked: return "Policy Checked"
        case .policyDenied: return "Policy Denied"
        }
    }
    
    public var icon: String {
        switch self {
        case .intentSubmitted: return "text.bubble"
        case .approvalGranted: return "checkmark.shield"
        case .approvalDenied: return "xmark.shield"
        case .executionStarted: return "play.circle"
        case .executionSucceeded: return "checkmark.circle.fill"
        case .executionFailed: return "exclamationmark.triangle.fill"
        case .executionCancelled: return "xmark.circle"
        case .draftSaved: return "doc.fill"
        case .templateUsed: return "doc.on.doc"
        case .templateCompleted: return "checkmark.seal"
        case .policyChecked: return "shield"
        case .policyDenied: return "shield.slash"
        }
    }
}

// MARK: - Customer Audit Event Result

public enum CustomerAuditEventResult: String, Codable {
    case success = "success"
    case failure = "failure"
    case cancelled = "cancelled"
    case denied = "denied"
    case partial = "partial"
    case pending = "pending"
}

// MARK: - Customer Audit Policy Decision

public enum CustomerAuditPolicyDecision: String, Codable {
    case allowed = "allowed"
    case denied = "denied"
    case limitReached = "limit_reached"
    case notApplicable = "not_applicable"
}

// MARK: - Customer Audit Event

public struct CustomerAuditEvent: Identifiable, Codable, Equatable {
    
    // MARK: - Identity
    
    public let id: UUID
    
    // MARK: - Timing (Day-Rounded Only)
    
    /// Day-rounded creation date (yyyy-MM-dd)
    public let createdAtDayRounded: String
    
    // MARK: - Event Details
    
    /// Kind of event
    public let kind: CustomerAuditEventKind
    
    /// Intent type (e.g., "email_draft", "calendar_event")
    public let intentType: String
    
    /// Output type (e.g., "draft", "event", "reminder")
    public let outputType: String
    
    /// Result of the event
    public let result: CustomerAuditEventResult
    
    /// Failure category (if applicable)
    public let failureCategory: FailureCategory?
    
    /// Backend used (e.g., "apple_on_device", "openai")
    public let backendUsed: String
    
    /// Policy decision (if applicable)
    public let policyDecision: CustomerAuditPolicyDecision?
    
    /// Tier at time of event
    public let tierAtTime: String
    
    /// Schema version
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        createdAtDayRounded: String? = nil,
        kind: CustomerAuditEventKind,
        intentType: String,
        outputType: String,
        result: CustomerAuditEventResult,
        failureCategory: FailureCategory? = nil,
        backendUsed: String,
        policyDecision: CustomerAuditPolicyDecision? = nil,
        tierAtTime: String
    ) {
        self.id = id
        self.createdAtDayRounded = createdAtDayRounded ?? Self.dayRoundedNow()
        self.kind = kind
        self.intentType = intentType
        self.outputType = outputType
        self.result = result
        self.failureCategory = failureCategory
        self.backendUsed = backendUsed
        self.policyDecision = policyDecision
        self.tierAtTime = tierAtTime
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    // MARK: - Day-Rounded Date
    
    private static func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}

// MARK: - Customer Audit Trail Summary

public struct CustomerAuditTrailSummary: Codable, Equatable {
    
    /// Total events in trail
    public let totalEvents: Int
    
    /// Events in last 7 days
    public let eventsLast7Days: Int
    
    /// Count by event kind
    public let countByKind: [String: Int]
    
    /// Count by result
    public let countByResult: [String: Int]
    
    /// Success rate
    public let successRate: Double?
    
    /// Most recent 20 events (metadata only)
    public let recentEvents: [CustomerAuditEvent]
    
    /// Schema version
    public let schemaVersion: Int
    
    /// Day-rounded capture date
    public let capturedAt: String
    
    public static let currentSchemaVersion = 1
}

// MARK: - Forbidden Keys Validation

extension CustomerAuditEvent {
    
    /// Forbidden keys that must never appear in audit events
    public static let forbiddenKeys: [String] = [
        "body", "subject", "content", "draft", "prompt",
        "context", "note", "email", "attendees", "title",
        "description", "message", "text", "recipient", "sender",
        "userId", "deviceId", "rawTimestamp", "freeText"
    ]
    
    /// Validates event contains no forbidden keys
    public func validateNoForbiddenKeys() throws -> [String] {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(self)
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }
        
        var violations: [String] = []
        for key in json.keys {
            if Self.forbiddenKeys.contains(key.lowercased()) {
                violations.append("Forbidden key: \(key)")
            }
        }
        
        return violations
    }
}
