import XCTest
@testable import OperatorKit

// ============================================================================
// CONVERSION FUNNEL TESTS (Phase 10L)
//
// Tests for conversion funnel:
// - Summary is numeric only
// - Rates compute correctly
// - No forbidden keys in export
// - Core modules untouched
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class ConversionFunnelTests: XCTestCase {
    
    // MARK: - A) Funnel Summary
    
    /// Verifies funnel summary contains only numeric data
    func testFunnelSummaryIsNumericOnly() {
        let summary = FunnelSummary(
            onboardingShownCount: 100,
            pricingViewedCount: 50,
            upgradeTappedCount: 25,
            purchaseStartedCount: 15,
            purchaseSuccessCount: 10,
            purchaseCancelledCount: 5,
            restoreTappedCount: 8,
            restoreSuccessCount: 3,
            currentVariantId: "variant_a",
            capturedAt: "2026-01-24",
            schemaVersion: 1
        )
        
        XCTAssertTrue(summary.isNumericOnly())
        
        // All count fields should be >= 0
        XCTAssertGreaterThanOrEqual(summary.onboardingShownCount, 0)
        XCTAssertGreaterThanOrEqual(summary.pricingViewedCount, 0)
        XCTAssertGreaterThanOrEqual(summary.upgradeTappedCount, 0)
        XCTAssertGreaterThanOrEqual(summary.purchaseStartedCount, 0)
        XCTAssertGreaterThanOrEqual(summary.purchaseSuccessCount, 0)
    }
    
    /// Verifies rates compute correctly
    func testRatesComputeCorrectly() {
        let summary = FunnelSummary(
            onboardingShownCount: 100,
            pricingViewedCount: 50,
            upgradeTappedCount: 25,
            purchaseStartedCount: 20,
            purchaseSuccessCount: 10,
            purchaseCancelledCount: 10,
            restoreTappedCount: 10,
            restoreSuccessCount: 5,
            currentVariantId: "variant_a",
            capturedAt: "2026-01-24",
            schemaVersion: 1
        )
        
        // Pricing view rate: 50/100 = 0.5
        XCTAssertEqual(summary.pricingViewRate, 0.5, accuracy: 0.001)
        
        // Upgrade tap rate: 25/50 = 0.5
        XCTAssertEqual(summary.upgradeTapRate, 0.5, accuracy: 0.001)
        
        // Purchase start rate: 20/25 = 0.8
        XCTAssertEqual(summary.purchaseStartRate, 0.8, accuracy: 0.001)
        
        // Purchase success rate: 10/20 = 0.5
        XCTAssertEqual(summary.purchaseSuccessRate, 0.5, accuracy: 0.001)
        
        // Overall conversion: 10/50 = 0.2
        XCTAssertEqual(summary.overallConversionRate, 0.2, accuracy: 0.001)
        
        // Restore success rate: 5/10 = 0.5
        XCTAssertEqual(summary.restoreSuccessRate, 0.5, accuracy: 0.001)
    }
    
    /// Verifies rates handle zero denominators
    func testRatesHandleZeroDenominators() {
        let summary = FunnelSummary(
            onboardingShownCount: 0,
            pricingViewedCount: 0,
            upgradeTappedCount: 0,
            purchaseStartedCount: 0,
            purchaseSuccessCount: 0,
            purchaseCancelledCount: 0,
            restoreTappedCount: 0,
            restoreSuccessCount: 0,
            currentVariantId: "variant_a",
            capturedAt: "2026-01-24",
            schemaVersion: 1
        )
        
        // All rates should be nil when denominator is 0
        XCTAssertNil(summary.pricingViewRate)
        XCTAssertNil(summary.upgradeTapRate)
        XCTAssertNil(summary.purchaseStartRate)
        XCTAssertNil(summary.purchaseSuccessRate)
        XCTAssertNil(summary.overallConversionRate)
        XCTAssertNil(summary.restoreSuccessRate)
    }
    
    // MARK: - B) Export Validation
    
    /// Verifies export packet contains no forbidden keys
    func testNoForbiddenKeysInExport() async throws {
        let packet = await ConversionExportPacket()
        let violations = try packet.validateNoForbiddenKeys()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Export contains forbidden keys: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies export JSON is valid
    func testExportJSONIsValid() async throws {
        let packet = await ConversionExportPacket()
        let jsonData = try packet.exportJSON()
        
        XCTAssertGreaterThan(jsonData.count, 0)
        
        // Verify valid JSON
        let json = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(json as? [String: Any])
    }
    
    /// Verifies export filename format
    func testExportFilenameFormat() async {
        let packet = await ConversionExportPacket()
        
        XCTAssertTrue(packet.exportFilename.hasPrefix("OperatorKit_Conversion_"))
        XCTAssertTrue(packet.exportFilename.hasSuffix(".json"))
    }
    
    // MARK: - C) Funnel Steps
    
    /// Verifies all funnel steps have display names
    func testFunnelStepsHaveDisplayNames() {
        for step in FunnelStep.allCases {
            XCTAssertFalse(step.displayName.isEmpty, "Step \(step.rawValue) has no display name")
        }
    }
    
    /// Verifies funnel steps map to conversion events
    func testFunnelStepsMapToConversionEvents() {
        // Most steps should map to ConversionEvent
        XCTAssertNotNil(FunnelStep.pricingViewed.conversionEvent)
        XCTAssertNotNil(FunnelStep.upgradeTapped.conversionEvent)
        XCTAssertNotNil(FunnelStep.purchaseStarted.conversionEvent)
        XCTAssertNotNil(FunnelStep.purchaseSuccess.conversionEvent)
        XCTAssertNotNil(FunnelStep.restoreTapped.conversionEvent)
        XCTAssertNotNil(FunnelStep.restoreSuccess.conversionEvent)
        
        // onboardingShown is tracked separately
        XCTAssertNil(FunnelStep.onboardingShown.conversionEvent)
    }
    
    // MARK: - D) Schema Version
    
    /// Verifies schema version is set
    func testSchemaVersionIsSet() {
        XCTAssertGreaterThan(
            FunnelSummary.currentSchemaVersion,
            0,
            "Schema version should be > 0"
        )
    }
}
