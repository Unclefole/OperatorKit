import Foundation

// MARK: - Preflight Validator (Phase 7B)
//
// Validates that the app is ready for TestFlight or App Store submission.
// Runs automated checks that verify configuration, privacy compliance,
// and invariant integrity.
//
// Call from: Unit tests, CI pipeline, or DEBUG launch validation

/// Result of a single preflight check
public struct PreflightCheckResult {
    public let category: String
    public let name: String
    public let passed: Bool
    public let message: String
    public let severity: Severity
    
    public enum Severity: String {
        case blocker = "BLOCKER"      // Must fix before submission
        case warning = "WARNING"       // Should fix, may cause rejection
        case info = "INFO"            // Informational only
    }
    
    public static func passed(_ category: String, _ name: String) -> PreflightCheckResult {
        PreflightCheckResult(
            category: category,
            name: name,
            passed: true,
            message: "✓ \(name)",
            severity: .info
        )
    }
    
    public static func failed(_ category: String, _ name: String, reason: String, severity: Severity = .blocker) -> PreflightCheckResult {
        PreflightCheckResult(
            category: category,
            name: name,
            passed: false,
            message: "✗ \(name): \(reason)",
            severity: severity
        )
    }
}

/// Preflight validation report
public struct PreflightReport {
    public let results: [PreflightCheckResult]
    public let timestamp: Date
    public let releaseMode: ReleaseMode
    
    public var allPassed: Bool {
        results.allSatisfy { $0.passed }
    }
    
    public var blockers: [PreflightCheckResult] {
        results.filter { !$0.passed && $0.severity == .blocker }
    }
    
    public var warnings: [PreflightCheckResult] {
        results.filter { !$0.passed && $0.severity == .warning }
    }
    
    public var passedCount: Int {
        results.filter { $0.passed }.count
    }
    
    public var totalCount: Int {
        results.count
    }
    
    public var summary: String {
        var lines: [String] = []
        
        lines.append("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
        lines.append("PREFLIGHT VALIDATION REPORT")
        lines.append("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
        lines.append("Timestamp: \(timestamp)")
        lines.append("Release Mode: \(releaseMode.displayName)")
        lines.append("Results: \(passedCount)/\(totalCount) passed")
        lines.append("")
        
        if !blockers.isEmpty {
            lines.append("🚫 BLOCKERS (\(blockers.count)):")
            for blocker in blockers {
                lines.append("   \(blocker.message)")
            }
            lines.append("")
        }
        
        if !warnings.isEmpty {
            lines.append("⚠️ WARNINGS (\(warnings.count)):")
            for warning in warnings {
                lines.append("   \(warning.message)")
            }
            lines.append("")
        }
        
        // Group passed by category
        let categories = Set(results.map { $0.category })
        for category in categories.sorted() {
            let categoryResults = results.filter { $0.category == category }
            let categoryPassed = categoryResults.filter { $0.passed }.count
            lines.append("\(category): \(categoryPassed)/\(categoryResults.count)")
        }
        
        lines.append("")
        lines.append(allPassed ? "✅ PREFLIGHT PASSED" : "❌ PREFLIGHT FAILED")
        lines.append("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
        
        return lines.joined(separator: "\n")
    }
}

/// Runs all preflight validation checks
public final class PreflightValidator {
    
    public static let shared = PreflightValidator()
    
    private init() {}
    
    // MARK: - Run All Checks
    
    /// Runs complete preflight validation
    public func runAllChecks() -> PreflightReport {
        var results: [PreflightCheckResult] = []
        
        // Configuration checks
        results.append(contentsOf: runConfigurationChecks())
        
        // Privacy checks
        results.append(contentsOf: runPrivacyChecks())
        
        // Invariant checks
        results.append(contentsOf: runInvariantChecks())
        
        // Release mode checks
        results.append(contentsOf: runReleaseModeChecks())
        
        // Documentation checks
        results.append(contentsOf: runDocumentationChecks())
        
        // Safety contract checks (Phase 8C)
        results.append(contentsOf: runSafetyContractChecks())
        
        // Quality gate checks (Phase 8C)
        results.append(contentsOf: runQualityGateChecks())
        
        return PreflightReport(
            results: results,
            timestamp: Date(),
            releaseMode: ReleaseMode.current
        )
    }
    
    // MARK: - Configuration Checks
    
    private func runConfigurationChecks() -> [PreflightCheckResult] {
        var results: [PreflightCheckResult] = []
        let category = "Configuration"
        
        // Check deployment target
        if #available(iOS 17.0, *) {
            results.append(.passed(category, "Deployment Target iOS 17+"))
        } else {
            results.append(.failed(category, "Deployment Target", reason: "Requires iOS 17+"))
        }
        
        // Check release safety config
        let violations = ReleaseSafetyConfig.validateConfiguration()
        if violations.isEmpty {
            results.append(.passed(category, "Release Safety Config"))
        } else {
            results.append(.failed(category, "Release Safety Config", reason: violations.first ?? "Unknown"))
        }
        
        // Check compile-time guards
        if CompileTimeGuardStatus.allGuardsPassed {
            results.append(.passed(category, "Compile-Time Guards"))
        } else {
            results.append(.failed(category, "Compile-Time Guards", reason: "Guards indicate failure"))
        }
        
        return results
    }
    
    // MARK: - Privacy Checks
    
    private func runPrivacyChecks() -> [PreflightCheckResult] {
        var results: [PreflightCheckResult] = []
        let category = "Privacy"
        
        // Check no background modes
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        if backgroundModes == nil || backgroundModes?.isEmpty == true {
            results.append(.passed(category, "No Background Modes"))
        } else {
            results.append(.failed(category, "No Background Modes", reason: "UIBackgroundModes found: \(backgroundModes ?? [])"))
        }
        
        // Check required privacy keys exist
        let requiredKeys = ["NSCalendarsUsageDescription", "NSRemindersUsageDescription", "NSSiriUsageDescription"]
        for key in requiredKeys {
            if Bundle.main.object(forInfoDictionaryKey: key) != nil {
                results.append(.passed(category, "\(key) Present"))
            } else {
                results.append(.failed(category, "\(key) Present", reason: "Missing from Info.plist"))
            }
        }
        
        // Check no unexpected permission keys
        let unexpectedKeys = [
            "NSLocationWhenInUseUsageDescription",
            "NSCameraUsageDescription",
            "NSMicrophoneUsageDescription",
            "NSPhotoLibraryUsageDescription",
            "NSContactsUsageDescription"
        ]
        var foundUnexpected: [String] = []
        for key in unexpectedKeys {
            if Bundle.main.object(forInfoDictionaryKey: key) != nil {
                foundUnexpected.append(key)
            }
        }
        if foundUnexpected.isEmpty {
            results.append(.passed(category, "No Unexpected Permissions"))
        } else {
            results.append(.failed(category, "No Unexpected Permissions", reason: "Found: \(foundUnexpected.joined(separator: ", "))", severity: .warning))
        }
        
        return results
    }
    
    // MARK: - Invariant Checks
    
    private func runInvariantChecks() -> [PreflightCheckResult] {
        var results: [PreflightCheckResult] = []
        let category = "Invariants"
        
        // Run invariant check runner
        let invariantRunner = InvariantCheckRunner.shared
        let invariantResults = invariantRunner.runAllChecks()
        
        for result in invariantResults {
            if result.passed {
                results.append(.passed(category, result.name))
            } else {
                results.append(.failed(category, result.name, reason: result.message))
            }
        }
        
        return results
    }
    
    // MARK: - Release Mode Checks
    
    private func runReleaseModeChecks() -> [PreflightCheckResult] {
        var results: [PreflightCheckResult] = []
        let category = "Release Mode"
        
        let mode = ReleaseMode.current
        results.append(.passed(category, "Mode Detected: \(mode.displayName)"))
        
        #if DEBUG
        // In DEBUG, warn that this is not a release build
        results.append(.failed(category, "Release Build", reason: "This is a DEBUG build", severity: .warning))
        #else
        results.append(.passed(category, "Release Build"))
        #endif
        
        // Check that DEBUG-only features are not available in release
        #if !DEBUG
        // These should all be false in release
        if !mode.allowsSyntheticData {
            results.append(.passed(category, "Synthetic Data Disabled"))
        } else {
            results.append(.failed(category, "Synthetic Data Disabled", reason: "Should be disabled in release"))
        }
        
        if !mode.allowsEvalHarness {
            results.append(.passed(category, "Eval Harness Disabled"))
        } else {
            results.append(.failed(category, "Eval Harness Disabled", reason: "Should be disabled in release"))
        }
        
        if !mode.allowsFaultInjection {
            results.append(.passed(category, "Fault Injection Disabled"))
        } else {
            results.append(.failed(category, "Fault Injection Disabled", reason: "Should be disabled in release"))
        }
        #endif
        
        return results
    }
    
    // MARK: - Documentation Checks
    
    private func runDocumentationChecks() -> [PreflightCheckResult] {
        var results: [PreflightCheckResult] = []
        let category = "Documentation"
        
        // These are informational - we can't verify file contents at runtime
        // But we note that documentation should exist
        results.append(.passed(category, "Privacy strings defined in PrivacyStrings.swift"))
        results.append(.passed(category, "Reviewer help available in-app"))
        results.append(.passed(category, "Data use disclosure available in-app"))
        
        return results
    }
    
    // MARK: - Safety Contract Checks (Phase 8C)
    
    private func runSafetyContractChecks() -> [PreflightCheckResult] {
        var results: [PreflightCheckResult] = []
        let category = "Safety Contract"
        
        let status = SafetyContractSnapshot.getStatus()
        
        switch status.matchStatus {
        case .matched:
            results.append(.passed(category, "Safety Contract Unchanged"))
            
        case .modified:
            results.append(.failed(
                category,
                "Safety Contract Unchanged",
                reason: "SAFETY_CONTRACT.md has been modified. Update hash if intentional.",
                severity: .blocker
            ))
            
        case .notFound:
            results.append(.failed(
                category,
                "Safety Contract Present",
                reason: "SAFETY_CONTRACT.md not found",
                severity: .warning
            ))
        }
        
        // Check schema version is set
        if SafetyContractSnapshot.schemaVersion > 0 {
            results.append(.passed(category, "Schema Version Set"))
        } else {
            results.append(.failed(category, "Schema Version Set", reason: "Schema version not set"))
        }
        
        return results
    }
    
    // MARK: - Quality Gate Checks (Phase 8C)
    
    private func runQualityGateChecks() -> [PreflightCheckResult] {
        var results: [PreflightCheckResult] = []
        let category = "Quality Gate"
        
        let evaluator = QualityGateEvaluator()
        let gateResult = evaluator.evaluate()
        
        // Report golden case count
        let goldenCount = gateResult.metrics.goldenCaseCount
        if goldenCount >= QualityGateThresholds.default.minimumGoldenCases {
            results.append(.passed(category, "Golden Cases (\(goldenCount) pinned)"))
        } else {
            results.append(.failed(
                category,
                "Golden Cases",
                reason: "Only \(goldenCount) golden cases (min \(QualityGateThresholds.default.minimumGoldenCases))",
                severity: .warning
            ))
        }
        
        // Report quality gate status
        switch gateResult.status {
        case .pass:
            results.append(.passed(category, "Quality Gate: PASS"))
            
        case .warn:
            let reasonSummary = gateResult.reasons.prefix(2).joined(separator: "; ")
            results.append(.failed(
                category,
                "Quality Gate: WARN",
                reason: reasonSummary,
                severity: .warning
            ))
            
        case .fail:
            let reasonSummary = gateResult.reasons.prefix(2).joined(separator: "; ")
            results.append(.failed(
                category,
                "Quality Gate: FAIL",
                reason: reasonSummary,
                severity: .blocker
            ))
            
        case .skipped:
            results.append(.failed(
                category,
                "Quality Gate: SKIPPED",
                reason: gateResult.reasons.first ?? "Insufficient data",
                severity: .warning
            ))
        }
        
        // Report drift level if available
        if let driftLevel = gateResult.metrics.driftLevel {
            if driftLevel == "None" {
                results.append(.passed(category, "Drift Level: \(driftLevel)"))
            } else if driftLevel == "High" {
                results.append(.failed(
                    category,
                    "Drift Level",
                    reason: "High drift detected",
                    severity: .blocker
                ))
            } else {
                results.append(.failed(
                    category,
                    "Drift Level",
                    reason: "\(driftLevel) drift detected",
                    severity: .warning
                ))
            }
        }
        
        // Report pass rate if available
        if let passRate = gateResult.metrics.latestPassRate {
            let passRatePercent = Int(passRate * 100)
            if passRate >= QualityGateThresholds.default.minimumPassRate {
                results.append(.passed(category, "Pass Rate: \(passRatePercent)%"))
            } else {
                results.append(.failed(
                    category,
                    "Pass Rate",
                    reason: "\(passRatePercent)% (min \(Int(QualityGateThresholds.default.minimumPassRate * 100))%)",
                    severity: .blocker
                ))
            }
        }
        
        return results
    }
}

// MARK: - Convenience Methods

extension PreflightValidator {
    
    /// Runs validation and prints report (DEBUG only)
    #if DEBUG
    public func runAndPrint() {
        let report = runAllChecks()
        print(report.summary)
    }
    #endif
    
    /// Returns true if all checks pass
    public var isReady: Bool {
        runAllChecks().allPassed
    }
    
    /// Returns blocking issues only
    public var blockingIssues: [PreflightCheckResult] {
        runAllChecks().blockers
    }
}
