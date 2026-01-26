import Foundation

// ============================================================================
// SYNC PACKET (Phase 10D)
//
// Wrapper for syncable packets with metadata.
// Only metadata-only packets can be synced.
//
// SYNCABLE PACKET TYPES (metadata only):
// ✅ ExportQualityPacket - quality metrics
// ✅ DiagnosticsExportPacket - diagnostics snapshot
// ✅ PolicyExportPacket - policy settings
// ✅ ReleaseAcknowledgement - release sign-off
// ✅ EvidencePacket - integrity evidence
//
// NEVER SYNCABLE (user content):
// ❌ Drafts (email, reminder, calendar)
// ❌ Memory items
// ❌ User inputs / prompts
// ❌ Context packets
//
// See: docs/SAFETY_CONTRACT.md (Section 13)
// ============================================================================

// MARK: - Sync Packet Wrapper

/// Wrapper for a packet staged for sync
public struct SyncPacket: Identifiable, Codable {
    
    /// Unique identifier
    public let id: UUID
    
    /// When the packet was staged
    public let stagedAt: Date
    
    /// Type of packet
    public let packetType: SyncSafetyConfig.SyncablePacketType
    
    /// JSON data (pre-validated)
    public let jsonData: Data
    
    /// Size in bytes
    public var sizeBytes: Int { jsonData.count }
    
    /// Schema version extracted from packet
    public let schemaVersion: Int
    
    /// When the original packet was exported
    public let originalExportedAt: Date
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        stagedAt: Date = Date(),
        packetType: SyncSafetyConfig.SyncablePacketType,
        jsonData: Data,
        schemaVersion: Int,
        originalExportedAt: Date
    ) {
        self.id = id
        self.stagedAt = stagedAt
        self.packetType = packetType
        self.jsonData = jsonData
        self.schemaVersion = schemaVersion
        self.originalExportedAt = originalExportedAt
    }
    
    // MARK: - Display Helpers
    
    /// Formatted size
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }
    
    /// Display name for packet type
    public var packetTypeDisplayName: String {
        switch packetType {
        case .qualityExport: return "Quality Export"
        case .diagnosticsExport: return "Diagnostics Export"
        case .policyExport: return "Policy Export"
        case .releaseAcknowledgement: return "Release Acknowledgement"
        case .evidencePacket: return "Evidence Packet"
        }
    }
}

// MARK: - Sync Packet Summary

/// Summary of staged packets for display
public struct SyncPacketSummary {
    public let totalPackets: Int
    public let totalSizeBytes: Int
    public let packetsByType: [SyncSafetyConfig.SyncablePacketType: Int]
    
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSizeBytes), countStyle: .file)
    }
    
    public var isEmpty: Bool {
        totalPackets == 0
    }
}

// MARK: - Validation Result

/// Result of packet validation
public struct SyncPacketValidationResult {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    
    public static func valid() -> SyncPacketValidationResult {
        SyncPacketValidationResult(isValid: true, errors: [], warnings: [])
    }
    
    public static func invalid(errors: [String], warnings: [String] = []) -> SyncPacketValidationResult {
        SyncPacketValidationResult(isValid: false, errors: errors, warnings: warnings)
    }
}
