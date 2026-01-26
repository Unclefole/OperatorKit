import Foundation
import CryptoKit

// ============================================================================
// ABUSE GUARDRAILS (Phase 10F)
//
// Metadata-only abuse detection without content inspection.
// Uses hashes, timing, and patterns — never content itself.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No content inspection
// ❌ No content storage
// ❌ No content logging
// ❌ Does NOT affect execution
// ❌ No analytics
// ✅ Hash-based deduplication
// ✅ Pattern detection only
// ✅ UI boundary enforcement
// ✅ Fail closed
//
// See: docs/SAFETY_CONTRACT.md (Section 15)
// ============================================================================

// MARK: - Abuse Check Result

/// Result of abuse detection check
public struct AbuseCheckResult {
    
    /// Whether abuse was detected
    public let abuseDetected: Bool
    
    /// Type of abuse (if detected)
    public let abuseType: AbuseType?
    
    /// User-facing message
    public let message: String?
    
    /// Whether to block at UI level
    public let shouldBlock: Bool
    
    /// Creates a clean result
    public static func clean() -> AbuseCheckResult {
        AbuseCheckResult(
            abuseDetected: false,
            abuseType: nil,
            message: nil,
            shouldBlock: false
        )
    }
    
    /// Creates a detected result
    public static func detected(
        type: AbuseType,
        message: String,
        shouldBlock: Bool
    ) -> AbuseCheckResult {
        AbuseCheckResult(
            abuseDetected: true,
            abuseType: type,
            message: message,
            shouldBlock: shouldBlock
        )
    }
}

// MARK: - Abuse Type

/// Types of abuse patterns (metadata only)
public enum AbuseType: String, Codable {
    case intentRepetition = "intent_repetition"
    case rapidFire = "rapid_fire"
    case burstPattern = "burst_pattern"
    case unusualTiming = "unusual_timing"
    
    public var displayName: String {
        switch self {
        case .intentRepetition: return "Repeated Request"
        case .rapidFire: return "Rapid Requests"
        case .burstPattern: return "Burst Pattern"
        case .unusualTiming: return "Unusual Pattern"
        }
    }
}

// MARK: - Abuse Detector

/// Metadata-only abuse detection
@MainActor
public final class AbuseDetector: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = AbuseDetector()
    
    // MARK: - Configuration
    
    /// How many identical intents before flagging
    private let repetitionThreshold = 3
    
    /// Time window for repetition detection (seconds)
    private let repetitionWindowSeconds: TimeInterval = 300  // 5 minutes
    
    /// Minimum interval between executions (seconds)
    private let minIntervalSeconds: TimeInterval = 2
    
    /// Max executions in rapid-fire window
    private let rapidFireThreshold = 10
    
    /// Rapid-fire detection window (seconds)
    private let rapidFireWindowSeconds: TimeInterval = 60
    
    // MARK: - State
    
    /// Recent intent hashes (NO content, just hashes)
    private var intentHashes: [(hash: String, timestamp: Date)] = []
    
    /// Recent execution timestamps
    private var executionTimestamps: [Date] = []
    
    @Published public private(set) var lastAbuseType: AbuseType?
    @Published public private(set) var abuseCount: Int = 0
    
    private let defaults: UserDefaults
    private let hashesKey = "com.operatorkit.abuse.hashes"
    private let timestampsKey = "com.operatorkit.abuse.timestamps"
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadState()
    }
    
    // MARK: - Abuse Detection
    
    /// Checks for abuse patterns
    /// IMPORTANT: Uses hash ONLY, never inspects content
    /// - Parameter intentHash: Hash of intent (computed externally)
    public func checkForAbuse(intentHash: String) -> AbuseCheckResult {
        let now = Date()
        
        // Clean old data
        cleanOldData()
        
        // 1. Check for intent repetition (hash-based, no content)
        let recentSameHash = intentHashes.filter {
            $0.hash == intentHash &&
            now.timeIntervalSince($0.timestamp) < repetitionWindowSeconds
        }.count
        
        if recentSameHash >= repetitionThreshold {
            lastAbuseType = .intentRepetition
            abuseCount += 1
            return .detected(
                type: .intentRepetition,
                message: "You've made this request several times recently. Consider trying something different.",
                shouldBlock: false  // Inform, don't block
            )
        }
        
        // 2. Check for rapid-fire
        let recentExecutions = executionTimestamps.filter {
            now.timeIntervalSince($0) < rapidFireWindowSeconds
        }.count
        
        if recentExecutions >= rapidFireThreshold {
            lastAbuseType = .rapidFire
            abuseCount += 1
            return .detected(
                type: .rapidFire,
                message: "You're running actions very quickly. Consider slowing down.",
                shouldBlock: true  // Block at UI level
            )
        }
        
        // 3. Check for too-rapid interval
        if let lastExecution = executionTimestamps.last {
            let interval = now.timeIntervalSince(lastExecution)
            if interval < minIntervalSeconds {
                return .detected(
                    type: .rapidFire,
                    message: "Please wait a moment between actions.",
                    shouldBlock: true
                )
            }
        }
        
        return .clean()
    }
    
    /// Records an intent hash after execution
    /// IMPORTANT: Only stores hash, never content
    public func recordIntent(hash: String) {
        let now = Date()
        intentHashes.append((hash: hash, timestamp: now))
        executionTimestamps.append(now)
        saveState()
    }
    
    /// Computes a hash for an intent (call this externally)
    /// The intent content is immediately discarded after hashing
    public static func computeIntentHash(_ intent: String) -> String {
        // Use SHA256 for one-way hashing
        let data = Data(intent.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Resets abuse detection state (for testing)
    public func reset() {
        intentHashes = []
        executionTimestamps = []
        lastAbuseType = nil
        abuseCount = 0
        defaults.removeObject(forKey: hashesKey)
        defaults.removeObject(forKey: timestampsKey)
    }
    
    // MARK: - Persistence
    
    private func loadState() {
        // Load timestamps
        if let timestampData = defaults.data(forKey: timestampsKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let timestamps = try? decoder.decode([Date].self, from: timestampData) {
                executionTimestamps = timestamps
            }
        }
        
        // Load hashes (stored as array of dictionaries)
        if let hashData = defaults.data(forKey: hashesKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let hashes = try? decoder.decode([IntentHashRecord].self, from: hashData) {
                intentHashes = hashes.map { ($0.hash, $0.timestamp) }
            }
        }
    }
    
    private func saveState() {
        // Save timestamps
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let timestampData = try? encoder.encode(executionTimestamps) {
            defaults.set(timestampData, forKey: timestampsKey)
        }
        
        // Save hashes
        let hashRecords = intentHashes.map { IntentHashRecord(hash: $0.hash, timestamp: $0.timestamp) }
        if let hashData = try? encoder.encode(hashRecords) {
            defaults.set(hashData, forKey: hashesKey)
        }
    }
    
    private func cleanOldData() {
        let cutoff = Date().addingTimeInterval(-repetitionWindowSeconds * 2)
        intentHashes = intentHashes.filter { $0.timestamp > cutoff }
        executionTimestamps = executionTimestamps.filter { $0 > cutoff }
    }
}

// MARK: - Intent Hash Record

private struct IntentHashRecord: Codable {
    let hash: String
    let timestamp: Date
}

// MARK: - Abuse Summary

/// Summary of abuse patterns (for diagnostics)
public struct AbuseSummary: Codable {
    public let capturedAt: Date
    public let totalAbuseDetections: Int
    public let lastAbuseType: String?
    public let executionsInLastHour: Int
    public let uniqueIntentsInLastHour: Int
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
}

// MARK: - Abuse Detector Summary Extension

extension AbuseDetector {
    
    /// Creates current abuse summary
    public func currentSummary() -> AbuseSummary {
        let hourAgo = Date().addingTimeInterval(-3600)
        let recentCount = executionTimestamps.filter { $0 > hourAgo }.count
        let uniqueHashes = Set(intentHashes.filter { $0.timestamp > hourAgo }.map { $0.hash }).count
        
        return AbuseSummary(
            capturedAt: Date(),
            totalAbuseDetections: abuseCount,
            lastAbuseType: lastAbuseType?.rawValue,
            executionsInLastHour: recentCount,
            uniqueIntentsInLastHour: uniqueHashes,
            schemaVersion: AbuseSummary.currentSchemaVersion
        )
    }
}
