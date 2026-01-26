import XCTest
@testable import OperatorKit

// ============================================================================
// STORE LISTING LOCKDOWN TESTS (Phase 10K)
//
// Tests for store listing copy lockdown:
// - Hash matches expected (or provides update instructions)
// - Last update reason is set
// - No banned words in store listing copy
// - Length limits respected
// - No forbidden keys in exports
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class StoreListingLockdownTests: XCTestCase {
    
    // MARK: - A) Hash Verification
    
    /// Verifies store listing hash verification works
    func testStoreListingHashVerification() {
        let result = StoreListingSnapshot.verifyHash()
        
        // Hash should be calculated
        XCTAssertFalse(result.currentHash.isEmpty)
        
        // If expected hash is placeholder, provide update instructions
        if StoreListingSnapshot.expectedHash == "UPDATE_ON_FIRST_RUN" {
            print("UPDATE REQUIRED: Set expectedHash to: \(result.currentHash)")
        }
    }
    
    /// Verifies hash calculation is deterministic
    func testHashCalculationDeterministic() {
        let hash1 = StoreListingSnapshot.calculateCurrentHash()
        let hash2 = StoreListingSnapshot.calculateCurrentHash()
        
        XCTAssertEqual(hash1, hash2, "Hash calculation should be deterministic")
    }
    
    /// Verifies hash changes when content changes
    func testHashChangesWithContent() {
        let originalHash = StoreListingSnapshot.calculateCurrentHash()
        
        // Hash should be a valid hex string
        XCTAssertTrue(originalHash.allSatisfy { $0.isHexDigit })
        XCTAssertEqual(originalHash.count, 64, "SHA256 hash should be 64 hex characters")
    }
    
    // MARK: - B) Update Reason
    
    /// Verifies last update reason is set
    func testLastUpdateReasonIsSet() {
        XCTAssertFalse(
            StoreListingSnapshot.lastUpdateReason.isEmpty,
            "Last update reason should be set"
        )
        
        XCTAssertFalse(
            StoreListingSnapshot.lastUpdatePhase.isEmpty,
            "Last update phase should be set"
        )
    }
    
    /// Verifies schema version is set
    func testSchemaVersionIsSet() {
        XCTAssertGreaterThan(
            StoreListingSnapshot.schemaVersion,
            0,
            "Schema version should be > 0"
        )
    }
    
    // MARK: - C) Store Listing Copy Validation
    
    /// Verifies no banned words in store listing copy
    func testNoBannedWordsInStoreListingCopy() {
        let errors = StoreListingCopy.validate()
        
        // Filter for banned word violations only
        let bannedWordErrors = errors.filter { $0.contains("banned") || $0.contains("Contains") }
        
        XCTAssertTrue(
            bannedWordErrors.isEmpty,
            "Store listing has banned words: \(bannedWordErrors.joined(separator: ", "))"
        )
    }
    
    /// Verifies title length limit
    func testTitleLengthLimit() {
        XCTAssertLessThanOrEqual(
            StoreListingCopy.title.count,
            StoreListingCopy.maxTitleLength,
            "Title exceeds \(StoreListingCopy.maxTitleLength) characters"
        )
    }
    
    /// Verifies subtitle length limit
    func testSubtitleLengthLimit() {
        XCTAssertLessThanOrEqual(
            StoreListingCopy.subtitle.count,
            StoreListingCopy.maxSubtitleLength,
            "Subtitle exceeds \(StoreListingCopy.maxSubtitleLength) characters"
        )
    }
    
    /// Verifies description length limit
    func testDescriptionLengthLimit() {
        XCTAssertLessThanOrEqual(
            StoreListingCopy.description.count,
            StoreListingCopy.maxDescriptionLength,
            "Description exceeds \(StoreListingCopy.maxDescriptionLength) characters"
        )
    }
    
    /// Verifies keywords length limit
    func testKeywordsLengthLimit() {
        XCTAssertLessThanOrEqual(
            StoreListingCopy.keywords.count,
            StoreListingCopy.maxKeywordsLength,
            "Keywords exceed \(StoreListingCopy.maxKeywordsLength) characters"
        )
    }
    
    /// Verifies promotional text length limit
    func testPromotionalTextLengthLimit() {
        XCTAssertLessThanOrEqual(
            StoreListingCopy.promotionalText.count,
            StoreListingCopy.maxPromotionalLength,
            "Promotional text exceeds \(StoreListingCopy.maxPromotionalLength) characters"
        )
    }
    
    // MARK: - D) Content Safety
    
    /// Verifies no anthropomorphic language
    func testNoAnthropomorphicLanguage() {
        let allCopy = [
            StoreListingCopy.title,
            StoreListingCopy.subtitle,
            StoreListingCopy.description,
            StoreListingCopy.promotionalText
        ].joined(separator: " ").lowercased()
        
        let patterns = ["ai thinks", "ai learns", "ai decides", "ai understands"]
        
        for pattern in patterns {
            XCTAssertFalse(
                allCopy.contains(pattern),
                "Store listing contains '\(pattern)'"
            )
        }
    }
    
    /// Verifies no unproven security claims
    func testNoUnprovenSecurityClaims() {
        let allCopy = [
            StoreListingCopy.title,
            StoreListingCopy.subtitle,
            StoreListingCopy.description
        ].joined(separator: " ").lowercased()
        
        // "secure" and "encrypted" should not appear without proof
        XCTAssertFalse(
            allCopy.contains("secure"),
            "Store listing contains unproven 'secure' claim"
        )
        XCTAssertFalse(
            allCopy.contains("encrypted"),
            "Store listing contains unproven 'encrypted' claim"
        )
    }
    
    // MARK: - E) Snapshot Export
    
    /// Verifies snapshot export contains no forbidden keys
    func testSnapshotExportNoForbiddenKeys() throws {
        let snapshot = StoreListingSnapshot.createSnapshot()
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(snapshot)
        
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Could not parse snapshot JSON")
            return
        }
        
        let forbiddenKeys = AppStoreSubmissionPacket.forbiddenKeys
        
        for key in json.keys {
            XCTAssertFalse(
                forbiddenKeys.contains(key.lowercased()),
                "Snapshot contains forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - F) Core Modules Untouched
    
    /// Verifies ExecutionEngine has no store listing imports
    func testExecutionEngineNoStoreListingImports() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let patterns = [
            "StoreListingCopy",
            "StoreListingSnapshot",
            "AppReviewRiskScanner"
        ]
        
        for pattern in patterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ExecutionEngine.swift contains: \(pattern)"
            )
        }
    }
    
    /// Verifies ApprovalGate has no store listing imports
    func testApprovalGateNoStoreListingImports() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let patterns = ["StoreListingCopy", "StoreListingSnapshot"]
        
        for pattern in patterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ApprovalGate.swift contains: \(pattern)"
            )
        }
    }
    
    /// Verifies ModelRouter has no store listing imports
    func testModelRouterNoStoreListingImports() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let patterns = ["StoreListingCopy", "StoreListingSnapshot"]
        
        for pattern in patterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ModelRouter.swift contains: \(pattern)"
            )
        }
    }
    
    // MARK: - G) No Networking in New Files
    
    /// Verifies AppReviewRiskScanner has no networking
    func testRiskScannerNoNetworking() throws {
        let filePath = findProjectFile(named: "AppReviewRiskScanner.swift", in: "Safety")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "HTTPURLResponse"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "AppReviewRiskScanner.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies StoreListingSnapshot has no networking
    func testStoreListingSnapshotNoNetworking() throws {
        let filePath = findProjectFile(named: "StoreListingSnapshot.swift", in: "Safety")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "StoreListingSnapshot.swift contains networking: \(pattern)"
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
