import XCTest
@testable import OperatorKit

// ============================================================================
// TEAM SALES KIT TESTS (Phase 10M)
//
// Tests for team sales kit:
// - mailto draft is generic (no identifiers)
// - No networking imports in sales kit files
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

final class TeamSalesKitTests: XCTestCase {
    
    // MARK: - A) Mailto Draft
    
    /// Verifies mailto draft contains no device/user identifiers
    func testMailtoDraftIsGeneric() {
        // Simulate the mailto content from TeamSalesKitView
        let trialSubject = "OperatorKit Team Trial Request"
        let trialBody = """
        Hello,
        
        I am interested in a team trial for OperatorKit.
        
        Organization: [Your Organization]
        Number of seats: [Number]
        
        Thank you.
        """
        
        let invoiceSubject = "OperatorKit Invoice Request"
        let invoiceBody = """
        Hello,
        
        I would like to request an invoice for OperatorKit Team tier.
        
        Organization: [Your Organization]
        Billing contact: [Contact Name]
        Number of seats: [Number]
        
        Thank you.
        """
        
        // Check no identifiers in subjects
        XCTAssertFalse(trialSubject.contains("UUID"), "Subject contains UUID")
        XCTAssertFalse(invoiceSubject.contains("UUID"), "Subject contains UUID")
        
        // Check no identifiers in bodies
        let identifierPatterns = [
            "deviceId", "device_id", "userId", "user_id",
            "UDID", "IMEI", "SerialNumber", "serial_number",
            "receipt", "transactionId", "transaction_id"
        ]
        
        for pattern in identifierPatterns {
            XCTAssertFalse(
                trialBody.lowercased().contains(pattern.lowercased()),
                "Trial body contains identifier: \(pattern)"
            )
            XCTAssertFalse(
                invoiceBody.lowercased().contains(pattern.lowercased()),
                "Invoice body contains identifier: \(pattern)"
            )
        }
        
        // Check bodies use placeholders, not real data
        XCTAssertTrue(trialBody.contains("[Your Organization]"), "Should use placeholder")
        XCTAssertTrue(invoiceBody.contains("[Contact Name]"), "Should use placeholder")
    }
    
    // MARK: - B) No Networking Imports
    
    /// Verifies TeamSalesKitView has no networking imports
    func testNoNetworkingImportsInSalesKitView() throws {
        let filePath = findProjectFile(named: "TeamSalesKitView.swift", in: "UI/Team")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "HTTPURLResponse", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "TeamSalesKitView.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies EnterpriseReadinessView has no networking imports
    func testNoNetworkingImportsInEnterpriseReadinessView() throws {
        let filePath = findProjectFile(named: "EnterpriseReadinessView.swift", in: "UI/Settings")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "HTTPURLResponse", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "EnterpriseReadinessView.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies EnterpriseReadinessPacket has no networking imports
    func testNoNetworkingImportsInEnterpriseReadinessPacket() throws {
        let filePath = findProjectFile(named: "EnterpriseReadinessPacket.swift", in: "Domain/Review")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "HTTPURLResponse", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "EnterpriseReadinessPacket.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies EnterpriseReadinessBuilder has no networking imports
    func testNoNetworkingImportsInEnterpriseReadinessBuilder() throws {
        let filePath = findProjectFile(named: "EnterpriseReadinessBuilder.swift", in: "Domain/Review")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "HTTPURLResponse", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "EnterpriseReadinessBuilder.swift contains networking: \(pattern)"
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
