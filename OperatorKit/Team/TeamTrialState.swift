import Foundation

// ============================================================================
// TEAM TRIAL STATE (Phase 10N)
//
// Local-only team trial state. Process-only, does not change execution safety.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No execution behavior changes
// ❌ No approval bypassing
// ❌ No networking
// ❌ No user content
// ✅ Local UserDefaults only
// ✅ Process-only trial
// ✅ Requires user acknowledgement
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

// MARK: - Team Trial State

public struct TeamTrialState: Codable, Equatable {
    
    /// When trial started
    public let trialStartDate: Date
    
    /// Trial duration in days
    public let trialDays: Int
    
    /// When user acknowledged trial terms
    public let acknowledgedAt: Date
    
    /// Schema version
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    public static let defaultTrialDays = 14
    
    // MARK: - Computed Properties
    
    /// Trial end date
    public var trialEndDate: Date {
        Calendar.current.date(byAdding: .day, value: trialDays, to: trialStartDate) ?? trialStartDate
    }
    
    /// Whether trial is still active
    public var isActive: Bool {
        Date() < trialEndDate
    }
    
    /// Days remaining in trial
    public var daysRemaining: Int {
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: trialEndDate).day ?? 0
        return max(0, remaining)
    }
    
    /// Progress (0.0 - 1.0)
    public var progress: Double {
        let total = Double(trialDays)
        let elapsed = Double(trialDays - daysRemaining)
        return min(1.0, max(0.0, elapsed / total))
    }
    
    // MARK: - Factory
    
    /// Creates a new trial state (requires acknowledgement timestamp)
    public static func createTrial(acknowledgedAt: Date = Date(), days: Int = defaultTrialDays) -> TeamTrialState {
        TeamTrialState(
            trialStartDate: Date(),
            trialDays: days,
            acknowledgedAt: acknowledgedAt,
            schemaVersion: currentSchemaVersion
        )
    }
}

// MARK: - Trial Acknowledgement

public struct TeamTrialAcknowledgement {
    /// Terms that must be acknowledged
    public static let terms: [String] = [
        "This is a process-only trial",
        "Execution safety guarantees remain unchanged",
        "No shared drafts or user content",
        "Team features are governance-only",
        "Trial is local to this device"
    ]
    
    /// Summary for display
    public static let summary = """
    The Team trial lets you explore team governance features. \
    It does not change how OperatorKit processes your requests or \
    bypass any safety guarantees. All execution still requires your approval.
    """
}
