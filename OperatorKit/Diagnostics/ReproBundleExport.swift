import Foundation

// ============================================================================
// REPRO BUNDLE EXPORT (Phase 10P)
//
// Single artifact containing all diagnostic/quality/audit data.
// Metadata-only, user-initiated export only.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No networking
// ❌ No auto-export
// ✅ Aggregates existing exports
// ✅ Metadata-only
// ✅ User-initiated via ShareSheet
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Repro Bundle Export

public struct ReproBundleExport: Codable {
    
    // MARK: - Metadata
    
    public let schemaVersion: Int
    public let exportedAtDayRounded: String
    public let appVersion: String
    public let buildNumber: String
    public let releaseMode: String
    
    // MARK: - Included Packets (Summaries)
    
    /// Diagnostics summary
    public let diagnosticsSummary: DiagnosticsSummaryExport?
    
    /// Quality summary
    public let qualitySummary: QualitySummaryExport?
    
    /// Policy summary
    public let policySummary: ReproBundlePolicySummary?
    
    /// Pilot share pack summary
    public let pilotSummary: PilotSummaryExport?
    
    /// Audit trail summary (counts + recent 20 events)
    public let auditTrailSummary: CustomerAuditTrailSummary?
    
    // MARK: - Export Status
    
    public let availableSections: [String]
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
        "OperatorKit_ReproBundle_\(exportedAtDayRounded).json"
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
        "userId", "deviceId", "receipt", "freeText"
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
    
    public static func fromJSONData(_ data: Data) throws -> ReproBundleExport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ReproBundleExport.self, from: data)
    }
}

// MARK: - Summary Types

public struct DiagnosticsSummaryExport: Codable {
    public let totalExecutions: Int
    public let successCount: Int
    public let failureCount: Int
    public let approvalRate: Double?
    public let invariantsPassing: Bool
    public let schemaVersion: Int
}

public struct QualitySummaryExport: Codable {
    public let qualityGateStatus: String
    public let coverageScore: Int
    public let trendDirection: String
    public let invariantsPassing: Bool
    public let lastEvalDayRounded: String?
    public let schemaVersion: Int
}

public struct ReproBundlePolicySummary: Codable {
    public let policyEnabled: Bool
    public let allowEmailDrafts: Bool
    public let allowCalendarWrites: Bool
    public let allowTaskCreation: Bool
    public let allowMemoryWrites: Bool
    public let maxExecutionsPerDay: Int?
    public let requireExplicitConfirmation: Bool
    public let schemaVersion: Int
}

public struct PilotSummaryExport: Codable {
    public let hasTeamTier: Bool
    public let hasActiveTrial: Bool
    public let enterpriseReadinessScore: Int?
    public let availableSections: Int
    public let schemaVersion: Int
}
