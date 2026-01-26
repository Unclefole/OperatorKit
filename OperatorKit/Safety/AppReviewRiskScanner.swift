import Foundation
import CryptoKit

// ============================================================================
// APP REVIEW RISK SCANNER (Phase 10K)
//
// Deterministic, local-only scanner for App Store rejection risks.
// Pure function with no side effects.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No side effects
// ❌ No networking
// ❌ No user content access
// ❌ No behavior changes
// ✅ Pure function
// ✅ Deterministic output
// ✅ Metadata-only analysis
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - App Review Risk Scanner

public enum AppReviewRiskScanner {
    
    // MARK: - Rule Definitions
    
    /// Anthropomorphic language patterns (RISK-001 to RISK-010)
    public static let anthropomorphicPatterns: [RiskPattern] = [
        RiskPattern(
            id: "RISK-001",
            pattern: "ai thinks",
            title: "Anthropomorphic Language: Thinks",
            severity: .fail,
            suggestedFix: "Replace 'AI thinks' with 'processes' or 'analyzes'"
        ),
        RiskPattern(
            id: "RISK-002",
            pattern: "ai learns",
            title: "Anthropomorphic Language: Learns",
            severity: .fail,
            suggestedFix: "Replace 'AI learns' with 'stores preferences' or 'remembers settings'"
        ),
        RiskPattern(
            id: "RISK-003",
            pattern: "ai decides",
            title: "Anthropomorphic Language: Decides",
            severity: .fail,
            suggestedFix: "Replace 'AI decides' with 'suggests' or 'recommends'"
        ),
        RiskPattern(
            id: "RISK-004",
            pattern: "ai understands",
            title: "Anthropomorphic Language: Understands",
            severity: .fail,
            suggestedFix: "Replace 'AI understands' with 'processes' or 'interprets'"
        ),
        RiskPattern(
            id: "RISK-005",
            pattern: "smart ai",
            title: "Anthropomorphic Language: Smart AI",
            severity: .warn,
            suggestedFix: "Remove 'smart' or replace with specific capabilities"
        ),
        RiskPattern(
            id: "RISK-006",
            pattern: "intelligent ai",
            title: "Anthropomorphic Language: Intelligent AI",
            severity: .warn,
            suggestedFix: "Remove 'intelligent' or replace with specific capabilities"
        ),
        RiskPattern(
            id: "RISK-007",
            pattern: "learns your",
            title: "Personalization Implication: Learns Your",
            severity: .fail,
            suggestedFix: "Replace with 'saves your preferences' or 'remembers your settings'"
        ),
        RiskPattern(
            id: "RISK-008",
            pattern: "learns you",
            title: "Personalization Implication: Learns You",
            severity: .fail,
            suggestedFix: "Replace with specific functionality description"
        ),
        RiskPattern(
            id: "RISK-009",
            pattern: "personalizes automatically",
            title: "Automatic Personalization",
            severity: .warn,
            suggestedFix: "Clarify user-initiated personalization only"
        ),
        RiskPattern(
            id: "RISK-010",
            pattern: "adapts to you",
            title: "Adaptive Personalization",
            severity: .warn,
            suggestedFix: "Replace with specific, user-controlled settings"
        )
    ]
    
    /// Unproven security claims (RISK-011 to RISK-020)
    public static let securityClaimPatterns: [RiskPattern] = [
        RiskPattern(
            id: "RISK-011",
            pattern: "secure",
            title: "Unproven Security Claim: Secure",
            severity: .fail,
            suggestedFix: "Remove or prove with specific security measures"
        ),
        RiskPattern(
            id: "RISK-012",
            pattern: "encrypted",
            title: "Unproven Security Claim: Encrypted",
            severity: .fail,
            suggestedFix: "Remove or specify encryption method used"
        ),
        RiskPattern(
            id: "RISK-013",
            pattern: "protected",
            title: "Unproven Security Claim: Protected",
            severity: .warn,
            suggestedFix: "Remove or specify protection mechanism"
        ),
        RiskPattern(
            id: "RISK-014",
            pattern: "safe",
            title: "Ambiguous Safety Claim",
            severity: .info,
            suggestedFix: "Consider more specific language"
        ),
        RiskPattern(
            id: "RISK-015",
            pattern: "unhackable",
            title: "Absolute Security Claim",
            severity: .fail,
            suggestedFix: "Remove - no system is unhackable"
        ),
        RiskPattern(
            id: "RISK-016",
            pattern: "100% secure",
            title: "Absolute Security Percentage",
            severity: .fail,
            suggestedFix: "Remove absolute claim"
        )
    ]
    
    /// Background/tracking implications (RISK-021 to RISK-030)
    public static let backgroundPatterns: [RiskPattern] = [
        RiskPattern(
            id: "RISK-021",
            pattern: "monitors",
            title: "Background Implication: Monitors",
            severity: .fail,
            suggestedFix: "Remove or clarify user-initiated only"
        ),
        RiskPattern(
            id: "RISK-022",
            pattern: "tracks",
            title: "Background Implication: Tracks",
            severity: .fail,
            suggestedFix: "Remove or clarify no tracking occurs"
        ),
        RiskPattern(
            id: "RISK-023",
            pattern: "runs in background",
            title: "Background Execution",
            severity: .fail,
            suggestedFix: "Remove - app doesn't run in background"
        ),
        RiskPattern(
            id: "RISK-024",
            pattern: "automatically watches",
            title: "Automatic Surveillance",
            severity: .fail,
            suggestedFix: "Remove entirely"
        ),
        RiskPattern(
            id: "RISK-025",
            pattern: "always listening",
            title: "Always-On Listening",
            severity: .fail,
            suggestedFix: "Remove entirely"
        ),
        RiskPattern(
            id: "RISK-026",
            pattern: "constantly",
            title: "Constant Operation Implication",
            severity: .warn,
            suggestedFix: "Replace with specific, user-initiated actions"
        )
    ]
    
    /// Data sharing implications (RISK-031 to RISK-040)
    public static let dataSharingPatterns: [RiskPattern] = [
        RiskPattern(
            id: "RISK-031",
            pattern: "syncs automatically",
            title: "Automatic Sync Without Consent",
            severity: .warn,
            suggestedFix: "Add 'when enabled' or 'opt-in' qualifier"
        ),
        RiskPattern(
            id: "RISK-032",
            pattern: "sends your data",
            title: "Data Sending Implication",
            severity: .fail,
            suggestedFix: "Clarify no data is sent without consent"
        ),
        RiskPattern(
            id: "RISK-033",
            pattern: "uploads automatically",
            title: "Automatic Upload",
            severity: .fail,
            suggestedFix: "Add user consent qualifier"
        ),
        RiskPattern(
            id: "RISK-034",
            pattern: "shares with",
            title: "Data Sharing Implication",
            severity: .warn,
            suggestedFix: "Clarify what is shared and consent required"
        ),
        RiskPattern(
            id: "RISK-035",
            pattern: "collects",
            title: "Data Collection Implication",
            severity: .warn,
            suggestedFix: "Specify exactly what is collected locally"
        )
    ]
    
    /// Monetization disclosure issues (RISK-041 to RISK-050)
    public static let monetizationPatterns: [RiskPattern] = [
        RiskPattern(
            id: "RISK-041",
            pattern: "free forever",
            title: "Misleading Free Claim",
            severity: .info,
            suggestedFix: "Clarify free tier limitations"
        ),
        RiskPattern(
            id: "RISK-042",
            pattern: "no hidden fees",
            title: "Hidden Fees Claim",
            severity: .info,
            suggestedFix: "List all potential charges"
        )
    ]
    
    /// All patterns combined
    public static var allPatterns: [RiskPattern] {
        anthropomorphicPatterns +
        securityClaimPatterns +
        backgroundPatterns +
        dataSharingPatterns +
        monetizationPatterns
    }
    
    // MARK: - Scanning
    
    /// Scans all submission copy for risks
    public static func scanSubmissionCopy() -> AppReviewRiskReport {
        var findings: [RiskFinding] = []
        
        // Scan SubmissionCopy templates
        let reviewNotes = SubmissionCopy.reviewNotesTemplate(version: "1.0", build: "1")
        findings.append(contentsOf: scanText(reviewNotes, source: "SubmissionCopy.reviewNotes"))
        
        let whatsNew = SubmissionCopy.whatsNewTemplate(version: "1.0", highlights: SubmissionCopy.defaultHighlights)
        findings.append(contentsOf: scanText(whatsNew, source: "SubmissionCopy.whatsNew"))
        
        findings.append(contentsOf: scanText(SubmissionCopy.privacyDisclosureBlurb, source: "SubmissionCopy.privacyDisclosure"))
        findings.append(contentsOf: scanText(SubmissionCopy.monetizationDisclosureBlurb, source: "SubmissionCopy.monetizationDisclosure"))
        
        // Scan PricingCopy
        findings.append(contentsOf: scanText(PricingCopy.tagline, source: "PricingCopy.tagline"))
        findings.append(contentsOf: scanText(PricingCopy.whyWeCharge, source: "PricingCopy.whyWeCharge"))
        
        for (index, prop) in PricingCopy.valueProps.enumerated() {
            findings.append(contentsOf: scanText(prop, source: "PricingCopy.valueProps[\(index)]"))
        }
        
        // Scan AppStoreMetadata
        findings.append(contentsOf: scanText(AppStoreMetadata.subtitle, source: "AppStoreMetadata.subtitle"))
        findings.append(contentsOf: scanText(AppStoreMetadata.description, source: "AppStoreMetadata.description"))
        findings.append(contentsOf: scanText(AppStoreMetadata.promotionalText, source: "AppStoreMetadata.promotionalText"))
        
        // Scan SupportCopy
        findings.append(contentsOf: scanText(SupportCopy.refundInstructions, source: "SupportCopy.refundInstructions"))
        
        for item in SupportCopy.faqItems {
            findings.append(contentsOf: scanText(item.answer, source: "SupportCopy.faq"))
        }
        
        // Scan ScreenshotChecklist captions
        for shot in ScreenshotChecklist.requiredShots {
            findings.append(contentsOf: scanText(shot.captionTemplate, source: "ScreenshotChecklist.\(shot.name)"))
        }
        
        // Scan StoreListingCopy if available
        findings.append(contentsOf: scanText(StoreListingCopy.title, source: "StoreListingCopy.title"))
        findings.append(contentsOf: scanText(StoreListingCopy.subtitle, source: "StoreListingCopy.subtitle"))
        findings.append(contentsOf: scanText(StoreListingCopy.description, source: "StoreListingCopy.description"))
        
        // Check for required disclosures
        findings.append(contentsOf: checkRequiredDisclosures())
        
        // Determine overall status
        let status = determineStatus(from: findings)
        
        return AppReviewRiskReport(
            schemaVersion: AppReviewRiskReport.currentSchemaVersion,
            createdAt: dayRoundedDate(),
            status: status,
            findings: findings,
            scannedSources: [
                "SubmissionCopy",
                "PricingCopy",
                "AppStoreMetadata",
                "SupportCopy",
                "ScreenshotChecklist",
                "StoreListingCopy"
            ]
        )
    }
    
    /// Scans a single text for risk patterns
    public static func scanText(_ text: String, source: String) -> [RiskFinding] {
        var findings: [RiskFinding] = []
        let lowercased = text.lowercased()
        
        for pattern in allPatterns {
            if lowercased.contains(pattern.pattern.lowercased()) {
                findings.append(RiskFinding(
                    id: pattern.id,
                    severity: pattern.severity,
                    title: pattern.title,
                    message: "Found '\(pattern.pattern)' in \(source)",
                    evidenceSource: source,
                    suggestedFix: pattern.suggestedFix
                ))
            }
        }
        
        return findings
    }
    
    /// Checks for required disclosures
    private static func checkRequiredDisclosures() -> [RiskFinding] {
        var findings: [RiskFinding] = []
        
        let monetizationDisclosure = SubmissionCopy.monetizationDisclosureBlurb.lowercased()
        
        // Check for restore purchases mention
        if !monetizationDisclosure.contains("restore") {
            findings.append(RiskFinding(
                id: "RISK-051",
                severity: .warn,
                title: "Missing Restore Purchases Disclosure",
                message: "Monetization disclosure should mention restore purchases",
                evidenceSource: "SubmissionCopy.monetizationDisclosure",
                suggestedFix: "Add 'Restore purchases is available in Settings' to disclosure"
            ))
        }
        
        // Check for auto-renewal terms
        if !monetizationDisclosure.contains("auto-renew") && !monetizationDisclosure.contains("automatically renew") {
            findings.append(RiskFinding(
                id: "RISK-052",
                severity: .warn,
                title: "Missing Auto-Renewal Disclosure",
                message: "Monetization disclosure should mention auto-renewal terms",
                evidenceSource: "SubmissionCopy.monetizationDisclosure",
                suggestedFix: "Add auto-renewal terms to disclosure"
            ))
        }
        
        // Check for cancellation instructions
        if !monetizationDisclosure.contains("cancel") {
            findings.append(RiskFinding(
                id: "RISK-053",
                severity: .info,
                title: "Consider Adding Cancellation Instructions",
                message: "Disclosure could benefit from cancellation instructions",
                evidenceSource: "SubmissionCopy.monetizationDisclosure",
                suggestedFix: "Add how to cancel subscription"
            ))
        }
        
        return findings
    }
    
    /// Determines overall status from findings
    private static func determineStatus(from findings: [RiskFinding]) -> RiskStatus {
        if findings.contains(where: { $0.severity == .fail }) {
            return .fail
        } else if findings.contains(where: { $0.severity == .warn }) {
            return .warn
        } else if findings.isEmpty {
            return .pass
        } else {
            return .pass // Only info-level findings
        }
    }
    
    /// Returns day-rounded date string
    private static func dayRoundedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}

// MARK: - Risk Pattern

public struct RiskPattern {
    public let id: String
    public let pattern: String
    public let title: String
    public let severity: RiskSeverity
    public let suggestedFix: String
}

// MARK: - Risk Severity

public enum RiskSeverity: String, Codable {
    case info = "info"
    case warn = "warn"
    case fail = "fail"
    
    public var displayName: String {
        switch self {
        case .info: return "Info"
        case .warn: return "Warning"
        case .fail: return "Failure"
        }
    }
}

// MARK: - Risk Status

public enum RiskStatus: String, Codable {
    case pass = "PASS"
    case warn = "WARN"
    case fail = "FAIL"
}

// MARK: - Risk Finding

public struct RiskFinding: Codable {
    public let id: String
    public let severity: RiskSeverity
    public let title: String
    public let message: String
    public let evidenceSource: String
    public let suggestedFix: String
}

// MARK: - Risk Report

public struct AppReviewRiskReport: Codable {
    public let schemaVersion: Int
    public let createdAt: String
    public let status: RiskStatus
    public let findings: [RiskFinding]
    public let scannedSources: [String]
    
    public static let currentSchemaVersion = 1
    
    /// Count of findings by severity
    public var findingCounts: [RiskSeverity: Int] {
        var counts: [RiskSeverity: Int] = [.info: 0, .warn: 0, .fail: 0]
        for finding in findings {
            counts[finding.severity, default: 0] += 1
        }
        return counts
    }
    
    /// Summary string
    public var summary: String {
        let counts = findingCounts
        return "\(status.rawValue): \(counts[.fail] ?? 0) failures, \(counts[.warn] ?? 0) warnings, \(counts[.info] ?? 0) info"
    }
    
    /// Export to JSON
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    
    /// Export filename
    public var exportFilename: String {
        "OperatorKit_RiskReport_\(createdAt).json"
    }
}
