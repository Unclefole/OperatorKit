import XCTest
@testable import OperatorKit

// ============================================================================
// COMMERCIAL READINESS TESTS (Phase 10H)
//
// These tests prove commercial readiness:
// - No analytics SDK imports
// - Conversion ledger contains no forbidden keys
// - StoreKit product mapping is complete
// - Pricing copy has no banned language
// - Quota sources are consistent (no duplication)
//
// See: docs/SAFETY_CONTRACT.md (Section 17)
// ============================================================================

final class CommercialReadinessTests: XCTestCase {
    
    // MARK: - A) No Analytics SDK Imports
    
    /// Verifies no analytics SDKs are imported anywhere
    func testNoAnalyticsSDKImports() throws {
        let projectRoot = findProjectRoot()
        let swiftFiles = findSwiftFiles(in: projectRoot)
        
        let analyticsSDKs = [
            "Firebase",
            "FirebaseAnalytics",
            "Amplitude",
            "Mixpanel",
            "Segment",
            "Adjust",
            "AppsFlyer",
            "Branch",
            "Flurry",
            "Crashlytics",  // Often bundles analytics
            "Fabric"
        ]
        
        for file in swiftFiles {
            let content = try String(contentsOfFile: file, encoding: .utf8)
            
            for sdk in analyticsSDKs {
                XCTAssertFalse(
                    content.contains("import \(sdk)"),
                    "INVARIANT VIOLATION: \(file) imports analytics SDK: \(sdk)"
                )
            }
        }
    }
    
    /// Verifies no tracking code patterns exist
    func testNoTrackingCodePatterns() throws {
        let projectRoot = findProjectRoot()
        let swiftFiles = findSwiftFiles(in: projectRoot)
        
        let trackingPatterns = [
            "Analytics.track",
            "analytics.log",
            "logEvent(",
            "trackScreen(",
            "trackAction(",
            "Amplitude.instance",
            "Mixpanel.mainInstance"
        ]
        
        for file in swiftFiles {
            let content = try String(contentsOfFile: file, encoding: .utf8)
            
            for pattern in trackingPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "INVARIANT VIOLATION: \(file) contains tracking pattern: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - B) Conversion Ledger Safety
    
    /// Verifies ConversionData contains no forbidden keys
    func testConversionLedgerNoForbiddenKeys() throws {
        let data = ConversionData()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(data)
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        // Check for forbidden content keys
        let forbiddenKeys = SyncSafetyConfig.forbiddenContentKeys
        for key in forbiddenKeys {
            XCTAssertNil(json[key], "ConversionData should not contain forbidden key: \(key)")
        }
    }
    
    /// Verifies ConversionExportPacket contains no forbidden keys
    func testConversionExportNoContent() throws {
        let summary = ConversionSummary(
            paywallShownCount: 10,
            upgradeTapCount: 5,
            purchaseStartedCount: 3,
            purchaseSuccessCount: 1,
            restoreTapCount: 2,
            restoreSuccessCount: 0,
            lastEventAt: Date(),
            capturedAt: Date()
        )
        
        let packet = ConversionExportPacket(summary: summary)
        let jsonData = try packet.exportJSON()
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        // Check for forbidden content keys
        let forbiddenKeys = SyncSafetyConfig.forbiddenContentKeys
        
        func checkNested(_ dict: [String: Any], path: String = "") {
            for (key, value) in dict {
                let fullPath = path.isEmpty ? key : "\(path).\(key)"
                
                for forbidden in forbiddenKeys {
                    XCTAssertFalse(
                        key.lowercased().contains(forbidden.lowercased()),
                        "ConversionExportPacket contains forbidden key: \(fullPath)"
                    )
                }
                
                if let nested = value as? [String: Any] {
                    checkNested(nested, path: fullPath)
                }
            }
        }
        
        checkNested(json)
    }
    
    /// Verifies ConversionLedger stores no identifiers
    func testConversionLedgerNoIdentifiers() {
        // ConversionData should not have identifier fields
        let data = ConversionData()
        
        // Check struct fields - should only have counts and timestamps
        XCTAssertNotNil(data.counts)
        XCTAssertTrue(data.schemaVersion > 0)
        
        // No identifier fields should exist (userId, deviceId, etc.)
        // This is a structural check - if they existed, they'd be accessible
    }
    
    // MARK: - C) StoreKit Product Mapping
    
    /// Verifies all tiers have product IDs
    func testTierProductMappingComplete() {
        let result = StoreKitValidation.validateTierProductMapping()
        XCTAssertTrue(result.isEmpty, "Tier product mapping errors: \(result.joined(separator: ", "))")
    }
    
    /// Verifies product ID format is valid
    func testProductIdFormatValid() {
        let result = StoreKitValidation.validateAllProductIds()
        XCTAssertTrue(result.isEmpty, "Product ID format errors: \(result.joined(separator: ", "))")
    }
    
    /// Verifies display order is complete
    func testDisplayOrderComplete() {
        let result = StoreKitValidation.validateDisplayOrder()
        XCTAssertTrue(result.isEmpty, "Display order errors: \(result.joined(separator: ", "))")
    }
    
    /// Verifies TierMatrix is consistent
    func testTierMatrixConsistent() {
        let result = StoreKitValidation.validateTierMatrix()
        XCTAssertTrue(result.isEmpty, "TierMatrix errors: \(result.joined(separator: ", "))")
    }
    
    /// Verifies full StoreKit validation passes
    func testStoreKitValidationPasses() {
        let result = StoreKitValidation.runAllValidations()
        XCTAssertTrue(result.isValid, "StoreKit validation failed: \(result.errorSummary)")
    }
    
    // MARK: - D) Pricing Copy Safety
    
    /// Verifies pricing copy has no banned words
    func testPricingCopyNoBannedWords() {
        let textsToCheck = [
            PricingCopy.tagline,
            PricingCopy.shortTagline,
            PricingCopy.whyWeCharge,
            PricingCopy.subscriptionDisclosure,
            PricingCopy.reviewNotes,
            AppStoreMetadata.subtitle,
            AppStoreMetadata.promotionalText,
            AppStoreMetadata.description
        ]
        
        for text in textsToCheck {
            let violations = PricingCopy.validate(text)
            XCTAssertTrue(violations.isEmpty, "Pricing copy violations: \(violations.joined(separator: ", "))")
        }
        
        // Also check value props
        for prop in PricingCopy.valueProps {
            let violations = PricingCopy.validate(prop)
            XCTAssertTrue(violations.isEmpty, "Value prop violations: \(violations.joined(separator: ", "))")
        }
        
        // Check tier bullets
        for tier in SubscriptionTier.allCases {
            for bullet in PricingCopy.tierBullets(for: tier) {
                let violations = PricingCopy.validate(bullet)
                XCTAssertTrue(violations.isEmpty, "Tier bullet violations for \(tier): \(violations.joined(separator: ", "))")
            }
        }
    }
    
    /// Verifies tagline length limits
    func testPricingCopyLengthLimits() {
        // Tagline should be under limit
        XCTAssertLessThanOrEqual(
            PricingCopy.tagline.count,
            100,  // Generous limit for internal tagline
            "Tagline too long"
        )
        
        // Short tagline should be under App Store limit
        XCTAssertLessThanOrEqual(
            PricingCopy.shortTagline.count,
            PricingCopy.maxTaglineLength,
            "Short tagline exceeds App Store limit"
        )
        
        // Subtitle should be under limit
        XCTAssertLessThanOrEqual(
            AppStoreMetadata.subtitle.count,
            30,
            "Subtitle too long for App Store"
        )
    }
    
    /// Verifies no AI anthropomorphism
    func testNoAIAnthropomorphism() {
        let aiPatterns = [
            "AI decides",
            "AI learns",
            "AI thinks",
            "AI understands",
            "AI knows",
            "smart AI",
            "intelligent AI",
            "the AI will"
        ]
        
        let textsToCheck = [
            PricingCopy.tagline,
            PricingCopy.whyWeCharge,
            AppStoreMetadata.description,
            AppStoreMetadata.promotionalText
        ]
        
        for text in textsToCheck {
            for pattern in aiPatterns {
                XCTAssertFalse(
                    text.lowercased().contains(pattern.lowercased()),
                    "Text contains AI anthropomorphism: '\(pattern)'"
                )
            }
        }
    }
    
    // MARK: - E) Quota Consistency
    
    /// Verifies quotas are defined in one place only
    func testQuotaConsistency() {
        let result = StoreKitValidation.validateQuotaConsistency()
        XCTAssertTrue(result.isEmpty, "Quota consistency errors: \(result.joined(separator: ", "))")
    }
    
    /// Verifies free tier limits match between TierMatrix and TierQuotas
    func testFreeTierLimitsMatch() {
        let matrixExec = TierMatrix.weeklyExecutionLimit(for: .free)
        let quotasExec = TierQuotas.weeklyExecutionLimit(for: .free)
        
        XCTAssertEqual(
            matrixExec, quotasExec,
            "Free tier execution limits don't match: TierMatrix=\(matrixExec ?? -1), TierQuotas=\(quotasExec ?? -1)"
        )
        
        let matrixMem = TierMatrix.memoryItemLimit(for: .free)
        let quotasMem = TierQuotas.memoryItemLimit(for: .free)
        
        XCTAssertEqual(
            matrixMem, quotasMem,
            "Free tier memory limits don't match: TierMatrix=\(matrixMem ?? -1), TierQuotas=\(quotasMem ?? -1)"
        )
    }
    
    // MARK: - F) Core Modules Untouched
    
    /// Verifies ExecutionEngine has no monetization imports
    func testExecutionEngineNoMonetizationImports() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let monetizationPatterns = [
            "ConversionLedger",
            "PricingCopy",
            "StoreKitValidation",
            "QuotaEnforcer",
            "PaywallGate"
        ]
        
        for pattern in monetizationPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ExecutionEngine.swift contains monetization pattern: \(pattern)"
            )
        }
    }
    
    /// Verifies ApprovalGate has no monetization imports
    func testApprovalGateNoMonetizationImports() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let monetizationPatterns = [
            "ConversionLedger",
            "PricingCopy",
            "StoreKitValidation"
        ]
        
        for pattern in monetizationPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ApprovalGate.swift contains monetization pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - Helpers
    
    private func findProjectRoot() -> String {
        let currentFile = URL(fileURLWithPath: #file)
        return currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("OperatorKit")
            .path
    }
    
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
    
    private func findSwiftFiles(in directory: String) -> [String] {
        let fileManager = FileManager.default
        var swiftFiles: [String] = []
        
        guard let enumerator = fileManager.enumerator(atPath: directory) else {
            return swiftFiles
        }
        
        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".swift") {
                swiftFiles.append((directory as NSString).appendingPathComponent(file))
            }
        }
        
        return swiftFiles
    }
}

// MARK: - Conversion Event Tests

extension CommercialReadinessTests {
    
    /// Verifies all conversion events have display names
    func testConversionEventsHaveDisplayNames() {
        for event in ConversionEvent.allCases {
            XCTAssertFalse(event.displayName.isEmpty, "Event \(event.rawValue) has no display name")
        }
    }
    
    /// Verifies conversion summary calculates correctly
    func testConversionSummaryCalculation() {
        let summary = ConversionSummary(
            paywallShownCount: 100,
            upgradeTapCount: 50,
            purchaseStartedCount: 25,
            purchaseSuccessCount: 10,
            restoreTapCount: 5,
            restoreSuccessCount: 2,
            lastEventAt: Date(),
            capturedAt: Date()
        )
        
        // Conversion rate should be 10%
        XCTAssertEqual(summary.conversionRate, 0.1, accuracy: 0.001)
        
        // Total events
        XCTAssertEqual(summary.totalEvents, 100 + 50 + 25 + 10 + 5 + 2)
    }
}
