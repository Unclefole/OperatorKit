import Foundation

// ============================================================================
// PIPELINE MODELS (Phase 11B)
//
// Zero-content pipeline tracking models.
// No prospect identity. Counts and stages only.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ NO company name
// ❌ NO person name
// ❌ NO email
// ❌ NO notes
// ❌ NO domain
// ❌ NO free text
// ✅ UUID only
// ✅ Stage enum
// ✅ Channel enum
// ✅ Day-rounded dates
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Pipeline Stage

public enum PipelineStage: String, Codable, CaseIterable {
    case leadContacted = "lead_contacted"
    case demoScheduled = "demo_scheduled"
    case pilotRequested = "pilot_requested"
    case securityReview = "security_review"
    case procurement = "procurement"
    case closedWon = "closed_won"
    case closedLost = "closed_lost"
    
    public var displayName: String {
        switch self {
        case .leadContacted: return "Lead Contacted"
        case .demoScheduled: return "Demo Scheduled"
        case .pilotRequested: return "Pilot Requested"
        case .securityReview: return "Security Review"
        case .procurement: return "Procurement"
        case .closedWon: return "Closed Won"
        case .closedLost: return "Closed Lost"
        }
    }
    
    public var icon: String {
        switch self {
        case .leadContacted: return "person.badge.plus"
        case .demoScheduled: return "calendar"
        case .pilotRequested: return "airplane"
        case .securityReview: return "shield"
        case .procurement: return "building.2"
        case .closedWon: return "checkmark.seal.fill"
        case .closedLost: return "xmark.seal"
        }
    }
    
    public var isOpen: Bool {
        switch self {
        case .closedWon, .closedLost: return false
        default: return true
        }
    }
    
    public var sortOrder: Int {
        switch self {
        case .leadContacted: return 0
        case .demoScheduled: return 1
        case .pilotRequested: return 2
        case .securityReview: return 3
        case .procurement: return 4
        case .closedWon: return 5
        case .closedLost: return 6
        }
    }
    
    /// Next possible stages
    public var nextStages: [PipelineStage] {
        switch self {
        case .leadContacted: return [.demoScheduled, .closedLost]
        case .demoScheduled: return [.pilotRequested, .closedLost]
        case .pilotRequested: return [.securityReview, .procurement, .closedWon, .closedLost]
        case .securityReview: return [.procurement, .closedWon, .closedLost]
        case .procurement: return [.closedWon, .closedLost]
        case .closedWon: return []
        case .closedLost: return []
        }
    }
}

// MARK: - Pipeline Channel

public enum PipelineChannel: String, Codable, CaseIterable {
    case referral = "referral"
    case outboundEmail = "outbound_email"
    case inbound = "inbound"
    case appStore = "app_store"
    case other = "other"
    
    public var displayName: String {
        switch self {
        case .referral: return "Referral"
        case .outboundEmail: return "Outbound Email"
        case .inbound: return "Inbound"
        case .appStore: return "App Store"
        case .other: return "Other"
        }
    }
    
    public var icon: String {
        switch self {
        case .referral: return "person.2"
        case .outboundEmail: return "envelope"
        case .inbound: return "tray.and.arrow.down"
        case .appStore: return "app.badge"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Pipeline Item

public struct PipelineItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let createdAtDayRounded: String
    public var stage: PipelineStage
    public let channel: PipelineChannel
    public var lastUpdatedAtDayRounded: String
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public init(
        id: UUID = UUID(),
        stage: PipelineStage = .leadContacted,
        channel: PipelineChannel = .other
    ) {
        self.id = id
        self.createdAtDayRounded = Self.dayRoundedNow()
        self.stage = stage
        self.channel = channel
        self.lastUpdatedAtDayRounded = Self.dayRoundedNow()
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    public mutating func moveToStage(_ newStage: PipelineStage) {
        stage = newStage
        lastUpdatedAtDayRounded = Self.dayRoundedNow()
    }
    
    private static func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}

// MARK: - Pipeline Summary

public struct PipelineSummary: Codable {
    public let totalItems: Int
    public let openItems: Int
    public let closedWonCount: Int
    public let closedLostCount: Int
    public let countsByStage: [String: Int]
    public let countsByChannel: [String: Int]
    public let capturedAtDayRounded: String
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    /// Forbidden keys that must never appear in this export
    public static let forbiddenKeys: [String] = [
        "body", "subject", "content", "draft", "prompt",
        "context", "email", "recipient", "attendees", "title",
        "description", "message", "text", "name", "address",
        "company", "domain", "phone", "note", "notes"
    ]
    
    public init(items: [PipelineItem]) {
        self.totalItems = items.count
        self.openItems = items.filter { $0.stage.isOpen }.count
        self.closedWonCount = items.filter { $0.stage == .closedWon }.count
        self.closedLostCount = items.filter { $0.stage == .closedLost }.count
        
        var stageMap: [String: Int] = [:]
        for stage in PipelineStage.allCases {
            stageMap[stage.rawValue] = items.filter { $0.stage == stage }.count
        }
        self.countsByStage = stageMap
        
        var channelMap: [String: Int] = [:]
        for channel in PipelineChannel.allCases {
            channelMap[channel.rawValue] = items.filter { $0.channel == channel }.count
        }
        self.countsByChannel = channelMap
        
        self.capturedAtDayRounded = Self.dayRoundedNow()
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    private static func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
    
    /// Validates export contains no forbidden keys
    public func validateNoForbiddenKeys() throws -> [String] {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(self)
        
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }
        
        return findForbiddenKeys(in: json, path: "")
    }
    
    private func findForbiddenKeys(in dict: [String: Any], path: String) -> [String] {
        var violations: [String] = []
        
        for (key, value) in dict {
            let fullPath = path.isEmpty ? key : "\(path).\(key)"
            
            if Self.forbiddenKeys.contains(key.lowercased()) {
                violations.append("Forbidden key: \(fullPath)")
            }
            
            if let nested = value as? [String: Any] {
                violations.append(contentsOf: findForbiddenKeys(in: nested, path: fullPath))
            }
        }
        
        return violations
    }
}
