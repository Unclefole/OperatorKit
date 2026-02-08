import Foundation

// ============================================================================
// EXPORT QUALITY PACKET (Phase 9B, extended Phase 9C)
//
// Aggregates all quality metrics for export.
// Contains METADATA ONLY - no user content.
//
// Phase 9C additions:
// - Integrity seal for tamper-evident records
// - Local verification support
//
// INVARIANT: No user content (no draft text, emails, events)
// INVARIANT: Dates are day-rounded where applicable
// INVARIANT: Safe for sharing/auditing
// INVARIANT: Integrity is advisory and local only (Phase 9C)
// INVARIANT: UUIDs are used strictly for record identification and UI diffing.
// INVARIANT: UUIDs are NEVER included in proof hash computation.
// Hash inputs are limited to schemaVersion, status fields, counts,
// and day-rounded timestamps only.
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Complete quality export packet (metadata only)
public struct ExportQualityPacket: Codable {
    
    // MARK: - Metadata
    
    public let schemaVersion: Int
    public let exportedAt: Date
    public let exportedAtDayRounded: String  // Day-rounded date string
    public let appVersion: String
    public let buildNumber: String
    public let releaseMode: String
    
    // MARK: - Quality Signature
    
    public let qualitySignature: QualitySignature?
    
    // MARK: - Safety Contract
    
    public let safetyContractStatus: EvalSafetyContractExport
    
    // MARK: - Quality Gate
    
    public let qualityGateResult: EvalQualityGateExport
    
    // MARK: - Coverage
    
    public let coverageScore: Int
    public let coverageDimensions: [CoverageDimensionExport]
    
    // MARK: - Trend
    
    public let trend: QualityTrendExport
    
    // MARK: - Recommendations (titles + severity only)
    
    public let recommendations: [RecommendationExport]
    
    // MARK: - Release Acknowledgement (if exists)
    
    public let lastAcknowledgement: ReleaseAcknowledgementExport?
    
    // MARK: - Prompt Scaffold Registry
    
    public let promptScaffoldMetadata: PromptScaffoldRegistry.ExportableMetadata
    
    // MARK: - Integrity Seal (Phase 9C)
    
    /// Cryptographic integrity seal for tamper-evident records
    ///
    /// - Contains hash of quality metadata sections
    /// - Never contains user content
    /// - Advisory only, does not block export
    public let integritySeal: IntegritySeal?
    
    public static let currentSchemaVersion = 2  // Bumped for Phase 9C
}

// MARK: - Sub-structures

public struct EvalSafetyContractExport: Codable {
    public let currentHash: String
    public let expectedHash: String
    public let isUnchanged: Bool
    public let lastUpdateReason: String
}

public struct EvalQualityGateExport: Codable {
    public let status: String
    public let reasons: [String]
    public let goldenCaseCount: Int
    public let latestPassRate: Double?
    public let driftLevel: String?
}

public struct CoverageDimensionExport: Codable {
    public let name: String
    public let coveragePercent: Int
    public let coveredCount: Int
    public let totalCount: Int
    public let missingCategories: [String]
}

public struct QualityTrendExport: Codable {
    public let passRateDirection: String
    public let driftDirection: String
    public let passingStreak: Int
    public let evalStreak: Int
    public let daysSinceLastEval: Int?
    public let isFresh: Bool
    public let averagePassRate: Double
    public let periodDays: Int
    public let dataPoints: Int
}

public struct RecommendationExport: Codable {
    public let severity: String
    public let title: String
    public let category: String
    // NOTE: message and suggestedNextSteps intentionally omitted for brevity
}

public struct ReleaseAcknowledgementExport: Codable {
    public let acknowledgedAtDayRounded: String  // Day-rounded
    public let appVersion: String
    public let buildNumber: String
    public let qualityGateStatus: String
    public let goldenCaseCount: Int
    public let preflightPassed: Bool
}

// MARK: - Factory

public final class QualityPacketExporter {
    
    private let goldenCaseStore: GoldenCaseStore
    private let evalRunner: LocalEvalRunner
    private let historyStore: QualityHistoryStore
    private let acknowledgementStore: ReleaseAcknowledgementStore
    
    public init(
        goldenCaseStore: GoldenCaseStore = .shared,
        evalRunner: LocalEvalRunner = .shared,
        historyStore: QualityHistoryStore = .shared,
        acknowledgementStore: ReleaseAcknowledgementStore = .shared
    ) {
        self.goldenCaseStore = goldenCaseStore
        self.evalRunner = evalRunner
        self.historyStore = historyStore
        self.acknowledgementStore = acknowledgementStore
    }
    
    /// Creates a complete export packet
    public func createPacket() -> ExportQualityPacket {
        let now = Date()
        let dayRoundedFormatter = DateFormatter()
        dayRoundedFormatter.dateFormat = "yyyy-MM-dd"
        
        // Quality signature
        let signature = QualitySignature.capture()
        
        // Safety contract
        let safetyStatus = SafetyContractSnapshot.getStatus()
        let safetyExport = EvalSafetyContractExport(
            currentHash: safetyStatus.currentHash ?? "unknown",
            expectedHash: safetyStatus.expectedHash ?? "unknown",
            isUnchanged: safetyStatus.isUnchanged,
            lastUpdateReason: SafetyContractSnapshot.lastUpdateReason
        )
        
        // Quality gate
        let gateResult = QualityGateEvaluator(
            goldenCaseStore: goldenCaseStore,
            evalRunner: evalRunner
        ).evaluate()
        let gateExport = EvalQualityGateExport(
            status: gateResult.status.rawValue,
            reasons: gateResult.reasons,
            goldenCaseCount: gateResult.metrics.goldenCaseCount,
            latestPassRate: gateResult.metrics.latestPassRate,
            driftLevel: gateResult.metrics.driftLevel
        )
        
        // Coverage
        let coverage = GoldenCaseCoverageComputer(goldenCaseStore: goldenCaseStore).computeCoverage()
        let coverageDimensions = [
            createCoverageDimensionExport(coverage.intentTypeCoverage),
            createCoverageDimensionExport(coverage.confidenceBandCoverage),
            createCoverageDimensionExport(coverage.backendTypeCoverage)
        ]
        
        // Trend
        let trend = QualityTrendComputer(historyStore: historyStore).computeTrend(days: 30)
        let trendExport = QualityTrendExport(
            passRateDirection: trend.passRateDirection.rawValue,
            driftDirection: trend.driftDirection.rawValue,
            passingStreak: trend.passingStreak,
            evalStreak: trend.evalStreak,
            daysSinceLastEval: trend.daysSinceLastEval,
            isFresh: trend.isFresh,
            averagePassRate: trend.averagePassRate,
            periodDays: trend.periodDays,
            dataPoints: trend.dataPoints
        )
        
        // Recommendations (titles + severity only)
        let recommendations = CalibrationAdvisor(
            goldenCaseStore: goldenCaseStore,
            evalRunner: evalRunner,
            historyStore: historyStore
        ).generateRecommendations()
        let recsExport = recommendations.map { rec in
            RecommendationExport(
                severity: rec.severity.rawValue,
                title: rec.title,
                category: rec.category.rawValue
            )
        }
        
        // Last acknowledgement
        var ackExport: ReleaseAcknowledgementExport? = nil
        if let lastAck = acknowledgementStore.latestAcknowledgement {
            ackExport = ReleaseAcknowledgementExport(
                acknowledgedAtDayRounded: dayRoundedFormatter.string(from: lastAck.acknowledgedAt),
                appVersion: lastAck.appVersion,
                buildNumber: lastAck.buildNumber,
                qualityGateStatus: lastAck.qualityGateStatus,
                goldenCaseCount: lastAck.goldenCaseCount,
                preflightPassed: lastAck.preflightPassed
            )
        }
        
        // Create integrity seal (Phase 9C)
        // INVARIANT: Seal creation is synchronous
        // INVARIANT: Failure to seal → export still succeeds, seal marked "unavailable"
        let sealFactory = IntegritySealFactory()
        let integritySeal = sealFactory.createSeal(
            signature: signature,
            safetyStatus: safetyExport,
            gateResult: gateExport,
            coverageScore: coverage.overallScore,
            trend: trendExport
        )
        
        return ExportQualityPacket(
            schemaVersion: ExportQualityPacket.currentSchemaVersion,
            exportedAt: now,
            exportedAtDayRounded: dayRoundedFormatter.string(from: now),
            appVersion: signature.appVersion,
            buildNumber: signature.buildNumber,
            releaseMode: signature.releaseMode,
            qualitySignature: signature,
            safetyContractStatus: safetyExport,
            qualityGateResult: gateExport,
            coverageScore: coverage.overallScore,
            coverageDimensions: coverageDimensions,
            trend: trendExport,
            recommendations: recsExport,
            lastAcknowledgement: ackExport,
            promptScaffoldMetadata: PromptScaffoldRegistry.exportMetadata(),
            integritySeal: integritySeal
        )
    }
    
    private func createCoverageDimensionExport(_ dimension: CoverageDimension) -> CoverageDimensionExport {
        CoverageDimensionExport(
            name: dimension.name,
            coveragePercent: dimension.coveragePercent,
            coveredCount: dimension.coveredCategories.count,
            totalCount: dimension.categories.count,
            missingCategories: dimension.missingCategories
        )
    }
    
    /// Exports packet as JSON
    public func exportJSON() throws -> Data {
        let packet = createPacket()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(packet)
    }
}
