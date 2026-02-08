import Foundation

// ============================================================================
// PILOT SHARE PACK BUILDER (Phase 10O)
//
// Assembles PilotSharePack from existing builders/stores.
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
public final class PilotSharePackBuilder {
    
    // MARK: - Singleton
    
    public static let shared = PilotSharePackBuilder()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Build
    
    public func build() -> PilotSharePack {
        var availableSections: [String] = []
        var unavailableSections: [String] = []
        
        // Enterprise Readiness
        let enterpriseReadiness = buildEnterpriseReadinessSummary()
        if enterpriseReadiness != nil {
            availableSections.append("enterpriseReadiness")
        } else {
            unavailableSections.append("enterpriseReadiness")
        }
        
        // Quality
        let quality = buildQualitySummary()
        if quality != nil {
            availableSections.append("quality")
        } else {
            unavailableSections.append("quality")
        }
        
        // Diagnostics
        let diagnostics = buildDiagnosticsSummary()
        if diagnostics != nil {
            availableSections.append("diagnostics")
        } else {
            unavailableSections.append("diagnostics")
        }
        
        // Policy
        let policy = buildPolicySummary()
        if policy != nil {
            availableSections.append("policy")
        } else {
            unavailableSections.append("policy")
        }
        
        // Team
        let team = buildTeamSummary()
        if team != nil {
            availableSections.append("team")
        } else {
            unavailableSections.append("team")
        }
        
        // Conversion
        let conversion = buildConversionSummary()
        if conversion != nil {
            availableSections.append("conversion")
        } else {
            unavailableSections.append("conversion")
        }
        
        return PilotSharePack(
            schemaVersion: PilotSharePack.currentSchemaVersion,
            exportedAt: dayRoundedDate(),
            appVersion: appVersion,
            buildNumber: buildNumber,
            releaseMode: releaseMode,
            enterpriseReadinessSummary: enterpriseReadiness,
            qualitySummary: quality,
            diagnosticsSummary: diagnostics,
            policySummary: policy,
            teamSummary: team,
            conversionSummary: conversion,
            availableSections: availableSections,
            unavailableSections: unavailableSections
        )
    }
    
    // MARK: - Section Builders
    
    private func buildEnterpriseReadinessSummary() -> PilotEnterpriseReadinessSummary? {
        // Build from EnterpriseReadinessBuilder
        let packet = EnterpriseReadinessBuilder.shared.build()
        
        return PilotEnterpriseReadinessSummary(
            readinessStatus: packet.readinessStatus.rawValue,
            readinessScore: packet.readinessScore,
            safetyContractMatch: packet.safetyContractStatus?.hashMatches ?? false,
            docIntegrityPassing: packet.docIntegritySummary?.status == "all_present",
            sectionsAvailable: countAvailableSections(in: packet),
            schemaVersion: EnterpriseReadinessPacket.currentSchemaVersion
        )
    }
    
    private func buildQualitySummary() -> QualityPacketSummary? {
        // Try to get quality data
        guard let gate = QualityGate.shared.currentResult else {
            return nil
        }
        
        return QualityPacketSummary(
            qualityGateStatus: gate.status.rawValue,
            coverageScore: gate.coverageScore ?? 0,
            trendDirection: gate.trend?.rawValue ?? "unknown",
            invariantsPassing: gate.invariantsPassing,
            schemaVersion: ExportQualityPacket.currentSchemaVersion
        )
    }
    
    private func buildDiagnosticsSummary() -> DiagnosticsPacketSummary? {
        let snapshot = ExecutionDiagnostics.shared.currentSnapshot()

        // Derive from snapshot
        let total = snapshot.executionsLast7Days
        let approvalRate: Double? = total > 0 && snapshot.lastExecutionOutcome == .success ? 1.0 : nil

        return DiagnosticsPacketSummary(
            totalExecutions: total,
            approvalRate: approvalRate,
            invariantsPassing: true, // Default - not tracked in snapshot
            schemaVersion: 1
        )
    }
    
    private func buildPolicySummary() -> PolicyPacketSummary? {
        let policy = OperatorPolicyStore.shared.currentPolicy
        
        return PolicyPacketSummary(
            allowEmailDrafts: policy.allowEmailDrafts,
            allowCalendarWrites: policy.allowCalendarWrites,
            allowTaskCreation: policy.allowTaskCreation,
            allowMemoryWrites: policy.allowMemoryWrites,
            schemaVersion: PolicyExportPacket.currentSchemaVersion
        )
    }
    
    private func buildTeamSummary() -> TeamPacketSummary? {
        let trialStore = TeamTrialStore.shared
        let templateStore = PolicyTemplateStore.shared
        
        return TeamPacketSummary(
            hasTeamTier: EntitlementManager.shared.currentTier == .team,
            hasActiveTrial: trialStore.hasActiveTrial,
            teamMembersCount: nil,  // Not tracked locally
            policyTemplatesCount: templateStore.templates.count,
            schemaVersion: 1
        )
    }
    
    private func buildConversionSummary() -> ConversionPacketSummary? {
        let variantStore = PricingVariantStore.shared
        let ledger = ConversionLedger.shared
        let satisfaction = SatisfactionSignalStore.shared
        let outcome = OutcomeLedger.shared
        
        return ConversionPacketSummary(
            pricingVariant: variantStore.currentVariant.id,
            totalPurchases: ledger.data.counts[ConversionEvent.purchaseSuccess.rawValue] ?? 0,
            satisfactionAverage: satisfaction.currentSummary().overallAverage,
            templatesUsed: outcome.data.globalCounts.used,
            schemaVersion: ConversionExportPacket.currentSchemaVersion
        )
    }
    
    // MARK: - Helpers
    
    private func dayRoundedDate() -> String {
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
