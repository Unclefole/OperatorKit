import Foundation

// ============================================================================
// SAFETY CONTRACT REFERENCE
// This file enforces: Guarantee #1 (No Autonomous Actions)
// See: docs/SAFETY_CONTRACT.md
// Changes to approval logic require Safety Contract Change Approval
// ============================================================================

/// Controls the approval gate before execution
/// INVARIANT: No execution can occur without explicit approval
/// INVARIANT: All side effects must be acknowledged before execution
/// INVARIANT: Confidence must meet minimum threshold (0.35)
/// INVARIANT: Low confidence (0.35-0.65) requires explicit "Proceed Anyway"
final class ApprovalGate {
    
    static let shared = ApprovalGate()
    
    private init() {}
    
    // MARK: - Validation
    
    /// Validates that execution can proceed
    /// Returns true only if ALL conditions are met:
    /// 1. Draft exists
    /// 2. Approval was explicitly granted
    /// 3. All enabled side effects are acknowledged
    /// 4. Required permissions are available (or will be requested)
    /// 5. Confidence meets minimum threshold (>= 0.35)
    /// 6. If low confidence (< 0.65), user explicitly confirmed "Proceed Anyway"
    func canExecute(
        draft: Draft?,
        approvalGranted: Bool,
        sideEffects: [SideEffect],
        permissionState: PermissionState,
        didConfirmLowConfidence: Bool = true // Default true for backward compatibility
    ) -> ApprovalValidation {
        
        // Check 1: Draft exists
        guard let draft = draft else {
            return ApprovalValidation(
                canProceed: false,
                reason: "No draft to execute",
                violations: [.missingDraft],
                confidenceSnapshot: nil
            )
        }
        
        var violations: [InvariantViolation] = []
        
        // Check 2: Approval granted
        if !approvalGranted {
            violations.append(.approvalNotGranted)
        }
        
        // Check 3: All enabled side effects acknowledged
        let enabledEffects = sideEffects.filter { $0.isEnabled }
        let unacknowledged = enabledEffects.filter { !$0.isAcknowledged }
        if !unacknowledged.isEmpty {
            violations.append(.sideEffectsNotAcknowledged(count: unacknowledged.count))
        }
        
        // Check 4: Required permissions available
        let missingPermissions = getMissingPermissions(
            sideEffects: enabledEffects,
            permissionState: permissionState
        )
        if !missingPermissions.isEmpty {
            violations.append(.missingPermissions(missingPermissions))
        }
        
        // Check 5: CONFIDENCE INVARIANT - Minimum threshold (0.35)
        if draft.confidence < DraftOutput.minimumExecutionConfidence {
            violations.append(.confidenceTooLow(actual: draft.confidence, required: DraftOutput.minimumExecutionConfidence))
            
            #if DEBUG
            assertionFailure("INVARIANT VIOLATION: Confidence \(draft.confidencePercentage)% is below minimum threshold 35%. Execution path must be blocked.")
            #endif
        }
        
        // Check 6: CONFIDENCE INVARIANT - Low confidence requires explicit confirmation
        if draft.confidence < DraftOutput.directProceedConfidence &&
           draft.confidence >= DraftOutput.minimumExecutionConfidence &&
           !didConfirmLowConfidence {
            violations.append(.lowConfidenceNotConfirmed(confidence: draft.confidence))
        }
        
        // Log invariant check
        #if DEBUG
        if !violations.isEmpty {
            for violation in violations {
                AppLogger.shared.logInvariantCheck(violation.description, passed: false)
            }
        }
        #endif
        
        // Build confidence snapshot for audit trail
        let confidenceSnapshot = ConfidenceSnapshot(
            confidence: draft.confidence,
            threshold: DraftOutput.directProceedConfidence,
            minimumThreshold: DraftOutput.minimumExecutionConfidence,
            modelId: draft.modelMetadata?.modelId ?? "unknown",
            citationsCount: draft.citations.count,
            wasLowConfidenceConfirmed: didConfirmLowConfidence
        )
        
        return ApprovalValidation(
            canProceed: violations.isEmpty,
            reason: violations.isEmpty ? nil : violations.first?.description,
            violations: violations,
            draft: draft,
            confidenceSnapshot: confidenceSnapshot
        )
    }
    
    /// Convenience method with default permission check
    func canExecute(
        draft: Draft?,
        approvalGranted: Bool,
        sideEffects: [SideEffect]
    ) -> Bool {
        let validation = canExecute(
            draft: draft,
            approvalGranted: approvalGranted,
            sideEffects: sideEffects,
            permissionState: PermissionManager.shared.currentState,
            didConfirmLowConfidence: true
        )
        
        #if DEBUG
        if !validation.canProceed {
            assertionFailure("INVARIANT VIOLATION: \(validation.reason ?? "Unknown")")
        }
        #endif
        
        return validation.canProceed
    }
    
    // MARK: - Confidence Checks
    
    /// Check if draft confidence allows proceeding
    /// INVARIANT: Confidence < 0.35 blocks execution entirely
    func checkConfidence(_ draft: Draft) -> ConfidenceCheckResult {
        if draft.confidence < DraftOutput.minimumExecutionConfidence {
            return .blocked(
                confidence: draft.confidence,
                reason: "Confidence \(draft.confidencePercentage)% is below minimum threshold. Add more context or clarify intent."
            )
        } else if draft.confidence < DraftOutput.directProceedConfidence {
            return .requiresConfirmation(
                confidence: draft.confidence,
                reason: "Low confidence (\(draft.confidencePercentage)%). Review carefully and confirm to proceed."
            )
        } else {
            return .canProceed(confidence: draft.confidence)
        }
    }
    
    /// Validate that flow hasn't skipped confidence check
    /// Call this in ApprovalView to ensure proper routing
    func validateConfidenceGate(draft: Draft, didPassThroughFallback: Bool) -> Bool {
        // If confidence is low, must have passed through fallback or draft output confirmation
        if draft.requiresFallbackConfirmation {
            if !didPassThroughFallback {
                #if DEBUG
                assertionFailure("INVARIANT VIOLATION: Low confidence draft reached approval without fallback confirmation")
                #endif
                return false
            }
        }
        
        // If confidence is blocked, should never reach here
        if draft.isBlocked {
            #if DEBUG
            assertionFailure("INVARIANT VIOLATION: Blocked draft reached approval gate")
            #endif
            return false
        }
        
        return true
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
    
    // MARK: - Permission Checking
    
    /// Returns missing permissions required by side effects
    func getMissingPermissions(
        sideEffects: [SideEffect],
        permissionState: PermissionState
    ) -> [SideEffect.PermissionType] {
        var missing: [SideEffect.PermissionType] = []
        
        for effect in sideEffects where effect.isEnabled {
            guard let required = effect.requiresPermission else { continue }
            
            switch required {
            case .calendar:
                if !permissionState.calendar.isGranted {
                    missing.append(.calendar)
                }
            case .mail:
                if !permissionState.mail.isGranted {
                    missing.append(.mail)
                }
            case .reminders:
                if !permissionState.reminders.isGranted {
                    missing.append(.reminders)
                }
            }
        }
        
        return Array(Set(missing)) // Deduplicate
    }
    
    /// Check if any side effect requires a permission
    func requiresPermission(_ sideEffects: [SideEffect]) -> Bool {
        sideEffects.contains { $0.isEnabled && $0.requiresPermission != nil }
    }
}

// MARK: - Approval Validation Result

struct ApprovalValidation {
    let canProceed: Bool
    let reason: String?
    let violations: [InvariantViolation]
    let draft: Draft?
    let confidenceSnapshot: ConfidenceSnapshot?
    
    init(
        canProceed: Bool,
        reason: String?,
        violations: [InvariantViolation],
        draft: Draft? = nil,
        confidenceSnapshot: ConfidenceSnapshot? = nil
    ) {
        self.canProceed = canProceed
        self.reason = reason
        self.violations = violations
        self.draft = draft
        self.confidenceSnapshot = confidenceSnapshot
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

// MARK: - Confidence Check Result

enum ConfidenceCheckResult {
    case canProceed(confidence: Double)
    case requiresConfirmation(confidence: Double, reason: String)
    case blocked(confidence: Double, reason: String)
    
    var isBlocked: Bool {
        if case .blocked = self { return true }
        return false
    }
    
    var requiresConfirmation: Bool {
        if case .requiresConfirmation = self { return true }
        return false
    }
    
    var canProceed: Bool {
        if case .canProceed = self { return true }
        return false
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
