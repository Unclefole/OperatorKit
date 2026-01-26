import Foundation

// ============================================================================
// BINARY PROOF PACKET (Phase 13G)
//
// Metadata-only export packet for binary inspection results.
// Contains NO user content, NO forbidden keys, NO full paths.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No forbidden keys (body, subject, content, prompt, etc.)
// ❌ No user content
// ❌ No full filesystem paths
// ❌ No free-form text except controlled identifiers
// ✅ Sanitized framework identifiers only
// ✅ Deterministic serialization
// ============================================================================

// MARK: - Forbidden Keys

public enum BinaryProofForbiddenKeys {
    
    /// Keys that must NEVER appear in Binary Proof exports
    public static let all: Set<String> = [
        "body", "subject", "content", "draft", "prompt", "context",
        "message", "text", "recipient", "sender", "title", "description",
        "attendees", "email", "phone", "address", "name", "note", "notes",
        "userData", "personalData", "identifier", "deviceId", "userId",
        "path", "fullPath", "absolutePath", "homeDirectory", "userDirectory"
    ]
    
    /// Validate a JSON string contains no forbidden keys
    public static func validate(_ jsonString: String) -> [String] {
        var violations: [String] = []
        let lowercased = jsonString.lowercased()
        
        for key in all {
            if lowercased.contains("\"\(key)\"") {
                violations.append("Contains forbidden key: \(key)")
            }
        }
        
        return violations
    }
}

// MARK: - Binary Proof Packet

public struct BinaryProofPacket: Codable, Equatable {
    
    /// Schema version for forward compatibility
    public let schemaVersion: Int
    
    /// Day-rounded creation date
    public let createdAtDayRounded: String
    
    /// App version
    public let appVersion: String
    
    /// Build number
    public let buildNumber: String
    
    /// Overall inspection status
    public let overallStatus: BinaryProofStatus
    
    /// Sanitized framework identifiers (no full paths)
    public let linkedFrameworks: [String]
    
    /// Sensitive framework presence checks
    public let sensitiveFrameworkChecks: [SensitiveFrameworkCheck]
    
    /// Short factual notes (no banned words)
    public let proofNotes: [String]
    
    /// Framework count
    public let frameworkCount: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Init
    
    public init(from result: BinaryInspectionResult) {
        self.schemaVersion = Self.currentSchemaVersion
        self.createdAtDayRounded = Self.dayRoundedNow()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        self.overallStatus = result.status
        self.linkedFrameworks = result.linkedFrameworks
        self.sensitiveFrameworkChecks = result.sensitiveChecks
        self.proofNotes = result.notes
        self.frameworkCount = result.linkedFrameworks.count
    }
    
    // MARK: - Day Rounding
    
    private static func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
    
    // MARK: - Validation
    
    public func validate() -> [String] {
        var errors: [String] = []
        
        // Validate no forbidden keys in serialization
        if let jsonData = try? JSONEncoder().encode(self),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            errors.append(contentsOf: BinaryProofForbiddenKeys.validate(jsonString))
        }
        
        // Validate no full paths in framework list
        for framework in linkedFrameworks {
            if framework.contains("/") {
                errors.append("Framework contains path separator: \(framework)")
            }
            if framework.hasPrefix("/") {
                errors.append("Framework starts with path: \(framework)")
            }
        }
        
        return errors
    }
    
    // MARK: - Export
    
    public func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
}

// MARK: - Summary

extension BinaryProofPacket {
    
    /// Human-readable summary for display
    public var summary: String {
        var lines: [String] = []
        lines.append("Binary Proof: \(overallStatus.rawValue)")
        lines.append("Frameworks: \(frameworkCount)")
        lines.append("Sensitive Checks: \(sensitiveFrameworkChecks.filter { !$0.isPresent }.count)/\(sensitiveFrameworkChecks.count) passed")
        return lines.joined(separator: " | ")
    }
}
