import Foundation

// ============================================================================
// ENTERPRISE READINESS PACKET (Phase 10M)
//
// Procurement-ready, content-free evidence export for B2B sales.
// Aggregates safety, quality, and governance metadata only.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content (body, subject, draft, prompt, context, etc.)
// ❌ No raw doc text or listing copy
// ❌ No networking
// ❌ No execution behavior changes
// ✅ Metadata-only: hashes, statuses, counts, flags
// ✅ Soft-fail for missing sections
// ✅ Forbidden-key validated
// ✅ User-initiated export only
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Enterprise Readiness Packet

public struct EnterpriseReadinessPacket: Codable {
    
    // MARK: - Metadata
    
    /// Schema version
    public let schemaVersion: Int
    
    /// Export timestamp (day-rounded)
    public let exportedAt: String
    
    /// App version
    public let appVersion: String
    
    /// Build number
    public let buildNumber: String
    
    /// Release mode (debug/testflight/appstore)
    public let releaseMode: String
    
    // MARK: - Safety & Governance
    
    /// Safety contract status (hash + match status)
    public let safetyContractStatus: EnterpriseSafetyContractStatus?
    
    /// Doc integrity summary
    public let docIntegritySummary: EnterpriseDocIntegritySummary?
    
    /// Claim registry summary (IDs + counts only)
    public let claimRegistrySummary: EnterpriseClaimRegistrySummary?
    
    /// App review risk summary
    public let appReviewRiskSummary: EnterpriseRiskSummary?
    
    // MARK: - Quality
    
    /// Quality summary
    public let qualitySummary: EnterpriseQualitySummary?
    
    /// Diagnostics summary (counts only)
    public let diagnosticsSummary: EnterpriseDiagnosticsSummary?
    
    // MARK: - Team Governance
    
    /// Team governance summary
    public let teamGovernanceSummary: EnterpriseTeamGovernanceSummary?
    
    // MARK: - Readiness Score
    
    /// Overall readiness status
    public let readinessStatus: EnterpriseReadinessStatus
    
    /// Readiness score (0-100)
    public let readinessScore: Int
    
    // MARK: - Schema
    
    public static let currentSchemaVersion = 1
}

// MARK: - Safety Contract Status

public struct EnterpriseSafetyContractStatus: Codable {
    /// SHA-256 hash of safety contract
    public let contentHash: String
    
    /// Whether hash matches expected
    public let hashMatches: Bool
    
    /// Guarantees count
    public let guaranteesCount: Int
    
    /// Last verified date
    public let lastVerified: String?
    
    /// Status
    public let status: String  // valid/invalid/unavailable
}

// MARK: - Doc Integrity Summary

public struct EnterpriseDocIntegritySummary: Codable {
    /// Total required docs
    public let requiredDocsCount: Int
    
    /// Present docs count
    public let presentCount: Int
    
    /// Missing docs count
    public let missingCount: Int
    
    /// Status
    public let status: String  // all_present/partial/unavailable
}

// MARK: - Claim Registry Summary

public struct EnterpriseClaimRegistrySummary: Codable {
    /// Schema version
    public let registrySchemaVersion: Int
    
    /// Total claims count
    public let totalClaims: Int
    
    /// Claim IDs (no content)
    public let claimIds: [String]
    
    /// Last updated phase
    public let lastUpdatedPhase: String
}

// MARK: - Risk Summary

public struct EnterpriseRiskSummary: Codable {
    /// Overall status
    public let status: String  // PASS/WARN/FAIL
    
    /// Finding counts by severity
    public let findingCounts: EnterpriseRiskFindingCounts
    
    /// Scanned sources count
    public let scannedSourcesCount: Int
}

public struct EnterpriseRiskFindingCounts: Codable {
    public let failCount: Int
    public let warnCount: Int
    public let infoCount: Int
}

// MARK: - Quality Summary

public struct EnterpriseQualitySummary: Codable {
    /// Gate status
    public let gateStatus: String  // passed/failed/not_run
    
    /// Coverage score (0-100)
    public let coverageScore: Int
    
    /// Trend direction
    public let trendDirection: String  // improving/stable/declining
    
    /// Golden case count
    public let goldenCaseCount: Int
    
    /// Feedback count
    public let feedbackCount: Int
}

// MARK: - Diagnostics Summary

public struct EnterpriseDiagnosticsSummary: Codable {
    /// Total executions (7 days)
    public let totalExecutions7Days: Int
    
    /// Executions today
    public let executionsToday: Int
    
    /// Invariants passing
    public let invariantsPassing: Bool
    
    /// Last outcome
    public let lastOutcome: String
}

// MARK: - Team Governance Summary

public struct EnterpriseTeamGovernanceSummary: Codable {
    /// Team tier enabled
    public let teamTierEnabled: Bool
    
    /// Sync enabled
    public let syncEnabled: Bool
    
    /// Policy templates available
    public let policyTemplatesAvailable: Bool
    
    /// Team diagnostics available
    public let teamDiagnosticsAvailable: Bool
    
    /// Team quality summaries available
    public let teamQualitySummariesAvailable: Bool
}

// MARK: - Readiness Status

public enum EnterpriseReadinessStatus: String, Codable {
    case ready = "READY"
    case partiallyReady = "PARTIALLY_READY"
    case notReady = "NOT_READY"
    case unavailable = "UNAVAILABLE"
}

// MARK: - Export Extension

extension EnterpriseReadinessPacket {
    
    /// Exports to JSON data
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    
    /// Export filename
    public var exportFilename: String {
        "OperatorKit_EnterpriseReadiness_\(appVersion)_\(exportedAt).json"
    }
}
