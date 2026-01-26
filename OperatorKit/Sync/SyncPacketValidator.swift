import Foundation

// ============================================================================
// SYNC PACKET VALIDATOR (Phase 10D)
//
// Content-free enforcer. Validates packets before sync to ensure
// they contain ONLY metadata, no user content.
//
// VALIDATION RULES (FAIL CLOSED):
// 1. Reject if JSON contains forbidden keys
// 2. Reject if payload exceeds size limit
// 3. Require schemaVersion + exportedAt present
// 4. If uncertain → BLOCK and explain why
//
// See: docs/SAFETY_CONTRACT.md (Section 13)
// ============================================================================

/// Validates packets for sync safety
public final class SyncPacketValidator {
    
    // MARK: - Singleton
    
    public static let shared = SyncPacketValidator()
    
    private init() {}
    
    // MARK: - Validation
    
    /// Validates a packet for sync
    /// INVARIANT: Fail closed - if uncertain, block
    public func validate(
        jsonData: Data,
        packetType: SyncSafetyConfig.SyncablePacketType
    ) -> SyncPacketValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // 1. Check size limit
        if jsonData.count > SyncSafetyConfig.maxPayloadSizeBytes {
            errors.append("Payload size (\(jsonData.count) bytes) exceeds limit (\(SyncSafetyConfig.maxPayloadSizeBytes) bytes)")
        }
        
        // 2. Parse JSON
        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            errors.append("Invalid JSON format")
            return .invalid(errors: errors, warnings: warnings)
        }
        
        // 3. Check for forbidden content keys
        let forbiddenKeysFound = findForbiddenKeys(in: jsonDict)
        if !forbiddenKeysFound.isEmpty {
            for key in forbiddenKeysFound {
                errors.append("Forbidden content key found: \"\(key)\"")
            }
        }
        
        // 4. Check required metadata keys
        for requiredKey in SyncSafetyConfig.requiredMetadataKeys {
            if !containsKey(requiredKey, in: jsonDict) {
                errors.append("Missing required metadata key: \"\(requiredKey)\"")
            }
        }
        
        // 5. Verify packet type matches expected schema
        if let schemaVersion = jsonDict["schemaVersion"] as? Int {
            if schemaVersion < 1 {
                warnings.append("Schema version is less than 1")
            }
        }
        
        // 6. Fail closed: if we have any errors, reject
        if errors.isEmpty {
            return .valid()
        } else {
            return .invalid(errors: errors, warnings: warnings)
        }
    }
    
    /// Validates a Codable packet
    public func validate<T: Codable>(
        _ packet: T,
        as packetType: SyncSafetyConfig.SyncablePacketType
    ) -> (result: SyncPacketValidationResult, data: Data?) {
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        
        guard let data = try? encoder.encode(packet) else {
            return (.invalid(errors: ["Failed to encode packet"]), nil)
        }
        
        let result = validate(jsonData: data, packetType: packetType)
        return (result, result.isValid ? data : nil)
    }
    
    // MARK: - Helpers
    
    /// Recursively finds forbidden keys in a JSON dictionary
    private func findForbiddenKeys(in dict: [String: Any], parentKey: String = "") -> [String] {
        var found: [String] = []
        
        for (key, value) in dict {
            let fullKey = parentKey.isEmpty ? key : "\(parentKey).\(key)"
            
            // Check if this key is forbidden
            if SyncSafetyConfig.forbiddenContentKeys.contains(key.lowercased()) {
                found.append(fullKey)
            }
            
            // Recursively check nested objects
            if let nested = value as? [String: Any] {
                found.append(contentsOf: findForbiddenKeys(in: nested, parentKey: fullKey))
            }
            
            // Check arrays of objects
            if let array = value as? [[String: Any]] {
                for (index, item) in array.enumerated() {
                    found.append(contentsOf: findForbiddenKeys(in: item, parentKey: "\(fullKey)[\(index)]"))
                }
            }
        }
        
        return found
    }
    
    /// Checks if a key exists anywhere in the JSON structure
    private func containsKey(_ key: String, in dict: [String: Any]) -> Bool {
        if dict[key] != nil {
            return true
        }
        
        for value in dict.values {
            if let nested = value as? [String: Any] {
                if containsKey(key, in: nested) {
                    return true
                }
            }
        }
        
        return false
    }
}

// MARK: - Packet Type Validation

extension SyncPacketValidator {
    
    /// Validates an ExportQualityPacket
    public func validateQualityPacket(_ packet: ExportQualityPacket) -> (SyncPacketValidationResult, Data?) {
        validate(packet, as: .qualityExport)
    }
    
    /// Validates a DiagnosticsExportPacket
    public func validateDiagnosticsPacket(_ packet: DiagnosticsExportPacket) -> (SyncPacketValidationResult, Data?) {
        validate(packet, as: .diagnosticsExport)
    }
    
    /// Validates a PolicyExportPacket
    public func validatePolicyPacket(_ packet: PolicyExportPacket) -> (SyncPacketValidationResult, Data?) {
        validate(packet, as: .policyExport)
    }
}

// MARK: - Pre-Flight Check

extension SyncPacketValidator {
    
    /// Pre-flight check before upload
    /// Returns human-readable summary of what will be uploaded
    public func preFlightCheck(packets: [SyncPacket]) -> PreFlightReport {
        var totalSize = 0
        var packetSummaries: [String] = []
        var issues: [String] = []
        
        for packet in packets {
            totalSize += packet.sizeBytes
            packetSummaries.append("• \(packet.packetTypeDisplayName) (\(packet.formattedSize), schema v\(packet.schemaVersion))")
            
            // Re-validate each packet
            let result = validate(jsonData: packet.jsonData, packetType: packet.packetType)
            if !result.isValid {
                issues.append(contentsOf: result.errors.map { "\(packet.packetTypeDisplayName): \($0)" })
            }
        }
        
        return PreFlightReport(
            packetCount: packets.count,
            totalSizeBytes: totalSize,
            packetSummaries: packetSummaries,
            issues: issues,
            canProceed: issues.isEmpty
        )
    }
}

// MARK: - Pre-Flight Report

/// Report shown to user before upload
public struct PreFlightReport {
    public let packetCount: Int
    public let totalSizeBytes: Int
    public let packetSummaries: [String]
    public let issues: [String]
    public let canProceed: Bool
    
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSizeBytes), countStyle: .file)
    }
    
    public var summaryText: String {
        if canProceed {
            return "\(packetCount) packet(s), \(formattedTotalSize) total"
        } else {
            return "Cannot upload: \(issues.count) issue(s) found"
        }
    }
}
