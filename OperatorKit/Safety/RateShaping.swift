import Foundation

// ============================================================================
// RATE SHAPING (Phase 10F)
//
// UI-level rate shaping to prevent abuse and accidental overuse.
// Does NOT block execution — provides user feedback only.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ Does NOT modify ExecutionEngine
// ❌ Does NOT block ApprovalGate
// ❌ No background processing
// ❌ No analytics
// ❌ No content inspection
// ✅ UI boundary enforcement only
// ✅ Plain-language feedback
//
// See: docs/SAFETY_CONTRACT.md (Section 15)
// ============================================================================

// MARK: - Rate Shape Result

/// Result of rate shaping check
public struct RateShapeResult {
    
    /// Whether the action should proceed
    public let shouldProceed: Bool
    
    /// User-facing message (if rate shaped)
    public let message: String?
    
    /// Suggested wait time in seconds
    public let suggestedWaitSeconds: Int?
    
    /// Intensity level
    public let intensityLevel: UsageIntensity
    
    /// Creates a result allowing the action
    public static func allow(intensity: UsageIntensity = .normal) -> RateShapeResult {
        RateShapeResult(
            shouldProceed: true,
            message: nil,
            suggestedWaitSeconds: nil,
            intensityLevel: intensity
        )
    }
    
    /// Creates a result suggesting the user slow down
    public static func suggest(
        message: String,
        waitSeconds: Int,
        intensity: UsageIntensity
    ) -> RateShapeResult {
        RateShapeResult(
            shouldProceed: true,  // Still allow, but inform
            message: message,
            suggestedWaitSeconds: waitSeconds,
            intensityLevel: intensity
        )
    }
    
    /// Creates a result blocking at UI level
    public static func block(
        message: String,
        waitSeconds: Int,
        intensity: UsageIntensity = .heavy
    ) -> RateShapeResult {
        RateShapeResult(
            shouldProceed: false,
            message: message,
            suggestedWaitSeconds: waitSeconds,
            intensityLevel: intensity
        )
    }
}

// MARK: - Usage Intensity

/// Usage intensity level (informational only)
public enum UsageIntensity: String, Codable, CaseIterable {
    case low = "low"
    case normal = "normal"
    case elevated = "elevated"
    case heavy = "heavy"
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .elevated: return "Elevated"
        case .heavy: return "Heavy"
        }
    }
    
    public var color: String {
        switch self {
        case .low: return "green"
        case .normal: return "blue"
        case .elevated: return "orange"
        case .heavy: return "red"
        }
    }
    
    public var description: String {
        switch self {
        case .low: return "Light usage"
        case .normal: return "Typical usage"
        case .elevated: return "Above average usage"
        case .heavy: return "Heavy usage"
        }
    }
}

// MARK: - Rate Shaper

/// UI-level rate shaping (does NOT affect execution)
@MainActor
public final class RateShaper: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = RateShaper()
    
    // MARK: - Configuration
    
    /// Minimum seconds between executions (soft limit)
    private let minIntervalSeconds: TimeInterval = 5
    
    /// Cooldown after burst detection (seconds)
    private let burstCooldownSeconds: Int = 30
    
    /// Max executions in burst window
    private let burstThreshold: Int = 5
    
    /// Burst window duration (seconds)
    private let burstWindowSeconds: TimeInterval = 60
    
    /// Heavy usage threshold (executions per hour)
    private let heavyUsageThreshold: Int = 20
    
    /// Elevated usage threshold (executions per hour)
    private let elevatedUsageThreshold: Int = 10
    
    // MARK: - State
    
    @Published public private(set) var currentIntensity: UsageIntensity = .normal
    @Published public private(set) var lastRateShapeMessage: String?
    
    private var executionTimestamps: [Date] = []
    private let defaults: UserDefaults
    private let timestampsKey = "com.operatorkit.rateShaping.timestamps"
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadTimestamps()
        updateIntensity()
    }
    
    // MARK: - Rate Shaping Check
    
    /// Checks if an execution should be rate shaped
    /// IMPORTANT: This is UI-level only — does NOT affect actual execution
    public func checkExecution() -> RateShapeResult {
        let now = Date()
        
        // Clean old timestamps
        cleanOldTimestamps()
        
        // Check for burst
        if isBurstDetected() {
            let message = "You've been running actions quickly. Consider taking a short break."
            lastRateShapeMessage = message
            return .suggest(
                message: message,
                waitSeconds: burstCooldownSeconds,
                intensity: .heavy
            )
        }
        
        // Check for rapid-fire
        if let lastExecution = executionTimestamps.last {
            let interval = now.timeIntervalSince(lastExecution)
            if interval < minIntervalSeconds {
                let waitTime = Int(ceil(minIntervalSeconds - interval))
                let message = "Please wait a moment before the next action."
                lastRateShapeMessage = message
                return .suggest(
                    message: message,
                    waitSeconds: waitTime,
                    intensity: currentIntensity
                )
            }
        }
        
        // Update intensity
        updateIntensity()
        
        // Allow with current intensity
        lastRateShapeMessage = nil
        return .allow(intensity: currentIntensity)
    }
    
    /// Records that an execution occurred
    public func recordExecution() {
        executionTimestamps.append(Date())
        saveTimestamps()
        updateIntensity()
    }
    
    /// Resets rate shaping state (for testing)
    public func reset() {
        executionTimestamps = []
        currentIntensity = .normal
        lastRateShapeMessage = nil
        defaults.removeObject(forKey: timestampsKey)
    }
    
    // MARK: - Intensity Calculation
    
    /// Updates the current usage intensity
    private func updateIntensity() {
        let hourAgo = Date().addingTimeInterval(-3600)
        let recentCount = executionTimestamps.filter { $0 > hourAgo }.count
        
        if recentCount >= heavyUsageThreshold {
            currentIntensity = .heavy
        } else if recentCount >= elevatedUsageThreshold {
            currentIntensity = .elevated
        } else if recentCount > 0 {
            currentIntensity = .normal
        } else {
            currentIntensity = .low
        }
    }
    
    /// Detects burst usage pattern
    private func isBurstDetected() -> Bool {
        let burstWindowStart = Date().addingTimeInterval(-burstWindowSeconds)
        let recentCount = executionTimestamps.filter { $0 > burstWindowStart }.count
        return recentCount >= burstThreshold
    }
    
    // MARK: - Persistence
    
    private func loadTimestamps() {
        guard let data = defaults.data(forKey: timestampsKey) else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let timestamps = try? decoder.decode([Date].self, from: data) {
            executionTimestamps = timestamps
        }
    }
    
    private func saveTimestamps() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(executionTimestamps) {
            defaults.set(data, forKey: timestampsKey)
        }
    }
    
    private func cleanOldTimestamps() {
        let dayAgo = Date().addingTimeInterval(-86400)
        executionTimestamps = executionTimestamps.filter { $0 > dayAgo }
        saveTimestamps()
    }
    
    // MARK: - Statistics
    
    /// Executions in the last hour
    public var executionsLastHour: Int {
        let hourAgo = Date().addingTimeInterval(-3600)
        return executionTimestamps.filter { $0 > hourAgo }.count
    }
    
    /// Executions today
    public var executionsToday: Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return executionTimestamps.filter { $0 >= startOfDay }.count
    }
    
    /// Time until next suggested execution (nil if no cooldown)
    public var cooldownRemaining: TimeInterval? {
        guard let lastExecution = executionTimestamps.last else { return nil }
        
        let elapsed = Date().timeIntervalSince(lastExecution)
        
        if isBurstDetected() {
            let cooldown = TimeInterval(burstCooldownSeconds)
            if elapsed < cooldown {
                return cooldown - elapsed
            }
        } else if elapsed < minIntervalSeconds {
            return minIntervalSeconds - elapsed
        }
        
        return nil
    }
}

// MARK: - Rate Shape Message Builder

/// Builds user-friendly rate shaping messages
public enum RateShapeMessages {
    
    /// Message for burst detection
    public static func burstDetected(waitSeconds: Int) -> String {
        "You've been running several actions quickly. Consider waiting about \(waitSeconds) seconds."
    }
    
    /// Message for rapid-fire
    public static func rapidFire(waitSeconds: Int) -> String {
        "Please wait \(waitSeconds) \(waitSeconds == 1 ? "second" : "seconds") before the next action."
    }
    
    /// Message for heavy usage
    public static func heavyUsage(executionsThisHour: Int) -> String {
        "You've run \(executionsThisHour) actions this hour. Usage is elevated."
    }
    
    /// Message for approaching limit
    public static func approachingLimit(remaining: Int, window: String) -> String {
        "You have \(remaining) executions remaining this \(window)."
    }
    
    /// Message for limit reached
    public static func limitReached(window: String) -> String {
        "You've reached your execution limit for this \(window)."
    }
}
