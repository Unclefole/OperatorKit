import Foundation

// ============================================================================
// COST VISIBILITY (Phase 10F)
//
// Local cost approximation for user transparency.
// Shows usage intensity without exposing actual costs.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No actual pricing information
// ❌ No server-side cost tracking
// ❌ No analytics
// ❌ No content inspection
// ✅ Local-only estimation
// ✅ Unit-based (not currency-based)
// ✅ Informational only
//
// See: docs/SAFETY_CONTRACT.md (Section 15)
// ============================================================================

// MARK: - Usage Units

/// Abstract usage unit (not currency)
public struct UsageUnits {
    
    /// Raw unit count
    public let units: Double
    
    /// Create from execution count
    public static func fromExecutions(_ count: Int) -> UsageUnits {
        UsageUnits(units: Double(count) * 1.0)
    }
    
    /// Create from model inference count
    public static func fromInferences(_ count: Int, complexity: InferenceComplexity) -> UsageUnits {
        UsageUnits(units: Double(count) * complexity.unitMultiplier)
    }
    
    /// Formatted display
    public var displayString: String {
        if units < 10 {
            return String(format: "%.1f units", units)
        } else {
            return "\(Int(units)) units"
        }
    }
    
    /// Approximate level
    public var level: UsageLevel {
        if units < 10 {
            return .minimal
        } else if units < 50 {
            return .moderate
        } else if units < 100 {
            return .significant
        } else {
            return .heavy
        }
    }
}

// MARK: - Inference Complexity

/// Complexity level for cost approximation
public enum InferenceComplexity {
    case trivial    // Simple lookup, cached
    case simple     // Basic inference
    case moderate   // Standard generation
    case complex    // Long-form generation
    
    var unitMultiplier: Double {
        switch self {
        case .trivial: return 0.1
        case .simple: return 0.5
        case .moderate: return 1.0
        case .complex: return 2.0
        }
    }
    
    var displayName: String {
        switch self {
        case .trivial: return "Trivial"
        case .simple: return "Simple"
        case .moderate: return "Moderate"
        case .complex: return "Complex"
        }
    }
}

// MARK: - Usage Level

/// Overall usage level (informational)
public enum UsageLevel: String, Codable, CaseIterable {
    case minimal = "minimal"
    case moderate = "moderate"
    case significant = "significant"
    case heavy = "heavy"
    
    public var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .moderate: return "Moderate"
        case .significant: return "Significant"
        case .heavy: return "Heavy"
        }
    }
    
    public var icon: String {
        switch self {
        case .minimal: return "leaf"
        case .moderate: return "chart.bar"
        case .significant: return "chart.bar.fill"
        case .heavy: return "flame"
        }
    }
    
    public var color: String {
        switch self {
        case .minimal: return "green"
        case .moderate: return "blue"
        case .significant: return "orange"
        case .heavy: return "red"
        }
    }
}

// MARK: - Cost Indicator

/// User-facing cost indicator (no actual prices)
@MainActor
public final class CostIndicator: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = CostIndicator()
    
    // MARK: - Published State
    
    @Published public private(set) var currentLevel: UsageLevel = .minimal
    @Published public private(set) var unitsToday: UsageUnits = UsageUnits(units: 0)
    @Published public private(set) var unitsThisWeek: UsageUnits = UsageUnits(units: 0)
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let todayKey = "com.operatorkit.cost.today"
    private let weekKey = "com.operatorkit.cost.week"
    private let lastResetKey = "com.operatorkit.cost.lastReset"
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadUsage()
        checkReset()
    }
    
    // MARK: - Recording
    
    /// Records usage from an execution
    public func recordExecution(complexity: InferenceComplexity = .moderate) {
        checkReset()
        
        let units = complexity.unitMultiplier
        
        let newToday = unitsToday.units + units
        let newWeek = unitsThisWeek.units + units
        
        unitsToday = UsageUnits(units: newToday)
        unitsThisWeek = UsageUnits(units: newWeek)
        
        updateLevel()
        saveUsage()
    }
    
    /// Gets current usage summary
    public var summary: UsageSummary {
        UsageSummary(
            levelToday: unitsToday.level,
            levelThisWeek: unitsThisWeek.level,
            unitsToday: unitsToday,
            unitsThisWeek: unitsThisWeek
        )
    }
    
    // MARK: - Level Calculation
    
    private func updateLevel() {
        // Base on today's usage
        currentLevel = unitsToday.level
    }
    
    // MARK: - Persistence
    
    private func loadUsage() {
        let todayUnits = defaults.double(forKey: todayKey)
        let weekUnits = defaults.double(forKey: weekKey)
        
        unitsToday = UsageUnits(units: todayUnits)
        unitsThisWeek = UsageUnits(units: weekUnits)
        updateLevel()
    }
    
    private func saveUsage() {
        defaults.set(unitsToday.units, forKey: todayKey)
        defaults.set(unitsThisWeek.units, forKey: weekKey)
        defaults.set(Date().timeIntervalSince1970, forKey: lastResetKey)
    }
    
    private func checkReset() {
        let lastReset = defaults.double(forKey: lastResetKey)
        let lastResetDate = Date(timeIntervalSince1970: lastReset)
        let now = Date()
        
        // Reset daily
        if !Calendar.current.isDate(lastResetDate, inSameDayAs: now) {
            unitsToday = UsageUnits(units: 0)
        }
        
        // Reset weekly
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        if lastResetDate < weekAgo {
            unitsThisWeek = UsageUnits(units: 0)
        }
    }
    
    /// Resets all usage (for testing)
    public func reset() {
        unitsToday = UsageUnits(units: 0)
        unitsThisWeek = UsageUnits(units: 0)
        currentLevel = .minimal
        defaults.removeObject(forKey: todayKey)
        defaults.removeObject(forKey: weekKey)
        defaults.removeObject(forKey: lastResetKey)
    }
}

// MARK: - Usage Summary

/// Summary of usage for display
public struct UsageSummary {
    public let levelToday: UsageLevel
    public let levelThisWeek: UsageLevel
    public let unitsToday: UsageUnits
    public let unitsThisWeek: UsageUnits
    
    public var todayDescription: String {
        "\(unitsToday.displayString) today (\(levelToday.displayName))"
    }
    
    public var weekDescription: String {
        "\(unitsThisWeek.displayString) this week (\(levelThisWeek.displayName))"
    }
}

// MARK: - Team Usage Summary (Metadata Only)

/// Aggregate team usage (no user content)
public struct TeamUsageSummary: Codable {
    
    /// Capture timestamp
    public let capturedAt: Date
    
    /// Number of team members
    public let memberCount: Int
    
    /// Aggregate usage level
    public let aggregateLevel: UsageLevel
    
    /// Total units this week (team aggregate)
    public let totalUnitsThisWeek: Double
    
    /// Average units per member
    public var averagePerMember: Double {
        guard memberCount > 0 else { return 0 }
        return totalUnitsThisWeek / Double(memberCount)
    }
    
    /// Schema version
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public init(
        memberCount: Int,
        totalUnitsThisWeek: Double,
        aggregateLevel: UsageLevel
    ) {
        self.capturedAt = Date()
        self.memberCount = memberCount
        self.totalUnitsThisWeek = totalUnitsThisWeek
        self.aggregateLevel = aggregateLevel
        self.schemaVersion = Self.currentSchemaVersion
    }
}
