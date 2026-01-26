import Foundation

// ============================================================================
// OPERATOR POLICY (Phase 10C)
//
// User-defined execution constraints that CONSTRAIN what OperatorKit
// is allowed to draft or execute.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ NO content fields
// ❌ NO context references
// ❌ NO behavior changes in ExecutionEngine/ApprovalGate/ModelRouter
// ✅ Enforced at UI entry points ONLY
// ✅ Fail closed (deny if uncertain)
// ✅ Explainable in plain language
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

// MARK: - Operator Policy

/// User-defined execution policy (content-free)
public struct OperatorPolicy: Codable, Equatable {
    
    /// Unique identifier
    public let id: UUID
    
    /// When the policy was created
    public let createdAt: Date
    
    /// Whether the policy is enabled
    public var enabled: Bool
    
    // MARK: - Capability Toggles
    
    /// Allow drafting emails
    public var allowEmailDrafts: Bool
    
    /// Allow writing to calendar (create/update events)
    public var allowCalendarWrites: Bool
    
    /// Allow creating reminders/tasks
    public var allowTaskCreation: Bool
    
    /// Allow saving to memory
    public var allowMemoryWrites: Bool
    
    // MARK: - Scope Limits
    
    /// Maximum executions per day (nil = unlimited)
    public var maxExecutionsPerDay: Int?
    
    /// Require explicit confirmation for all actions
    public var requireExplicitConfirmation: Bool
    
    // MARK: - Metadata
    
    /// Schema version for migration
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        enabled: Bool = true,
        allowEmailDrafts: Bool = true,
        allowCalendarWrites: Bool = true,
        allowTaskCreation: Bool = true,
        allowMemoryWrites: Bool = true,
        maxExecutionsPerDay: Int? = nil,
        requireExplicitConfirmation: Bool = true
    ) {
        self.id = id
        self.createdAt = createdAt
        self.enabled = enabled
        self.allowEmailDrafts = allowEmailDrafts
        self.allowCalendarWrites = allowCalendarWrites
        self.allowTaskCreation = allowTaskCreation
        self.allowMemoryWrites = allowMemoryWrites
        self.maxExecutionsPerDay = maxExecutionsPerDay
        self.requireExplicitConfirmation = requireExplicitConfirmation
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    /// Default conservative policy
    /// - All capabilities enabled (user can disable)
    /// - Explicit confirmation required
    /// - No daily limit (subscription limits apply separately)
    public static var defaultPolicy: OperatorPolicy {
        OperatorPolicy(
            enabled: true,
            allowEmailDrafts: true,
            allowCalendarWrites: true,
            allowTaskCreation: true,
            allowMemoryWrites: true,
            maxExecutionsPerDay: nil,
            requireExplicitConfirmation: true
        )
    }
    
    /// Restrictive policy (all capabilities disabled)
    public static var restrictive: OperatorPolicy {
        OperatorPolicy(
            enabled: true,
            allowEmailDrafts: false,
            allowCalendarWrites: false,
            allowTaskCreation: false,
            allowMemoryWrites: false,
            maxExecutionsPerDay: 0,
            requireExplicitConfirmation: true
        )
    }
    
    // MARK: - Display Helpers
    
    /// Plain language summary of the policy
    public var summary: String {
        if !enabled {
            return "Policy disabled — all capabilities allowed"
        }
        
        var parts: [String] = []
        
        // Capabilities
        var allowed: [String] = []
        var denied: [String] = []
        
        if allowEmailDrafts { allowed.append("email drafts") } else { denied.append("email drafts") }
        if allowCalendarWrites { allowed.append("calendar writes") } else { denied.append("calendar writes") }
        if allowTaskCreation { allowed.append("task creation") } else { denied.append("task creation") }
        if allowMemoryWrites { allowed.append("memory saves") } else { denied.append("memory saves") }
        
        if !denied.isEmpty {
            parts.append("Blocked: \(denied.joined(separator: ", "))")
        }
        
        // Limits
        if let max = maxExecutionsPerDay {
            parts.append("Limit: \(max) executions/day")
        }
        
        if requireExplicitConfirmation {
            parts.append("Explicit confirmation required")
        }
        
        return parts.isEmpty ? "All capabilities allowed" : parts.joined(separator: " • ")
    }
    
    /// Short status text
    public var statusText: String {
        if !enabled {
            return "Disabled"
        }
        
        let blockedCount = [
            !allowEmailDrafts,
            !allowCalendarWrites,
            !allowTaskCreation,
            !allowMemoryWrites
        ].filter { $0 }.count
        
        if blockedCount == 0 {
            return "All Allowed"
        } else if blockedCount == 4 {
            return "All Blocked"
        } else {
            return "\(blockedCount) Blocked"
        }
    }
}

// MARK: - Policy Capability

/// Individual capability that can be toggled
public enum PolicyCapability: String, CaseIterable, Codable {
    case emailDrafts = "email_drafts"
    case calendarWrites = "calendar_writes"
    case taskCreation = "task_creation"
    case memoryWrites = "memory_writes"
    
    /// Display name
    public var displayName: String {
        switch self {
        case .emailDrafts: return "Email Drafts"
        case .calendarWrites: return "Calendar Writes"
        case .taskCreation: return "Task Creation"
        case .memoryWrites: return "Memory Saves"
        }
    }
    
    /// Description
    public var description: String {
        switch self {
        case .emailDrafts: return "Allow drafting and presenting emails"
        case .calendarWrites: return "Allow creating and updating calendar events"
        case .taskCreation: return "Allow creating reminders and tasks"
        case .memoryWrites: return "Allow saving items to memory"
        }
    }
    
    /// SF Symbol icon
    public var icon: String {
        switch self {
        case .emailDrafts: return "envelope"
        case .calendarWrites: return "calendar"
        case .taskCreation: return "checklist"
        case .memoryWrites: return "brain.head.profile"
        }
    }
    
    /// Check if capability is allowed by policy
    public func isAllowed(by policy: OperatorPolicy) -> Bool {
        guard policy.enabled else { return true } // Disabled policy = all allowed
        
        switch self {
        case .emailDrafts: return policy.allowEmailDrafts
        case .calendarWrites: return policy.allowCalendarWrites
        case .taskCreation: return policy.allowTaskCreation
        case .memoryWrites: return policy.allowMemoryWrites
        }
    }
}
