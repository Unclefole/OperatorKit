import Foundation

// ============================================================================
// ONBOARDING STATE STORE (Phase 10I)
//
// Tracks onboarding completion state. Local-only, no user content.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content storage
// ❌ No analytics
// ❌ No networking
// ✅ Local UserDefaults only
// ✅ Metadata-only (completion flag + version)
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

@MainActor
public final class OnboardingStateStore: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = OnboardingStateStore()
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let storageKey = "com.operatorkit.onboarding.state"
    
    // MARK: - Published State
    
    @Published public private(set) var state: OnboardingState
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.state = OnboardingState()
        loadState()
    }
    
    // MARK: - Public API
    
    /// Whether onboarding has been completed
    public var isCompleted: Bool {
        state.isCompleted
    }
    
    /// Whether to show onboarding on launch
    public var shouldShowOnboarding: Bool {
        !state.isCompleted || state.needsRerun
    }
    
    /// Marks onboarding as completed
    public func markCompleted() {
        state.isCompleted = true
        state.completedAt = Date()
        state.needsRerun = false
        saveState()
        
        logDebug("Onboarding completed", category: .lifecycle)
    }
    
    /// Marks onboarding for re-run (from Settings)
    public func markForRerun() {
        state.needsRerun = true
        saveState()
        
        logDebug("Onboarding marked for re-run", category: .lifecycle)
    }
    
    /// Resets onboarding state completely
    public func reset() {
        state = OnboardingState()
        saveState()
        
        logDebug("Onboarding state reset", category: .lifecycle)
    }
    
    // MARK: - Persistence
    
    private func loadState() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let loaded = try? decoder.decode(OnboardingState.self, from: data) {
            // Check if schema migration needed
            if loaded.schemaVersion < OnboardingState.currentSchemaVersion {
                state = migrateState(from: loaded)
            } else {
                state = loaded
            }
        }
    }
    
    private func saveState() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(state) {
            defaults.set(data, forKey: storageKey)
        }
    }
    
    private func migrateState(from old: OnboardingState) -> OnboardingState {
        var new = OnboardingState()
        new.isCompleted = old.isCompleted
        new.completedAt = old.completedAt
        // Migration logic would go here for future schema changes
        return new
    }
}

// MARK: - Onboarding State

/// Onboarding state structure (metadata only)
public struct OnboardingState: Codable {
    
    /// Whether onboarding has been completed
    public var isCompleted: Bool
    
    /// When onboarding was completed
    public var completedAt: Date?
    
    /// Whether user requested re-run from Settings
    public var needsRerun: Bool
    
    /// Schema version for migrations
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public init() {
        self.isCompleted = false
        self.completedAt = nil
        self.needsRerun = false
        self.schemaVersion = Self.currentSchemaVersion
    }
}
