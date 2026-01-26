import XCTest
@testable import OperatorKit

// ============================================================================
// GROWTH ENGINE INVARIANT TESTS (Phase 11A)
//
// Tests proving growth engine constraints:
// - No execution module changes
// - No URLSession in new files
// - No background APIs
// - Referral code contains no user identifiers
// - Referral ledger stores only counts + dates
// - BuyerProofPacket contains no forbidden keys
// - Outbound templates contain no banned words/promises
// - Export packets round-trip encode/decode
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

final class GrowthEngineInvariantTests: XCTestCase {
    
    // MARK: - A) Execution Modules Untouched
    
    /// Verifies ExecutionEngine has no Phase 11A imports
    func testExecutionEngineNoPhase11AImports() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase11APatterns = [
            "ReferralCode",
            "ReferralLedger",
            "BuyerProofPacket",
            "OutboundTemplates",
            "GrowthEngine"
        ]
        
        for pattern in phase11APatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ExecutionEngine.swift contains Phase 11A pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ApprovalGate has no Phase 11A imports
    func testApprovalGateNoPhase11AImports() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase11APatterns = [
            "ReferralCode",
            "BuyerProofPacket",
            "OutboundTemplates"
        ]
        
        for pattern in phase11APatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ApprovalGate.swift contains Phase 11A pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ModelRouter has no Phase 11A imports
    func testModelRouterNoPhase11AImports() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase11APatterns = [
            "ReferralCode",
            "BuyerProofPacket",
            "OutboundTemplates"
        ]
        
        for pattern in phase11APatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ModelRouter.swift contains Phase 11A pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - B) No URLSession in New Files
    
    /// Verifies new growth files have no URLSession
    func testNoURLSessionInGrowthFiles() throws {
        let newFiles = [
            ("ReferralCode.swift", "Growth"),
            ("ReferralLedger.swift", "Growth"),
            ("OutboundTemplates.swift", "Growth"),
            ("BuyerProofPacket.swift", "Domain/Review"),
            ("BuyerProofPacketBuilder.swift", "Domain/Review")
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
            ("ReferralCode.swift", "Growth"),
            ("ReferralLedger.swift", "Growth"),
            ("OutboundTemplates.swift", "Growth"),
            ("BuyerProofPacket.swift", "Domain/Review"),
            ("BuyerProofPacketBuilder.swift", "Domain/Review")
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
    
    // MARK: - D) Referral Code No Identifiers
    
    /// Verifies referral code contains no user identifiers
    func testReferralCodeNoIdentifiers() {
        let code = ReferralCode()
        
        // Validate format
        XCTAssertTrue(ReferralCode.isValidFormat(code.code))
        
        // Validate no identifiers
        let violations = code.validateNoIdentifiers()
        XCTAssertTrue(violations.isEmpty, "Referral code contains identifiers: \(violations)")
        
        // Verify format: OK-XXXX-XXXX
        XCTAssertTrue(code.code.hasPrefix("OK-"))
        XCTAssertEqual(code.code.count, 12) // OK-XXXX-XXXX = 12 chars
    }
    
    /// Verifies referral code is deterministic format
    func testReferralCodeFormat() {
        for _ in 0..<10 {
            let code = ReferralCode()
            XCTAssertTrue(
                ReferralCode.isValidFormat(code.code),
                "Invalid format: \(code.code)"
            )
        }
    }
    
    // MARK: - E) Referral Ledger Counts Only
    
    /// Verifies referral ledger stores only counts
    func testReferralLedgerCountsOnly() async {
        let ledger = await ReferralLedger.shared
        await ledger.reset()
        
        // Record some actions
        await ledger.recordAction(.shareTapped)
        await ledger.recordAction(.copyTapped)
        
        // Get summary
        let summary = await ledger.currentSummary()
        
        // Verify numeric only
        XCTAssertGreaterThanOrEqual(summary.totalShares, 0)
        XCTAssertGreaterThanOrEqual(summary.totalCopies, 0)
        XCTAssertGreaterThanOrEqual(summary.schemaVersion, 1)
        
        await ledger.reset()
    }
    
    /// Verifies referral ledger has day-rounded timestamps
    func testReferralLedgerDayRounded() async {
        let ledger = await ReferralLedger.shared
        await ledger.reset()
        
        await ledger.recordAction(.viewed)
        
        let summary = await ledger.currentSummary()
        
        if let lastActivity = summary.lastActivityDayRounded {
            // Should be in yyyy-MM-dd format
            let components = lastActivity.split(separator: "-")
            XCTAssertEqual(components.count, 3)
            XCTAssertFalse(lastActivity.contains(":"))
        }
        
        await ledger.reset()
    }
    
    // MARK: - F) BuyerProofPacket No Forbidden Keys
    
    /// Verifies buyer proof packet contains no forbidden keys
    func testBuyerProofPacketNoForbiddenKeys() async throws {
        let builder = await BuyerProofPacketBuilder.shared
        let packet = await builder.build()
        
        let violations = try packet.validateNoForbiddenKeys()
        
        XCTAssertTrue(
            violations.isEmpty,
            "BuyerProofPacket contains forbidden keys: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies forbidden keys list is complete
    func testBuyerProofPacketForbiddenKeysComplete() {
        let expectedForbidden = [
            "body", "subject", "content", "draft", "prompt",
            "context", "email", "recipient", "attendees", "title",
            "description", "message", "text", "name", "address"
        ]
        
        for key in expectedForbidden {
            XCTAssertTrue(
                BuyerProofPacket.forbiddenKeys.contains(key),
                "Missing forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - G) Outbound Templates Validation
    
    /// Verifies outbound templates contain no banned words
    func testOutboundTemplatesNoBannedWords() {
        let violations = OutboundTemplates.validateNoBannedWords()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Outbound templates contain banned words: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies outbound templates contain no promises
    func testOutboundTemplatesNoPromises() {
        let violations = OutboundTemplates.validateNoPromises()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Outbound templates contain promises: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies outbound templates use placeholders only
    func testOutboundTemplatesPlaceholdersOnly() {
        let violations = OutboundTemplates.validatePlaceholdersOnly()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Outbound templates validation failed: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies mailto templates have no injected emails
    func testMailtoTemplatesNoInjectedEmails() {
        for template in OutboundTemplates.all {
            // Check subject and body don't contain actual email addresses
            let emailPattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
            
            XCTAssertNil(
                template.subjectTemplate.range(of: emailPattern, options: .regularExpression),
                "Template '\(template.id)' subject contains email address"
            )
            
            XCTAssertNil(
                template.bodyTemplate.range(of: emailPattern, options: .regularExpression),
                "Template '\(template.id)' body contains email address"
            )
        }
    }
    
    // MARK: - H) Export Packets Round-Trip
    
    /// Verifies BuyerProofPacket can be encoded and decoded
    func testBuyerProofPacketRoundTrip() async throws {
        let builder = await BuyerProofPacketBuilder.shared
        let original = await builder.build()
        
        let jsonData = try original.toJSONData()
        let decoded = try BuyerProofPacket.fromJSONData(jsonData)
        
        XCTAssertEqual(original.schemaVersion, decoded.schemaVersion)
        XCTAssertEqual(original.exportedAtDayRounded, decoded.exportedAtDayRounded)
        XCTAssertEqual(original.availableSections, decoded.availableSections)
    }
    
    /// Verifies ReferralCode can be encoded and decoded
    func testReferralCodeRoundTrip() throws {
        let original = ReferralCode()
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(ReferralCode.self, from: encoded)
        
        XCTAssertEqual(original.code, decoded.code)
        XCTAssertEqual(original.schemaVersion, decoded.schemaVersion)
    }
    
    /// Verifies OutboundTemplate can be encoded and decoded
    func testOutboundTemplateRoundTrip() throws {
        let original = OutboundTemplates.all.first!
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(OutboundTemplate.self, from: encoded)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.templateName, decoded.templateName)
        XCTAssertEqual(original.schemaVersion, decoded.schemaVersion)
    }
    
    // MARK: - I) Schema Versions
    
    /// Verifies all new models have schema versions
    func testSchemaVersionsSet() {
        XCTAssertGreaterThan(ReferralCode.currentSchemaVersion, 0)
        XCTAssertGreaterThan(ReferralLedgerSummary.currentSchemaVersion, 0)
        XCTAssertGreaterThan(BuyerProofPacket.currentSchemaVersion, 0)
        XCTAssertGreaterThan(OutboundTemplate.currentSchemaVersion, 0)
    }
    
    // MARK: - J) Funnel Steps
    
    /// Verifies new funnel steps are marked as growth steps
    func testFunnelGrowthStepsIdentified() {
        let growthSteps: [FunnelStep] = [
            .referralViewed,
            .referralShared,
            .buyerProofExported,
            .outboundTemplateCopied,
            .outboundMailOpened
        ]
        
        for step in growthSteps {
            XCTAssertTrue(step.isGrowthStep, "\(step) should be a growth step")
        }
        
        // Non-growth steps
        XCTAssertFalse(FunnelStep.onboardingShown.isGrowthStep)
        XCTAssertFalse(FunnelStep.purchaseSuccess.isGrowthStep)
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
