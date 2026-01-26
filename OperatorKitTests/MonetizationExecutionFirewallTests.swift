import XCTest
@testable import OperatorKit

// ============================================================================
// MONETIZATION EXECUTION FIREWALL TESTS (Phase 10L)
//
// Tests proving core execution modules have no imports/references to
// monetization modules added in Phase 10L.
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

final class MonetizationExecutionFirewallTests: XCTestCase {
    
    // MARK: - A) ExecutionEngine Firewall
    
    /// Verifies ExecutionEngine has no pricing variant imports
    func testExecutionEngineNoPricingVariantImports() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let monetizationPatterns = [
            "PricingVariant",
            "PricingVariantStore",
            "PricingVariantsCopy",
            "ConversionFunnel",
            "ConversionFunnelManager",
            "ConversionExportPacket",
            "FunnelStep",
            "FunnelSummary"
        ]
        
        for pattern in monetizationPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ExecutionEngine.swift contains monetization pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - B) ApprovalGate Firewall
    
    /// Verifies ApprovalGate has no pricing variant imports
    func testApprovalGateNoPricingVariantImports() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let monetizationPatterns = [
            "PricingVariant",
            "PricingVariantStore",
            "ConversionFunnel",
            "FunnelStep"
        ]
        
        for pattern in monetizationPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ApprovalGate.swift contains monetization pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - C) ModelRouter Firewall
    
    /// Verifies ModelRouter has no pricing variant imports
    func testModelRouterNoPricingVariantImports() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let monetizationPatterns = [
            "PricingVariant",
            "ConversionFunnel",
            "FunnelStep"
        ]
        
        for pattern in monetizationPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ModelRouter.swift contains monetization pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - D) No Network Imports
    
    /// Verifies PricingVariant has no networking imports
    func testPricingVariantNoNetworkImports() throws {
        let filePath = findProjectFile(named: "PricingVariant.swift", in: "Monetization")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "HTTPURLResponse", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "PricingVariant.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies ConversionFunnel has no networking imports
    func testConversionFunnelNoNetworkImports() throws {
        let filePath = findProjectFile(named: "ConversionFunnel.swift", in: "Monetization")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "HTTPURLResponse", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ConversionFunnel.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies ConversionExportPacket has no networking imports
    func testConversionExportPacketNoNetworkImports() throws {
        let filePath = findProjectFile(named: "ConversionExportPacket.swift", in: "Monetization")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "HTTPURLResponse", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ConversionExportPacket.swift contains networking: \(pattern)"
            )
        }
    }
    
    // MARK: - E) Forbidden Keys
    
    /// Verifies FunnelSummary contains no forbidden keys
    func testFunnelSummaryNoForbiddenKeys() throws {
        let summary = FunnelSummary(
            onboardingShownCount: 1,
            pricingViewedCount: 1,
            upgradeTappedCount: 1,
            purchaseStartedCount: 1,
            purchaseSuccessCount: 1,
            purchaseCancelledCount: 1,
            restoreTappedCount: 1,
            restoreSuccessCount: 1,
            currentVariantId: "test",
            capturedAt: "2026-01-24",
            schemaVersion: 1
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(summary)
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        let forbiddenKeys = [
            "body", "subject", "content", "draft", "prompt",
            "context", "note", "email", "attendees", "title",
            "description", "message", "text", "recipient", "sender"
        ]
        
        for key in json.keys {
            XCTAssertFalse(
                forbiddenKeys.contains(key.lowercased()),
                "FunnelSummary contains forbidden key: \(key)"
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
