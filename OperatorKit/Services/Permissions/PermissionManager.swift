import Foundation
import EventKit
import MessageUI
import UIKit

/// Manages permission states with REAL system checks via adapters
/// INVARIANT: No auto-requesting permissions
/// INVARIANT: If permission missing, show warning and block execution
/// INVARIANT: Write operations blocked if permission not granted
/// INVARIANT: Uses adapters as single source of truth
@MainActor
final class PermissionManager: ObservableObject {
    
    static let shared = PermissionManager()
    
    // MARK: - Adapters (Single Source of Truth)
    
    private let calendarAdapter = CalendarAuthAdapter.shared
    private let remindersAdapter = RemindersAuthAdapter.shared
    
    // MARK: - Published State
    
    @Published private(set) var calendarState: AuthorizationState = .notDetermined
    @Published private(set) var remindersState: AuthorizationState = .notDetermined
    @Published private(set) var canSendMail: Bool = false
    @Published private(set) var lastRefresh: Date = Date()
    
    // MARK: - Initialization
    
    private init() {
        // Initial refresh on init (does NOT prompt)
        refreshSystemPermissionStates()
        
        // Observe app becoming active to refresh permissions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        // Refresh on foreground - this is user-initiated by design
        refreshSystemPermissionStates()
    }
    
    // MARK: - Permission Refresh
    
    /// Refreshes all permission states from adapters
    /// Does NOT request any permissions - read-only
    /// INVARIANT: Safe to call anytime, no prompts
    /// Call on:
    ///   - App foreground
    ///   - User opening PrivacyControls
    ///   - User tapping manual refresh button
    func refreshSystemPermissionStates() {
        log("PermissionManager: Refreshing permission states via adapters...")
        
        // Calendar (via adapter)
        calendarState = calendarAdapter.eventsAuthorizationStatus()
        
        // Reminders (via adapter)
        remindersState = remindersAdapter.remindersAuthorizationStatus()
        
        // Mail (direct check - no adapter needed)
        canSendMail = MFMailComposeViewController.canSendMail()
        
        lastRefresh = Date()
        
        log("PermissionManager: States refreshed - Calendar: \(calendarState.displayName), Reminders: \(remindersState.displayName), Mail: \(canSendMail ? "Available" : "Not Configured")")
    }
    
    // MARK: - Permission Checks
    
    /// Current permission state (for audit trail)
    var currentState: PermissionState {
        PermissionState(
            calendar: calendarState.toAppPermission,
            reminders: remindersState.toAppPermission,
            mail: canSendMail ? .granted : .notConfigured,
            calendarGranted: isCalendarAuthorized,
            remindersGranted: isRemindersAuthorized,
            mailGranted: canSendMail,
            timestamp: lastRefresh
        )
    }
    
    /// Check if a specific permission is granted
    func hasPermission(_ permission: SideEffect.PermissionType) -> Bool {
        switch permission {
        case .calendar:
            return isCalendarAuthorized
        case .reminders:
            return isRemindersAuthorized
        case .mail:
            return canSendMail
        }
    }
    
    /// Check if calendar is authorized (can read)
    var isCalendarAuthorized: Bool {
        calendarAdapter.canReadEvents
    }
    
    /// Check if calendar can write
    var canWriteCalendar: Bool {
        calendarAdapter.canWriteEvents
    }
    
    /// Check if reminders are authorized (can read)
    var isRemindersAuthorized: Bool {
        remindersAdapter.canReadReminders
    }
    
    /// Check if reminders write is possible
    var canWriteReminders: Bool {
        remindersAdapter.canWriteReminders
    }
    
    // MARK: - Permission Request (User-Initiated Only)
    
    /// Request calendar access (ONLY when user explicitly triggers)
    /// INVARIANT: Never called automatically
    func requestCalendarAccess() async -> Bool {
        log("[Permission] REQUEST START — Calendar")

        let newState = await calendarAdapter.requestEventsWriteAccess()
        log("[Permission] iOS RESPONSE — Calendar: \(newState.rawValue)")

        // Force recheck from system (iOS dialog response can lag)
        let verifiedState = calendarAdapter.eventsAuthorizationStatus()
        let finalState = verifiedState.canWrite ? verifiedState : newState
        log("[Permission] VERIFIED STATE — Calendar: \(finalState.rawValue)")

        calendarState = finalState
        lastRefresh = Date()
        objectWillChange.send()

        let granted = finalState.canRead || finalState.canWrite
        log("[Permission] FINAL — Calendar: \(granted ? "GRANTED ✅" : "DENIED ❌")")
        return granted
    }

    /// Request reminders access (ONLY when user explicitly triggers)
    /// INVARIANT: Never called automatically
    func requestRemindersAccess() async -> Bool {
        log("[Permission] REQUEST START — Reminders")

        let newState = await remindersAdapter.requestRemindersWriteAccess()
        log("[Permission] iOS RESPONSE — Reminders: \(newState.rawValue)")

        // Force recheck from system (iOS dialog response can lag)
        let verifiedState = remindersAdapter.remindersAuthorizationStatus()
        let finalState = verifiedState.canWrite ? verifiedState : newState
        log("[Permission] VERIFIED STATE — Reminders: \(finalState.rawValue)")

        remindersState = finalState
        lastRefresh = Date()
        objectWillChange.send()

        let granted = finalState.canRead || finalState.canWrite
        log("[Permission] FINAL — Reminders: \(granted ? "GRANTED ✅" : "DENIED ❌")")
        return granted
    }
    
    // MARK: - Side Effect Permission Check
    
    /// Check if all required permissions for side effects are granted
    /// INVARIANT: Blocks execution if any required permission is missing
    func canExecuteSideEffects(_ sideEffects: [SideEffect]) -> PermissionCheckResult {
        var missingPermissions: [SideEffect.PermissionType] = []
        var warnings: [String] = []
        var blockedWriteOperations: [SideEffect.SideEffectType] = []
        
        for effect in sideEffects where effect.isEnabled {
            if let required = effect.requiresPermission {
                if !hasPermission(required) {
                    missingPermissions.append(required)
                    warnings.append("\(effect.type.displayName) requires \(required.rawValue)")
                    
                    // Track blocked write operations specifically
                    if effect.type.isWriteOperation {
                        blockedWriteOperations.append(effect.type)
                    }
                }
            }
        }
        
        // Log any blocked write operations
        if !blockedWriteOperations.isEmpty {
            logWarning("Write operations blocked due to missing permissions: \(blockedWriteOperations.map { $0.displayName }.joined(separator: ", "))")
        }
        
        return PermissionCheckResult(
            canProceed: missingPermissions.isEmpty,
            missingPermissions: missingPermissions,
            warnings: warnings,
            blockedWriteOperations: blockedWriteOperations
        )
    }
    
    // MARK: - Settings Helper
    
    /// Open system settings for OperatorKit
    /// Use when user needs to manually grant permissions
    @MainActor
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            #if DEBUG
            print("[PermissionManager] ❌ Failed to create settings URL")
            #endif
            return
        }

        Task { @MainActor in
            let success = await UIApplication.shared.open(url)
            #if DEBUG
            if success {
                print("[PermissionManager] ✅ Opened Settings successfully")
            } else {
                print("[PermissionManager] ❌ Failed to open Settings URL")
            }
            #endif
        }
    }
    
    /// Get guidance for denied permission
    func getPermissionGuidance(for permission: SideEffect.PermissionType) -> PermissionGuidance {
        let isGranted = hasPermission(permission)
        
        switch permission {
        case .calendar:
            return PermissionGuidance(
                permission: permission,
                authState: calendarState,
                isGranted: isGranted,
                title: "Calendar Access",
                message: isGranted ? "Calendar access is granted." : "Calendar access is required to view and select events.",
                actionTitle: isGranted ? nil : (calendarState.requiresUserAction ? "Allow Access" : "Open Settings"),
                canRequestDirectly: calendarState.requiresUserAction
            )
            
        case .reminders:
            return PermissionGuidance(
                permission: permission,
                authState: remindersState,
                isGranted: isGranted,
                title: "Reminders Access",
                message: isGranted ? "Reminders access is granted." : "Reminders access is required to create reminders.",
                actionTitle: isGranted ? nil : (remindersState.requiresUserAction ? "Allow Access" : "Open Settings"),
                canRequestDirectly: remindersState.requiresUserAction
            )
            
        case .mail:
            return PermissionGuidance(
                permission: permission,
                authState: canSendMail ? .authorized : .denied,
                isGranted: canSendMail,
                title: "Mail Access",
                message: canSendMail ? "Mail is configured." : "A mail account must be configured in the iOS Mail app.",
                actionTitle: canSendMail ? nil : "Open Mail Settings",
                canRequestDirectly: false
            )
        }
    }
    
    // MARK: - Diagnostics (DEBUG)
    
    #if DEBUG
    func diagnosticInfo() -> [String: Any] {
        var info: [String: Any] = [:]
        
        info["calendarState"] = calendarState.rawValue
        info["calendarCanRead"] = calendarAdapter.canReadEvents
        info["calendarCanWrite"] = calendarAdapter.canWriteEvents
        info["calendarLastRefresh"] = calendarAdapter.lastRefresh?.ISO8601Format() ?? "never"
        info["calendarDiagnostics"] = calendarAdapter.diagnosticInfo()
        
        info["remindersState"] = remindersState.rawValue
        info["remindersCanRead"] = remindersAdapter.canReadReminders
        info["remindersCanWrite"] = remindersAdapter.canWriteReminders
        info["remindersLastRefresh"] = remindersAdapter.lastRefresh?.ISO8601Format() ?? "never"
        info["remindersDiagnostics"] = remindersAdapter.diagnosticInfo()
        
        info["mailConfigured"] = canSendMail
        info["lastRefresh"] = lastRefresh.ISO8601Format()
        
        return info
    }
    #endif
}

// MARK: - Permission State Model

/// Snapshot of all permission states (for audit trail)
struct PermissionState: Equatable {
    let calendar: AppPermissionStatus
    let reminders: AppPermissionStatus
    let mail: AppPermissionStatus
    
    // Convenience booleans
    let calendarGranted: Bool
    let remindersGranted: Bool
    let mailGranted: Bool
    
    let timestamp: Date
    
    enum AppPermissionStatus: String, Codable {
        case granted = "Granted"
        case denied = "Denied"
        case notDetermined = "Not Requested"
        case restricted = "Restricted"
        case notConfigured = "Not Configured"
        case writeOnly = "Write Only"
        
        var isGranted: Bool {
            self == .granted
        }
        
        var displayColor: String {
            switch self {
            case .granted: return "green"
            case .denied, .restricted: return "red"
            case .notDetermined, .notConfigured: return "orange"
            case .writeOnly: return "blue"
            }
        }
    }
    
    var allGranted: Bool {
        calendar.isGranted && reminders.isGranted && mail.isGranted
    }
    
    var summary: String {
        """
        Calendar: \(calendar.rawValue)
        Reminders: \(reminders.rawValue)
        Mail: \(mail.rawValue)
        """
    }
}

// MARK: - AuthorizationState Extension

extension AuthorizationState {
    /// Convert to AppPermissionStatus for audit trail
    var toAppPermission: PermissionState.AppPermissionStatus {
        switch self {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .granted
        case .writeOnly:
            return .writeOnly
        case .unknown:
            return .notDetermined
        }
    }
}

// MARK: - Permission Check Result

struct PermissionCheckResult {
    let canProceed: Bool
    let missingPermissions: [SideEffect.PermissionType]
    let warnings: [String]
    let blockedWriteOperations: [SideEffect.SideEffectType]
    
    init(
        canProceed: Bool,
        missingPermissions: [SideEffect.PermissionType],
        warnings: [String],
        blockedWriteOperations: [SideEffect.SideEffectType] = []
    ) {
        self.canProceed = canProceed
        self.missingPermissions = missingPermissions
        self.warnings = warnings
        self.blockedWriteOperations = blockedWriteOperations
    }
    
    var displayMessage: String {
        if canProceed {
            return "All required permissions granted"
        } else {
            return "Missing: \(missingPermissions.map { $0.rawValue }.joined(separator: ", "))"
        }
    }
    
    var hasBlockedWrites: Bool {
        !blockedWriteOperations.isEmpty
    }
}

// MARK: - Permission Guidance

struct PermissionGuidance {
    let permission: SideEffect.PermissionType
    let authState: AuthorizationState
    let isGranted: Bool
    let title: String
    let message: String
    let actionTitle: String?
    let canRequestDirectly: Bool
}
