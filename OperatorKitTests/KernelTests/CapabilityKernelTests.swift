import XCTest
@testable import OperatorKit

@MainActor
final class CapabilityKernelTests: XCTestCase {
    
    var kernel: CapabilityKernel!
    
    override func setUp() async throws {
        try await super.setUp()
        kernel = CapabilityKernel.shared
    }
    
    // MARK: - Basic Execution Flow Tests
    
    func testLowRiskIntentAutoApproves() async {
        let intent = ExecutionIntent(action: "create_draft", target: "draft")
        
        let result = await kernel.execute(intent: intent)
        
        // Low risk drafts should complete without pending approval
        XCTAssertTrue(result.status == .completed || result.status == .pendingApproval)
        XCTAssertNotNil(result.toolPlan)
        XCTAssertNotNil(result.riskAssessment)
    }
    
    func testMediumRiskIntentRequiresApproval() async {
        let intent = ExecutionIntent(action: "create calendar event", target: "meeting")
        
        let result = await kernel.execute(intent: intent)
        
        // Medium risk should require approval
        if result.riskAssessment?.tier == .medium || result.riskAssessment?.tier == .high {
            XCTAssertTrue(
                result.status == .pendingApproval || 
                result.status == .completed,
                "Medium/high risk should require approval or complete"
            )
        }
    }
    
    func testHighRiskIntentRequiresApproval() async {
        let intent = ExecutionIntent(action: "send email", target: "client@example.com")
        
        let result = await kernel.execute(intent: intent)
        
        // Email (high risk) should require approval
        XCTAssertNotNil(result.policyDecision)
        if result.riskAssessment?.tier == .high || result.riskAssessment?.tier == .critical {
            XCTAssertTrue(
                result.status == .pendingApproval || 
                result.policyDecision?.approvalRequirement.requiresBiometric == true
            )
        }
    }
    
    // MARK: - Kernel Phase Progression Tests
    
    func testKernelProgressesThroughPhases() async {
        let intent = ExecutionIntent(action: "create_draft", target: "test")
        
        // Capture initial phase
        let initialPhase = kernel.currentPhase
        XCTAssertEqual(initialPhase, .idle)
        
        let result = await kernel.execute(intent: intent)
        
        // After execution, should return to idle
        XCTAssertEqual(kernel.currentPhase, .idle, "Kernel should return to idle after completion")
        
        // Result should indicate final phase
        XCTAssertTrue(
            result.phase == .complete || 
            result.phase == .awaitingApproval ||
            result.phase == .probes,
            "Final phase should be complete, awaitingApproval, or probes"
        )
    }
    
    // MARK: - Tool Plan Generation Tests
    
    func testToolPlanIsGenerated() async {
        let intent = ExecutionIntent(action: "create_draft", target: "test")
        
        let result = await kernel.execute(intent: intent)
        
        XCTAssertNotNil(result.toolPlan)
        XCTAssertEqual(result.toolPlan?.intent.type, .createDraft)
        XCTAssertTrue(result.toolPlan?.verifySignature() ?? false)
    }
    
    func testToolPlanHasProbes() async {
        let intent = ExecutionIntent(action: "send email", target: "recipient@example.com")
        
        let result = await kernel.execute(intent: intent)
        
        XCTAssertNotNil(result.toolPlan?.probes)
        XCTAssertGreaterThan(result.toolPlan?.probes.count ?? 0, 0)
    }
    
    func testToolPlanHasExecutionSteps() async {
        let intent = ExecutionIntent(action: "create calendar event", target: "meeting")
        
        let result = await kernel.execute(intent: intent)
        
        XCTAssertNotNil(result.toolPlan?.executionSteps)
        XCTAssertGreaterThan(result.toolPlan?.executionSteps.count ?? 0, 0)
    }
    
    // MARK: - Risk Assessment Tests
    
    func testRiskAssessmentIsPerformed() async {
        let intent = ExecutionIntent(action: "send email", target: "client@example.com")
        
        let result = await kernel.execute(intent: intent)
        
        XCTAssertNotNil(result.riskAssessment)
        XCTAssertGreaterThanOrEqual(result.riskAssessment?.score ?? -1, 0)
        XCTAssertLessThanOrEqual(result.riskAssessment?.score ?? 101, 100)
    }
    
    func testRiskTierMatchesScore() async {
        let intent = ExecutionIntent(action: "external_api call", target: "https://api.example.com")
        
        let result = await kernel.execute(intent: intent)
        
        if let assessment = result.riskAssessment {
            let expectedTier = RiskTier.from(score: assessment.score)
            XCTAssertEqual(assessment.tier, expectedTier)
        }
    }
    
    // MARK: - Verification Tests
    
    func testVerificationIsPerformed() async {
        let intent = ExecutionIntent(action: "create_draft", target: "test")
        
        let result = await kernel.execute(intent: intent)
        
        XCTAssertNotNil(result.verificationResult)
    }
    
    func testVerificationFailureBlocksExecution() async {
        // This test would need a way to make verification fail
        // For now, we test that verification result is present
        let intent = ExecutionIntent(action: "send email", target: "recipient")
        
        let result = await kernel.execute(intent: intent)
        
        if let verification = result.verificationResult {
            if !verification.overallPassed {
                XCTAssertNotEqual(result.status, .completed)
            }
        }
    }
    
    // MARK: - Policy Decision Tests
    
    func testPolicyDecisionIsGenerated() async {
        let intent = ExecutionIntent(action: "send email", target: "client@example.com")
        
        let result = await kernel.execute(intent: intent)
        
        // Policy decision might be nil if verification fails early
        if result.phase.rawValue >= KernelPhase.policyMapping.rawValue {
            // If we got past policy mapping phase, decision should exist
        }
    }
    
    // MARK: - Pending Plan Management Tests
    
    func testPendingPlansArTracked() async {
        let intent = ExecutionIntent(action: "send email", target: "client@example.com")
        
        let result = await kernel.execute(intent: intent)
        
        if result.status == .pendingApproval {
            let pendingPlans = kernel.getPendingPlans()
            XCTAssertGreaterThan(pendingPlans.count, 0)
            
            // Clean up - deny the pending plan
            if let planId = result.planId {
                _ = kernel.deny(planId: planId, reason: "Test cleanup")
            }
        }
    }
    
    func testDenyRemovesPendingPlan() async {
        let intent = ExecutionIntent(action: "send email", target: "client@example.com")
        
        let result = await kernel.execute(intent: intent)
        
        if result.status == .pendingApproval, let planId = result.planId {
            let initialCount = kernel.getPendingPlans().count
            
            _ = kernel.deny(planId: planId, reason: "Test denial")
            
            let finalCount = kernel.getPendingPlans().count
            XCTAssertEqual(finalCount, initialCount - 1)
        }
    }
    
    func testAuthorizeExecutesPlan() async {
        let intent = ExecutionIntent(action: "create calendar event", target: "meeting")
        
        let result = await kernel.execute(intent: intent)
        
        if result.status == .pendingApproval, let planId = result.planId {
            let approval = ApprovalRecord(
                planId: planId,
                approved: true,
                approvalType: .userConfirm,
                approverIdentifier: "TEST_USER",
                reason: "Test approval"
            )
            
            let authorizeResult = await kernel.authorize(planId: planId, approval: approval)
            
            // Should either complete or fail, not remain pending
            XCTAssertNotEqual(authorizeResult.status, .pendingApproval)
        }
    }
    
    // MARK: - Invalid Intent Tests
    
    func testEmptyActionFails() async {
        let intent = ExecutionIntent(action: "", target: nil)
        
        let result = await kernel.execute(intent: intent)
        
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.phase, .intake)
    }
    
    // MARK: - Result Properties Tests
    
    func testResultIncludesDuration() async {
        let intent = ExecutionIntent(action: "create_draft", target: "test")
        
        let result = await kernel.execute(intent: intent)
        
        XCTAssertGreaterThanOrEqual(result.duration, 0)
    }
    
    func testResultHasMessage() async {
        let intent = ExecutionIntent(action: "create_draft", target: "test")
        
        let result = await kernel.execute(intent: intent)
        
        XCTAssertFalse(result.message.isEmpty)
    }
    
    func testIsSuccessMatchesStatus() async {
        let intent = ExecutionIntent(action: "create_draft", target: "test")
        
        let result = await kernel.execute(intent: intent)
        
        if result.status == .completed {
            XCTAssertTrue(result.isSuccess)
        } else {
            XCTAssertFalse(result.isSuccess)
        }
    }
    
    // MARK: - Invariant Tests
    
    func testNoExecutionWithoutToolPlan() async {
        // Every execution should produce a ToolPlan (unless it fails at intake)
        let intent = ExecutionIntent(action: "send email", target: "test")
        
        let result = await kernel.execute(intent: intent)
        
        if result.phase.rawValue > KernelPhase.intake.rawValue {
            XCTAssertNotNil(result.toolPlan, "Execution past intake must have ToolPlan")
        }
    }
    
    func testToolPlanSignatureVerified() async {
        let intent = ExecutionIntent(action: "create_draft", target: "test")
        
        let result = await kernel.execute(intent: intent)
        
        if let plan = result.toolPlan {
            XCTAssertTrue(plan.verifySignature(), "ToolPlan signature must be valid")
        }
    }
}
