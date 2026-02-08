import Foundation

// ============================================================================
// TEAM ARTIFACTS (Phase 10E)
//
// Metadata-only artifacts that can be shared within a team.
// These are derived from local artifacts, stripped of any user content.
//
// SHAREABLE (Metadata Only):
// ✅ Policy templates (settings only)
// ✅ Diagnostics snapshots (aggregate stats)
// ✅ Quality summaries (pass rates, drift)
// ✅ Evidence packet references (hash + timestamp)
// ✅ Release acknowledgements (sign-off metadata)
//
// NEVER SHAREABLE:
// ❌ Drafts
// ❌ Memory items
// ❌ Context packets
// ❌ User inputs
//
// See: docs/SAFETY_CONTRACT.md (Section 14)
// ============================================================================

// MARK: - Team Policy Template

/// Policy template derived from OperatorPolicy (settings only)
public struct TeamPolicyTemplate: Codable, Equatable {
    
    /// Unique identifier
    public let id: UUID
    
    /// Template name
    public let name: String
    
    /// Description
    public let description: String
    
    /// When created
    public let createdAt: Date
    
    /// Who created it (user ID)
    public let createdBy: String
    
    // MARK: - Policy Settings (NO user content)
    
    /// Allow email drafts
    public let allowEmailDrafts: Bool
    
    /// Allow calendar writes
    public let allowCalendarWrites: Bool
    
    /// Allow task creation
    public let allowTaskCreation: Bool
    
    /// Allow memory writes
    public let allowMemoryWrites: Bool
    
    /// Max executions per day
    public let maxExecutionsPerDay: Int?
    
    /// Require explicit confirmation
    public let requireExplicitConfirmation: Bool
    
    /// Schema version
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Factory
    
    /// Creates a template from an OperatorPolicy
    public static func fromPolicy(
        _ policy: OperatorPolicy,
        name: String,
        description: String,
        createdBy: String
    ) -> TeamPolicyTemplate {
        TeamPolicyTemplate(
            id: UUID(),
            name: name,
            description: description,
            createdAt: Date(),
            createdBy: createdBy,
            allowEmailDrafts: policy.allowEmailDrafts,
            allowCalendarWrites: policy.allowCalendarWrites,
            allowTaskCreation: policy.allowTaskCreation,
            allowMemoryWrites: policy.allowMemoryWrites,
            maxExecutionsPerDay: policy.maxExecutionsPerDay,
            requireExplicitConfirmation: policy.requireExplicitConfirmation,
            schemaVersion: Self.currentSchemaVersion
        )
    }
    
    /// Converts to an OperatorPolicy (for applying template)
    public func toPolicy() -> OperatorPolicy {
        OperatorPolicy(
            enabled: true,
            allowEmailDrafts: allowEmailDrafts,
            allowCalendarWrites: allowCalendarWrites,
            allowTaskCreation: allowTaskCreation,
            allowMemoryWrites: allowMemoryWrites,
            maxExecutionsPerDay: maxExecutionsPerDay,
            requireExplicitConfirmation: requireExplicitConfirmation
        )
    }
}

// MARK: - Team Diagnostics Snapshot

/// Aggregated diagnostics for team visibility (no user content)
public struct TeamDiagnosticsSnapshot: Codable, Equatable {
    
    /// Unique identifier
    public let id: UUID
    
    /// When captured
    public let capturedAt: Date
    
    /// Who captured it
    public let capturedBy: String
    
    // MARK: - Aggregate Stats (NO user content)
    
    /// Total executions in period
    public let totalExecutions: Int
    
    /// Success rate (0.0 - 1.0)
    public let successRate: Double
    
    /// Fallback usage rate
    public let fallbackRate: Double
    
    /// Executions today
    public let executionsToday: Int
    
    /// Last execution outcome
    public let lastOutcome: String
    
    /// App version
    public let appVersion: String
    
    /// Build number
    public let buildNumber: String
    
    /// Schema version
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Factory
    
    /// Creates from DiagnosticsExportPacket
    public static func fromDiagnostics(
        _ packet: DiagnosticsExportPacket,
        capturedBy: String
    ) -> TeamDiagnosticsSnapshot {
        TeamDiagnosticsSnapshot(
            id: UUID(),
            capturedAt: Date(),
            capturedBy: capturedBy,
            totalExecutions: packet.execution.executionsLast7Days,
            successRate: calculateSuccessRate(from: packet.execution),
            fallbackRate: packet.execution.fallbackUsedRecently ? 0.1 : 0.0,
            executionsToday: packet.execution.executionsToday,
            lastOutcome: packet.execution.lastExecutionOutcome.rawValue,
            appVersion: packet.appVersion,
            buildNumber: packet.buildNumber,
            schemaVersion: Self.currentSchemaVersion
        )
    }
    
    private static func calculateSuccessRate(from exec: ExecutionDiagnosticsSnapshot) -> Double {
        switch exec.lastExecutionOutcome {
        case .success: return 1.0
        case .partialSuccess: return 0.7
        case .failed: return 0.0
        case .cancelled: return 0.5
        default: return 0.5
        }
    }
}

// MARK: - Team Quality Summary

/// Quality summary for team visibility (pass rates, drift only)
public struct TeamQualitySummary: Codable, Equatable {
    
    /// Unique identifier
    public let id: UUID
    
    /// When captured
    public let capturedAt: Date
    
    /// Who captured it
    public let capturedBy: String
    
    // MARK: - Quality Metrics (NO user content)
    
    /// Quality gate pass rate (0.0 - 1.0)
    public let qualityGatePassRate: Double
    
    /// Overall quality score (0 - 100)
    public let qualityScore: Int
    
    /// Coverage score (0 - 100)
    public let coverageScore: Int
    
    /// Drift level (none, low, moderate, high)
    public let driftLevel: String
    
    /// Total golden cases
    public let goldenCaseCount: Int
    
    /// Total feedback entries
    public let feedbackCount: Int
    
    /// Trend direction (improving, stable, declining)
    public let trendDirection: String
    
    /// App version
    public let appVersion: String
    
    /// Schema version
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Factory
    
    /// Creates from ExportQualityPacket
    public static func fromQualityPacket(
        _ packet: ExportQualityPacket,
        capturedBy: String
    ) -> TeamQualitySummary {
        TeamQualitySummary(
            id: UUID(),
            capturedAt: Date(),
            capturedBy: capturedBy,
            qualityGatePassRate: packet.qualityGateResult.status == "pass" ? 1.0 : 0.0,
            qualityScore: packet.coverageScore,
            coverageScore: packet.coverageScore,
            driftLevel: packet.qualityGateResult.driftLevel ?? "unknown",
            goldenCaseCount: packet.qualityGateResult.goldenCaseCount,
            feedbackCount: packet.trend.dataPoints,
            trendDirection: packet.trend.passRateDirection,
            appVersion: packet.appVersion,
            schemaVersion: Self.currentSchemaVersion
        )
    }
}

// MARK: - Team Evidence Packet Reference

/// Reference to an evidence packet (hash + timestamp only, NO content)
public struct TeamEvidencePacketRef: Codable, Equatable {
    
    /// Unique identifier
    public let id: UUID
    
    /// When captured
    public let capturedAt: Date
    
    /// Who captured it
    public let capturedBy: String
    
    // MARK: - Reference Data (NO content)
    
    /// Hash of the evidence packet
    public let packetHash: String
    
    /// Original export timestamp
    public let originalExportedAt: Date
    
    /// Evidence type
    public let evidenceType: String
    
    /// Size in bytes
    public let sizeBytes: Int
    
    /// App version
    public let appVersion: String
    
    /// Build number
    public let buildNumber: String
    
    /// Schema version
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
}

// MARK: - Team Release Acknowledgement

/// Org-level release acknowledgement
public struct TeamReleaseAcknowledgement: Codable, Equatable {
    
    /// Unique identifier
    public let id: UUID
    
    /// When acknowledged
    public let acknowledgedAt: Date
    
    /// Who acknowledged
    public let acknowledgedBy: String
    
    /// Acknowledger's role
    public let acknowledgerRole: String
    
    // MARK: - Release Info (NO content)
    
    /// Release version
    public let releaseVersion: String
    
    /// Build number
    public let buildNumber: String
    
    /// Quality gate result
    public let qualityGatePassed: Bool
    
    /// Quality score at release
    public let qualityScoreAtRelease: Int
    
    /// Coverage at release
    public let coverageAtRelease: Int
    
    /// Recommendation count at release
    public let recommendationCount: Int
    
    /// Notes (optional, limited length)
    public let notes: String?
    
    /// Schema version
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    /// Maximum notes length
    public static let maxNotesLength = 200
}

// MARK: - Export Encoding

extension TeamPolicyTemplate {
    /// Exports to JSON data
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

extension TeamDiagnosticsSnapshot {
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

extension TeamQualitySummary {
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

extension TeamEvidencePacketRef {
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

extension TeamReleaseAcknowledgement {
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}
