import XCTest
@testable import OperatorKit

final class VerificationEngineTests: XCTestCase {
    
    var verificationEngine: VerificationEngine!
    
    override func setUp() {
        super.setUp()
        verificationEngine = VerificationEngine.shared
    }
    
    // MARK: - Reversibility Classification Tests
    
    func testDraftIsReversible() {
        let assessment = verificationEngine.classifyReversibility(
            for: .createDraft,
            context: ReversibilityContext()
        )
        
        XCTAssertEqual(assessment.reversibilityClass, .reversible)
        XCTAssertTrue(assessment.canRollback)
        XCTAssertFalse(assessment.cooldownRequired)
    }
    
    func testEmailIsIrreversible() {
        let assessment = verificationEngine.classifyReversibility(
            for: .sendEmail,
            context: ReversibilityContext()
        )
        
        XCTAssertEqual(assessment.reversibilityClass, .irreversible)
        XCTAssertFalse(assessment.canRollback)
        XCTAssertTrue(assessment.cooldownRequired)
        XCTAssertGreaterThan(assessment.recommendedCooldownSeconds, 0)
    }
    
    func testCalendarEventIsPartiallyReversible() {
        let assessment = verificationEngine.classifyReversibility(
            for: .createCalendarEvent,
            context: ReversibilityContext()
        )
        
        XCTAssertEqual(assessment.reversibilityClass, .partiallyReversible)
        XCTAssertTrue(assessment.canRollback)
        XCTAssertNotNil(assessment.rollbackMechanism)
    }
    
    func testFileDeleteWithBackup() {
        let context = ReversibilityContext(hasBackup: true, hasPreviousState: false, retentionDays: 30)
        let assessment = verificationEngine.classifyReversibility(
            for: .fileDelete,
            context: context
        )
        
        XCTAssertTrue(assessment.canRollback)
        XCTAssertNotNil(assessment.rollbackMechanism)
    }
    
    func testFileDeleteWithoutBackup() {
        let context = ReversibilityContext(hasBackup: false, hasPreviousState: false, retentionDays: 0)
        let assessment = verificationEngine.classifyReversibility(
            for: .fileDelete,
            context: context
        )
        
        XCTAssertEqual(assessment.reversibilityClass, .irreversible)
        XCTAssertFalse(assessment.canRollback)
    }
    
    func testExternalAPIIsIrreversible() {
        let assessment = verificationEngine.classifyReversibility(
            for: .externalAPICall,
            context: ReversibilityContext()
        )
        
        XCTAssertEqual(assessment.reversibilityClass, .irreversible)
        XCTAssertNil(assessment.rollbackMechanism)
    }
    
    func testUnknownIntentDefaultsToIrreversible() {
        let assessment = verificationEngine.classifyReversibility(
            for: .unknown,
            context: ReversibilityContext()
        )
        
        XCTAssertEqual(assessment.reversibilityClass, .irreversible)
        XCTAssertTrue(assessment.reason.contains("safety"))
    }
    
    // MARK: - Probe Generation Tests
    
    func testEmailProbesGenerated() {
        let probes = verificationEngine.generateProbes(for: .sendEmail, target: "recipient@example.com")
        
        XCTAssertGreaterThanOrEqual(probes.count, 2)
        
        let hasPermissionProbe = probes.contains { $0.type == .permissionCheck }
        let hasRecipientProbe = probes.contains { $0.type == .objectExists }
        
        XCTAssertTrue(hasPermissionProbe)
        XCTAssertTrue(hasRecipientProbe)
    }
    
    func testCalendarProbesGenerated() {
        let probes = verificationEngine.generateProbes(for: .createCalendarEvent, target: "calendar")
        
        let hasPermissionProbe = probes.contains { $0.type == .permissionCheck }
        let hasConnectionProbe = probes.contains { $0.type == .connectionValid }
        
        XCTAssertTrue(hasPermissionProbe)
        XCTAssertTrue(hasConnectionProbe)
    }
    
    func testUpdateEventProbesIncludeExistenceCheck() {
        let probes = verificationEngine.generateProbes(for: .updateCalendarEvent, target: "event-id")
        
        let hasExistenceProbe = probes.contains { $0.type == .objectExists }
        XCTAssertTrue(hasExistenceProbe)
    }
    
    func testDeleteEventProbesIncludeExistenceCheck() {
        let probes = verificationEngine.generateProbes(for: .deleteCalendarEvent, target: "event-id")
        
        let hasExistenceProbe = probes.contains { $0.type == .objectExists }
        XCTAssertTrue(hasExistenceProbe)
    }
    
    func testExternalAPIProbesIncludeHealthCheck() {
        let probes = verificationEngine.generateProbes(for: .externalAPICall, target: "https://api.example.com")
        
        let hasHealthProbe = probes.contains { $0.type == .endpointHealth }
        XCTAssertTrue(hasHealthProbe)
    }
    
    func testRequiredProbesMarked() {
        let probes = verificationEngine.generateProbes(for: .sendEmail, target: "recipient")
        
        // Permission probes should always be required
        let permissionProbes = probes.filter { $0.type == .permissionCheck }
        XCTAssertTrue(permissionProbes.allSatisfy { $0.isRequired })
    }
    
    // MARK: - Verification Result Tests
    
    func testVerificationWithValidPlan() async {
        let plan = ToolPlanBuilder()
            .setIntent(ToolPlanIntent(type: .createDraft, summary: "Draft", targetDescription: ""))
            .setOriginatingAction("draft")
            .setRisk(score: 10, reasons: [])
            .setReversibility(.reversible, reason: "")
            .addProbe(ProbeDefinition(type: .resourceAvailable, description: "Check storage", target: "storage", isRequired: false))
            .build()!
        
        let result = await verificationEngine.verify(plan: plan)
        
        XCTAssertTrue(result.overallPassed)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.8)
        XCTAssertFalse(result.phases.isEmpty)
    }
    
    func testVerificationIncludesSignaturePhase() async {
        let plan = ToolPlanBuilder()
            .setIntent(ToolPlanIntent(type: .createDraft, summary: "Draft", targetDescription: ""))
            .setOriginatingAction("draft")
            .setRisk(score: 10, reasons: [])
            .setReversibility(.reversible, reason: "")
            .build()!
        
        let result = await verificationEngine.verify(plan: plan)
        
        let signaturePhase = result.phases.first { $0.name == "Signature Verification" }
        XCTAssertNotNil(signaturePhase)
        XCTAssertTrue(signaturePhase!.passed)
    }
    
    func testVerificationIncludesReversibilityPhase() async {
        let plan = ToolPlanBuilder()
            .setIntent(ToolPlanIntent(type: .sendEmail, summary: "Email", targetDescription: ""))
            .setOriginatingAction("email")
            .setRisk(score: 50, reasons: [])
            .setReversibility(.irreversible, reason: "")
            .build()!
        
        let result = await verificationEngine.verify(plan: plan)
        
        let reversibilityPhase = result.phases.first { $0.name == "Reversibility Classification" }
        XCTAssertNotNil(reversibilityPhase)
        XCTAssertNotNil(reversibilityPhase!.reversibilityAssessment)
    }
    
    func testVerificationIncludesProbePhase() async {
        let plan = ToolPlanBuilder()
            .setIntent(ToolPlanIntent(type: .sendEmail, summary: "Email", targetDescription: ""))
            .setOriginatingAction("email")
            .setRisk(score: 50, reasons: [])
            .setReversibility(.irreversible, reason: "")
            .addProbe(ProbeDefinition(type: .permissionCheck, description: "Check permission", target: "mail", isRequired: true))
            .build()!
        
        let result = await verificationEngine.verify(plan: plan)
        
        let probePhase = result.phases.first { $0.name == "Idempotent Probing" }
        XCTAssertNotNil(probePhase)
        XCTAssertNotNil(probePhase!.probeResults)
    }
    
    func testVerificationResultSummary() async {
        let plan = ToolPlanBuilder()
            .setIntent(ToolPlanIntent(type: .createDraft, summary: "Draft", targetDescription: ""))
            .setOriginatingAction("draft")
            .setRisk(score: 10, reasons: [])
            .setReversibility(.reversible, reason: "")
            .build()!
        
        let result = await verificationEngine.verify(plan: plan)
        
        XCTAssertFalse(result.summary.isEmpty)
        XCTAssertTrue(result.summary.contains("PASSED") || result.summary.contains("FAILED"))
    }
    
    // MARK: - Escalation Tests
    
    func testLowConfidenceRequiresEscalation() async {
        // Create a plan with many required probes that might fail
        let plan = ToolPlanBuilder()
            .setIntent(ToolPlanIntent(type: .externalAPICall, summary: "API", targetDescription: ""))
            .setOriginatingAction("api")
            .setRisk(score: 60, reasons: [])
            .setReversibility(.irreversible, reason: "")
            .addProbe(ProbeDefinition(type: .endpointHealth, description: "Health", target: "api", isRequired: true))
            .addProbe(ProbeDefinition(type: .permissionCheck, description: "Permission", target: "api", isRequired: true))
            .addProbe(ProbeDefinition(type: .quotaCheck, description: "Quota", target: "api", isRequired: true))
            .build()!
        
        let result = await verificationEngine.verify(plan: plan)
        
        // The result should indicate if escalation is needed based on confidence
        if result.confidence < 0.8 {
            XCTAssertTrue(result.requiresEscalation)
        }
    }
}
