import Foundation

// ============================================================================
// TEAM STORE (Phase 10E)
//
// Local store for team state. All team data is fetched on-demand,
// not synchronized in background.
//
// INVARIANT: Team features do NOT affect execution
// INVARIANT: Role resolution is local and for UI display only
// INVARIANT: No background sync of team data
//
// See: docs/SAFETY_CONTRACT.md (Section 14)
// ============================================================================

/// Local store for team state
@MainActor
public final class TeamStore: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = TeamStore()
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let storageKey = "com.operatorkit.team.current"
    private let membersKey = "com.operatorkit.team.members"
    
    // MARK: - Published State
    
    @Published public private(set) var currentTeam: TeamAccount?
    @Published public private(set) var members: [TeamMembership] = []
    @Published public private(set) var pendingInvites: [TeamInvite] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: String?
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadCachedTeam()
    }
    
    // MARK: - Team State
    
    /// Whether user is part of a team
    public var hasTeam: Bool {
        currentTeam != nil
    }
    
    /// Current user's role (for UI display only)
    public var currentRole: TeamRole? {
        currentTeam?.memberRole
    }
    
    /// Whether current user can manage members (UI display only)
    public var canManageMembers: Bool {
        currentRole?.canManageMembers ?? false
    }
    
    // MARK: - Team Operations (via SupabaseClient)
    
    /// Creates a new team
    public func createTeam(name: String) async throws {
        guard SupabaseClient.shared.isSignedIn else {
            throw TeamError.notSignedIn
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Create team via Supabase
        let team = try await TeamSupabaseClient.shared.createTeam(name: name)
        
        currentTeam = team
        saveTeamCache()
        
        logDebug("Team created: \(team.shortId)", category: .flow)
    }
    
    /// Joins a team via invite code
    public func joinTeam(inviteCode: String) async throws {
        guard SupabaseClient.shared.isSignedIn else {
            throw TeamError.notSignedIn
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let team = try await TeamSupabaseClient.shared.joinTeam(inviteCode: inviteCode)
        
        currentTeam = team
        saveTeamCache()
        
        logDebug("Joined team: \(team.shortId)", category: .flow)
    }
    
    /// Leaves the current team
    public func leaveTeam() async throws {
        guard let team = currentTeam else { return }
        guard SupabaseClient.shared.isSignedIn else {
            throw TeamError.notSignedIn
        }
        
        isLoading = true
        defer { isLoading = false }
        
        try await TeamSupabaseClient.shared.leaveTeam(teamId: team.id)
        
        currentTeam = nil
        members = []
        clearTeamCache()
        
        logDebug("Left team: \(team.shortId)", category: .flow)
    }
    
    /// Refreshes team data from server
    public func refreshTeam() async {
        guard SupabaseClient.shared.isSignedIn else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            if let team = try await TeamSupabaseClient.shared.fetchCurrentTeam() {
                currentTeam = team
                members = try await TeamSupabaseClient.shared.fetchTeamMembers(teamId: team.id)
                saveTeamCache()
            } else {
                currentTeam = nil
                members = []
                clearTeamCache()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    // MARK: - Member Management
    
    /// Invites a member to the team
    public func inviteMember(email: String, role: TeamRole) async throws {
        guard let team = currentTeam else {
            throw TeamError.noTeam
        }
        guard canManageMembers else {
            throw TeamError.insufficientPermissions
        }
        
        isLoading = true
        defer { isLoading = false }
        
        try await TeamSupabaseClient.shared.inviteMember(
            teamId: team.id,
            email: email,
            role: role
        )
        
        logDebug("Invited member to team", category: .flow)
    }
    
    /// Removes a member from the team
    public func removeMember(userId: String) async throws {
        guard let team = currentTeam else {
            throw TeamError.noTeam
        }
        guard canManageMembers else {
            throw TeamError.insufficientPermissions
        }
        
        isLoading = true
        defer { isLoading = false }
        
        try await TeamSupabaseClient.shared.removeMember(teamId: team.id, userId: userId)
        
        members.removeAll { $0.userId == userId }
        
        logDebug("Removed member from team", category: .flow)
    }
    
    /// Updates a member's role
    public func updateMemberRole(userId: String, newRole: TeamRole) async throws {
        guard let team = currentTeam else {
            throw TeamError.noTeam
        }
        guard canManageMembers else {
            throw TeamError.insufficientPermissions
        }
        
        isLoading = true
        defer { isLoading = false }
        
        try await TeamSupabaseClient.shared.updateMemberRole(
            teamId: team.id,
            userId: userId,
            role: newRole
        )
        
        // Update local cache
        if let index = members.firstIndex(where: { $0.userId == userId }) {
            let member = members[index]
            members[index] = TeamMembership(
                userId: member.userId,
                teamId: member.teamId,
                email: member.email,
                role: newRole,
                joinedAt: member.joinedAt
            )
        }
        
        logDebug("Updated member role", category: .flow)
    }
    
    // MARK: - Cache
    
    private func loadCachedTeam() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let team = try? decoder.decode(TeamAccount.self, from: data) {
            currentTeam = team
        }
    }
    
    private func saveTeamCache() {
        guard let team = currentTeam else { return }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(team) {
            defaults.set(data, forKey: storageKey)
        }
    }
    
    private func clearTeamCache() {
        defaults.removeObject(forKey: storageKey)
        defaults.removeObject(forKey: membersKey)
    }
}

// MARK: - Team Error

public enum TeamError: Error, LocalizedError {
    case notSignedIn
    case noTeam
    case insufficientPermissions
    case teamNotFound
    case inviteExpired
    case inviteInvalid
    case alreadyMember
    case networkError(Error)
    case serverError(String)
    
    public var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Please sign in to access team features."
        case .noTeam:
            return "You are not part of a team."
        case .insufficientPermissions:
            return "You don't have permission for this action."
        case .teamNotFound:
            return "Team not found."
        case .inviteExpired:
            return "This invite has expired."
        case .inviteInvalid:
            return "Invalid invite code."
        case .alreadyMember:
            return "You are already a member of this team."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
