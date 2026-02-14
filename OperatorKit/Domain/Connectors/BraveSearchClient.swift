import Foundation

// ============================================================================
// BRAVE SEARCH CLIENT — Governed Web Search Connector
//
// Calls the Brave Search Web API to retrieve search results.
// Read-only. GET-only. HTTPS-only.
//
// INVARIANT: ALL requests pass through ConnectorGate + NetworkPolicyEnforcer.
// INVARIANT: API key retrieved from Keychain (hardware-backed, biometric-gated).
// INVARIANT: No cookies, no auth headers beyond API token, no form submissions.
// INVARIANT: Results are structured data only — no executable code.
// INVARIANT: Feature-flag gated: webResearchEnabled + researchHostAllowlistEnabled.
//
// Evidence events:
//   brave_search_started    — search initiated
//   brave_search_completed  — results received
//   brave_search_denied     — policy/gate denied
//   brave_search_failed     — network/parse error
//   brave_search_no_key     — API key not configured
// ============================================================================

// MARK: - Search Result

/// A single web search result from Brave Search API.
public struct BraveSearchResult: Codable, Sendable {
    public let title: String
    public let url: URL
    public let description: String
    public let age: String?

    public init(title: String, url: URL, description: String, age: String? = nil) {
        self.title = title
        self.url = url
        self.description = description
        self.age = age
    }
}

/// Response from a Brave Search query.
public struct BraveSearchResponse: Sendable {
    public let query: String
    public let results: [BraveSearchResult]
    public let totalResults: Int

    public init(query: String, results: [BraveSearchResult], totalResults: Int) {
        self.query = query
        self.results = results
        self.totalResults = totalResults
    }
}

// MARK: - Search Error

public enum BraveSearchError: Error, LocalizedError, Sendable {
    case noAPIKey
    case policyDenied(String)
    case networkError(String)
    case invalidResponse
    case rateLimited
    case httpError(Int)

    public var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Brave Search API key not configured. Add it in Intelligence Settings."
        case .policyDenied(let r): return "Search denied by policy: \(r)"
        case .networkError(let r): return "Search network error: \(r)"
        case .invalidResponse: return "Invalid response from Brave Search API"
        case .rateLimited: return "Brave Search rate limit reached (2,000/month free tier)"
        case .httpError(let code): return "Brave Search HTTP error: \(code)"
        }
    }
}

// MARK: - Brave Search Client

public final class BraveSearchClient: @unchecked Sendable {

    public static let shared = BraveSearchClient()

    /// Connector manifest — declares permissions and constraints.
    public let manifest: ConnectorManifest = ConnectorManifestRegistry.braveSearch

    private let enforcer = NetworkPolicyEnforcer.shared
    private static let baseURL = "https://api.search.brave.com/res/v1/web/search"
    private static let maxResults = 5  // Conservative for free tier

    /// Keychain service for the Brave Search API key.
    static let keychainService = "com.operatorkit.vault.connector.brave_search"
    static let keychainAccount = "brave_search_api_key"

    private init() {}

    // MARK: - Search

    /// Execute a governed web search via Brave Search API.
    ///
    /// - Parameter query: The search query string.
    /// - Parameter count: Number of results (max 5 for governed use).
    /// - Returns: BraveSearchResponse with structured results.
    ///
    /// INVARIANT: ConnectorGate + NetworkPolicyEnforcer enforced.
    /// INVARIANT: API key from Keychain, never cached.
    /// INVARIANT: Feature flags must be ON.
    public func search(query: String, count: Int = 5) async throws -> BraveSearchResponse {
        let searchId = UUID()

        // 1. Feature flag check (FAIL CLOSED)
        guard EnterpriseFeatureFlags.webResearchFullyEnabled else {
            logEvidence(type: "brave_search_denied", detail: "Web research flags not enabled")
            throw BraveSearchError.policyDenied("Web research not enabled. Enable in settings.")
        }

        // 2. Build URL
        let clampedCount = min(count, Self.maxResults)
        var components = URLComponents(string: Self.baseURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: String(clampedCount))
        ]
        guard let url = components.url else {
            throw BraveSearchError.invalidResponse
        }

        // 3. ConnectorGate pre-flight
        let gateRequest = ConnectorRequest(
            connectorId: manifest.connectorId,
            targetURL: url,
            httpMethod: "GET",
            payloadSize: 0
        )
        do {
            try ConnectorGate.enforce(request: gateRequest, manifest: manifest)
        } catch {
            logEvidence(type: "brave_search_denied", detail: "ConnectorGate: \(error.localizedDescription)")
            throw BraveSearchError.policyDenied(error.localizedDescription)
        }

        // 4. Retrieve API key from Keychain (biometric-gated)
        let apiKey: String
        do {
            apiKey = try retrieveAPIKey()
        } catch {
            logEvidence(type: "brave_search_no_key", detail: "API key not available: \(error.localizedDescription)")
            throw BraveSearchError.noAPIKey
        }

        // 5. Build request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.httpShouldHandleCookies = false
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")

        logEvidence(type: "brave_search_started", detail: "query=\(query.prefix(100)), count=\(clampedCount), searchId=\(searchId)")

        // 6. Execute through NetworkPolicyEnforcer (sole egress)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await enforcer.execute(request)
        } catch let error as NetworkPolicyEnforcer.NetworkPolicyError {
            logEvidence(type: "brave_search_denied", detail: "NetworkPolicy: \(error.localizedDescription)")
            throw BraveSearchError.policyDenied(error.localizedDescription)
        } catch {
            logEvidence(type: "brave_search_failed", detail: "Network: \(error.localizedDescription)")
            throw BraveSearchError.networkError(error.localizedDescription)
        }

        // 7. Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BraveSearchError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                logEvidence(type: "brave_search_failed", detail: "Rate limited (429)")
                throw BraveSearchError.rateLimited
            }
            logEvidence(type: "brave_search_failed", detail: "HTTP \(httpResponse.statusCode)")
            throw BraveSearchError.httpError(httpResponse.statusCode)
        }

        // 8. Parse response
        let searchResponse = try parseResponse(data: data, query: query)

        logEvidence(type: "brave_search_completed",
                   detail: "query=\(query.prefix(50)), results=\(searchResponse.results.count), searchId=\(searchId)")

        return searchResponse
    }

    // MARK: - API Key Management

    /// Store Brave Search API key in Keychain with biometric protection.
    public func storeAPIKey(_ key: String) throws {
        guard let keyData = key.data(using: .utf8) else { return }

        // Create access control
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &error
        ) else {
            throw APIKeyVaultError.accessControlCreationFailed
        }

        // Delete existing first
        deleteAPIKey()

        // Store
        // NOTE: kSecAttrIsExtractable is only valid for kSecClassKey, not GenericPassword
        let query: [String: Any] = [
            kSecClass as String:             kSecClassGenericPassword,
            kSecAttrService as String:       Self.keychainService,
            kSecAttrAccount as String:       Self.keychainAccount,
            kSecValueData as String:         keyData,
            kSecAttrAccessControl as String: accessControl,
            kSecAttrSynchronizable as String: false as CFBoolean
        ]

        var status = SecItemAdd(query as CFDictionary, nil)

        // Handle duplicate gracefully
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String:       kSecClassGenericPassword,
                kSecAttrService as String: Self.keychainService,
                kSecAttrAccount as String: Self.keychainAccount
            ]
            let updateAttrs: [String: Any] = [
                kSecValueData as String:         keyData,
                kSecAttrAccessControl as String: accessControl
            ]
            status = SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary)
        }

        guard status == errSecSuccess else {
            throw APIKeyVaultError.keychainStoreFailed(status)
        }

        logEvidence(type: "brave_search_key_saved", detail: "Brave Search API key stored in Keychain")
    }

    /// Retrieve Brave Search API key from Keychain (triggers biometric).
    private func retrieveAPIKey() throws -> String {
        let context = LAContext()
        context.localizedReason = "Authenticate to use Brave Search API"

        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      Self.keychainService,
            kSecAttrAccount as String:      Self.keychainAccount,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw APIKeyVaultError.noKeyStored
        }

        return key
    }

    /// Check if Brave Search API key exists (no auth required).
    public func hasAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess
    }

    /// Delete Brave Search API key from Keychain.
    public func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Response Parsing

    private func parseResponse(data: Data, query: String) throws -> BraveSearchResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BraveSearchError.invalidResponse
        }

        var results: [BraveSearchResult] = []

        if let web = json["web"] as? [String: Any],
           let webResults = web["results"] as? [[String: Any]] {
            for item in webResults {
                guard let title = item["title"] as? String,
                      let urlString = item["url"] as? String,
                      let url = URL(string: urlString),
                      let description = item["description"] as? String else {
                    continue
                }

                // Only HTTPS results
                guard url.scheme?.lowercased() == "https" else { continue }

                results.append(BraveSearchResult(
                    title: title,
                    url: url,
                    description: description,
                    age: item["age"] as? String
                ))
            }
        }

        return BraveSearchResponse(
            query: query,
            results: results,
            totalResults: results.count
        )
    }

    // MARK: - Evidence

    private func logEvidence(type: String, detail: String) {
        let planId = UUID()
        let timestamp = Date().ISO8601Format()
        Task { @MainActor in
            try? EvidenceEngine.shared.logGenericArtifact(
                type: type,
                planId: planId,
                jsonString: """
                {"connector":"brave_search","detail":"\(detail)","timestamp":"\(timestamp)"}
                """
            )
        }
    }
}

// MARK: - LAContext Import

import LocalAuthentication
