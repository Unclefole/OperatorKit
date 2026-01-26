import Foundation

// ============================================================================
// AUDIT VAULT STORE (Phase 13E)
//
// Local-only ring buffer store for Audit Vault events.
// No networking, no cloud sync, no background tasks.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking
// ❌ No cloud sync
// ❌ No background tasks
// ❌ No iCloud backup (if using files)
// ✅ Local UserDefaults only
// ✅ Ring buffer (max 500 events)
// ✅ Purge requires explicit confirmation
// ============================================================================

@MainActor
public final class AuditVaultStore: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = AuditVaultStore()
    
    // MARK: - Configuration
    
    public static let maxEventCount = 500
    private static let storageKey = "com.operatorkit.auditvault.events.v1"
    private static let sequenceKey = "com.operatorkit.auditvault.sequence.v1"
    
    // MARK: - State
    
    @Published public private(set) var events: [AuditVaultEvent] = []
    private var nextSequenceNumber: Int = 0
    
    // MARK: - Init
    
    private init() {
        load()
    }
    
    // MARK: - Load
    
    private func load() {
        // Load sequence number
        nextSequenceNumber = UserDefaults.standard.integer(forKey: Self.sequenceKey)
        
        // Load events
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else {
            events = []
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([AuditVaultEvent].self, from: data)
            events = decoded.sorted { $0.sequenceNumber < $1.sequenceNumber }
        } catch {
            events = []
        }
    }
    
    // MARK: - Save
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(events)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
            UserDefaults.standard.set(nextSequenceNumber, forKey: Self.sequenceKey)
        } catch {
            // Silent fail for local storage
        }
    }
    
    // MARK: - Add Event
    
    public func addEvent(kind: AuditVaultEventKind, lineage: AuditVaultLineage? = nil) {
        guard AuditVaultFeatureFlag.isEnabled else { return }
        
        let event = AuditVaultEvent(
            sequenceNumber: nextSequenceNumber,
            kind: kind,
            lineage: lineage
        )
        
        nextSequenceNumber += 1
        events.append(event)
        
        // Enforce ring buffer
        enforceRingBuffer()
        
        save()
    }
    
    // MARK: - Ring Buffer
    
    private func enforceRingBuffer() {
        if events.count > Self.maxEventCount {
            // Remove oldest events (lowest sequence numbers)
            let toRemove = events.count - Self.maxEventCount
            events = Array(events.dropFirst(toRemove))
        }
    }
    
    // MARK: - Stats
    
    public func summary() -> AuditVaultSummary {
        let now = dayRoundedNow()
        let sevenDaysAgo = dayRounded(daysAgo: 7)
        
        let last7Days = events.filter { $0.createdAtDayRounded >= sevenDaysAgo }
        
        var countByKind: [String: Int] = [:]
        for event in events {
            countByKind[event.kind.rawValue, default: 0] += 1
        }
        
        let editCount = events.filter { $0.kind == .lineageEdited }.count
        let exportCount = events.filter { $0.kind == .lineageExported }.count
        let lastVerified = events.last { $0.kind == .firewallVerified }?.createdAtDayRounded
        
        return AuditVaultSummary(
            totalEvents: events.count,
            eventsLast7Days: last7Days.count,
            countByKind: countByKind,
            editCount: editCount,
            exportCount: exportCount,
            lastVerifiedDayRounded: lastVerified
        )
    }
    
    // MARK: - List
    
    public func list(limit: Int? = nil) -> [AuditVaultEvent] {
        let sorted = events.sorted { $0.sequenceNumber > $1.sequenceNumber }
        if let limit = limit {
            return Array(sorted.prefix(limit))
        }
        return sorted
    }
    
    // MARK: - Get Event
    
    public func event(id: UUID) -> AuditVaultEvent? {
        events.first { $0.id == id }
    }
    
    // MARK: - Purge (Requires Explicit Confirmation)
    
    public enum PurgeResult {
        case success(purgedCount: Int)
        case requiresConfirmation
        case notEnabled
    }
    
    public func purge(confirmed: Bool) -> PurgeResult {
        guard AuditVaultFeatureFlag.isEnabled else {
            return .notEnabled
        }
        
        guard confirmed else {
            return .requiresConfirmation
        }
        
        let count = events.count
        
        // Record purge event before clearing
        let purgeEvent = AuditVaultEvent(
            sequenceNumber: nextSequenceNumber,
            kind: .vaultPurged,
            lineage: nil
        )
        nextSequenceNumber += 1
        
        // Clear all events except the purge record
        events = [purgeEvent]
        save()
        
        return .success(purgedCount: count)
    }
    
    // MARK: - Export (Metadata Only)
    
    public func exportSummary() -> AuditVaultExportPacket? {
        guard AuditVaultFeatureFlag.isEnabled else { return nil }
        
        let summary = self.summary()
        let recentEvents = list(limit: 20)
        
        return AuditVaultExportPacket(
            summary: summary,
            recentEvents: recentEvents,
            exportedAtDayRounded: dayRoundedNow(),
            schemaVersion: AuditVaultExportPacket.currentSchemaVersion
        )
    }
    
    // MARK: - Helpers
    
    private func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
    
    private func dayRounded(daysAgo: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return formatter.string(from: date)
    }
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    public func addSyntheticEvents(count: Int) {
        for i in 0..<count {
            let lineage = SyntheticAuditVaultLineage.generate(index: i)
            addEvent(kind: .lineageCreated, lineage: lineage)
            
            if i % 3 == 0 {
                addEvent(kind: .lineageEdited, lineage: lineage.withIncrementedEditCount())
            }
        }
    }
    
    public func reset() {
        events = []
        nextSequenceNumber = 0
        save()
    }
    #endif
}

// MARK: - Export Packet

public struct AuditVaultExportPacket: Codable {
    public let summary: AuditVaultSummary
    public let recentEvents: [AuditVaultEvent]
    public let exportedAtDayRounded: String
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Validation
    
    public func validate() -> [String] {
        var errors: [String] = []
        
        // Validate no forbidden keys in serialization
        if let jsonData = try? JSONEncoder().encode(self),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let lowercased = jsonString.lowercased()
            
            for key in AuditVaultForbiddenKeys.all {
                if lowercased.contains("\"\(key)\"") {
                    errors.append("Export contains forbidden key: \(key)")
                }
            }
            
            if !AuditVaultForbiddenKeys.validate(jsonString) {
                errors.append("Export contains forbidden patterns")
            }
        }
        
        return errors
    }
}
