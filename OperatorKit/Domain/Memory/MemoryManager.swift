import Foundation

/// Manages memory operations with persistent storage
@MainActor
final class MemoryManager {
    
    static let shared = MemoryManager()
    
    private let store = MemoryStore.shared
    
    private init() {}
    
    // MARK: - Accessors
    
    var allItems: [PersistedMemoryItem] {
        store.items
    }
    
    var recentItems: [PersistedMemoryItem] {
        Array(store.items.prefix(10))
    }
    
    var itemCount: Int {
        store.items.count
    }
    
    // MARK: - Save Operations
    
    /// Saves an execution result with full audit trail
    func save(
        executionResult: ExecutionResultModel,
        intent: IntentRequest?,
        context: ContextPacket?,
        approvalTimestamp: Date
    ) {
        store.addFromExecution(
            result: executionResult,
            intent: intent,
            context: context,
            approvalTimestamp: approvalTimestamp
        )
        
        log("Saved execution result to persistent memory: \(executionResult.draft.title)")
    }
    
    // MARK: - Search & Filter
    
    func search(query: String) -> [PersistedMemoryItem] {
        store.search(query: query)
    }
    
    func getItemsFromPast(days: Int) -> [PersistedMemoryItem] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return store.items.filter { $0.createdAt >= cutoffDate }
    }
    
    // MARK: - Deletion
    
    func delete(item: PersistedMemoryItem) {
        store.remove(item)
    }
    
    func deleteById(_ id: UUID) {
        store.remove(id: id)
    }
    
    func clearAllMemory() {
        store.clearAll()
    }
    
    // MARK: - Lookup
    
    func getItem(by id: UUID) -> PersistedMemoryItem? {
        store.getItem(by: id)
    }
}
