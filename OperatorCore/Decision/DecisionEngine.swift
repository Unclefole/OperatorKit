import Foundation

public struct DecisionEngine: Sendable {
    
    public init() {}
    
    public func evaluate(action: OperatorAction, context: OperatorContext) -> Outcome {
        let trustValidation = action.requiredTrustLevel.validate(context: context)
        
        let evidence = EvidenceRecord(
            action: action,
            context: context,
            trustValidation: trustValidation
        )
        
        switch trustValidation {
        case .trusted:
            if shouldEscalate(action: action, context: context) {
                return .requiresEscalation(evidence, reason: escalationReason(context: context))
            }
            return .allowed(evidence)
            
        case .untrusted:
            if isNearThreshold(context: context, required: action.requiredTrustLevel) {
                return .requiresEscalation(evidence, reason: .nearTrustThreshold)
            }
            return .denied(evidence)
        }
    }
    
    private func shouldEscalate(action: OperatorAction, context: OperatorContext) -> Bool {
        if context.environment.isDebug && action.requiredTrustLevel == .system {
            return true
        }
        if context.actor.role == .automation && action.requiredTrustLevel >= .userVerified {
            return true
        }
        return false
    }
    
    private func escalationReason(context: OperatorContext) -> Outcome.EscalationReason {
        if context.environment.isDebug {
            return .debugEnvironment
        }
        if context.actor.role == .automation {
            return .unknownActor
        }
        return .custom("policy escalation required")
    }
    
    private func isNearThreshold(context: OperatorContext, required: TrustBoundary) -> Bool {
        let threshold = required.minimumTrustScore
        let score = context.deviceTrustScore.value
        let margin = 0.1
        return score >= (threshold - margin) && score < threshold
    }
}
