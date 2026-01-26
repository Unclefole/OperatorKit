import XCTest
@testable import OperatorKit

// ============================================================================
// AUDIT VAULT INVARIANT TESTS (Phase 13E)
//
// Tests proving Audit Vault is:
// - Zero-content (no user data stored)
// - Local-only (no networking)
// - Deterministic (hashing is stable)
// - Bounded (ring buffer enforced)
// - Feature-flagged
// - Does not touch core execution modules
//
// See: Features/AuditVault/*
// ============================================================================

final class AuditVaultInvariantTests: XCTestCase {
    
    // MARK: - Test 1: Core Execution Modules Untouched - No Imports from Phase 13E
    
    func testCoreExecutionModulesUntouched_NoImportsPhase13E() throws {
        let protectedFiles = [
            ("ExecutionEngine.swift", "OperatorKit/Domain/Execution"),
            ("ApprovalGate.swift", "OperatorKit/Domain/Approval"),
            ("ModelRouter.swift", "OperatorKit/Models"),
            ("SideEffectContract.swift", "OperatorKit/Domain/SideEffects")
        ]
        
        for (fileName, subdirectory) in protectedFiles {
            let filePath = findProjectFile(at: "\(subdirectory)/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertFalse(
                content.contains("Phase 13E"),
                "\(fileName) should not contain Phase 13E references"
            )
            
            XCTAssertFalse(
                content.contains("AuditVault"),
                "\(fileName) should not import AuditVault"
            )
        }
    }
    
    // MARK: - Test 2: No URLSession or Network Imports in Audit Vault
    
    func testNoURLSessionOrNetworkImportsInAuditVault() throws {
        let auditVaultFiles = [
            "AuditVaultFeatureFlag.swift",
            "AuditVaultModels.swift",
            "AuditVaultLineage.swift",
            "AuditVaultStore.swift",
            "AuditVaultDashboardView.swift",
            "AuditVaultEventDetailView.swift"
        ]
        
        for fileName in auditVaultFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/AuditVault/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertFalse(
                content.contains("URLSession"),
                "\(fileName) should not use URLSession"
            )
            
            XCTAssertFalse(
                content.contains("import Network"),
                "\(fileName) should not import Network"
            )
            
            XCTAssertFalse(
                content.contains("URLRequest"),
                "\(fileName) should not use URLRequest"
            )
        }
    }
    
    // MARK: - Test 3: No Background APIs in Audit Vault
    
    func testNoBackgroundAPIsInAuditVault() throws {
        let auditVaultFiles = [
            "AuditVaultStore.swift",
            "AuditVaultModels.swift"
        ]
        
        for fileName in auditVaultFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/AuditVault/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertFalse(
                content.contains("BGTaskScheduler"),
                "\(fileName) should not use BGTaskScheduler"
            )
            
            XCTAssertFalse(
                content.contains("BackgroundTask"),
                "\(fileName) should not use BackgroundTask"
            )
        }
    }
    
    // MARK: - Test 4: Audit Vault Models Contain No Forbidden Keys
    
    func testAuditVaultModelsContainNoForbiddenKeys() throws {
        // Create a lineage
        let lineage = AuditVaultLineage(
            procedureHash: "abc123def456",
            contextSlot: .slotA,
            outcomeType: .emailDraft,
            policyDecision: .allowed,
            tierAtTime: .free,
            editCount: 3
        )
        
        // Create an event
        let event = AuditVaultEvent(
            sequenceNumber: 1,
            kind: .lineageCreated,
            lineage: lineage
        )
        
        // Serialize
        let encoder = JSONEncoder()
        let eventData = try encoder.encode(event)
        let eventJson = String(data: eventData, encoding: .utf8)!
        let lowercased = eventJson.lowercased()
        
        // Check no forbidden keys
        let criticalForbidden = ["body", "subject", "content", "draft", "prompt", "email", "recipient", "message"]
        
        for key in criticalForbidden {
            XCTAssertFalse(
                lowercased.contains("\"\(key)\""),
                "Audit Vault model should not contain forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - Test 5: Audit Vault Does Not Allow Free Text
    
    func testAuditVaultDoesNotAllowFreeText() throws {
        // Check that AuditVaultLineage has no free text string fields
        let lineagePath = findProjectFile(at: "OperatorKit/Features/AuditVault/AuditVaultLineage.swift")
        let content = try String(contentsOfFile: lineagePath, encoding: .utf8)
        
        // Should not have common free text property names
        let freeTextIndicators = [
            "var note:", "var notes:", "var description:", "var title:",
            "var text:", "var message:", "var body:", "var subject:"
        ]
        
        for indicator in freeTextIndicators {
            XCTAssertFalse(
                content.contains(indicator),
                "AuditVaultLineage should not have free text field: \(indicator)"
            )
        }
    }
    
    // MARK: - Test 6: Audit Vault Hashing Deterministic
    
    func testAuditVaultHashingDeterministic() {
        let lineage1 = AuditVaultLineage(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            procedureHash: "abc123",
            contextSlot: .slotA,
            outcomeType: .emailDraft,
            policyDecision: .allowed,
            tierAtTime: .free,
            editCount: 2,
            createdAtDayRounded: "2099-01-01"
        )
        
        let lineage2 = AuditVaultLineage(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            procedureHash: "abc123",
            contextSlot: .slotA,
            outcomeType: .emailDraft,
            policyDecision: .allowed,
            tierAtTime: .free,
            editCount: 2,
            createdAtDayRounded: "2099-01-01"
        )
        
        XCTAssertEqual(
            lineage1.deterministicHash,
            lineage2.deterministicHash,
            "Identical lineages must produce identical hashes"
        )
        
        // Different edit count should produce different hash
        let lineage3 = lineage1.withIncrementedEditCount()
        XCTAssertNotEqual(
            lineage1.deterministicHash,
            lineage3.deterministicHash,
            "Different edit counts should produce different hashes"
        )
    }
    
    // MARK: - Test 7: Audit Vault Store Ring Buffer Bounded
    
    func testAuditVaultStoreRingBufferBounded() {
        XCTAssertEqual(
            AuditVaultStore.maxEventCount,
            500,
            "Ring buffer should be bounded at 500 events"
        )
    }
    
    // MARK: - Test 8: Audit Vault Store Serialization Round Trip
    
    func testAuditVaultStoreSerializationRoundTrip() throws {
        let lineage = AuditVaultLineage(
            procedureHash: "test123",
            contextSlot: .slotB,
            outcomeType: .calendarEvent,
            policyDecision: .allowed,
            tierAtTime: .pro,
            editCount: 5
        )
        
        let event = AuditVaultEvent(
            sequenceNumber: 42,
            kind: .lineageEdited,
            lineage: lineage
        )
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AuditVaultEvent.self, from: data)
        
        // Verify
        XCTAssertEqual(event.id, decoded.id, "ID should survive round-trip")
        XCTAssertEqual(event.sequenceNumber, decoded.sequenceNumber, "Sequence should survive round-trip")
        XCTAssertEqual(event.kind, decoded.kind, "Kind should survive round-trip")
        XCTAssertEqual(event.lineage?.editCount, decoded.lineage?.editCount, "Lineage edit count should survive round-trip")
        XCTAssertEqual(event.lineage?.outcomeType, decoded.lineage?.outcomeType, "Lineage outcome type should survive round-trip")
    }
    
    // MARK: - Test 9: Audit Vault Export Packet No Forbidden Keys
    
    func testAuditVaultExportPacketNoForbiddenKeys() throws {
        let summary = AuditVaultSummary(
            totalEvents: 10,
            eventsLast7Days: 5,
            countByKind: ["lineage_created": 3, "lineage_edited": 2],
            editCount: 2,
            exportCount: 1,
            lastVerifiedDayRounded: "2099-01-01"
        )
        
        let event = AuditVaultEvent(
            sequenceNumber: 1,
            kind: .lineageCreated,
            lineage: AuditVaultLineage(
                procedureHash: "abc",
                contextSlot: .none,
                outcomeType: .summary,
                policyDecision: .allowed,
                tierAtTime: .free,
                editCount: 0
            )
        )
        
        let packet = AuditVaultExportPacket(
            summary: summary,
            recentEvents: [event],
            exportedAtDayRounded: "2099-01-01",
            schemaVersion: 1
        )
        
        let errors = packet.validate()
        XCTAssertTrue(errors.isEmpty, "Export packet should have no forbidden keys: \(errors)")
    }
    
    // MARK: - Test 10: Purge Requires Explicit Confirmation
    
    func testPurgeRequiresExplicitConfirmation() async {
        // Without confirmation, purge should be rejected
        let result = await AuditVaultStore.shared.purge(confirmed: false)
        
        switch result {
        case .requiresConfirmation:
            // Expected
            break
        case .success, .notEnabled:
            XCTFail("Purge should require confirmation")
        }
    }
    
    // MARK: - Test 11: Feature Flag Gates All Entry Points
    
    func testFeatureFlagGatesAllEntryPoints() throws {
        let viewFiles = [
            "AuditVaultDashboardView.swift",
            "AuditVaultEventDetailView.swift"
        ]
        
        for fileName in viewFiles {
            let filePath = findProjectFile(at: "OperatorKit/Features/AuditVault/\(fileName)")
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                continue
            }
            
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertTrue(
                content.contains("AuditVaultFeatureFlag"),
                "\(fileName) must reference AuditVaultFeatureFlag"
            )
        }
        
        // Store should also check flag
        let storePath = findProjectFile(at: "OperatorKit/Features/AuditVault/AuditVaultStore.swift")
        let storeContent = try String(contentsOfFile: storePath, encoding: .utf8)
        
        XCTAssertTrue(
            storeContent.contains("AuditVaultFeatureFlag.isEnabled"),
            "AuditVaultStore must check feature flag"
        )
    }
    
    // MARK: - Test 12: Release Seals Still Pass
    
    func testReleaseSealsStillPass() {
        // Verify seal hashes are unchanged
        XCTAssertEqual(
            ReleaseSeal.terminologyCanonHash,
            "SEAL_TERMINOLOGY_CANON_V1",
            "Terminology Canon seal must remain intact"
        )
        
        XCTAssertEqual(
            ReleaseSeal.claimRegistryHash,
            "SEAL_CLAIM_REGISTRY_V25",
            "Claim Registry seal must remain intact"
        )
        
        XCTAssertEqual(
            ReleaseSeal.safetyContractHash,
            "SEAL_SAFETY_CONTRACT_V1",
            "Safety Contract seal must remain intact"
        )
        
        XCTAssertEqual(
            ReleaseSeal.pricingRegistryHash,
            "SEAL_PRICING_REGISTRY_V2",
            "Pricing Registry seal must remain intact"
        )
        
        XCTAssertEqual(
            ReleaseSeal.storeListingCopyHash,
            "SEAL_STORE_LISTING_V1",
            "Store Listing seal must remain intact"
        )
    }
    
    // MARK: - Helpers
    
    private func findProjectFile(at relativePath: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        return projectRoot
            .appendingPathComponent(relativePath)
            .path
    }
}
