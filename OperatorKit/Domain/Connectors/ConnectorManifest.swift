import Foundation

// ============================================================================
// CONNECTOR MANIFEST — Declarative Security Contract for Connectors
//
// Every connector in OperatorKit MUST declare a manifest.
// The manifest is the COMPLETE description of what the connector may do.
// ConnectorGate validates every request against the manifest BEFORE execution.
//
// INVARIANT: No connector may operate outside its manifest.
// INVARIANT: Manifest is immutable after creation.
// INVARIANT: Connectors NEVER receive execution scopes.
// INVARIANT: Connector IDs are first-party signed (bundle-embedded).
// ============================================================================

// MARK: - Data Classification

/// What class of data the connector touches.
public enum ConnectorDataClass: String, Codable, Sendable, CaseIterable {
    case publicWeb        = "public_web"         // Public internet documents
    case piiPossible      = "pii_possible"       // Content that MAY contain PII
    case credentialsNone  = "credentials_none"   // No credentials handled
    case internalLogs     = "internal_logs"       // App-internal log/evidence data
    case webhookPayload   = "webhook_payload"     // Outbound structured payload
}

// MARK: - Connector Scope

/// Fine-grained scopes a connector may request.
/// These are READ-ONLY or OUTBOUND-ONLY — never execution.
public enum ConnectorScope: String, Codable, Sendable, CaseIterable {
    // Read-only scopes
    case readWebPublic      = "read_web_public"        // Fetch public web documents
    case readCalendar       = "read_calendar"           // Read calendar events
    case readMail           = "read_mail"               // Read mail (no compose/send)
    case readReminders      = "read_reminders"          // Read reminders
    case readInternalLogs   = "read_internal_logs"      // Read evidence/audit data

    // Outbound notification scopes (no execution authority)
    case postSlack          = "post_slack"              // Post to Slack webhook
    case postWebhook        = "post_webhook"            // Post to enterprise webhook

    // Draft scopes (proposal only — never direct execution)
    case draftEmail         = "draft_email"             // Produce email draft text
    case draftProposal      = "draft_proposal"          // Produce ProposalPack

    // ── FORBIDDEN SCOPES (listed for documentation — NEVER granted) ──
    // execute_action, mint_token, write_calendar, send_email, write_file
    // These are ONLY available through CapabilityKernel + KernelAuthorizationToken.

    /// Whether this scope is read-only (no outbound mutation).
    public var isReadOnly: Bool {
        switch self {
        case .readWebPublic, .readCalendar, .readMail, .readReminders, .readInternalLogs:
            return true
        case .postSlack, .postWebhook:
            return false  // outbound, but non-execution
        case .draftEmail, .draftProposal:
            return true   // produces artifacts, no side effects
        }
    }

    /// Whether this scope involves network egress.
    public var requiresNetwork: Bool {
        switch self {
        case .readWebPublic, .postSlack, .postWebhook:
            return true
        default:
            return false
        }
    }
}

// MARK: - Connector Manifest

/// Immutable security contract for a connector.
/// Validated by ConnectorGate before every operation.
public struct ConnectorManifest: Sendable, Identifiable, Codable {
    // ── Identity ──────────────────────────────────────
    public let id: String                           // e.g. "com.operatorkit.connector.web-fetcher"
    public let connectorId: String                  // Short name: "web_fetcher"
    public let version: String                      // SemVer: "1.0.0"
    public let displayName: String
    public let description: String

    // ── Network Constraints ───────────────────────────
    public let allowedHosts: [String]               // Explicit host allowlist (empty = no network)
    public let allowedHTTPMethods: [String]          // ["GET"] for read-only, ["POST"] for webhooks
    public let maxPayloadBytes: Int                  // Max response/request body size
    public let timeoutSeconds: TimeInterval          // Max request timeout

    // ── Data Classification ───────────────────────────
    public let dataClassesTouched: [ConnectorDataClass]
    public let requiresDataDiode: Bool               // Must redact via DataDiode before cloud

    // ── Authorization ─────────────────────────────────
    public let scopes: [ConnectorScope]              // What this connector is permitted to do
    public let minApprovalTier: RiskTier             // Minimum approval tier for this connector
    public let requiredFeatureFlags: [String]         // Feature flags that MUST be ON

    // ── Evidence ──────────────────────────────────────
    public let requiredEvidenceTags: [String]         // Evidence tags this connector MUST emit

    // ── Signing (first-party only for v1) ─────────────
    public let signedBy: String                      // "com.operatorkit.firstparty"
    public let manifestHash: String                  // SHA256 of manifest content (computed)

    public init(
        connectorId: String,
        version: String,
        displayName: String,
        description: String,
        allowedHosts: [String],
        allowedHTTPMethods: [String],
        maxPayloadBytes: Int,
        timeoutSeconds: TimeInterval,
        dataClassesTouched: [ConnectorDataClass],
        requiresDataDiode: Bool,
        scopes: [ConnectorScope],
        minApprovalTier: RiskTier,
        requiredFeatureFlags: [String],
        requiredEvidenceTags: [String]
    ) {
        self.connectorId = connectorId
        self.version = version
        self.displayName = displayName
        self.description = description
        self.allowedHosts = allowedHosts
        self.allowedHTTPMethods = allowedHTTPMethods.map { $0.uppercased() }
        self.maxPayloadBytes = maxPayloadBytes
        self.timeoutSeconds = timeoutSeconds
        self.dataClassesTouched = dataClassesTouched
        self.requiresDataDiode = requiresDataDiode
        self.scopes = scopes
        self.minApprovalTier = minApprovalTier
        self.requiredFeatureFlags = requiredFeatureFlags
        self.requiredEvidenceTags = requiredEvidenceTags
        self.signedBy = "com.operatorkit.firstparty"
        self.id = "com.operatorkit.connector.\(connectorId)"

        // Compute manifest hash (content-addressable identity)
        let hashInput = "\(connectorId)|\(version)|\(allowedHosts.sorted().joined())|\(allowedHTTPMethods.sorted().joined())|\(scopes.map(\.rawValue).sorted().joined())"
        let data = Data(hashInput.utf8)
        self.manifestHash = CryptoKit.SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    /// True if this connector has ANY network scope.
    public var requiresNetwork: Bool {
        scopes.contains(where: \.requiresNetwork)
    }

    /// True if all scopes are read-only.
    public var isFullyReadOnly: Bool {
        scopes.allSatisfy(\.isReadOnly)
    }
}

import CryptoKit

// MARK: - First-Party Manifests

/// Registry of all first-party connector manifests.
/// Third-party manifests are NOT supported in v1.
public enum ConnectorManifestRegistry {

    /// GovernedWebFetcher manifest.
    public static let webFetcher = ConnectorManifest(
        connectorId: "web_fetcher",
        version: "1.0.0",
        displayName: "Governed Web Fetcher",
        description: "Fetches public web documents (GET, HTTPS, read-only, allowlisted hosts)",
        allowedHosts: [
            "www.justice.gov", "www.supremecourt.gov", "www.uscourts.gov",
            "www.sec.gov", "www.ftc.gov", "www.fbi.gov", "www.usa.gov",
            "www.congress.gov", "www.gpo.gov", "www.govinfo.gov", "www.federalregister.gov"
        ],
        allowedHTTPMethods: ["GET"],
        maxPayloadBytes: 10_485_760,      // 10 MB
        timeoutSeconds: 10.0,
        dataClassesTouched: [.publicWeb, .piiPossible, .credentialsNone],
        requiresDataDiode: true,
        scopes: [.readWebPublic],
        minApprovalTier: .low,
        requiredFeatureFlags: ["ok_enterprise_web_research", "ok_enterprise_research_host_allowlist"],
        requiredEvidenceTags: ["web_fetch_started", "web_fetch_completed", "web_fetch_denied", "web_fetch_failed"]
    )

    /// SlackNotifier manifest.
    public static let slackNotifier = ConnectorManifest(
        connectorId: "slack_notifier",
        version: "1.0.0",
        displayName: "Slack Notifier",
        description: "Posts FindingPack notifications to Slack via incoming webhook",
        allowedHosts: ["hooks.slack.com"],
        allowedHTTPMethods: ["POST"],
        maxPayloadBytes: 65_536,           // 64 KB
        timeoutSeconds: 15.0,
        dataClassesTouched: [.internalLogs, .webhookPayload, .credentialsNone],
        requiresDataDiode: false,          // Findings are already processed
        scopes: [.postSlack],
        minApprovalTier: .low,
        requiredFeatureFlags: ["ok_enterprise_slack_enabled", "ok_enterprise_slack_host_allowlist"],
        requiredEvidenceTags: ["slack_finding_delivered", "slack_delivery_failed"]
    )

    /// BraveSearch connector manifest.
    public static let braveSearch = ConnectorManifest(
        connectorId: "brave_search",
        version: "1.0.0",
        displayName: "Brave Search",
        description: "Governed web search via Brave Search API (GET, HTTPS, read-only, API-key gated)",
        allowedHosts: ["api.search.brave.com"],
        allowedHTTPMethods: ["GET"],
        maxPayloadBytes: 0,              // GET-only, no request payload
        timeoutSeconds: 15.0,
        dataClassesTouched: [.publicWeb, .credentialsNone],
        requiresDataDiode: false,        // Search results are metadata, not PII-bearing documents
        scopes: [.readWebPublic],
        minApprovalTier: .low,
        requiredFeatureFlags: ["ok_enterprise_web_research", "ok_enterprise_research_host_allowlist"],
        requiredEvidenceTags: ["brave_search_started", "brave_search_completed", "brave_search_denied", "brave_search_failed"]
    )

    /// All registered manifests.
    public static let all: [ConnectorManifest] = [webFetcher, slackNotifier, braveSearch]

    /// Lookup by connectorId.
    public static func manifest(for connectorId: String) -> ConnectorManifest? {
        all.first(where: { $0.connectorId == connectorId })
    }
}
