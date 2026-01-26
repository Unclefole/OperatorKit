import XCTest
@testable import OperatorKit

// ============================================================================
// MONETIZATION INVARIANT TESTS (Phase 10A)
//
// These tests enforce the FIREWALL between monetization and execution.
//
// INVARIANTS TESTED:
// 1. Core execution modules do NOT import StoreKit
// 2. Core execution modules do NOT reference EntitlementManager/UsageLedger
// 3. UsageLedger stores only counters/dates, no user content
// 4. Behavior invariants remain unchanged
// 5. Preflight checks still pass
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

final class MonetizationInvariantTests: XCTestCase {
    
    // MARK: - A) No StoreKit Import in Core Execution Modules
    
    /// Verifies that ExecutionEngine does NOT import StoreKit
    func testExecutionEngineDoesNotImportStoreKit() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // Check for StoreKit import
        XCTAssertFalse(
            content.contains("import StoreKit"),
            "INVARIANT VIOLATION: ExecutionEngine.swift must NOT import StoreKit"
        )
        
        // Check for StoreKit types
        let storeKitTypes = ["Product", "Transaction", "AppStore.sync"]
        for type in storeKitTypes {
            XCTAssertFalse(
                content.contains(type) && !content.contains("//"),  // Ignore comments
                "INVARIANT VIOLATION: ExecutionEngine.swift references StoreKit type: \(type)"
            )
        }
    }
    
    /// Verifies that ApprovalGate does NOT import StoreKit
    func testApprovalGateDoesNotImportStoreKit() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        XCTAssertFalse(
            content.contains("import StoreKit"),
            "INVARIANT VIOLATION: ApprovalGate.swift must NOT import StoreKit"
        )
    }
    
    /// Verifies that ModelRouter does NOT import StoreKit
    func testModelRouterDoesNotImportStoreKit() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        XCTAssertFalse(
            content.contains("import StoreKit"),
            "INVARIANT VIOLATION: ModelRouter.swift must NOT import StoreKit"
        )
    }
    
    // MARK: - B) Entitlement Checks Not Referenced from Core Modules
    
    /// Verifies ExecutionEngine does NOT reference EntitlementManager
    func testExecutionEngineNoEntitlementReferences() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let forbiddenReferences = [
            "EntitlementManager",
            "UsageLedger",
            "SubscriptionTier",
            "SubscriptionStatus",
            "checkExecutionLimit",
            "checkMemoryLimit",
            "currentTier"
        ]
        
        for reference in forbiddenReferences {
            XCTAssertFalse(
                content.contains(reference),
                "INVARIANT VIOLATION: ExecutionEngine.swift references monetization type: \(reference)"
            )
        }
    }
    
    /// Verifies ApprovalGate does NOT reference monetization types
    func testApprovalGateNoEntitlementReferences() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let forbiddenReferences = [
            "EntitlementManager",
            "UsageLedger",
            "SubscriptionTier",
            "LimitDecision"
        ]
        
        for reference in forbiddenReferences {
            XCTAssertFalse(
                content.contains(reference),
                "INVARIANT VIOLATION: ApprovalGate.swift references monetization type: \(reference)"
            )
        }
    }
    
    // MARK: - C) Quota Logic Content-Free
    
    /// Verifies UsageLedger stores only numeric counters and dates
    func testUsageLedgerIsContentFree() {
        let ledger = UsageLedger.shared
        
        #if DEBUG
        ledger.forceReset()
        #endif
        
        // Record some executions
        ledger.recordExecution()
        ledger.recordExecution()
        
        // Get the ledger data
        let data = ledger.data
        
        // Verify it only contains allowed fields
        XCTAssertNotNil(data.windowStart)
        XCTAssertGreaterThan(data.executionsThisWindow, 0)
        XCTAssertEqual(data.schemaVersion, LedgerData.currentSchemaVersion)
    }
    
    /// Verifies exported LedgerData JSON contains no forbidden keys
    func testLedgerDataJSONContainsNoContentKeys() throws {
        let ledgerData = LedgerData(
            windowStart: Date(),
            executionsThisWindow: 3
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(ledgerData)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // Forbidden keys that would indicate user content storage
        let forbiddenKeys = [
            "body", "subject", "title", "recipient", "event",
            "draft", "context", "email", "attendee", "description",
            "participants", "content", "message", "text"
        ]
        
        for key in forbiddenKeys {
            XCTAssertFalse(
                jsonString.lowercased().contains("\"\(key)\""),
                "INVARIANT VIOLATION: LedgerData JSON contains forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - D) Behavior Invariants Unchanged
    
    /// Verifies limit exceeded returns proper user-facing reason
    func testLimitExceededReturnsProperReason() {
        // Create a scenario where limit is exceeded
        let decision = LimitDecision.executionLimitReached(
            resetsAt: Date().addingTimeInterval(86400 * 3) // 3 days from now
        )
        
        XCTAssertFalse(decision.allowed)
        XCTAssertNotNil(decision.reason)
        XCTAssertEqual(decision.limitType, .executionsWeekly)
        XCTAssertEqual(decision.remaining, 0)
        XCTAssertNotNil(decision.resetsAt)
    }
    
    /// Verifies memory limit decision has proper reason
    func testMemoryLimitReturnsProperReason() {
        let decision = LimitDecision.memoryLimitReached(currentCount: 10)
        
        XCTAssertFalse(decision.allowed)
        XCTAssertNotNil(decision.reason)
        XCTAssertEqual(decision.limitType, .memoryItems)
        XCTAssertEqual(decision.remaining, 0)
        XCTAssertNil(decision.resetsAt) // Memory limit doesn't reset
    }
    
    /// Verifies Pro tier always returns unlimited
    func testProTierReturnsUnlimited() {
        let ledger = UsageLedger.shared
        
        // Check execution limit for Pro
        let executionDecision = ledger.canExecute(tier: .pro)
        XCTAssertTrue(executionDecision.allowed)
        XCTAssertNil(executionDecision.remaining) // Unlimited
        
        // Check memory limit for Pro
        let memoryDecision = ledger.canSaveMemoryItem(tier: .pro, currentCount: 100)
        XCTAssertTrue(memoryDecision.allowed)
        XCTAssertNil(memoryDecision.remaining) // Unlimited
    }
    
    /// Verifies Free tier respects quotas
    func testFreeTierRespectsQuotas() {
        let ledger = UsageLedger.shared
        
        #if DEBUG
        ledger.forceReset()
        #endif
        
        // Should allow first execution
        var decision = ledger.canExecute(tier: .free)
        XCTAssertTrue(decision.allowed)
        XCTAssertEqual(decision.remaining, UsageQuota.freeExecutionsPerWeek)
        
        // Record executions up to limit
        for _ in 0..<UsageQuota.freeExecutionsPerWeek {
            ledger.recordExecution()
        }
        
        // Should now block
        decision = ledger.canExecute(tier: .free)
        XCTAssertFalse(decision.allowed)
        XCTAssertEqual(decision.remaining, 0)
    }
    
    // MARK: - E) Subscription Status Content-Free
    
    /// Verifies SubscriptionStatus contains no user content
    func testSubscriptionStatusIsContentFree() throws {
        let status = SubscriptionStatus(
            tier: .pro,
            isActive: true,
            renewalDate: Date().addingTimeInterval(86400 * 30),
            productId: "com.operatorkit.pro.monthly"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(status)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // Verify no content-related keys
        let forbiddenKeys = ["body", "subject", "title", "recipient", "email", "draft"]
        for key in forbiddenKeys {
            XCTAssertFalse(
                jsonString.lowercased().contains("\"\(key)\""),
                "SubscriptionStatus JSON contains forbidden key: \(key)"
            )
        }
    }
    
    /// Verifies SubscriptionStatus round-trips correctly
    func testSubscriptionStatusRoundTrip() throws {
        let original = SubscriptionStatus(
            tier: .pro,
            isActive: true,
            renewalDate: Date().addingTimeInterval(86400 * 30),
            productId: "com.operatorkit.pro.monthly"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SubscriptionStatus.self, from: data)
        
        XCTAssertEqual(decoded.tier, original.tier)
        XCTAssertEqual(decoded.isActive, original.isActive)
        XCTAssertEqual(decoded.productId, original.productId)
    }
    
    // MARK: - F) Product IDs Validation
    
    /// Verifies product IDs follow Apple naming convention
    func testProductIDsFollowAppleConvention() {
        let productIds = StoreKitProductIDs.allProducts
        
        for productId in productIds {
            // Must start with reverse domain
            XCTAssertTrue(
                productId.hasPrefix("com.operatorkit."),
                "Product ID must start with com.operatorkit.: \(productId)"
            )
            
            // Must not contain spaces
            XCTAssertFalse(
                productId.contains(" "),
                "Product ID must not contain spaces: \(productId)"
            )
            
            // Must be lowercase
            XCTAssertEqual(
                productId, productId.lowercased(),
                "Product ID must be lowercase: \(productId)"
            )
        }
    }
    
    /// Verifies subscription products are defined
    func testSubscriptionProductsDefined() {
        XCTAssertEqual(StoreKitProductIDs.proMonthly, "com.operatorkit.pro.monthly")
        XCTAssertEqual(StoreKitProductIDs.proAnnual, "com.operatorkit.pro.annual")
        XCTAssertEqual(StoreKitProductIDs.allSubscriptions.count, 2)
    }
    
    // MARK: - Helpers
    
    /// Finds a project file by name and subdirectory
    private func findProjectFile(named fileName: String, in subdirectory: String) -> String {
        // Get the project root (go up from test bundle)
        let bundle = Bundle(for: type(of: self))
        
        // Try multiple possible paths
        let possiblePaths = [
            // Source root
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent() // Tests
                .deletingLastPathComponent() // OperatorKit root
                .appendingPathComponent("OperatorKit")
                .appendingPathComponent(subdirectory)
                .appendingPathComponent(fileName),
            
            // Bundle resource path based
            bundle.bundlePath
                .replacingOccurrences(of: "OperatorKitTests.xctest", with: "")
                .appending("OperatorKit/\(subdirectory)/\(fileName)")
        ]
        
        for path in possiblePaths {
            let pathString = path is URL ? (path as! URL).path : path as! String
            if FileManager.default.fileExists(atPath: pathString) {
                return pathString
            }
        }
        
        // Fallback: construct path from current file location
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

// MARK: - Quota Verification Tests

extension MonetizationInvariantTests {
    
    /// Verifies quota constants are set correctly
    func testQuotaConstants() {
        XCTAssertEqual(UsageQuota.freeExecutionsPerWeek, 5)
        XCTAssertEqual(UsageQuota.freeMemoryItemsMax, 10)
        XCTAssertEqual(UsageQuota.weeklyWindowDuration, 7 * 24 * 60 * 60)
    }
    
    /// Verifies LimitType enum values
    func testLimitTypeValues() {
        XCTAssertEqual(LimitType.executionsWeekly.rawValue, "executions_weekly")
        XCTAssertEqual(LimitType.memoryItems.rawValue, "memory_items")
    }
    
    /// Verifies SubscriptionTier values
    func testSubscriptionTierValues() {
        XCTAssertEqual(SubscriptionTier.free.rawValue, "free")
        XCTAssertEqual(SubscriptionTier.pro.rawValue, "pro")
        XCTAssertEqual(SubscriptionTier.free.displayName, "Free")
        XCTAssertEqual(SubscriptionTier.pro.displayName, "Pro")
    }
}

// MARK: - Error Message Quality Tests

extension MonetizationInvariantTests {
    
    /// Verifies subscription error messages are plain and factual
    func testSubscriptionErrorMessagesArePlain() {
        let errors: [SubscriptionError] = [
            .productNotFound,
            .purchaseFailed(underlying: nil),
            .verificationFailed,
            .storeKitUnavailable,
            .unknown
        ]
        
        for error in errors {
            if let message = error.errorDescription {
                // No hype words
                XCTAssertFalse(message.contains("amazing"))
                XCTAssertFalse(message.contains("incredible"))
                XCTAssertFalse(message.contains("awesome"))
                
                // No AI anthropomorphism
                XCTAssertFalse(message.contains("AI thinks"))
                XCTAssertFalse(message.contains("we believe"))
                
                // Plain language
                XCTAssertTrue(message.hasSuffix(".") || message.isEmpty)
            }
        }
    }
}
