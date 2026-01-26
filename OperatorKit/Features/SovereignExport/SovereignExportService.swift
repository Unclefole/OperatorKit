import Foundation

// ============================================================================
// SOVEREIGN EXPORT SERVICE (Phase 13C)
//
// Service for building and importing Sovereign Export bundles.
// User-initiated only, no background operations.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking
// ❌ No background writes
// ❌ No automatic operations
// ✅ User-initiated only
// ✅ Explicit confirmation required
// ============================================================================

@MainActor
public final class SovereignExportService {
    
    // MARK: - Singleton
    
    public static let shared = SovereignExportService()
    
    private init() {}
    
    // MARK: - Build Export Bundle
    
    /// Build a Sovereign Export bundle from current state
    public func buildBundle() -> BuildResult {
        guard SovereignExportFeatureFlag.isEnabled else {
            return .failure("Sovereign Export is not enabled")
        }
        
        // Collect procedures (logic-only)
        let procedures = collectProcedures()
        
        // Collect policy summary (flags only)
        let policySummary = collectPolicySummary()
        
        // Collect entitlement state (tier only)
        let entitlementState = collectEntitlementState()
        
        // Collect audit counts (aggregates only)
        let auditCounts = collectAuditCounts()
        
        // Get app version
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        
        // Build bundle
        let bundle = SovereignExportBundle(
            procedures: procedures,
            policySummary: policySummary,
            entitlementState: entitlementState,
            auditCounts: auditCounts,
            appVersion: appVersion
        )
        
        // Validate
        let validation = SovereignExportBundleValidator.validate(bundle)
        guard validation.isValid else {
            return .failure("Bundle validation failed: \(validation.errors.joined(separator: ", "))")
        }
        
        return .success(bundle)
    }
    
    // MARK: - Apply Import
    
    /// Apply an imported bundle (requires confirmation)
    public func applyBundle(_ bundle: SovereignExportBundle, confirmed: Bool) -> ApplyResult {
        guard SovereignExportFeatureFlag.isEnabled else {
            return .failure("Sovereign Export is not enabled")
        }
        
        guard confirmed else {
            return .requiresConfirmation(summary: bundleSummary(bundle))
        }
        
        // Validate before applying
        let validation = SovereignExportBundleValidator.validate(bundle)
        guard validation.isValid else {
            return .failure("Bundle validation failed")
        }
        
        // Apply procedures
        let procedureResult = applyProcedures(bundle.procedures)
        
        // Note: Policy and entitlement state are NOT automatically applied
        // User must manually configure these
        
        return .success(ApplyReport(
            proceduresImported: procedureResult.imported,
            proceduresSkipped: procedureResult.skipped,
            policyApplied: false, // Manual only
            entitlementRestored: false // Manual only
        ))
    }
    
    // MARK: - Collect Data
    
    private func collectProcedures() -> [ExportedProcedure] {
        // Get from ProcedureStore if available
        guard ProcedureSharingFeatureFlag.isEnabled else {
            return []
        }
        
        return ProcedureStore.shared.procedures.map { procedure in
            ExportedProcedure(
                id: procedure.id,
                name: procedure.name,
                category: procedure.category.rawValue,
                intentType: procedure.intentSkeleton.intentType,
                outputType: procedure.outputType.rawValue,
                promptScaffold: procedure.intentSkeleton.promptScaffold,
                requiresApproval: procedure.constraints.requiresApproval,
                createdAtDayRounded: procedure.createdAtDayRounded
            )
        }
    }
    
    private func collectPolicySummary() -> ExportedPolicySummary {
        // Return default policy summary
        // Actual policy integration would read from PolicyStore
        return ExportedPolicySummary(
            isCustomPolicyEnabled: false,
            maxExecutionsPerDay: nil,
            allowedDaysOfWeek: nil,
            requiresTwoKeyApproval: true
        )
    }
    
    private func collectEntitlementState() -> ExportedEntitlementState {
        // Return current tier without sensitive details
        return ExportedEntitlementState(
            tier: "free", // Would read from EntitlementManager
            isLifetime: false,
            teamSeatCount: nil
        )
    }
    
    private func collectAuditCounts() -> ExportedAuditCounts {
        // Return aggregate counts only
        // Would read from CustomerAuditTrailStore
        return ExportedAuditCounts(
            totalDraftedOutcomes: 0,
            totalApprovals: 0,
            totalExecutions: 0,
            totalFailures: 0
        )
    }
    
    // MARK: - Apply Data
    
    private func applyProcedures(_ exportedProcedures: [ExportedProcedure]) -> (imported: Int, skipped: Int) {
        guard ProcedureSharingFeatureFlag.isEnabled else {
            return (0, exportedProcedures.count)
        }
        
        var imported = 0
        var skipped = 0
        
        for exported in exportedProcedures {
            // Convert to ProcedureTemplate
            let skeleton = IntentSkeleton(
                intentType: exported.intentType,
                requiredContextTypes: [],
                promptScaffold: exported.promptScaffold
            )
            
            let category = ProcedureCategory(rawValue: exported.category) ?? .general
            let outputType = ProcedureOutputType(rawValue: exported.outputType) ?? .textSummary
            
            let procedure = ProcedureTemplate(
                id: exported.id,
                name: exported.name,
                category: category,
                intentSkeleton: skeleton,
                constraints: ProcedureConstraints(requiresApproval: exported.requiresApproval),
                outputType: outputType,
                createdAtDayRounded: exported.createdAtDayRounded
            )
            
            // Add to store
            let result = ProcedureStore.shared.add(procedure, confirmed: true)
            
            switch result {
            case .success:
                imported += 1
            case .failure, .requiresConfirmation:
                skipped += 1
            }
        }
        
        return (imported, skipped)
    }
    
    // MARK: - Summary
    
    private func bundleSummary(_ bundle: SovereignExportBundle) -> ImportSummary {
        ImportSummary(
            procedureCount: bundle.procedures.count,
            hasCustomPolicy: bundle.policySummary.isCustomPolicyEnabled,
            tier: bundle.entitlementState.tier,
            exportDate: bundle.exportedAtDayRounded,
            appVersion: bundle.appVersion
        )
    }
    
    // MARK: - Result Types
    
    public enum BuildResult {
        case success(SovereignExportBundle)
        case failure(String)
    }
    
    public enum ApplyResult {
        case success(ApplyReport)
        case requiresConfirmation(summary: ImportSummary)
        case failure(String)
    }
}

// MARK: - Import Summary

public struct ImportSummary {
    public let procedureCount: Int
    public let hasCustomPolicy: Bool
    public let tier: String
    public let exportDate: String
    public let appVersion: String
}

// MARK: - Apply Report

public struct ApplyReport {
    public let proceduresImported: Int
    public let proceduresSkipped: Int
    public let policyApplied: Bool
    public let entitlementRestored: Bool
}
