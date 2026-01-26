import Foundation

// ============================================================================
// REGRESSION FIREWALL RUNNER (Phase 13D)
//
// Executes all firewall rules locally and produces pass/fail evidence.
// Pure, deterministic, no side effects.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking
// ❌ No file writes
// ❌ No state mutation
// ❌ No telemetry
// ✅ Pure verification only
// ✅ Ephemeral memory only
// ✅ Reproducible results
// ============================================================================

// MARK: - Regression Firewall Runner

public final class RegressionFirewallRunner {
    
    // MARK: - Singleton
    
    public static let shared = RegressionFirewallRunner()
    
    private init() {}
    
    // MARK: - Verification
    
    /// Run all firewall rules and return results
    /// This is a pure function with no side effects
    public func runAllRules() -> FirewallVerificationReport {
        guard RegressionFirewallFeatureFlag.isEnabled else {
            return FirewallVerificationReport(
                status: .disabled,
                results: [],
                verifiedAt: Date(),
                ruleCount: 0,
                passedCount: 0,
                failedCount: 0
            )
        }
        
        let startTime = Date()
        var results: [RuleResult] = []
        
        // Execute each rule
        for rule in RegressionFirewallRules.all {
            let verification = rule.verify()
            
            results.append(RuleResult(
                ruleId: rule.id,
                ruleName: rule.name,
                category: rule.category,
                severity: rule.severity,
                passed: verification.passed,
                evidence: verification.evidence,
                verifiedAt: verification.verifiedAt
            ))
        }
        
        // Calculate summary
        let passedCount = results.filter { $0.passed }.count
        let failedCount = results.filter { !$0.passed }.count
        let status: FirewallStatus = failedCount > 0 ? .failed : .passed
        
        return FirewallVerificationReport(
            status: status,
            results: results,
            verifiedAt: startTime,
            ruleCount: results.count,
            passedCount: passedCount,
            failedCount: failedCount
        )
    }
    
    /// Run rules in a specific category
    public func runRules(in category: RuleCategory) -> [RuleResult] {
        guard RegressionFirewallFeatureFlag.isEnabled else {
            return []
        }
        
        let rules = RegressionFirewallRules.rules(in: category)
        
        return rules.map { rule in
            let verification = rule.verify()
            return RuleResult(
                ruleId: rule.id,
                ruleName: rule.name,
                category: rule.category,
                severity: rule.severity,
                passed: verification.passed,
                evidence: verification.evidence,
                verifiedAt: verification.verifiedAt
            )
        }
    }
    
    /// Verify a single rule by ID
    public func verifyRule(id: String) -> RuleResult? {
        guard RegressionFirewallFeatureFlag.isEnabled else {
            return nil
        }
        
        guard let rule = RegressionFirewallRules.all.first(where: { $0.id == id }) else {
            return nil
        }
        
        let verification = rule.verify()
        
        return RuleResult(
            ruleId: rule.id,
            ruleName: rule.name,
            category: rule.category,
            severity: rule.severity,
            passed: verification.passed,
            evidence: verification.evidence,
            verifiedAt: verification.verifiedAt
        )
    }
    
    // MARK: - Quick Status
    
    /// Get quick pass/fail status without full report
    public func quickStatus() -> FirewallStatus {
        guard RegressionFirewallFeatureFlag.isEnabled else {
            return .disabled
        }
        
        for rule in RegressionFirewallRules.all {
            let result = rule.verify()
            if !result.passed {
                return .failed
            }
        }
        
        return .passed
    }
}

// MARK: - Firewall Status

public enum FirewallStatus: String {
    case passed = "PASSED"
    case failed = "FAILED"
    case disabled = "DISABLED"
    
    public var displayColor: String {
        switch self {
        case .passed: return "green"
        case .failed: return "red"
        case .disabled: return "gray"
        }
    }
    
    public var icon: String {
        switch self {
        case .passed: return "checkmark.shield.fill"
        case .failed: return "xmark.shield.fill"
        case .disabled: return "shield.slash"
        }
    }
}

// MARK: - Rule Result

public struct RuleResult: Identifiable {
    public let id: String
    public let ruleId: String
    public let ruleName: String
    public let category: RuleCategory
    public let severity: RuleSeverity
    public let passed: Bool
    public let evidence: String
    public let verifiedAt: Date
    
    public init(
        ruleId: String,
        ruleName: String,
        category: RuleCategory,
        severity: RuleSeverity,
        passed: Bool,
        evidence: String,
        verifiedAt: Date
    ) {
        self.id = ruleId
        self.ruleId = ruleId
        self.ruleName = ruleName
        self.category = category
        self.severity = severity
        self.passed = passed
        self.evidence = evidence
        self.verifiedAt = verifiedAt
    }
}

// MARK: - Verification Report

public struct FirewallVerificationReport {
    public let status: FirewallStatus
    public let results: [RuleResult]
    public let verifiedAt: Date
    public let ruleCount: Int
    public let passedCount: Int
    public let failedCount: Int
    
    public var failedRules: [RuleResult] {
        results.filter { !$0.passed }
    }
    
    public var criticalFailures: [RuleResult] {
        failedRules.filter { $0.severity == .critical }
    }
    
    public var formattedVerifiedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: verifiedAt)
    }
    
    public var summaryText: String {
        switch status {
        case .passed:
            return "All \(ruleCount) rules passed"
        case .failed:
            return "\(failedCount) of \(ruleCount) rules failed"
        case .disabled:
            return "Firewall verification disabled"
        }
    }
}
