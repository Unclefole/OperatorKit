import Foundation
import EventKit

// MARK: - Authorization State

/// Unified authorization state across all permission types
/// Maps platform-specific states to a consistent internal representation
enum AuthorizationState: String, Codable, CaseIterable {
    case notDetermined = "not_determined"
    case denied = "denied"
    case authorized = "authorized"
    case restricted = "restricted"
    case writeOnly = "write_only"      // iOS 17+: writeOnly access granted
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .restricted: return "Restricted"
        case .writeOnly: return "Write Only"
        case .unknown: return "Unknown"
        }
    }
    
    var canRead: Bool {
        self == .authorized
    }
    
    var canWrite: Bool {
        self == .authorized || self == .writeOnly
    }
    
    var requiresUserAction: Bool {
        self == .notDetermined
    }
    
    var requiresSettings: Bool {
        self == .denied || self == .restricted
    }
    
    var icon: String {
        switch self {
        case .notDetermined: return "questionmark.circle"
        case .denied: return "xmark.circle.fill"
        case .authorized: return "checkmark.circle.fill"
        case .restricted: return "lock.circle.fill"
        case .writeOnly: return "pencil.circle.fill"
        case .unknown: return "exclamationmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .notDetermined: return "gray"
        case .denied: return "red"
        case .authorized: return "green"
        case .restricted: return "orange"
        case .writeOnly: return "blue"
        case .unknown: return "gray"
        }
    }
}

// MARK: - Calendar Auth Adapter

/// Adapter for calendar (EKEvent) authorization
/// Handles iOS version differences with #available checks
/// INVARIANT: No prompts without explicit user action
/// INVARIANT: Always use correct API for iOS version
final class CalendarAuthAdapter {
    
    static let shared = CalendarAuthAdapter()
    
    private let eventStore = EKEventStore()
    private var lastRefreshTime: Date?
    
    private init() {}
    
    // MARK: - Authorization Status
    
    /// Get current events authorization status
    /// Does NOT prompt the user - safe to call anytime
    func eventsAuthorizationStatus() -> AuthorizationState {
        lastRefreshTime = Date()
        
        if #available(iOS 17.0, *) {
            return mapStatusIOS17(EKEventStore.authorizationStatus(for: .event))
        } else {
            return mapStatusLegacy(EKEventStore.authorizationStatus(for: .event))
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
            return .authorized  // Full read+write
        case .writeOnly:
            return .writeOnly   // Can write but not read events
        @unknown default:
            log("CalendarAuthAdapter: Unknown status on iOS 17+: \(status.rawValue)")
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
            log("CalendarAuthAdapter: Unknown legacy status: \(status.rawValue)")
            return .unknown
        }
    }
    
    // MARK: - Computed Properties
    
    /// Can read calendar events (requires full access on iOS 17+)
    var canReadEvents: Bool {
        eventsAuthorizationStatus().canRead
    }
    
    /// Can write calendar events (full access OR write-only on iOS 17+)
    var canWriteEvents: Bool {
        eventsAuthorizationStatus().canWrite
    }
    
    /// Last time status was refreshed
    var lastRefresh: Date? {
        lastRefreshTime
    }
    
    // MARK: - Request Access
    
    /// Request FULL access to events (read + write)
    /// INVARIANT: Only call on explicit user tap
    /// Use this for OperatorKit since we need both read (context) and write (create/update)
    func requestEventsWriteAccess() async -> AuthorizationState {
        log("CalendarAuthAdapter: User-initiated FULL access request")
        
        do {
            if #available(iOS 17.0, *) {
                // iOS 17+: Request full access for read+write
                let granted = try await eventStore.requestFullAccessToEvents()
                log("CalendarAuthAdapter: Full access \(granted ? "granted" : "denied")")
                return eventsAuthorizationStatus()
            } else {
                // Legacy: requestAccess grants both read and write
                let granted = try await eventStore.requestAccess(to: .event)
                log("CalendarAuthAdapter: Legacy access \(granted ? "granted" : "denied")")
                return eventsAuthorizationStatus()
            }
        } catch {
            logError("CalendarAuthAdapter: Access request failed: \(error.localizedDescription)")
            return eventsAuthorizationStatus()
        }
    }
    
    /// Request READ-ONLY access to events
    /// INVARIANT: Only call on explicit user tap
    /// Note: On iOS 17+, there's no read-only API - this requests full access
    func requestEventsReadAccess() async -> AuthorizationState {
        log("CalendarAuthAdapter: User-initiated READ access request")
        
        // For OperatorKit, read access also needs full access on iOS 17+
        // because we show events in ContextPicker
        return await requestEventsWriteAccess()
    }
    
    /// Request WRITE-ONLY access (iOS 17+ only)
    /// INVARIANT: Only call on explicit user tap
    /// Note: For OperatorKit, we typically need full access, not write-only
    @available(iOS 17.0, *)
    func requestEventsWriteOnlyAccess() async -> AuthorizationState {
        log("CalendarAuthAdapter: User-initiated WRITE-ONLY access request")
        
        do {
            let granted = try await eventStore.requestWriteOnlyAccessToEvents()
            log("CalendarAuthAdapter: Write-only access \(granted ? "granted" : "denied")")
            return eventsAuthorizationStatus()
        } catch {
            logError("CalendarAuthAdapter: Write-only access request failed: \(error.localizedDescription)")
            return eventsAuthorizationStatus()
        }
    }
    
    // MARK: - Diagnostics (DEBUG)
    
    #if DEBUG
    func diagnosticInfo() -> [String: String] {
        var info: [String: String] = [:]
        
        info["currentStatus"] = eventsAuthorizationStatus().rawValue
        info["canRead"] = canReadEvents ? "true" : "false"
        info["canWrite"] = canWriteEvents ? "true" : "false"
        info["lastRefresh"] = lastRefreshTime?.ISO8601Format() ?? "never"
        
        if #available(iOS 17.0, *) {
            info["apiVersion"] = "iOS 17+ (EKAuthorizationStatus with fullAccess/writeOnly)"
            info["rawStatus"] = String(EKEventStore.authorizationStatus(for: .event).rawValue)
        } else {
            info["apiVersion"] = "Legacy (EKAuthorizationStatus.authorized)"
            info["rawStatus"] = String(EKEventStore.authorizationStatus(for: .event).rawValue)
        }
        
        return info
    }
    #endif
}
