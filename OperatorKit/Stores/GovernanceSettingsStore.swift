import Foundation
import SwiftUI

// ============================================================================
// GOVERNANCE SETTINGS STORE — CENTRALIZED STATE FOR SETTINGS + GOVERNANCE
// ============================================================================
// All settings UI reads from this store. All mutations go through here.
// Security-sensitive mutations require BiometricGate authentication.
//
// INVARIANTS:
// ✅ Tier 2 auto-approval is HARD LOCKED false
// ✅ Cloud sync toggle requires biometric authentication
// ✅ Disabling explicit confirmation requires biometric authentication
// ✅ All state persists via UserDefaults
// ✅ Thread-safe via @MainActor
// ============================================================================

@MainActor
public final class GovernanceSettingsStore: ObservableObject {

    // MARK: - Singleton

    public static let shared = GovernanceSettingsStore()

    // MARK: - Storage Keys

    private enum Keys {
        static let tier0AutoApprove = "com.operatorkit.governance.tier0AutoApprove"
        static let tier1AutoApprove = "com.operatorkit.governance.tier1AutoApprove"
        static let biometricRequired = "com.operatorkit.governance.biometricRequired"
        static let sovereignMode = "com.operatorkit.governance.sovereignMode"
    }

    // MARK: - Published State

    /// Whether Tier 0 (Observe) actions auto-approve without confirmation
    @Published public private(set) var tier0AutoApprove: Bool

    /// Whether Tier 1 (Reversible) actions auto-approve without confirmation
    /// Enabling requires FaceID/TouchID
    @Published public private(set) var tier1AutoApprove: Bool

    /// Whether biometric auth is required for security-sensitive changes
    @Published public private(set) var biometricRequired: Bool

    /// Sovereign Mode: all cloud features disabled, device-only operation
    @Published public private(set) var sovereignMode: Bool

    // MARK: - Computed State

    /// Tier 2 auto-approval — HARD LOCKED. Never changes. Never.
    public var tier2AutoApprove: Bool { false }

    /// Whether cloud sync is currently enabled (delegates to SyncFeatureFlag)
    public var cloudSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: SyncFeatureFlag.storageKey)
    }

    /// The current data guarantees (computed from live state)
    public var dataGuarantees: DataGuarantees {
        DataGuarantees.current
    }

    /// The current intelligence mode (computed from device capabilities)
    public var intelligenceMode: IntelligenceMode {
        IntelligenceMode.current
    }

    /// All safety invariants with runtime verification
    public var safetyInvariants: [SafetyInvariant] {
        SafetyInvariant.all
    }

    /// Whether any safety invariant is violated
    public var hasViolation: Bool {
        SafetyInvariant.hasViolation
    }

    /// Network access status text for UI
    public var networkStatusText: String {
        AppSecurityConfig.networkAccessAllowed
            ? "Network Enabled (Sync Only)"
            : "Network Disabled"
    }

    /// Network status icon
    public var networkStatusIcon: String {
        AppSecurityConfig.networkAccessAllowed ? "wifi" : "wifi.slash"
    }

    /// Network status color
    public var networkStatusColor: Color {
        AppSecurityConfig.networkAccessAllowed ? OKColor.riskWarning : OKColor.riskNominal
    }

    /// Institutional policy status text — NEVER "All Allowed"
    public var policyStatusText: String {
        let policy = OperatorPolicyStore.shared.currentPolicy
        if !policy.enabled {
            return "Policy Disabled"
        }
        if policy.requireExplicitConfirmation {
            return "Explicit Confirmation Required"
        }
        // Fallback: count blocked capabilities
        let blockedCount = [
            !policy.allowEmailDrafts,
            !policy.allowCalendarWrites,
            !policy.allowTaskCreation,
            !policy.allowMemoryWrites
        ].filter { $0 }.count

        if blockedCount > 0 {
            return "\(blockedCount) Capabilities Restricted"
        }
        return "Explicit Confirmation Required"
    }

    // MARK: - Initialization

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.tier0AutoApprove = defaults.bool(forKey: Keys.tier0AutoApprove)
        self.tier1AutoApprove = defaults.bool(forKey: Keys.tier1AutoApprove)
        self.biometricRequired = defaults.object(forKey: Keys.biometricRequired) as? Bool ?? true
        self.sovereignMode = defaults.object(forKey: Keys.sovereignMode) as? Bool ?? true
    }

    // MARK: - Tier Auto-Approval

    /// Set Tier 0 auto-approval (no biometric required — low risk)
    public func setTier0AutoApprove(_ enabled: Bool) {
        tier0AutoApprove = enabled
        defaults.set(enabled, forKey: Keys.tier0AutoApprove)
        logDebug("Tier 0 auto-approve → \(enabled)", category: .flow)
    }

    /// Set Tier 1 auto-approval (REQUIRES biometric authentication)
    public func setTier1AutoApprove(_ enabled: Bool) async -> Bool {
        // Enabling requires biometric — disabling does not
        if enabled {
            let authenticated = await BiometricGate.authenticate(
                reason: "Confirm: allow reversible actions without approval"
            )
            guard authenticated else {
                logDebug("Tier 1 auto-approve denied — biometric failed", category: .flow)
                return false
            }
        }
        tier1AutoApprove = enabled
        defaults.set(enabled, forKey: Keys.tier1AutoApprove)
        logDebug("Tier 1 auto-approve → \(enabled)", category: .flow)
        return true
    }

    // MARK: - Cloud Sync

    /// Toggle cloud sync (REQUIRES biometric to enable)
    public func setCloudSyncEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            // Sovereign mode blocks sync
            guard !sovereignMode else {
                logDebug("Cloud sync blocked — Sovereign Mode active", category: .flow)
                return false
            }

            let authenticated = await BiometricGate.authenticate(
                reason: "Confirm: enable cloud sync"
            )
            guard authenticated else {
                logDebug("Cloud sync enable denied — biometric failed", category: .flow)
                return false
            }
        }
        defaults.set(enabled, forKey: SyncFeatureFlag.storageKey)
        objectWillChange.send()
        logDebug("Cloud sync → \(enabled)", category: .flow)
        return true
    }

    // MARK: - Sovereign Mode

    /// Toggle Sovereign Mode. Enabling forces sync OFF.
    public func setSovereignMode(_ enabled: Bool) async -> Bool {
        if !enabled {
            // Disabling sovereign mode is a security downgrade — requires biometric
            let authenticated = await BiometricGate.authenticate(
                reason: "Confirm: disable Sovereign Mode"
            )
            guard authenticated else { return false }
        }

        sovereignMode = enabled
        defaults.set(enabled, forKey: Keys.sovereignMode)

        // Sovereign mode forces sync OFF
        if enabled && cloudSyncEnabled {
            defaults.set(false, forKey: SyncFeatureFlag.storageKey)
            objectWillChange.send()
            logDebug("Sovereign Mode ON — cloud sync forced OFF", category: .flow)
        }

        logDebug("Sovereign Mode → \(enabled)", category: .flow)
        return true
    }

    // MARK: - Explicit Confirmation

    /// Toggle explicit confirmation requirement (REQUIRES biometric to disable)
    public func setRequireExplicitConfirmation(_ required: Bool) async -> Bool {
        if !required {
            let authenticated = await BiometricGate.authenticate(
                reason: "Confirm: disable explicit confirmation requirement"
            )
            guard authenticated else {
                logDebug("Explicit confirmation disable denied — biometric failed", category: .flow)
                return false
            }
        }
        OperatorPolicyStore.shared.setRequireExplicitConfirmation(required)
        objectWillChange.send()
        logDebug("Explicit confirmation → \(required)", category: .flow)
        return true
    }

    // MARK: - Execution Tier Display

    /// Returns display info for all execution tiers
    public var executionTierSummary: [(tier: ExecutionTier, autoApprove: Bool, locked: Bool)] {
        [
            (.observe, tier0AutoApprove, false),
            (.reversible, tier1AutoApprove, false),
            (.irreversible, false, true)  // HARD LOCKED
        ]
    }
}
