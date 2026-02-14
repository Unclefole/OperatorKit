import Foundation

// ============================================================================
// CONNECTOR GATE — Hard-Fail Policy Enforcement for Connectors
//
// INVARIANT: Every connector request MUST pass through ConnectorGate.
// INVARIANT: Deny = immediate fail-closed + Evidence log + no retry.
// INVARIANT: Gate validates manifest, dual-gates, host allowlist,
//            HTTP method, payload cap, and HTTPS requirement.
// INVARIANT: ConnectorGate NEVER grants execution authority.
// ============================================================================

// MARK: - Gate Decision

public enum ConnectorGateDecision: Sendable {
    case allow(reason: String)
    case deny(reason: String)

    public var isAllowed: Bool {
        if case .allow = self { return true }
        return false
    }

    public var reason: String {
        switch self {
        case .allow(let r): return r
        case .deny(let r): return r
        }
    }
}

// MARK: - Connector Gate Error

public enum ConnectorGateError: Error, LocalizedError {
    case denied(connectorId: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .denied(let cid, let reason):
            return "ConnectorGate DENIED [\(cid)]: \(reason)"
        }
    }
}

// MARK: - Connector Request

/// Describes a connector's intended operation for gate validation.
public struct ConnectorRequest: Sendable {
    public let connectorId: String
    public let targetURL: URL
    public let httpMethod: String       // "GET", "POST", etc.
    public let payloadSize: Int         // Body size in bytes (0 for GET)
    public let timestamp: Date

    public init(connectorId: String, targetURL: URL, httpMethod: String, payloadSize: Int = 0) {
        self.connectorId = connectorId
        self.targetURL = targetURL
        self.httpMethod = httpMethod.uppercased()
        self.payloadSize = payloadSize
        self.timestamp = Date()
    }
}

// MARK: - Connector Gate

public enum ConnectorGate {

    // MARK: - Validate

    /// Validate a connector request against its manifest and runtime policies.
    /// Returns allow/deny with a reason. On deny, evidence is logged.
    public static func validate(
        request: ConnectorRequest,
        manifest: ConnectorManifest
    ) -> ConnectorGateDecision {

        // ── 1. Connector ID must match manifest ──────────
        guard request.connectorId == manifest.connectorId else {
            return deny(
                request: request,
                manifest: manifest,
                reason: "Connector ID mismatch: request=\(request.connectorId), manifest=\(manifest.connectorId)"
            )
        }

        // ── 2. HTTPS required (absolute) ─────────────────
        guard request.targetURL.scheme?.lowercased() == "https" else {
            return deny(
                request: request,
                manifest: manifest,
                reason: "HTTP forbidden — HTTPS required"
            )
        }

        // ── 3. HTTP method must be in manifest ───────────
        guard manifest.allowedHTTPMethods.contains(request.httpMethod) else {
            return deny(
                request: request,
                manifest: manifest,
                reason: "HTTP method \(request.httpMethod) not permitted (allowed: \(manifest.allowedHTTPMethods.joined(separator: ", ")))"
            )
        }

        // ── 4. Host must be on manifest allowlist ────────
        guard let host = request.targetURL.host?.lowercased() else {
            return deny(
                request: request,
                manifest: manifest,
                reason: "No host in URL"
            )
        }

        // Check manifest static allowlist
        let manifestHostAllowed = manifest.allowedHosts.contains(where: { $0.lowercased() == host })
        // Also check NetworkPolicyEnforcer runtime allowlist (for dynamically registered hosts)
        let enforcerAllowed: Bool
        do {
            try NetworkPolicyEnforcer.shared.validate(request.targetURL)
            enforcerAllowed = true
        } catch {
            enforcerAllowed = false
        }

        guard manifestHostAllowed || enforcerAllowed else {
            return deny(
                request: request,
                manifest: manifest,
                reason: "Host '\(host)' not in connector allowlist and not in NetworkPolicyEnforcer allowlist"
            )
        }

        // ── 5. Feature flags (dual-gate) ─────────────────
        for flag in manifest.requiredFeatureFlags {
            guard isFeatureFlagEnabled(flag) else {
                return deny(
                    request: request,
                    manifest: manifest,
                    reason: "Required feature flag '\(flag)' is OFF"
                )
            }
        }

        // ── 6. Cloud kill switch ─────────────────────────
        if EnterpriseFeatureFlags.cloudKillSwitch {
            return deny(
                request: request,
                manifest: manifest,
                reason: "Cloud kill switch is active — all egress denied"
            )
        }

        // ── 7. Payload size cap ──────────────────────────
        if request.payloadSize > manifest.maxPayloadBytes {
            return deny(
                request: request,
                manifest: manifest,
                reason: "Payload \(request.payloadSize) bytes exceeds manifest cap of \(manifest.maxPayloadBytes) bytes"
            )
        }

        // ── 8. Device attestation enforcement ────────────
        //
        // Posture-driven:
        //   Consumer     → advisory (log warning)
        //   Professional → HARD DENY if unattested and supported
        //   Enterprise   → HARD DENY if unattested and supported
        //
        // Simulator/unsupported in DEBUG → bypass with warning.
        // Simulator/unsupported in RELEASE → DENY (no attestation = no trust).
        let attestService = DeviceAttestationService.shared
        let attestVerifier = AppAttestVerifier.shared
        let postureRequiresAttestation = SecurityPostureManager.shared.attestationRequired

        if attestService.isSupported {
            // Device supports App Attest — enforce if posture requires it
            if postureRequiresAttestation && !attestVerifier.isVerified {
                return deny(
                    request: request,
                    manifest: manifest,
                    reason: "device_not_attested: App Attest supported but device not verified. Posture requires attestation."
                )
            } else if !attestVerifier.isVerified {
                // Consumer posture — log warning
                SecurityTelemetry.shared.record(
                    category: .attestation,
                    detail: "Connector request without attestation (consumer posture): \(request.connectorId)",
                    outcome: .warning,
                    metadata: ["host": host, "attestState": attestService.state.rawValue]
                )
            }
        } else {
            // Device does NOT support App Attest (Simulator)
            #if DEBUG
            // DEBUG + Simulator — bypass with warning
            SecurityTelemetry.shared.record(
                category: .attestation,
                detail: "DEBUG: Simulator attestation bypass for \(request.connectorId)",
                outcome: .warning,
                metadata: ["host": host]
            )
            #else
            // RELEASE + unsupported device — HARD DENY if posture requires
            if postureRequiresAttestation {
                return deny(
                    request: request,
                    manifest: manifest,
                    reason: "device_not_attested: App Attest not supported on this device. Cannot verify device integrity."
                )
            }
            #endif
        }

        // ── All checks passed ────────────────────────────
        let attestLabel = attestService.isSupported ? "attest=\(attestService.state.rawValue)" : "attest=n/a"
        let allowReason = "All policies satisfied: host=\(host), method=\(request.httpMethod), flags=OK, \(attestLabel)"
        logDecision(request: request, manifest: manifest, decision: .allow(reason: allowReason))
        return .allow(reason: allowReason)
    }

    // MARK: - Enforce (Throwing)

    /// Validate and throw on deny. Use this as the pre-flight guard.
    public static func enforce(
        request: ConnectorRequest,
        manifest: ConnectorManifest
    ) throws {
        let decision = validate(request: request, manifest: manifest)
        guard decision.isAllowed else {
            throw ConnectorGateError.denied(connectorId: request.connectorId, reason: decision.reason)
        }
    }

    // MARK: - Feature Flag Lookup

    private static func isFeatureFlagEnabled(_ key: String) -> Bool {
        // Check against known feature flag keys
        switch key {
        case "ok_enterprise_web_research":
            return EnterpriseFeatureFlags.webResearchEnabled
        case "ok_enterprise_research_host_allowlist":
            return EnterpriseFeatureFlags.researchHostAllowlistEnabled
        case "ok_enterprise_slack_enabled":
            return EnterpriseFeatureFlags.slackIntegrationEnabled
        case "ok_enterprise_slack_host_allowlist":
            return EnterpriseFeatureFlags.slackHostAllowlistEnabled
        case "ok_enterprise_scout_mode":
            return EnterpriseFeatureFlags.scoutModeEnabled
        default:
            // Unknown flag → fail closed
            log("[CONNECTOR_GATE] Unknown feature flag '\(key)' — fail closed")
            return false
        }
    }

    // MARK: - Deny Helper

    private static func deny(
        request: ConnectorRequest,
        manifest: ConnectorManifest,
        reason: String
    ) -> ConnectorGateDecision {
        let decision = ConnectorGateDecision.deny(reason: reason)
        logDecision(request: request, manifest: manifest, decision: decision)
        log("[CONNECTOR_GATE] DENIED [\(request.connectorId) v\(manifest.version)]: \(reason)")
        return decision
    }

    // MARK: - Evidence Logging

    private static func logDecision(
        request: ConnectorRequest,
        manifest: ConnectorManifest,
        decision: ConnectorGateDecision
    ) {
        let host = request.targetURL.host ?? "nil"
        let path = request.targetURL.path
        let allowed = decision.isAllowed

        let evidenceType = allowed ? "connector_policy_allowed" : "connector_policy_denied"
        let planId = UUID()

        Task { @MainActor in
            try? EvidenceEngine.shared.logGenericArtifact(
                type: evidenceType,
                planId: planId,
                jsonString: """
                {"connectorId":"\(request.connectorId)","version":"\(manifest.version)","manifestHash":"\(manifest.manifestHash.prefix(16))","host":"\(host)","path":"\(path)","method":"\(request.httpMethod)","decision":"\(allowed ? "ALLOW" : "DENY")","reason":"\(decision.reason.prefix(200))","timestamp":"\(Date().ISO8601Format())"}
                """
            )
        }
    }
}
