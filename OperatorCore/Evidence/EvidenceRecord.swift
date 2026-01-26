import Foundation

public struct EvidenceRecord: Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let actionId: UUID
    public let actionName: String
    public let requiredTrust: TrustBoundary
    public let evaluatedTrustScore: Double
    public let trustValidation: TrustValidationResult
    public let actorId: String
    public let actorRole: OperatorContext.Actor.Role
    public let environmentSnapshot: EnvironmentSnapshot
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        action: OperatorAction,
        context: OperatorContext,
        trustValidation: TrustValidationResult
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actionId = action.id
        self.actionName = action.name
        self.requiredTrust = action.requiredTrustLevel
        self.evaluatedTrustScore = context.deviceTrustScore.value
        self.trustValidation = trustValidation
        self.actorId = context.actor.id
        self.actorRole = context.actor.role
        self.environmentSnapshot = EnvironmentSnapshot(from: context.environment)
    }
    
    public struct EnvironmentSnapshot: Equatable, Sendable {
        public let isDebug: Bool
        public let platform: String
        public let osVersion: String
        
        public init(from environment: OperatorContext.Environment) {
            self.isDebug = environment.isDebug
            self.platform = environment.platform
            self.osVersion = environment.osVersion
        }
    }
}

extension EvidenceRecord: CustomStringConvertible {
    public var description: String {
        "EvidenceRecord(action: \(actionName), trust: \(trustValidation.isTrusted ? "trusted" : "untrusted"), score: \(evaluatedTrustScore))"
    }
}
