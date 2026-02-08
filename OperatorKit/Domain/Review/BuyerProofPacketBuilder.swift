import Foundation

// ============================================================================
// BUYER PROOF PACKET BUILDER (Phase 11A)
//
// Assembles BuyerProofPacket from existing stores/builders.
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
public final class BuyerProofPacketBuilder {
    
    // MARK: - Singleton
    
    public static let shared = BuyerProofPacketBuilder()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Build
    
    public func build() -> BuyerProofPacket {
        var availableSections: [String] = []
        var unavailableSections: [String] = []
        
        // Safety Contract
        let safetyContract = buildSafetyContractSummary()
        if safetyContract != nil {
            availableSections.append("safetyContract")
        } else {
            unavailableSections.append("safetyContract")
        }
        
        // Claim Registry
        let claimRegistry = buildClaimRegistrySummary()
        if claimRegistry != nil {
            availableSections.append("claimRegistry")
        } else {
            unavailableSections.append("claimRegistry")
        }
        
        // Quality Gate
        let qualityGate = buildQualityGateSummary()
        if qualityGate != nil {
            availableSections.append("qualityGate")
        } else {
            unavailableSections.append("qualityGate")
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
        
        // Team Readiness
        let teamReadiness = buildTeamReadinessSummary()
        if teamReadiness != nil {
            availableSections.append("teamReadiness")
        } else {
            unavailableSections.append("teamReadiness")
        }
        
        // Launch Checklist
        let launchChecklist = buildLaunchChecklistSummary()
        if launchChecklist != nil {
            availableSections.append("launchChecklist")
        } else {
            unavailableSections.append("launchChecklist")
        }
        
        return BuyerProofPacket(
            schemaVersion: BuyerProofPacket.currentSchemaVersion,
            exportedAtDayRounded: dayRoundedNow(),
            appVersion: appVersion,
            buildNumber: buildNumber,
            releaseMode: releaseMode,
            safetyContractStatus: safetyContract,
            claimRegistrySummary: claimRegistry,
            qualityGateSummary: qualityGate,
            diagnosticsSummary: diagnostics,
            policySummary: policy,
            teamReadinessSummary: teamReadiness,
            launchChecklistSummary: launchChecklist,
            availableSections: availableSections,
            unavailableSections: unavailableSections
        )
    }
    
    // MARK: - Section Builders
    
    private func buildSafetyContractSummary() -> SafetyContractStatusSummary? {
        let validator = SafetyContractValidator.shared
        
        return SafetyContractStatusSummary(
            hashMatch: validator.hashMatches,
            isValid: validator.isValid,
            schemaVersion: 1
        )
    }
    
    private func buildClaimRegistrySummary() -> ClaimRegistryBuyerSummary? {
        // Get claim IDs from registry (IDs only, no content)
        let claimIds = ClaimRegistry.shared.allClaimIds
        
        return ClaimRegistryBuyerSummary(
            totalClaims: claimIds.count,
            claimIds: claimIds,
            schemaVersion: 1
        )
    }
    
    private func buildQualityGateSummary() -> QualityGateBuyerSummary? {
        guard let gate = QualityGate.shared.currentResult else {
            return nil
        }
        
        return QualityGateBuyerSummary(
            status: gate.status.rawValue,
            coverageScore: gate.coverageScore,
            invariantsPassing: gate.invariantsPassing,
            lastEvalDayRounded: gate.evaluatedAtDayRounded,
            schemaVersion: 1
        )
    }
    
    private func buildDiagnosticsSummary() -> DiagnosticsBuyerSummary? {
        let snapshot = ExecutionDiagnostics.shared.currentSnapshot()

        // Derive counts from snapshot data
        let total = snapshot.executionsLast7Days
        let successCount = snapshot.lastExecutionOutcome == .success ? total : 0
        let failureCount = snapshot.lastExecutionOutcome == .failed ? total : 0
        let successRate: Double? = total > 0 ? Double(successCount) / Double(total) : nil

        return DiagnosticsBuyerSummary(
            totalExecutions: total,
            successCount: successCount,
            failureCount: failureCount,
            successRate: successRate,
            schemaVersion: 1
        )
    }
    
    private func buildPolicySummary() -> PolicyBuyerSummary? {
        let policy = OperatorPolicyStore.shared.currentPolicy
        
        var enabled = 0
        var disabled = 0
        
        if policy.allowEmailDrafts { enabled += 1 } else { disabled += 1 }
        if policy.allowCalendarWrites { enabled += 1 } else { disabled += 1 }
        if policy.allowTaskCreation { enabled += 1 } else { disabled += 1 }
        if policy.allowMemoryWrites { enabled += 1 } else { disabled += 1 }
        
        return PolicyBuyerSummary(
            policyEnabled: policy.enabled,
            capabilitiesEnabled: enabled,
            capabilitiesDisabled: disabled,
            requiresConfirmation: policy.requireExplicitConfirmation,
            schemaVersion: 1
        )
    }
    
    private func buildTeamReadinessSummary() -> TeamReadinessBuyerSummary? {
        let entitlement = EntitlementManager.shared
        let trial = TeamTrialStore.shared
        
        return TeamReadinessBuyerSummary(
            hasTeamTier: entitlement.currentTier == .team,
            hasActiveTrial: trial.hasActiveTrial,
            trialDaysRemaining: trial.hasActiveTrial ? trial.daysRemaining : nil,
            schemaVersion: 1
        )
    }
    
    private func buildLaunchChecklistSummary() -> LaunchChecklistBuyerSummary? {
        let validator = LaunchChecklistValidator.shared
        let result = validator.validate()
        
        return LaunchChecklistBuyerSummary(
            overallStatus: result.overallStatus.rawValue,
            passCount: result.passCount,
            warnCount: result.warnCount,
            failCount: result.failCount,
            isLaunchReady: result.isLaunchReady,
            schemaVersion: 1
        )
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
}
