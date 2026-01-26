import Foundation

// ============================================================================
// OUTCOME LEDGER (Phase 10O)
//
// Local-only outcome tracking. Aggregates only, no user content.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No user identifiers
// ❌ No networking
// ❌ No fine timestamps
// ✅ Counts per template ID
// ✅ Day-rounded buckets (optional)
// ✅ Local UserDefaults only
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Outcome Event

public enum OutcomeEvent: String, Codable, CaseIterable {
    case shown = "shown"       // Template list viewed
    case used = "used"         // User tapped "Use Template"
    case completed = "completed" // Execution approved and completed
    
    public var displayName: String {
        switch self {
        case .shown: return "Shown"
        case .used: return "Used"
        case .completed: return "Completed"
        }
    }
}

// MARK: - Outcome Counts

public struct OutcomeCounts: Codable, Equatable {
    public var shown: Int
    public var used: Int
    public var completed: Int
    
    public init(shown: Int = 0, used: Int = 0, completed: Int = 0) {
        self.shown = shown
        self.used = used
        self.completed = completed
    }
    
    public static let zero = OutcomeCounts()
}

// MARK: - Outcome Ledger Data

public struct OutcomeLedgerData: Codable, Equatable {
    /// Global counts (all templates)
    public var globalCounts: OutcomeCounts
    
    /// Per-template counts
    public var templateCounts: [String: OutcomeCounts]
    
    /// Schema version
    public var schemaVersion: Int
    
    /// Last updated (day-rounded)
    public var lastUpdated: String
    
    public static let currentSchemaVersion = 1
    
    public init() {
        self.globalCounts = OutcomeCounts()
        self.templateCounts = [:]
        self.schemaVersion = Self.currentSchemaVersion
        self.lastUpdated = Self.dayRoundedNow()
    }
    
    private static func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
    
    mutating func updateLastUpdated() {
        lastUpdated = Self.dayRoundedNow()
    }
}

// MARK: - Outcome Ledger

@MainActor
public final class OutcomeLedger: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = OutcomeLedger()
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let storageKey = "com.operatorkit.outcome.ledger"
    
    // MARK: - State
    
    @Published public private(set) var data: OutcomeLedgerData
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.data = OutcomeLedgerData()
        loadData()
    }
    
    // MARK: - Recording
    
    /// Records that template list was shown
    public func recordShown() {
        data.globalCounts.shown += 1
        data.updateLastUpdated()
        saveData()
        
        logDebug("Outcome templates shown", category: .monetization)
    }
    
    /// Records that a template was used
    public func recordUsed(templateId: String) {
        data.globalCounts.used += 1
        
        var counts = data.templateCounts[templateId] ?? OutcomeCounts()
        counts.used += 1
        data.templateCounts[templateId] = counts
        
        data.updateLastUpdated()
        saveData()
        
        logDebug("Outcome template used: \(templateId)", category: .monetization)
    }
    
    /// Records that an outcome was completed
    /// NOTE: Call only when execution approval succeeds
    public func recordCompleted(templateId: String) {
        data.globalCounts.completed += 1
        
        var counts = data.templateCounts[templateId] ?? OutcomeCounts()
        counts.completed += 1
        data.templateCounts[templateId] = counts
        
        data.updateLastUpdated()
        saveData()
        
        logDebug("Outcome completed: \(templateId)", category: .monetization)
    }
    
    // MARK: - Summary
    
    /// Gets current summary for export
    public func currentSummary() -> OutcomeSummary {
        OutcomeSummary(
            globalCounts: data.globalCounts,
            templateCountsCount: data.templateCounts.count,
            topTemplatesByUsage: topTemplates(by: \.used, limit: 5),
            topTemplatesByCompletion: topTemplates(by: \.completed, limit: 5),
            usageRate: usageRate,
            completionRate: completionRate,
            schemaVersion: OutcomeLedgerData.currentSchemaVersion,
            capturedAt: data.lastUpdated
        )
    }
    
    /// Usage rate (used / shown)
    public var usageRate: Double? {
        guard data.globalCounts.shown > 0 else { return nil }
        return Double(data.globalCounts.used) / Double(data.globalCounts.shown)
    }
    
    /// Completion rate (completed / used)
    public var completionRate: Double? {
        guard data.globalCounts.used > 0 else { return nil }
        return Double(data.globalCounts.completed) / Double(data.globalCounts.used)
    }
    
    // MARK: - Reset
    
    /// Resets all data (for testing)
    public func reset() {
        data = OutcomeLedgerData()
        defaults.removeObject(forKey: storageKey)
    }
    
    // MARK: - Private
    
    private func loadData() {
        guard let savedData = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(OutcomeLedgerData.self, from: savedData) else {
            return
        }
        data = decoded
    }
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
    
    private func topTemplates(by keyPath: KeyPath<OutcomeCounts, Int>, limit: Int) -> [String] {
        data.templateCounts
            .sorted { $0.value[keyPath: keyPath] > $1.value[keyPath: keyPath] }
            .prefix(limit)
            .map { $0.key }
    }
}

// MARK: - Outcome Summary

public struct OutcomeSummary: Codable, Equatable {
    public let globalCounts: OutcomeCounts
    public let templateCountsCount: Int
    public let topTemplatesByUsage: [String]
    public let topTemplatesByCompletion: [String]
    public let usageRate: Double?
    public let completionRate: Double?
    public let schemaVersion: Int
    public let capturedAt: String
}

// MARK: - Activation Outcome Summary (for ConversionExportPacket)

public struct ActivationOutcomeSummary: Codable, Equatable {
    /// Total templates shown
    public let templatesShown: Int
    
    /// Total templates used
    public let templatesUsed: Int
    
    /// Total outcomes completed
    public let outcomesCompleted: Int
    
    /// Usage rate (used / shown)
    public let usageRate: Double?
    
    /// Completion rate (completed / used)
    public let completionRate: Double?
    
    /// Number of unique templates used
    public let uniqueTemplatesUsed: Int
    
    /// Schema version
    public let schemaVersion: Int
    
    @MainActor
    public init(from ledger: OutcomeLedger = .shared) {
        self.templatesShown = ledger.data.globalCounts.shown
        self.templatesUsed = ledger.data.globalCounts.used
        self.outcomesCompleted = ledger.data.globalCounts.completed
        self.usageRate = ledger.usageRate
        self.completionRate = ledger.completionRate
        self.uniqueTemplatesUsed = ledger.data.templateCounts.count
        self.schemaVersion = OutcomeLedgerData.currentSchemaVersion
    }
}
