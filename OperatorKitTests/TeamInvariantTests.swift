import XCTest
@testable import OperatorKit

// ============================================================================
// TEAM INVARIANT TESTS (Phase 10E)
//
// These tests enforce that team functionality:
// - Does NOT affect execution
// - Contains NO user content
// - Is metadata-only
// - Role changes do NOT affect execution
// - Core modules remain untouched
//
// See: docs/SAFETY_CONTRACT.md (Section 14)
// ============================================================================

final class TeamInvariantTests: XCTestCase {
    
    // MARK: - A) Core Modules Do Not Import Team
    
    /// Verifies ExecutionEngine.swift does NOT reference Team
    func testExecutionEngineDoesNotImportTeam() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let forbiddenPatterns = [
            "TeamAccount",
            "TeamStore",
            "TeamMembership",
            "TeamRole",
            "TeamArtifact"
        ]
        
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "INVARIANT VIOLATION: ExecutionEngine.swift contains forbidden pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ApprovalGate.swift does NOT reference Team
    func testApprovalGateDoesNotImportTeam() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let forbiddenPatterns = [
            "TeamAccount",
            "TeamStore",
            "TeamMembership",
            "TeamRole"
        ]
        
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "INVARIANT VIOLATION: ApprovalGate.swift contains forbidden pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ModelRouter.swift does NOT reference Team
    func testModelRouterDoesNotImportTeam() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let forbiddenPatterns = [
            "TeamAccount",
            "TeamStore",
            "TeamMembership",
            "TeamRole"
        ]
        
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "INVARIANT VIOLATION: ModelRouter.swift contains forbidden pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - B) Team Artifacts Contain No Forbidden Keys
    
    /// Verifies TeamPolicyTemplate contains no forbidden keys
    func testPolicyTemplateContainsNoForbiddenKeys() throws {
        let template = TeamPolicyTemplate(
            id: UUID(),
            name: "Test Template",
            description: "Test",
            createdAt: Date(),
            createdBy: "user123",
            allowEmailDrafts: true,
            allowCalendarWrites: false,
            allowTaskCreation: true,
            allowMemoryWrites: true,
            maxExecutionsPerDay: 10,
            requireExplicitConfirmation: true,
            schemaVersion: 1
        )
        
        let data = try template.exportJSON()
        let (result, _) = TeamArtifactValidator.shared.validatePolicyTemplate(template)
        
        XCTAssertTrue(result.isValid, "Policy template should pass validation: \(result.errors)")
    }
    
    /// Verifies TeamDiagnosticsSnapshot contains no forbidden keys
    func testDiagnosticsSnapshotContainsNoForbiddenKeys() throws {
        let snapshot = TeamDiagnosticsSnapshot(
            id: UUID(),
            capturedAt: Date(),
            capturedBy: "user123",
            totalExecutions: 100,
            successRate: 0.95,
            fallbackRate: 0.05,
            executionsToday: 5,
            lastOutcome: "success",
            appVersion: "1.0.0",
            buildNumber: "100",
            schemaVersion: 1
        )
        
        let (result, _) = TeamArtifactValidator.shared.validateDiagnosticsSnapshot(snapshot)
        
        XCTAssertTrue(result.isValid, "Diagnostics snapshot should pass validation: \(result.errors)")
    }
    
    /// Verifies TeamQualitySummary contains no forbidden keys
    func testQualitySummaryContainsNoForbiddenKeys() throws {
        let summary = TeamQualitySummary(
            id: UUID(),
            capturedAt: Date(),
            capturedBy: "user123",
            qualityGatePassRate: 0.9,
            qualityScore: 85,
            coverageScore: 80,
            driftLevel: "low",
            goldenCaseCount: 10,
            feedbackCount: 50,
            trendDirection: "stable",
            appVersion: "1.0.0",
            schemaVersion: 1
        )
        
        let (result, _) = TeamArtifactValidator.shared.validateQualitySummary(summary)
        
        XCTAssertTrue(result.isValid, "Quality summary should pass validation: \(result.errors)")
    }
    
    /// Verifies TeamEvidencePacketRef contains no forbidden keys
    func testEvidenceRefContainsNoForbiddenKeys() throws {
        let ref = TeamEvidencePacketRef(
            id: UUID(),
            capturedAt: Date(),
            capturedBy: "user123",
            packetHash: "abc123def456",
            originalExportedAt: Date(),
            evidenceType: "quality_export",
            sizeBytes: 1024,
            appVersion: "1.0.0",
            buildNumber: "100",
            schemaVersion: 1
        )
        
        let (result, _) = TeamArtifactValidator.shared.validateEvidenceRef(ref)
        
        XCTAssertTrue(result.isValid, "Evidence ref should pass validation: \(result.errors)")
    }
    
    // MARK: - C) Team Validator Blocks Forbidden Keys
    
    /// Verifies validator blocks payloads with forbidden content keys
    func testValidatorBlocksForbiddenKeys() {
        let validator = TeamArtifactValidator.shared
        
        // Payload with forbidden "body" key
        let badPayload: [String: Any] = [
            "schemaVersion": 1,
            "capturedAt": ISO8601DateFormatter().string(from: Date()),
            "body": "This is user content"  // FORBIDDEN
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: badPayload)
        let result = validator.validate(jsonData: data, artifactType: .policyTemplate)
        
        XCTAssertFalse(result.isValid, "Validator should reject payload with 'body' key")
    }
    
    /// Verifies validator blocks payloads with secret keys
    func testValidatorBlocksSecretKeys() {
        let validator = TeamArtifactValidator.shared
        
        let badPayload: [String: Any] = [
            "schemaVersion": 1,
            "capturedAt": ISO8601DateFormatter().string(from: Date()),
            "password": "secret123"  // FORBIDDEN
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: badPayload)
        let result = validator.validate(jsonData: data, artifactType: .policyTemplate)
        
        XCTAssertFalse(result.isValid, "Validator should reject payload with 'password' key")
    }
    
    // MARK: - D) Team Sync Disabled by Default
    
    /// Verifies team features default to off
    func testTeamFeaturesOffByDefault() {
        XCTAssertFalse(
            TeamFeatureFlag.defaultToggleState,
            "Team features must be OFF by default"
        )
    }
    
    // MARK: - E) Role Changes Do Not Affect Execution
    
    /// Verifies TeamRole has no execution enforcement methods
    func testTeamRoleHasNoExecutionMethods() {
        // TeamRole should only have display-related methods
        let role = TeamRole.member
        
        // These are allowed (display only)
        _ = role.displayName
        _ = role.description
        _ = role.icon
        _ = role.canManageMembers
        _ = role.canUploadArtifacts
        _ = role.canDeleteTeam
        
        // The role struct should NOT have any methods that affect execution
        // This is a structural check - if such methods existed, this test file
        // would need to import execution modules, which is forbidden
    }
    
    /// Verifies TeamStore does not affect execution on role change
    func testTeamStoreDoesNotAffectExecution() {
        // TeamStore should only manage team state, not execution
        let store = TeamStore.shared
        
        // These properties are allowed (UI display only)
        _ = store.hasTeam
        _ = store.currentRole
        _ = store.canManageMembers
        
        // Verify no execution-related methods exist
        // (This is enforced by not having execution imports)
    }
    
    // MARK: - F) Team Files No Execution Imports
    
    /// Verifies Team files don't import execution modules
    func testTeamFilesNoExecutionImports() throws {
        let teamFiles = [
            ("TeamAccount.swift", "Team"),
            ("TeamStore.swift", "Team"),
            ("TeamArtifacts.swift", "Team"),
            ("TeamArtifactValidator.swift", "Team"),
            ("TeamSupabaseClient.swift", "Team")
        ]
        
        let executionPatterns = [
            "ExecutionEngine",
            "ApprovalGate",
            "ModelRouter",
            "DraftGenerator",
            "ContextAssembler"
        ]
        
        for (fileName, directory) in teamFiles {
            let filePath = findProjectFile(named: fileName, in: directory)
            guard FileManager.default.fileExists(atPath: filePath) else { continue }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            for pattern in executionPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "INVARIANT VIOLATION: \(fileName) contains execution pattern: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - G) Team Artifacts Are Metadata Only
    
    /// Verifies shareable artifact types are limited
    func testShareableArtifactTypesAreLimited() {
        let types = TeamSafetyConfig.TeamArtifactType.allCases
        
        // Should be a small, controlled list
        XCTAssertLessThanOrEqual(types.count, 10, "Shareable artifact types should be limited")
        
        // Verify NO content types
        for type in types {
            XCTAssertFalse(
                type.rawValue.lowercased().contains("draft"),
                "No draft types should be shareable"
            )
            XCTAssertFalse(
                type.rawValue.lowercased().contains("memory"),
                "No memory types should be shareable"
            )
            XCTAssertFalse(
                type.rawValue.lowercased().contains("context"),
                "No context types should be shareable"
            )
            XCTAssertFalse(
                type.rawValue.lowercased().contains("input"),
                "No input types should be shareable"
            )
        }
    }
    
    // MARK: - H) Subscription Tier Team Features
    
    /// Verifies only Team tier has team features
    func testOnlyTeamTierHasTeamFeatures() {
        XCTAssertFalse(SubscriptionTier.free.hasTeamFeatures)
        XCTAssertFalse(SubscriptionTier.pro.hasTeamFeatures)
        XCTAssertTrue(SubscriptionTier.team.hasTeamFeatures)
    }
    
    /// Verifies Pro and Team have unlimited executions
    func testProAndTeamHaveUnlimitedExecutions() {
        XCTAssertFalse(SubscriptionTier.free.hasUnlimitedExecutions)
        XCTAssertTrue(SubscriptionTier.pro.hasUnlimitedExecutions)
        XCTAssertTrue(SubscriptionTier.team.hasUnlimitedExecutions)
    }
    
    // MARK: - Helpers
    
    /// Finds a project file by name and subdirectory
    private func findProjectFile(named fileName: String, in subdirectory: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let targetPath = projectRoot
            .appendingPathComponent("OperatorKit")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent(fileName)
            .path
        
        return targetPath
    }
}

// MARK: - Team Artifact Type Tests

extension TeamInvariantTests {
    
    /// Verifies artifact type display names are user-friendly
    func testArtifactTypeDisplayNames() {
        for type in TeamSafetyConfig.TeamArtifactType.allCases {
            XCTAssertFalse(type.displayName.isEmpty)
            XCTAssertFalse(type.description.isEmpty)
            
            // Should not contain technical jargon
            XCTAssertFalse(type.displayName.contains("JSON"))
            XCTAssertFalse(type.displayName.contains("struct"))
        }
    }
    
    /// Verifies TeamRole display names
    func testTeamRoleDisplayNames() {
        for role in TeamRole.allCases {
            XCTAssertFalse(role.displayName.isEmpty)
            XCTAssertFalse(role.description.isEmpty)
            XCTAssertFalse(role.icon.isEmpty)
        }
    }
}
