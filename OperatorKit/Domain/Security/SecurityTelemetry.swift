import Foundation
import os.log
#if canImport(UIKit)
import UIKit
#endif

// ============================================================================
// SECURITY TELEMETRY — Structured Trust Signal Logging
//
// Logs security-relevant events WITHOUT sensitive data. Enterprise-grade
// observability for regulated environments.
//
// INVARIANT: NO secrets, keys, tokens, or PII ever appear in telemetry.
// INVARIANT: All events carry structured metadata (device, timestamp, category).
// INVARIANT: Events are append-only — cannot be retroactively modified.
// INVARIANT: Telemetry is device-local unless enterprise mirror is configured.
// ============================================================================

public enum SecurityEventCategory: String, Sendable {
    case vaultAccess       = "vault_access"
    case vaultFailure      = "vault_failure"
    case biometricPrompt   = "biometric_prompt"
    case biometricReject   = "biometric_reject"
    case attestation       = "attestation"
    case attestationFail   = "attestation_fail"
    case connectorDeny     = "connector_deny"
    case integrityCheck    = "integrity_check"
    case integrityViolation = "integrity_violation"
    case executionGate     = "execution_gate"
    case networkPolicy     = "network_policy"
    case tokenIssuance     = "token_issuance"
    case tokenReject       = "token_reject"
    case keystoreReset     = "keystore_reset"
    case deviceRegistration = "device_registration"
    case catalystSecurity  = "catalyst_security"
}

public struct SecurityEvent: Sendable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let category: String
    public let detail: String
    public let deviceClass: String
    public let outcome: String       // "success", "failure", "denied", "warning"
    public let metadata: [String: String]

    public init(
        category: SecurityEventCategory,
        detail: String,
        outcome: SecurityEventOutcome,
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.category = category.rawValue
        self.detail = String(detail.prefix(500)) // Cap detail length
        self.outcome = outcome.rawValue
        self.metadata = metadata

        #if targetEnvironment(macCatalyst)
        self.deviceClass = "mac"
        #elseif os(iOS)
        // Use idiom to distinguish iPhone vs iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.deviceClass = "ipad"
        } else {
            self.deviceClass = "iphone"
        }
        #else
        self.deviceClass = "unknown"
        #endif
    }
}

public enum SecurityEventOutcome: String, Sendable {
    case success = "success"
    case failure = "failure"
    case denied  = "denied"
    case warning = "warning"
}

// MARK: - Security Telemetry Engine

public final class SecurityTelemetry: @unchecked Sendable {

    public static let shared = SecurityTelemetry()

    private static let logger = Logger(subsystem: "com.operatorkit", category: "SecurityTelemetry")

    /// In-memory ring buffer — capped at 1000 events. Oldest evicted first.
    private var events: [SecurityEvent] = []
    private let maxEvents = 1000
    private let queue = DispatchQueue(label: "com.operatorkit.security-telemetry", qos: .utility)

    private init() {}

    // MARK: - Record

    /// Record a security event. Thread-safe. No sensitive data allowed.
    public func record(
        category: SecurityEventCategory,
        detail: String,
        outcome: SecurityEventOutcome,
        metadata: [String: String] = [:]
    ) {
        let event = SecurityEvent(
            category: category,
            detail: detail,
            outcome: outcome,
            metadata: metadata
        )

        queue.async { [weak self] in
            guard let self else { return }
            self.events.append(event)
            if self.events.count > self.maxEvents {
                self.events.removeFirst(self.events.count - self.maxEvents)
            }
        }

        // Also pipe to os.log for Console.app / sysdiagnose
        let level: OSLogType = (outcome == .failure || outcome == .denied) ? .error : .info
        Self.logger.log(level: level, "[\(category.rawValue)] \(detail) → \(outcome.rawValue)")

        // Pipe to EvidenceEngine for append-only audit
        let planId = UUID()
        Task { @MainActor in
            try? EvidenceEngine.shared.logGenericArtifact(
                type: "security_telemetry_\(category.rawValue)",
                planId: planId,
                jsonString: """
                {"detail":"\(String(detail.prefix(200)))","outcome":"\(outcome.rawValue)","deviceClass":"\(event.deviceClass)","timestamp":"\(event.timestamp.ISO8601Format())"}
                """
            )
        }
    }

    // MARK: - Query

    /// Return recent events (newest first). Thread-safe.
    public func recentEvents(limit: Int = 50) -> [SecurityEvent] {
        queue.sync {
            Array(events.suffix(limit).reversed())
        }
    }

    /// Return events filtered by category. Thread-safe.
    public func events(for category: SecurityEventCategory, limit: Int = 50) -> [SecurityEvent] {
        queue.sync {
            Array(events.filter { $0.category == category.rawValue }.suffix(limit).reversed())
        }
    }

    /// Count of events by outcome for a given category.
    public func outcomeCount(for category: SecurityEventCategory) -> [String: Int] {
        queue.sync {
            var counts: [String: Int] = [:]
            for event in events where event.category == category.rawValue {
                counts[event.outcome, default: 0] += 1
            }
            return counts
        }
    }

    // MARK: - Export (Redacted)

    /// Export telemetry for support/diagnostics. No secrets included.
    public func exportRedactedReport() -> String {
        let snapshot = queue.sync { events }
        var lines: [String] = [
            "=== OPERATORKIT SECURITY TELEMETRY REPORT ===",
            "Generated: \(Date().ISO8601Format())",
            "Total events: \(snapshot.count)",
            "---"
        ]

        // Summary by category
        var categoryCounts: [String: Int] = [:]
        var outcomeCounts: [String: Int] = [:]
        for event in snapshot {
            categoryCounts[event.category, default: 0] += 1
            outcomeCounts[event.outcome, default: 0] += 1
        }

        lines.append("CATEGORY SUMMARY:")
        for (cat, count) in categoryCounts.sorted(by: { $0.key < $1.key }) {
            lines.append("  \(cat): \(count)")
        }

        lines.append("OUTCOME SUMMARY:")
        for (outcome, count) in outcomeCounts.sorted(by: { $0.key < $1.key }) {
            lines.append("  \(outcome): \(count)")
        }

        lines.append("---")
        lines.append("RECENT EVENTS (last 50):")
        for event in snapshot.suffix(50) {
            lines.append("  [\(event.timestamp.ISO8601Format())] \(event.category) → \(event.outcome): \(event.detail)")
        }

        return lines.joined(separator: "\n")
    }
}
