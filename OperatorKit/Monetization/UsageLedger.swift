import Foundation

// ============================================================================
// USAGE LEDGER (Phase 10A)
//
// Local-only ledger storing usage counters. NO content stored.
// Uses rolling 7-day window for executions.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content in ledger
// ❌ No execution behavior changes
// ✅ Counters and dates only
// ✅ Enforcement at UI boundary only
// ✅ Derive memory count from MemoryStore when possible
//
// Window Strategy: Rolling 7-day window
// - windowStart = first execution timestamp
// - Resets when (now - windowStart) >= 7 days
// - This is simpler than calendar-based Monday reset
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

/// Local-only usage ledger
public final class UsageLedger: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = UsageLedger()
    
    // MARK: - Storage Keys
    
    private enum StorageKey {
        static let ledgerData = "com.operatorkit.usageLedger"
    }
    
    // MARK: - Published State
    
    @Published public private(set) var data: LedgerData
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.data = Self.load(from: defaults)
    }
    
    // MARK: - Execution Limit Check
    
    /// Check if execution is allowed for the given tier
    /// - Parameter tier: The subscription tier
    /// - Returns: Decision on whether execution is allowed
    public func canExecute(tier: SubscriptionTier) -> LimitDecision {
        // Pro tier = unlimited
        if tier == .pro {
            return .unlimited(limitType: .executionsWeekly)
        }
        
        // Reset window if needed
        resetWindowIfNeeded()
        
        // Check quota
        if data.executionsThisWindow >= UsageQuota.freeExecutionsPerWeek {
            let resetsAt = data.windowStart.addingTimeInterval(UsageQuota.weeklyWindowDuration)
            return .executionLimitReached(resetsAt: resetsAt)
        }
        
        let remaining = UsageQuota.freeExecutionsPerWeek - data.executionsThisWindow
        return .allow(limitType: .executionsWeekly, remaining: remaining)
    }
    
    /// Record an execution (call after successful execution)
    public func recordExecution() {
        // Start window if first execution
        if data.windowStart == .distantPast {
            data.windowStart = Date()
        }
        
        data.executionsThisWindow += 1
        save()
        
        logDebug("Recorded execution: \(data.executionsThisWindow)/\(UsageQuota.freeExecutionsPerWeek) this window", category: .monetization)
    }
    
    // MARK: - Memory Limit Check
    
    /// Check if saving a memory item is allowed
    /// - Parameters:
    ///   - tier: The subscription tier
    ///   - currentCount: Current number of memory items
    /// - Returns: Decision on whether save is allowed
    public func canSaveMemoryItem(tier: SubscriptionTier, currentCount: Int) -> LimitDecision {
        // Pro tier = unlimited
        if tier == .pro {
            return .unlimited(limitType: .memoryItems)
        }
        
        // Check quota
        if currentCount >= UsageQuota.freeMemoryItemsMax {
            return .memoryLimitReached(currentCount: currentCount)
        }
        
        let remaining = UsageQuota.freeMemoryItemsMax - currentCount
        return .allow(limitType: .memoryItems, remaining: remaining)
    }
    
    // MARK: - Window Management
    
    /// Reset the weekly window if it has expired
    public func resetWindowIfNeeded() {
        let now = Date()
        let windowEnd = data.windowStart.addingTimeInterval(UsageQuota.weeklyWindowDuration)
        
        if now >= windowEnd {
            data.windowStart = now
            data.executionsThisWindow = 0
            save()
            
            logDebug("Weekly window reset", category: .monetization)
        }
    }
    
    /// Force reset (for testing only)
    #if DEBUG
    public func forceReset() {
        data = LedgerData()
        save()
    }
    #endif
    
    // MARK: - Persistence
    
    private static func load(from defaults: UserDefaults) -> LedgerData {
        guard let jsonData = defaults.data(forKey: StorageKey.ledgerData) else {
            return LedgerData()
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let ledger = try decoder.decode(LedgerData.self, from: jsonData)
            
            // Check schema version
            if ledger.schemaVersion < LedgerData.currentSchemaVersion {
                // Migration would go here
                logDebug("Ledger schema migration needed: \(ledger.schemaVersion) → \(LedgerData.currentSchemaVersion)", category: .monetization)
            }
            
            return ledger
        } catch {
            logError("Failed to load usage ledger: \(error.localizedDescription)", category: .monetization)
            return LedgerData()
        }
    }
    
    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(data)
            defaults.set(jsonData, forKey: StorageKey.ledgerData)
        } catch {
            logError("Failed to save usage ledger: \(error.localizedDescription)", category: .monetization)
        }
    }
    
    // MARK: - Display Helpers
    
    /// Remaining executions this week (for Free tier display)
    public var remainingExecutions: Int {
        max(0, UsageQuota.freeExecutionsPerWeek - data.executionsThisWindow)
    }
    
    /// When the current window resets
    public var windowResetDate: Date {
        data.windowStart.addingTimeInterval(UsageQuota.weeklyWindowDuration)
    }
}

// MARK: - Ledger Data

/// Serializable ledger data
/// CONTENT-FREE: Only counters and dates, no user content
public struct LedgerData: Codable, Equatable {
    
    /// Start of the current weekly window
    public var windowStart: Date
    
    /// Number of executions in the current window
    public var executionsThisWindow: Int
    
    /// Schema version for migration
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public init(
        windowStart: Date = .distantPast,
        executionsThisWindow: Int = 0
    ) {
        self.windowStart = windowStart
        self.executionsThisWindow = executionsThisWindow
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    // MARK: - Codable Keys
    
    /// Explicit coding keys — MUST NOT contain content-related keys
    enum CodingKeys: String, CodingKey {
        case windowStart
        case executionsThisWindow
        case schemaVersion
    }
}
