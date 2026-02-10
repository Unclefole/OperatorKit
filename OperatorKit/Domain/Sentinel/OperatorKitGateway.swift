import Foundation

// ============================================================================
// OPERATORKIT GATEWAY — ENTERPRISE AUTHORITY LAYER
//
// Companies DO NOT connect agents directly to tools.
// They connect to OperatorKit.
//
// The Gateway provides:
//   • Policy federation — external policies map to CapabilityKernel rules
//   • Scoped connectors — tools accessible only through governed channels
//   • Audit mirroring — evidence chain exportable for enterprise compliance
//   • Execution attestations — cryptographic proof of authorized execution
//   • Domain allowlists — restrict external connections
//
// INVARIANT: Gateway NEVER bypasses CapabilityKernel.
// INVARIANT: Gateway NEVER executes side effects directly.
// INVARIANT: All Gateway actions are logged to EvidenceEngine.
// ============================================================================

// MARK: - Gateway Protocol

/// Protocol for enterprise connections to OperatorKit.
/// Implementations MUST route through CapabilityKernel.
public protocol OperatorKitGatewayConnector {
    var connectorId: String { get }
    var connectorName: String { get }
    var allowedDomains: [String] { get }
    var allowedScopes: [PermissionScope] { get }
    func validatePolicy(_ proposal: ProposalPack) -> GatewayPolicyResult
}

public struct GatewayPolicyResult {
    public let allowed: Bool
    public let reason: String
    public let enforcedScopes: [PermissionScope]
    
    public static func allow(scopes: [PermissionScope]) -> GatewayPolicyResult {
        GatewayPolicyResult(allowed: true, reason: "Within policy", enforcedScopes: scopes)
    }
    
    public static func deny(reason: String) -> GatewayPolicyResult {
        GatewayPolicyResult(allowed: false, reason: reason, enforcedScopes: [])
    }
}

// MARK: - Execution Attestation

/// Cryptographic proof that an execution was properly authorized.
/// Can be exported for enterprise compliance.
public struct ExecutionAttestation: Codable, Identifiable {
    public let id: UUID
    public let executionRecordId: UUID
    public let proposalId: UUID
    public let approvalSessionId: UUID
    public let tokenId: UUID
    public let planHash: String
    public let riskTier: String
    public let approvedScopes: [String]
    public let executedAt: Date
    public let outcomeStatus: String
    public let attestationSignature: String

    public init(
        executionRecordId: UUID,
        proposalId: UUID,
        approvalSessionId: UUID,
        tokenId: UUID,
        planHash: String,
        riskTier: String,
        approvedScopes: [String],
        executedAt: Date,
        outcomeStatus: String,
        attestationSignature: String
    ) {
        self.id = UUID()
        self.executionRecordId = executionRecordId
        self.proposalId = proposalId
        self.approvalSessionId = approvalSessionId
        self.tokenId = tokenId
        self.planHash = planHash
        self.riskTier = riskTier
        self.approvedScopes = approvedScopes
        self.executedAt = executedAt
        self.outcomeStatus = outcomeStatus
        self.attestationSignature = attestationSignature
    }
}

// MARK: - Gateway

@MainActor
public final class OperatorKitGateway: ObservableObject {

    public static let shared = OperatorKitGateway()

    @Published public private(set) var registeredConnectors: [String: any OperatorKitGatewayConnector] = [:]
    @Published public private(set) var attestations: [ExecutionAttestation] = []

    private init() {}

    // MARK: - Connector Registration

    /// Register an enterprise connector.
    public func registerConnector(_ connector: any OperatorKitGatewayConnector) {
        registeredConnectors[connector.connectorId] = connector
        log("[GATEWAY] Connector registered: \(connector.connectorName) (\(connector.connectorId))")

        try? EvidenceEngine.shared.logGenericArtifact(
            type: "gateway_connector_registered",
            planId: UUID(),
            jsonString: """
            {"connectorId":"\(connector.connectorId)","name":"\(connector.connectorName)","domains":\(connector.allowedDomains),"scopeCount":\(connector.allowedScopes.count)}
            """
        )
    }

    // MARK: - Policy Validation

    /// Validate a proposal against all registered enterprise policies.
    /// Returns merged policy result.
    public func validateEnterprisePolicies(for proposal: ProposalPack) -> GatewayPolicyResult {
        guard !registeredConnectors.isEmpty else {
            return .allow(scopes: proposal.permissionManifest.scopes)
        }

        for (_, connector) in registeredConnectors {
            let result = connector.validatePolicy(proposal)
            if !result.allowed {
                try? EvidenceEngine.shared.logGenericArtifact(
                    type: "gateway_policy_denied",
                    planId: proposal.id,
                    jsonString: """
                    {"connectorId":"\(connector.connectorId)","reason":"\(result.reason)","proposalId":"\(proposal.id)"}
                    """
                )
                return result
            }
        }

        return .allow(scopes: proposal.permissionManifest.scopes)
    }

    // MARK: - Attestation

    /// Generate an execution attestation after authorized execution.
    public func generateAttestation(
        executionRecordId: UUID,
        proposalId: UUID,
        approvalSessionId: UUID,
        token: CapabilityKernel.AuthorizationToken,
        outcomeStatus: String
    ) -> ExecutionAttestation {
        let attestation = ExecutionAttestation(
            executionRecordId: executionRecordId,
            proposalId: proposalId,
            approvalSessionId: approvalSessionId,
            tokenId: token.id,
            planHash: token.planHash,
            riskTier: token.riskTier.rawValue,
            approvedScopes: token.approvedScopes,
            executedAt: Date(),
            outcomeStatus: outcomeStatus,
            attestationSignature: token.signature
        )

        attestations.append(attestation)
        if attestations.count > 100 { attestations.removeFirst() }

        try? EvidenceEngine.shared.logGenericArtifact(
            type: "execution_attestation",
            planId: proposalId,
            jsonString: """
            {"attestationId":"\(attestation.id)","executionRecordId":"\(executionRecordId)","proposalId":"\(proposalId)","sessionId":"\(approvalSessionId)","tokenId":"\(token.id)","riskTier":"\(token.riskTier.rawValue)","outcome":"\(outcomeStatus)"}
            """
        )

        return attestation
    }

    // MARK: - Audit Export

    /// Export audit trail for enterprise compliance.
    public func exportAuditTrail() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(attestations)
    }
}
