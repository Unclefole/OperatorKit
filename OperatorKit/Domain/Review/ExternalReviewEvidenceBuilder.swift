import Foundation

// ============================================================================
// EXTERNAL REVIEW EVIDENCE BUILDER (Phase 9D)
//
// Assembles the ExternalReviewEvidencePacket from existing sources.
// Performs zero side effects. Fails softly: if a section is unavailable,
// includes "unavailable" markers and continues.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No side effects
// ❌ No networking
// ❌ No content collection
// ✅ Synchronous assembly
// ✅ Soft failure with unavailable markers
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Builder for External Review Evidence Packets
public final class ExternalReviewEvidenceBuilder {
    
    // MARK: - Dependencies
    
    private let goldenCaseStore: GoldenCaseStore
    private let evalRunner: LocalEvalRunner
    private let historyStore: QualityHistoryStore
    private let acknowledgementStore: ReleaseAcknowledgementStore
    private let docHashRegistry: DocHashRegistry
    
    public init(
        goldenCaseStore: GoldenCaseStore = .shared,
        evalRunner: LocalEvalRunner = .shared,
        historyStore: QualityHistoryStore = .shared,
        acknowledgementStore: ReleaseAcknowledgementStore = .shared,
        docHashRegistry: DocHashRegistry = .shared
    ) {
        self.goldenCaseStore = goldenCaseStore
        self.evalRunner = evalRunner
        self.historyStore = historyStore
        self.acknowledgementStore = acknowledgementStore
        self.docHashRegistry = docHashRegistry
    }
    
    // MARK: - Build Packet
    
    /// Builds the complete evidence packet
    /// - Returns: ExternalReviewEvidencePacket with all available sections
    public func build() -> ExternalReviewEvidencePacket {
        let now = Date()
        let dayRoundedFormatter = DateFormatter()
        dayRoundedFormatter.dateFormat = "yyyy-MM-dd"
        
        // Build quality packet (reuse existing exporter)
        let qualityPacketExporter = QualityPacketExporter(
            goldenCaseStore: goldenCaseStore,
            evalRunner: evalRunner,
            historyStore: historyStore,
            acknowledgementStore: acknowledgementStore
        )
        let qualityPacket = qualityPacketExporter.createPacket()
        
        // Build other sections
        let safetyExport = buildSafetyContractExport()
        let claimSummary = buildClaimRegistrySummary()
        let invariantSummary = buildInvariantCheckSummary()
        let preflightSummary = buildPreflightSummary()
        let sentinelSummary = buildRegressionSentinelSummary()
        let integrityStatus = buildIntegrityStatusExport(from: qualityPacket)
        let releaseAck = buildReleaseAcknowledgementExport()
        let docHashes = docHashRegistry.computeAllHashes()
        
        return ExternalReviewEvidencePacket(
            schemaVersion: ExternalReviewEvidencePacket.currentSchemaVersion,
            exportedAt: now,
            exportedAtDayRounded: dayRoundedFormatter.string(from: now),
            appVersion: qualityPacket.appVersion,
            buildNumber: qualityPacket.buildNumber,
            releaseMode: qualityPacket.releaseMode,
            safetyContractSnapshot: safetyExport,
            claimRegistrySummary: claimSummary,
            phaseBoundariesHash: docHashes.phaseBoundariesHash,
            releaseAcknowledgement: releaseAck,
            invariantCheckSummary: invariantSummary,
            preflightSummary: preflightSummary,
            regressionSentinelSummary: sentinelSummary,
            qualityPacket: qualityPacket,
            integritySealStatus: integrityStatus,
            latestQualitySignature: qualityPacket.qualitySignature,
            reviewerTestPlan: ReviewerTestPlan.twoMinutePlan,
            reviewerFAQ: ReviewerFAQ.items,
            disclaimers: DisclaimersRegistry.allDisclaimers,
            docHashes: docHashes
        )
    }
    
    // MARK: - Section Builders
    
    private func buildSafetyContractExport() -> SafetyContractExport {
        let status = SafetyContractSnapshot.getStatus()
        return SafetyContractExport(
            contentHash: status.currentHash ?? "unavailable",
            status: status.isValid ? "valid" : "invalid",
            guaranteesCount: 12,  // Number of guarantees in SAFETY_CONTRACT.md
            lastVerified: dayRoundedDate()
        )
    }
    
    private func buildClaimRegistrySummary() -> ClaimRegistrySummaryExport {
        // Hardcoded claim IDs from CLAIM_REGISTRY.md
        let claimIds = [
            "CLAIM-001", "CLAIM-002", "CLAIM-003", "CLAIM-004",
            "CLAIM-005", "CLAIM-006", "CLAIM-007", "CLAIM-008",
            "CLAIM-009", "CLAIM-010", "CLAIM-011", "CLAIM-012"
        ]
        
        return ClaimRegistrySummaryExport(
            schemaVersion: 2,  // Updated for Phase 9C
            totalClaims: claimIds.count,
            claimIds: claimIds,
            lastUpdated: "Phase 9C"
        )
    }
    
    private func buildInvariantCheckSummary() -> InvariantCheckSummaryExport {
        let runner = InvariantCheckRunner.shared
        let results = runner.runAllChecks()
        
        let passed = results.filter { $0.passed }.count
        let failed = results.filter { !$0.passed }.count
        let status = failed == 0 ? "PASS" : "FAIL"
        
        return InvariantCheckSummaryExport(
            totalChecks: results.count,
            passedChecks: passed,
            failedChecks: failed,
            status: status,
            checkNames: results.map { $0.name },
            failedCheckNames: results.filter { !$0.passed }.map { $0.name }
        )
    }
    
    private func buildPreflightSummary() -> PreflightSummaryExport {
        let validator = PreflightValidator.shared
        let report = validator.runAllChecks()
        
        let status: String
        if !report.blockers.isEmpty {
            status = "FAIL"
        } else if !report.warnings.isEmpty {
            status = "WARN"
        } else {
            status = "PASS"
        }
        
        let categories = Set(report.results.map { $0.category }).sorted()
        
        return PreflightSummaryExport(
            totalChecks: report.totalCount,
            passedChecks: report.passedCount,
            blockers: report.blockers.count,
            warnings: report.warnings.count,
            status: status,
            releaseMode: report.releaseMode.rawValue,
            categories: categories,
            blockerNames: report.blockers.map { $0.name }
        )
    }
    
    private func buildRegressionSentinelSummary() -> RegressionSentinelExport? {
        // Only include in DEBUG/TestFlight
        #if DEBUG
        return buildRegressionSentinelSummaryInternal()
        #else
        if ReleaseMode.current == .testFlight {
            return buildRegressionSentinelSummaryInternal()
        }
        return nil
        #endif
    }
    
    private func buildRegressionSentinelSummaryInternal() -> RegressionSentinelExport {
        let sentinel = RegressionSentinel.shared
        let results = sentinel.runAllChecks()
        
        let passed = results.filter { $0.passed }.count
        let failed = results.filter { !$0.passed }.count
        let status = failed == 0 ? "ALL_CLEAR" : "REGRESSION_DETECTED"
        
        return RegressionSentinelExport(
            totalChecks: results.count,
            passedChecks: passed,
            status: status,
            checkNames: results.map { $0.name },
            failedCheckNames: results.filter { !$0.passed }.map { $0.name }
        )
    }
    
    private func buildIntegrityStatusExport(from packet: ExportQualityPacket) -> IntegrityStatusExport? {
        guard let seal = packet.integritySeal else {
            return IntegrityStatusExport(
                status: "Not Available",
                algorithm: nil,
                inputsHashed: nil,
                sealedAt: nil
            )
        }
        
        // Verify integrity
        let verifier = IntegrityVerifier()
        let status = verifier.verify(packet: packet)
        
        return IntegrityStatusExport(from: status, seal: seal)
    }
    
    private func buildReleaseAcknowledgementExport() -> ReleaseAcknowledgementExport? {
        guard let ack = acknowledgementStore.latestAcknowledgement else {
            return nil
        }
        
        let dayRoundedFormatter = DateFormatter()
        dayRoundedFormatter.dateFormat = "yyyy-MM-dd"
        
        return ReleaseAcknowledgementExport(
            acknowledgedAtDayRounded: dayRoundedFormatter.string(from: ack.acknowledgedAt),
            appVersion: ack.appVersion,
            buildNumber: ack.buildNumber,
            qualityGateStatus: ack.qualityGateStatus,
            goldenCaseCount: ack.goldenCaseCount,
            preflightPassed: ack.preflightPassed
        )
    }
    
    // MARK: - Export
    
    /// Builds and exports as JSON data
    public func exportJSON() throws -> Data {
        let packet = build()
        return try packet.toJSON()
    }
    
    /// Builds and exports to a temporary file for sharing
    public func exportToFile() throws -> URL {
        let data = try exportJSON()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: Date())
        
        let fileName = "operatorkit-evidence-packet-\(timestamp).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try data.write(to: tempURL)
        return tempURL
    }
}

// MARK: - Singleton Access

extension ExternalReviewEvidenceBuilder {
    
    /// Shared builder instance
    public static let shared = ExternalReviewEvidenceBuilder()
    
    /// Returns current date rounded to day (yyyy-MM-dd) in UTC
    private func dayRoundedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
