import XCTest
@testable import OperatorKit

// ============================================================================
// AUDIT/REPRO FIREWALL TESTS (Phase 10P)
//
// Tests proving core execution modules have no imports/references to
// audit trail or repro bundle modules.
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

final class AuditReproFirewallTests: XCTestCase {
    
    // MARK: - A) ExecutionEngine Firewall
    
    /// Verifies ExecutionEngine has no audit/repro imports
    func testExecutionEngineNoPhase10PImports() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase10PPatterns = [
            "CustomerAuditTrail",
            "CustomerAuditTrailStore",
            "CustomerAuditEvent",
            "ReproBundleExport",
            "ReproBundleBuilder",
            "CustomerProofView"
        ]
        
        for pattern in phase10PPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ExecutionEngine.swift contains Phase 10P pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - B) ApprovalGate Firewall
    
    /// Verifies ApprovalGate has no audit/repro imports
    func testApprovalGateNoPhase10PImports() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase10PPatterns = [
            "AuditTrail",
            "ReproBundleExport"
        ]
        
        for pattern in phase10PPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ApprovalGate.swift contains Phase 10P pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - C) ModelRouter Firewall
    
    /// Verifies ModelRouter has no audit/repro imports
    func testModelRouterNoPhase10PImports() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase10PPatterns = [
            "AuditTrail",
            "ReproBundleExport"
        ]
        
        for pattern in phase10PPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ModelRouter.swift contains Phase 10P pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - D) No Networking in New Modules
    
    /// Verifies AuditTrail has no networking
    func testAuditTrailNoNetworking() throws {
        let filePath = findProjectFile(named: "AuditTrail.swift", in: "Diagnostics")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "AuditTrail.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies AuditTrailStore has no networking
    func testAuditTrailStoreNoNetworking() throws {
        let filePath = findProjectFile(named: "AuditTrailStore.swift", in: "Diagnostics")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "AuditTrailStore.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies ReproBundleExport has no networking
    func testReproBundleExportNoNetworking() throws {
        let filePath = findProjectFile(named: "ReproBundleExport.swift", in: "Diagnostics")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ReproBundleExport.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies ReproBundleBuilder has no networking
    func testReproBundleBuilderNoNetworking() throws {
        let filePath = findProjectFile(named: "ReproBundleBuilder.swift", in: "Diagnostics")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ReproBundleBuilder.swift contains networking: \(pattern)"
            )
        }
    }
    
    // MARK: - E) No Background Tasks
    
    /// Verifies new modules have no background task usage
    func testNoBackgroundTasks() throws {
        let files = [
            ("AuditTrail.swift", "Diagnostics"),
            ("AuditTrailStore.swift", "Diagnostics"),
            ("ReproBundleExport.swift", "Diagnostics"),
            ("ReproBundleBuilder.swift", "Diagnostics")
        ]
        
        let backgroundPatterns = [
            "BGTaskScheduler",
            "UIBackgroundTask",
            "BackgroundTask",
            "beginBackgroundTask"
        ]
        
        for (fileName, subdirectory) in files {
            let filePath = findProjectFile(named: fileName, in: subdirectory)
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            for pattern in backgroundPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "\(fileName) contains background task: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - F) No New URLSession Outside Sync
    
    /// Verifies no new URLSession usage outside Sync directory
    func testNoNewURLSessionOutsideSync() throws {
        let newFiles = [
            ("AuditTrail.swift", "Diagnostics"),
            ("AuditTrailStore.swift", "Diagnostics"),
            ("ReproBundleExport.swift", "Diagnostics"),
            ("ReproBundleBuilder.swift", "Diagnostics"),
            ("CustomerProofView.swift", "UI/Settings")
        ]
        
        for (fileName, subdirectory) in newFiles {
            let filePath = findProjectFile(named: fileName, in: subdirectory)
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            XCTAssertFalse(
                content.contains("URLSession"),
                "\(fileName) contains URLSession usage"
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
