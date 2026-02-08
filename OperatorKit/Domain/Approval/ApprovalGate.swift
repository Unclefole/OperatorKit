import Foundation

// ============================================================================
// SAFETY CONTRACT REFERENCE
// This file enforces: Guarantee #1 (No Autonomous Actions)
// See: docs/SAFETY_CONTRACT.md
// Changes to approval logic require Safety Contract Change Approval
// ============================================================================

/// ZERO POLICY.
/// Delegates ALL authority to CapabilityKernel.
/// If kernel fails → execution fails.
///
/// ╔═══════════════════════════════════════════════════════════════════════════╗
/// ║  CONTROL-PLANE REFACTOR: PURE ADAPTER                                   ║
/// ╠═══════════════════════════════════════════════════════════════════════════╣
/// ║  ApprovalGate contains ZERO policy logic.                               ║
/// ║  CapabilityKernel is the SOLE policy authority.                         ║
/// ║                                                                         ║
/// ║  ApprovalGate ONLY:                                                     ║
/// ║  ✔ Checks if a draft exists (UI precondition)                           ║
/// ║  ✔ Delegates ALL policy to CapabilityKernel.evaluateExecutionEligibility║
/// ║  ✔ Converts KernelAuthorizationDecision → ApprovalValidation for UI     ║
/// ║                                                                         ║
/// ║  ApprovalGate does NOT:                                                 ║
/// ║  ✘ Evaluate confidence thresholds                                       ║
/// ║  ✘ Check permissions                                                    ║
/// ║  ✘ Decide approval tiers                                                ║
/// ║  ✘ Enforce any policy                                                   ║
/// ║  ✘ Issue authorization tokens                                           ║
/// ║  ✘ Override kernel policy                                               ║
/// ╚═══════════════════════════════════════════════════════════════════════════╝
///
/// SECURITY NOTE: This class MUST be @MainActor to prevent off-main-thread bypasses
@MainActor
final class ApprovalGate {
    
    static let shared = ApprovalGate()
    
    private init() {}
    
    // MARK: - Kernel-Delegated Validation
    
    /// Validates execution eligibility by delegating ALL policy to CapabilityKernel.
    ///
    /// THIS DOES NOT AUTHORIZE EXECUTION.
    /// A passing result means "the kernel has approved UI state for token request."
    ///
    /// ApprovalGate performs EXACTLY ONE local check:
    ///   - Draft exists (cannot call kernel without a draft)
    ///
    /// ALL other checks (confidence, permissions, acknowledgement, approval)
    /// are delegated to CapabilityKernel.evaluateExecutionEligibility().
    ///
    /// SECURITY: didConfirmLowConfidence has NO default value to prevent bypass
    func canExecute(
        draft: Draft?,
        approvalGranted: Bool,
        sideEffects: [SideEffect],
        permissionState: PermissionState,
        didConfirmLowConfidence: Bool  // NO DEFAULT - prevents bypass vulnerability
    ) -> ApprovalValidation {
        
        // ─── SOLE LOCAL CHECK: Draft must exist ─────────────────────────
        guard let draft = draft else {
            return ApprovalValidation(
                canProceed: false,
                reason: "No draft to execute",
                violations: [.missingDraft],
                confidenceSnapshot: nil
            )
        }
        
        // ─── DELEGATE ALL POLICY TO KERNEL ──────────────────────────────
        let kernelDecision = CapabilityKernel.shared.evaluateExecutionEligibility(
            draft: draft,
            sideEffects: sideEffects,
            permissionState: permissionState,
            approvalGranted: approvalGranted,
            didConfirmLowConfidence: didConfirmLowConfidence
        )
        
        // ─── CONVERT KERNEL DECISION → UI VIOLATIONS ────────────────────
        let violations = mapKernelViolations(kernelDecision.violations)
        
        #if DEBUG
        if !violations.isEmpty {
            for violation in violations {
                AppLogger.shared.logInvariantCheck(violation.description, passed: false)
            }
        }
        #endif
        
        // Build confidence snapshot for audit trail (data passthrough, not policy)
        let confidenceSnapshot = ConfidenceSnapshot(
            confidence: draft.confidence,
            threshold: DraftOutput.directProceedConfidence,
            minimumThreshold: DraftOutput.minimumExecutionConfidence,
            modelId: draft.modelMetadata?.modelId ?? "unknown",
            citationsCount: draft.citations.count,
            wasLowConfidenceConfirmed: didConfirmLowConfidence
        )
        
        return ApprovalValidation(
            canProceed: kernelDecision.executionAllowed,
            reason: kernelDecision.reason,
            violations: violations,
            draft: draft,
            confidenceSnapshot: confidenceSnapshot,
            kernelDecision: kernelDecision
        )
    }
    
    /// Convenience method with default permission check
    /// SECURITY: Requires explicit didConfirmLowConfidence parameter
    func canExecute(
        draft: Draft?,
        approvalGranted: Bool,
        sideEffects: [SideEffect],
        didConfirmLowConfidence: Bool  // NO DEFAULT - explicit required
    ) -> Bool {
        let validation = canExecute(
            draft: draft,
            approvalGranted: approvalGranted,
            sideEffects: sideEffects,
            permissionState: PermissionManager.shared.currentState,
            didConfirmLowConfidence: didConfirmLowConfidence
        )

        #if DEBUG
        if !validation.canProceed {
            assertionFailure("INVARIANT VIOLATION: \(validation.reason ?? "Unknown")")
        }
        #endif

        return validation.canProceed
    }
    
    // MARK: - Side Effect Generation
    
    /// Creates side effects list from a draft
    func getSideEffects(for draft: Draft) -> [SideEffect] {
        SideEffectBuilder.build(for: draft)
    }
    
    /// Creates side effects list from an execution plan
    func getSideEffects(from plan: ExecutionPlan) -> [SideEffect] {
        SideEffectBuilder.build(from: plan)
    }
    
    // MARK: - Kernel Violation Mapping
    
    /// Map kernel violation reasons to UI-facing InvariantViolation values.
    /// This is a PURE data conversion. No policy logic.
    private func mapKernelViolations(_ kernelViolations: [KernelPolicyViolationReason]) -> [InvariantViolation] {
        kernelViolations.compactMap { kernelViolation -> InvariantViolation? in
            switch kernelViolation {
            case .approvalNotGranted:
                return .approvalNotGranted
            case .confidenceBelowMinimum(let actual, let required):
                return .confidenceTooLow(actual: actual, required: required)
            case .lowConfidenceUnconfirmed(let confidence):
                return .lowConfidenceNotConfirmed(confidence: confidence)
            case .missingPermissions(let permissions):
                return .missingPermissions(permissions)
            case .sideEffectsNotAcknowledged(let count):
                return .sideEffectsNotAcknowledged(count: count)
            }
        }
    }
}

// MARK: - Approval Validation Result

struct ApprovalValidation {
    let canProceed: Bool
    let reason: String?
    let violations: [InvariantViolation]
    let draft: Draft?
    let confidenceSnapshot: ConfidenceSnapshot?
    let kernelDecision: KernelAuthorizationDecision?
    
    init(
        canProceed: Bool,
        reason: String?,
        violations: [InvariantViolation],
        draft: Draft? = nil,
        confidenceSnapshot: ConfidenceSnapshot? = nil,
        kernelDecision: KernelAuthorizationDecision? = nil
    ) {
        self.canProceed = canProceed
        self.reason = reason
        self.violations = violations
        self.draft = draft
        self.confidenceSnapshot = confidenceSnapshot
        self.kernelDecision = kernelDecision
    }
}

// MARK: - Confidence Snapshot (for Audit Trail)

/// Extended confidence snapshot with model metadata for audit trail
/// Phase 4A: Includes backend info, latency, and safety notes
struct ConfidenceSnapshot: Equatable, Codable {
    let confidence: Double
    let threshold: Double
    let minimumThreshold: Double
    let modelId: String
    let modelBackend: String           // Phase 4A: Backend type used
    let modelVersion: String?          // Phase 4A: Model version
    let citationsCount: Int
    let wasLowConfidenceConfirmed: Bool
    let timestamp: Date
    
    // Phase 4A: Extended fields
    let latencyMs: Int?                // Time to generate draft
    let safetyNotes: [String]          // Safety notes at draft time
    let fallbackReason: String?        // If fallback was used, why
    
    init(
        confidence: Double,
        threshold: Double,
        minimumThreshold: Double,
        modelId: String,
        modelBackend: String = "deterministic",
        modelVersion: String? = nil,
        citationsCount: Int,
        wasLowConfidenceConfirmed: Bool,
        timestamp: Date = Date(),
        latencyMs: Int? = nil,
        safetyNotes: [String] = [],
        fallbackReason: String? = nil
    ) {
        self.confidence = confidence
        self.threshold = threshold
        self.minimumThreshold = minimumThreshold
        self.modelId = modelId
        self.modelBackend = modelBackend
        self.modelVersion = modelVersion
        self.citationsCount = citationsCount
        self.wasLowConfidenceConfirmed = wasLowConfidenceConfirmed
        self.timestamp = timestamp
        self.latencyMs = latencyMs
        self.safetyNotes = safetyNotes
        self.fallbackReason = fallbackReason
    }
    
    /// Create from Draft and ModelMetadata
    init(from draft: Draft, metadata: ModelMetadata?, latencyMs: Int? = nil, wasLowConfidenceConfirmed: Bool = true, fallbackReason: String? = nil) {
        self.confidence = draft.confidence
        self.threshold = DraftOutput.directProceedConfidence
        self.minimumThreshold = DraftOutput.minimumExecutionConfidence
        self.modelId = metadata?.modelId ?? draft.modelMetadata?.modelId ?? "unknown"
        self.modelBackend = metadata?.backend.rawValue ?? draft.modelMetadata?.backend.rawValue ?? "deterministic"
        self.modelVersion = metadata?.version ?? draft.modelMetadata?.version
        self.citationsCount = draft.citations.count
        self.wasLowConfidenceConfirmed = wasLowConfidenceConfirmed
        self.timestamp = Date()
        self.latencyMs = latencyMs ?? metadata?.latencyMs
        self.safetyNotes = draft.safetyNotes
        self.fallbackReason = fallbackReason ?? metadata?.fallbackReason
    }
    
    var confidencePercentage: Int {
        Int(confidence * 100)
    }
    
    var metThreshold: Bool {
        confidence >= threshold
    }
    
    var metMinimum: Bool {
        confidence >= minimumThreshold
    }
    
    var formattedLatency: String? {
        guard let ms = latencyMs else { return nil }
        if ms < 1000 {
            return "\(ms)ms"
        } else {
            return String(format: "%.1fs", Double(ms) / 1000.0)
        }
    }
}

// MARK: - Invariant Violations

enum InvariantViolation: Equatable {
    case missingDraft
    case approvalNotGranted
    case sideEffectsNotAcknowledged(count: Int)
    case missingPermissions([SideEffect.PermissionType])
    case confidenceTooLow(actual: Double, required: Double)
    case lowConfidenceNotConfirmed(confidence: Double)
    
    var description: String {
        switch self {
        case .missingDraft:
            return "No draft to execute"
        case .approvalNotGranted:
            return "Approval not granted by user"
        case .sideEffectsNotAcknowledged(let count):
            return "\(count) side effect(s) not acknowledged"
        case .missingPermissions(let permissions):
            let names = permissions.map { $0.rawValue }.joined(separator: ", ")
            return "Missing permissions: \(names)"
        case .confidenceTooLow(let actual, let required):
            return "Confidence \(Int(actual * 100))% is below minimum \(Int(required * 100))%"
        case .lowConfidenceNotConfirmed(let confidence):
            return "Low confidence \(Int(confidence * 100))% requires explicit confirmation"
        }
    }
    
    var isCritical: Bool {
        switch self {
        case .missingDraft, .approvalNotGranted, .confidenceTooLow:
            return true
        case .sideEffectsNotAcknowledged, .missingPermissions, .lowConfidenceNotConfirmed:
            return true // All violations are critical
        }
    }
}
