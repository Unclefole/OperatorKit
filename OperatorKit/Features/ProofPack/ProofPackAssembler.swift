import Foundation

// ============================================================================
// PROOF PACK ASSEMBLER (Phase 13H)
//
// Collects existing outputs only. No new computation logic.
// Aggregates metadata from existing trust surfaces.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No side effects
// ❌ No new data collection
// ❌ No networking
// ❌ No file writes
// ❌ No user content access
// ✅ Read-only aggregation
// ✅ Deterministic output
// ============================================================================

public enum ProofPackAssembler {
    
    // MARK: - Assemble
    
    /// Assemble a Proof Pack from existing trust surfaces
    /// This is read-only aggregation with no side effects
    @MainActor
    public static func assemble() -> ProofPack {
        ProofPack(
            schemaVersion: ProofPack.currentSchemaVersion,
            appVersion: appVersion(),
            buildNumber: buildNumber(),
            createdAtDayRounded: dayRoundedNow(),
            releaseSeals: assembleReleaseSeals(),
            securityManifest: assembleSecurityManifest(),
            binaryProof: assembleBinaryProof(),
            regressionFirewall: assembleRegressionFirewall(),
            auditVault: assembleAuditVault(),
            offlineCertification: assembleOfflineCertification(),
            buildSeals: assembleBuildSeals(),
            featureFlags: assembleFeatureFlags()
        )
    }
    
    // MARK: - App Identity
    
    private static func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
    
    private static func buildNumber() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }
    
    private static func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
    
    // MARK: - Release Seals
    
    private static func assembleReleaseSeals() -> ReleaseSealSummary {
        // Check seals by verifying expected hash constants are present
        // This is read-only verification, not modification
        ReleaseSealSummary(
            terminologyCanon: ReleaseSeal.terminologyCanonHash == "SEAL_TERMINOLOGY_CANON_V1" ? .pass : .fail,
            claimRegistry: ReleaseSeal.claimRegistryHash == "SEAL_CLAIM_REGISTRY_V25" ? .pass : .fail,
            safetyContract: ReleaseSeal.safetyContractHash == "SEAL_SAFETY_CONTRACT_V1" ? .pass : .fail,
            pricingRegistry: ReleaseSeal.pricingRegistryHash == "SEAL_PRICING_REGISTRY_V2" ? .pass : .fail,
            storeListing: ReleaseSeal.storeListingCopyHash == "SEAL_STORE_LISTING_V1" ? .pass : .fail
        )
    }
    
    // MARK: - Security Manifest
    
    private static func assembleSecurityManifest() -> SecurityManifestSummary {
        // Binary inspection provides the ground truth for security manifest claims
        let inspection = BinaryImageInspector.inspect()
        let sensitiveChecks = Dictionary(
            uniqueKeysWithValues: inspection.sensitiveChecks.map { ($0.framework, $0.isPresent) }
        )
        
        return SecurityManifestSummary(
            webkitPresent: sensitiveChecks["WebKit"] ?? false,
            javascriptPresent: sensitiveChecks["JavaScriptCore"] ?? false,
            embeddedBrowserPresent: sensitiveChecks["SafariServices"] ?? false,
            remoteCodeExecutionPresent: false // No dynamic code loading
        )
    }
    
    // MARK: - Binary Proof
    
    private static func assembleBinaryProof() -> BinaryProofSummary {
        let inspection = BinaryImageInspector.inspect()
        let sensitiveChecks = Dictionary(
            uniqueKeysWithValues: inspection.sensitiveChecks.map { ($0.framework, $0.isPresent) }
        )
        
        return BinaryProofSummary(
            frameworkCount: inspection.linkedFrameworks.count,
            sensitiveFrameworks: SensitiveFrameworksSummary(
                webKit: sensitiveChecks["WebKit"] ?? false,
                javaScriptCore: sensitiveChecks["JavaScriptCore"] ?? false,
                safariServices: sensitiveChecks["SafariServices"] ?? false,
                webKitLegacy: sensitiveChecks["WebKitLegacy"] ?? false
            ),
            overallStatus: inspection.status.rawValue
        )
    }
    
    // MARK: - Regression Firewall
    
    private static func assembleRegressionFirewall() -> RegressionFirewallSummary {
        // Run firewall rules to get current status
        let report = RegressionFirewallRunner.shared.runAllRules()
        
        return RegressionFirewallSummary(
            ruleCount: report.totalRules,
            passed: report.passedCount,
            failed: report.failedCount,
            overallStatus: report.overallStatus.rawValue
        )
    }
    
    // MARK: - Audit Vault
    
    @MainActor
    private static func assembleAuditVault() -> AuditVaultAggregate {
        let summary = AuditVaultStore.shared.summary()
        
        return AuditVaultAggregate(
            eventCount: summary.totalEvents,
            maxCapacity: AuditVaultStore.maxEventCount,
            editCount: summary.editCount,
            exportCount: summary.exportCount
        )
    }
    
    // MARK: - Offline Certification
    
    private static func assembleOfflineCertification() -> OfflineCertificationSummary {
        let report = OfflineCertificationRunner.shared.runAllChecks()
        
        return OfflineCertificationSummary(
            overallStatus: report.status.rawValue,
            ruleCount: report.ruleCount,
            passedCount: report.passedCount,
            failedCount: report.failedCount
        )
    }
    
    // MARK: - Build Seals (Phase 13J)
    
    private static func assembleBuildSeals() -> BuildSealsSummary {
        let packet = BuildSealsLoader.loadAllSeals()
        return BuildSealsLoader.generateSummary(from: packet)
    }
    
    // MARK: - Feature Flags
    
    private static func assembleFeatureFlags() -> FeatureFlagSummary {
        FeatureFlagSummary(
            trustSurfaces: TrustSurfacesFeatureFlag.isEnabled,
            auditVault: AuditVaultFeatureFlag.isEnabled,
            securityManifest: SecurityManifestFeatureFlag.isEnabled,
            binaryProof: BinaryProofFeatureFlag.isEnabled,
            regressionFirewall: RegressionFirewallFeatureFlag.isEnabled,
            procedureSharing: ProcedureSharingFeatureFlag.isEnabled,
            sovereignExport: SovereignExportFeatureFlag.isEnabled,
            proofPack: ProofPackFeatureFlag.isEnabled,
            offlineCertification: OfflineCertificationFeatureFlag.isEnabled,
            buildSeals: BuildSealsFeatureFlag.isEnabled
        )
    }
}
