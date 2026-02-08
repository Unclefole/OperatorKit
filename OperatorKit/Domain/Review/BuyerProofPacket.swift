import Foundation

// ============================================================================
// BUYER PROOF PACKET (Phase 11A)
//
// Single exportable artifact combining existing metadata-only sections.
// For procurement and buyer trust verification.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No networking
// ❌ No auto-export
// ✅ Metadata only
// ✅ User-initiated export
// ✅ Soft-fail for missing sections
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Claim Registry (Singleton for claim ID lookup)

public enum ClaimRegistry {
    public static let shared = ClaimRegistryAccessor()
}

public struct ClaimRegistryAccessor {
    /// All claim IDs from CLAIM_REGISTRY.md
    public let allClaimIds: [String] = [
        "CLAIM-001", "CLAIM-002", "CLAIM-003", "CLAIM-004",
        "CLAIM-005", "CLAIM-006", "CLAIM-007", "CLAIM-008",
        "CLAIM-009", "CLAIM-010", "CLAIM-011", "CLAIM-012"
    ]
}

// MARK: - Buyer Proof Packet

public struct BuyerProofPacket: Codable {
    
    // MARK: - Metadata
    
    public let schemaVersion: Int
    public let exportedAtDayRounded: String
    public let appVersion: String
    public let buildNumber: String
    public let releaseMode: String
    
    // MARK: - Proof Sections
    
    /// Safety contract status
    public let safetyContractStatus: SafetyContractStatusSummary?
    
    /// Claim registry summary (IDs only)
    public let claimRegistrySummary: ClaimRegistryBuyerSummary?
    
    /// Quality gate summary
    public let qualityGateSummary: QualityGateBuyerSummary?
    
    /// Diagnostics summary
    public let diagnosticsSummary: DiagnosticsBuyerSummary?
    
    /// Policy summary
    public let policySummary: PolicyBuyerSummary?
    
    /// Team readiness summary
    public let teamReadinessSummary: TeamReadinessBuyerSummary?
    
    /// Launch checklist result (Phase 10Q)
    public let launchChecklistSummary: LaunchChecklistBuyerSummary?
    
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
        "OperatorKit_BuyerProof_\(exportedAtDayRounded).json"
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
        "userId", "deviceId", "name", "address", "phone"
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
    
    public static func fromJSONData(_ data: Data) throws -> BuyerProofPacket {
        let decoder = JSONDecoder()
        return try decoder.decode(BuyerProofPacket.self, from: data)
    }
}

// MARK: - Buyer Summary Types

public struct SafetyContractStatusSummary: Codable {
    public let hashMatch: Bool
    public let isValid: Bool
    public let schemaVersion: Int
}

public struct ClaimRegistryBuyerSummary: Codable {
    public let totalClaims: Int
    public let claimIds: [String]
    public let schemaVersion: Int
}

public struct QualityGateBuyerSummary: Codable {
    public let status: String
    public let coverageScore: Int?
    public let invariantsPassing: Bool
    public let lastEvalDayRounded: String?
    public let schemaVersion: Int
}

public struct DiagnosticsBuyerSummary: Codable {
    public let totalExecutions: Int
    public let successCount: Int
    public let failureCount: Int
    public let successRate: Double?
    public let schemaVersion: Int
}

public struct PolicyBuyerSummary: Codable {
    public let policyEnabled: Bool
    public let capabilitiesEnabled: Int
    public let capabilitiesDisabled: Int
    public let requiresConfirmation: Bool
    public let schemaVersion: Int
}

public struct TeamReadinessBuyerSummary: Codable {
    public let hasTeamTier: Bool
    public let hasActiveTrial: Bool
    public let trialDaysRemaining: Int?
    public let schemaVersion: Int
}

public struct LaunchChecklistBuyerSummary: Codable {
    public let overallStatus: String
    public let passCount: Int
    public let warnCount: Int
    public let failCount: Int
    public let isLaunchReady: Bool
    public let schemaVersion: Int
}
