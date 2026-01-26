import Foundation

public enum Outcome: Equatable, Sendable {
    case allowed(EvidenceRecord)
    case denied(EvidenceRecord)
    case requiresEscalation(EvidenceRecord, reason: EscalationReason)
    
    public var evidence: EvidenceRecord {
        switch self {
        case .allowed(let record): return record
        case .denied(let record): return record
        case .requiresEscalation(let record, _): return record
        }
    }
    
    public var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }
    
    public var isDenied: Bool {
        if case .denied = self { return true }
        return false
    }
    
    public var requiresEscalation: Bool {
        if case .requiresEscalation = self { return true }
        return false
    }
    
    public enum EscalationReason: Equatable, Hashable, Sendable {
        case nearTrustThreshold
        case debugEnvironment
        case unknownActor
        case custom(String)
    }
}

extension Outcome: CustomStringConvertible {
    public var description: String {
        switch self {
        case .allowed(let evidence):
            return "Outcome.allowed(\(evidence.actionName))"
        case .denied(let evidence):
            return "Outcome.denied(\(evidence.actionName))"
        case .requiresEscalation(let evidence, let reason):
            return "Outcome.requiresEscalation(\(evidence.actionName), reason: \(reason))"
        }
    }
}
