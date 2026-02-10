import Foundation

// ============================================================================
// ⚠️  AIR-GAP EXCEPTION: SUPABASE CLIENT (Phase 10D)
// ============================================================================
//
// THIS FILE IS THE DOCUMENTED EXCEPTION TO OPERATORKIT'S AIR-GAP CLAIM.
//
// CLAIM-001 states: "OperatorKit Core Verification Mode is fully air-gapped.
// Sync is an explicit, user-initiated, OFF-by-default exception."
//
// This file contains the ONLY URLSession usage in OperatorKit.
// It is permitted because:
//   1. Sync is OFF by default (SyncFeatureFlag.defaultToggleState = false)
//   2. Requires explicit user action to enable AND sign in
//   3. Uploads metadata-only packets (content blocked by SyncPacketValidator)
//   4. Isolated to /Sync/ directory — no imports from execution modules
//   5. No background networking (waitsForConnectivity = false)
//
// CORE MODULES (ExecutionEngine, ApprovalGate, ModelRouter, DraftGenerator,
// ContextAssembler, MemoryStore) have ZERO network code.
//
// CONSTRAINTS (ABSOLUTE):
// ✅ Credentials via build settings / xcconfig (no hardcoded secrets)
// ✅ Request timeouts enforced
// ✅ Log sizes and schema versions only, NEVER payloads
// ✅ Error mapping to user-friendly messages
// ❌ NO logging of payload content
// ❌ NO background requests
// ❌ NO execution module imports
//
// See: docs/SAFETY_CONTRACT.md (Section 13)
// See: docs/CLAIM_REGISTRY.md (CLAIM-001)
// ============================================================================

// MARK: - Supabase Configuration

/// Configuration loaded from build settings
public enum SupabaseConfig {
    
    /// Supabase project URL - loaded from xcconfig / build settings
    /// Set SUPABASE_URL in your xcconfig or build settings
    public static var projectURL: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
    }
    
    /// Supabase anonymous key - loaded from xcconfig / build settings
    /// Set SUPABASE_ANON_KEY in your xcconfig or build settings
    public static var anonKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    }
    
    /// Whether Supabase is configured
    public static var isConfigured: Bool {
        !projectURL.isEmpty && !anonKey.isEmpty
    }
    
    /// Base URL for auth endpoints
    public static var authURL: URL? {
        guard let base = URL(string: projectURL) else { return nil }
        return base.appendingPathComponent("auth/v1")
    }
    
    /// Base URL for REST endpoints
    public static var restURL: URL? {
        guard let base = URL(string: projectURL) else { return nil }
        return base.appendingPathComponent("rest/v1")
    }
}

// MARK: - Supabase User

/// Represents an authenticated Supabase user (minimal info)
public struct SupabaseUser: Codable, Equatable {
    public let id: String
    public let email: String?
    public let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
    }
}

// MARK: - Supabase Session

/// Represents an active session
public struct SupabaseSession: Codable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int
    public let user: SupabaseUser
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

// MARK: - Sync Error

/// Errors from sync operations
public enum SyncError: Error, LocalizedError {
    case notConfigured
    case notSignedIn
    case networkError(Error)
    case serverError(Int, String)
    case encodingError
    case decodingError
    case payloadTooLarge(Int)
    case payloadContainsForbiddenContent(String)
    case missingRequiredField(String)
    case timeout
    case unknown
    case invalidURL(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Cloud sync is not configured."
        case .notSignedIn:
            return "Please sign in to sync."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .encodingError:
            return "Could not encode data."
        case .decodingError:
            return "Could not decode response."
        case .payloadTooLarge(let size):
            return "Payload too large (\(size) bytes). Maximum is \(SyncSafetyConfig.maxPayloadSizeBytes) bytes."
        case .payloadContainsForbiddenContent(let key):
            return "Payload contains forbidden content key: \(key)"
        case .missingRequiredField(let field):
            return "Payload missing required field: \(field)"
        case .timeout:
            return "Request timed out."
        case .unknown:
            return "An unknown error occurred."
        case .invalidURL(let table):
            return "Could not construct URL for table: \(table)"
        }
    }
}

// MARK: - Supabase Client

/// Isolated client for Supabase operations
/// INVARIANT: This is the ONLY class in OperatorKit that uses URLSession
@MainActor
public final class SupabaseClient: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = SupabaseClient()
    
    // MARK: - Published State
    
    @Published public private(set) var currentUser: SupabaseUser?
    @Published public private(set) var isSignedIn: Bool = false
    @Published public private(set) var isLoading: Bool = false
    
    // MARK: - Session Storage
    
    private var session: SupabaseSession?
    private let sessionKey = "com.operatorkit.sync.session"
    
    // MARK: - URL Session
    
    /// Dedicated URLSession with timeout configuration
    /// INVARIANT: Only used within this file
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = SyncSafetyConfig.requestTimeoutSeconds
        config.timeoutIntervalForResource = SyncSafetyConfig.requestTimeoutSeconds * 2
        config.waitsForConnectivity = false  // Don't wait in background
        return URLSession(configuration: config)
    }()
    
    // MARK: - Initialization
    
    private init() {
        loadSession()
    }
    
    // MARK: - Configuration Check
    
    /// Whether the client is properly configured
    public var isConfigured: Bool {
        SupabaseConfig.isConfigured
    }
    
    /// Whether sync operations are permitted
    /// INVARIANT: Returns false unless feature flag is enabled
    public var isSyncEnabled: Bool {
        SyncFeatureFlag.isEnabled
    }
    
    // MARK: - Sync Isolation Guard
    
    /// Verifies sync is explicitly enabled before any network operation.
    /// This is a runtime assertion that Sync cannot run unless:
    /// 1. Feature flag is explicitly enabled
    /// 2. User action triggered the flow (implied by guard placement)
    ///
    /// - Throws: SyncError.notConfigured if sync is disabled
    private func assertSyncEnabled() throws {
        guard SyncFeatureFlag.isEnabled else {
            logDebug("SYNC BLOCKED: Feature flag is disabled", category: .flow)
            throw SyncError.notConfigured
        }
    }
    
    // MARK: - Authentication
    
    /// Request OTP via email
    /// REQUIRES: SyncFeatureFlag.isEnabled == true (user must have enabled sync)
    public func requestOTP(email: String) async throws {
        try assertSyncEnabled()
        guard isConfigured else { throw SyncError.notConfigured }
        guard let authURL = SupabaseConfig.authURL else { throw SyncError.notConfigured }
        
        isLoading = true
        defer { isLoading = false }
        
        let endpoint = authURL.appendingPathComponent("otp")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "create_user": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.unknown
        }
        
        if httpResponse.statusCode >= 400 {
            throw SyncError.serverError(httpResponse.statusCode, "Failed to send OTP")
        }
        
        logDebug("OTP requested for email (not logged)", category: .flow)
    }
    
    /// Verify OTP and sign in
    /// REQUIRES: SyncFeatureFlag.isEnabled == true
    public func verifyOTP(email: String, token: String) async throws {
        try assertSyncEnabled()
        guard isConfigured else { throw SyncError.notConfigured }
        guard let authURL = SupabaseConfig.authURL else { throw SyncError.notConfigured }
        
        isLoading = true
        defer { isLoading = false }
        
        let endpoint = authURL.appendingPathComponent("verify")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "token": token,
            "type": "email"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.unknown
        }
        
        if httpResponse.statusCode >= 400 {
            throw SyncError.serverError(httpResponse.statusCode, "Invalid OTP")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let session = try decoder.decode(SupabaseSession.self, from: data)
        
        self.session = session
        self.currentUser = session.user
        self.isSignedIn = true
        saveSession()
        
        logDebug("User signed in (id: \(session.user.id.prefix(8))...)", category: .flow)
    }
    
    /// Sign out
    /// REQUIRES: SyncFeatureFlag.isEnabled == true
    public func signOut() async throws {
        try assertSyncEnabled()
        guard isConfigured else { throw SyncError.notConfigured }
        guard let authURL = SupabaseConfig.authURL else { throw SyncError.notConfigured }
        guard let session = session else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let endpoint = authURL.appendingPathComponent("logout")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        // Best effort - clear local state regardless
        _ = try? await performRequest(request)
        
        clearSession()
        logDebug("User signed out", category: .flow)
    }
    
    /// Get current user info
    public func currentUserInfo() -> SupabaseUser? {
        currentUser
    }
    
    // MARK: - Packet Operations
    
    /// Upload a validated packet
    /// INVARIANT: Payload must be pre-validated by SyncPacketValidator
    /// REQUIRES: SyncFeatureFlag.isEnabled == true
    public func uploadPacket(type: SyncSafetyConfig.SyncablePacketType, jsonData: Data) async throws -> String {
        try assertSyncEnabled()
        guard isConfigured else { throw SyncError.notConfigured }
        guard let session = session else { throw SyncError.notSignedIn }
        guard let restURL = SupabaseConfig.restURL else { throw SyncError.notConfigured }
        
        isLoading = true
        defer { isLoading = false }
        
        // Log only size and type, NEVER content
        logDebug("Uploading packet: type=\(type.rawValue), size=\(jsonData.count) bytes", category: .flow)
        
        let endpoint = restURL.appendingPathComponent("sync_packets")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        // Wrap payload in database row format
        let packetId = UUID().uuidString
        let wrapper: [String: Any] = [
            "id": packetId,
            "user_id": session.user.id,
            "packet_type": type.rawValue,
            "payload": String(data: jsonData, encoding: .utf8) ?? "",
            "size_bytes": jsonData.count,
            "uploaded_at": ISO8601DateFormatter().string(from: Date())
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: wrapper)
        
        let (_, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.unknown
        }
        
        if httpResponse.statusCode >= 400 {
            throw SyncError.serverError(httpResponse.statusCode, "Upload failed")
        }
        
        logDebug("Packet uploaded: id=\(packetId.prefix(8))...", category: .flow)
        return packetId
    }
    
    /// List user's uploaded packets
    /// REQUIRES: SyncFeatureFlag.isEnabled == true
    public func listPackets() async throws -> [SyncPacketMetadata] {
        try assertSyncEnabled()
        guard isConfigured else { throw SyncError.notConfigured }
        guard let session = session else { throw SyncError.notSignedIn }
        guard let restURL = SupabaseConfig.restURL else { throw SyncError.notConfigured }
        
        isLoading = true
        defer { isLoading = false }
        
        var components = URLComponents(url: restURL.appendingPathComponent("sync_packets"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
            URLQueryItem(name: "select", value: "id,packet_type,size_bytes,uploaded_at"),
            URLQueryItem(name: "order", value: "uploaded_at.desc")
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.unknown
        }
        
        if httpResponse.statusCode >= 400 {
            throw SyncError.serverError(httpResponse.statusCode, "Failed to list packets")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let packets = try decoder.decode([SyncPacketMetadata].self, from: data)
        
        logDebug("Listed \(packets.count) packets", category: .flow)
        return packets
    }
    
    /// Delete a packet
    /// REQUIRES: SyncFeatureFlag.isEnabled == true
    public func deletePacket(id: String) async throws {
        try assertSyncEnabled()
        guard isConfigured else { throw SyncError.notConfigured }
        guard let session = session else { throw SyncError.notSignedIn }
        guard let restURL = SupabaseConfig.restURL else { throw SyncError.notConfigured }
        
        isLoading = true
        defer { isLoading = false }
        
        var components = URLComponents(url: restURL.appendingPathComponent("sync_packets"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id)"),
            URLQueryItem(name: "user_id", value: "eq.\(session.user.id)")
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (_, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.unknown
        }
        
        if httpResponse.statusCode >= 400 {
            throw SyncError.serverError(httpResponse.statusCode, "Delete failed")
        }
        
        logDebug("Packet deleted: id=\(id.prefix(8))...", category: .flow)
    }
    
    // MARK: - Network Helpers
    
    /// Performs a network request with error handling
    /// INVARIANT: All requests pass through NetworkPolicyEnforcer
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            // Validate via NetworkPolicyEnforcer first, then use configured session
            if let url = request.url {
                try NetworkPolicyEnforcer.shared.validate(url)
            }
            return try await urlSession.data(for: request)
        } catch let error as URLError {
            if error.code == .timedOut {
                throw SyncError.timeout
            }
            throw SyncError.networkError(error)
        } catch {
            throw SyncError.networkError(error)
        }
    }
    
    // MARK: - Session Persistence
    
    private func saveSession() {
        guard let session = session else { return }
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }
    
    private func loadSession() {
        guard let data = UserDefaults.standard.data(forKey: sessionKey),
              let session = try? JSONDecoder().decode(SupabaseSession.self, from: data) else {
            return
        }
        self.session = session
        self.currentUser = session.user
        self.isSignedIn = true
    }
    
    private func clearSession() {
        session = nil
        currentUser = nil
        isSignedIn = false
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
}

// MARK: - Packet Metadata

/// Metadata about an uploaded packet (no payload content)
public struct SyncPacketMetadata: Codable, Identifiable {
    public let id: String
    public let packetType: String
    public let sizeBytes: Int
    public let uploadedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case packetType = "packet_type"
        case sizeBytes = "size_bytes"
        case uploadedAt = "uploaded_at"
    }
    
    /// Display name for packet type
    public var packetTypeDisplayName: String {
        switch packetType {
        case "quality_export": return "Quality Export"
        case "diagnostics_export": return "Diagnostics Export"
        case "policy_export": return "Policy Export"
        case "release_acknowledgement": return "Release Acknowledgement"
        case "evidence_packet": return "Evidence Packet"
        default: return packetType.capitalized
        }
    }
    
    /// Formatted size
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }
}
