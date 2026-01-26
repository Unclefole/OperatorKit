import Foundation

// ============================================================================
// OFFLINE CERTIFICATION PACKET (Phase 13I)
//
// Metadata-only result bundle for certification export.
// Contains NO user content, NO identifiers, NO free text.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No identifiers
// ❌ No free text (except controlled enum values)
// ❌ No paths
// ✅ Metadata only
// ✅ Forbidden-key validated
// ✅ Export via ShareSheet only
// ============================================================================

// MARK: - Forbidden Keys

public enum OfflineCertificationForbiddenKeys {
    
    /// Keys that must NEVER appear in certification exports
    public static let all: Set<String> = [
        "body", "subject", "content", "draft", "prompt", "context",
        "message", "text", "recipient", "sender", "title", "description",
        "attendees", "email", "phone", "address", "name", "note", "notes",
        "userData", "personalData", "identifier", "deviceId", "userId",
        "path", "fullPath", "absolutePath", "homeDirectory", "userDirectory",
        "memory", "memoryText", "contextText", "calendar", "reminder"
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

// MARK: - Certification Packet

public struct OfflineCertificationPacket: Codable, Equatable {
    
    /// Schema version
    public let schemaVersion: Int
    
    /// App version
    public let appVersion: String
    
    /// Build number
    public let buildNumber: String
    
    /// Day-rounded creation date
    public let createdAtDayRounded: String
    
    /// Total rule count
    public let ruleCount: Int
    
    /// Passed count
    public let passedCount: Int
    
    /// Failed count
    public let failedCount: Int
    
    /// Overall status
    public let overallStatus: String
    
    /// Results by category (counts only)
    public let categoryResults: [CategoryResult]
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Init from Report
    
    public init(from report: OfflineCertificationReport) {
        self.schemaVersion = Self.currentSchemaVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        self.createdAtDayRounded = report.timestamp
        self.ruleCount = report.ruleCount
        self.passedCount = report.passedCount
        self.failedCount = report.failedCount
        self.overallStatus = report.status.rawValue
        
        // Aggregate by category
        var categoryMap: [String: (passed: Int, failed: Int)] = [:]
        for result in report.checkResults {
            let current = categoryMap[result.category] ?? (passed: 0, failed: 0)
            if result.passed {
                categoryMap[result.category] = (passed: current.passed + 1, failed: current.failed)
            } else {
                categoryMap[result.category] = (passed: current.passed, failed: current.failed + 1)
            }
        }
        
        self.categoryResults = categoryMap.map { CategoryResult(category: $0.key, passed: $0.value.passed, failed: $0.value.failed) }
            .sorted { $0.category < $1.category }
    }
    
    // MARK: - Validation
    
    public func validate() -> [String] {
        var errors: [String] = []
        
        if let jsonData = try? JSONEncoder().encode(self),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            errors.append(contentsOf: OfflineCertificationForbiddenKeys.validate(jsonString))
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

// MARK: - Category Result

public struct CategoryResult: Codable, Equatable {
    public let category: String
    public let passed: Int
    public let failed: Int
    
    public var total: Int { passed + failed }
    public var allPassed: Bool { failed == 0 }
}
