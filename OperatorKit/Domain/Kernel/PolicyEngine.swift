import Foundation

// ============================================================================
// POLICY ENGINE — PHASE 1 CAPABILITY KERNEL
//
// Purpose: Map risk → governance requirements.
// Output MUST be machine enforceable.
//
// Approval Matrix:
// - LOW      → auto-approved
// - MEDIUM   → preview required
// - HIGH     → biometric / explicit confirm
// - CRITICAL → multi-signature + cooldown
//
// INVARIANT: Policy must be configurable but NOT runtime-editable without auth
// INVARIANT: No hidden overrides
// ============================================================================

// MARK: - Policy Engine

/// Maps risk assessments to approval requirements.
/// Deterministic. No ML. No runtime edits without authorization.
public final class PolicyEngine {
    
    public static let shared = PolicyEngine()
    
    // MARK: - Policy Configuration
    
    private var policy: PolicyConfiguration
    private let lock = NSLock()
    
    private init() {
        self.policy = PolicyConfiguration.defaultPolicy
    }
    
    // MARK: - Public API
    
    /// Map risk assessment to approval requirement
    public func mapToApproval(assessment: RiskAssessment) -> KernelPolicyDecision {
        lock.lock()
        defer { lock.unlock() }
        
        let requirement = determineApprovalRequirement(tier: assessment.tier, assessment: assessment)
        let constraints = determineConstraints(tier: assessment.tier, assessment: assessment)
        
        return KernelPolicyDecision(
            tier: assessment.tier,
            approvalRequirement: requirement,
            constraints: constraints,
            appliedPolicies: collectAppliedPolicies(tier: assessment.tier)
        )
    }
    
    /// Map intent type directly to base approval (before risk adjustment)
    public func baseApprovalForIntent(type: IntentType) -> ApprovalRequirement {
        lock.lock()
        defer { lock.unlock() }
        
        switch type {
        // Read-only: Auto-approve
        case .readCalendar, .readContacts:
            return ApprovalRequirement.autoApprove
            
        // Draft creation: Preview required
        case .createDraft:
            return ApprovalRequirement.previewRequired
            
        // External communication: Higher bar
        case .sendEmail:
            return ApprovalRequirement.biometricRequired
            
        // Calendar mutations: Preview with explicit confirm
        case .createCalendarEvent, .updateCalendarEvent:
            return ApprovalRequirement.previewRequired
            
        // Deletions: High bar
        case .deleteCalendarEvent, .fileDelete:
            return ApprovalRequirement.biometricRequired
            
        // External API / Database: Critical
        case .externalAPICall, .databaseMutation:
            return ApprovalRequirement.criticalMultiSig
            
        // File writes: Preview
        case .fileWrite:
            return ApprovalRequirement.previewRequired
            
        // System config: Critical
        case .systemConfiguration:
            return ApprovalRequirement.criticalMultiSig
            
        // Reminders: Preview
        case .createReminder:
            return ApprovalRequirement.previewRequired
            
        case .unknown:
            // Unknown defaults to biometric
            return ApprovalRequirement.biometricRequired
        }
    }
    
    /// Update policy (requires authorization)
    /// Returns true if update was applied, false if denied
    public func updatePolicy(_ newPolicy: PolicyConfiguration, authorization: PolicyAuthorizationToken) -> Bool {
        guard authorization.isValid else { return false }
        
        lock.lock()
        defer { lock.unlock() }
        
        self.policy = newPolicy
        return true
    }
    
    /// Get current policy snapshot (read-only)
    public func currentPolicySnapshot() -> PolicyConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return policy
    }
    
    // MARK: - Internal Logic
    
    private func determineApprovalRequirement(tier: RiskTier, assessment: RiskAssessment) -> ApprovalRequirement {
        switch tier {
        case .low:
            return policy.lowTierApproval
            
        case .medium:
            return policy.mediumTierApproval
            
        case .high:
            var requirement = policy.highTierApproval
            
            // Escalate if irreversible
            if assessment.dimensions.reversibility > 50 {
                requirement = ApprovalRequirement(
                    approvalsNeeded: requirement.approvalsNeeded,
                    requiresBiometric: true,
                    cooldownSeconds: max(requirement.cooldownSeconds, 10),
                    multiSignerCount: requirement.multiSignerCount,
                    requiresPreview: true
                )
            }
            
            return requirement
            
        case .critical:
            var requirement = policy.criticalTierApproval
            
            // Always enforce cooldown for critical
            requirement = ApprovalRequirement(
                approvalsNeeded: max(2, requirement.approvalsNeeded),
                requiresBiometric: true,
                cooldownSeconds: max(30, requirement.cooldownSeconds),
                multiSignerCount: max(2, requirement.multiSignerCount),
                requiresPreview: true
            )
            
            return requirement
        }
    }
    
    private func determineConstraints(tier: RiskTier, assessment: RiskAssessment) -> [PolicyConstraint] {
        var constraints: [PolicyConstraint] = []
        
        // Time-of-day constraint
        if tier == .high || tier == .critical {
            constraints.append(PolicyConstraint(
                type: .timeWindow,
                description: "High-risk actions may be restricted during off-hours",
                isSoft: true
            ))
        }
        
        // Rate limiting
        if assessment.dimensions.externalExposure > 50 {
            constraints.append(PolicyConstraint(
                type: .rateLimit,
                description: "External communications are rate-limited",
                isSoft: false
            ))
        }
        
        // Cooldown constraint
        if assessment.dimensions.reversibility > 70 {
            constraints.append(PolicyConstraint(
                type: .cooldown,
                description: "Irreversible actions require cooldown period",
                isSoft: false
            ))
        }
        
        // Audit constraint (always)
        constraints.append(PolicyConstraint(
            type: .auditRequired,
            description: "Action will be logged to audit trail",
            isSoft: false
        ))
        
        return constraints
    }
    
    private func collectAppliedPolicies(tier: RiskTier) -> [String] {
        var policies: [String] = ["BASE_POLICY_v1"]
        
        switch tier {
        case .low:
            policies.append("AUTO_APPROVE_LOW_RISK")
        case .medium:
            policies.append("PREVIEW_MEDIUM_RISK")
            policies.append("USER_CONFIRM_REQUIRED")
        case .high:
            policies.append("BIOMETRIC_HIGH_RISK")
            policies.append("ESCALATE_IRREVERSIBLE")
        case .critical:
            policies.append("MULTI_SIG_CRITICAL")
            policies.append("MANDATORY_COOLDOWN")
            policies.append("ESCALATE_IRREVERSIBLE")
        }
        
        return policies
    }
}

// MARK: - Kernel Policy Decision
// Named KernelPolicyDecision to avoid collision with existing PolicyDecision in PolicyEvaluator.swift

public struct KernelPolicyDecision: Codable, Equatable {
    public let tier: RiskTier
    public let approvalRequirement: ApprovalRequirement
    public let constraints: [PolicyConstraint]
    public let appliedPolicies: [String]
    public let decidedAt: Date
    
    public init(
        tier: RiskTier,
        approvalRequirement: ApprovalRequirement,
        constraints: [PolicyConstraint],
        appliedPolicies: [String],
        decidedAt: Date = Date()
    ) {
        self.tier = tier
        self.approvalRequirement = approvalRequirement
        self.constraints = constraints
        self.appliedPolicies = appliedPolicies
        self.decidedAt = decidedAt
    }
    
    /// Human-readable summary
    public var summary: String {
        var parts: [String] = []
        parts.append("Tier: \(tier.rawValue)")
        
        if approvalRequirement.requiresBiometric {
            parts.append("Biometric required")
        }
        if approvalRequirement.cooldownSeconds > 0 {
            parts.append("Cooldown: \(approvalRequirement.cooldownSeconds)s")
        }
        if approvalRequirement.multiSignerCount > 1 {
            parts.append("Multi-sig: \(approvalRequirement.multiSignerCount)")
        }
        
        return parts.joined(separator: " | ")
    }
}

// MARK: - Policy Constraint

public struct PolicyConstraint: Codable, Equatable, Identifiable {
    public let id: UUID
    public let type: ConstraintType
    public let description: String
    public let isSoft: Bool  // Soft constraints can be overridden with justification
    
    public init(
        id: UUID = UUID(),
        type: ConstraintType,
        description: String,
        isSoft: Bool
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.isSoft = isSoft
    }
}

public enum ConstraintType: String, Codable, CaseIterable {
    case timeWindow = "time_window"
    case rateLimit = "rate_limit"
    case cooldown = "cooldown"
    case auditRequired = "audit_required"
    case geographicRestriction = "geographic_restriction"
    case deviceTrust = "device_trust"
}

// MARK: - Policy Configuration

/// Configurable policy rules.
/// Changes require PolicyAuthorizationToken.
public struct PolicyConfiguration: Codable, Equatable {
    public let version: String
    public let lowTierApproval: ApprovalRequirement
    public let mediumTierApproval: ApprovalRequirement
    public let highTierApproval: ApprovalRequirement
    public let criticalTierApproval: ApprovalRequirement
    public let globalConstraints: [PolicyConstraint]
    
    public init(
        version: String,
        lowTierApproval: ApprovalRequirement,
        mediumTierApproval: ApprovalRequirement,
        highTierApproval: ApprovalRequirement,
        criticalTierApproval: ApprovalRequirement,
        globalConstraints: [PolicyConstraint] = []
    ) {
        self.version = version
        self.lowTierApproval = lowTierApproval
        self.mediumTierApproval = mediumTierApproval
        self.highTierApproval = highTierApproval
        self.criticalTierApproval = criticalTierApproval
        self.globalConstraints = globalConstraints
    }
    
    /// Default production policy
    public static let defaultPolicy = PolicyConfiguration(
        version: "1.0.0",
        lowTierApproval: ApprovalRequirement(
            approvalsNeeded: 0,
            requiresBiometric: false,
            cooldownSeconds: 0,
            multiSignerCount: 0,
            requiresPreview: false
        ),
        mediumTierApproval: ApprovalRequirement(
            approvalsNeeded: 1,
            requiresBiometric: false,
            cooldownSeconds: 0,
            multiSignerCount: 1,
            requiresPreview: true
        ),
        highTierApproval: ApprovalRequirement(
            approvalsNeeded: 1,
            requiresBiometric: true,
            cooldownSeconds: 0,
            multiSignerCount: 1,
            requiresPreview: true
        ),
        criticalTierApproval: ApprovalRequirement(
            approvalsNeeded: 2,
            requiresBiometric: true,
            cooldownSeconds: 30,
            multiSignerCount: 2,
            requiresPreview: true
        ),
        globalConstraints: [
            PolicyConstraint(
                type: .auditRequired,
                description: "All actions are logged",
                isSoft: false
            )
        ]
    )
    
    /// Strict policy for high-security environments
    public static let strictPolicy = PolicyConfiguration(
        version: "1.0.0-strict",
        lowTierApproval: ApprovalRequirement(
            approvalsNeeded: 1,
            requiresBiometric: false,
            cooldownSeconds: 0,
            multiSignerCount: 1,
            requiresPreview: true
        ),
        mediumTierApproval: ApprovalRequirement(
            approvalsNeeded: 1,
            requiresBiometric: true,
            cooldownSeconds: 5,
            multiSignerCount: 1,
            requiresPreview: true
        ),
        highTierApproval: ApprovalRequirement(
            approvalsNeeded: 2,
            requiresBiometric: true,
            cooldownSeconds: 15,
            multiSignerCount: 2,
            requiresPreview: true
        ),
        criticalTierApproval: ApprovalRequirement(
            approvalsNeeded: 3,
            requiresBiometric: true,
            cooldownSeconds: 60,
            multiSignerCount: 3,
            requiresPreview: true
        ),
        globalConstraints: [
            PolicyConstraint(
                type: .auditRequired,
                description: "All actions are logged",
                isSoft: false
            ),
            PolicyConstraint(
                type: .deviceTrust,
                description: "Device must be trusted",
                isSoft: false
            )
        ]
    )
}

// MARK: - Policy Authorization Token

/// Token required to modify policy configuration.
/// Prevents runtime tampering.
public struct PolicyAuthorizationToken: Codable {
    public let tokenId: UUID
    public let issuedAt: Date
    public let expiresAt: Date
    public let scope: PolicyAuthorizationScope
    
    public init(
        tokenId: UUID = UUID(),
        issuedAt: Date = Date(),
        validForSeconds: TimeInterval = 300,
        scope: PolicyAuthorizationScope = .policyUpdate
    ) {
        self.tokenId = tokenId
        self.issuedAt = issuedAt
        self.expiresAt = issuedAt.addingTimeInterval(validForSeconds)
        self.scope = scope
    }
    
    public var isValid: Bool {
        Date() < expiresAt
    }
    
    /// Create a test token (DEBUG only)
    #if DEBUG
    public static func testToken() -> PolicyAuthorizationToken {
        PolicyAuthorizationToken(validForSeconds: 3600, scope: .fullAccess)
    }
    #endif
}

public enum PolicyAuthorizationScope: String, Codable {
    case policyUpdate = "policy_update"
    case emergencyOverride = "emergency_override"
    case fullAccess = "full_access"
}

// MARK: - Policy Violation

public struct PolicyViolation: Codable, Identifiable {
    public let id: UUID
    public let violationType: PolicyViolationType
    public let description: String
    public let severity: ViolationSeverity
    public let occurredAt: Date
    
    public init(
        id: UUID = UUID(),
        violationType: PolicyViolationType,
        description: String,
        severity: ViolationSeverity,
        occurredAt: Date = Date()
    ) {
        self.id = id
        self.violationType = violationType
        self.description = description
        self.severity = severity
        self.occurredAt = occurredAt
    }
}

public enum PolicyViolationType: String, Codable, CaseIterable {
    case bypassAttempt = "bypass_attempt"
    case approvalSkipped = "approval_skipped"
    case cooldownViolation = "cooldown_violation"
    case signatureMismatch = "signature_mismatch"
    case unauthorizedExecution = "unauthorized_execution"
    case rateLimitExceeded = "rate_limit_exceeded"
}

public enum ViolationSeverity: String, Codable, CaseIterable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case critical = "CRITICAL"
}
