import Foundation

// ============================================================================
// SUPPORT PACKET (Phase 10Q)
//
// Metadata-only export for support escalation.
// User-initiated via ShareSheet only.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content (body, subject, draft, prompt, etc.)
// ❌ No networking
// ❌ No auto-export
// ✅ Metadata only
// ✅ User-initiated
// ✅ ShareSheet export
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Support Packet

public struct SupportPacket: Codable {
    
    // MARK: - Metadata
    
    public let schemaVersion: Int
    public let exportedAt: String // Day-rounded
    
    // MARK: - App Info
    
    public let appVersion: String
    public let buildNumber: String
    public let releaseMode: String
    public let iosVersion: String
    public let deviceModel: String
    
    // MARK: - Account State
    
    public let currentTier: String
    public let hasActiveTrial: Bool
    public let isFirstWeek: Bool
    public let daysSinceInstall: Int
    
    // MARK: - Policy State
    
    public let policyEnabled: Bool
    public let policyCapabilities: PolicyCapabilitiesSummary
    
    // MARK: - Quality State
    
    public let qualityGateStatus: String
    public let coverageScore: Int?
    public let invariantsPassing: Bool
    
    // MARK: - Audit Summary (Counts Only)
    
    public let auditEventCount: Int
    public let auditEventsLast7Days: Int
    
    // MARK: - Diagnostics Summary (Counts Only)
    
    public let totalExecutions: Int
    public let successCount: Int
    public let failureCount: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Export
    
    public func toJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    
    public var filename: String {
        "OperatorKit_Support_\(exportedAt).json"
    }
    
    // MARK: - Validation
    
    public func validateNoForbiddenKeys() throws -> [String] {
        let jsonData = try toJSONData()
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }
        
        return Self.findForbiddenKeys(in: json, path: "")
    }
    
    public static let forbiddenKeys: [String] = [
        "body", "subject", "content", "draft", "prompt",
        "context", "note", "email", "attendees", "title",
        "description", "message", "text", "recipient", "sender",
        "userId", "deviceId", "receipt", "freeText", "rawError"
    ]
    
    private static func findForbiddenKeys(in dict: [String: Any], path: String) -> [String] {
        var violations: [String] = []
        
        for (key, value) in dict {
            let fullPath = path.isEmpty ? key : "\(path).\(key)"
            
            if forbiddenKeys.contains(key.lowercased()) {
                violations.append("Forbidden key: \(fullPath)")
            }
            
            if let nested = value as? [String: Any] {
                violations.append(contentsOf: findForbiddenKeys(in: nested, path: fullPath))
            }
        }
        
        return violations
    }
}

// MARK: - Policy Capabilities Summary

public struct PolicyCapabilitiesSummary: Codable {
    public let allowEmailDrafts: Bool
    public let allowCalendarWrites: Bool
    public let allowTaskCreation: Bool
    public let allowMemoryWrites: Bool
    public let maxExecutionsPerDay: Int?
    public let requireExplicitConfirmation: Bool
}

// MARK: - Support Packet Builder

@MainActor
public final class SupportPacketBuilder {
    
    // MARK: - Singleton
    
    public static let shared = SupportPacketBuilder()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Build
    
    public func build() -> SupportPacket {
        let firstWeek = FirstWeekStore.shared
        let entitlement = EntitlementManager.shared
        let trial = TeamTrialStore.shared
        let policy = OperatorPolicyStore.shared.currentPolicy
        let diagnostics = ExecutionDiagnostics.shared.currentSnapshot()
        let auditStore = CustomerAuditTrailStore.shared
        
        // Quality gate
        var qualityStatus = "unknown"
        var coverage: Int? = nil
        var invariants = true
        if let gate = QualityGate.shared.currentResult {
            qualityStatus = gate.status.rawValue
            coverage = gate.coverageScore
            invariants = gate.invariantsPassing
        }
        
        return SupportPacket(
            schemaVersion: SupportPacket.currentSchemaVersion,
            exportedAt: dayRoundedNow(),
            appVersion: appVersion,
            buildNumber: buildNumber,
            releaseMode: releaseMode,
            iosVersion: iosVersion,
            deviceModel: deviceModel,
            currentTier: entitlement.currentTier.rawValue,
            hasActiveTrial: trial.hasActiveTrial,
            isFirstWeek: firstWeek.isFirstWeek,
            daysSinceInstall: firstWeek.daysSinceInstall,
            policyEnabled: policy.enabled,
            policyCapabilities: PolicyCapabilitiesSummary(
                allowEmailDrafts: policy.allowEmailDrafts,
                allowCalendarWrites: policy.allowCalendarWrites,
                allowTaskCreation: policy.allowTaskCreation,
                allowMemoryWrites: policy.allowMemoryWrites,
                maxExecutionsPerDay: policy.maxExecutionsPerDay,
                requireExplicitConfirmation: policy.requireExplicitConfirmation
            ),
            qualityGateStatus: qualityStatus,
            coverageScore: coverage,
            invariantsPassing: invariants,
            auditEventCount: auditStore.events.count,
            auditEventsLast7Days: auditStore.eventsFromLastDays(7).count,
            totalExecutions: diagnostics.totalExecutions,
            successCount: diagnostics.successCount,
            failureCount: diagnostics.failureCount
        )
    }
    
    // MARK: - Helpers
    
    private func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    private var releaseMode: String {
        #if DEBUG
        return "debug"
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return "testflight"
        }
        return "appstore"
        #endif
    }
    
    private var iosVersion: String {
        #if os(iOS)
        return UIDevice.current.systemVersion
        #else
        return "Unknown"
        #endif
    }
    
    private var deviceModel: String {
        #if os(iOS)
        return UIDevice.current.model
        #else
        return "Unknown"
        #endif
    }
}
