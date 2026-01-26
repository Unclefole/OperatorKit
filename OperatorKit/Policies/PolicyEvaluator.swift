import Foundation

// ============================================================================
// POLICY EVALUATOR (Phase 10C)
//
// Read-only policy evaluation. No side effects.
// Evaluated ONLY from AppState/UI boundary.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ NO side effects
// ❌ NO state mutation
// ❌ NO execution references
// ✅ Pure functions
// ✅ Fail closed (deny if uncertain)
// ✅ Plain language reasons
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

// MARK: - Policy Decision

/// Result of a policy evaluation
public struct PolicyDecision: Equatable {
    
    /// Whether the action is allowed
    public let allowed: Bool
    
    /// Plain language reason (always provided)
    public let reason: String
    
    /// Which capability was evaluated (if applicable)
    public let capability: PolicyCapability?
    
    // MARK: - Factory Methods
    
    /// Create an "allowed" decision
    public static func allow(reason: String = "Action allowed by policy") -> PolicyDecision {
        PolicyDecision(allowed: true, reason: reason, capability: nil)
    }
    
    /// Create an "allowed" decision for a capability
    public static func allow(capability: PolicyCapability) -> PolicyDecision {
        PolicyDecision(
            allowed: true,
            reason: "\(capability.displayName) is allowed by your policy",
            capability: capability
        )
    }
    
    /// Create a "denied" decision
    public static func deny(reason: String) -> PolicyDecision {
        PolicyDecision(allowed: false, reason: reason, capability: nil)
    }
    
    /// Create a "denied" decision for a capability
    public static func deny(capability: PolicyCapability) -> PolicyDecision {
        PolicyDecision(
            allowed: false,
            reason: "\(capability.displayName) is blocked by your policy",
            capability: capability
        )
    }
    
    /// Create a "denied" decision for daily limit
    public static func denyDailyLimit(used: Int, max: Int) -> PolicyDecision {
        PolicyDecision(
            allowed: false,
            reason: "Daily limit reached (\(used)/\(max)). Resets at midnight.",
            capability: nil
        )
    }
    
    /// Create a decision for policy disabled
    public static var policyDisabled: PolicyDecision {
        PolicyDecision(
            allowed: true,
            reason: "Policy is disabled — all capabilities allowed",
            capability: nil
        )
    }
}

// MARK: - Policy Evaluator

/// Evaluates policy decisions without side effects
/// INVARIANT: All methods are pure functions
public final class PolicyEvaluator {
    
    // MARK: - Dependencies
    
    private let policyStore: OperatorPolicyStore
    private let usageLedger: UsageLedger
    
    // MARK: - Initialization
    
    public init(
        policyStore: OperatorPolicyStore = .shared,
        usageLedger: UsageLedger = .shared
    ) {
        self.policyStore = policyStore
        self.usageLedger = usageLedger
    }
    
    // MARK: - Policy Access
    
    /// Current policy (read-only)
    @MainActor
    public var currentPolicy: OperatorPolicy {
        policyStore.currentPolicy
    }
    
    // MARK: - Execution Checks
    
    /// Check if execution can start
    /// INVARIANT: No side effects
    @MainActor
    public func canStartExecution() -> PolicyDecision {
        let policy = currentPolicy
        
        // Policy disabled = all allowed
        guard policy.enabled else {
            return .policyDisabled
        }
        
        // Check daily limit
        if let maxPerDay = policy.maxExecutionsPerDay {
            let todayCount = countTodayExecutions()
            if todayCount >= maxPerDay {
                return .denyDailyLimit(used: todayCount, max: maxPerDay)
            }
        }
        
        return .allow(reason: "Execution allowed by policy")
    }
    
    /// Check if email drafting is allowed
    /// INVARIANT: No side effects
    @MainActor
    public func canDraftEmail() -> PolicyDecision {
        let policy = currentPolicy
        
        guard policy.enabled else {
            return .policyDisabled
        }
        
        if policy.allowEmailDrafts {
            return .allow(capability: .emailDrafts)
        } else {
            return .deny(capability: .emailDrafts)
        }
    }
    
    /// Check if calendar writing is allowed
    /// INVARIANT: No side effects
    @MainActor
    public func canWriteCalendar() -> PolicyDecision {
        let policy = currentPolicy
        
        guard policy.enabled else {
            return .policyDisabled
        }
        
        if policy.allowCalendarWrites {
            return .allow(capability: .calendarWrites)
        } else {
            return .deny(capability: .calendarWrites)
        }
    }
    
    /// Check if task/reminder creation is allowed
    /// INVARIANT: No side effects
    @MainActor
    public func canCreateTask() -> PolicyDecision {
        let policy = currentPolicy
        
        guard policy.enabled else {
            return .policyDisabled
        }
        
        if policy.allowTaskCreation {
            return .allow(capability: .taskCreation)
        } else {
            return .deny(capability: .taskCreation)
        }
    }
    
    /// Check if memory writing is allowed
    /// INVARIANT: No side effects
    @MainActor
    public func canWriteMemory() -> PolicyDecision {
        let policy = currentPolicy
        
        guard policy.enabled else {
            return .policyDisabled
        }
        
        if policy.allowMemoryWrites {
            return .allow(capability: .memoryWrites)
        } else {
            return .deny(capability: .memoryWrites)
        }
    }
    
    /// Check a specific capability
    /// INVARIANT: No side effects
    @MainActor
    public func canUseCapability(_ capability: PolicyCapability) -> PolicyDecision {
        switch capability {
        case .emailDrafts:
            return canDraftEmail()
        case .calendarWrites:
            return canWriteCalendar()
        case .taskCreation:
            return canCreateTask()
        case .memoryWrites:
            return canWriteMemory()
        }
    }
    
    /// Check if explicit confirmation is required
    /// INVARIANT: No side effects
    @MainActor
    public func requiresExplicitConfirmation() -> Bool {
        let policy = currentPolicy
        guard policy.enabled else { return true } // Default to requiring confirmation
        return policy.requireExplicitConfirmation
    }
    
    // MARK: - Helpers
    
    /// Count executions today (derived from usage ledger)
    private func countTodayExecutions() -> Int {
        // Use the executions from the usage ledger
        // This is a read-only operation
        return usageLedger.data.executionsThisWindow
    }
}

// MARK: - Policy Summary

extension PolicyEvaluator {
    
    /// Get a summary of all policy decisions
    /// INVARIANT: No side effects
    @MainActor
    public func allDecisions() -> [PolicyCapability: PolicyDecision] {
        var decisions: [PolicyCapability: PolicyDecision] = [:]
        
        for capability in PolicyCapability.allCases {
            decisions[capability] = canUseCapability(capability)
        }
        
        return decisions
    }
    
    /// Get blocked capabilities
    /// INVARIANT: No side effects
    @MainActor
    public func blockedCapabilities() -> [PolicyCapability] {
        PolicyCapability.allCases.filter { capability in
            !canUseCapability(capability).allowed
        }
    }
    
    /// Get allowed capabilities
    /// INVARIANT: No side effects
    @MainActor
    public func allowedCapabilities() -> [PolicyCapability] {
        PolicyCapability.allCases.filter { capability in
            canUseCapability(capability).allowed
        }
    }
}
