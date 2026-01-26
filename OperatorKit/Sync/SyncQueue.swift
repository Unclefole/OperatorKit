import Foundation

// ============================================================================
// SYNC QUEUE (Phase 10D)
//
// Local queue for packets staged for upload.
// Manual upload only - no background retries.
//
// CONSTRAINTS (ABSOLUTE):
// ✅ No background retries
// ✅ Queue is local storage only
// ✅ User must explicitly trigger upload
// ✅ All packets validated before staging
// ❌ NO automatic upload on app launch
// ❌ NO scheduled uploads
// ❌ NO background sync
//
// See: docs/SAFETY_CONTRACT.md (Section 13)
// ============================================================================

/// Manages the local queue of packets staged for sync
@MainActor
public final class SyncQueue: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = SyncQueue()
    
    // MARK: - Storage
    
    private let storageKey = "com.operatorkit.sync.queue"
    private let defaults: UserDefaults
    
    // MARK: - Published State
    
    @Published public private(set) var stagedPackets: [SyncPacket] = []
    @Published public private(set) var lastUploadResult: UploadResult?
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadQueue()
    }
    
    // MARK: - Queue Status
    
    /// Summary of staged packets
    public var summary: SyncPacketSummary {
        var byType: [SyncSafetyConfig.SyncablePacketType: Int] = [:]
        for packet in stagedPackets {
            byType[packet.packetType, default: 0] += 1
        }
        
        return SyncPacketSummary(
            totalPackets: stagedPackets.count,
            totalSizeBytes: stagedPackets.reduce(0) { $0 + $1.sizeBytes },
            packetsByType: byType
        )
    }
    
    /// Whether there are packets ready to upload
    public var hasPacketsToUpload: Bool {
        !stagedPackets.isEmpty
    }
    
    // MARK: - Stage Packet
    
    /// Stages a packet for upload after validation
    /// INVARIANT: Packet must pass validation before staging
    @discardableResult
    public func stagePacketForUpload<T: Codable>(
        _ packet: T,
        as packetType: SyncSafetyConfig.SyncablePacketType,
        exportedAt: Date
    ) throws -> SyncPacket {
        // Validate packet
        let (result, data) = SyncPacketValidator.shared.validate(packet, as: packetType)
        
        guard result.isValid, let jsonData = data else {
            throw SyncError.payloadContainsForbiddenContent(result.errors.first ?? "Unknown validation error")
        }
        
        // Extract schema version
        let schemaVersion = extractSchemaVersion(from: jsonData) ?? 1
        
        // Create sync packet
        let syncPacket = SyncPacket(
            packetType: packetType,
            jsonData: jsonData,
            schemaVersion: schemaVersion,
            originalExportedAt: exportedAt
        )
        
        // Add to queue
        stagedPackets.append(syncPacket)
        saveQueue()
        
        logDebug("Packet staged for upload: type=\(packetType.rawValue), size=\(syncPacket.sizeBytes) bytes", category: .flow)
        
        return syncPacket
    }
    
    /// Stages raw JSON data for upload
    @discardableResult
    public func stageRawPacket(
        jsonData: Data,
        packetType: SyncSafetyConfig.SyncablePacketType,
        exportedAt: Date
    ) throws -> SyncPacket {
        // Validate packet
        let result = SyncPacketValidator.shared.validate(jsonData: jsonData, packetType: packetType)
        
        guard result.isValid else {
            throw SyncError.payloadContainsForbiddenContent(result.errors.first ?? "Unknown validation error")
        }
        
        // Extract schema version
        let schemaVersion = extractSchemaVersion(from: jsonData) ?? 1
        
        // Create sync packet
        let syncPacket = SyncPacket(
            packetType: packetType,
            jsonData: jsonData,
            schemaVersion: schemaVersion,
            originalExportedAt: exportedAt
        )
        
        // Add to queue
        stagedPackets.append(syncPacket)
        saveQueue()
        
        return syncPacket
    }
    
    // MARK: - Upload
    
    /// Uploads all staged packets NOW (user-initiated)
    /// INVARIANT: This is the ONLY way to trigger uploads
    public func uploadStagedPacketsNow() async -> UploadResult {
        guard !stagedPackets.isEmpty else {
            let result = UploadResult(
                success: true,
                uploadedCount: 0,
                failedCount: 0,
                errors: []
            )
            lastUploadResult = result
            return result
        }
        
        let client = SupabaseClient.shared
        
        guard client.isConfigured else {
            let result = UploadResult(
                success: false,
                uploadedCount: 0,
                failedCount: stagedPackets.count,
                errors: ["Cloud sync is not configured"]
            )
            lastUploadResult = result
            return result
        }
        
        guard client.isSignedIn else {
            let result = UploadResult(
                success: false,
                uploadedCount: 0,
                failedCount: stagedPackets.count,
                errors: ["Please sign in to upload"]
            )
            lastUploadResult = result
            return result
        }
        
        var uploadedCount = 0
        var failedCount = 0
        var errors: [String] = []
        var uploadedIds: Set<UUID> = []
        
        for packet in stagedPackets {
            do {
                _ = try await client.uploadPacket(type: packet.packetType, jsonData: packet.jsonData)
                uploadedCount += 1
                uploadedIds.insert(packet.id)
            } catch {
                failedCount += 1
                errors.append("\(packet.packetTypeDisplayName): \(error.localizedDescription)")
            }
        }
        
        // Remove successfully uploaded packets from queue
        stagedPackets.removeAll { uploadedIds.contains($0.id) }
        saveQueue()
        
        let result = UploadResult(
            success: failedCount == 0,
            uploadedCount: uploadedCount,
            failedCount: failedCount,
            errors: errors
        )
        lastUploadResult = result
        
        logDebug("Upload complete: \(uploadedCount) uploaded, \(failedCount) failed", category: .flow)
        
        return result
    }
    
    // MARK: - Queue Management
    
    /// Removes a packet from the queue
    public func removePacket(id: UUID) {
        stagedPackets.removeAll { $0.id == id }
        saveQueue()
    }
    
    /// Clears all staged packets
    public func clearQueue() {
        stagedPackets.removeAll()
        saveQueue()
        logDebug("Sync queue cleared", category: .flow)
    }
    
    // MARK: - Persistence
    
    private func saveQueue() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(stagedPackets) {
            defaults.set(data, forKey: storageKey)
        }
    }
    
    private func loadQueue() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let packets = try? decoder.decode([SyncPacket].self, from: data) {
            stagedPackets = packets
        }
    }
    
    // MARK: - Helpers
    
    private func extractSchemaVersion(from data: Data) -> Int? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["schemaVersion"] as? Int else {
            return nil
        }
        return version
    }
}

// MARK: - Upload Result

/// Result of an upload operation
public struct UploadResult {
    public let success: Bool
    public let uploadedCount: Int
    public let failedCount: Int
    public let errors: [String]
    
    public var summaryText: String {
        if success {
            return "Successfully uploaded \(uploadedCount) packet(s)"
        } else if uploadedCount > 0 {
            return "Uploaded \(uploadedCount), failed \(failedCount)"
        } else {
            return "Upload failed: \(errors.first ?? "Unknown error")"
        }
    }
}
