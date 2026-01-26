import Foundation

// ============================================================================
// SALES KIT PACKET (Phase 11B)
//
// Single exportable artifact for sales outreach.
// Metadata only. Forbidden key scan.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No prospect info
// ✅ Metadata only
// ✅ Soft-fail
// ✅ Forbidden key scan
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Sales Kit Packet

public struct SalesKitPacket: Codable {
    
    // MARK: - Metadata
    
    public let schemaVersion: Int
    public let exportedAtDayRounded: String
    public let appVersion: String
    public let buildNumber: String
    
    // MARK: - Sections
    
    /// Pricing package registry snapshot
    public let pricingPackageSnapshot: PricingPackageRegistrySnapshot?
    
    /// Pricing consistency validator result
    public let pricingValidationResult: PricingValidationResult?
    
    /// Sales playbook metadata (IDs only)
    public let playbookMetadata: SalesPlaybookMetadata?
    
    /// Pipeline summary (counts only)
    public let pipelineSummary: PipelineSummary?
    
    /// Buyer proof packet status (hash + status only)
    public let buyerProofStatus: BuyerProofStatus?
    
    /// Enterprise readiness summary (status/score only)
    public let enterpriseReadinessSummary: EnterpriseReadinessSummary?
    
    // MARK: - Availability
    
    public let availableSections: [String]
    public let unavailableSections: [String]
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Export
    
    public func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    
    public var filename: String {
        "OperatorKit_SalesKit_\(exportedAtDayRounded).json"
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
        "userId", "deviceId", "name", "address", "company",
        "domain", "phone"
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
    
    public static func fromJSONData(_ data: Data) throws -> SalesKitPacket {
        let decoder = JSONDecoder()
        return try decoder.decode(SalesKitPacket.self, from: data)
    }
}

// MARK: - Buyer Proof Status (Summary Only)

public struct BuyerProofStatus: Codable {
    public let isAvailable: Bool
    public let availableSectionsCount: Int
    public let unavailableSectionsCount: Int
    public let schemaVersion: Int
}

// MARK: - Enterprise Readiness Summary

public struct EnterpriseReadinessSummary: Codable {
    public let overallStatus: String
    public let safetyContractValid: Bool
    public let qualityGatePassing: Bool
    public let launchChecklistReady: Bool
    public let schemaVersion: Int
}
