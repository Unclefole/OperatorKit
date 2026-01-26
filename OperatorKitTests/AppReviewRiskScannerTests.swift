import XCTest
@testable import OperatorKit

// ============================================================================
// APP REVIEW RISK SCANNER TESTS (Phase 10K)
//
// Tests for the rejection risk scanner:
// - Default copy passes (or expected warnings only)
// - Anthropomorphic language detected
// - Security claims detected
// - Background language detected
// - Memory personalization detected
// - Risk report contains no forbidden keys
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class AppReviewRiskScannerTests: XCTestCase {
    
    // MARK: - A) Default Copy Scanning
    
    /// Verifies default copy passes or has only expected warnings
    func testRiskScannerPassesDefaultCopy() {
        let report = AppReviewRiskScanner.scanSubmissionCopy()
        
        // Should not have FAIL status (only PASS or WARN acceptable)
        XCTAssertNotEqual(
            report.status,
            .fail,
            "Default copy should not have failure-level findings"
        )
        
        // Any failures are problems
        let failures = report.findings.filter { $0.severity == .fail }
        XCTAssertTrue(
            failures.isEmpty,
            "Default copy has failures: \(failures.map { $0.title }.joined(separator: ", "))"
        )
    }
    
    /// Verifies report structure is valid
    func testRiskReportStructure() {
        let report = AppReviewRiskScanner.scanSubmissionCopy()
        
        XCTAssertGreaterThan(report.schemaVersion, 0)
        XCTAssertFalse(report.createdAt.isEmpty)
        XCTAssertFalse(report.scannedSources.isEmpty)
    }
    
    // MARK: - B) Anthropomorphic Language Detection
    
    /// Verifies scanner flags "AI thinks"
    func testRiskScannerFlagsAIThinks() {
        let findings = AppReviewRiskScanner.scanText(
            "Our AI thinks about your request carefully",
            source: "test"
        )
        
        XCTAssertTrue(
            findings.contains { $0.id == "RISK-001" },
            "Should flag 'AI thinks'"
        )
    }
    
    /// Verifies scanner flags "AI learns"
    func testRiskScannerFlagsAILearns() {
        let findings = AppReviewRiskScanner.scanText(
            "The AI learns from your preferences",
            source: "test"
        )
        
        XCTAssertTrue(
            findings.contains { $0.id == "RISK-002" },
            "Should flag 'AI learns'"
        )
    }
    
    /// Verifies scanner flags "AI decides"
    func testRiskScannerFlagsAIDecides() {
        let findings = AppReviewRiskScanner.scanText(
            "AI decides the best action for you",
            source: "test"
        )
        
        XCTAssertTrue(
            findings.contains { $0.id == "RISK-003" },
            "Should flag 'AI decides'"
        )
    }
    
    /// Verifies scanner flags "AI understands"
    func testRiskScannerFlagsAIUnderstands() {
        let findings = AppReviewRiskScanner.scanText(
            "Our AI understands natural language",
            source: "test"
        )
        
        XCTAssertTrue(
            findings.contains { $0.id == "RISK-004" },
            "Should flag 'AI understands'"
        )
    }
    
    // MARK: - C) Security Claims Detection
    
    /// Verifies scanner flags "secure"
    func testRiskScannerFlagsSecure() {
        let findings = AppReviewRiskScanner.scanText(
            "Your data is secure with us",
            source: "test"
        )
        
        XCTAssertTrue(
            findings.contains { $0.id == "RISK-011" },
            "Should flag 'secure'"
        )
    }
    
    /// Verifies scanner flags "encrypted"
    func testRiskScannerFlagsEncrypted() {
        let findings = AppReviewRiskScanner.scanText(
            "All data is encrypted end-to-end",
            source: "test"
        )
        
        XCTAssertTrue(
            findings.contains { $0.id == "RISK-012" },
            "Should flag 'encrypted'"
        )
    }
    
    // MARK: - D) Background Language Detection
    
    /// Verifies scanner flags "monitors"
    func testRiskScannerFlagsMonitors() {
        let findings = AppReviewRiskScanner.scanText(
            "The app monitors your activity",
            source: "test"
        )
        
        XCTAssertTrue(
            findings.contains { $0.id == "RISK-021" },
            "Should flag 'monitors'"
        )
    }
    
    /// Verifies scanner flags "tracks"
    func testRiskScannerFlagsTracks() {
        let findings = AppReviewRiskScanner.scanText(
            "We track your usage patterns",
            source: "test"
        )
        
        XCTAssertTrue(
            findings.contains { $0.id == "RISK-022" },
            "Should flag 'tracks'"
        )
    }
    
    /// Verifies scanner flags "runs in background"
    func testRiskScannerFlagsBackground() {
        let findings = AppReviewRiskScanner.scanText(
            "The app runs in background continuously",
            source: "test"
        )
        
        XCTAssertTrue(
            findings.contains { $0.id == "RISK-023" },
            "Should flag 'runs in background'"
        )
    }
    
    // MARK: - E) Memory Personalization Detection
    
    /// Verifies scanner flags "learns your"
    func testRiskScannerFlagsLearnsYour() {
        let findings = AppReviewRiskScanner.scanText(
            "Memory learns your preferences over time",
            source: "test"
        )
        
        XCTAssertTrue(
            findings.contains { $0.id == "RISK-007" },
            "Should flag 'learns your'"
        )
    }
    
    /// Verifies scanner flags "personalizes automatically"
    func testRiskScannerFlagsPersonalizesAutomatically() {
        let findings = AppReviewRiskScanner.scanText(
            "The app personalizes automatically based on usage",
            source: "test"
        )
        
        XCTAssertTrue(
            findings.contains { $0.id == "RISK-009" },
            "Should flag 'personalizes automatically'"
        )
    }
    
    // MARK: - F) Risk Report Export Safety
    
    /// Verifies risk report contains no forbidden keys
    func testRiskReportContainsNoForbiddenKeys() throws {
        let report = AppReviewRiskScanner.scanSubmissionCopy()
        let jsonData = try report.exportJSON()
        
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Could not parse risk report JSON")
            return
        }
        
        let forbiddenKeys = AppStoreSubmissionPacket.forbiddenKeys
        let violations = findForbiddenKeys(in: json, forbidden: forbiddenKeys)
        
        XCTAssertTrue(
            violations.isEmpty,
            "Risk report contains forbidden keys: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies risk report filename format
    func testRiskReportFilename() {
        let report = AppReviewRiskScanner.scanSubmissionCopy()
        
        XCTAssertTrue(report.exportFilename.hasPrefix("OperatorKit_RiskReport_"))
        XCTAssertTrue(report.exportFilename.hasSuffix(".json"))
    }
    
    // MARK: - G) Scanner Purity
    
    /// Verifies scanner is pure (same input = same output)
    func testScannerIsPure() {
        let text = "Test text with AI thinks"
        
        let findings1 = AppReviewRiskScanner.scanText(text, source: "test")
        let findings2 = AppReviewRiskScanner.scanText(text, source: "test")
        
        XCTAssertEqual(
            findings1.map { $0.id },
            findings2.map { $0.id },
            "Scanner should be deterministic"
        )
    }
    
    /// Verifies scanner has no side effects (file unchanged)
    func testScannerNoSideEffects() {
        let report1 = AppReviewRiskScanner.scanSubmissionCopy()
        let report2 = AppReviewRiskScanner.scanSubmissionCopy()
        
        XCTAssertEqual(
            report1.findings.count,
            report2.findings.count,
            "Multiple scans should produce identical results"
        )
    }
    
    // MARK: - Helpers
    
    private func findForbiddenKeys(in dict: [String: Any], forbidden: [String], path: String = "") -> [String] {
        var violations: [String] = []
        
        for (key, value) in dict {
            let fullPath = path.isEmpty ? key : "\(path).\(key)"
            
            if forbidden.contains(key.lowercased()) {
                violations.append(fullPath)
            }
            
            if let nested = value as? [String: Any] {
                violations.append(contentsOf: findForbiddenKeys(in: nested, forbidden: forbidden, path: fullPath))
            }
            
            if let array = value as? [[String: Any]] {
                for (index, item) in array.enumerated() {
                    violations.append(contentsOf: findForbiddenKeys(in: item, forbidden: forbidden, path: "\(fullPath)[\(index)]"))
                }
            }
        }
        
        return violations
    }
}
