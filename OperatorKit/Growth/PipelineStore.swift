import Foundation

// ============================================================================
// PIPELINE STORE (Phase 11B)
//
// Local-only pipeline tracking.
// 90-day retention. Counts-only export.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No prospect identity
// ❌ No networking
// ✅ Local-only storage
// ✅ 90-day retention
// ✅ Counts-only export
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

@MainActor
public final class PipelineStore: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = PipelineStore()
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let storageKey = "com.operatorkit.pipeline.items"
    
    // MARK: - Configuration
    
    public static let maxRetentionDays = 90
    
    // MARK: - State
    
    @Published public private(set) var items: [PipelineItem] = []
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadItems()
        purgeOldItems()
    }
    
    // MARK: - Public API
    
    /// Adds a new pipeline item
    public func addItem(channel: PipelineChannel = .other) -> PipelineItem {
        let item = PipelineItem(channel: channel)
        items.append(item)
        saveItems()
        
        logDebug("Pipeline item added: \(item.id)", category: .monetization)
        return item
    }
    
    /// Moves an item to a new stage
    public func moveItem(_ id: UUID, to stage: PipelineStage) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        
        items[index].moveToStage(stage)
        saveItems()
        
        logDebug("Pipeline item \(id) moved to \(stage.displayName)", category: .monetization)
    }
    
    /// Removes an item
    public func removeItem(_ id: UUID) {
        items.removeAll { $0.id == id }
        saveItems()
    }
    
    /// Gets items at a specific stage
    public func items(at stage: PipelineStage) -> [PipelineItem] {
        items.filter { $0.stage == stage }
    }
    
    /// Gets count at a specific stage
    public func count(at stage: PipelineStage) -> Int {
        items.filter { $0.stage == stage }.count
    }
    
    /// Gets items from a specific channel
    public func items(from channel: PipelineChannel) -> [PipelineItem] {
        items.filter { $0.channel == channel }
    }
    
    /// Gets count from a specific channel
    public func count(from channel: PipelineChannel) -> Int {
        items.filter { $0.channel == channel }.count
    }
    
    /// Open items (not closed)
    public var openItems: [PipelineItem] {
        items.filter { $0.stage.isOpen }
    }
    
    /// Closed won items
    public var closedWonItems: [PipelineItem] {
        items.filter { $0.stage == .closedWon }
    }
    
    /// Closed lost items
    public var closedLostItems: [PipelineItem] {
        items.filter { $0.stage == .closedLost }
    }
    
    // MARK: - Summary (Counts Only)
    
    public func currentSummary() -> PipelineSummary {
        PipelineSummary(items: items)
    }
    
    // MARK: - Purge
    
    /// Purges items older than retention period
    public func purgeOldItems() {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -Self.maxRetentionDays, to: Date()) ?? Date()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let cutoffString = formatter.string(from: cutoffDate)
        
        let initialCount = items.count
        items.removeAll { $0.createdAtDayRounded < cutoffString }
        
        if items.count != initialCount {
            saveItems()
            logDebug("Purged \(initialCount - items.count) old pipeline items", category: .monetization)
        }
    }
    
    /// Purges all items (user-initiated)
    public func purgeAll() {
        items.removeAll()
        saveItems()
        logDebug("All pipeline items purged", category: .monetization)
    }
    
    // MARK: - Reset (for testing)
    
    public func reset() {
        items.removeAll()
        defaults.removeObject(forKey: storageKey)
    }
    
    // MARK: - Private
    
    private func loadItems() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PipelineItem].self, from: data) else {
            return
        }
        items = decoded
    }
    
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
}
