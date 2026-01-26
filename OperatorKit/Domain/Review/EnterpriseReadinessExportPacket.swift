import Foundation

// ============================================================================
// ENTERPRISE READINESS EXPORT PACKET (Phase 10M)
//
// Wrapper for exporting EnterpriseReadinessPacket with validation.
// Includes forbidden-key scan before export.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No networking
// ✅ Forbidden-key validated
// ✅ User-initiated export only
// ✅ Round-trip JSON support
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

public struct EnterpriseReadinessExportPacket {
    
    // MARK: - Properties
    
    public let packet: EnterpriseReadinessPacket
    
    // MARK: - Initialization
    
    public init(packet: EnterpriseReadinessPacket) {
        self.packet = packet
    }
    
    @MainActor
    public init() {
        self.packet = EnterpriseReadinessBuilder.shared.build()
    }
    
    // MARK: - Export
    
    /// Exports to JSON data after validation
    public func toJSONData() throws -> Data {
        // First validate
        let violations = try validateNoForbiddenKeys()
        if !violations.isEmpty {
            throw EnterpriseExportError.forbiddenKeysFound(violations)
        }
        
        return try packet.exportJSON()
    }
    
    /// Export filename
    public var filename: String {
        packet.exportFilename
    }
    
    // MARK: - Validation
    
    /// Forbidden keys that must never appear in exports
    public static let forbiddenKeys: [String] = [
        "body",
        "subject",
        "content",
        "draft",
        "prompt",
        "context",
        "note",
        "email",
        "attendees",
        "title",
        "description",
        "message",
        "text",
        "recipient",
        "sender",
        "userId",
        "deviceId",
        "receipt"
    ]
    
    /// Validates packet contains no forbidden keys
    public func validateNoForbiddenKeys() throws -> [String] {
        let jsonData = try packet.exportJSON()
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }
        
        return Self.findForbiddenKeys(in: json, path: "")
    }
    
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
    
    /// Decodes from JSON data
    public static func fromJSONData(_ data: Data) throws -> EnterpriseReadinessExportPacket {
        let decoder = JSONDecoder()
        let packet = try decoder.decode(EnterpriseReadinessPacket.self, from: data)
        return EnterpriseReadinessExportPacket(packet: packet)
    }
}

// MARK: - Export Error

public enum EnterpriseExportError: Error, LocalizedError {
    case forbiddenKeysFound([String])
    case encodingFailed
    case decodingFailed
    
    public var errorDescription: String? {
        switch self {
        case .forbiddenKeysFound(let keys):
            return "Export contains forbidden keys: \(keys.joined(separator: ", "))"
        case .encodingFailed:
            return "Failed to encode export packet"
        case .decodingFailed:
            return "Failed to decode export packet"
        }
    }
}
