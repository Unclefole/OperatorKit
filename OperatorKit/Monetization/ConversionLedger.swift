import Foundation

// ============================================================================
// CONVERSION LEDGER (Phase 10H)
//
// Local-only conversion event tracking. NO analytics, NO identifiers.
// Counts and timestamps only, exportable via user-initiated action.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No analytics SDKs
// ❌ No user identifiers
// ❌ No network transmission (except user-initiated export)
// ❌ No receipt data storage
// ❌ No user content
// ✅ Local counters only
// ✅ User-initiated export only
// ✅ Metadata-only
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

// MARK: - Conversion Event

/// Conversion events tracked locally
public enum ConversionEvent: String, Codable, CaseIterable {
    case paywallShown = "paywall_shown"
    case upgradeTapped = "upgrade_tapped"
    case purchaseStarted = "purchase_started"
    case purchaseSuccess = "purchase_success"
    case purchaseCancelled = "purchase_cancelled"
    case purchaseFailed = "purchase_failed"
    case restoreTapped = "restore_tapped"
    case restoreSuccess = "restore_success"
    case restoreFailed = "restore_failed"
    
    public var displayName: String {
        switch self {
        case .paywallShown: return "Paywall Shown"
        case .upgradeTapped: return "Upgrade Tapped"
        case .purchaseStarted: return "Purchase Started"
        case .purchaseSuccess: return "Purchase Success"
        case .purchaseCancelled: return "Purchase Cancelled"
        case .purchaseFailed: return "Purchase Failed"
        case .restoreTapped: return "Restore Tapped"
        case .restoreSuccess: return "Restore Success"
        case .restoreFailed: return "Restore Failed"
        }
    }
}

// MARK: - Conversion Ledger

/// Local-only conversion tracking (NO analytics)
@MainActor
public final class ConversionLedger: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = ConversionLedger()
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let storageKey = "com.operatorkit.conversion.ledger"
    
    // MARK: - State
    
    @Published public private(set) var data: ConversionData
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.data = ConversionData()
        loadData()
    }
    
    // MARK: - Recording
    
    /// Records a conversion event
    /// IMPORTANT: Local-only, no network transmission
    public func recordEvent(_ event: ConversionEvent) {
        data.incrementCount(for: event)
        data.lastEventAt = Date()
        saveData()
        
        logDebug("Conversion event recorded: \(event.rawValue)", category: .monetization)
    }
    
    /// Gets count for a specific event
    public func count(for event: ConversionEvent) -> Int {
        data.counts[event.rawValue] ?? 0
    }
    
    /// Gets summary of all events
    public var summary: ConversionSummary {
        ConversionSummary(
            paywallShownCount: count(for: .paywallShown),
            upgradeTapCount: count(for: .upgradeTapped),
            purchaseStartedCount: count(for: .purchaseStarted),
            purchaseSuccessCount: count(for: .purchaseSuccess),
            restoreTapCount: count(for: .restoreTapped),
            restoreSuccessCount: count(for: .restoreSuccess),
            lastEventAt: data.lastEventAt,
            capturedAt: Date()
        )
    }
    
    /// Resets all counters (for testing)
    public func reset() {
        data = ConversionData()
        saveData()
    }
    
    // MARK: - Persistence
    
    private func loadData() {
        guard let stored = defaults.data(forKey: storageKey) else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let loaded = try? decoder.decode(ConversionData.self, from: stored) {
            data = loaded
        }
    }
    
    private func saveData() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let encoded = try? encoder.encode(data) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
}

// MARK: - Conversion Data

/// Local-only conversion data structure
public struct ConversionData: Codable {
    
    /// Event counts (keyed by event rawValue)
    public var counts: [String: Int]
    
    /// Last event timestamp
    public var lastEventAt: Date?
    
    /// First event timestamp
    public var firstEventAt: Date?
    
    /// Schema version
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public init() {
        self.counts = [:]
        self.lastEventAt = nil
        self.firstEventAt = nil
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    /// Increments count for an event
    mutating func incrementCount(for event: ConversionEvent) {
        let key = event.rawValue
        counts[key] = (counts[key] ?? 0) + 1
        
        if firstEventAt == nil {
            firstEventAt = Date()
        }
    }
}

// MARK: - Conversion Summary

/// Summary for display and export (NO user content)
public struct ConversionSummary: Codable {
    public let paywallShownCount: Int
    public let upgradeTapCount: Int
    public let purchaseStartedCount: Int
    public let purchaseSuccessCount: Int
    public let restoreTapCount: Int
    public let restoreSuccessCount: Int
    public let lastEventAt: Date?
    public let capturedAt: Date
    
    /// Conversion rate (purchases / paywall shows)
    public var conversionRate: Double? {
        guard paywallShownCount > 0 else { return nil }
        return Double(purchaseSuccessCount) / Double(paywallShownCount)
    }
    
    /// Formatted conversion rate
    public var formattedConversionRate: String {
        guard let rate = conversionRate else { return "N/A" }
        return String(format: "%.1f%%", rate * 100)
    }
    
    /// Total events
    public var totalEvents: Int {
        paywallShownCount + upgradeTapCount + purchaseStartedCount +
        purchaseSuccessCount + restoreTapCount + restoreSuccessCount
    }
}

// MARK: - Ledger Conversion Export

/// Export packet for conversion data from ledger (user-initiated only)
public struct LedgerConversionExport: Codable {
    
    /// When exported
    public let exportedAt: Date
    
    /// App version
    public let appVersion: String
    
    /// Build number
    public let buildNumber: String
    
    /// Conversion summary
    public let summary: ConversionSummary
    
    /// Schema version
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public init(summary: ConversionSummary) {
        self.exportedAt = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        self.summary = summary
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    /// Exports to JSON data
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
