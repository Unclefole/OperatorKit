import Foundation

// ============================================================================
// VERIFICATION ENGINE — PHASE 1 CAPABILITY KERNEL
//
// This is where most agent systems fail.
// Implements the "Scientific Method Engine"
//
// INVARIANT: Verification BEFORE execution (never after)
// INVARIANT: Execution order: INTAKE → CLASSIFY → RISK SCORE → REVERSIBILITY
//            CHECK → PROBES → APPROVAL → EXECUTE
// INVARIANT: Any reversed ordering is a kernel violation
//
// Two Critical Steps:
// 1. Reversibility Check (MANDATORY) — before probes
// 2. Idempotent Probing — READ ONLY, retry-safe, no mutation
// ============================================================================

// MARK: - Verification Engine

/// Scientific Method Engine for pre-execution verification.
/// Never trust. Always verify.
public final class VerificationEngine {
    
    public static let shared = VerificationEngine()
    
    // MARK: - Configuration
    
    private let confidenceThreshold: Double = 0.8  // 80% probes must pass
    private let maxProbeRetries: Int = 2
    private let probeTimeoutSeconds: TimeInterval = 10.0
    
    private init() {}
    
    // MARK: - Public API
    
    /// Run complete verification pipeline for a ToolPlan
    public func verify(plan: ToolPlan) async -> KernelVerificationResult {
        let startTime = Date()
        var phases: [VerificationPhase] = []
        
        // Phase 1: Signature Verification
        let signaturePhase = verifySignature(plan: plan)
        phases.append(signaturePhase)
        
        if !signaturePhase.passed {
            return KernelVerificationResult(
                planId: plan.id,
                overallPassed: false,
                phases: phases,
                confidence: 0.0,
                verifiedAt: startTime,
                duration: Date().timeIntervalSince(startTime)
            )
        }
        
        // Phase 2: Reversibility Classification
        let reversibilityPhase = classifyReversibility(plan: plan)
        phases.append(reversibilityPhase)
        
        // Phase 3: Run Probes
        let probePhase = await runProbes(plan: plan)
        phases.append(probePhase)
        
        // Calculate overall confidence
        let requiredProbes = plan.probes.filter { $0.isRequired }
        let passedRequired = probePhase.probeResults?.filter { result in
            result.passed && plan.probes.first(where: { p in p.id == result.probeId })?.isRequired == true
        }.count ?? 0
        
        let confidence: Double
        if requiredProbes.isEmpty {
            confidence = 1.0
        } else {
            confidence = Double(passedRequired) / Double(requiredProbes.count)
        }
        
        let overallPassed = signaturePhase.passed && 
                           probePhase.passed && 
                           confidence >= confidenceThreshold
        
        return KernelVerificationResult(
            planId: plan.id,
            overallPassed: overallPassed,
            phases: phases,
            confidence: confidence,
            verifiedAt: startTime,
            duration: Date().timeIntervalSince(startTime)
        )
    }
    
    /// Classify reversibility for an action
    public func classifyReversibility(for intentType: IntentType, context: ReversibilityContext) -> ReversibilityAssessment {
        let reversibilityClass: ReversibilityClass
        var reason: String
        var canRollback: Bool
        var rollbackMechanism: String?
        
        switch intentType {
        // Fully Reversible Actions
        case .createDraft:
            reversibilityClass = .reversible
            reason = "Drafts can be deleted without side effects"
            canRollback = true
            rollbackMechanism = "Delete draft"
            
        case .createReminder:
            reversibilityClass = .reversible
            reason = "Reminders can be deleted"
            canRollback = true
            rollbackMechanism = "Delete reminder"
            
        case .readCalendar, .readContacts:
            reversibilityClass = .reversible
            reason = "Read-only operation has no side effects"
            canRollback = true
            rollbackMechanism = nil
            
        // Partially Reversible Actions
        case .sendEmail:
            reversibilityClass = .irreversible
            reason = "Sent emails cannot be recalled"
            canRollback = false
            rollbackMechanism = nil
            
        case .createCalendarEvent:
            reversibilityClass = .partiallyReversible
            reason = "Event can be deleted but attendees may have been notified"
            canRollback = true
            rollbackMechanism = "Delete event (notifications cannot be undone)"
            
        case .updateCalendarEvent:
            reversibilityClass = .partiallyReversible
            reason = "Can revert to previous state but notifications sent"
            canRollback = true
            rollbackMechanism = "Restore previous event data"
            
        // Irreversible Actions
        case .deleteCalendarEvent:
            reversibilityClass = .partiallyReversible
            reason = "Deleted event data may be recoverable within retention window"
            canRollback = context.hasBackup
            rollbackMechanism = context.hasBackup ? "Restore from backup" : nil
            
        case .fileDelete:
            reversibilityClass = .irreversible
            reason = "File deletion may be permanent"
            canRollback = context.hasBackup
            rollbackMechanism = context.hasBackup ? "Restore from backup" : nil
            
        case .fileWrite:
            reversibilityClass = .partiallyReversible
            reason = "Previous file state can be restored if backed up"
            canRollback = context.hasBackup
            rollbackMechanism = context.hasBackup ? "Restore previous version" : nil
            
        case .externalAPICall:
            reversibilityClass = .irreversible
            reason = "External API calls may trigger irreversible side effects"
            canRollback = false
            rollbackMechanism = nil
            
        case .databaseMutation:
            reversibilityClass = context.hasBackup ? .partiallyReversible : .irreversible
            reason = context.hasBackup 
                ? "Database state can be restored from backup"
                : "No backup available for rollback"
            canRollback = context.hasBackup
            rollbackMechanism = context.hasBackup ? "Restore from transaction log or backup" : nil
            
        case .systemConfiguration:
            reversibilityClass = .partiallyReversible
            reason = "Configuration changes can be reverted if previous state is known"
            canRollback = context.hasPreviousState
            rollbackMechanism = context.hasPreviousState ? "Restore previous configuration" : nil
            
        case .unknown:
            reversibilityClass = .irreversible
            reason = "Unknown action type - assuming irreversible for safety"
            canRollback = false
            rollbackMechanism = nil
        }
        
        return ReversibilityAssessment(
            intentType: intentType,
            reversibilityClass: reversibilityClass,
            reason: reason,
            canRollback: canRollback,
            rollbackMechanism: rollbackMechanism,
            cooldownRequired: reversibilityClass == .irreversible,
            recommendedCooldownSeconds: reversibilityClass == .irreversible ? 30 : 0,
            assessedAt: Date()
        )
    }
    
    /// Generate probes for an intent type
    public func generateProbes(for intentType: IntentType, target: String) -> [ProbeDefinition] {
        var probes: [ProbeDefinition] = []
        
        switch intentType {
        case .sendEmail:
            probes.append(ProbeDefinition(
                type: .permissionCheck,
                description: "Check email sending permission",
                target: target,
                isRequired: true
            ))
            probes.append(ProbeDefinition(
                type: .objectExists,
                description: "Validate recipient exists",
                target: target,
                isRequired: true
            ))
            probes.append(ProbeDefinition(
                type: .quotaCheck,
                description: "Check email quota",
                target: target,
                isRequired: false
            ))
            
        case .createCalendarEvent, .updateCalendarEvent, .deleteCalendarEvent:
            probes.append(ProbeDefinition(
                type: .permissionCheck,
                description: "Check calendar access permission",
                target: target,
                isRequired: true
            ))
            probes.append(ProbeDefinition(
                type: .connectionValid,
                description: "Validate calendar store connection",
                target: target,
                isRequired: true
            ))
            if intentType == .updateCalendarEvent || intentType == .deleteCalendarEvent {
                probes.append(ProbeDefinition(
                    type: .objectExists,
                    description: "Verify event exists",
                    target: target,
                    isRequired: true
                ))
            }
            
        case .fileWrite, .fileDelete:
            probes.append(ProbeDefinition(
                type: .permissionCheck,
                description: "Check file system permission",
                target: target,
                isRequired: true
            ))
            probes.append(ProbeDefinition(
                type: .resourceAvailable,
                description: "Check storage space",
                target: target,
                isRequired: false
            ))
            if intentType == .fileDelete {
                probes.append(ProbeDefinition(
                    type: .objectExists,
                    description: "Verify file exists",
                    target: target,
                    isRequired: true
                ))
            }
            
        case .externalAPICall:
            probes.append(ProbeDefinition(
                type: .endpointHealth,
                description: "Check API endpoint health",
                target: target,
                isRequired: true
            ))
            probes.append(ProbeDefinition(
                type: .permissionCheck,
                description: "Validate API credentials",
                target: target,
                isRequired: true
            ))
            probes.append(ProbeDefinition(
                type: .quotaCheck,
                description: "Check API rate limits",
                target: target,
                isRequired: false
            ))
            
        case .databaseMutation:
            probes.append(ProbeDefinition(
                type: .connectionValid,
                description: "Validate database connection",
                target: target,
                isRequired: true
            ))
            probes.append(ProbeDefinition(
                type: .permissionCheck,
                description: "Check database write permission",
                target: target,
                isRequired: true
            ))
            
        case .readCalendar, .readContacts:
            probes.append(ProbeDefinition(
                type: .permissionCheck,
                description: "Check read permission",
                target: target,
                isRequired: true
            ))
            
        case .createDraft, .createReminder:
            probes.append(ProbeDefinition(
                type: .resourceAvailable,
                description: "Check storage space",
                target: target,
                isRequired: false
            ))
            
        case .systemConfiguration:
            probes.append(ProbeDefinition(
                type: .permissionCheck,
                description: "Check configuration permission",
                target: target,
                isRequired: true
            ))
            
        case .unknown:
            // Always probe for unknown types
            probes.append(ProbeDefinition(
                type: .permissionCheck,
                description: "Check general permission",
                target: target,
                isRequired: true
            ))
        }
        
        return probes
    }
    
    // MARK: - Internal Verification Phases
    
    private func verifySignature(plan: ToolPlan) -> VerificationPhase {
        let isValid = plan.verifySignature()
        
        return VerificationPhase(
            name: "Signature Verification",
            passed: isValid,
            details: isValid 
                ? "ToolPlan signature is valid and tamper-free"
                : "SIGNATURE MISMATCH - ToolPlan may have been tampered with",
            duration: 0.001
        )
    }
    
    private func classifyReversibility(plan: ToolPlan) -> VerificationPhase {
        let assessment = classifyReversibility(
            for: plan.intent.type,
            context: ReversibilityContext()
        )
        
        let details = """
        Reversibility: \(assessment.reversibilityClass.rawValue)
        Reason: \(assessment.reason)
        Can Rollback: \(assessment.canRollback)
        \(assessment.cooldownRequired ? "⚠️ Cooldown Required: \(assessment.recommendedCooldownSeconds)s" : "")
        """
        
        return VerificationPhase(
            name: "Reversibility Classification",
            passed: true,  // Classification always passes; it informs approval tier
            details: details,
            duration: 0.001,
            reversibilityAssessment: assessment
        )
    }
    
    private func runProbes(plan: ToolPlan) async -> VerificationPhase {
        var results: [ProbeResult] = []
        let startTime = Date()
        
        for probe in plan.probes {
            let result = await executeProbe(probe)
            results.append(result)
        }
        
        let requiredProbes = plan.probes.filter { $0.isRequired }
        let passedRequired = results.filter { result in
            guard let probe = plan.probes.first(where: { $0.id == result.probeId }) else { return false }
            return probe.isRequired && result.passed
        }
        
        let allRequiredPassed = passedRequired.count == requiredProbes.count
        
        return VerificationPhase(
            name: "Idempotent Probing",
            passed: allRequiredPassed,
            details: "\(passedRequired.count)/\(requiredProbes.count) required probes passed",
            duration: Date().timeIntervalSince(startTime),
            probeResults: results
        )
    }
    
    private func executeProbe(_ probe: ProbeDefinition) async -> ProbeResult {
        // INVARIANT: Probes are READ ONLY, retry-safe, no mutation
        
        let startTime = Date()
        var retryCount = 0
        var lastError: String?
        
        while retryCount <= maxProbeRetries {
            do {
                // Simulate probe execution (in production, these would be real checks)
                let passed = await performProbeCheck(probe)
                
                return ProbeResult(
                    probeId: probe.id,
                    probeType: probe.type,
                    passed: passed,
                    details: passed 
                        ? "Probe passed: \(probe.description)"
                        : "Probe failed: \(probe.description)",
                    retryCount: retryCount,
                    executedAt: startTime,
                    duration: Date().timeIntervalSince(startTime)
                )
            } catch {
                lastError = error.localizedDescription
                retryCount += 1
                
                if retryCount <= maxProbeRetries {
                    // Exponential backoff
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 100_000_000))
                }
            }
        }
        
        return ProbeResult(
            probeId: probe.id,
            probeType: probe.type,
            passed: false,
            details: "Probe failed after \(maxProbeRetries) retries: \(lastError ?? "Unknown error")",
            retryCount: retryCount,
            executedAt: startTime,
            duration: Date().timeIntervalSince(startTime)
        )
    }
    
    private func performProbeCheck(_ probe: ProbeDefinition) async -> Bool {
        // In a real implementation, these would perform actual checks
        // For now, we simulate based on probe type
        
        switch probe.type {
        case .permissionCheck:
            // Check actual permission status
            return await checkPermission(for: probe.target)
            
        case .objectExists:
            // Verify target object exists
            return await checkObjectExists(target: probe.target)
            
        case .endpointHealth:
            // Check endpoint is reachable
            return await checkEndpointHealth(url: probe.target)
            
        case .quotaCheck:
            // Verify quota not exceeded
            return await checkQuota(for: probe.target)
            
        case .connectionValid:
            // Validate connection is active
            return await checkConnection(to: probe.target)
            
        case .resourceAvailable:
            // Check resource availability
            return await checkResourceAvailable(resource: probe.target)
        }
    }
    
    // MARK: - Probe Implementations (Stubs for Phase 1)
    
    private func checkPermission(for target: String) async -> Bool {
        // Stub: In production, check actual iOS permissions
        // For Phase 1, we return true to allow testing
        return true
    }
    
    private func checkObjectExists(target: String) async -> Bool {
        // Stub: In production, verify object exists
        return true
    }
    
    private func checkEndpointHealth(url: String) async -> Bool {
        // Stub: In production, perform health check
        // NO ACTUAL NETWORK CALL - this would check cached status or local proxy
        return true
    }
    
    private func checkQuota(for target: String) async -> Bool {
        // Stub: In production, check quota limits
        return true
    }
    
    private func checkConnection(to target: String) async -> Bool {
        // Stub: In production, validate connection
        return true
    }
    
    private func checkResourceAvailable(resource: String) async -> Bool {
        // Stub: In production, check resource availability
        return true
    }
}

// MARK: - Kernel Verification Result
// Named KernelVerificationResult to avoid collision with StoreKit's VerificationResult<T>

public struct KernelVerificationResult: Codable, Identifiable {
    public let id: UUID
    public let planId: UUID
    public let overallPassed: Bool
    public let phases: [VerificationPhase]
    public let confidence: Double  // 0.0 - 1.0
    public let verifiedAt: Date
    public let duration: TimeInterval
    
    public init(
        id: UUID = UUID(),
        planId: UUID,
        overallPassed: Bool,
        phases: [VerificationPhase],
        confidence: Double,
        verifiedAt: Date,
        duration: TimeInterval
    ) {
        self.id = id
        self.planId = planId
        self.overallPassed = overallPassed
        self.phases = phases
        self.confidence = confidence
        self.verifiedAt = verifiedAt
        self.duration = duration
    }
    
    /// Check if confidence is below threshold (requires escalation)
    public var requiresEscalation: Bool {
        confidence < 0.8
    }
    
    /// Human-readable summary
    public var summary: String {
        let status = overallPassed ? "✅ PASSED" : "❌ FAILED"
        return "\(status) | Confidence: \(Int(confidence * 100))% | Duration: \(String(format: "%.2f", duration))s"
    }
}

// MARK: - Verification Phase

public struct VerificationPhase: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let passed: Bool
    public let details: String
    public let duration: TimeInterval
    public let reversibilityAssessment: ReversibilityAssessment?
    public let probeResults: [ProbeResult]?
    
    public init(
        id: UUID = UUID(),
        name: String,
        passed: Bool,
        details: String,
        duration: TimeInterval,
        reversibilityAssessment: ReversibilityAssessment? = nil,
        probeResults: [ProbeResult]? = nil
    ) {
        self.id = id
        self.name = name
        self.passed = passed
        self.details = details
        self.duration = duration
        self.reversibilityAssessment = reversibilityAssessment
        self.probeResults = probeResults
    }
}

// MARK: - Probe Result

public struct ProbeResult: Codable, Identifiable {
    public let id: UUID
    public let probeId: UUID
    public let probeType: ProbeType
    public let passed: Bool
    public let details: String
    public let retryCount: Int
    public let executedAt: Date
    public let duration: TimeInterval
    
    public init(
        id: UUID = UUID(),
        probeId: UUID,
        probeType: ProbeType,
        passed: Bool,
        details: String,
        retryCount: Int,
        executedAt: Date,
        duration: TimeInterval
    ) {
        self.id = id
        self.probeId = probeId
        self.probeType = probeType
        self.passed = passed
        self.details = details
        self.retryCount = retryCount
        self.executedAt = executedAt
        self.duration = duration
    }
}

// MARK: - Reversibility Assessment

public struct ReversibilityAssessment: Codable {
    public let intentType: IntentType
    public let reversibilityClass: ReversibilityClass
    public let reason: String
    public let canRollback: Bool
    public let rollbackMechanism: String?
    public let cooldownRequired: Bool
    public let recommendedCooldownSeconds: Int
    public let assessedAt: Date
    
    public init(
        intentType: IntentType,
        reversibilityClass: ReversibilityClass,
        reason: String,
        canRollback: Bool,
        rollbackMechanism: String?,
        cooldownRequired: Bool,
        recommendedCooldownSeconds: Int,
        assessedAt: Date = Date()
    ) {
        self.intentType = intentType
        self.reversibilityClass = reversibilityClass
        self.reason = reason
        self.canRollback = canRollback
        self.rollbackMechanism = rollbackMechanism
        self.cooldownRequired = cooldownRequired
        self.recommendedCooldownSeconds = recommendedCooldownSeconds
        self.assessedAt = assessedAt
    }
}

// MARK: - Reversibility Context

public struct ReversibilityContext {
    public let hasBackup: Bool
    public let hasPreviousState: Bool
    public let retentionDays: Int
    
    public init(
        hasBackup: Bool = false,
        hasPreviousState: Bool = false,
        retentionDays: Int = 0
    ) {
        self.hasBackup = hasBackup
        self.hasPreviousState = hasPreviousState
        self.retentionDays = retentionDays
    }
}

// MARK: - Verification Errors

public enum VerificationError: Error, LocalizedError {
    case signatureInvalid
    case probesFailed(count: Int, required: Int)
    case confidenceBelowThreshold(confidence: Double, threshold: Double)
    case cooldownActive(remainingSeconds: Int)
    case executionOrderViolation(expectedPhase: String, actualPhase: String)
    
    public var errorDescription: String? {
        switch self {
        case .signatureInvalid:
            return "ToolPlan signature is invalid - possible tampering detected"
        case .probesFailed(let count, let required):
            return "\(count) of \(required) required probes failed"
        case .confidenceBelowThreshold(let confidence, let threshold):
            return "Confidence (\(Int(confidence * 100))%) below threshold (\(Int(threshold * 100))%)"
        case .cooldownActive(let remaining):
            return "Cooldown active - \(remaining) seconds remaining"
        case .executionOrderViolation(let expected, let actual):
            return "Execution order violation: expected \(expected), got \(actual)"
        }
    }
}
