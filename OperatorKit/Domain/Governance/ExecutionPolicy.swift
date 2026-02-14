import Foundation
import CryptoKit

// ============================================================================
// EXECUTION POLICY — Versioned, Hashable Policy-as-Code
//
// The formal governance layer for execution eligibility.
// Every execution MUST be evaluated against an ExecutionPolicy
// before a token can be minted.
//
// INVARIANT: Policies are versioned and immutable once created.
// INVARIANT: Policy hash is deterministic (same inputs = same hash).
// INVARIANT: Fail closed — if policy cannot be evaluated, execution is denied.
// INVARIANT: This does NOT replace PolicyEvaluator (capability checks) or
//            PolicyEngine (risk-to-governance mapping). It is the FORMAL
//            governance layer that ExecutionEngine checks before token mint.
//
// EVIDENCE TAGS:
//   policy_evaluated, policy_denied, policy_hash
// ============================================================================

// MARK: - Execution Policy

/// A versioned, hashable execution policy that defines what is allowed.
/// This is the source of truth for execution eligibility decisions.
public struct ExecutionPolicy: Codable, Equatable, Sendable {

    // ── Identity ──────────────────────────────────────
    public let version: String                        // SemVer: "1.0.0"
    public let policyId: UUID
    public let createdAt: Date

    // ── Scope Rules ───────────────────────────────────
    /// Scopes that are explicitly allowed (empty = all blocked)
    public let allowedScopes: Set<String>

    // ── Risk Rules ────────────────────────────────────
    /// Maximum risk tier that can be auto-approved
    public let riskCeiling: RiskTier

    // ── Approval Rules ────────────────────────────────
    /// Whether biometric approval is always required
    public let requiresBiometric: Bool

    /// Whether quorum (multi-signer) approval is required
    public let requiresQuorum: Bool

    /// Only allow reversible operations
    public let reversibleOnly: Bool

    // ── Cost Rules ────────────────────────────────────
    /// Maximum estimated token cost for a single execution (0 = unlimited)
    public let maxTokenCost: Int

    // ── Time Rules ────────────────────────────────────
    /// Hours of the day when execution is allowed (empty = always allowed)
    public let allowedHours: ClosedRange<Int>?

    // MARK: - Initialization

    public init(
        version: String = "1.0.0",
        policyId: UUID = UUID(),
        createdAt: Date = Date(),
        allowedScopes: Set<String> = [],
        riskCeiling: RiskTier = .high,
        requiresBiometric: Bool = false,
        requiresQuorum: Bool = false,
        reversibleOnly: Bool = false,
        maxTokenCost: Int = 0,
        allowedHours: ClosedRange<Int>? = nil
    ) {
        self.version = version
        self.policyId = policyId
        self.createdAt = createdAt
        self.allowedScopes = allowedScopes
        self.riskCeiling = riskCeiling
        self.requiresBiometric = requiresBiometric
        self.requiresQuorum = requiresQuorum
        self.reversibleOnly = reversibleOnly
        self.maxTokenCost = maxTokenCost
        self.allowedHours = allowedHours
    }

    // MARK: - Deterministic Hash

    /// SHA256 hash of the policy content. Deterministic — same inputs produce same hash.
    /// This hash is embedded in every AuthorizationToken and ExecutionCertificate.
    public var policyHash: String {
        let material = [
            "v=\(version)",
            "id=\(policyId.uuidString)",
            "scopes=\(allowedScopes.sorted().joined(separator: ","))",
            "ceiling=\(riskCeiling.rawValue)",
            "bio=\(requiresBiometric)",
            "quorum=\(requiresQuorum)",
            "revOnly=\(reversibleOnly)",
            "maxCost=\(maxTokenCost)",
            "hours=\(allowedHours.map { "\($0.lowerBound)-\($0.upperBound)" } ?? "any")"
        ].joined(separator: "|")

        let hash = SHA256.hash(data: Data(material.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Default Policies

    /// Default production policy — balanced security
    public static let `default` = ExecutionPolicy(
        version: "1.0.0",
        allowedScopes: [
            "readWebPublic", "readCalendar", "readMail", "readReminders",
            "draftEmail", "draftProposal",
            "readInternalLogs"
        ],
        riskCeiling: .high,
        requiresBiometric: false,
        requiresQuorum: false,
        reversibleOnly: false,
        maxTokenCost: 50_000
    )

    /// Strict policy — enterprise / high-security environments
    public static let strict = ExecutionPolicy(
        version: "1.0.0-strict",
        allowedScopes: [
            "readWebPublic", "readCalendar", "readMail",
            "draftEmail", "draftProposal"
        ],
        riskCeiling: .medium,
        requiresBiometric: true,
        requiresQuorum: true,
        reversibleOnly: true,
        maxTokenCost: 10_000
    )

    /// Lockdown policy — no execution permitted
    public static let lockdown = ExecutionPolicy(
        version: "1.0.0-lockdown",
        allowedScopes: [],
        riskCeiling: .low,
        requiresBiometric: true,
        requiresQuorum: true,
        reversibleOnly: true,
        maxTokenCost: 0
    )
}
