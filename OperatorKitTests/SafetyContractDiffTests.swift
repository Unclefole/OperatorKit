import XCTest
@testable import OperatorKit

/// Tests for safety contract diff enforcement (Phase 8C)
///
/// These tests ensure that any changes to SAFETY_CONTRACT.md are intentional.
/// If a test fails, it means the safety contract has been modified.
///
/// To fix a failing test after an INTENTIONAL change:
/// 1. Review the change to ensure it's approved
/// 2. Update SafetyContractSnapshot.expectedHash
/// 3. Update SafetyContractSnapshot.lastUpdateReason
/// 4. Add changelog entry to SAFETY_CONTRACT.md
/// 5. Run tests again
final class SafetyContractDiffTests: XCTestCase {
    
    // MARK: - Core Diff Test
    
    /// CRITICAL: This test fails if SAFETY_CONTRACT.md has been modified
    /// without updating the expected hash.
    ///
    /// This is intentional friction to prevent silent safety guarantee drift.
    func testSafetyContractUnchanged() {
        let status = SafetyContractSnapshot.getStatus()
        
        // If file not found, skip in development but fail in CI
        if status.matchStatus == .notFound {
            #if DEBUG
            // In development, log warning but don't fail
            print("⚠️ SAFETY_CONTRACT.md not found - skipping diff check in DEBUG")
            return
            #else
            XCTFail("SAFETY_CONTRACT.md not found in release build")
            return
            #endif
        }
        
        // Print diagnostic info for debugging
        print("""
        
        ========================================
        SAFETY CONTRACT DIFF CHECK
        ========================================
        Expected Hash: \(status.expectedHash)
        Current Hash:  \(status.currentHash ?? "nil")
        Status:        \(status.matchStatus.rawValue)
        Last Update:   \(status.lastUpdateReason)
        ========================================
        
        """)
        
        // If hash is PENDING_INITIAL_HASH, this is first run
        if SafetyContractSnapshot.expectedHash == "PENDING_INITIAL_HASH" {
            if let currentHash = status.currentHash {
                print("""
                
                ⚠️ INITIAL SETUP REQUIRED
                
                This appears to be the first run of safety contract diff enforcement.
                Update SafetyContractSnapshot.expectedHash to:
                
                    \(currentHash)
                
                """)
            }
            // Don't fail on initial setup
            return
        }
        
        // Main assertion
        XCTAssertTrue(
            status.isValid,
            """
            
            ❌ SAFETY CONTRACT MODIFIED
            
            The safety contract (docs/SAFETY_CONTRACT.md) has been modified.
            
            If this change is INTENTIONAL:
            1. Update SafetyContractSnapshot.expectedHash to: \(status.currentHash ?? "unknown")
            2. Update SafetyContractSnapshot.lastUpdateReason
            3. Add changelog entry to SAFETY_CONTRACT.md
            4. Ensure change is reviewed and approved
            5. Run tests again
            
            If this change is UNINTENTIONAL:
            1. Revert the changes to SAFETY_CONTRACT.md
            2. Run tests again
            
            This friction is intentional. Safety guarantees must not drift silently.
            
            """
        )
    }
    
    // MARK: - Schema Tests
    
    func testSchemaVersionIsSet() {
        XCTAssertGreaterThan(
            SafetyContractSnapshot.schemaVersion,
            0,
            "Schema version must be set"
        )
    }
    
    func testLastUpdateReasonIsSet() {
        XCTAssertFalse(
            SafetyContractSnapshot.lastUpdateReason.isEmpty,
            "Last update reason must be documented"
        )
    }
    
    // MARK: - Export Tests
    
    func testExportContainsRequiredFields() throws {
        let export = SafetyContractExport()
        let jsonData = try export.toJSON()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        
        // Verify required fields
        XCTAssertTrue(jsonString.contains("schemaVersion"))
        XCTAssertTrue(jsonString.contains("exportedAt"))
        XCTAssertTrue(jsonString.contains("expectedHash"))
        XCTAssertTrue(jsonString.contains("isUnchanged"))
        XCTAssertTrue(jsonString.contains("matchStatus"))
        XCTAssertTrue(jsonString.contains("lastUpdateReason"))
    }
    
    func testExportIsValidJSON() throws {
        let export = SafetyContractExport()
        let jsonData = try export.toJSON()
        
        // Should be parseable
        let parsed = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(parsed as? [String: Any])
    }
    
    // MARK: - Status Type Tests
    
    func testMatchStatusDisplayNames() {
        XCTAssertEqual(SafetyContractStatus.MatchStatus.matched.displayName, "Matched")
        XCTAssertEqual(SafetyContractStatus.MatchStatus.modified.displayName, "Modified")
        XCTAssertEqual(SafetyContractStatus.MatchStatus.notFound.displayName, "Not Found")
    }
    
    func testMatchStatusSystemImages() {
        XCTAssertFalse(SafetyContractStatus.MatchStatus.matched.systemImage.isEmpty)
        XCTAssertFalse(SafetyContractStatus.MatchStatus.modified.systemImage.isEmpty)
        XCTAssertFalse(SafetyContractStatus.MatchStatus.notFound.systemImage.isEmpty)
    }
}
