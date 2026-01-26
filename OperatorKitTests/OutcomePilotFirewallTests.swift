import XCTest
@testable import OperatorKit

// ============================================================================
// OUTCOME/PILOT FIREWALL TESTS (Phase 10O)
//
// Tests proving core execution modules have no imports/references to
// outcome templates, outcome ledger, or pilot mode modules.
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

final class OutcomePilotFirewallTests: XCTestCase {
    
    // MARK: - A) ExecutionEngine Firewall
    
    /// Verifies ExecutionEngine has no outcome/pilot imports
    func testExecutionEngineNoPhase10OImports() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase10OPatterns = [
            "OutcomeTemplates",
            "OutcomeTemplate",
            "OutcomeLedger",
            "OutcomeSummary",
            "PilotSharePack",
            "PilotSharePackBuilder",
            "PilotModeView",
            "PilotChecklist"
        ]
        
        for pattern in phase10OPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ExecutionEngine.swift contains Phase 10O pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - B) ApprovalGate Firewall
    
    /// Verifies ApprovalGate has no outcome/pilot imports
    func testApprovalGateNoPhase10OImports() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase10OPatterns = [
            "OutcomeTemplates",
            "OutcomeLedger",
            "PilotSharePack"
        ]
        
        for pattern in phase10OPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ApprovalGate.swift contains Phase 10O pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - C) ModelRouter Firewall
    
    /// Verifies ModelRouter has no outcome/pilot imports
    func testModelRouterNoPhase10OImports() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase10OPatterns = [
            "OutcomeTemplates",
            "OutcomeLedger",
            "PilotSharePack"
        ]
        
        for pattern in phase10OPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ModelRouter.swift contains Phase 10O pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - D) No Networking in New Modules
    
    /// Verifies OutcomeTemplates has no networking
    func testOutcomeTemplatesNoNetworking() throws {
        let filePath = findProjectFile(named: "OutcomeTemplates.swift", in: "Monetization")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "OutcomeTemplates.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies OutcomeLedger has no networking
    func testOutcomeLedgerNoNetworking() throws {
        let filePath = findProjectFile(named: "OutcomeLedger.swift", in: "Monetization")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "OutcomeLedger.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies PilotSharePack has no networking
    func testPilotSharePackNoNetworking() throws {
        let filePath = findProjectFile(named: "PilotSharePack.swift", in: "Domain/Review")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "PilotSharePack.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies PilotSharePackBuilder has no networking
    func testPilotSharePackBuilderNoNetworking() throws {
        let filePath = findProjectFile(named: "PilotSharePackBuilder.swift", in: "Domain/Review")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "PilotSharePackBuilder.swift contains networking: \(pattern)"
            )
        }
    }
    
    // MARK: - E) No Background Tasks
    
    /// Verifies new modules have no background task usage
    func testNoBackgroundTasks() throws {
        let files = [
            ("OutcomeTemplates.swift", "Monetization"),
            ("OutcomeLedger.swift", "Monetization"),
            ("PilotSharePack.swift", "Domain/Review"),
            ("PilotSharePackBuilder.swift", "Domain/Review")
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
            ("OutcomeTemplates.swift", "Monetization"),
            ("OutcomeLedger.swift", "Monetization"),
            ("PilotSharePack.swift", "Domain/Review"),
            ("PilotSharePackBuilder.swift", "Domain/Review"),
            ("OutcomeTemplatesView.swift", "UI/Monetization"),
            ("PilotModeView.swift", "UI/Settings")
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
