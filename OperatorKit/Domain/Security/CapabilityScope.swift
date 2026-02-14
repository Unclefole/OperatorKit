import Foundation

// ============================================================================
// CAPABILITY SCOPE — Least-Privilege Authority Boundaries
//
// Defines the complete scope taxonomy for OperatorKit.
// Scopes are divided into two hard-separated categories:
//
// 1. CONNECTOR SCOPES — read/outbound, never execution
//    (ConnectorScope enum in ConnectorManifest.swift)
//
// 2. KERNEL SCOPES — execution authority, only via KernelAuthorizationToken
//    (KernelScope enum below)
//
// INVARIANT: Connectors NEVER receive kernel scopes.
// INVARIANT: Kernel scopes require ApprovalGate + KernelAuthorizationToken.
// INVARIANT: No scope escalation without biometric re-auth.
// INVARIANT: Scope grants are logged to EvidenceEngine.
// ============================================================================

// MARK: - Kernel Scopes (Execution Authority)

/// Scopes that ONLY the CapabilityKernel may grant, and ONLY after
/// ApprovalGate + biometric verification + KernelAuthorizationToken issuance.
///
/// NO connector may hold a kernel scope. This is enforced at compile time
/// (separate enum type) and at runtime (CapabilityScopeGuard).
public enum KernelScope: String, Codable, Sendable, CaseIterable {
    case executeAction      = "execute_action"       // Run a side-effecting action
    case mintToken          = "mint_token"            // Issue a KernelAuthorizationToken
    case writeCalendar      = "write_calendar"        // Create/modify calendar events
    case sendEmail          = "send_email"            // Actually send an email
    case writeFile          = "write_file"             // Create/modify a file
    case writeReminder      = "write_reminder"         // Create/modify reminders
    case modifyContacts     = "modify_contacts"        // Create/modify contacts
    case purchaseTransaction = "purchase_transaction"  // In-app purchase / financial

    /// Human-readable description.
    public var displayName: String {
        switch self {
        case .executeAction:       return "Execute Action"
        case .mintToken:           return "Mint Authorization Token"
        case .writeCalendar:       return "Write Calendar"
        case .sendEmail:           return "Send Email"
        case .writeFile:           return "Write File"
        case .writeReminder:       return "Write Reminder"
        case .modifyContacts:      return "Modify Contacts"
        case .purchaseTransaction: return "Purchase Transaction"
        }
    }
}

// MARK: - Capability Scope Guard

/// Runtime guard ensuring connectors never hold kernel scopes.
/// Called at connector registration and before any connector operation.
public enum CapabilityScopeGuard {

    // ── Connector-Side Validation ─────────────────────

    /// Verify a connector manifest does NOT claim any kernel scopes.
    /// Returns `true` if the manifest is clean, `false` if it illegally references execution.
    public static func validateManifest(_ manifest: ConnectorManifest) -> ScopeValidationResult {
        // Check 1: Connector scopes must all be ConnectorScope values (enforced by type system)
        // Check 2: Verify no scope name collides with a kernel scope
        let connectorScopeNames = Set(manifest.scopes.map(\.rawValue))
        let kernelScopeNames = Set(KernelScope.allCases.map(\.rawValue))
        let overlap = connectorScopeNames.intersection(kernelScopeNames)

        if !overlap.isEmpty {
            let reason = "Connector '\(manifest.connectorId)' illegally claims kernel scopes: \(overlap.sorted().joined(separator: ", "))"
            logScopeViolation(connectorId: manifest.connectorId, reason: reason)
            return .denied(reason: reason)
        }

        // Check 3: Manifest must not contain execution-related evidence tags
        let forbiddenTags = ["execution_started", "token_issued", "action_executed"]
        let illegalTags = manifest.requiredEvidenceTags.filter { forbiddenTags.contains($0) }
        if !illegalTags.isEmpty {
            let reason = "Connector '\(manifest.connectorId)' references execution evidence tags: \(illegalTags.joined(separator: ", "))"
            logScopeViolation(connectorId: manifest.connectorId, reason: reason)
            return .denied(reason: reason)
        }

        return .allowed
    }

    /// Verify a set of ConnectorScope values contains no execution authority.
    /// This is a compile-time-safe check (ConnectorScope and KernelScope are different types),
    /// but we also do a runtime string-level check for defense-in-depth.
    public static func validateConnectorScopes(_ scopes: [ConnectorScope]) -> ScopeValidationResult {
        let scopeNames = Set(scopes.map(\.rawValue))
        let kernelNames = Set(KernelScope.allCases.map(\.rawValue))
        let overlap = scopeNames.intersection(kernelNames)

        guard overlap.isEmpty else {
            return .denied(reason: "Connector scopes overlap with kernel scopes: \(overlap.sorted().joined(separator: ", "))")
        }
        return .allowed
    }

    // ── Kernel-Side Validation ────────────────────────

    /// Verify a kernel scope grant is appropriate for the given intent.
    /// Only CapabilityKernel should call this.
    public static func validateKernelGrant(scope: KernelScope, forIntent: String) -> ScopeValidationResult {
        // All kernel grants require an intent
        guard !forIntent.isEmpty else {
            return .denied(reason: "Kernel scope '\(scope.rawValue)' requested without intent")
        }
        return .allowed
    }

    // ── Evidence Logging ──────────────────────────────

    private static func logScopeViolation(connectorId: String, reason: String) {
        log("[SCOPE_GUARD] VIOLATION: \(reason)")
        Task { @MainActor in
            try? EvidenceEngine.shared.logGenericArtifact(
                type: "scope_violation",
                planId: UUID(),
                jsonString: """
                {"connectorId":"\(connectorId)","reason":"\(reason)","timestamp":"\(Date().ISO8601Format())"}
                """
            )
        }
    }
}

// MARK: - Scope Validation Result

public enum ScopeValidationResult: Sendable {
    case allowed
    case denied(reason: String)

    public var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }

    public var reason: String? {
        switch self {
        case .allowed: return nil
        case .denied(let r): return r
        }
    }
}

// MARK: - Scope Summary (for audit/display)

/// Human-readable summary of a connector's capability profile.
public struct CapabilityScopeSummary: Sendable {
    public let connectorId: String
    public let version: String
    public let grantedScopes: [ConnectorScope]
    public let isFullyReadOnly: Bool
    public let requiresNetwork: Bool
    public let hasKernelScopeViolation: Bool
    public let violationReason: String?

    public init(manifest: ConnectorManifest) {
        self.connectorId = manifest.connectorId
        self.version = manifest.version
        self.grantedScopes = manifest.scopes
        self.isFullyReadOnly = manifest.isFullyReadOnly
        self.requiresNetwork = manifest.requiresNetwork

        let validation = CapabilityScopeGuard.validateManifest(manifest)
        self.hasKernelScopeViolation = !validation.isAllowed
        self.violationReason = validation.reason
    }
}
