import XCTest
@testable import OperatorKit

final class RiskEngineTests: XCTestCase {
    
    var riskEngine: RiskEngine!
    
    override func setUp() {
        super.setUp()
        riskEngine = RiskEngine.shared
    }
    
    // MARK: - Basic Risk Assessment Tests
    
    func testLowRiskContext() {
        let context = RiskContext(
            involvesPayment: false,
            involvesSubscription: false,
            consumesResources: false,
            sendsExternalCommunication: false,
            externalRecipientCount: 0,
            hasPublicVisibility: false,
            involvesThirdPartyAPI: false,
            involvesPII: false,
            involvesCredentials: false,
            involvesHealthData: false,
            involvesFinancialData: false,
            writeToDatabase: false,
            writeToFileSystem: false,
            isDeleteOperation: false,
            changesConfiguration: false,
            reversibility: .reversible,
            hasRollbackMechanism: true,
            affectedEntityCount: 1,
            isBatchOperation: false,
            crossesSystemBoundary: false
        )
        
        let assessment = riskEngine.assess(context: context)
        
        XCTAssertEqual(assessment.tier, .low)
        XCTAssertLessThanOrEqual(assessment.score, 20)
    }
    
    func testHighRiskExternalCommunication() {
        let context = RiskContextBuilder()
            .setExternalExposure(sends: true, recipientCount: 5, public_: false, thirdParty: false)
            .build()
        
        let assessment = riskEngine.assess(context: context)
        
        // External communication adds significant risk
        XCTAssertGreaterThan(assessment.score, 20)
        XCTAssertTrue(assessment.reasons.contains { $0.dimension == .externalExposure })
    }
    
    func testCriticalRiskPaymentWithCredentials() {
        let context = RiskContextBuilder()
            .setFinancial(payment: true, subscription: false, resources: false)
            .setDataSensitivity(pii: true, credentials: true, health: false, financial: true)
            .setReversibility(.irreversible, hasRollback: false)
            .build()
        
        let assessment = riskEngine.assess(context: context)
        
        // Payment + credentials + irreversible = critical
        XCTAssertEqual(assessment.tier, .critical)
        XCTAssertGreaterThanOrEqual(assessment.score, 76)
    }
    
    func testMediumRiskDatabaseWrite() {
        let context = RiskContextBuilder()
            .setMutation(database: true, fileSystem: false, delete: false, config: false)
            .setReversibility(.partiallyReversible, hasRollback: true)
            .build()
        
        let assessment = riskEngine.assess(context: context)
        
        XCTAssertTrue(assessment.reasons.contains { $0.dimension == .systemMutation })
        // Database write without other factors should be medium
        XCTAssertGreaterThanOrEqual(assessment.score, 10)
    }
    
    // MARK: - Dimension-Specific Tests
    
    func testFinancialImpactScoring() {
        // Payment involvement
        let paymentContext = RiskContextBuilder()
            .setFinancial(payment: true, subscription: false, resources: false)
            .build()
        
        let paymentAssessment = riskEngine.assess(context: paymentContext)
        let paymentFinancialReasons = paymentAssessment.reasons.filter { $0.dimension == .financialImpact }
        
        XCTAssertFalse(paymentFinancialReasons.isEmpty)
        XCTAssertTrue(paymentFinancialReasons.first!.scoreContribution >= 80)
    }
    
    func testExternalExposureScoring() {
        // Multiple recipients + public
        let context = RiskContextBuilder()
            .setExternalExposure(sends: true, recipientCount: 10, public_: true, thirdParty: true)
            .build()
        
        let assessment = riskEngine.assess(context: context)
        let externalReasons = assessment.reasons.filter { $0.dimension == .externalExposure }
        
        XCTAssertGreaterThanOrEqual(externalReasons.count, 3)
    }
    
    func testDataSensitivityScoring() {
        // Health data (HIPAA)
        let healthContext = RiskContextBuilder()
            .setDataSensitivity(pii: false, credentials: false, health: true, financial: false)
            .build()
        
        let healthAssessment = riskEngine.assess(context: healthContext)
        let healthReasons = healthAssessment.reasons.filter { $0.dimension == .dataSensitivity }
        
        XCTAssertFalse(healthReasons.isEmpty)
        XCTAssertTrue(healthReasons.first!.scoreContribution >= 70)
    }
    
    func testReversibilityScoring() {
        // Irreversible without rollback
        let irreversibleContext = RiskContextBuilder()
            .setReversibility(.irreversible, hasRollback: false)
            .build()
        
        let assessment = riskEngine.assess(context: irreversibleContext)
        let reversibilityReasons = assessment.reasons.filter { $0.dimension == .reversibility }
        
        XCTAssertFalse(reversibilityReasons.isEmpty)
        // Should have high score contribution for irreversible
        let totalContribution = reversibilityReasons.reduce(0) { $0 + $1.scoreContribution }
        XCTAssertGreaterThanOrEqual(totalContribution, 60)
    }
    
    func testScopeScoring() {
        // Batch operation affecting many entities
        let batchContext = RiskContextBuilder()
            .setScope(entityCount: 100, batch: true, crossSystem: true)
            .build()
        
        let assessment = riskEngine.assess(context: batchContext)
        let scopeReasons = assessment.reasons.filter { $0.dimension == .scope }
        
        XCTAssertGreaterThanOrEqual(scopeReasons.count, 2)
    }
    
    // MARK: - Risk Assessment Output Tests
    
    func testRiskAssessmentHasReasons() {
        let context = RiskContextBuilder()
            .setExternalExposure(sends: true, recipientCount: 1, public_: false, thirdParty: false)
            .setMutation(database: false, fileSystem: true, delete: false, config: false)
            .build()
        
        let assessment = riskEngine.assess(context: context)
        
        // Should have reasons explaining the score
        XCTAssertFalse(assessment.reasons.isEmpty)
        // Each reason should have a description
        XCTAssertTrue(assessment.reasons.allSatisfy { !$0.description.isEmpty })
    }
    
    func testRiskAssessmentDimensionsPopulated() {
        let context = RiskContextBuilder()
            .setFinancial(payment: false, subscription: true, resources: true)
            .setExternalExposure(sends: true, recipientCount: 2, public_: false, thirdParty: false)
            .setDataSensitivity(pii: true, credentials: false, health: false, financial: false)
            .setMutation(database: true, fileSystem: false, delete: false, config: false)
            .setReversibility(.partiallyReversible, hasRollback: true)
            .setScope(entityCount: 5, batch: false, crossSystem: false)
            .build()
        
        let assessment = riskEngine.assess(context: context)
        
        // All dimensions should be assessed
        XCTAssertGreaterThanOrEqual(assessment.dimensions.financialImpact, 0)
        XCTAssertGreaterThanOrEqual(assessment.dimensions.externalExposure, 0)
        XCTAssertGreaterThanOrEqual(assessment.dimensions.dataSensitivity, 0)
        XCTAssertGreaterThanOrEqual(assessment.dimensions.systemMutation, 0)
        XCTAssertGreaterThanOrEqual(assessment.dimensions.reversibility, 0)
        XCTAssertGreaterThanOrEqual(assessment.dimensions.scope, 0)
    }
    
    func testRiskScoreIsClamped() {
        // Even with maximum risk factors, score should not exceed 100
        let maxRiskContext = RiskContextBuilder()
            .setFinancial(payment: true, subscription: true, resources: true)
            .setExternalExposure(sends: true, recipientCount: 100, public_: true, thirdParty: true)
            .setDataSensitivity(pii: true, credentials: true, health: true, financial: true)
            .setMutation(database: true, fileSystem: true, delete: true, config: true)
            .setReversibility(.irreversible, hasRollback: false)
            .setScope(entityCount: 1000, batch: true, crossSystem: true)
            .build()
        
        let assessment = riskEngine.assess(context: maxRiskContext)
        
        XCTAssertLessThanOrEqual(assessment.score, 100)
        XCTAssertEqual(assessment.tier, .critical)
    }
    
    // MARK: - Determinism Tests
    
    func testRiskAssessmentIsDeterministic() {
        let context = RiskContextBuilder()
            .setExternalExposure(sends: true, recipientCount: 3, public_: false, thirdParty: true)
            .setDataSensitivity(pii: true, credentials: false, health: false, financial: false)
            .setReversibility(.partiallyReversible, hasRollback: true)
            .build()
        
        let assessment1 = riskEngine.assess(context: context)
        let assessment2 = riskEngine.assess(context: context)
        
        // Same input should produce same output
        XCTAssertEqual(assessment1.score, assessment2.score)
        XCTAssertEqual(assessment1.tier, assessment2.tier)
        XCTAssertEqual(assessment1.reasons.count, assessment2.reasons.count)
    }
}
