import Foundation

// ============================================================================
// FIRST WEEK STATE (Phase 10Q)
//
// Lightweight, UI-only helper for first-week guidance.
// Read-only. No analytics. No networking. No execution hooks.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No analytics
// ❌ No networking
// ❌ No execution hooks
// ❌ No blocking behavior
// ❌ No restrictions
// ✅ Read-only state
// ✅ Gentle guidance only
// ✅ UI surface only
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - First Week State

public struct FirstWeekState: Codable, Equatable {
    
    /// When the app was first installed
    public let installedAt: Date
    
    /// Schema version for migration
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    /// Default trial period for first week
    public static let firstWeekDays = 7
    
    // MARK: - Computed Properties
    
    /// Days since install (rounded down)
    public var daysSinceInstall: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: installedAt, to: Date())
        return max(0, components.day ?? 0)
    }
    
    /// Whether this is still the first week
    public var isFirstWeek: Bool {
        daysSinceInstall < Self.firstWeekDays
    }
    
    /// Progress through first week (0.0 to 1.0)
    public var firstWeekProgress: Double {
        min(1.0, Double(daysSinceInstall) / Double(Self.firstWeekDays))
    }
    
    /// Days remaining in first week
    public var daysRemainingInFirstWeek: Int {
        max(0, Self.firstWeekDays - daysSinceInstall)
    }
    
    // MARK: - Initialization
    
    public init(installedAt: Date = Date()) {
        self.installedAt = installedAt
        self.schemaVersion = Self.currentSchemaVersion
    }
}

// MARK: - First Week Store

@MainActor
public final class FirstWeekStore: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = FirstWeekStore()
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let storageKey = "com.operatorkit.first_week_state"
    
    // MARK: - State
    
    @Published public private(set) var state: FirstWeekState
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        
        // Load or create state
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(FirstWeekState.self, from: data) {
            self.state = decoded
        } else {
            // First launch - record install date
            let newState = FirstWeekState()
            self.state = newState
            saveState(newState)
        }
    }
    
    // MARK: - Public API
    
    /// Whether user is in first week
    public var isFirstWeek: Bool {
        state.isFirstWeek
    }
    
    /// Days since install
    public var daysSinceInstall: Int {
        state.daysSinceInstall
    }
    
    /// Days remaining in first week
    public var daysRemaining: Int {
        state.daysRemainingInFirstWeek
    }
    
    // MARK: - Reset (for testing only)
    
    public func reset() {
        let newState = FirstWeekState()
        self.state = newState
        saveState(newState)
    }
    
    // MARK: - Private
    
    private func saveState(_ state: FirstWeekState) {
        if let encoded = try? JSONEncoder().encode(state) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
}

// MARK: - First Week Tips

public enum FirstWeekTips {
    
    /// Static tips for first-week users (App Store safe)
    public static let tips: [String] = [
        "Review drafts carefully before approving",
        "You're always in control of what runs",
        "Nothing executes without your approval",
        "You can export proof of actions anytime",
        "All drafts are shown before execution"
    ]
    
    /// Short tips for inline display
    public static let shortTips: [String] = [
        "Review before approving",
        "You control execution",
        "Approval always required",
        "Export proof anytime"
    ]
    
    /// Validates tips contain no banned words
    public static func validateNoBannedWords() -> [String] {
        let bannedWords = [
            "automatic", "automatically", "learns", "thinks", "decides",
            "understands", "monitors", "tracks", "watches", "background",
            "secure", "encrypted", "safe", "protected", "AI agent"
        ]
        
        var violations: [String] = []
        
        for tip in tips + shortTips {
            let lowered = tip.lowercased()
            for word in bannedWords {
                if lowered.contains(word.lowercased()) {
                    violations.append("Tip '\(tip)' contains banned word: \(word)")
                }
            }
        }
        
        return violations
    }
}
