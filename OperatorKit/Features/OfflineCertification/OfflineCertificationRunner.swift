import Foundation

// ============================================================================
// OFFLINE CERTIFICATION RUNNER (Phase 13I)
//
// Executes certification checks locally.
// No mutations, no retries, no auto-fix.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No mutations
// ❌ No retries
// ❌ No auto-fix
// ❌ No networking
// ❌ No enforcement
// ✅ Read-only verification
// ✅ Deterministic
// ✅ User-initiated only
// ============================================================================

public final class OfflineCertificationRunner {
    
    // MARK: - Singleton
    
    public static let shared = OfflineCertificationRunner()
    
    private init() {}
    
    // MARK: - Run All Checks
    
    /// Run all certification checks
    /// This is user-initiated only, never automatic
    public func runAllChecks() -> OfflineCertificationReport {
        guard OfflineCertificationFeatureFlag.isEnabled else {
            return OfflineCertificationReport(
                status: .disabled,
                checkResults: [],
                timestamp: dayRoundedNow()
            )
        }
        
        var results: [CheckResultEntry] = []
        
        for check in OfflineCertificationChecks.all {
            let result = check.verify()
            results.append(CheckResultEntry(
                checkId: check.id,
                checkName: check.name,
                category: check.category.rawValue,
                severity: check.severity.rawValue,
                passed: result.passed,
                evidence: result.evidence
            ))
        }
        
        let passedCount = results.filter { $0.passed }.count
        let failedCount = results.filter { !$0.passed }.count
        
        let status: OfflineCertificationStatus
        if failedCount == 0 {
            status = .certified
        } else if results.filter({ !$0.passed && $0.severity == "critical" }).isEmpty {
            status = .partiallyVerified
        } else {
            status = .failed
        }
        
        return OfflineCertificationReport(
            status: status,
            checkResults: results,
            timestamp: dayRoundedNow()
        )
    }
    
    // MARK: - Run Specific Category
    
    /// Run checks for a specific category
    public func runChecks(in category: OfflineCertificationCategory) -> OfflineCertificationReport {
        guard OfflineCertificationFeatureFlag.isEnabled else {
            return OfflineCertificationReport(
                status: .disabled,
                checkResults: [],
                timestamp: dayRoundedNow()
            )
        }
        
        let categoryChecks = OfflineCertificationChecks.all.filter { $0.category == category }
        var results: [CheckResultEntry] = []
        
        for check in categoryChecks {
            let result = check.verify()
            results.append(CheckResultEntry(
                checkId: check.id,
                checkName: check.name,
                category: check.category.rawValue,
                severity: check.severity.rawValue,
                passed: result.passed,
                evidence: result.evidence
            ))
        }
        
        let passedCount = results.filter { $0.passed }.count
        let failedCount = results.filter { !$0.passed }.count
        
        let status: OfflineCertificationStatus = failedCount == 0 ? .certified : .failed
        
        return OfflineCertificationReport(
            status: status,
            checkResults: results,
            timestamp: dayRoundedNow()
        )
    }
    
    // MARK: - Quick Status
    
    /// Get quick certification status without full report
    public func quickStatus() -> OfflineCertificationStatus {
        guard OfflineCertificationFeatureFlag.isEnabled else {
            return .disabled
        }
        
        for check in OfflineCertificationChecks.all {
            if check.severity == .critical {
                let result = check.verify()
                if !result.passed {
                    return .failed
                }
            }
        }
        
        return .certified
    }
    
    // MARK: - Helpers
    
    private func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}

// MARK: - Certification Status

public enum OfflineCertificationStatus: String, Codable {
    case certified = "CERTIFIED"
    case partiallyVerified = "PARTIALLY_VERIFIED"
    case failed = "FAILED"
    case disabled = "DISABLED"
    
    public var displayName: String {
        switch self {
        case .certified: return "Offline Verified"
        case .partiallyVerified: return "Partially Verified"
        case .failed: return "Verification Failed"
        case .disabled: return "Disabled"
        }
    }
    
    public var icon: String {
        switch self {
        case .certified: return "checkmark.seal.fill"
        case .partiallyVerified: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.seal.fill"
        case .disabled: return "circle.slash"
        }
    }
}

// MARK: - Check Result Entry

public struct CheckResultEntry: Codable, Equatable {
    public let checkId: String
    public let checkName: String
    public let category: String
    public let severity: String
    public let passed: Bool
    public let evidence: String
}

// MARK: - Certification Report

public struct OfflineCertificationReport: Codable, Equatable {
    public let status: OfflineCertificationStatus
    public let checkResults: [CheckResultEntry]
    public let timestamp: String
    
    public var ruleCount: Int { checkResults.count }
    public var passedCount: Int { checkResults.filter { $0.passed }.count }
    public var failedCount: Int { checkResults.filter { !$0.passed }.count }
    
    public var criticalFailures: [CheckResultEntry] {
        checkResults.filter { !$0.passed && $0.severity == "critical" }
    }
}
