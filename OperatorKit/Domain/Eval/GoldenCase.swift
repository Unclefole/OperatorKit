import Foundation

// ============================================================================
// GOLDEN CASE (Phase 8B)
//
// Local-only "golden cases" for quality evaluation.
// INVARIANT: No raw user content stored (only metadata)
// INVARIANT: User-initiated pinning only
// INVARIANT: User can delete at any time
// INVARIANT: No network transmission
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

// MARK: - Golden Case Source

/// Source of a golden case
public enum GoldenCaseSource: String, Codable {
    case memoryItem = "memory_item"
    
    public var displayName: String {
        switch self {
        case .memoryItem: return "Memory Item"
        }
    }
}

// MARK: - Golden Case

/// A pinned golden case for local evaluation
/// INVARIANT: Contains metadata only, never raw content
public struct GoldenCase: Identifiable, Codable {
    public let id: UUID
    public let createdAt: Date
    public var title: String  // User-editable, max 80 chars
    public let source: GoldenCaseSource
    public let memoryItemId: UUID
    public let snapshot: GoldenCaseSnapshot
    
    /// Maximum title length
    public static let maxTitleLength = 80
    
    /// Schema version for migration
    public static let schemaVersion = 1
    
    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String,
        source: GoldenCaseSource,
        memoryItemId: UUID,
        snapshot: GoldenCaseSnapshot
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = String(title.prefix(Self.maxTitleLength))
        self.source = source
        self.memoryItemId = memoryItemId
        self.snapshot = snapshot
    }
    
    /// Updates the title (enforces max length)
    public mutating func rename(_ newTitle: String) {
        self.title = String(newTitle.prefix(Self.maxTitleLength))
    }
}

// MARK: - Golden Case Snapshot

/// Content-safe snapshot of a memory item for evaluation
/// INVARIANT: Contains NO raw user content - metadata only
public struct GoldenCaseSnapshot: Codable {
    public let intentType: String
    public let outputType: String
    public let contextCounts: ContextCounts
    public let confidenceBand: String
    public let backendUsed: String
    public let usedFallback: Bool
    public let timeoutOccurred: Bool
    public let validationPass: Bool?
    public let citationValidityPass: Bool?
    public let citationsCount: Int
    public let latencyMs: Int?
    public let promptScaffoldHash: String?
    public let schemaVersion: Int
    
    public struct ContextCounts: Codable {
        public let calendar: Int
        public let reminders: Int
        public let mail: Int
        public let files: Int
        
        public var total: Int {
            calendar + reminders + mail + files
        }
        
        public var summary: String {
            var parts: [String] = []
            if calendar > 0 { parts.append("Calendar: \(calendar)") }
            if reminders > 0 { parts.append("Reminders: \(reminders)") }
            if mail > 0 { parts.append("Mail: \(mail)") }
            if files > 0 { parts.append("Files: \(files)") }
            return parts.isEmpty ? "No context" : parts.joined(separator: ", ")
        }
        
        public init(calendar: Int = 0, reminders: Int = 0, mail: Int = 0, files: Int = 0) {
            self.calendar = calendar
            self.reminders = reminders
            self.mail = mail
            self.files = files
        }
    }
    
    public init(
        intentType: String,
        outputType: String,
        contextCounts: ContextCounts,
        confidenceBand: String,
        backendUsed: String,
        usedFallback: Bool,
        timeoutOccurred: Bool,
        validationPass: Bool?,
        citationValidityPass: Bool?,
        citationsCount: Int,
        latencyMs: Int?,
        promptScaffoldHash: String?
    ) {
        self.intentType = intentType
        self.outputType = outputType
        self.contextCounts = contextCounts
        self.confidenceBand = confidenceBand
        self.backendUsed = backendUsed
        self.usedFallback = usedFallback
        self.timeoutOccurred = timeoutOccurred
        self.validationPass = validationPass
        self.citationValidityPass = citationValidityPass
        self.citationsCount = citationsCount
        self.latencyMs = latencyMs
        self.promptScaffoldHash = promptScaffoldHash
        self.schemaVersion = GoldenCase.schemaVersion
    }
}

// MARK: - Factory for Creating Snapshots

extension GoldenCaseSnapshot {
    
    /// Creates a snapshot from a PersistedMemoryItem
    /// INVARIANT: Extracts metadata only, never raw content
    static func from(memoryItem: PersistedMemoryItem) -> GoldenCaseSnapshot {
        // Determine confidence band
        let confidenceBand: String
        if let confidence = memoryItem.confidenceAtDraft {
            if confidence < 0.35 {
                confidenceBand = "low"
            } else if confidence < 0.65 {
                confidenceBand = "medium"
            } else {
                confidenceBand = "high"
            }
        } else {
            confidenceBand = "unknown"
        }
        
        // Parse context counts from summary (metadata only)
        let contextCounts = parseContextCounts(from: memoryItem.contextSummary)
        
        return GoldenCaseSnapshot(
            intentType: memoryItem.type.rawValue,
            outputType: memoryItem.type.rawValue,
            contextCounts: contextCounts,
            confidenceBand: confidenceBand,
            backendUsed: memoryItem.modelBackendUsed ?? "unknown",
            usedFallback: memoryItem.usedFallback,
            timeoutOccurred: memoryItem.timeoutOccurred,
            validationPass: memoryItem.validationPass,
            citationValidityPass: memoryItem.citationValidityPass,
            citationsCount: memoryItem.citationsCount ?? 0,
            latencyMs: memoryItem.generationLatencyMs,
            promptScaffoldHash: memoryItem.promptScaffoldHash
        )
    }
    
    /// Parses context counts from a summary string (no content extraction)
    private static func parseContextCounts(from summary: String?) -> ContextCounts {
        guard let summary = summary else {
            return ContextCounts()
        }
        
        // Parse counts from metadata summary like "Calendar: 2, Mail: 1"
        var calendar = 0
        var reminders = 0
        var mail = 0
        var files = 0
        
        let components = summary.components(separatedBy: ",")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().contains("calendar") {
                if let num = extractNumber(from: trimmed) {
                    calendar = num
                }
            } else if trimmed.lowercased().contains("reminder") {
                if let num = extractNumber(from: trimmed) {
                    reminders = num
                }
            } else if trimmed.lowercased().contains("mail") || trimmed.lowercased().contains("email") {
                if let num = extractNumber(from: trimmed) {
                    mail = num
                }
            } else if trimmed.lowercased().contains("file") {
                if let num = extractNumber(from: trimmed) {
                    files = num
                }
            }
        }
        
        return ContextCounts(calendar: calendar, reminders: reminders, mail: mail, files: files)
    }
    
    private static func extractNumber(from string: String) -> Int? {
        let digits = string.filter { $0.isNumber }
        return Int(digits)
    }
}

// MARK: - Export Format

/// Export-safe representation of golden cases
public struct GoldenCaseExport: Codable {
    public let schemaVersion: Int
    public let appVersion: String?
    public let exportedAt: Date
    public let totalCases: Int
    public let cases: [GoldenCaseExportEntry]
    
    public struct GoldenCaseExportEntry: Codable {
        public let id: String
        public let createdAt: Date
        public let title: String
        public let source: String
        public let snapshot: GoldenCaseSnapshot
    }
    
    public init(cases: [GoldenCase]) {
        self.schemaVersion = GoldenCase.schemaVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        self.exportedAt = Date()
        self.totalCases = cases.count
        self.cases = cases.map { goldenCase in
            GoldenCaseExportEntry(
                id: goldenCase.id.uuidString,
                createdAt: goldenCase.createdAt,
                title: goldenCase.title,
                source: goldenCase.source.rawValue,
                snapshot: goldenCase.snapshot
            )
        }
    }
    
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
