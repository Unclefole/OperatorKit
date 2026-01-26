import Foundation

// ============================================================================
// POLICY EXPORT PACKET (Phase 10C)
//
// Exportable policy snapshot for operator review.
// User-initiated export only, JSON format.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ NO content fields
// ❌ NO automatic export
// ✅ User-initiated only
// ✅ JSON format
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

// MARK: - Policy Export Packet

/// Exportable snapshot of current policy
public struct PolicyExportPacket: Codable, Equatable {
    
    /// When this packet was exported
    public let exportedAt: Date
    
    /// App version
    public let appVersion: String
    
    /// Build number
    public let buildNumber: String
    
    /// Current policy snapshot
    public let policy: OperatorPolicy
    
    /// Policy summary (plain language)
    public let policySummary: String
    
    /// Schema version for migration
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Initialization
    
    public init(
        exportedAt: Date = Date(),
        appVersion: String,
        buildNumber: String,
        policy: OperatorPolicy,
        policySummary: String
    ) {
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.policy = policy
        self.policySummary = policySummary
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    // MARK: - JSON Export
    
    /// Exports the packet as JSON data
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    
    /// Exports the packet as a JSON string
    public func exportJSONString() throws -> String {
        let data = try exportJSON()
        guard let string = String(data: data, encoding: .utf8) else {
            throw PolicyExportError.encodingFailed
        }
        return string
    }
    
    /// Exports to a temporary file and returns the URL
    public func exportToFile() throws -> URL {
        let data = try exportJSON()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: exportedAt)
        let filename = "OperatorKit_Policy_\(timestamp).json"
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        try data.write(to: fileURL)
        return fileURL
    }
}

// MARK: - Export Error

public enum PolicyExportError: Error, LocalizedError {
    case encodingFailed
    case fileWriteFailed
    
    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Could not encode policy."
        case .fileWriteFailed:
            return "Could not write policy file."
        }
    }
}

// MARK: - Policy Export Builder

/// Builds a policy export packet
public final class PolicyExportBuilder {
    
    // MARK: - Dependencies
    
    private let policyStore: OperatorPolicyStore
    
    // MARK: - Initialization
    
    public init(policyStore: OperatorPolicyStore = .shared) {
        self.policyStore = policyStore
    }
    
    // MARK: - Build Packet
    
    /// Builds a policy export packet
    /// INVARIANT: Read-only, does not modify state
    @MainActor
    public func buildPacket() -> PolicyExportPacket {
        let policy = policyStore.currentPolicy
        
        // Get app info
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        return PolicyExportPacket(
            appVersion: appVersion,
            buildNumber: buildNumber,
            policy: policy,
            policySummary: policy.summary
        )
    }
}
