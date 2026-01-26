import Foundation

public struct OperatorAction: Equatable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let timestamp: Date
    public let requiredTrustLevel: TrustBoundary
    
    public init(
        id: UUID = UUID(),
        name: String,
        timestamp: Date = Date(),
        requiredTrustLevel: TrustBoundary
    ) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.requiredTrustLevel = requiredTrustLevel
    }
}

extension OperatorAction: CustomStringConvertible {
    public var description: String {
        "OperatorAction(\(name), trust: \(requiredTrustLevel))"
    }
}
