import Foundation
import CryptoKit

// ============================================================================
// WEBHOOK HANDLER — Signed Inbound Webhook Verification + Routing
//
// INVARIANT: All webhooks MUST carry HMAC signature verified against org key.
// INVARIANT: Nonces are one-time consumed (replay protection).
// INVARIANT: Webhooks NEVER trigger execution. They route to UI only.
// ============================================================================

@MainActor
public final class WebhookHandler: ObservableObject {

    public static let shared = WebhookHandler()

    @Published private(set) var lastWebhookAt: Date?
    @Published private(set) var rejectedCount: Int = 0

    private static var consumedWebhookNonces = ConsumedTokenStore(filename: "consumed_webhook_nonces.json")

    private init() {}

    // MARK: - Webhook Payload

    public struct WebhookPayload: Codable {
        public let type: String        // NotificationType raw value
        public let timestamp: Date
        public let nonce: String       // UUID string
        public let data: [String: String]
        public let signature: String   // HMAC-SHA256 base64
    }

    public enum WebhookError: Error, LocalizedError {
        case invalidSignature
        case replayDetected
        case expiredTimestamp
        case unknownType
        case featureDisabled

        public var errorDescription: String? {
            switch self {
            case .invalidSignature: return "Webhook signature verification failed"
            case .replayDetected: return "Webhook nonce already consumed (replay)"
            case .expiredTimestamp: return "Webhook timestamp too old"
            case .unknownType: return "Unknown webhook event type"
            case .featureDisabled: return "APNs/webhooks feature not enabled"
            }
        }
    }

    // MARK: - Webhook Verification

    /// Verify and process an inbound webhook. FAIL CLOSED on any issue.
    public func handleInbound(_ payload: WebhookPayload) throws {
        // Feature flag gate
        guard EnterpriseFeatureFlags.apnsEnabled else {
            throw WebhookError.featureDisabled
        }

        // 1. Timestamp freshness (5 minute window)
        let age = Date().timeIntervalSince(payload.timestamp)
        guard age >= 0, age < 300 else {
            rejectedCount += 1
            logViolation("expired_timestamp", nonce: payload.nonce)
            throw WebhookError.expiredTimestamp
        }

        // 2. Verify HMAC signature
        guard verifySignature(payload) else {
            rejectedCount += 1
            logViolation("invalid_signature", nonce: payload.nonce)
            throw WebhookError.invalidSignature
        }

        // 3. Nonce replay protection
        guard let nonceUUID = UUID(uuidString: payload.nonce) else {
            rejectedCount += 1
            throw WebhookError.replayDetected
        }
        let expiry = Date().addingTimeInterval(600) // 10-min TTL for nonce
        guard Self.consumedWebhookNonces.consume(tokenId: nonceUUID, expiresAt: expiry) else {
            rejectedCount += 1
            logViolation("nonce_replay", nonce: payload.nonce)
            throw WebhookError.replayDetected
        }

        // 4. Route by type (UI navigation only — NEVER execution)
        try routeWebhook(payload)

        lastWebhookAt = Date()
        log("[WEBHOOK] Processed: type=\(payload.type), nonce=\(payload.nonce.prefix(8))...")
    }

    // MARK: - Signature Verification

    private func verifySignature(_ payload: WebhookPayload) -> Bool {
        // Reconstruct signing material
        let material = "\(payload.type)|\(payload.timestamp.timeIntervalSince1970)|\(payload.nonce)|\(serializeData(payload.data))"

        guard let key = TrustEpochManager.shared.activeSigningKey(),
              let materialData = material.data(using: .utf8),
              let sigData = Data(base64Encoded: payload.signature) else {
            return false
        }

        return HMAC<SHA256>.isValidAuthenticationCode(sigData, authenticating: materialData, using: key)
    }

    private func serializeData(_ data: [String: String]) -> String {
        data.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    }

    // MARK: - Routing (Navigation Only)

    private func routeWebhook(_ payload: WebhookPayload) throws {
        guard let type = NotificationBridge.NotificationType(rawValue: payload.type) else {
            throw WebhookError.unknownType
        }

        switch type {
        case .proposalReady:
            NotificationBridge.shared.scheduleProposalReady(
                proposalId: UUID(uuidString: payload.data["proposalId"] ?? "") ?? UUID()
            )
        case .executionCompleted:
            NotificationBridge.shared.scheduleExecutionCompleted(
                executionId: UUID(uuidString: payload.data["executionId"] ?? "") ?? UUID(),
                summary: payload.data["summary"] ?? "Completed"
            )
        case .integrityLockdown:
            NotificationBridge.shared.scheduleIntegrityLockdown(
                reason: payload.data["reason"] ?? "Remote integrity alert"
            )
        case .deviceTrustChanged:
            NotificationBridge.shared.scheduleDeviceTrustChanged(
                state: payload.data["state"] ?? "unknown",
                fingerprint: payload.data["fingerprint"] ?? ""
            )
        case .scoutRunRequested:
            // Safe: enqueues BG scout task + local notification. NO execution.
            NotificationBridge.shared.scheduleScoutRunRequest()
        }
    }

    // MARK: - Webhook Generation (for DevServerAdapter / testing)

    /// Create a properly signed webhook payload (used by dev server / tests).
    public static func createSigned(
        type: NotificationBridge.NotificationType,
        data: [String: String]
    ) -> WebhookPayload? {
        let nonce = UUID().uuidString
        let timestamp = Date()
        let material = "\(type.rawValue)|\(timestamp.timeIntervalSince1970)|\(nonce)|\(data.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: "&"))"

        guard let key = TrustEpochManager.shared.activeSigningKey(),
              let materialData = material.data(using: .utf8) else {
            return nil
        }

        let mac = HMAC<SHA256>.authenticationCode(for: materialData, using: key)
        let signature = Data(mac).base64EncodedString()

        return WebhookPayload(
            type: type.rawValue,
            timestamp: timestamp,
            nonce: nonce,
            data: data,
            signature: signature
        )
    }

    // MARK: - Violation Logging

    private func logViolation(_ reason: String, nonce: String) {
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "webhook_violation",
            planId: UUID(),
            jsonString: """
            {"reason":"\(reason)","nonce":"\(nonce.prefix(8))...","timestamp":"\(Date())"}
            """
        )
    }
}

// NOTE: APNs token registration is in NotificationBridge.swift (same-file extension required for private(set) access)
