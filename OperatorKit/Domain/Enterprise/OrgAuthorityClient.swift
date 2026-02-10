import Foundation
import CryptoKit

// ============================================================================
// ORG AUTHORITY CLIENT — Hybrid Quorum Co-Signer (iOS Side)
//
// INVARIANT: Organization co-signing is REQUIRED for HIGH and CRITICAL tokens.
// INVARIANT: Revoked devices cannot obtain org signatures.
// INVARIANT: Org server is a witness + co-signer — NOT a control plane.
// INVARIANT: Network is feature-flag gated.
//
// Flow:
//   1. Device presents: planHash, deviceFingerprint, epoch, keyVersion, sessionId
//   2. Org server validates device trust + risk policy
//   3. Org server returns CollectedSignature (type: .organizationAuthority)
//   4. Device attaches signature to AuthorizationToken.collectedSignatures
//   5. ExecutionEngine validates quorum with signer types
// ============================================================================

@MainActor
public final class OrgAuthorityClient: ObservableObject {

    public static let shared = OrgAuthorityClient()

    @Published private(set) var isConfigured: Bool = false
    @Published private(set) var lastCoSignAt: Date?
    @Published private(set) var orgEndpoint: URL?

    private init() {}

    // MARK: - Configuration

    public func configure(endpoint: URL) {
        self.orgEndpoint = endpoint
        self.isConfigured = true
        log("[ORG_AUTHORITY] Configured with endpoint: \(endpoint)")
    }

    // MARK: - Co-Sign Request

    public struct CoSignRequest: Codable {
        public let devicePublicKeyFingerprint: String
        public let planHash: String
        public let trustEpoch: Int
        public let keyVersion: Int
        public let approvalSessionId: UUID
        public let riskTier: String
        public let evidenceChainHash: String
    }

    public struct CoSignResponse: Codable {
        public let signerId: String
        public let signatureData: Data
        public let signedAt: Date
        public let orgName: String
    }

    /// Dev mode: use local in-process server adapter instead of network.
    @Published public var useDevServer: Bool = true

    /// Request org co-signature for HIGH/CRITICAL tokens.
    /// Returns a CollectedSignature on success, nil on failure.
    public func requestCoSign(
        planHash: String,
        approvalSessionId: UUID,
        riskTier: RiskTier
    ) async -> CapabilityKernel.CollectedSignature? {

        guard let fingerprint = SecureEnclaveApprover.shared.deviceFingerprint else {
            logError("[ORG_AUTHORITY] No device fingerprint — cannot request co-sign")
            return nil
        }

        // Dev mode: in-process crypto-real co-signer
        if useDevServer {
            let result = DevServerAdapter.shared.handleOrgCoSign(
                deviceFingerprint: fingerprint,
                planHash: planHash,
                trustEpoch: TrustEpochManager.shared.trustEpoch,
                keyVersion: TrustEpochManager.shared.activeKeyVersion,
                approvalSessionId: approvalSessionId,
                riskTier: riskTier.rawValue
            )
            if let sig = result.signature {
                lastCoSignAt = Date()
                log("[ORG_AUTHORITY] Dev co-sign granted")
                try? EvidenceEngine.shared.logGenericArtifact(
                    type: "org_cosign_received",
                    planId: approvalSessionId,
                    jsonString: """
                    {"mode":"dev","planHash":"\(planHash.prefix(16))...","riskTier":"\(riskTier.rawValue)"}
                    """
                )
                return sig
            } else {
                logError("[ORG_AUTHORITY] Dev co-sign REJECTED: \(result.error ?? "unknown")")
                return nil
            }
        }

        // Prod mode: real HTTP endpoint
        guard isConfigured, let endpoint = orgEndpoint else {
            logError("[ORG_AUTHORITY] Not configured — cannot request co-sign")
            return nil
        }

        let chainHash = computeEvidenceChainHash()

        let request = CoSignRequest(
            devicePublicKeyFingerprint: fingerprint,
            planHash: planHash,
            trustEpoch: TrustEpochManager.shared.trustEpoch,
            keyVersion: TrustEpochManager.shared.activeKeyVersion,
            approvalSessionId: approvalSessionId,
            riskTier: riskTier.rawValue,
            evidenceChainHash: chainHash
        )

        do {
            var urlRequest = URLRequest(url: endpoint.appendingPathComponent("/api/v1/cosign"))
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = try JSONEncoder().encode(request)
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("OperatorKit/1.0", forHTTPHeaderField: "User-Agent")
            urlRequest.timeoutInterval = 30

            let (data, response) = try await NetworkPolicyEnforcer.shared.execute(urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                logError("[ORG_AUTHORITY] Co-sign request failed: non-2xx response")
                return nil
            }

            let coSignResponse = try JSONDecoder().decode(CoSignResponse.self, from: data)

            let signature = CapabilityKernel.CollectedSignature(
                signerId: coSignResponse.signerId,
                signerType: .organizationAuthority,
                signatureData: coSignResponse.signatureData,
                signedAt: coSignResponse.signedAt
            )

            lastCoSignAt = Date()

            log("[ORG_AUTHORITY] Co-sign received from org '\(coSignResponse.orgName)'")
            try? EvidenceEngine.shared.logGenericArtifact(
                type: "org_cosign_received",
                planId: approvalSessionId,
                jsonString: """
                {"orgSignerId":"\(coSignResponse.signerId.prefix(16))...","planHash":"\(planHash.prefix(16))...","riskTier":"\(riskTier.rawValue)"}
                """
            )

            return signature

        } catch {
            logError("[ORG_AUTHORITY] Co-sign request error: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    private nonisolated func computeEvidenceChainHash() -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let chainFile = docs.appendingPathComponent("EvidenceChain", isDirectory: true)
            .appendingPathComponent("chain.jsonl")
        guard let data = try? Data(contentsOf: chainFile),
              let content = String(data: data, encoding: .utf8) else {
            return ""
        }
        let digest = SHA256.hash(data: content.data(using: .utf8)!)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
