import Foundation

// ============================================================================
// REPRO BUNDLE BUILDER (Phase 10P)
//
// Assembles ReproBundleExport from existing stores/builders.
// Soft-fails unavailable sections.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No side effects
// ❌ No networking
// ✅ Soft-fail missing sections
// ✅ Metadata-only output
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

@MainActor
public final class ReproBundleBuilder {
    
    // MARK: - Singleton
    
    public static let shared = ReproBundleBuilder()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Build
    
    public func build() -> ReproBundleExport {
        var availableSections: [String] = []
        var unavailableSections: [String] = []
        
        // Diagnostics
        let diagnostics = buildDiagnosticsSummary()
        if diagnostics != nil {
            availableSections.append("diagnostics")
        } else {
            unavailableSections.append("diagnostics")
        }
        
        // Quality
        let quality = buildQualitySummary()
        if quality != nil {
            availableSections.append("quality")
        } else {
            unavailableSections.append("quality")
        }
        
        // Policy
        let policy = buildPolicySummary()
        if policy != nil {
            availableSections.append("policy")
        } else {
            unavailableSections.append("policy")
        }
        
        // Pilot
        let pilot = buildPilotSummary()
        if pilot != nil {
            availableSections.append("pilot")
        } else {
            unavailableSections.append("pilot")
        }
        
        // Audit Trail
        let auditTrail = buildAuditTrailSummary()
        if auditTrail != nil {
            availableSections.append("auditTrail")
        } else {
            unavailableSections.append("auditTrail")
        }
        
        return ReproBundleExport(
            schemaVersion: ReproBundleExport.currentSchemaVersion,
            exportedAtDayRounded: dayRoundedNow(),
            appVersion: appVersion,
            buildNumber: buildNumber,
            releaseMode: releaseMode,
            diagnosticsSummary: diagnostics,
            qualitySummary: quality,
            policySummary: policy,
            pilotSummary: pilot,
            auditTrailSummary: auditTrail,
            availableSections: availableSections,
            unavailableSections: unavailableSections
        )
    }
    
    // MARK: - Section Builders
    
    private func buildDiagnosticsSummary() -> DiagnosticsSummaryExport? {
        let diagnostics = ExecutionDiagnostics.shared
        let snapshot = diagnostics.currentSnapshot()
        
        return DiagnosticsSummaryExport(
            totalExecutions: snapshot.totalExecutions,
            successCount: snapshot.successCount,
            failureCount: snapshot.failureCount,
            approvalRate: snapshot.approvalRate,
            invariantsPassing: snapshot.allInvariantsPassing,
            schemaVersion: DiagnosticsExportPacket.currentSchemaVersion
        )
    }
    
    private func buildQualitySummary() -> QualitySummaryExport? {
        guard let gate = QualityGate.shared.currentResult else {
            return nil
        }
        
        return QualitySummaryExport(
            qualityGateStatus: gate.status.rawValue,
            coverageScore: gate.coverageScore ?? 0,
            trendDirection: gate.trend?.rawValue ?? "unknown",
            invariantsPassing: gate.invariantsPassing,
            lastEvalDayRounded: gate.evaluatedAtDayRounded,
            schemaVersion: ExportQualityPacket.currentSchemaVersion
        )
    }
    
    private func buildPolicySummary() -> PolicySummaryExport? {
        let policy = OperatorPolicyStore.shared.currentPolicy
        
        return PolicySummaryExport(
            policyEnabled: policy.enabled,
            allowEmailDrafts: policy.allowEmailDrafts,
            allowCalendarWrites: policy.allowCalendarWrites,
            allowTaskCreation: policy.allowTaskCreation,
            allowMemoryWrites: policy.allowMemoryWrites,
            maxExecutionsPerDay: policy.maxExecutionsPerDay,
            requireExplicitConfirmation: policy.requireExplicitConfirmation,
            schemaVersion: PolicyExportPacket.currentSchemaVersion
        )
    }
    
    private func buildPilotSummary() -> PilotSummaryExport? {
        let trialStore = TeamTrialStore.shared
        let entitlement = EntitlementManager.shared
        
        // Try to get enterprise readiness score
        let packet = EnterpriseReadinessBuilder.shared.build()
        
        return PilotSummaryExport(
            hasTeamTier: entitlement.currentTier == .team,
            hasActiveTrial: trialStore.hasActiveTrial,
            enterpriseReadinessScore: packet.readinessScore,
            availableSections: countAvailableSections(in: packet),
            schemaVersion: PilotSharePack.currentSchemaVersion
        )
    }
    
    private func buildAuditTrailSummary() -> CustomerAuditTrailSummary? {
        let store = CustomerAuditTrailStore.shared
        return store.currentSummary()
    }
    
    // MARK: - Helpers
    
    private func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    private var releaseMode: String {
        #if DEBUG
        return "debug"
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return "testflight"
        }
        return "appstore"
        #endif
    }
    
    private func countAvailableSections(in packet: EnterpriseReadinessPacket) -> Int {
        var count = 0
        if packet.safetyContractStatus != nil { count += 1 }
        if packet.docIntegritySummary != nil { count += 1 }
        if packet.claimRegistrySummary != nil { count += 1 }
        if packet.appReviewRiskSummary != nil { count += 1 }
        if packet.qualitySummary != nil { count += 1 }
        if packet.diagnosticsSummary != nil { count += 1 }
        if packet.teamGovernanceSummary != nil { count += 1 }
        return count
    }
}
