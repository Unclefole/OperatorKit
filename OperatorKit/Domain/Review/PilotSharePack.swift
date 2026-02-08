import Foundation

// ============================================================================
// PILOT SHARE PACK (Phase 10O)
//
// Single metadata-only artifact aggregating all pilot exports.
// User-initiated export only.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No networking
// ❌ No auto-export
// ✅ Metadata-only
// ✅ Aggregates existing exports
// ✅ User-initiated via ShareSheet
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Pilot Share Pack

public struct PilotSharePack: Codable {
    
    // MARK: - Metadata
    
    public let schemaVersion: Int
    public let exportedAt: String  // Day-rounded
    public let appVersion: String
    public let buildNumber: String
    public let releaseMode: String
    
    // MARK: - Included Packets
    
    /// Enterprise readiness summary (not full packet to keep size down)
    public let enterpriseReadinessSummary: PilotEnterpriseReadinessSummary?
    
    /// Quality packet summary
    public let qualitySummary: QualityPacketSummary?
    
    /// Diagnostics summary
    public let diagnosticsSummary: DiagnosticsPacketSummary?
    
    /// Policy summary
    public let policySummary: PolicyPacketSummary?
    
    /// Team summary (metadata only)
    public let teamSummary: TeamPacketSummary?
    
    /// Conversion/activation summary
    public let conversionSummary: ConversionPacketSummary?
    
    // MARK: - Export Status
    
    /// Which sections were available
    public let availableSections: [String]
    
    /// Which sections were unavailable
    public let unavailableSections: [String]
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Export
    
    public func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
    
    public var filename: String {
        "OperatorKit_PilotSharePack_\(exportedAt).json"
    }
    
    // MARK: - Validation
    
    public func validateNoForbiddenKeys() throws -> [String] {
        let jsonData = try toJSONData()
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }
        
        return Self.findForbiddenKeys(in: json, path: "")
    }
    
    public static let forbiddenKeys: [String] = [
        "body", "subject", "content", "draft", "prompt",
        "context", "note", "email", "attendees", "title",
        "description", "message", "text", "recipient", "sender",
        "userId", "deviceId", "receipt"
    ]
    
    private static func findForbiddenKeys(in dict: [String: Any], path: String) -> [String] {
        var violations: [String] = []
        
        for (key, value) in dict {
            let fullPath = path.isEmpty ? key : "\(path).\(key)"
            
            if forbiddenKeys.contains(key.lowercased()) {
                violations.append("Forbidden key: \(fullPath)")
            }
            
            if let nested = value as? [String: Any] {
                violations.append(contentsOf: findForbiddenKeys(in: nested, path: fullPath))
            }
            
            if let array = value as? [[String: Any]] {
                for (index, item) in array.enumerated() {
                    violations.append(contentsOf: findForbiddenKeys(in: item, path: "\(fullPath)[\(index)]"))
                }
            }
        }
        
        return violations
    }
    
    // MARK: - Round-trip
    
    public static func fromJSONData(_ data: Data) throws -> PilotSharePack {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PilotSharePack.self, from: data)
    }
}

// MARK: - Summary Types

public struct PilotEnterpriseReadinessSummary: Codable {
    public let readinessStatus: String
    public let readinessScore: Int
    public let safetyContractMatch: Bool
    public let docIntegrityPassing: Bool
    public let sectionsAvailable: Int
    public let schemaVersion: Int
}

public struct QualityPacketSummary: Codable {
    public let qualityGateStatus: String
    public let coverageScore: Int
    public let trendDirection: String
    public let invariantsPassing: Bool
    public let schemaVersion: Int
}

public struct DiagnosticsPacketSummary: Codable {
    public let totalExecutions: Int
    public let approvalRate: Double?
    public let invariantsPassing: Bool
    public let schemaVersion: Int
}

public struct PolicyPacketSummary: Codable {
    public let allowEmailDrafts: Bool
    public let allowCalendarWrites: Bool
    public let allowTaskCreation: Bool
    public let allowMemoryWrites: Bool
    public let schemaVersion: Int
}

public struct TeamPacketSummary: Codable {
    public let hasTeamTier: Bool
    public let hasActiveTrial: Bool
    public let teamMembersCount: Int?
    public let policyTemplatesCount: Int
    public let schemaVersion: Int
}

public struct ConversionPacketSummary: Codable {
    public let pricingVariant: String
    public let totalPurchases: Int
    public let satisfactionAverage: Double?
    public let templatesUsed: Int
    public let schemaVersion: Int
}
