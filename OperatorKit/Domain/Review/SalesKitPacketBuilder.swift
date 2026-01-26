import Foundation

// ============================================================================
// SALES KIT PACKET BUILDER (Phase 11B)
//
// Assembles SalesKitPacket from existing stores/builders.
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
public final class SalesKitPacketBuilder {
    
    // MARK: - Singleton
    
    public static let shared = SalesKitPacketBuilder()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Build
    
    public func build() -> SalesKitPacket {
        var availableSections: [String] = []
        var unavailableSections: [String] = []
        
        // Pricing Package
        let pricingSnapshot = buildPricingSnapshot()
        if pricingSnapshot != nil {
            availableSections.append("pricingPackage")
        } else {
            unavailableSections.append("pricingPackage")
        }
        
        // Pricing Validation
        let pricingValidation = buildPricingValidation()
        if pricingValidation != nil {
            availableSections.append("pricingValidation")
        } else {
            unavailableSections.append("pricingValidation")
        }
        
        // Playbook Metadata
        let playbookMeta = buildPlaybookMetadata()
        if playbookMeta != nil {
            availableSections.append("playbook")
        } else {
            unavailableSections.append("playbook")
        }
        
        // Pipeline Summary
        let pipeline = buildPipelineSummary()
        if pipeline != nil {
            availableSections.append("pipeline")
        } else {
            unavailableSections.append("pipeline")
        }
        
        // Buyer Proof Status
        let buyerProof = buildBuyerProofStatus()
        if buyerProof != nil {
            availableSections.append("buyerProof")
        } else {
            unavailableSections.append("buyerProof")
        }
        
        // Enterprise Readiness
        let enterprise = buildEnterpriseReadiness()
        if enterprise != nil {
            availableSections.append("enterpriseReadiness")
        } else {
            unavailableSections.append("enterpriseReadiness")
        }
        
        return SalesKitPacket(
            schemaVersion: SalesKitPacket.currentSchemaVersion,
            exportedAtDayRounded: dayRoundedNow(),
            appVersion: appVersion,
            buildNumber: buildNumber,
            pricingPackageSnapshot: pricingSnapshot,
            pricingValidationResult: pricingValidation,
            playbookMetadata: playbookMeta,
            pipelineSummary: pipeline,
            buyerProofStatus: buyerProof,
            enterpriseReadinessSummary: enterprise,
            availableSections: availableSections,
            unavailableSections: unavailableSections
        )
    }
    
    // MARK: - Section Builders
    
    private func buildPricingSnapshot() -> PricingPackageRegistrySnapshot? {
        return PricingPackageRegistrySnapshot()
    }
    
    private func buildPricingValidation() -> PricingValidationResult? {
        return PricingConsistencyValidator.shared.validate()
    }
    
    private func buildPlaybookMetadata() -> SalesPlaybookMetadata? {
        return SalesPlaybookMetadata()
    }
    
    private func buildPipelineSummary() -> PipelineSummary? {
        let store = PipelineStore.shared
        return store.currentSummary()
    }
    
    private func buildBuyerProofStatus() -> BuyerProofStatus? {
        let builder = BuyerProofPacketBuilder.shared
        let packet = builder.build()
        
        return BuyerProofStatus(
            isAvailable: true,
            availableSectionsCount: packet.availableSections.count,
            unavailableSectionsCount: packet.unavailableSections.count,
            schemaVersion: 1
        )
    }
    
    private func buildEnterpriseReadiness() -> EnterpriseReadinessSummary? {
        // Check components
        let safetyValid = SafetyContractValidator.shared.isValid
        let qualityPassing = QualityGate.shared.currentResult?.status == .passing
        let launchReady = LaunchChecklistValidator.shared.validate().isLaunchReady
        
        let status: String
        if safetyValid && qualityPassing && launchReady {
            status = "ready"
        } else if safetyValid && qualityPassing {
            status = "partial"
        } else {
            status = "not_ready"
        }
        
        return EnterpriseReadinessSummary(
            overallStatus: status,
            safetyContractValid: safetyValid,
            qualityGatePassing: qualityPassing,
            launchChecklistReady: launchReady,
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
}
