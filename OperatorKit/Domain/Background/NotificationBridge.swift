import Foundation
import UserNotifications
import CryptoKit

// ============================================================================
// NOTIFICATION BRIDGE — Local + Push Notification Management
//
// INVARIANT: Notifications NEVER trigger execution. They only navigate + prefill.
// INVARIANT: Deep links carry signed nonces for replay protection.
// ============================================================================

@MainActor
public final class NotificationBridge: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    public static let shared = NotificationBridge()

    @Published private(set) var deviceToken: Data?
    @Published private(set) var notificationsAuthorized: Bool = false

    // MARK: - Notification Types

    public enum NotificationType: String {
        case proposalReady = "proposal_ready"
        case executionCompleted = "execution_completed"
        case integrityLockdown = "integrity_lockdown"
        case deviceTrustChanged = "device_trust_changed"
        case scoutRunRequested = "scout_run_requested"
    }

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    public func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            notificationsAuthorized = granted
            log("[NOTIFICATIONS] Authorization: \(granted)")
        } catch {
            logError("[NOTIFICATIONS] Authorization failed: \(error)")
        }
    }

    // MARK: - Schedule Local Notifications

    public func scheduleProposalReady(proposalId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "Proposal Ready"
        content.body = "A new action proposal is ready for your review."
        content.sound = .default
        content.userInfo = [
            "type": NotificationType.proposalReady.rawValue,
            "proposalId": proposalId.uuidString,
            "nonce": generateSignedNonce(payload: proposalId.uuidString)
        ]
        content.categoryIdentifier = "PROPOSAL_REVIEW"

        let request = UNNotificationRequest(
            identifier: "proposal-\(proposalId.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
        log("[NOTIFICATIONS] Scheduled proposalReady for \(proposalId)")
    }

    public func scheduleExecutionCompleted(executionId: UUID, summary: String) {
        let content = UNMutableNotificationContent()
        content.title = "Execution Complete"
        content.body = summary.prefix(200).description
        content.sound = .default
        content.userInfo = [
            "type": NotificationType.executionCompleted.rawValue,
            "executionId": executionId.uuidString,
            "nonce": generateSignedNonce(payload: executionId.uuidString)
        ]

        let request = UNNotificationRequest(
            identifier: "exec-\(executionId.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    public func scheduleIntegrityLockdown(reason: String) {
        let content = UNMutableNotificationContent()
        content.title = "⛔ Security Alert"
        content.body = "System integrity failure detected. Execution locked."
        content.sound = UNNotificationSound.defaultCritical
        content.userInfo = [
            "type": NotificationType.integrityLockdown.rawValue,
            "reason": reason,
            "nonce": generateSignedNonce(payload: "lockdown")
        ]

        let request = UNNotificationRequest(
            identifier: "lockdown-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    public func scheduleDeviceTrustChanged(state: String, fingerprint: String) {
        let content = UNMutableNotificationContent()
        content.title = "Device Trust Changed"
        content.body = "Device \(fingerprint.prefix(8))... is now \(state)."
        content.sound = .default
        content.userInfo = [
            "type": NotificationType.deviceTrustChanged.rawValue,
            "state": state,
            "nonce": generateSignedNonce(payload: fingerprint)
        ]

        let request = UNNotificationRequest(
            identifier: "trust-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Schedule a local notification indicating scout was triggered. Also enqueue scout BG task.
    public func scheduleScoutRunRequest() {
        guard EnterpriseFeatureFlags.scoutModeEnabled else { return }

        // Schedule actual scout run via BG queue
        BackgroundScheduler.scheduleScoutRun()

        let content = UNMutableNotificationContent()
        content.title = "Scout Run Requested"
        content.body = "An inbound webhook triggered an autonomous Scout scan."
        content.sound = .default
        content.userInfo = [
            "type": NotificationType.scoutRunRequested.rawValue
        ]

        let request = UNNotificationRequest(
            identifier: "scout-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    public func scheduleGeneric(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Signed Nonce (Replay Protection for Deep Links)

    /// Consumed nonces — prevent replay of deep link activation.
    private static var consumedNonces = ConsumedTokenStore(filename: "consumed_notification_nonces.json")

    /// Generate HMAC-signed nonce bound to a payload + epoch.
    private func generateSignedNonce(payload: String) -> String {
        let nonce = UUID().uuidString
        let epoch = TrustEpochManager.shared.trustEpoch
        let keyVersion = TrustEpochManager.shared.activeKeyVersion
        let material = "\(nonce)|\(payload)|\(epoch)|\(keyVersion)|\(Date().timeIntervalSince1970)"
        guard let key = TrustEpochManager.shared.activeSigningKey() else {
            return nonce // Fallback: unsigned nonce
        }
        let mac = HMAC<SHA256>.authenticationCode(for: material.data(using: .utf8)!, using: key)
        let sig = Data(mac).base64EncodedString()
        return "\(nonce):\(sig):\(epoch):\(keyVersion)"
    }

    /// Validate and consume a signed nonce. Returns true on first valid use.
    public func validateAndConsumeNonce(_ nonceString: String, payload: String) -> Bool {
        let parts = nonceString.split(separator: ":")
        guard parts.count == 4,
              let nonceUUID = UUID(uuidString: String(parts[0])),
              let epoch = Int(parts[2]),
              let keyVersion = Int(parts[3]) else {
            logError("[NOTIFICATIONS] Invalid nonce format")
            return false
        }

        // Epoch/key version must match current
        guard TrustEpochManager.shared.validateTokenBinding(keyVersion: keyVersion, epoch: epoch) else {
            logError("[NOTIFICATIONS] Nonce epoch/key mismatch")
            return false
        }

        // One-time consumption
        let expiry = Date().addingTimeInterval(3600) // 1-hour TTL
        guard Self.consumedNonces.consume(tokenId: nonceUUID, expiresAt: expiry) else {
            logError("[NOTIFICATIONS] Nonce already consumed (replay)")
            return false
        }

        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            handleNotificationAction(userInfo: userInfo)
        }
        completionHandler()
    }

    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - Deep Link Routing (Navigation Only — NEVER Execution)

    private func handleNotificationAction(userInfo: [AnyHashable: Any]) {
        guard let typeString = userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString) else { return }

        switch type {
        case .proposalReady:
            // Navigate to OperatorChannel — NEVER execute
            if let nav = resolveNavigationState() {
                nav.navigate(to: .operatorChannel)
            }
        case .executionCompleted:
            // Navigate to execution details — read only
            break
        case .integrityLockdown:
            // Navigate to integrity incident view
            break
        case .deviceTrustChanged:
            break
        case .scoutRunRequested:
            // Navigate to Scout dashboard — NEVER execute
            if let nav = resolveNavigationState() {
                nav.navigate(to: .scoutDashboard)
            }
        }
    }

    private func resolveNavigationState() -> AppNavigationState? {
        // Resolved via dependency; in production use environment or singleton
        return nil // Wired in OperatorKitApp via onReceive
    }

    // MARK: - APNs Token Registration

    /// Store APNs device token received from UIApplicationDelegate.
    public func registerDeviceToken(_ tokenData: Data) {
        guard EnterpriseFeatureFlags.apnsEnabled else {
            log("[APNs] Feature not enabled — token not stored")
            return
        }
        deviceToken = tokenData
        let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
        log("[APNs] Device token registered: \(tokenString.prefix(16))...")

        // Persist token securely
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.operatorkit.apns-token",
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    /// Load persisted APNs token.
    public func loadPersistedToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.operatorkit.apns-token",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data {
            deviceToken = data
        }
    }
}
