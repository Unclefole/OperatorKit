import XCTest
@testable import OperatorKit

final class ToolPlanTests: XCTestCase {
    
    // MARK: - ToolPlan Creation Tests
    
    func testToolPlanCreation() {
        let intent = ToolPlanIntent(
            type: .sendEmail,
            summary: "Send follow-up email",
            targetDescription: "client@example.com"
        )
        
        let plan = ToolPlanBuilder()
            .setIntent(intent)
            .setOriginatingAction("send_email")
            .setRisk(score: 45, reasons: ["External communication"])
            .setReversibility(.irreversible, reason: "Sent emails cannot be recalled")
            .build()
        
        XCTAssertNotNil(plan)
        XCTAssertEqual(plan?.intent.type, .sendEmail)
        XCTAssertEqual(plan?.reversibility, .irreversible)
    }
    
    func testToolPlanSignature() {
        let intent = ToolPlanIntent(
            type: .createDraft,
            summary: "Create draft",
            targetDescription: "N/A"
        )
        
        let plan = ToolPlanBuilder()
            .setIntent(intent)
            .setOriginatingAction("create_draft")
            .setRisk(score: 10, reasons: [])
            .setReversibility(.reversible, reason: "Drafts can be deleted")
            .build()!
        
        // Signature should be valid immediately after creation
        XCTAssertTrue(plan.verifySignature())
        XCTAssertFalse(plan.signature.isEmpty)
    }
    
    func testToolPlanRiskTierCalculation() {
        // LOW tier: 0-20
        let lowRiskPlan = ToolPlanBuilder()
            .setIntent(ToolPlanIntent(type: .createDraft, summary: "Draft", targetDescription: ""))
            .setOriginatingAction("draft")
            .setRisk(score: 15, reasons: [])
            .setReversibility(.reversible, reason: "")
            .build()!
        
        XCTAssertEqual(lowRiskPlan.riskTier, .low)
        
        // MEDIUM tier: 21-50
        let mediumRiskPlan = ToolPlanBuilder()
            .setIntent(ToolPlanIntent(type: .createCalendarEvent, summary: "Event", targetDescription: ""))
            .setOriginatingAction("event")
            .setRisk(score: 35, reasons: [])
            .setReversibility(.partiallyReversible, reason: "")
            .build()!
        
        XCTAssertEqual(mediumRiskPlan.riskTier, .medium)
        
        // HIGH tier: 51-75
        let highRiskPlan = ToolPlanBuilder()
            .setIntent(ToolPlanIntent(type: .sendEmail, summary: "Email", targetDescription: ""))
            .setOriginatingAction("email")
            .setRisk(score: 60, reasons: [])
            .setReversibility(.irreversible, reason: "")
            .build()!
        
        XCTAssertEqual(highRiskPlan.riskTier, .high)
        
        // CRITICAL tier: 76-100
        let criticalRiskPlan = ToolPlanBuilder()
            .setIntent(ToolPlanIntent(type: .databaseMutation, summary: "DB", targetDescription: ""))
            .setOriginatingAction("db")
            .setRisk(score: 85, reasons: [])
            .setReversibility(.irreversible, reason: "")
            .build()!
        
        XCTAssertEqual(criticalRiskPlan.riskTier, .critical)
    }
    
    func testReversibilityRiskModifier() {
        // Irreversible adds +30 to risk score
        let plan = ToolPlanBuilder()
            .setIntent(ToolPlanIntent(type: .sendEmail, summary: "Email", targetDescription: ""))
            .setOriginatingAction("email")
            .setRisk(score: 40, reasons: [])
            .setReversibility(.irreversible, reason: "Cannot recall")
            .build()!
        
        // 40 base + 30 irreversible modifier = 70
        XCTAssertEqual(plan.riskScore, 70)
        XCTAssertEqual(plan.riskTier, .high)
    }
    
    func testToolPlanWithProbes() {
        let plan = ToolPlanBuilder()
            .setIntent(ToolPlanIntent(type: .sendEmail, summary: "Email", targetDescription: ""))
            .setOriginatingAction("email")
            .setRisk(score: 30, reasons: [])
            .setReversibility(.irreversible, reason: "")
            .addProbe(ProbeDefinition(
                type: .permissionCheck,
                description: "Check email permission",
                target: "mail",
                isRequired: true
            ))
            .addProbe(ProbeDefinition(
                type: .objectExists,
                description: "Validate recipient",
                target: "recipient",
                isRequired: true
            ))
            .build()!
        
        XCTAssertEqual(plan.probes.count, 2)
        XCTAssertTrue(plan.probes.allSatisfy { $0.isRequired })
    }
    
    func testToolPlanWithExecutionSteps() {
        let plan = ToolPlanBuilder()
            .setIntent(ToolPlanIntent(type: .createCalendarEvent, summary: "Event", targetDescription: ""))
            .setOriginatingAction("event")
            .setRisk(score: 20, reasons: [])
            .setReversibility(.partiallyReversible, reason: "")
            .addExecutionStep(ExecutionStepDefinition(
                order: 1,
                action: "prepare_event",
                description: "Prepare event data",
                isMutation: false
            ))
            .addExecutionStep(ExecutionStepDefinition(
                order: 2,
                action: "create_event",
                description: "Create in calendar",
                isMutation: true,
                rollbackAction: "delete_event"
            ))
            .build()!
        
        XCTAssertEqual(plan.executionSteps.count, 2)
        XCTAssertFalse(plan.executionSteps[0].isMutation)
        XCTAssertTrue(plan.executionSteps[1].isMutation)
        XCTAssertNotNil(plan.executionSteps[1].rollbackAction)
    }
    
    // MARK: - Approval Requirement Tests
    
    func testApprovalRequirementFactories() {
        let autoApprove = ApprovalRequirement.autoApprove
        XCTAssertEqual(autoApprove.approvalsNeeded, 0)
        XCTAssertFalse(autoApprove.requiresBiometric)
        
        let previewRequired = ApprovalRequirement.previewRequired
        XCTAssertEqual(previewRequired.approvalsNeeded, 1)
        XCTAssertTrue(previewRequired.requiresPreview)
        
        let biometricRequired = ApprovalRequirement.biometricRequired
        XCTAssertTrue(biometricRequired.requiresBiometric)
        
        let criticalMultiSig = ApprovalRequirement.criticalMultiSig
        XCTAssertEqual(criticalMultiSig.multiSignerCount, 2)
        XCTAssertTrue(criticalMultiSig.cooldownSeconds > 0)
    }
}
