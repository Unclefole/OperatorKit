import Foundation

// ============================================================================
// LAUNCH CHECKLIST VALIDATOR (Phase 10Q)
//
// Advisory validator for launch readiness.
// Does NOT block app usage. Used for internal readiness only.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No blocking behavior
// ❌ No runtime enforcement
// ❌ No networking
// ✅ Pure and deterministic
// ✅ Advisory only
// ✅ Read-only checks
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Launch Check Item

public struct LaunchCheckItem: Identifiable, Codable {
    public let id: String
    public let category: LaunchCheckCategory
    public let displayName: String
    public let checkDescription: String
    public var status: LaunchCheckStatus
    public var details: String?
    
    public init(
        id: String,
        category: LaunchCheckCategory,
        displayName: String,
        checkDescription: String,
        status: LaunchCheckStatus = .pending,
        details: String? = nil
    ) {
        self.id = id
        self.category = category
        self.displayName = displayName
        self.checkDescription = checkDescription
        self.status = status
        self.details = details
    }
}

// MARK: - Launch Check Category

public enum LaunchCheckCategory: String, Codable, CaseIterable {
    case documentation = "documentation"
    case safety = "safety"
    case quality = "quality"
    case storeListing = "store_listing"
    case submission = "submission"
    
    public var displayName: String {
        switch self {
        case .documentation: return "Documentation"
        case .safety: return "Safety"
        case .quality: return "Quality"
        case .storeListing: return "Store Listing"
        case .submission: return "Submission"
        }
    }
    
    public var icon: String {
        switch self {
        case .documentation: return "doc.text"
        case .safety: return "shield.checkered"
        case .quality: return "checkmark.seal"
        case .storeListing: return "storefront"
        case .submission: return "paperplane"
        }
    }
}

// MARK: - Launch Check Status

public enum LaunchCheckStatus: String, Codable {
    case pending = "pending"
    case passing = "passing"
    case warning = "warning"
    case failing = "failing"
    
    public var icon: String {
        switch self {
        case .pending: return "circle"
        case .passing: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failing: return "xmark.circle.fill"
        }
    }
    
    public var color: String {
        switch self {
        case .pending: return "gray"
        case .passing: return "green"
        case .warning: return "orange"
        case .failing: return "red"
        }
    }
}

// MARK: - Launch Checklist Result

public struct LaunchChecklistResult: Codable {
    public let checkItems: [LaunchCheckItem]
    public let overallStatus: LaunchCheckStatus
    public let passCount: Int
    public let warnCount: Int
    public let failCount: Int
    public let checkedAt: String
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public var isLaunchReady: Bool {
        overallStatus == .passing || overallStatus == .warning
    }
}

// MARK: - Launch Checklist Validator

@MainActor
public final class LaunchChecklistValidator {
    
    // MARK: - Singleton
    
    public static let shared = LaunchChecklistValidator()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Validation
    
    /// Validates all launch checks (pure, deterministic)
    public func validate() -> LaunchChecklistResult {
        var items: [LaunchCheckItem] = []
        
        // Documentation checks
        items.append(contentsOf: checkDocumentation())
        
        // Safety checks
        items.append(contentsOf: checkSafety())
        
        // Quality checks
        items.append(contentsOf: checkQuality())
        
        // Store listing checks
        items.append(contentsOf: checkStoreListing())
        
        // Submission checks
        items.append(contentsOf: checkSubmission())
        
        // Calculate overall status
        let passCount = items.filter { $0.status == .passing }.count
        let warnCount = items.filter { $0.status == .warning }.count
        let failCount = items.filter { $0.status == .failing }.count
        
        let overallStatus: LaunchCheckStatus
        if failCount > 0 {
            overallStatus = .failing
        } else if warnCount > 0 {
            overallStatus = .warning
        } else {
            overallStatus = .passing
        }
        
        return LaunchChecklistResult(
            checkItems: items,
            overallStatus: overallStatus,
            passCount: passCount,
            warnCount: warnCount,
            failCount: failCount,
            checkedAt: dayRoundedNow(),
            schemaVersion: LaunchChecklistResult.currentSchemaVersion
        )
    }
    
    // MARK: - Documentation Checks
    
    private func checkDocumentation() -> [LaunchCheckItem] {
        var items: [LaunchCheckItem] = []
        
        // Check required docs exist
        let missingDocs = DocIntegrity.requiredDocs.filter { !DocIntegrity.docExists($0) }
        
        items.append(LaunchCheckItem(
            id: "docs-present",
            category: .documentation,
            displayName: "Required Docs Present",
            checkDescription: "All required documentation files exist",
            status: missingDocs.isEmpty ? .passing : .failing,
            details: missingDocs.isEmpty ? nil : "Missing: \(missingDocs.map { $0.name }.joined(separator: ", "))"
        ))
        
        return items
    }
    
    // MARK: - Safety Checks
    
    private func checkSafety() -> [LaunchCheckItem] {
        var items: [LaunchCheckItem] = []
        
        // Safety contract hash
        let contractValid = SafetyContractValidator.shared.isValid
        items.append(LaunchCheckItem(
            id: "safety-contract",
            category: .safety,
            displayName: "Safety Contract Valid",
            checkDescription: "Safety contract hash matches expected",
            status: contractValid ? .passing : .warning,
            details: contractValid ? nil : "Hash mismatch detected"
        ))
        
        // Known limitations validation
        let limitationViolations = KnownLimitations.validateNoBannedWords() +
                                   KnownLimitations.validateFactualOnly()
        items.append(LaunchCheckItem(
            id: "limitations-valid",
            category: .safety,
            displayName: "Limitations Copy Valid",
            checkDescription: "Known limitations contain no banned words",
            status: limitationViolations.isEmpty ? .passing : .failing,
            details: limitationViolations.isEmpty ? nil : limitationViolations.first
        ))
        
        // First week tips validation
        let tipViolations = FirstWeekTips.validateNoBannedWords()
        items.append(LaunchCheckItem(
            id: "tips-valid",
            category: .safety,
            displayName: "First Week Tips Valid",
            checkDescription: "First week tips contain no banned words",
            status: tipViolations.isEmpty ? .passing : .failing,
            details: tipViolations.isEmpty ? nil : tipViolations.first
        ))
        
        return items
    }
    
    // MARK: - Quality Checks
    
    private func checkQuality() -> [LaunchCheckItem] {
        var items: [LaunchCheckItem] = []
        
        // Quality gate status
        if let gate = QualityGate.shared.currentResult {
            let status: LaunchCheckStatus
            switch gate.status {
            case .pass: status = .passing
            case .warn: status = .warning
            default: status = .failing
            }
            
            items.append(LaunchCheckItem(
                id: "quality-gate",
                category: .quality,
                displayName: "Quality Gate",
                checkDescription: "Quality gate evaluation status",
                status: status,
                details: "Coverage: \(gate.coverageScore ?? 0)%"
            ))
        } else {
            items.append(LaunchCheckItem(
                id: "quality-gate",
                category: .quality,
                displayName: "Quality Gate",
                checkDescription: "Quality gate evaluation status",
                status: .warning,
                details: "Not evaluated"
            ))
        }
        
        return items
    }
    
    // MARK: - Store Listing Checks
    
    private func checkStoreListing() -> [LaunchCheckItem] {
        var items: [LaunchCheckItem] = []
        
        // Store listing hash
        let hashResult = StoreListingSnapshot.verifyHash()
        items.append(LaunchCheckItem(
            id: "store-listing-locked",
            category: .storeListing,
            displayName: "Store Listing Locked",
            checkDescription: "Store listing copy matches expected hash",
            status: hashResult.isValid ? .passing : .warning,
            details: hashResult.isValid ? nil : "Copy may have changed"
        ))
        
        return items
    }
    
    // MARK: - Submission Checks
    
    private func checkSubmission() -> [LaunchCheckItem] {
        var items: [LaunchCheckItem] = []
        
        // Risk scanner
        let report = AppReviewRiskScanner.scanSubmissionCopy()
        
        let riskStatus: LaunchCheckStatus
        switch report.status {
        case .pass: riskStatus = .passing
        case .warn: riskStatus = .warning
        case .fail: riskStatus = .failing
        }
        
        items.append(LaunchCheckItem(
            id: "risk-scanner",
            category: .submission,
            displayName: "Risk Scanner",
            checkDescription: "App Review risk scanner status",
            status: riskStatus,
            details: report.findings.isEmpty ? nil : "\(report.findings.count) finding(s)"
        ))
        
        return items
    }
    
    // MARK: - Helpers
    
    private func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
