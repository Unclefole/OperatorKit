import Foundation

// ============================================================================
// KERNEL INVARIANTS — PHASE 1 CAPABILITY KERNEL
//
// SAFETY GUARDS THAT MUST BE VERIFIED
//
// Search codebase and FAIL build if found:
// ❌ Direct execution calls (bypassing Kernel)
// ❌ Network mutation outside executor
// ❌ Force unwrap on execution paths
// ❌ Silent retries on mutation
// ❌ Cached approvals
//
// These invariants are enforced at compile-time via assertions
// and at runtime via the KernelGuard.
// ============================================================================

// MARK: - Kernel Invariants

public enum KernelInvariant: String, CaseIterable {
    /// INV-001: No side effects without Kernel approval
    case noSideEffectsWithoutApproval = "INV-001"
    
    /// INV-002: Every action originates from a signed ToolPlan
    case everyActionFromSignedToolPlan = "INV-002"
    
    /// INV-003: Verification before execution (never after)
    case verificationBeforeExecution = "INV-003"
    
    /// INV-004: Secrets never leave trust boundary
    case secretsNeverLeaveTrustBoundary = "INV-004"
    
    /// INV-005: Uncertainty escalates — never executes
    case uncertaintyEscalates = "INV-005"
    
    /// INV-006: No module may self-authorize
    case noSelfAuthorization = "INV-006"
    
    /// INV-007: Execution order must be preserved
    case executionOrderPreserved = "INV-007"
    
    /// INV-008: All mutations must be logged
    case allMutationsLogged = "INV-008"
    
    /// INV-009: Approvals cannot be cached or reused
    case approvalsNotCached = "INV-009"
    
    /// INV-010: Signatures must be verified before use
    case signaturesVerified = "INV-010"
    
    public var description: String {
        switch self {
        case .noSideEffectsWithoutApproval:
            return "Any function capable of mutation MUST pass through Kernel.authorize()"
        case .everyActionFromSignedToolPlan:
            return "No ToolPlan → No execution"
        case .verificationBeforeExecution:
            return "Order: INTAKE → CLASSIFY → RISK → REVERSIBILITY → PROBES → APPROVAL → EXECUTE"
        case .secretsNeverLeaveTrustBoundary:
            return "Real values are tokenized; cloud/model NEVER receives raw secrets"
        case .uncertaintyEscalates:
            return "If confidence < threshold: block execution, require human review"
        case .noSelfAuthorization:
            return "Kernel is supreme authority; modules cannot self-authorize"
        case .executionOrderPreserved:
            return "Execution phases must proceed in strict order"
        case .allMutationsLogged:
            return "Every mutation must be recorded in the evidence chain"
        case .approvalsNotCached:
            return "Each execution requires fresh approval"
        case .signaturesVerified:
            return "ToolPlan signatures must be verified before execution"
        }
    }
}

// MARK: - Kernel Guard

/// Runtime guard that enforces kernel invariants.
/// Violations are logged and optionally fatal in DEBUG mode.
@MainActor
public final class KernelGuard {
    
    public static let shared = KernelGuard()
    
    private var violations: [KernelInvariantViolation] = []
    private var isEnabled: Bool = true
    
    private init() {}
    
    // MARK: - Public API
    
    /// Assert an invariant holds
    public func assert(
        _ invariant: KernelInvariant,
        condition: Bool,
        context: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard isEnabled else { return }
        
        if !condition {
            let violation = KernelInvariantViolation(
                invariant: invariant,
                context: context,
                file: String(describing: file),
                line: Int(line),
                timestamp: Date()
            )
            
            violations.append(violation)
            
            #if DEBUG
            // In DEBUG, violations are fatal
            fatalError("KERNEL INVARIANT VIOLATION [\(invariant.rawValue)]: \(context) at \(file):\(line)")
            #else
            // In RELEASE, log and continue (but execution should be blocked)
            print("⚠️ KERNEL INVARIANT VIOLATION [\(invariant.rawValue)]: \(context)")
            #endif
        }
    }
    
    /// Check if a ToolPlan signature is valid
    public func verifyToolPlanSignature(_ plan: ToolPlan) -> Bool {
        let isValid = plan.verifySignature()
        
        assert(
            .signaturesVerified,
            condition: isValid,
            context: "ToolPlan signature verification failed for plan \(plan.id)"
        )
        
        return isValid
    }
    
    /// Verify execution order is correct
    public func verifyExecutionOrder(currentPhase: KernelPhase, expectedPhases: [KernelPhase]) -> Bool {
        let isValid = expectedPhases.contains(currentPhase)
        
        assert(
            .executionOrderPreserved,
            condition: isValid,
            context: "Unexpected phase \(currentPhase) - expected one of \(expectedPhases)"
        )
        
        return isValid
    }
    
    /// Verify approval is fresh (not cached)
    public func verifyApprovalFreshness(_ approval: ApprovalRecord, maxAgeSeconds: TimeInterval = 300) -> Bool {
        let age = Date().timeIntervalSince(approval.approvedAt)
        let isFresh = age <= maxAgeSeconds
        
        assert(
            .approvalsNotCached,
            condition: isFresh,
            context: "Approval is stale (\(Int(age))s old, max \(Int(maxAgeSeconds))s)"
        )
        
        return isFresh
    }
    
    /// Get all recorded violations
    public func getViolations() -> [KernelInvariantViolation] {
        violations
    }
    
    /// Clear violation history (for testing)
    public func clearViolations() {
        violations.removeAll()
    }
    
    /// Disable guard (for testing only)
    #if DEBUG
    public func disable() {
        isEnabled = false
    }
    
    public func enable() {
        isEnabled = true
    }
    #endif
}

// MARK: - Kernel Invariant Violation
// Named KernelInvariantViolation to avoid collision with existing InvariantViolation in ApprovalGate.swift

public struct KernelInvariantViolation: Codable, Identifiable {
    public let id: UUID
    public let invariant: KernelInvariant
    public let context: String
    public let file: String
    public let line: Int
    public let timestamp: Date
    
    public init(
        id: UUID = UUID(),
        invariant: KernelInvariant,
        context: String,
        file: String,
        line: Int,
        timestamp: Date
    ) {
        self.id = id
        self.invariant = invariant
        self.context = context
        self.file = file
        self.line = line
        self.timestamp = timestamp
    }
}

extension KernelInvariant: Codable {}

// MARK: - Compile-Time Safety Checks

/// Marker protocol for types that require Kernel authorization
public protocol RequiresKernelAuthorization {
    var kernelAuthorizationRequired: Bool { get }
}

/// Marker protocol for side-effect-free operations
public protocol SideEffectFree {
    var hasSideEffects: Bool { get }
}

// MARK: - Forbidden Patterns (Build Script Detection)

/*
 FORBIDDEN PATTERNS - These should be detected by build scripts:
 
 1. Direct URLSession calls outside /Sync/ module:
    Pattern: URLSession\.shared\.(data|upload|download)
    Exception: /Sync/SupabaseClient.swift
 
 2. Force unwraps on execution paths:
    Pattern: \![\s]*[^=]
    Exception: Test files
 
 3. Silent retry without logging:
    Pattern: catch\s*\{\s*\}
    All catches must log or rethrow
 
 4. Cached approval patterns:
    Pattern: static\s+.*approval
    Approvals must be fresh per execution
 
 5. Direct execution without Kernel:
    Pattern: execute\s*\(\s*without:
    All execution must go through Kernel
*/

// MARK: - Execution Gate

/// Gate that must be passed before any mutation can occur.
/// This is the final checkpoint before execution.
public struct ExecutionGate {
    
    /// Validate that all preconditions are met for execution
    public static func validate(
        toolPlan: ToolPlan,
        verificationResult: KernelVerificationResult,
        approval: ApprovalRecord,
        policyDecision: KernelPolicyDecision
    ) throws {
        
        // 1. Verify ToolPlan signature
        guard toolPlan.verifySignature() else {
            throw ExecutionGateError.signatureInvalid
        }
        
        // 2. Verify all required probes passed
        guard verificationResult.overallPassed else {
            throw ExecutionGateError.verificationFailed(verificationResult.summary)
        }
        
        // 3. Verify approval was granted
        guard approval.approved else {
            throw ExecutionGateError.approvalDenied(approval.reason ?? "No reason")
        }
        
        // 4. Verify approval is fresh
        let approvalAge = Date().timeIntervalSince(approval.approvedAt)
        guard approvalAge < 300 else {  // 5 minute freshness
            throw ExecutionGateError.approvalExpired(ageSeconds: Int(approvalAge))
        }
        
        // 5. Verify approval type matches policy requirement
        if policyDecision.approvalRequirement.requiresBiometric {
            guard approval.approvalType == .biometric || approval.approvalType == .multiSig else {
                throw ExecutionGateError.approvalTypeMismatch(
                    required: "biometric",
                    actual: approval.approvalType.rawValue
                )
            }
        }
        
        // 6. Verify multi-sig if required
        if policyDecision.approvalRequirement.multiSignerCount > 1 {
            guard approval.approvalType == .multiSig else {
                throw ExecutionGateError.multiSigRequired(
                    count: policyDecision.approvalRequirement.multiSignerCount
                )
            }
        }
        
        // All checks passed - execution is authorized
    }
}

// MARK: - Execution Gate Errors

public enum ExecutionGateError: Error, LocalizedError {
    case signatureInvalid
    case verificationFailed(String)
    case approvalDenied(String)
    case approvalExpired(ageSeconds: Int)
    case approvalTypeMismatch(required: String, actual: String)
    case multiSigRequired(count: Int)
    case cooldownActive(remainingSeconds: Int)
    case invariantViolation(KernelInvariant)
    
    public var errorDescription: String? {
        switch self {
        case .signatureInvalid:
            return "ToolPlan signature is invalid - possible tampering"
        case .verificationFailed(let summary):
            return "Verification failed: \(summary)"
        case .approvalDenied(let reason):
            return "Approval denied: \(reason)"
        case .approvalExpired(let age):
            return "Approval expired (\(age)s old)"
        case .approvalTypeMismatch(let required, let actual):
            return "Approval type mismatch - required: \(required), got: \(actual)"
        case .multiSigRequired(let count):
            return "Multi-signature required (\(count) signers)"
        case .cooldownActive(let remaining):
            return "Cooldown active - \(remaining)s remaining"
        case .invariantViolation(let invariant):
            return "Kernel invariant violation: \(invariant.description)"
        }
    }
}

// MARK: - Secret Tokenizer (Stub for Phase 1)

/// Tokenizes secrets before they leave trust boundary.
/// INVARIANT 4: Secrets never leave trust boundary.
public enum SecretTokenizer {
    
    private static var tokenStore: [String: String] = [:]
    
    /// Tokenize a secret value
    public static func tokenize(_ value: String) -> String {
        let token = "[TOKEN_\(UUID().uuidString.prefix(8))]"
        tokenStore[token] = value
        return token
    }
    
    /// Rehydrate a token back to its value (only within trust boundary)
    public static func rehydrate(_ token: String) -> String? {
        tokenStore[token]
    }
    
    /// Check if a string contains a raw secret (non-tokenized)
    public static func containsRawSecret(_ string: String) -> Bool {
        // Check for common secret patterns
        let secretPatterns = [
            "password", "secret", "api_key", "apikey", "token",
            "bearer", "authorization", "private_key", "credential"
        ]
        
        let lowercased = string.lowercased()
        return secretPatterns.contains { lowercased.contains($0) }
    }
    
    /// Clear token store (for testing)
    #if DEBUG
    public static func clearTokens() {
        tokenStore.removeAll()
    }
    #endif
}
