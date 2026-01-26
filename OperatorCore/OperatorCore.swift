import Foundation

public enum OperatorCore {
    
    private static let engine = DecisionEngine()
    
    public static func evaluate(action: OperatorAction, context: OperatorContext) -> Outcome {
        let outcome = engine.evaluate(action: action, context: context)
        OperatorLog.shared.append(outcome: outcome)
        return outcome
    }
    
    public static func evaluate(
        actionName: String,
        requiredTrust: TrustBoundary,
        context: OperatorContext
    ) -> Outcome {
        let action = OperatorAction(
            name: actionName,
            requiredTrustLevel: requiredTrust
        )
        return evaluate(action: action, context: context)
    }
    
    public static func validateTrust(
        boundary: TrustBoundary,
        context: OperatorContext
    ) -> TrustValidationResult {
        boundary.validate(context: context)
    }
    
    public static var log: OperatorLog {
        OperatorLog.shared
    }
}
