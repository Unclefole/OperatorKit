import Foundation

// ============================================================================
// TEAM TRIAL STORE (Phase 10N)
//
// UserDefaults-backed team trial storage.
// One active trial at a time, requires acknowledgement.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No execution behavior changes
// ❌ No silent tier changes
// ❌ No networking
// ✅ Local-only storage
// ✅ Requires acknowledgement
// ✅ Process-only features
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

@MainActor
public final class TeamTrialStore: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = TeamTrialStore()
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let trialStateKey = "com.operatorkit.team.trial_state"
    private let previousTrialsKey = "com.operatorkit.team.previous_trials_count"
    
    // MARK: - State
    
    @Published public private(set) var currentTrial: TeamTrialState?
    @Published public private(set) var previousTrialsCount: Int
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.previousTrialsCount = defaults.integer(forKey: previousTrialsKey)
        
        if let data = defaults.data(forKey: trialStateKey),
           let trial = try? JSONDecoder().decode(TeamTrialState.self, from: data) {
            // Only keep if still active
            if trial.isActive {
                self.currentTrial = trial
            } else {
                // Trial expired, clear it
                self.currentTrial = nil
                defaults.removeObject(forKey: trialStateKey)
            }
        } else {
            self.currentTrial = nil
        }
    }
    
    // MARK: - Trial Management
    
    /// Whether user can start a new trial
    public func canStartTrial() -> Bool {
        // Only one active trial at a time
        guard currentTrial == nil || currentTrial?.isActive == false else {
            return false
        }
        
        // Allow up to 2 trials total
        return previousTrialsCount < 2
    }
    
    /// Starts a new trial
    /// REQUIRES: User acknowledgement before calling
    /// NOTE: Does NOT change execution behavior (see SAFETY_CONTRACT.md)
    public func startTrial(acknowledgedAt: Date = Date(), days: Int = TeamTrialState.defaultTrialDays) -> Bool {
        guard canStartTrial() else {
            logDebug("Cannot start trial: trial already active or limit reached", category: .team)
            return false
        }
        
        let trial = TeamTrialState.createTrial(acknowledgedAt: acknowledgedAt, days: days)
        currentTrial = trial
        
        // Increment previous trials count
        previousTrialsCount += 1
        defaults.set(previousTrialsCount, forKey: previousTrialsKey)
        
        // Save trial state
        if let data = try? JSONEncoder().encode(trial) {
            defaults.set(data, forKey: trialStateKey)
        }
        
        logDebug("Team trial started: \(days) days", category: .team)
        return true
    }
    
    /// Ends the current trial early
    public func endTrial() {
        currentTrial = nil
        defaults.removeObject(forKey: trialStateKey)
        logDebug("Team trial ended", category: .team)
    }
    
    /// Resets all trial state (for testing)
    public func reset() {
        currentTrial = nil
        previousTrialsCount = 0
        defaults.removeObject(forKey: trialStateKey)
        defaults.removeObject(forKey: previousTrialsKey)
    }
    
    // MARK: - Trial Status
    
    /// Whether there's an active trial
    public var hasActiveTrial: Bool {
        currentTrial?.isActive == true
    }
    
    /// Days remaining in current trial
    public var daysRemaining: Int {
        currentTrial?.daysRemaining ?? 0
    }
    
    /// Trial progress (0.0 - 1.0)
    public var trialProgress: Double {
        currentTrial?.progress ?? 0
    }
    
    /// Status message for UI
    public var statusMessage: String {
        if let trial = currentTrial, trial.isActive {
            if trial.daysRemaining == 1 {
                return "1 day remaining"
            } else if trial.daysRemaining > 0 {
                return "\(trial.daysRemaining) days remaining"
            } else {
                return "Trial ending today"
            }
        } else if previousTrialsCount >= 2 {
            return "Trial limit reached"
        } else {
            return "Start your free trial"
        }
    }
}

// MARK: - Trial Feature Access

extension TeamTrialStore {
    
    /// Whether team governance features are accessible
    /// NOTE: This is UI-only; does NOT affect execution behavior
    public var canAccessTeamGovernance: Bool {
        hasActiveTrial
    }
    
    /// Whether policy templates are accessible during trial
    public var canAccessPolicyTemplates: Bool {
        hasActiveTrial
    }
    
    /// Whether team diagnostics are accessible during trial
    public var canAccessTeamDiagnostics: Bool {
        hasActiveTrial
    }
}
