import XCTest
@testable import OperatorKit

// ============================================================================
// ACTIVATION/TRIAL/SATISFACTION FIREWALL TESTS (Phase 10N)
//
// Tests proving core execution modules have no imports/references to
// activation, trial, or satisfaction modules.
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

final class ActivationTrialSatisfactionFirewallTests: XCTestCase {
    
    // MARK: - A) ExecutionEngine Firewall
    
    /// Verifies ExecutionEngine has no activation/trial/satisfaction imports
    func testExecutionEngineNoPhase10NImports() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase10NPatterns = [
            "ActivationPlaybook",
            "ActivationStateStore",
            "TeamTrialState",
            "TeamTrialStore",
            "SatisfactionSignal",
            "SatisfactionSignalStore",
            "ProcurementEmailTemplates"
        ]
        
        for pattern in phase10NPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ExecutionEngine.swift contains Phase 10N pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - B) ApprovalGate Firewall
    
    /// Verifies ApprovalGate has no activation/trial/satisfaction imports
    func testApprovalGateNoPhase10NImports() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase10NPatterns = [
            "ActivationPlaybook",
            "TeamTrialState",
            "SatisfactionSignal"
        ]
        
        for pattern in phase10NPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ApprovalGate.swift contains Phase 10N pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - C) ModelRouter Firewall
    
    /// Verifies ModelRouter has no activation/trial/satisfaction imports
    func testModelRouterNoPhase10NImports() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let phase10NPatterns = [
            "ActivationPlaybook",
            "TeamTrialState",
            "SatisfactionSignal"
        ]
        
        for pattern in phase10NPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ModelRouter.swift contains Phase 10N pattern: \(pattern)"
            )
        }
    }
    
    // MARK: - D) No Networking in New Modules
    
    /// Verifies ActivationPlaybook has no networking
    func testActivationPlaybookNoNetworking() throws {
        let filePath = findProjectFile(named: "ActivationPlaybook.swift", in: "Monetization")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ActivationPlaybook.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies TeamTrialState has no networking
    func testTeamTrialStateNoNetworking() throws {
        let filePath = findProjectFile(named: "TeamTrialState.swift", in: "Team")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "TeamTrialState.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies SatisfactionSignal has no networking
    func testSatisfactionSignalNoNetworking() throws {
        let filePath = findProjectFile(named: "SatisfactionSignal.swift", in: "Monetization")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "SatisfactionSignal.swift contains networking: \(pattern)"
            )
        }
    }
    
    /// Verifies ProcurementEmailTemplates has no networking
    func testProcurementEmailTemplatesNoNetworking() throws {
        let filePath = findProjectFile(named: "ProcurementEmailTemplates.swift", in: "Team")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let networkingPatterns = ["URLSession", "URLRequest", "import Network"]
        
        for pattern in networkingPatterns {
            XCTAssertFalse(
                content.contains(pattern),
                "ProcurementEmailTemplates.swift contains networking: \(pattern)"
            )
        }
    }
    
    // MARK: - E) No Background Tasks
    
    /// Verifies new modules have no background task usage
    func testNoBackgroundTasks() throws {
        let files = [
            ("ActivationPlaybook.swift", "Monetization"),
            ("TeamTrialState.swift", "Team"),
            ("TeamTrialStore.swift", "Team"),
            ("SatisfactionSignal.swift", "Monetization")
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
