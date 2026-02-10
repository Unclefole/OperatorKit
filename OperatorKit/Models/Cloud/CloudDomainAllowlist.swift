import Foundation

// ============================================================================
// CLOUD DOMAIN ALLOWLIST — Network Egress Control
//
// INVARIANT: Only URLs matching this allowlist may be contacted.
// INVARIANT: No arbitrary URLs. No user-supplied domains.
// INVARIANT: Checked BEFORE every URLSession request in cloud clients.
// ============================================================================

enum CloudDomainAllowlist {

    /// Allowed base domains for cloud model API calls.
    private static let allowedDomains: Set<String> = [
        "api.openai.com",
        "api.anthropic.com",
    ]

    /// Validate that a URL's host is in the allowlist.
    /// Returns true only if the host matches an allowed domain exactly.
    static func isAllowed(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return allowedDomains.contains(host)
    }

    /// Validate and throw if not allowed.
    static func assertAllowed(_ url: URL) throws {
        guard isAllowed(url) else {
            throw CloudModelError.domainNotAllowed(url.host ?? "nil")
        }
    }
}
