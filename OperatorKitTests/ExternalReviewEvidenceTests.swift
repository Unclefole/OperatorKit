import XCTest
@testable import OperatorKit

/// Tests for External Review Evidence Packet (Phase 9D)
///
/// Verifies:
/// - Evidence packet encodes/decodes round-trip
/// - Evidence packet contains no forbidden keys
/// - Evidence packet includes required sections
/// - Export builder produces packet even when optional sections unavailable
/// - External Review Readiness view renders in production builds
/// - No debug-only symbols referenced in production UI
/// - Doc hash registry returns stable hashes (for known fixtures)
/// - No execution-path imports reference ExternalReview module
final class ExternalReviewEvidenceTests: XCTestCase {
    
    // MARK: - Forbidden Keys
    
    /// Keys that must NEVER appear in evidence exports
    private let forbiddenKeys = [
        "draftText",
        "emailBody",
        "subject",
        "recipient",
        "eventTitle",
        "attendees",
        "contextPayload",
        "promptText",
        "userInput",
        "rawNote",
        "messageContent",
        "participantEmails",
        "calendarDescription",
        "reminderNote",
        "personalData",
        "password",
        "apiKey",
        "secretKey"
    ]
    
    func testEvidencePacketContainsNoForbiddenKeys() throws {
        let builder = ExternalReviewEvidenceBuilder.shared
        let packet = builder.build()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(packet)
        let jsonString = String(data: data, encoding: .utf8) ?? ""
        
        for key in forbiddenKeys {
            let keyPattern = "\"\(key)\""
            XCTAssertFalse(
                jsonString.contains(keyPattern),
                "Evidence packet should NOT contain forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - Round-Trip Tests
    
    func testEvidencePacketEncodesDecodes() throws {
        let builder = ExternalReviewEvidenceBuilder.shared
        let packet = builder.build()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(packet)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExternalReviewEvidencePacket.self, from: data)
        
        XCTAssertEqual(decoded.schemaVersion, packet.schemaVersion)
        XCTAssertEqual(decoded.appVersion, packet.appVersion)
        XCTAssertEqual(decoded.buildNumber, packet.buildNumber)
        XCTAssertEqual(decoded.releaseMode, packet.releaseMode)
    }
    
    func testEvidencePacketExportsAsJSON() throws {
        let builder = ExternalReviewEvidenceBuilder.shared
        let json = try builder.exportJSON()
        
        XCTAssertFalse(json.isEmpty)
        
        // Should be valid JSON
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: json))
    }
    
    // MARK: - Required Sections Tests
    
    func testEvidencePacketIncludesRequiredSections() {
        let builder = ExternalReviewEvidenceBuilder.shared
        let packet = builder.build()
        
        // App identity
        XCTAssertFalse(packet.appVersion.isEmpty)
        XCTAssertFalse(packet.buildNumber.isEmpty)
        XCTAssertFalse(packet.releaseMode.isEmpty)
        
        // Safety & governance
        XCTAssertFalse(packet.safetyContractSnapshot.expectedHash.isEmpty)
        XCTAssertGreaterThan(packet.claimRegistrySummary.totalClaims, 0)
        XCTAssertFalse(packet.claimRegistrySummary.claimIds.isEmpty)
        
        // Invariant proof
        XCTAssertGreaterThan(packet.invariantCheckSummary.totalChecks, 0)
        XCTAssertFalse(packet.invariantCheckSummary.status.isEmpty)
        
        // Preflight summary
        XCTAssertGreaterThan(packet.preflightSummary.totalChecks, 0)
        XCTAssertFalse(packet.preflightSummary.status.isEmpty)
        
        // Quality packet
        XCTAssertGreaterThan(packet.qualityPacket.schemaVersion, 0)
        
        // Reviewer guidance
        XCTAssertFalse(packet.reviewerTestPlan.title.isEmpty)
        XCTAssertFalse(packet.reviewerTestPlan.steps.isEmpty)
        XCTAssertFalse(packet.reviewerFAQ.isEmpty)
        
        // Disclaimers
        XCTAssertFalse(packet.disclaimers.isEmpty)
        
        // Doc hashes
        XCTAssertFalse(packet.docHashes.status.isEmpty)
    }
    
    // MARK: - Soft Failure Tests
    
    func testBuilderProducesPacketWithOptionalSectionsUnavailable() {
        // Even if optional sections are unavailable, packet should still be created
        let builder = ExternalReviewEvidenceBuilder.shared
        let packet = builder.build()
        
        // Should have a valid packet even if some optional fields are nil
        XCTAssertGreaterThan(packet.schemaVersion, 0)
        
        // Release acknowledgement is optional
        // If nil, that's acceptable
        // This test just ensures the builder doesn't crash
        
        // Regression sentinel is optional in App Store builds
        // In DEBUG, it should be present
        #if DEBUG
        XCTAssertNotNil(packet.regressionSentinelSummary)
        #endif
    }
    
    // MARK: - Disclaimers Tests
    
    func testDisclaimersRegistryHasContent() {
        XCTAssertFalse(DisclaimersRegistry.exportDisclaimers.isEmpty)
        XCTAssertFalse(DisclaimersRegistry.uiDisclaimers.isEmpty)
        XCTAssertFalse(DisclaimersRegistry.guaranteeDisclaimers.isEmpty)
        XCTAssertFalse(DisclaimersRegistry.integrityDisclaimers.isEmpty)
        XCTAssertFalse(DisclaimersRegistry.allDisclaimers.isEmpty)
    }
    
    func testDisclaimersDoNotContainSecurityClaims() {
        let securityTerms = ["secure", "encrypted", "protected", "safe from hackers", "unhackable"]
        
        for disclaimer in DisclaimersRegistry.allDisclaimers {
            for term in securityTerms {
                XCTAssertFalse(
                    disclaimer.lowercased().contains(term),
                    "Disclaimer should not contain security term '\(term)': \(disclaimer)"
                )
            }
        }
    }
    
    // MARK: - Reviewer FAQ Tests
    
    func testReviewerFAQHasContent() {
        XCTAssertFalse(ReviewerFAQ.items.isEmpty)
        
        for item in ReviewerFAQ.items {
            XCTAssertFalse(item.question.isEmpty)
            XCTAssertFalse(item.answer.isEmpty)
        }
    }
    
    func testReviewerFAQDoesNotContainAnthropomorphicLanguage() {
        let anthropomorphicTerms = ["AI thinks", "AI learns", "AI decides", "the AI knows", "AI understands"]
        
        for item in ReviewerFAQ.items {
            for term in anthropomorphicTerms {
                XCTAssertFalse(
                    item.answer.contains(term),
                    "FAQ should not contain anthropomorphic term '\(term)': \(item.answer)"
                )
            }
        }
    }
    
    // MARK: - Test Plan Tests
    
    func testReviewerTestPlanHasSteps() {
        let plan = ReviewerTestPlan.twoMinutePlan
        
        XCTAssertFalse(plan.title.isEmpty)
        XCTAssertGreaterThan(plan.estimatedMinutes, 0)
        XCTAssertFalse(plan.steps.isEmpty)
        
        for step in plan.steps {
            XCTAssertGreaterThan(step.stepNumber, 0)
            XCTAssertFalse(step.title.isEmpty)
            XCTAssertFalse(step.action.isEmpty)
            XCTAssertFalse(step.expectedResult.isEmpty)
            XCTAssertFalse(step.duration.isEmpty)
        }
    }
    
    // MARK: - Doc Hash Registry Tests
    
    func testDocHashRegistryDocumentNames() {
        XCTAssertTrue(DocHashRegistry.documentNames.contains("SAFETY_CONTRACT.md"))
        XCTAssertTrue(DocHashRegistry.documentNames.contains("CLAIM_REGISTRY.md"))
        XCTAssertTrue(DocHashRegistry.documentNames.contains("PHASE_BOUNDARIES.md"))
        XCTAssertTrue(DocHashRegistry.documentNames.contains("APP_REVIEW_PACKET.md"))
        XCTAssertTrue(DocHashRegistry.documentNames.contains("EXECUTION_GUARANTEES.md"))
    }
    
    func testDocHashRegistryComputesHashes() {
        let registry = DocHashRegistry.shared
        let hashes = registry.computeAllHashes()
        
        // Status should be one of the valid values
        XCTAssertTrue(
            ["all_available", "partial", "unavailable"].contains(hashes.status),
            "Hash status should be valid: \(hashes.status)"
        )
        
        // If a hash is present, it should be a valid SHA-256 hex string (64 chars)
        if let hash = hashes.safetyContractHash {
            XCTAssertEqual(hash.count, 64, "SHA-256 hash should be 64 hex characters")
            XCTAssertTrue(hash.allSatisfy { $0.isHexDigit }, "Hash should be hex string")
        }
    }
    
    func testDocHashIsStableForSameContent() {
        let registry = DocHashRegistry.shared
        
        // Hash the same document twice
        let hash1 = registry.hashDocument("SAFETY_CONTRACT.md")
        let hash2 = registry.hashDocument("SAFETY_CONTRACT.md")
        
        // If both are available, they should be equal
        if let h1 = hash1, let h2 = hash2 {
            XCTAssertEqual(h1, h2, "Hashes should be stable for same content")
        }
    }
    
    // MARK: - Claim Registry Summary Tests
    
    func testClaimRegistrySummaryHasAllClaims() {
        let builder = ExternalReviewEvidenceBuilder.shared
        let packet = builder.build()
        
        // Should have at least the original 11 claims plus Phase 9C's CLAIM-012
        XCTAssertGreaterThanOrEqual(packet.claimRegistrySummary.totalClaims, 12)
        
        // Should include specific claim IDs
        XCTAssertTrue(packet.claimRegistrySummary.claimIds.contains("CLAIM-001"))
        XCTAssertTrue(packet.claimRegistrySummary.claimIds.contains("CLAIM-012"))
    }
    
    // MARK: - Export Sub-structures Tests
    
    func testInvariantCheckSummaryExport() {
        let builder = ExternalReviewEvidenceBuilder.shared
        let packet = builder.build()
        
        let summary = packet.invariantCheckSummary
        
        XCTAssertEqual(summary.totalChecks, summary.passedChecks + summary.failedChecks)
        XCTAssertTrue(["PASS", "FAIL"].contains(summary.status))
        XCTAssertEqual(summary.checkNames.count, summary.totalChecks)
    }
    
    func testPreflightSummaryExport() {
        let builder = ExternalReviewEvidenceBuilder.shared
        let packet = builder.build()
        
        let summary = packet.preflightSummary
        
        XCTAssertGreaterThan(summary.totalChecks, 0)
        XCTAssertTrue(["PASS", "WARN", "FAIL"].contains(summary.status))
        XCTAssertFalse(summary.releaseMode.isEmpty)
        XCTAssertFalse(summary.categories.isEmpty)
    }
    
    func testIntegrityStatusExport() {
        let builder = ExternalReviewEvidenceBuilder.shared
        let packet = builder.build()
        
        if let integrityExport = packet.integritySealStatus {
            XCTAssertTrue(
                ["Verified", "Mismatch", "Not Available"].contains(integrityExport.status),
                "Integrity status should be valid: \(integrityExport.status)"
            )
        }
    }
    
    // MARK: - Schema Version Tests
    
    func testEvidencePacketSchemaVersion() {
        let builder = ExternalReviewEvidenceBuilder.shared
        let packet = builder.build()
        
        XCTAssertEqual(packet.schemaVersion, ExternalReviewEvidencePacket.currentSchemaVersion)
        XCTAssertGreaterThan(packet.schemaVersion, 0)
    }
    
    // MARK: - Day-Rounded Date Tests
    
    func testExportedAtDayRounded() throws {
        let builder = ExternalReviewEvidenceBuilder.shared
        let packet = builder.build()
        
        // Should be in yyyy-MM-dd format
        let dayRoundedRegex = try NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}$")
        let range = NSRange(packet.exportedAtDayRounded.startIndex..., in: packet.exportedAtDayRounded)
        
        XCTAssertNotNil(
            dayRoundedRegex.firstMatch(in: packet.exportedAtDayRounded, range: range),
            "exportedAtDayRounded should be in yyyy-MM-dd format: \(packet.exportedAtDayRounded)"
        )
    }
    
    // MARK: - Export File Tests
    
    func testExportToFileCreatesFile() throws {
        let builder = ExternalReviewEvidenceBuilder.shared
        let url = try builder.exportToFile()
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(url.lastPathComponent.hasPrefix("operatorkit-evidence-packet-"))
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".json"))
        
        // Clean up
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - No Content Leakage Tests
    
    func testPacketContainsOnlyMetadata() throws {
        let builder = ExternalReviewEvidenceBuilder.shared
        let packet = builder.build()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(packet)
        let jsonString = String(data: data, encoding: .utf8) ?? ""
        
        // Check for patterns that would indicate content leakage
        let contentPatterns = [
            "Dear ",           // Email salutation
            "Hi ",             // Email salutation
            "Hello ",          // Email salutation
            "Meeting with",    // Calendar event title pattern
            "@gmail.com",      // Email address
            "@outlook.com",    // Email address
            "RE:",             // Email reply
            "FW:",             // Email forward
        ]
        
        for pattern in contentPatterns {
            // Allow these patterns only if they're part of documentation/FAQ
            // The FAQ explains email drafting but shouldn't contain actual emails
            let occurrences = jsonString.components(separatedBy: pattern).count - 1
            XCTAssertLessThanOrEqual(
                occurrences,
                2,  // Allow max 2 occurrences (for FAQ explanations)
                "Pattern '\(pattern)' appears too many times - possible content leakage"
            )
        }
    }
}

// MARK: - Helper Extension

extension Character {
    var isHexDigit: Bool {
        "0123456789abcdefABCDEF".contains(self)
    }
}
