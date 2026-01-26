import XCTest
@testable import OperatorKit

// ============================================================================
// SALES PACKAGING AND PLAYBOOK TESTS (Phase 11B)
//
// Tests proving sales packaging constraints:
// - Core modules unchanged
// - No URLSession in new files
// - No background APIs
// - Pipeline models contain no identity
// - SalesPlaybook has no banned words/promises
// - SalesKitPacket contains no forbidden keys
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

final class SalesPackagingAndPlaybookTests: XCTestCase {
    
    // MARK: - A) Execution Modules Untouched
    
    /// Verifies ExecutionEngine has no Phase 11B imports
    func testExecutionEngineNoPhase11BImports() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase11BPatterns = [
            "PricingPackageRegistry",
            "PricingConsistencyValidator",
            "SalesPlaybookContent",
            "PipelineStore",
            "PipelineItem",
            "SalesKitPacket"
        ]
        
        for pattern in phase11BPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ExecutionEngine.swift contains Phase 11B pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ApprovalGate has no Phase 11B imports
    func testApprovalGateNoPhase11BImports() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase11BPatterns = [
            "PricingPackageRegistry",
            "SalesPlaybookContent",
            "PipelineStore",
            "SalesKitPacket"
        ]
        
        for pattern in phase11BPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ApprovalGate.swift contains Phase 11B pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ModelRouter has no Phase 11B imports
    func testModelRouterNoPhase11BImports() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase11BPatterns = [
            "PricingPackageRegistry",
            "SalesPlaybookContent",
            "PipelineStore",
            "SalesKitPacket"
        ]
        
        for pattern in phase11BPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ModelRouter.swift contains Phase 11B pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - B) No URLSession in New Files
    
    /// Verifies new sales files have no URLSession
    func testNoURLSessionInSalesFiles() throws {
        let newFiles = [
            ("PricingPackageRegistry.swift", "Monetization"),
            ("PricingConsistencyValidator.swift", "Monetization"),
            ("SalesPlaybookContent.swift", "Growth"),
            ("PipelineModels.swift", "Growth"),
            ("PipelineStore.swift", "Growth"),
            ("SalesKitPacket.swift", "Domain/Review"),
            ("SalesKitPacketBuilder.swift", "Domain/Review")
        ]
        
        let networkingPatterns = ["URLSession", "URLRequest", "import Network"]
        
        for (fileName, subdirectory) in newFiles {
            let filePath = findProjectFile(named: fileName, in: subdirectory)
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            for pattern in networkingPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "\(fileName) contains networking: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - C) No Background APIs
    
    /// Verifies new files have no background task APIs
    func testNoBackgroundAPIs() throws {
        let newFiles = [
            ("PricingPackageRegistry.swift", "Monetization"),
            ("SalesPlaybookContent.swift", "Growth"),
            ("PipelineStore.swift", "Growth"),
            ("SalesKitPacketBuilder.swift", "Domain/Review")
        ]
        
        let backgroundPatterns = [
            "BGTaskScheduler",
            "UIBackgroundTask",
            "beginBackgroundTask"
        ]
        
        for (fileName, subdirectory) in newFiles {
            let filePath = findProjectFile(named: fileName, in: subdirectory)
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            for pattern in backgroundPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "\(fileName) contains background API: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - D) Schema Versions
    
    /// Verifies all new models have schema versions
    func testSchemaVersionsSet() {
        XCTAssertGreaterThan(PricingPackage.currentSchemaVersion, 0)
        XCTAssertGreaterThan(PricingValidationResult.currentSchemaVersion, 0)
        XCTAssertGreaterThan(PlaybookSection.currentSchemaVersion, 0)
        XCTAssertGreaterThan(PipelineItem.currentSchemaVersion, 0)
        XCTAssertGreaterThan(PipelineSummary.currentSchemaVersion, 0)
        XCTAssertGreaterThan(SalesKitPacket.currentSchemaVersion, 0)
    }
    
    // MARK: - E) Pipeline Models No Identity
    
    /// Verifies PipelineItem contains no identity fields
    func testPipelineItemNoIdentityFields() {
        let item = PipelineItem(channel: .referral)
        
        // Encode to check keys
        let encoder = JSONEncoder()
        let data = try? encoder.encode(item)
        let json = try? JSONSerialization.jsonObject(with: data!) as? [String: Any]
        
        let identityKeys = ["name", "company", "email", "domain", "phone", "notes", "person"]
        
        for key in identityKeys {
            XCTAssertNil(json?[key], "PipelineItem contains identity key: \(key)")
        }
    }
    
    /// Verifies PipelineSummary export contains no forbidden keys
    func testPipelineSummaryNoForbiddenKeys() async throws {
        let store = await PipelineStore.shared
        await store.reset()
        
        // Add some test items
        _ = await store.addItem(channel: .referral)
        _ = await store.addItem(channel: .outboundEmail)
        
        let summary = await store.currentSummary()
        let violations = try summary.validateNoForbiddenKeys()
        
        XCTAssertTrue(
            violations.isEmpty,
            "PipelineSummary contains forbidden keys: \(violations.joined(separator: ", "))"
        )
        
        await store.reset()
    }
    
    // MARK: - F) Sales Playbook Content Validation
    
    /// Verifies playbook has no banned words
    func testPlaybookNoBannedWords() {
        let violations = SalesPlaybookContent.validateNoBannedWords()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Playbook contains banned words: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies playbook has no promises
    func testPlaybookNoPromises() {
        let violations = SalesPlaybookContent.validateNoPromises()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Playbook contains promises: \(violations.joined(separator: ", "))"
        )
    }
    
    // MARK: - G) Pricing Registry Validation
    
    /// Verifies pricing registry has no banned words
    func testPricingRegistryNoBannedWords() {
        let violations = PricingPackageRegistry.validateNoBannedWords()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Pricing registry contains banned words: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies pricing registry has no anthropomorphic language
    func testPricingRegistryNoAnthropomorphic() {
        let violations = PricingPackageRegistry.validateNoAnthropomorphicLanguage()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Pricing registry contains anthropomorphic language: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies pricing validation runs without crash
    func testPricingValidatorRuns() {
        let result = PricingConsistencyValidator.shared.validate()
        
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result.findings.count, 0)
    }
    
    // MARK: - H) SalesKitPacket Validation
    
    /// Verifies SalesKitPacket contains no forbidden keys
    func testSalesKitPacketNoForbiddenKeys() async throws {
        let builder = await SalesKitPacketBuilder.shared
        let packet = await builder.build()
        
        let violations = try packet.validateNoForbiddenKeys()
        
        XCTAssertTrue(
            violations.isEmpty,
            "SalesKitPacket contains forbidden keys: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies SalesKitPacket round-trip encodes/decodes
    func testSalesKitPacketRoundTrip() async throws {
        let builder = await SalesKitPacketBuilder.shared
        let original = await builder.build()
        
        let jsonData = try original.toJSONData()
        let decoded = try SalesKitPacket.fromJSONData(jsonData)
        
        XCTAssertEqual(original.schemaVersion, decoded.schemaVersion)
        XCTAssertEqual(original.exportedAtDayRounded, decoded.exportedAtDayRounded)
        XCTAssertEqual(original.availableSections, decoded.availableSections)
    }
    
    /// Verifies builder soft-fails missing sections
    func testSalesKitBuilderSoftFail() async {
        let builder = await SalesKitPacketBuilder.shared
        let packet = await builder.build()
        
        // Should build even if some sections unavailable
        XCTAssertGreaterThan(packet.availableSections.count, 0)
        
        // Export should succeed
        let jsonData = try? packet.toJSONData()
        XCTAssertNotNil(jsonData)
    }
    
    // MARK: - I) Forbidden Keys Comprehensive Check
    
    /// Verifies forbidden keys list is complete
    func testForbiddenKeysComplete() {
        let requiredForbidden = [
            "body", "subject", "content", "draft", "prompt",
            "context", "email", "recipient", "attendees", "title",
            "description", "message", "text", "name", "address",
            "company", "domain", "phone"
        ]
        
        // Check SalesKitPacket
        for key in requiredForbidden {
            XCTAssertTrue(
                SalesKitPacket.forbiddenKeys.contains(key),
                "SalesKitPacket missing forbidden key: \(key)"
            )
        }
        
        // Check PipelineSummary
        for key in requiredForbidden {
            XCTAssertTrue(
                PipelineSummary.forbiddenKeys.contains(key),
                "PipelineSummary missing forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - Helpers
    
    private func findProjectFile(named fileName: String, in subdirectory: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        return projectRoot
            .appendingPathComponent("OperatorKit")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent(fileName)
            .path
    }
}
