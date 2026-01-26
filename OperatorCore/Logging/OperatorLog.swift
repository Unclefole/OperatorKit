import Foundation

public final class OperatorLog: @unchecked Sendable {
    
    public static let shared = OperatorLog()
    
    private var entries: [Entry] = []
    private let lock = NSLock()
    
    public init() {}
    
    public func append(_ entry: Entry) {
        lock.lock()
        defer { lock.unlock() }
        entries.append(entry)
    }
    
    public func append(outcome: Outcome) {
        let entry = Entry(
            timestamp: Date(),
            level: outcome.isAllowed ? .info : .warning,
            category: .decision,
            message: outcome.description,
            actionId: outcome.evidence.actionId,
            actionName: outcome.evidence.actionName
        )
        append(entry)
    }
    
    public func allEntries() -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }
    
    public func entries(for category: Entry.Category) -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries.filter { $0.category == category }
    }
    
    public func entries(since date: Date) -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries.filter { $0.timestamp >= date }
    }
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }
    
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }
    
    public struct Entry: Equatable, Sendable {
        public let id: UUID
        public let timestamp: Date
        public let level: Level
        public let category: Category
        public let message: String
        public let actionId: UUID?
        public let actionName: String?
        
        public init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            level: Level,
            category: Category,
            message: String,
            actionId: UUID? = nil,
            actionName: String? = nil
        ) {
            self.id = id
            self.timestamp = timestamp
            self.level = level
            self.category = category
            self.message = message
            self.actionId = actionId
            self.actionName = actionName
        }
        
        public enum Level: String, Equatable, Sendable, CaseIterable {
            case debug
            case info
            case warning
            case error
        }
        
        public enum Category: String, Equatable, Sendable, CaseIterable {
            case decision
            case trust
            case action
            case system
        }
    }
}
