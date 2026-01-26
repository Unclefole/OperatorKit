import Foundation
import EventKit

// MARK: - Reminders Auth Adapter

/// Adapter for reminders (EKReminder) authorization
/// Handles iOS version differences with #available checks
/// INVARIANT: No prompts without explicit user action
/// INVARIANT: Always use correct API for iOS version
final class RemindersAuthAdapter {
    
    static let shared = RemindersAuthAdapter()
    
    private let eventStore = EKEventStore()
    private var lastRefreshTime: Date?
    
    private init() {}
    
    // MARK: - Authorization Status
    
    /// Get current reminders authorization status
    /// Does NOT prompt the user - safe to call anytime
    func remindersAuthorizationStatus() -> AuthorizationState {
        lastRefreshTime = Date()
        
        if #available(iOS 17.0, *) {
            return mapStatusIOS17(EKEventStore.authorizationStatus(for: .reminder))
        } else {
            return mapStatusLegacy(EKEventStore.authorizationStatus(for: .reminder))
        }
    }
    
    /// Map EKAuthorizationStatus on iOS 17+
    @available(iOS 17.0, *)
    private func mapStatusIOS17(_ status: EKAuthorizationStatus) -> AuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .fullAccess:
            return .authorized  // Full read+write for reminders
        case .writeOnly:
            // Reminders doesn't have a separate writeOnly on iOS 17+ but handle anyway
            return .writeOnly
        @unknown default:
            log("RemindersAuthAdapter: Unknown status on iOS 17+: \(status.rawValue)")
            return .unknown
        }
    }
    
    /// Map EKAuthorizationStatus on iOS < 17
    private func mapStatusLegacy(_ status: EKAuthorizationStatus) -> AuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            log("RemindersAuthAdapter: Unknown legacy status: \(status.rawValue)")
            return .unknown
        }
    }
    
    // MARK: - Computed Properties
    
    /// Can read reminders
    var canReadReminders: Bool {
        remindersAuthorizationStatus().canRead
    }
    
    /// Can write reminders (create/update/delete)
    var canWriteReminders: Bool {
        remindersAuthorizationStatus().canWrite
    }
    
    /// Last time status was refreshed
    var lastRefresh: Date? {
        lastRefreshTime
    }
    
    // MARK: - Request Access
    
    /// Request FULL access to reminders (read + write)
    /// INVARIANT: Only call on explicit user tap
    func requestRemindersWriteAccess() async -> AuthorizationState {
        log("RemindersAuthAdapter: User-initiated FULL access request")
        
        do {
            if #available(iOS 17.0, *) {
                // iOS 17+: Request full access for read+write
                let granted = try await eventStore.requestFullAccessToReminders()
                log("RemindersAuthAdapter: Full access \(granted ? "granted" : "denied")")
                return remindersAuthorizationStatus()
            } else {
                // Legacy: requestAccess grants both read and write
                let granted = try await eventStore.requestAccess(to: .reminder)
                log("RemindersAuthAdapter: Legacy access \(granted ? "granted" : "denied")")
                return remindersAuthorizationStatus()
            }
        } catch {
            logError("RemindersAuthAdapter: Access request failed: \(error.localizedDescription)")
            return remindersAuthorizationStatus()
        }
    }
    
    /// Request READ-ONLY access to reminders
    /// INVARIANT: Only call on explicit user tap
    /// Note: On iOS 17+, for OperatorKit we need full access to create reminders
    func requestRemindersReadAccess() async -> AuthorizationState {
        log("RemindersAuthAdapter: User-initiated READ access request")
        
        // For OperatorKit, we need full access since we create reminders
        return await requestRemindersWriteAccess()
    }
    
    // MARK: - Diagnostics (DEBUG)
    
    #if DEBUG
    func diagnosticInfo() -> [String: String] {
        var info: [String: String] = [:]
        
        info["currentStatus"] = remindersAuthorizationStatus().rawValue
        info["canRead"] = canReadReminders ? "true" : "false"
        info["canWrite"] = canWriteReminders ? "true" : "false"
        info["lastRefresh"] = lastRefreshTime?.ISO8601Format() ?? "never"
        
        if #available(iOS 17.0, *) {
            info["apiVersion"] = "iOS 17+ (EKAuthorizationStatus with fullAccess)"
            info["rawStatus"] = String(EKEventStore.authorizationStatus(for: .reminder).rawValue)
        } else {
            info["apiVersion"] = "Legacy (EKAuthorizationStatus.authorized)"
            info["rawStatus"] = String(EKEventStore.authorizationStatus(for: .reminder).rawValue)
        }
        
        return info
    }
    #endif
}
