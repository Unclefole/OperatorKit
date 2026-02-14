import Foundation
import CryptoKit

// ============================================================================
// GOVERNED WEB FETCHER — Read-Only Public Document Retrieval
//
// INVARIANT: STRICTLY READ-ONLY. GET requests only.
// INVARIANT: ALL requests pass through NetworkPolicyEnforcer.
// INVARIANT: HTTPS required. No cookies. No auth. No form submissions.
// INVARIANT: Redirects to non-allowlisted hosts are rejected.
// INVARIANT: Max payload size enforced.
// INVARIANT: MUST NOT reference ExecutionEngine, ServiceAccessToken,
//            or any write-capable service.
//
// EVIDENCE TAGS:
//   web_fetch_started, web_fetch_completed,
//   web_fetch_denied, web_fetch_failed
// ============================================================================

// MARK: - Web Document

/// Immutable artifact from a governed web fetch.
public struct WebDocument: Sendable, Identifiable {
    public let id: UUID
    public let url: URL
    public let mimeType: String
    public let rawData: Data
    public let fetchedAt: Date
    public let sha256Hash: String
    public let contentLength: Int
    public let statusCode: Int

    public init(url: URL, mimeType: String, rawData: Data, statusCode: Int) {
        self.id = UUID()
        self.url = url
        self.mimeType = mimeType
        self.rawData = rawData
        self.fetchedAt = Date()
        self.contentLength = rawData.count
        self.statusCode = statusCode
        self.sha256Hash = SHA256.hash(data: rawData)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    public var isHTML: Bool {
        mimeType.contains("text/html") || mimeType.contains("text/plain")
    }

    public var isPDF: Bool {
        mimeType.contains("application/pdf")
    }

    /// Raw text content (if HTML/text).
    public var textContent: String? {
        guard isHTML || mimeType.contains("text/") else { return nil }
        return String(data: rawData, encoding: .utf8)
    }
}

// MARK: - Fetch Errors

public enum WebFetchError: Error, LocalizedError {
    case policyDenied(String)
    case httpOnly
    case notGetRequest
    case authenticationRequired
    case redirectToUnallowedHost(String)
    case payloadTooLarge(Int)
    case timeout
    case httpError(Int, String)
    case networkError(String)
    case invalidURL
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .policyDenied(let r): return "Web fetch denied by network policy: \(r)"
        case .httpOnly: return "Web fetch requires HTTPS — HTTP is forbidden"
        case .notGetRequest: return "Web fetcher only supports GET requests"
        case .authenticationRequired: return "Target requires authentication — FAIL CLOSED"
        case .redirectToUnallowedHost(let h): return "Redirect to non-allowlisted host: \(h)"
        case .payloadTooLarge(let s): return "Response exceeds max size: \(s) bytes"
        case .timeout: return "Web fetch timed out"
        case .httpError(let c, let m): return "HTTP \(c): \(m)"
        case .networkError(let e): return "Network error: \(e)"
        case .invalidURL: return "Invalid URL"
        case .emptyResponse: return "Empty response"
        }
    }
}

// MARK: - Configuration

public struct WebFetchConfig: Sendable {
    public let maxPayloadBytes: Int
    public let timeoutSeconds: TimeInterval
    public let followRedirects: Bool
    public let userAgent: String

    public init(
        maxPayloadBytes: Int = 10_485_760,   // 10 MB
        timeoutSeconds: TimeInterval = 10.0,
        followRedirects: Bool = true,
        userAgent: String = "OperatorKit/1.0 (GovernedWebFetcher; read-only)"
    ) {
        self.maxPayloadBytes = maxPayloadBytes
        self.timeoutSeconds = timeoutSeconds
        self.followRedirects = followRedirects
        self.userAgent = userAgent
    }

    public static let `default` = WebFetchConfig()
}

// MARK: - Governed Web Fetcher

public final class GovernedWebFetcher: @unchecked Sendable {

    public static let shared = GovernedWebFetcher()

    /// Connector manifest — declares ALL permissions and constraints.
    public let manifest: ConnectorManifest = ConnectorManifestRegistry.webFetcher

    private let config: WebFetchConfig
    private let enforcer: NetworkPolicyEnforcer

    public init(config: WebFetchConfig = .default) {
        self.config = config
        self.enforcer = NetworkPolicyEnforcer.shared
    }

    // MARK: - Fetch

    /// Fetch a public web document. Read-only. GET only. HTTPS required.
    /// ALL requests pass through ConnectorGate + NetworkPolicyEnforcer.
    public func fetch(url: URL) async throws -> WebDocument {
        let fetchId = UUID()

        // ── ConnectorGate pre-flight (HARD FAIL) ─────────
        let gateRequest = ConnectorRequest(
            connectorId: manifest.connectorId,
            targetURL: url,
            httpMethod: "GET",
            payloadSize: 0
        )
        do {
            try ConnectorGate.enforce(request: gateRequest, manifest: manifest)
        } catch {
            logEvidence(type: "web_fetch_denied", detail: "ConnectorGate: \(error.localizedDescription)", url: url, fetchId: fetchId)
            throw WebFetchError.policyDenied(error.localizedDescription)
        }

        // ── Pre-flight checks ──────────────────────────

        // 1. HTTPS required (belt-and-suspenders — ConnectorGate also checks)
        guard url.scheme?.lowercased() == "https" else {
            logEvidence(type: "web_fetch_denied", detail: "HTTP forbidden", url: url, fetchId: fetchId)
            throw WebFetchError.httpOnly
        }

        // 2. Validate against NetworkPolicyEnforcer (belt-and-suspenders)
        do {
            try enforcer.validate(url)
        } catch {
            logEvidence(type: "web_fetch_denied", detail: "Policy: \(error.localizedDescription)", url: url, fetchId: fetchId)
            throw WebFetchError.policyDenied(error.localizedDescription)
        }

        // 3. Build GET-only request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = config.timeoutSeconds
        request.httpShouldHandleCookies = false
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/pdf,text/plain", forHTTPHeaderField: "Accept")

        // Log fetch start
        logEvidence(type: "web_fetch_started", detail: "host=\(url.host ?? "nil"), path=\(url.path)", url: url, fetchId: fetchId)

        log("[WEB_FETCH] Fetching \(url.host ?? "?")\(url.path)")

        // ── Execute through enforcer ────────────────────

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await enforcer.execute(request)
        } catch let error as NetworkPolicyEnforcer.NetworkPolicyError {
            logEvidence(type: "web_fetch_denied", detail: error.localizedDescription, url: url, fetchId: fetchId)
            throw WebFetchError.policyDenied(error.localizedDescription)
        } catch {
            logEvidence(type: "web_fetch_failed", detail: error.localizedDescription, url: url, fetchId: fetchId)
            throw WebFetchError.networkError(error.localizedDescription)
        }

        // ── Post-flight validation ──────────────────────

        guard let httpResponse = response as? HTTPURLResponse else {
            logEvidence(type: "web_fetch_failed", detail: "Non-HTTP response", url: url, fetchId: fetchId)
            throw WebFetchError.networkError("Non-HTTP response")
        }

        // 4. Check for auth-required responses (FAIL CLOSED)
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            logEvidence(type: "web_fetch_denied", detail: "Auth required (HTTP \(httpResponse.statusCode))", url: url, fetchId: fetchId)
            throw WebFetchError.authenticationRequired
        }

        // 5. Check redirect destination (if final URL differs)
        if let finalURL = httpResponse.url, finalURL.host?.lowercased() != url.host?.lowercased() {
            do {
                try enforcer.validate(finalURL)
            } catch {
                logEvidence(type: "web_fetch_denied", detail: "Redirect escaped allowlist: \(finalURL.host ?? "nil")", url: url, fetchId: fetchId)
                throw WebFetchError.redirectToUnallowedHost(finalURL.host ?? "unknown")
            }
        }

        // 6. Check HTTP status
        guard (200..<400).contains(httpResponse.statusCode) else {
            logEvidence(type: "web_fetch_failed", detail: "HTTP \(httpResponse.statusCode)", url: url, fetchId: fetchId)
            throw WebFetchError.httpError(httpResponse.statusCode, HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
        }

        // 7. Payload size check
        guard data.count <= config.maxPayloadBytes else {
            logEvidence(type: "web_fetch_denied", detail: "Payload too large: \(data.count) bytes", url: url, fetchId: fetchId)
            throw WebFetchError.payloadTooLarge(data.count)
        }

        // 8. Empty response check
        guard !data.isEmpty else {
            logEvidence(type: "web_fetch_failed", detail: "Empty response", url: url, fetchId: fetchId)
            throw WebFetchError.emptyResponse
        }

        // ── Build document ──────────────────────────────

        let mimeType = httpResponse.mimeType ?? "application/octet-stream"
        let document = WebDocument(
            url: httpResponse.url ?? url,
            mimeType: mimeType,
            rawData: data,
            statusCode: httpResponse.statusCode
        )

        logEvidence(
            type: "web_fetch_completed",
            detail: "host=\(url.host ?? "nil"), bytes=\(data.count), mime=\(mimeType), hash=\(document.sha256Hash.prefix(16))",
            url: url,
            fetchId: fetchId
        )

        log("[WEB_FETCH] Completed: \(data.count) bytes, \(mimeType)")
        return document
    }

    // MARK: - Evidence

    private func logEvidence(type: String, detail: String, url: URL, fetchId: UUID) {
        let host = url.host ?? "nil"
        let path = url.path
        let cid = manifest.connectorId
        let ver = manifest.version
        Task { @MainActor in
            try? EvidenceEngine.shared.logGenericArtifact(
                type: type,
                planId: fetchId,
                jsonString: """
                {"connectorId":"\(cid)","version":"\(ver)","host":"\(host)","path":"\(path)","detail":"\(detail)","timestamp":"\(Date().ISO8601Format())"}
                """
            )
        }
    }
}
