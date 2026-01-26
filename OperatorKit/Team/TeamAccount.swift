import Foundation

// ============================================================================
// TEAM ACCOUNT (Phase 10E)
//
// Team identity and membership for shared governance artifacts.
// Teams share ONLY metadata artifacts, never user content.
//
// WHAT TEAMS CAN SHARE (Metadata Only):
// ✅ Policy templates
// ✅ Diagnostics snapshots
// ✅ Quality summaries
// ✅ Evidence packet references
// ✅ Release acknowledgements
//
// WHAT TEAMS CANNOT SHARE (User Content):
// ❌ Drafts
// ❌ Memory items
// ❌ Context packets
// ❌ User inputs/prompts
// ❌ Execution state
//
// See: docs/SAFETY_CONTRACT.md (Section 14)
// ============================================================================

// MARK: - Team Account

/// Represents a team account for shared governance
public struct TeamAccount: Codable, Identifiable, Equatable {
    
    /// Unique team identifier
    public let id: String
    
    /// Team display name
    public let name: String
    
    /// When the team was created
    public let createdAt: Date
    
    /// Current user's role in this team
    public let memberRole: TeamRole
    
    /// Whether team features are active
    public let isActive: Bool
    
    /// Schema version for migration
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Initialization
    
    public init(
        id: String,
        name: String,
        createdAt: Date = Date(),
        memberRole: TeamRole = .member,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.memberRole = memberRole
        self.isActive = isActive
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    // MARK: - Display Helpers
    
    /// Abbreviated team ID for display
    public var shortId: String {
        String(id.prefix(8))
    }
    
    /// Role description
    public var roleDescription: String {
        memberRole.displayName
    }
}

// MARK: - Team Role

/// Roles within a team (for display only, NOT for execution enforcement)
public enum TeamRole: String, Codable, CaseIterable {
    case owner = "owner"
    case admin = "admin"
    case member = "member"
    
    /// Display name
    public var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .member: return "Member"
        }
    }
    
    /// Description
    public var description: String {
        switch self {
        case .owner: return "Full team management"
        case .admin: return "Can manage artifacts and members"
        case .member: return "Can view and upload artifacts"
        }
    }
    
    /// Icon
    public var icon: String {
        switch self {
        case .owner: return "crown.fill"
        case .admin: return "person.badge.key.fill"
        case .member: return "person.fill"
        }
    }
    
    /// Permissions (for UI display only, NOT enforcement)
    public var canManageMembers: Bool {
        self == .owner || self == .admin
    }
    
    public var canUploadArtifacts: Bool {
        true // All roles can upload
    }
    
    public var canDeleteTeam: Bool {
        self == .owner
    }
}

// MARK: - Team Membership

/// Represents a member of a team
public struct TeamMembership: Codable, Identifiable, Equatable {
    
    /// User ID
    public let userId: String
    
    /// Team ID
    public let teamId: String
    
    /// User's email (for display)
    public let email: String?
    
    /// Role in the team
    public let role: TeamRole
    
    /// When the member joined
    public let joinedAt: Date
    
    /// Unique identifier
    public var id: String { "\(teamId):\(userId)" }
    
    // MARK: - Initialization
    
    public init(
        userId: String,
        teamId: String,
        email: String? = nil,
        role: TeamRole,
        joinedAt: Date = Date()
    ) {
        self.userId = userId
        self.teamId = teamId
        self.email = email
        self.role = role
        self.joinedAt = joinedAt
    }
    
    /// Display name (email or shortened user ID)
    public var displayName: String {
        email ?? "User \(userId.prefix(8))..."
    }
}

// MARK: - Team Invite

/// Represents a pending team invite
public struct TeamInvite: Codable, Identifiable, Equatable {
    
    /// Invite ID
    public let id: String
    
    /// Team ID
    public let teamId: String
    
    /// Team name (for display)
    public let teamName: String
    
    /// Invited email
    public let email: String
    
    /// Role to be assigned
    public let role: TeamRole
    
    /// When the invite was created
    public let createdAt: Date
    
    /// When the invite expires
    public let expiresAt: Date
    
    /// Whether the invite is still valid
    public var isValid: Bool {
        Date() < expiresAt
    }
}

// MARK: - Team Feature Flag

/// Feature flag for team functionality
public enum TeamFeatureFlag {
    
    /// Whether team features are enabled
    #if TEAM_DISABLED
    public static let isEnabled = false
    #else
    public static let isEnabled = true
    #endif
    
    /// Storage key for team enabled preference
    public static let storageKey = "com.operatorkit.team.enabled"
    
    /// Default state (OFF by default)
    public static let defaultToggleState = false
}

// MARK: - Team Safety Config

/// Safety configuration for team features
public enum TeamSafetyConfig {
    
    /// Maximum team members (for validation)
    public static let maxTeamMembers = 100
    
    /// Invite expiration in days
    public static let inviteExpirationDays = 7
    
    /// Forbidden content keys (same as sync)
    public static var forbiddenContentKeys: [String] {
        SyncSafetyConfig.forbiddenContentKeys
    }
    
    /// Team-syncable artifact types
    public enum TeamArtifactType: String, CaseIterable, Codable {
        case policyTemplate = "policy_template"
        case diagnosticsSnapshot = "diagnostics_snapshot"
        case qualitySummary = "quality_summary"
        case evidencePacketRef = "evidence_packet_ref"
        case releaseAcknowledgement = "release_acknowledgement"
        
        public var displayName: String {
            switch self {
            case .policyTemplate: return "Policy Template"
            case .diagnosticsSnapshot: return "Diagnostics Snapshot"
            case .qualitySummary: return "Quality Summary"
            case .evidencePacketRef: return "Evidence Reference"
            case .releaseAcknowledgement: return "Release Acknowledgement"
            }
        }
        
        public var description: String {
            switch self {
            case .policyTemplate: return "Shared policy settings (read-only)"
            case .diagnosticsSnapshot: return "Aggregated diagnostics"
            case .qualitySummary: return "Pass rates and drift levels"
            case .evidencePacketRef: return "Hash and timestamp only"
            case .releaseAcknowledgement: return "Org-level release sign-off"
            }
        }
    }
}
