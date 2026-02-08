import XCTest
@testable import OperatorKit

final class PolicyEngineTests: XCTestCase {
    
    var policyEngine: PolicyEngine!
    
    override func setUp() {
        super.setUp()
        policyEngine = PolicyEngine.shared
    }
    
    // MARK: - Risk Tier to Approval Mapping Tests
    
    func testLowRiskAutoApproves() {
        let assessment = RiskAssessment(
            score: 15,
            tier: .low,
            reasons: [],
            dimensions: RiskDimensions()
        )
        
        let decision = policyEngine.mapToApproval(assessment: assessment)
        
        XCTAssertEqual(decision.tier, .low)
        XCTAssertEqual(decision.approvalRequirement.approvalsNeeded, 0)
        XCTAssertFalse(decision.approvalRequirement.requiresBiometric)
        XCTAssertFalse(decision.approvalRequirement.requiresPreview)
    }
    
    func testMediumRiskRequiresPreview() {
        let assessment = RiskAssessment(
            score: 35,
            tier: .medium,
            reasons: [],
            dimensions: RiskDimensions()
        )
        
        let decision = policyEngine.mapToApproval(assessment: assessment)
        
        XCTAssertEqual(decision.tier, .medium)
        XCTAssertTrue(decision.approvalRequirement.requiresPreview)
        XCTAssertEqual(decision.approvalRequirement.approvalsNeeded, 1)
    }
    
    func testHighRiskRequiresBiometric() {
        let assessment = RiskAssessment(
            score: 65,
            tier: .high,
            reasons: [],
            dimensions: RiskDimensions()
        )
        
        let decision = policyEngine.mapToApproval(assessment: assessment)
        
        XCTAssertEqual(decision.tier, .high)
        XCTAssertTrue(decision.approvalRequirement.requiresBiometric)
        XCTAssertTrue(decision.approvalRequirement.requiresPreview)
    }
    
    func testCriticalRiskRequiresMultiSig() {
        let assessment = RiskAssessment(
            score: 85,
            tier: .critical,
            reasons: [],
            dimensions: RiskDimensions()
        )
        
        let decision = policyEngine.mapToApproval(assessment: assessment)
        
        XCTAssertEqual(decision.tier, .critical)
        XCTAssertGreaterThanOrEqual(decision.approvalRequirement.multiSignerCount, 2)
        XCTAssertTrue(decision.approvalRequirement.requiresBiometric)
        XCTAssertGreaterThan(decision.approvalRequirement.cooldownSeconds, 0)
    }
    
    // MARK: - Intent Type Base Approval Tests
    
    func testReadOnlyIntentsAutoApprove() {
        let readCalendarApproval = policyEngine.baseApprovalForIntent(type: .readCalendar)
        XCTAssertEqual(readCalendarApproval.approvalsNeeded, 0)
        
        let readContactsApproval = policyEngine.baseApprovalForIntent(type: .readContacts)
        XCTAssertEqual(readContactsApproval.approvalsNeeded, 0)
    }
    
    func testDraftCreationRequiresPreview() {
        let approval = policyEngine.baseApprovalForIntent(type: .createDraft)
        XCTAssertTrue(approval.requiresPreview)
    }
    
    func testSendEmailRequiresBiometric() {
        let approval = policyEngine.baseApprovalForIntent(type: .sendEmail)
        XCTAssertTrue(approval.requiresBiometric)
    }
    
    func testExternalAPICallRequiresMultiSig() {
        let approval = policyEngine.baseApprovalForIntent(type: .externalAPICall)
        XCTAssertGreaterThanOrEqual(approval.multiSignerCount, 2)
    }
    
    func testDatabaseMutationRequiresMultiSig() {
        let approval = policyEngine.baseApprovalForIntent(type: .databaseMutation)
        XCTAssertGreaterThanOrEqual(approval.multiSignerCount, 2)
    }
    
    // MARK: - Policy Constraint Tests
    
    func testHighRiskHasTimeWindowConstraint() {
        let assessment = RiskAssessment(
            score: 70,
            tier: .high,
            reasons: [],
            dimensions: RiskDimensions()
        )
        
        let decision = policyEngine.mapToApproval(assessment: assessment)
        
        let hasTimeConstraint = decision.constraints.contains { $0.type == .timeWindow }
        XCTAssertTrue(hasTimeConstraint)
    }
    
    func testExternalExposureHasRateLimitConstraint() {
        let dimensions = RiskDimensions(
            financialImpact: 0,
            externalExposure: 60,
            dataSensitivity: 0,
            systemMutation: 0,
            reversibility: 0,
            scope: 0
        )
        
        let assessment = RiskAssessment(
            score: 50,
            tier: .medium,
            reasons: [],
            dimensions: dimensions
        )
        
        let decision = policyEngine.mapToApproval(assessment: assessment)
        
        let hasRateLimitConstraint = decision.constraints.contains { $0.type == .rateLimit }
        XCTAssertTrue(hasRateLimitConstraint)
    }
    
    func testAllDecisionsHaveAuditConstraint() {
        let tiers: [RiskTier] = [.low, .medium, .high, .critical]
        
        for tier in tiers {
            let score: Int
            switch tier {
            case .low: score = 10
            case .medium: score = 30
            case .high: score = 60
            case .critical: score = 90
            }
            
            let assessment = RiskAssessment(
                score: score,
                tier: tier,
                reasons: [],
                dimensions: RiskDimensions()
            )
            
            let decision = policyEngine.mapToApproval(assessment: assessment)
            let hasAuditConstraint = decision.constraints.contains { $0.type == .auditRequired }
            XCTAssertTrue(hasAuditConstraint, "Tier \(tier) should have audit constraint")
        }
    }
    
    // MARK: - Policy Decision Output Tests
    
    func testPolicyDecisionHasAppliedPolicies() {
        let assessment = RiskAssessment(
            score: 50,
            tier: .medium,
            reasons: [],
            dimensions: RiskDimensions()
        )
        
        let decision = policyEngine.mapToApproval(assessment: assessment)
        
        XCTAssertFalse(decision.appliedPolicies.isEmpty)
        XCTAssertTrue(decision.appliedPolicies.contains("BASE_POLICY_v1"))
    }
    
    func testPolicyDecisionSummary() {
        let assessment = RiskAssessment(
            score: 85,
            tier: .critical,
            reasons: [],
            dimensions: RiskDimensions()
        )
        
        let decision = policyEngine.mapToApproval(assessment: assessment)
        
        XCTAssertFalse(decision.summary.isEmpty)
        XCTAssertTrue(decision.summary.contains("CRITICAL"))
    }
    
    // MARK: - Policy Configuration Tests
    
    func testDefaultPolicyConfiguration() {
        let snapshot = policyEngine.currentPolicySnapshot()
        
        XCTAssertEqual(snapshot.version, "1.0.0")
        XCTAssertEqual(snapshot.lowTierApproval.approvalsNeeded, 0)
        XCTAssertTrue(snapshot.mediumTierApproval.requiresPreview)
        XCTAssertTrue(snapshot.highTierApproval.requiresBiometric)
        XCTAssertGreaterThanOrEqual(snapshot.criticalTierApproval.multiSignerCount, 2)
    }
    
    func testStrictPolicyConfiguration() {
        let strictPolicy = PolicyConfiguration.strictPolicy
        
        // Even low tier requires preview in strict mode
        XCTAssertTrue(strictPolicy.lowTierApproval.requiresPreview)
        
        // Medium tier requires biometric in strict mode
        XCTAssertTrue(strictPolicy.mediumTierApproval.requiresBiometric)
        
        // Critical tier requires 3 signers in strict mode
        XCTAssertEqual(strictPolicy.criticalTierApproval.multiSignerCount, 3)
    }
    
    #if DEBUG
    func testPolicyUpdateRequiresAuthorization() {
        let newPolicy = PolicyConfiguration.strictPolicy
        let expiredToken = PolicyAuthorizationToken(
            issuedAt: Date().addingTimeInterval(-3600),
            validForSeconds: 300,
            scope: .policyUpdate
        )
        
        let result = policyEngine.updatePolicy(newPolicy, authorization: expiredToken)
        XCTAssertFalse(result, "Expired token should not authorize policy update")
        
        let validToken = PolicyAuthorizationToken.testToken()
        let successResult = policyEngine.updatePolicy(newPolicy, authorization: validToken)
        XCTAssertTrue(successResult, "Valid token should authorize policy update")
    }
    #endif
}
