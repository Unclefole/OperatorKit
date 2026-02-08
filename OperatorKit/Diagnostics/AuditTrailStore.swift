import Foundation
import CryptoKit

// ============================================================================
// CUSTOMER AUDIT TRAIL STORE (Phase 10P + Hardening)
//
// File-backed ring buffer for customer audit events with crash-safe writes.
// Max 500 events, with purge controls.
//
// PERSISTENCE:
// - Primary: Documents/OperatorKit/Audit/audit_trail.json
// - Backup:  Documents/OperatorKit/Audit/audit_trail.json.backup
// - Checksum: Documents/OperatorKit/Audit/audit_trail.checksum
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No networking
// ❌ No background tasks
// ✅ Ring buffer with cap
// ✅ Purge controls in UI
// ✅ Content-free invariants
// ✅ Atomic writes (tmp -> replace)
// ✅ Auto-recovery from backup
// ✅ SHA256 checksum for tamper detection
// ✅ File protection: completeUntilFirstUserAuthentication
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

@MainActor
public final class CustomerAuditTrailStore: ObservableObject {

    // MARK: - Singleton

    public static let shared = CustomerAuditTrailStore()

    // MARK: - Constants

    /// Maximum number of events to store
    public static let maxEvents = 500

    // MARK: - File Paths

    private static var auditDirectory: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("OperatorKit/Audit", isDirectory: true)
    }

    private static var mainFileURL: URL {
        auditDirectory.appendingPathComponent("audit_trail.json")
    }

    private static var backupFileURL: URL {
        auditDirectory.appendingPathComponent("audit_trail.json.backup")
    }

    private static var checksumFileURL: URL {
        auditDirectory.appendingPathComponent("audit_trail.checksum")
    }

    // MARK: - Legacy Storage (for migration)

    private let legacyDefaults: UserDefaults
    private let legacyStorageKey = "com.operatorkit.customer.audit.trail"
    private let schemaVersionKey = "com.operatorkit.customer.audit.schema_version"

    // MARK: - State

    @Published public private(set) var events: [CustomerAuditEvent]

    /// Indicates if data was recovered from backup on last load
    public private(set) var wasRecoveredFromBackup: Bool = false

    // MARK: - Initialization

    private init(defaults: UserDefaults = .standard) {
        self.legacyDefaults = defaults
        self.events = []
        loadEvents()
    }

    /// Test-only initializer for dependency injection
    internal init(defaults: UserDefaults, testDirectory: URL?) {
        self.legacyDefaults = defaults
        self.events = []
        if let testDir = testDirectory {
            _testDirectoryOverride = testDir
        }
        loadEvents()
    }

    // MARK: - Test Support

    private var _testDirectoryOverride: URL?

    private var effectiveMainFileURL: URL {
        if let override = _testDirectoryOverride {
            return override.appendingPathComponent("audit_trail.json")
        }
        return Self.mainFileURL
    }

    private var effectiveBackupFileURL: URL {
        if let override = _testDirectoryOverride {
            return override.appendingPathComponent("audit_trail.json.backup")
        }
        return Self.backupFileURL
    }

    private var effectiveChecksumFileURL: URL {
        if let override = _testDirectoryOverride {
            return override.appendingPathComponent("audit_trail.checksum")
        }
        return Self.checksumFileURL
    }
    
    // MARK: - Recording
    
    /// Records an audit event
    public func recordEvent(_ event: CustomerAuditEvent) {
        events.append(event)
        
        // Enforce ring buffer cap
        while events.count > Self.maxEvents {
            events.removeFirst()
        }
        
        saveEvents()
        
        logDebug("Customer audit event recorded: \(event.kind.rawValue)", category: .diagnostics)
    }
    
    /// Records an event with parameters
    public func record(
        kind: CustomerAuditEventKind,
        intentType: String,
        outputType: String,
        result: CustomerAuditEventResult,
        failureCategory: FailureCategory? = nil,
        backendUsed: String,
        policyDecision: CustomerAuditPolicyDecision? = nil,
        tierAtTime: String
    ) {
        let event = CustomerAuditEvent(
            kind: kind,
            intentType: intentType,
            outputType: outputType,
            result: result,
            failureCategory: failureCategory,
            backendUsed: backendUsed,
            policyDecision: policyDecision,
            tierAtTime: tierAtTime
        )
        recordEvent(event)
    }
    
    // MARK: - Summary
    
    /// Gets current summary for export
    public func currentSummary() -> CustomerAuditTrailSummary {
        let today = dayRoundedNow()
        let sevenDaysAgo = dayRoundedDate(daysAgo: 7)
        
        // Count events in last 7 days
        let recentEvents = events.filter { $0.createdAtDayRounded >= sevenDaysAgo }
        
        // Count by kind
        var countByKind: [String: Int] = [:]
        for event in events {
            countByKind[event.kind.rawValue, default: 0] += 1
        }
        
        // Count by result
        var countByResult: [String: Int] = [:]
        for event in events {
            countByResult[event.result.rawValue, default: 0] += 1
        }
        
        // Success rate
        let successCount = countByResult[CustomerAuditEventResult.success.rawValue] ?? 0
        let totalWithOutcome = (countByResult[CustomerAuditEventResult.success.rawValue] ?? 0) +
                               (countByResult[CustomerAuditEventResult.failure.rawValue] ?? 0)
        let successRate: Double? = totalWithOutcome > 0 ? Double(successCount) / Double(totalWithOutcome) : nil
        
        // Most recent 20 events
        let mostRecent = Array(events.suffix(20))
        
        return CustomerAuditTrailSummary(
            totalEvents: events.count,
            eventsLast7Days: recentEvents.count,
            countByKind: countByKind,
            countByResult: countByResult,
            successRate: successRate,
            recentEvents: mostRecent,
            schemaVersion: CustomerAuditTrailSummary.currentSchemaVersion,
            capturedAt: today
        )
    }
    
    // MARK: - Query
    
    /// Events from last N days
    public func eventsFromLastDays(_ days: Int) -> [CustomerAuditEvent] {
        let cutoff = dayRoundedDate(daysAgo: days)
        return events.filter { $0.createdAtDayRounded >= cutoff }
    }
    
    /// Events of a specific kind
    public func events(ofKind kind: CustomerAuditEventKind) -> [CustomerAuditEvent] {
        events.filter { $0.kind == kind }
    }
    
    /// Count of events today
    public var countToday: Int {
        let today = dayRoundedNow()
        return events.filter { $0.createdAtDayRounded == today }.count
    }
    
    // MARK: - Purge
    
    /// Purges all audit events (user-initiated only)
    public func purgeAll() {
        events = []
        removeAllFiles()

        logDebug("Customer audit trail purged", category: .diagnostics)
    }

    /// Purges events older than N days
    public func purgeOlderThan(days: Int) {
        let cutoff = dayRoundedDate(daysAgo: days)
        events = events.filter { $0.createdAtDayRounded >= cutoff }
        saveEvents()

        logDebug("Customer audit trail purged events older than \(days) days", category: .diagnostics)
    }

    // MARK: - Reset (for testing)

    public func reset() {
        events = []
        removeAllFiles()
    }

    // MARK: - Private - File Operations

    private func loadEvents() {
        // 1. Try migration from legacy UserDefaults first
        if let legacyData = legacyDefaults.data(forKey: legacyStorageKey),
           let legacyEvents = try? JSONDecoder().decode([CustomerAuditEvent].self, from: legacyData) {
            logDebug("CustomerAuditTrailStore: Migrating from UserDefaults", category: .diagnostics)
            events = legacyEvents
            saveEvents() // Persist to file
            legacyDefaults.removeObject(forKey: legacyStorageKey) // Clean up legacy
            return
        }

        // 2. Load from file with recovery
        guard let result = AtomicFileWriter.readWithRecovery(
            from: effectiveMainFileURL,
            backupURL: effectiveBackupFileURL,
            checksumURL: effectiveChecksumFileURL
        ) else {
            // No file exists yet, start fresh
            events = []
            return
        }

        wasRecoveredFromBackup = result.wasRecovered

        // 3. Decode events
        guard let decoded = try? JSONDecoder().decode([CustomerAuditEvent].self, from: result.data) else {
            logError("CustomerAuditTrailStore: Failed to decode events", category: .diagnostics)
            events = []
            return
        }

        events = decoded

        if wasRecoveredFromBackup {
            logDebug("CustomerAuditTrailStore: Loaded \(events.count) events (recovered from backup)", category: .diagnostics)
        } else {
            logDebug("CustomerAuditTrailStore: Loaded \(events.count) events", category: .diagnostics)
        }
    }

    private func saveEvents() {
        guard let encoded = try? JSONEncoder().encode(events) else {
            logError("CustomerAuditTrailStore: Failed to encode events", category: .diagnostics)
            return
        }

        let success = AtomicFileWriter.writeAtomically(
            data: encoded,
            to: effectiveMainFileURL,
            backupURL: effectiveBackupFileURL,
            checksumURL: effectiveChecksumFileURL
        )

        if success {
            logDebug("CustomerAuditTrailStore: Saved \(events.count) events", category: .diagnostics)
        } else {
            logError("CustomerAuditTrailStore: Failed to save events (app continues)", category: .diagnostics)
        }
    }

    private func removeAllFiles() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: effectiveMainFileURL)
        try? fileManager.removeItem(at: effectiveBackupFileURL)
        try? fileManager.removeItem(at: effectiveChecksumFileURL)
        // Also clean up legacy UserDefaults
        legacyDefaults.removeObject(forKey: legacyStorageKey)
    }
    
    private func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
    
    private func dayRoundedDate(daysAgo: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Convenience Recording Methods

extension CustomerAuditTrailStore {
    
    /// Records an approval granted event
    public func recordApprovalGranted(
        intentType: String,
        outputType: String,
        backendUsed: String,
        tier: String
    ) {
        record(
            kind: .approvalGranted,
            intentType: intentType,
            outputType: outputType,
            result: .success,
            backendUsed: backendUsed,
            policyDecision: .allowed,
            tierAtTime: tier
        )
    }
    
    /// Records an execution succeeded event
    public func recordExecutionSucceeded(
        intentType: String,
        outputType: String,
        backendUsed: String,
        tier: String
    ) {
        record(
            kind: .executionSucceeded,
            intentType: intentType,
            outputType: outputType,
            result: .success,
            backendUsed: backendUsed,
            tierAtTime: tier
        )
    }
    
    /// Records an execution failed event
    public func recordExecutionFailed(
        intentType: String,
        outputType: String,
        backendUsed: String,
        tier: String,
        failureCategory: FailureCategory
    ) {
        record(
            kind: .executionFailed,
            intentType: intentType,
            outputType: outputType,
            result: .failure,
            failureCategory: failureCategory,
            backendUsed: backendUsed,
            tierAtTime: tier
        )
    }
    
    /// Records a template used event
    public func recordTemplateUsed(
        templateId: String,
        tier: String
    ) {
        record(
            kind: .templateUsed,
            intentType: "template",
            outputType: templateId,
            result: .success,
            backendUsed: "local",
            tierAtTime: tier
        )
    }
    
    /// Records a template completed event
    public func recordTemplateCompleted(
        templateId: String,
        tier: String
    ) {
        record(
            kind: .templateCompleted,
            intentType: "template",
            outputType: templateId,
            result: .success,
            backendUsed: "local",
            tierAtTime: tier
        )
    }
    
    /// Records a policy denied event
    public func recordPolicyDenied(
        intentType: String,
        outputType: String,
        tier: String,
        reason: CustomerAuditPolicyDecision
    ) {
        record(
            kind: .policyDenied,
            intentType: intentType,
            outputType: outputType,
            result: .denied,
            backendUsed: "policy",
            policyDecision: reason,
            tierAtTime: tier
        )
    }
}

// ============================================================================
// ATOMIC FILE WRITER (Inlined for Build Reliability)
//
// Crash-safe file writes with atomic tmp -> replace pattern.
// ============================================================================

/// Crash-safe file writer with backup and checksum support
private enum AtomicFileWriter {

    /// Writes data atomically with backup and checksum
    @discardableResult
    static func writeAtomically(
        data: Data,
        to url: URL,
        backupURL: URL? = nil,
        checksumURL: URL? = nil
    ) -> Bool {
        let fileManager = FileManager.default

        // 1. Ensure directory exists
        let directory = url.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [
                    .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
                ]
            )
        } catch {
            logError("AtomicFileWriter: Directory creation failed: \(error)", category: .diagnostics)
            return false
        }

        // 2. Create backup of existing file (if exists and backup URL provided)
        if let backupURL = backupURL, fileManager.fileExists(atPath: url.path) {
            do {
                if fileManager.fileExists(atPath: backupURL.path) {
                    try fileManager.removeItem(at: backupURL)
                }
                try fileManager.copyItem(at: url, to: backupURL)
            } catch {
                logError("AtomicFileWriter: Backup creation failed: \(error)", category: .diagnostics)
            }
        }

        // 3. Write to temp file
        let tempURL = url.appendingPathExtension("tmp")
        do {
            try data.write(
                to: tempURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
        } catch {
            logError("AtomicFileWriter: Temp write failed: \(error)", category: .diagnostics)
            return false
        }

        // 4. Replace main file with temp file
        do {
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: url)
            }
        } catch {
            logError("AtomicFileWriter: Replace failed: \(error)", category: .diagnostics)
            try? fileManager.removeItem(at: tempURL)
            return false
        }

        // 5. Write checksum (if URL provided)
        if let checksumURL = checksumURL {
            let checksum = computeChecksum(data)
            do {
                try checksum.write(to: checksumURL, atomically: true, encoding: .utf8)
            } catch {
                logError("AtomicFileWriter: Checksum write failed: \(error)", category: .diagnostics)
            }
        }

        return true
    }

    /// Reads data with automatic recovery from backup if main file is corrupted
    static func readWithRecovery(
        from url: URL,
        backupURL: URL?,
        checksumURL: URL?
    ) -> (data: Data, wasRecovered: Bool)? {
        let fileManager = FileManager.default

        // 1. Try reading main file
        if let data = try? Data(contentsOf: url) {
            if let checksumURL = checksumURL,
               let storedChecksum = try? String(contentsOf: checksumURL, encoding: .utf8) {
                let computedChecksum = computeChecksum(data)
                if storedChecksum.trimmingCharacters(in: .whitespacesAndNewlines) == computedChecksum {
                    return (data, false)
                } else {
                    logError("AtomicFileWriter: Checksum mismatch, trying backup", category: .diagnostics)
                }
            } else {
                return (data, false)
            }
        }

        // 2. Main file failed or corrupted, try backup
        guard let backupURL = backupURL,
              fileManager.fileExists(atPath: backupURL.path),
              let backupData = try? Data(contentsOf: backupURL) else {
            return nil
        }

        logDebug("AtomicFileWriter: Recovered from backup", category: .diagnostics)

        // 3. Restore backup to main
        do {
            try backupData.write(
                to: url,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
            if let checksumURL = checksumURL {
                let checksum = computeChecksum(backupData)
                try? checksum.write(to: checksumURL, atomically: true, encoding: .utf8)
            }
        } catch {
            logError("AtomicFileWriter: Failed to restore backup: \(error)", category: .diagnostics)
        }

        return (backupData, true)
    }

    /// Computes SHA256 checksum of data
    static func computeChecksum(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
