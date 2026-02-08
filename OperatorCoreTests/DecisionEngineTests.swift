import XCTest
@testable import OperatorCore

final class DecisionEngineTests: XCTestCase {
    
    private var engine: DecisionEngine!
    
    override func setUp() {
        super.setUp()
        engine = DecisionEngine()
        OperatorLog.shared.clear()
    }
    
    override func tearDown() {
        engine = nil
        OperatorLog.shared.clear()
        super.tearDown()
    }
    
    func testAllowedDecision() {
        let action = OperatorAction(
            name: "readData",
            requiredTrustLevel: .restricted
        )
        
        let context = OperatorContext(
            environment: OperatorContext.Environment(
                isDebug: false,
                platform: "iOS",
                osVersion: "17.0"
            ),
            actor: OperatorContext.Actor(
                id: "user-123",
                role: .user
            ),
            deviceTrustScore: OperatorContext.DeviceTrustScore(
                value: 0.8,
                factors: [
                    .init(name: "passcode", passed: true),
                    .init(name: "biometric", passed: true)
                ]
            )
        )
        
        let outcome = engine.evaluate(action: action, context: context)
        
        XCTAssertTrue(outcome.isAllowed)
        XCTAssertFalse(outcome.isDenied)
        XCTAssertFalse(outcome.requiresEscalation)
        XCTAssertEqual(outcome.evidence.actionName, "readData")
        XCTAssertEqual(outcome.evidence.requiredTrust, .restricted)
    }
    
    func testDeniedDecision() {
        let action = OperatorAction(
            name: "systemOperation",
            requiredTrustLevel: .system
        )
        
        let context = OperatorContext(
            environment: OperatorContext.Environment(
                isDebug: false,
                platform: "iOS",
                osVersion: "17.0"
            ),
            actor: OperatorContext.Actor(
                id: "user-456",
                role: .user
            ),
            deviceTrustScore: OperatorContext.DeviceTrustScore(
                value: 0.3,
                factors: [
                    .init(name: "passcode", passed: true),
                    .init(name: "biometric", passed: false)
                ]
            )
        )
        
        let outcome = engine.evaluate(action: action, context: context)
        
        XCTAssertFalse(outcome.isAllowed)
        XCTAssertTrue(outcome.isDenied)
        XCTAssertFalse(outcome.requiresEscalation)
        XCTAssertEqual(outcome.evidence.actionName, "systemOperation")
        XCTAssertEqual(outcome.evidence.requiredTrust, .system)
    }
    
    func testEscalationDecision() {
        let action = OperatorAction(
            name: "criticalOperation",
            requiredTrustLevel: .system
        )
        
        let context = OperatorContext(
            environment: OperatorContext.Environment(
                isDebug: true,
                platform: "iOS",
                osVersion: "17.0"
            ),
            actor: OperatorContext.Actor(
                id: "system",
                role: .system
            ),
            deviceTrustScore: OperatorContext.DeviceTrustScore(
                value: 0.95,
                factors: [
                    .init(name: "passcode", passed: true),
                    .init(name: "biometric", passed: true),
                    .init(name: "integrity", passed: true)
                ]
            )
        )
        
        let outcome = engine.evaluate(action: action, context: context)
        
        XCTAssertFalse(outcome.isAllowed)
        XCTAssertFalse(outcome.isDenied)
        XCTAssertTrue(outcome.requiresEscalation)
        XCTAssertEqual(outcome.evidence.actionName, "criticalOperation")
        
        if case .requiresEscalation(_, let reason) = outcome {
            XCTAssertEqual(reason, .debugEnvironment)
        } else {
            XCTFail("Expected escalation outcome")
        }
    }
}
