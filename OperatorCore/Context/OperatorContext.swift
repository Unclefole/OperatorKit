import Foundation

public struct OperatorContext: Equatable, Hashable, Sendable {
    public let environment: Environment
    public let actor: Actor
    public let deviceTrustScore: DeviceTrustScore
    
    public init(
        environment: Environment,
        actor: Actor,
        deviceTrustScore: DeviceTrustScore
    ) {
        self.environment = environment
        self.actor = actor
        self.deviceTrustScore = deviceTrustScore
    }
}

extension OperatorContext {
    public struct Environment: Equatable, Hashable, Sendable {
        public let isDebug: Bool
        public let platform: String
        public let osVersion: String
        
        public init(isDebug: Bool, platform: String, osVersion: String) {
            self.isDebug = isDebug
            self.platform = platform
            self.osVersion = osVersion
        }
        
        public static var current: Environment {
            Environment(
                isDebug: {
                    #if DEBUG
                    return true
                    #else
                    return false
                    #endif
                }(),
                platform: "iOS",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString
            )
        }
    }
    
    public struct Actor: Equatable, Hashable, Sendable {
        public let id: String
        public let role: Role
        
        public init(id: String, role: Role) {
            self.id = id
            self.role = role
        }
        
        public enum Role: String, Equatable, Hashable, Sendable, CaseIterable {
            case system
            case user
            case automation
        }
    }
    
    public struct DeviceTrustScore: Equatable, Hashable, Sendable {
        public let value: Double
        public let factors: [TrustFactor]
        
        public init(value: Double, factors: [TrustFactor]) {
            self.value = max(0, min(1, value))
            self.factors = factors
        }
        
        public struct TrustFactor: Equatable, Hashable, Sendable {
            public let name: String
            public let passed: Bool
            
            public init(name: String, passed: Bool) {
                self.name = name
                self.passed = passed
            }
        }
        
        public static var baseline: DeviceTrustScore {
            DeviceTrustScore(value: 0.5, factors: [])
        }
    }
}
