import Foundation

// ============================================================================
// TEAM SUPABASE CLIENT (Phase 10E)
//
// Extends SupabaseClient for team-specific operations.
// All network calls are user-initiated only.
//
// INVARIANT: No background sync
// INVARIANT: No execution enforcement
// INVARIANT: Metadata-only artifacts
//
// See: docs/SAFETY_CONTRACT.md (Section 14)
// ============================================================================

/// Team-specific Supabase operations
@MainActor
public final class TeamSupabaseClient {
    
    // MARK: - Singleton
    
    public static let shared = TeamSupabaseClient()
    
    // MARK: - Dependencies
    
    private var supabase: SupabaseClient { SupabaseClient.shared }
    
    private init() {}
    
    // MARK: - Team CRUD
    
    /// Creates a new team
    public func createTeam(name: String) async throws -> TeamAccount {
        guard supabase.isConfigured else { throw SyncError.notConfigured }
        guard supabase.isSignedIn else { throw TeamError.notSignedIn }
        guard let user = supabase.currentUser else { throw TeamError.notSignedIn }
        
        // Create team via REST API
        let teamId = UUID().uuidString
        let now = Date()
        
        let teamData: [String: Any] = [
            "id": teamId,
            "name": name,
            "owner_id": user.id,
            "created_at": ISO8601DateFormatter().string(from: now)
        ]
        
        try await supabase.insertRow(table: "teams", data: teamData)
        
        // Add owner as member
        let memberData: [String: Any] = [
            "team_id": teamId,
            "user_id": user.id,
            "role": TeamRole.owner.rawValue,
            "joined_at": ISO8601DateFormatter().string(from: now)
        ]
        
        try await supabase.insertRow(table: "team_members", data: memberData)
        
        return TeamAccount(
            id: teamId,
            name: name,
            createdAt: now,
            memberRole: .owner,
            isActive: true
        )
    }
    
    /// Fetches the current user's team
    public func fetchCurrentTeam() async throws -> TeamAccount? {
        guard supabase.isConfigured else { throw SyncError.notConfigured }
        guard supabase.isSignedIn else { throw TeamError.notSignedIn }
        guard let user = supabase.currentUser else { throw TeamError.notSignedIn }
        
        // Query team membership
        let memberships: [TeamMembershipResponse] = try await supabase.query(
            table: "team_members",
            filter: "user_id=eq.\(user.id)",
            select: "team_id,role,joined_at,teams(id,name,created_at)"
        )
        
        guard let membership = memberships.first,
              let team = membership.team else {
            return nil
        }
        
        return TeamAccount(
            id: team.id,
            name: team.name,
            createdAt: team.createdAt,
            memberRole: TeamRole(rawValue: membership.role) ?? .member,
            isActive: true
        )
    }
    
    /// Fetches team members
    public func fetchTeamMembers(teamId: String) async throws -> [TeamMembership] {
        guard supabase.isConfigured else { throw SyncError.notConfigured }
        guard supabase.isSignedIn else { throw TeamError.notSignedIn }
        
        let responses: [TeamMembershipResponse] = try await supabase.query(
            table: "team_members",
            filter: "team_id=eq.\(teamId)",
            select: "user_id,team_id,role,joined_at,users(email)"
        )
        
        return responses.map { response in
            TeamMembership(
                userId: response.userId,
                teamId: response.teamId,
                email: response.userEmail,
                role: TeamRole(rawValue: response.role) ?? .member,
                joinedAt: response.joinedAt
            )
        }
    }
    
    /// Joins a team via invite code
    public func joinTeam(inviteCode: String) async throws -> TeamAccount {
        guard supabase.isConfigured else { throw SyncError.notConfigured }
        guard supabase.isSignedIn else { throw TeamError.notSignedIn }
        guard let user = supabase.currentUser else { throw TeamError.notSignedIn }
        
        // Fetch invite
        let invites: [TeamInviteResponse] = try await supabase.query(
            table: "team_invites",
            filter: "code=eq.\(inviteCode)",
            select: "id,team_id,role,expires_at,teams(id,name,created_at)"
        )
        
        guard let invite = invites.first else {
            throw TeamError.inviteInvalid
        }
        
        // Check expiration
        if Date() > invite.expiresAt {
            throw TeamError.inviteExpired
        }
        
        guard let team = invite.team else {
            throw TeamError.teamNotFound
        }
        
        // Add as member
        let now = Date()
        let memberData: [String: Any] = [
            "team_id": team.id,
            "user_id": user.id,
            "role": invite.role,
            "joined_at": ISO8601DateFormatter().string(from: now)
        ]
        
        try await supabase.insertRow(table: "team_members", data: memberData)
        
        // Delete used invite
        try await supabase.deleteRow(table: "team_invites", filter: "id=eq.\(invite.id)")
        
        return TeamAccount(
            id: team.id,
            name: team.name,
            createdAt: team.createdAt,
            memberRole: TeamRole(rawValue: invite.role) ?? .member,
            isActive: true
        )
    }
    
    /// Leaves a team
    public func leaveTeam(teamId: String) async throws {
        guard supabase.isConfigured else { throw SyncError.notConfigured }
        guard supabase.isSignedIn else { throw TeamError.notSignedIn }
        guard let user = supabase.currentUser else { throw TeamError.notSignedIn }
        
        try await supabase.deleteRow(
            table: "team_members",
            filter: "team_id=eq.\(teamId)&user_id=eq.\(user.id)"
        )
    }
    
    // MARK: - Member Management
    
    /// Invites a member
    public func inviteMember(teamId: String, email: String, role: TeamRole) async throws {
        guard supabase.isConfigured else { throw SyncError.notConfigured }
        guard supabase.isSignedIn else { throw TeamError.notSignedIn }
        
        let inviteCode = UUID().uuidString.prefix(8).lowercased()
        let expiresAt = Calendar.current.date(
            byAdding: .day,
            value: TeamSafetyConfig.inviteExpirationDays,
            to: Date()
        )!
        
        let inviteData: [String: Any] = [
            "id": UUID().uuidString,
            "team_id": teamId,
            "email": email,
            "role": role.rawValue,
            "code": String(inviteCode),
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "expires_at": ISO8601DateFormatter().string(from: expiresAt)
        ]
        
        try await supabase.insertRow(table: "team_invites", data: inviteData)
    }
    
    /// Removes a member
    public func removeMember(teamId: String, userId: String) async throws {
        guard supabase.isConfigured else { throw SyncError.notConfigured }
        guard supabase.isSignedIn else { throw TeamError.notSignedIn }
        
        try await supabase.deleteRow(
            table: "team_members",
            filter: "team_id=eq.\(teamId)&user_id=eq.\(userId)"
        )
    }
    
    /// Updates a member's role
    public func updateMemberRole(teamId: String, userId: String, role: TeamRole) async throws {
        guard supabase.isConfigured else { throw SyncError.notConfigured }
        guard supabase.isSignedIn else { throw TeamError.notSignedIn }
        
        try await supabase.updateRow(
            table: "team_members",
            filter: "team_id=eq.\(teamId)&user_id=eq.\(userId)",
            data: ["role": role.rawValue]
        )
    }
    
    // MARK: - Team Artifacts
    
    /// Uploads a team artifact
    public func uploadTeamArtifact(
        teamId: String,
        artifactType: TeamSafetyConfig.TeamArtifactType,
        jsonData: Data
    ) async throws -> String {
        guard supabase.isConfigured else { throw SyncError.notConfigured }
        guard supabase.isSignedIn else { throw TeamError.notSignedIn }
        guard let user = supabase.currentUser else { throw TeamError.notSignedIn }
        
        // Validate artifact (fail closed)
        let validationResult = TeamArtifactValidator.shared.validate(
            jsonData: jsonData,
            artifactType: artifactType
        )
        
        guard validationResult.isValid else {
            throw SyncError.payloadContainsForbiddenContent(
                validationResult.errors.first ?? "Validation failed"
            )
        }
        
        let artifactId = UUID().uuidString
        
        let artifactData: [String: Any] = [
            "id": artifactId,
            "team_id": teamId,
            "user_id": user.id,
            "artifact_type": artifactType.rawValue,
            "payload": String(data: jsonData, encoding: .utf8) ?? "",
            "size_bytes": jsonData.count,
            "uploaded_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        try await supabase.insertRow(table: "team_artifacts", data: artifactData)
        
        logDebug("Team artifact uploaded: type=\(artifactType.rawValue), size=\(jsonData.count)", category: .flow)
        
        return artifactId
    }
    
    /// Lists team artifacts
    public func listTeamArtifacts(teamId: String) async throws -> [TeamArtifactMetadata] {
        guard supabase.isConfigured else { throw SyncError.notConfigured }
        guard supabase.isSignedIn else { throw TeamError.notSignedIn }
        
        let responses: [TeamArtifactResponse] = try await supabase.query(
            table: "team_artifacts",
            filter: "team_id=eq.\(teamId)",
            select: "id,artifact_type,size_bytes,uploaded_at,user_id"
        )
        
        return responses.map { response in
            TeamArtifactMetadata(
                id: response.id,
                artifactType: response.artifactType,
                sizeBytes: response.sizeBytes,
                uploadedAt: response.uploadedAt,
                uploadedBy: response.userId
            )
        }
    }
    
    /// Deletes a team artifact
    public func deleteTeamArtifact(artifactId: String) async throws {
        guard supabase.isConfigured else { throw SyncError.notConfigured }
        guard supabase.isSignedIn else { throw TeamError.notSignedIn }
        
        try await supabase.deleteRow(table: "team_artifacts", filter: "id=eq.\(artifactId)")
    }
}

// MARK: - Response Types

private struct TeamMembershipResponse: Codable {
    let userId: String
    let teamId: String
    let role: String
    let joinedAt: Date
    let team: TeamResponse?
    let userEmail: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case teamId = "team_id"
        case role
        case joinedAt = "joined_at"
        case team = "teams"
        case userEmail = "users"
    }
}

private struct TeamResponse: Codable {
    let id: String
    let name: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt = "created_at"
    }
}

private struct TeamInviteResponse: Codable {
    let id: String
    let teamId: String
    let role: String
    let expiresAt: Date
    let team: TeamResponse?
    
    enum CodingKeys: String, CodingKey {
        case id
        case teamId = "team_id"
        case role
        case expiresAt = "expires_at"
        case team = "teams"
    }
}

private struct TeamArtifactResponse: Codable {
    let id: String
    let artifactType: String
    let sizeBytes: Int
    let uploadedAt: Date
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case artifactType = "artifact_type"
        case sizeBytes = "size_bytes"
        case uploadedAt = "uploaded_at"
        case userId = "user_id"
    }
}

// MARK: - Team Artifact Metadata

/// Metadata about a team artifact (no payload)
public struct TeamArtifactMetadata: Codable, Identifiable {
    public let id: String
    public let artifactType: String
    public let sizeBytes: Int
    public let uploadedAt: Date
    public let uploadedBy: String
    
    public var artifactTypeDisplayName: String {
        TeamSafetyConfig.TeamArtifactType(rawValue: artifactType)?.displayName ?? artifactType.capitalized
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }
}

// MARK: - SupabaseClient Extensions

extension SupabaseClient {
    
    /// Generic query method
    func query<T: Codable>(table: String, filter: String, select: String) async throws -> [T] {
        guard isConfigured else { throw SyncError.notConfigured }
        guard isSignedIn else { throw SyncError.notSignedIn }
        guard let restURL = SupabaseConfig.restURL else { throw SyncError.notConfigured }
        
        var components = URLComponents(url: restURL.appendingPathComponent(table), resolvingAgainstBaseURL: false)!
        components.queryItems = filter.split(separator: "&").map { part in
            let kv = part.split(separator: "=", maxSplits: 1)
            return URLQueryItem(name: String(kv[0]), value: kv.count > 1 ? String(kv[1]) : nil)
        }
        components.queryItems?.append(URLQueryItem(name: "select", value: select))
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        addAuthHeaders(to: &request)
        
        let (data, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 400 else {
            throw SyncError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0, "Query failed")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([T].self, from: data)
    }
    
    /// Insert row
    func insertRow(table: String, data: [String: Any]) async throws {
        guard isConfigured else { throw SyncError.notConfigured }
        guard isSignedIn else { throw SyncError.notSignedIn }
        guard let restURL = SupabaseConfig.restURL else { throw SyncError.notConfigured }
        
        var request = URLRequest(url: restURL.appendingPathComponent(table))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: data)
        
        let (_, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 400 else {
            throw SyncError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0, "Insert failed")
        }
    }
    
    /// Update row
    func updateRow(table: String, filter: String, data: [String: Any]) async throws {
        guard isConfigured else { throw SyncError.notConfigured }
        guard isSignedIn else { throw SyncError.notSignedIn }
        guard let restURL = SupabaseConfig.restURL else { throw SyncError.notConfigured }
        
        var components = URLComponents(url: restURL.appendingPathComponent(table), resolvingAgainstBaseURL: false)!
        components.queryItems = filter.split(separator: "&").map { part in
            let kv = part.split(separator: "=", maxSplits: 1)
            return URLQueryItem(name: String(kv[0]), value: kv.count > 1 ? String(kv[1]) : nil)
        }
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: data)
        
        let (_, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 400 else {
            throw SyncError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0, "Update failed")
        }
    }
    
    /// Delete row
    func deleteRow(table: String, filter: String) async throws {
        guard isConfigured else { throw SyncError.notConfigured }
        guard isSignedIn else { throw SyncError.notSignedIn }
        guard let restURL = SupabaseConfig.restURL else { throw SyncError.notConfigured }
        
        var components = URLComponents(url: restURL.appendingPathComponent(table), resolvingAgainstBaseURL: false)!
        components.queryItems = filter.split(separator: "&").map { part in
            let kv = part.split(separator: "=", maxSplits: 1)
            return URLQueryItem(name: String(kv[0]), value: kv.count > 1 ? String(kv[1]) : nil)
        }
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        addAuthHeaders(to: &request)
        
        let (_, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 400 else {
            throw SyncError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0, "Delete failed")
        }
    }
    
    private func addAuthHeaders(to request: inout URLRequest) {
        // Access session through internal method
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        // Token will be added by session
    }
    
    func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        // Delegate to the internal URLSession
        try await URLSession.shared.data(for: request)
    }
}
