import Foundation

// ============================================================================
// OPERATOR POLICY STORE (Phase 10C)
//
// Local-only store for the active operator policy.
// Single active policy, no history, no background observers.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ NO network calls
// ❌ NO background observers
// ❌ NO history/versioning
// ✅ Single active policy
// ✅ UserDefaults persistence
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

/// Local-only store for operator policy
@MainActor
public final class OperatorPolicyStore: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = OperatorPolicyStore()
    
    // MARK: - Storage Keys
    
    private enum StorageKey {
        static let policy = "com.operatorkit.operatorPolicy"
    }
    
    // MARK: - Published State
    
    @Published public private(set) var currentPolicy: OperatorPolicy
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.currentPolicy = Self.load(from: defaults)
    }
    
    // MARK: - Policy Access
    
    /// Returns the current active policy
    public func policy() -> OperatorPolicy {
        currentPolicy
    }
    
    /// Returns a plain-text summary of the current policy
    public func policySummary() -> String {
        currentPolicy.summary
    }
    
    /// Returns the policy status text
    public func policyStatusText() -> String {
        currentPolicy.statusText
    }
    
    // MARK: - Policy Modification
    
    /// Updates the current policy
    public func updatePolicy(_ policy: OperatorPolicy) {
        currentPolicy = policy
        save(policy)
        logDebug("Policy updated: \(policy.statusText)", category: .flow)
    }
    
    /// Enables or disables the policy
    public func setEnabled(_ enabled: Bool) {
        var policy = currentPolicy
        policy.enabled = enabled
        updatePolicy(policy)
    }
    
    /// Updates a specific capability
    public func setCapability(_ capability: PolicyCapability, allowed: Bool) {
        var policy = currentPolicy
        
        switch capability {
        case .emailDrafts:
            policy.allowEmailDrafts = allowed
        case .calendarWrites:
            policy.allowCalendarWrites = allowed
        case .taskCreation:
            policy.allowTaskCreation = allowed
        case .memoryWrites:
            policy.allowMemoryWrites = allowed
        }
        
        updatePolicy(policy)
    }
    
    /// Sets the daily execution limit
    public func setMaxExecutionsPerDay(_ limit: Int?) {
        var policy = currentPolicy
        policy.maxExecutionsPerDay = limit
        updatePolicy(policy)
    }
    
    /// Sets whether explicit confirmation is required
    public func setRequireExplicitConfirmation(_ required: Bool) {
        var policy = currentPolicy
        policy.requireExplicitConfirmation = required
        updatePolicy(policy)
    }
    
    /// Resets to default policy
    public func resetToDefault() {
        let defaultPolicy = OperatorPolicy.defaultPolicy
        updatePolicy(defaultPolicy)
        logDebug("Policy reset to default", category: .flow)
    }
    
    // MARK: - Persistence
    
    private static func load(from defaults: UserDefaults) -> OperatorPolicy {
        guard let data = defaults.data(forKey: StorageKey.policy) else {
            return .defaultPolicy
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let policy = try decoder.decode(OperatorPolicy.self, from: data)
            
            // Schema migration would go here
            if policy.schemaVersion < OperatorPolicy.currentSchemaVersion {
                logDebug("Policy schema migration needed: \(policy.schemaVersion) → \(OperatorPolicy.currentSchemaVersion)", category: .flow)
            }
            
            return policy
        } catch {
            logError("Failed to load policy: \(error.localizedDescription)", category: .error)
            return .defaultPolicy
        }
    }
    
    private func save(_ policy: OperatorPolicy) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(policy)
            defaults.set(data, forKey: StorageKey.policy)
        } catch {
            logError("Failed to save policy: \(error.localizedDescription)", category: .error)
        }
    }
}
