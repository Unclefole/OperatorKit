import Foundation

// ============================================================================
// SAFE RESET CONTROLS (Phase 10Q)
//
// User-initiated reset actions with confirmation.
// No effect on execution safety. No data leaves device.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No effect on execution safety
// ❌ No data export
// ❌ No networking
// ❌ No background effects
// ✅ Confirmation required
// ✅ User-initiated only
// ✅ Local device only
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Reset Action

public enum ResetAction: String, CaseIterable, Identifiable {
    case auditTrail = "audit_trail"
    case diagnostics = "diagnostics"
    case onboarding = "onboarding"
    case firstWeek = "first_week"
    case conversionCounters = "conversion_counters"
    case outcomeLedger = "outcome_ledger"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .auditTrail: return "Clear Audit Trail"
        case .diagnostics: return "Clear Diagnostics"
        case .onboarding: return "Reset Onboarding"
        case .firstWeek: return "Reset First Week State"
        case .conversionCounters: return "Clear Conversion Counters"
        case .outcomeLedger: return "Clear Outcome Tracking"
        }
    }
    
    public var description: String {
        switch self {
        case .auditTrail:
            return "Removes all audit events from this device. Does not affect execution safety."
        case .diagnostics:
            return "Clears diagnostic snapshots and counters. Does not affect execution safety."
        case .onboarding:
            return "Allows you to see the onboarding flow again."
        case .firstWeek:
            return "Resets the first-week guidance state."
        case .conversionCounters:
            return "Clears local monetization counters. Does not affect your subscription."
        case .outcomeLedger:
            return "Clears outcome template usage counts."
        }
    }
    
    public var icon: String {
        switch self {
        case .auditTrail: return "list.bullet.clipboard"
        case .diagnostics: return "waveform.path.ecg"
        case .onboarding: return "person.crop.circle.badge.questionmark"
        case .firstWeek: return "calendar.badge.clock"
        case .conversionCounters: return "chart.bar"
        case .outcomeLedger: return "checkmark.seal"
        }
    }
    
    public var confirmationTitle: String {
        "Confirm \(displayName)"
    }
    
    public var confirmationMessage: String {
        "\(description)\n\nThis cannot be undone."
    }
    
    /// Whether this reset affects data that might be useful for support
    public var affectsSupport: Bool {
        switch self {
        case .auditTrail, .diagnostics:
            return true
        case .onboarding, .firstWeek, .conversionCounters, .outcomeLedger:
            return false
        }
    }
}

// MARK: - Safe Reset Controller

@MainActor
public final class SafeResetController: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = SafeResetController()
    
    // MARK: - State
    
    @Published public private(set) var lastResetAction: ResetAction?
    @Published public private(set) var lastResetDate: Date?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Reset Actions
    
    /// Performs a reset action (requires explicit confirmation from UI)
    public func performReset(_ action: ResetAction) {
        switch action {
        case .auditTrail:
            resetAuditTrail()
        case .diagnostics:
            resetDiagnostics()
        case .onboarding:
            resetOnboarding()
        case .firstWeek:
            resetFirstWeek()
        case .conversionCounters:
            resetConversionCounters()
        case .outcomeLedger:
            resetOutcomeLedger()
        }
        
        lastResetAction = action
        lastResetDate = Date()
        
        logDebug("Reset performed: \(action.rawValue)", category: .diagnostics)
    }
    
    // MARK: - Individual Resets
    
    private func resetAuditTrail() {
        CustomerAuditTrailStore.shared.purgeAll()
    }
    
    private func resetDiagnostics() {
        ExecutionDiagnostics.shared.reset()
    }
    
    private func resetOnboarding() {
        OnboardingStateStore.shared.reset()
    }
    
    private func resetFirstWeek() {
        FirstWeekStore.shared.reset()
    }
    
    private func resetConversionCounters() {
        ConversionLedger.shared.reset()
    }
    
    private func resetOutcomeLedger() {
        OutcomeLedger.shared.reset()
    }
}
