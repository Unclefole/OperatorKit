import Foundation

public enum TrustBoundary: Int, Equatable, Hashable, Sendable, CaseIterable, Comparable {
    case restricted = 0
    case userVerified = 1
    case system = 2
    
    public static func < (lhs: TrustBoundary, rhs: TrustBoundary) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    public var minimumTrustScore: Double {
        switch self {
        case .restricted: return 0.0
        case .userVerified: return 0.5
        case .system: return 0.9
        }
    }
    
    public func validate(context: OperatorContext) -> TrustValidationResult {
        let meetsScoreRequirement = context.deviceTrustScore.value >= minimumTrustScore
        let meetsRoleRequirement = validateRole(context.actor.role)
        
        if meetsScoreRequirement && meetsRoleRequirement {
            return .trusted(boundary: self, score: context.deviceTrustScore.value)
        } else {
            return .untrusted(
                required: self,
                actual: context.deviceTrustScore.value,
                reason: buildReason(meetsScoreRequirement: meetsScoreRequirement, meetsRoleRequirement: meetsRoleRequirement)
            )
        }
    }
    
    private func validateRole(_ role: OperatorContext.Actor.Role) -> Bool {
        switch self {
        case .restricted:
            return true
        case .userVerified:
            return role == .user || role == .system
        case .system:
            return role == .system
        }
    }
    
    private func buildReason(meetsScoreRequirement: Bool, meetsRoleRequirement: Bool) -> String {
        var reasons: [String] = []
        if !meetsScoreRequirement {
            reasons.append("trust score below threshold")
        }
        if !meetsRoleRequirement {
            reasons.append("insufficient role privileges")
        }
        return reasons.joined(separator: "; ")
    }
}

public enum TrustValidationResult: Equatable, Sendable {
    case trusted(boundary: TrustBoundary, score: Double)
    case untrusted(required: TrustBoundary, actual: Double, reason: String)
    
    public var isTrusted: Bool {
        if case .trusted = self { return true }
        return false
    }
}
