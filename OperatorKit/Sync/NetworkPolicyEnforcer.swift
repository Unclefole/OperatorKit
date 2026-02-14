import Foundation
import CryptoKit

// ============================================================================
// NETWORK POLICY ENFORCER — Runtime Egress Control Middleware
//
// INVARIANT: ALL outbound HTTP requests MUST pass through this enforcer.
// INVARIANT: scheme == https REQUIRED (no HTTP).
// INVARIANT: host MUST be in explicit allowlist.
// INVARIANT: Violations are logged to EvidenceEngine + may trigger lockdown.
// ============================================================================

public final class NetworkPolicyEnforcer: @unchecked Sendable {

    public static let shared = NetworkPolicyEnforcer()

    // MARK: - Policy Modes

    public enum PolicyMode: String, Sendable {
        case offlineOnly         // Deny ALL network
        case enterpriseAllowlist // Default: only allowlisted hosts
        case devMode             // Relaxed for development — requires admin flag
    }

    private var _mode: PolicyMode = .enterpriseAllowlist
    public var mode: PolicyMode {
        get { _mode }
        set {
            if newValue == .devMode {
                guard EnterpriseFeatureFlags.backgroundAutonomyEnabled else {
                    log("[NET_POLICY] DevMode denied — admin flag not set")
                    return
                }
            }
            _mode = newValue
            log("[NET_POLICY] Mode changed to \(newValue.rawValue)")
        }
    }

    // MARK: - Host Allowlist

    /// Combined allowlist: cloud AI + research domains + enterprise endpoints + sync
    private var hostAllowlist: Set<String> {
        var hosts: Set<String> = [
            // Cloud AI
            "api.openai.com",
            "api.anthropic.com",
        ]
        // Governed web research domains (public government / legal / reference)
        // DUAL-GATE: Both webResearchEnabled AND researchHostAllowlistEnabled must be ON.
        if EnterpriseFeatureFlags.webResearchFullyEnabled {
            hosts.formUnion(researchHosts)
        }
        // Enterprise endpoints (added at runtime by configuration)
        hosts.formUnion(enterpriseHosts)
        return hosts
    }

    // MARK: - Research Host Allowlist

    /// Default public research domains — feature-flag gated.
    /// These are READ-ONLY, GET-only targets.
    private static let defaultResearchHosts: Set<String> = [
        // Brave Search API (connector-level search)
        "api.search.brave.com",
        // Government / legal research domains
        "www.justice.gov",
        "www.supremecourt.gov",
        "www.uscourts.gov",
        "www.sec.gov",
        "www.ftc.gov",
        "www.fbi.gov",
        "www.usa.gov",
        "www.congress.gov",
        "www.gpo.gov",
        "www.govinfo.gov",
        "www.federalregister.gov",
    ]

    /// Runtime-configurable research hosts (enterprise can extend)
    private var researchHosts: Set<String> = NetworkPolicyEnforcer.defaultResearchHosts

    /// Register an additional research host at runtime.
    public func registerResearchHost(_ host: String) {
        researchHosts.insert(host.lowercased())
        log("[NET_POLICY] Research host registered: \(host)")
    }

    /// Remove a research host.
    public func removeResearchHost(_ host: String) {
        researchHosts.remove(host.lowercased())
    }

    /// Check if web research is active (BOTH flags ON).
    public var isWebResearchActive: Bool {
        EnterpriseFeatureFlags.webResearchFullyEnabled
    }

    /// List currently allowlisted research hosts.
    public var activeResearchHosts: Set<String> {
        EnterpriseFeatureFlags.webResearchFullyEnabled ? researchHosts : []
    }

    /// Path prefixes allowed per host (optional extra restriction)
    private let pathPrefixes: [String: [String]] = [
        "api.openai.com": ["/v1/"],
        "api.anthropic.com": ["/v1/"],
    ]

    /// Dynamically registered enterprise hosts (mirror, org authority, sync)
    private var enterpriseHosts: Set<String> = []

    /// Register an enterprise endpoint host at runtime.
    public func registerEnterpriseHost(_ host: String) {
        enterpriseHosts.insert(host.lowercased())
        log("[NET_POLICY] Enterprise host registered: \(host)")
    }

    /// Remove an enterprise host.
    public func removeEnterpriseHost(_ host: String) {
        enterpriseHosts.remove(host.lowercased())
    }

    private init() {}

    // MARK: - Enforcement

    public enum NetworkPolicyError: Error, LocalizedError {
        case offlineMode
        case httpForbidden(String)
        case hostNotAllowed(String)
        case pathNotAllowed(String, String)
        case killSwitchActive

        public var errorDescription: String? {
            switch self {
            case .offlineMode: return "Network policy: offline mode active — all egress denied"
            case .httpForbidden(let h): return "Network policy: HTTP forbidden for host \(h) — HTTPS required"
            case .hostNotAllowed(let h): return "Network policy: host \(h) not in allowlist"
            case .pathNotAllowed(let h, let p): return "Network policy: path \(p) not allowed for host \(h)"
            case .killSwitchActive: return "Network policy: cloud kill switch active — all egress denied"
            }
        }
    }

    /// Validate a URL against the active network policy.
    /// Returns normally on success, throws on violation.
    public func validate(_ url: URL) throws {
        // Kill switch check
        if EnterpriseFeatureFlags.cloudKillSwitch {
            logViolation(url, reason: "cloud kill switch active")
            throw NetworkPolicyError.killSwitchActive
        }

        // Mode check
        switch _mode {
        case .offlineOnly:
            logViolation(url, reason: "offline mode")
            throw NetworkPolicyError.offlineMode

        case .devMode:
            // DevMode permits all HTTPS — still requires HTTPS
            guard url.scheme?.lowercased() == "https" else {
                logViolation(url, reason: "HTTP forbidden even in dev mode")
                throw NetworkPolicyError.httpForbidden(url.host ?? "nil")
            }
            return

        case .enterpriseAllowlist:
            break
        }

        // 1. HTTPS required
        guard url.scheme?.lowercased() == "https" else {
            logViolation(url, reason: "HTTP forbidden")
            throw NetworkPolicyError.httpForbidden(url.host ?? "nil")
        }

        // 2. Host allowlist
        guard let host = url.host?.lowercased(), hostAllowlist.contains(host) else {
            let host = url.host ?? "nil"
            logViolation(url, reason: "host not allowed: \(host)")
            throw NetworkPolicyError.hostNotAllowed(host)
        }

        // 3. Path prefix check (optional — only for hosts with explicit prefixes)
        if let prefixes = pathPrefixes[url.host?.lowercased() ?? ""] {
            let path = url.path
            guard prefixes.contains(where: { path.hasPrefix($0) }) else {
                logViolation(url, reason: "path \(url.path) not allowed for host")
                throw NetworkPolicyError.pathNotAllowed(url.host ?? "", url.path)
            }
        }
    }

    /// Validate and execute a URLRequest. Returns data + response.
    /// This is the ONLY approved path for outbound HTTP in prod.
    ///
    /// PHASE 3: All egress now routes through this single method.
    /// PHASE 4: Uses pinned URLSession for hosts with certificate pins.
    public func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else {
            throw NetworkPolicyError.hostNotAllowed("nil")
        }
        try validate(url)

        // Use pinned session for hosts that have certificate pins configured
        let host = url.host?.lowercased() ?? ""
        let session: URLSession
        if CertificatePinningDelegate.isPinned(host) &&
           SecurityPostureManager.shared.certificatePinningRequired {
            session = NetworkPolicyEnforcer.pinnedSession
        } else {
            session = URLSession.shared
        }

        return try await session.data(for: request)
    }

    // MARK: - Violation Logging

    private func logViolation(_ url: URL, reason: String) {
        let redactedURL = "\(url.scheme ?? "?")://\(url.host ?? "?")\(url.path)"
        log("[NET_POLICY] VIOLATION: \(reason) — \(redactedURL)")

        // Evidence log (dispatch to MainActor since EvidenceEngine is isolated)
        let host = url.host ?? "nil"
        let path = url.path
        let mode = _mode.rawValue
        Task { @MainActor in
            try? EvidenceEngine.shared.logGenericArtifact(
                type: "network_policy_violation",
                planId: UUID(),
                jsonString: """
                {"reason":"\(reason)","host":"\(host)","path":"\(path)","mode":"\(mode)","timestamp":"\(Date())"}
                """
            )
        }
    }
}
