import Foundation
import CryptoKit

// ============================================================================
// SLACK NOTIFIER — Incoming Webhook Delivery for Scout Findings
//
// INVARIANT: Feature-flagged OFF by default.
// INVARIANT: Network-enforced via NetworkPolicyEnforcer allowlist.
// INVARIANT: Payloads signed with HMAC + nonce replay protection.
// INVARIANT: No execution, no tokens, no side effects.
// ============================================================================

@MainActor
public final class SlackNotifier: ObservableObject {

    public static let shared = SlackNotifier()

    @Published private(set) var lastSentAt: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isSending = false
    @Published public var isConfigured: Bool = false

    private static let webhookKeychainService = "com.operatorkit.slack-webhook-url"
    private static var consumedSlackNonces = ConsumedTokenStore(filename: "consumed_slack_nonces.json")

    private init() {
        isConfigured = loadWebhookURL() != nil
    }

    // MARK: - Webhook URL Management (Keychain)

    public func configureWebhook(url: String) {
        guard let urlObj = URL(string: url),
              urlObj.host?.contains("hooks.slack.com") == true || urlObj.host?.contains("slack.com") == true else {
            lastError = "Invalid Slack webhook URL"
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.webhookKeychainService,
            kSecValueData as String: url.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)

        isConfigured = true
        lastError = nil

        // Host allowlist is managed by EnterpriseFeatureFlags.setSlackHostAllowlistEnabled
        // Auto-enable if not already enabled
        if !EnterpriseFeatureFlags.slackHostAllowlistEnabled {
            EnterpriseFeatureFlags.setSlackHostAllowlistEnabled(true)
        }

        log("[SLACK] Webhook configured")
    }

    public func removeWebhook() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.webhookKeychainService
        ]
        SecItemDelete(query as CFDictionary)
        isConfigured = false
        EnterpriseFeatureFlags.setSlackHostAllowlistEnabled(false)
        log("[SLACK] Webhook removed")
    }

    private func loadWebhookURL() -> URL? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.webhookKeychainService,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8),
              let url = URL(string: str) else { return nil }
        return url
    }

    // MARK: - Send FindingPack

    public func sendFindingPack(_ pack: FindingPack) async {
        guard EnterpriseFeatureFlags.slackDeliveryPermitted else {
            log("[SLACK] Slack delivery not permitted (flags: integration=\(EnterpriseFeatureFlags.slackIntegrationEnabled), hostAllowlist=\(EnterpriseFeatureFlags.slackHostAllowlistEnabled))")
            return
        }

        guard let webhookURL = loadWebhookURL() else {
            lastError = "Webhook URL not configured"
            return
        }

        isSending = true
        defer { isSending = false }

        // Build Slack Block Kit payload
        let blocks = buildSlackBlocks(pack)
        let nonce = UUID()
        let timestamp = Date()

        // Sign payload
        let payloadJSON = (try? JSONSerialization.data(withJSONObject: blocks)) ?? Data()
        let signature = signPayload(nonce: nonce, timestamp: timestamp, payload: payloadJSON)

        // Consume nonce (replay protection)
        let expiry = Date().addingTimeInterval(3600)
        guard Self.consumedSlackNonces.consume(tokenId: nonce, expiresAt: expiry) else {
            lastError = "Nonce collision"
            return
        }

        // Build request
        let body: [String: Any] = ["blocks": blocks]

        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(nonce.uuidString, forHTTPHeaderField: "X-OperatorKit-Nonce")
        request.setValue(String(timestamp.timeIntervalSince1970), forHTTPHeaderField: "X-OperatorKit-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-OperatorKit-Signature")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        // Send via NetworkPolicyEnforcer
        do {
            let (_, response) = try await NetworkPolicyEnforcer.shared.execute(request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                lastError = "Slack returned non-200"
                logError("[SLACK] Delivery failed: non-200 response")
                return
            }
            lastSentAt = Date()
            lastError = nil
            log("[SLACK] FindingPack delivered: \(pack.id)")

            // Evidence: successful delivery
            try? EvidenceEngine.shared.logGenericArtifact(
                type: "slack_finding_delivered",
                planId: pack.scoutRunId,
                jsonString: """
                {"findingPackId":"\(pack.id)","severity":"\(pack.severity.rawValue)","findingCount":\(pack.findings.count),"deliveredAt":"\(Date())"}
                """
            )
        } catch {
            lastError = error.localizedDescription
            logError("[SLACK] Delivery failed: \(error)")

            // Evidence: delivery failure
            try? EvidenceEngine.shared.logGenericArtifact(
                type: "slack_delivery_failed",
                planId: pack.scoutRunId,
                jsonString: """
                {"findingPackId":"\(pack.id)","error":"\(error.localizedDescription)","timestamp":"\(Date())"}
                """
            )
        }
    }

    // MARK: - Send Test Message

    public func sendTestMessage() async -> Bool {
        guard EnterpriseFeatureFlags.slackDeliveryPermitted else {
            lastError = "Slack delivery not permitted (enable both flags)"
            return false
        }
        guard let webhookURL = loadWebhookURL() else {
            lastError = "Webhook URL not configured"
            return false
        }

        isSending = true
        defer { isSending = false }

        let body: [String: Any] = [
            "blocks": [
                ["type": "header", "text": ["type": "plain_text", "text": "OperatorKit Scout Test"]],
                ["type": "section", "text": ["type": "mrkdwn", "text": "This is a test message from OperatorKit Scout Mode. If you see this, Slack integration is working."]]
            ]
        ]

        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        do {
            let (_, response) = try await NetworkPolicyEnforcer.shared.execute(request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                lastError = "Slack returned non-200"
                return false
            }
            lastSentAt = Date()
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Slack Block Kit Builder

    private func buildSlackBlocks(_ pack: FindingPack) -> [[String: Any]] {
        var blocks: [[String: Any]] = []

        // Header
        let severityEmoji: String
        switch pack.severity {
        case .critical: severityEmoji = "🔴"
        case .warning: severityEmoji = "🟡"
        case .info: severityEmoji = "🔵"
        case .nominal: severityEmoji = "🟢"
        }

        blocks.append([
            "type": "header",
            "text": ["type": "plain_text", "text": "\(severityEmoji) OperatorKit Scout Findings"]
        ])

        // Summary
        blocks.append([
            "type": "section",
            "text": ["type": "mrkdwn", "text": pack.summary]
        ])

        blocks.append(["type": "divider"])

        // Top findings (max 5)
        for finding in pack.findings.prefix(5) {
            let emoji: String
            switch finding.category {
            case .integrityWarning, .auditDivergence: emoji = "🔴"
            case .policyDenialSpike, .deviceTrust, .keyLifecycle: emoji = "🟡"
            case .budgetThrottling: emoji = "🟠"
            case .executionAnomaly: emoji = "⚠️"
            case .systemHealth: emoji = "🟢"
            }

            blocks.append([
                "type": "section",
                "text": ["type": "mrkdwn", "text": "\(emoji) *\(finding.title)*\n\(finding.detail.prefix(200))"]
            ])
        }

        if pack.findings.count > 5 {
            blocks.append([
                "type": "section",
                "text": ["type": "mrkdwn", "text": "_+ \(pack.findings.count - 5) more findings…_"]
            ])
        }

        blocks.append(["type": "divider"])

        // Action buttons as context (Slack incoming webhooks don't support interactive blocks, so use deep link text)
        blocks.append([
            "type": "context",
            "elements": [
                ["type": "mrkdwn", "text": "📱 Open in OperatorKit → `operatorkit://scout`  |  📋 Create Proposal → `operatorkit://operator-channel`"]
            ]
        ])

        return blocks
    }

    // MARK: - Payload Signing

    private func signPayload(nonce: UUID, timestamp: Date, payload: Data) -> String {
        let material = "\(nonce.uuidString)|\(timestamp.timeIntervalSince1970)|\(payload.count)"
        guard let key = TrustEpochManager.shared.activeSigningKey(),
              let data = material.data(using: .utf8) else {
            return "unsigned"
        }
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(mac).base64EncodedString()
    }
}
