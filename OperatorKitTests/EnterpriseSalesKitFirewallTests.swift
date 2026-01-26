import XCTest
@testable import OperatorKit

// ============================================================================
// ENTERPRISE SALES KIT FIREWALL TESTS (Phase 10M)
//
// Tests proving core execution modules have no imports/references to
// enterprise/team sales kit types.
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

final class EnterpriseSalesKitFirewallTests: XCTestCase {
    
    // MARK: - A) ExecutionEngine Firewall
    
    /// Verifies ExecutionEngine has no enterprise/team sales kit imports
    func testExecutionEngineNoEnterpriseImports() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let enterprisePatterns = [
            "EnterpriseReadiness",
            "EnterpriseReadinessPacket",
            "EnterpriseReadinessBuilder",
            "EnterpriseReadinessExportPacket",
            "TeamSalesKit",
            "PolicyTemplate",
            "PolicyTemplateStore"
        ]
        
        for pattern in enterprisePatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ExecutionEngine.swift contains enterprise pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - B) ApprovalGate Firewall
    
    /// Verifies ApprovalGate has no enterprise/team sales kit imports
    func testApprovalGateNoEnterpriseImports() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let enterprisePatterns = [
            "EnterpriseReadiness",
            "TeamSalesKit",
            "PolicyTemplate"
        ]
        
        for pattern in enterprisePatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ApprovalGate.swift contains enterprise pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - C) ModelRouter Firewall
    
    /// Verifies ModelRouter has no enterprise/team sales kit imports
    func testModelRouterNoEnterpriseImports() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let enterprisePatterns = [
            "EnterpriseReadiness",
            "TeamSalesKit",
            "PolicyTemplate"
        ]
        
        for pattern in enterprisePatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ModelRouter.swift contains enterprise pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - D) No New URLSession Usage
    
    /// Verifies EnterpriseReadinessPacket has no URLSession
    func testEnterpriseReadinessPacketNoURLSession() throws {
        let filePath = findProjectFile(named: "EnterpriseReadinessPacket.swift", in: "Domain/Review")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        XCTAssertFalse(content.contains("URLSession"), "Contains URLSession")
        XCTAssertFalse(content.contains("URLRequest"), "Contains URLRequest")
    }
    
    /// Verifies EnterpriseReadinessBuilder has no URLSession
    func testEnterpriseReadinessBuilderNoURLSession() throws {
        let filePath = findProjectFile(named: "EnterpriseReadinessBuilder.swift", in: "Domain/Review")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        XCTAssertFalse(content.contains("URLSession"), "Contains URLSession")
        XCTAssertFalse(content.contains("URLRequest"), "Contains URLRequest")
    }
    
    /// Verifies PolicyTemplate has no URLSession
    func testPolicyTemplateNoURLSession() throws {
        let filePath = findProjectFile(named: "PolicyTemplate.swift", in: "Policies")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        XCTAssertFalse(content.contains("URLSession"), "Contains URLSession")
        XCTAssertFalse(content.contains("URLRequest"), "Contains URLRequest")
    }
    
    /// Verifies PolicyTemplateStore has no URLSession
    func testPolicyTemplateStoreNoURLSession() throws {
        let filePath = findProjectFile(named: "PolicyTemplateStore.swift", in: "Policies")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        XCTAssertFalse(content.contains("URLSession"), "Contains URLSession")
        XCTAssertFalse(content.contains("URLRequest"), "Contains URLRequest")
    }
    
    // MARK: - E) Forbidden Keys in Exports
    
    /// Verifies EnterpriseReadinessPacket export contains no forbidden keys
    func testEnterpriseExportNoForbiddenKeys() async throws {
        let exportPacket = await EnterpriseReadinessExportPacket()
        let violations = try exportPacket.validateNoForbiddenKeys()
        
        XCTAssertTrue(
            violations.isEmpty,
            "Export contains forbidden keys: \(violations.joined(separator: ", "))"
        )
    }
    
    /// Verifies PolicyTemplate contains no forbidden keys
    func testPolicyTemplateNoForbiddenKeys() throws {
        for template in PolicyTemplateStore.defaultTemplates {
            let violations = try template.validateNoForbiddenKeys()
            
            XCTAssertTrue(
                violations.isEmpty,
                "Template '\(template.name)' contains forbidden keys: \(violations.joined(separator: ", "))"
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
