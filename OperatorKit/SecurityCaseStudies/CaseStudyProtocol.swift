import Foundation

// MARK: - Security Case Study Protocol
// ============================================================================
// This protocol defines the contract for adversarial security case studies.
// Case studies are test-only constructs that verify security invariants
// through controlled adversarial scenarios.
//
// IMPORTANT: Case studies are DISABLED in production builds.
// ============================================================================

/// Represents the outcome of a security case study execution.
public enum CaseStudyOutcome: String, Codable {
    /// The security claim held under adversarial conditions.
    case passed = "PASSED"
    
    /// The security claim was violated - requires investigation.
    case failed = "FAILED"
    
    /// The case study could not complete execution.
    case inconclusive = "INCONCLUSIVE"
    
    /// The case study was skipped (e.g., missing prerequisites).
    case skipped = "SKIPPED"
}

/// Severity classification for security case studies.
public enum CaseStudySeverity: String, Codable {
    /// Critical security property - failure is a ship blocker.
    case critical = "CRITICAL"
    
    /// High severity - should be addressed before release.
    case high = "HIGH"
    
    /// Medium severity - should be documented if not addressed.
    case medium = "MEDIUM"
    
    /// Low severity - informational finding.
    case low = "LOW"
}

/// Category of security property being tested.
public enum CaseStudyCategory: String, Codable {
    /// Network isolation and air-gap verification.
    case networkIsolation = "NETWORK_ISOLATION"
    
    /// Memory safety and data persistence.
    case memoryHygiene = "MEMORY_HYGIENE"
    
    /// Data leakage through metadata or exports.
    case dataLeakage = "DATA_LEAKAGE"
    
    /// OS-level side effects and system calls.
    case osSideEffects = "OS_SIDE_EFFECTS"
    
    /// Entitlement and capability verification.
    case entitlements = "ENTITLEMENTS"
    
    /// Input validation and sanitization.
    case inputValidation = "INPUT_VALIDATION"
    
    /// Binary/runtime integrity violations.
    case integrityViolation = "INTEGRITY_VIOLATION"
    
    /// Access control and approval bypass attempts.
    case accessControl = "ACCESS_CONTROL"
}

/// Result of a single case study execution.
public struct CaseStudyResult: Codable {
    /// Unique identifier of the case study.
    public let caseStudyId: String
    
    /// Outcome of the execution.
    public let outcome: CaseStudyOutcome
    
    /// Detailed findings from execution.
    public let findings: [String]
    
    /// Duration of execution in seconds.
    public let durationSeconds: Double
    
    /// Timestamp of execution.
    public let executedAt: Date
    
    /// Environment metadata.
    public let environment: [String: String]
    
    /// Recommendations for remediation if failed.
    public let recommendations: [String]
    
    public init(
        caseStudyId: String,
        outcome: CaseStudyOutcome,
        findings: [String],
        durationSeconds: Double,
        executedAt: Date = Date(),
        environment: [String: String] = [:]
    ) {
        self.caseStudyId = caseStudyId
        self.outcome = outcome
        self.findings = findings
        self.durationSeconds = durationSeconds
        self.executedAt = executedAt
        self.environment = environment
        self.recommendations = []
    }
    
    /// Extended initializer with evidence and recommendations.
    public init(
        caseStudyId: String,
        outcome: CaseStudyOutcome,
        findings: [String],
        evidence: [String: Any],
        recommendations: [String],
        executedAt: Date = Date()
    ) {
        self.caseStudyId = caseStudyId
        self.outcome = outcome
        self.findings = findings
        self.durationSeconds = 0  // Calculated externally if needed
        self.executedAt = executedAt
        self.environment = evidence.compactMapValues { String(describing: $0) }
        self.recommendations = recommendations
    }
}

/// Protocol defining a security case study.
///
/// Implementers define adversarial test scenarios that verify
/// OperatorKit's security claims under controlled conditions.
public protocol CaseStudyProtocol {
    
    // MARK: - Identity
    
    /// Unique identifier for this case study.
    /// Format: "CS-[CATEGORY]-[NUMBER]" (e.g., "CS-NET-001")
    var id: String { get }
    
    /// Human-readable name.
    var name: String { get }
    
    /// Version of this case study implementation.
    var version: String { get }
    
    // MARK: - Classification
    
    /// Category of security property tested.
    var category: CaseStudyCategory { get }
    
    /// Severity if this case study fails.
    var severity: CaseStudySeverity { get }
    
    // MARK: - Documentation
    
    /// The specific security claim being tested.
    /// Example: "OperatorKit makes zero network connections during operation."
    var claimTested: String { get }
    
    /// The adversarial hypothesis being evaluated.
    /// Example: "Hidden OS-level network calls may occur via system frameworks."
    var hypothesis: String { get }
    
    /// Ordered list of steps this case study performs.
    var executionSteps: [String] { get }
    
    /// What result indicates the claim holds.
    var expectedResult: String { get }
    
    /// How the result is validated.
    var validationMethod: String { get }
    
    // MARK: - Prerequisites
    
    /// Conditions that must be true before execution.
    var prerequisites: [String] { get }
    
    /// Check if prerequisites are satisfied.
    func checkPrerequisites() -> Bool
    
    // MARK: - Execution
    
    /// Execute the case study and return results.
    /// - Returns: The result of the case study execution.
    func execute() -> CaseStudyResult
}

// MARK: - Default Implementations

public extension CaseStudyProtocol {
    
    var version: String { "1.0" }
    
    var prerequisites: [String] { [] }
    
    func checkPrerequisites() -> Bool { true }
    
    /// Generate environment metadata for result logging.
    func captureEnvironment() -> [String: String] {
        var env: [String: String] = [:]
        
        #if DEBUG
        env["buildConfiguration"] = "DEBUG"
        #else
        env["buildConfiguration"] = "RELEASE"
        #endif
        
        #if targetEnvironment(simulator)
        env["environment"] = "SIMULATOR"
        #else
        env["environment"] = "DEVICE"
        #endif
        
        env["osVersion"] = ProcessInfo.processInfo.operatingSystemVersionString
        env["processName"] = ProcessInfo.processInfo.processName
        
        return env
    }
}
