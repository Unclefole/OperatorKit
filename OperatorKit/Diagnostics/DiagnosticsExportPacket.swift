import Foundation
import CryptoKit

// ============================================================================
// DIAGNOSTICS EXPORT PACKET (Phase 10B)
//
// Exportable diagnostics bundle for operator/developer review.
// JSON export via ShareSheet, user-initiated only.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking
// ❌ No user content
// ❌ No identifiers beyond app/build
// ✅ User-initiated only
// ✅ Content-free
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

// MARK: - Diagnostics Export Packet

/// Complete diagnostics export for operator review
public struct DiagnosticsExportPacket: Codable, Equatable {
    
    /// When this packet was exported
    public let exportedAt: Date
    
    /// App version
    public let appVersion: String
    
    /// Build number
    public let buildNumber: String
    
    /// iOS version
    public let iosVersion: String
    
    /// Device model (generic, e.g., "iPhone")
    public let deviceModel: String
    
    /// Execution diagnostics snapshot
    public let execution: ExecutionDiagnosticsSnapshot
    
    /// Usage diagnostics snapshot
    public let usage: UsageDiagnosticsSnapshot
    
    /// Whether all invariants are currently passing
    public let invariantsPassing: Bool
    
    /// Hash of safety contract (for verification)
    public let safetyContractHash: String
    
    /// Schema version for migration
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Initialization
    
    public init(
        exportedAt: Date = Date(),
        appVersion: String,
        buildNumber: String,
        iosVersion: String,
        deviceModel: String,
        execution: ExecutionDiagnosticsSnapshot,
        usage: UsageDiagnosticsSnapshot,
        invariantsPassing: Bool,
        safetyContractHash: String
    ) {
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.iosVersion = iosVersion
        self.deviceModel = deviceModel
        self.execution = execution
        self.usage = usage
        self.invariantsPassing = invariantsPassing
        self.safetyContractHash = safetyContractHash
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    // MARK: - JSON Export
    
    /// Exports the packet as JSON data
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    
    /// Exports the packet as a JSON string
    public func exportJSONString() throws -> String {
        let data = try exportJSON()
        guard let string = String(data: data, encoding: .utf8) else {
            throw DiagnosticsExportError.encodingFailed
        }
        return string
    }
    
    /// Exports to a temporary file and returns the URL
    public func exportToFile() throws -> URL {
        let data = try exportJSON()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: exportedAt)
        let filename = "OperatorKit_Diagnostics_\(timestamp).json"
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        try data.write(to: fileURL)
        return fileURL
    }
}

// MARK: - Export Error

public enum DiagnosticsExportError: Error, LocalizedError {
    case encodingFailed
    case fileWriteFailed
    
    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Could not encode diagnostics."
        case .fileWriteFailed:
            return "Could not write diagnostics file."
        }
    }
}

// MARK: - Diagnostics Export Builder

/// Builds a complete diagnostics export packet
public final class DiagnosticsExportBuilder {
    
    // MARK: - Dependencies
    
    private let executionCollector: ExecutionDiagnosticsCollector
    private let usageCollector: UsageDiagnosticsCollector
    
    // MARK: - Initialization
    
    public init(
        executionCollector: ExecutionDiagnosticsCollector = ExecutionDiagnosticsCollector(),
        usageCollector: UsageDiagnosticsCollector = UsageDiagnosticsCollector()
    ) {
        self.executionCollector = executionCollector
        self.usageCollector = usageCollector
    }
    
    // MARK: - Build Packet
    
    /// Builds a complete diagnostics export packet
    /// INVARIANT: Read-only, does not modify any state
    @MainActor
    public func buildPacket() -> DiagnosticsExportPacket {
        let now = Date()
        
        // Capture snapshots
        let executionSnapshot = executionCollector.captureSnapshot()
        let usageSnapshot = usageCollector.captureSnapshot()
        
        // Get app info
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        // Get device info (generic, no identifiers)
        let iosVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model // Generic: "iPhone", "iPad"
        
        // Check invariants
        let invariantsPassing = checkInvariantsPassing()
        
        // Compute safety contract hash
        let safetyContractHash = computeSafetyContractHash()
        
        return DiagnosticsExportPacket(
            exportedAt: now,
            appVersion: appVersion,
            buildNumber: buildNumber,
            iosVersion: iosVersion,
            deviceModel: deviceModel,
            execution: executionSnapshot,
            usage: usageSnapshot,
            invariantsPassing: invariantsPassing,
            safetyContractHash: safetyContractHash
        )
    }
    
    // MARK: - Helpers
    
    /// Checks if invariants are passing
    private func checkInvariantsPassing() -> Bool {
        // Use InvariantCheckRunner if available
        let result = InvariantCheckRunner.shared.runAllChecks()
        return result.overallStatus == .allPassing
    }
    
    /// Computes hash of safety contract (simplified)
    private func computeSafetyContractHash() -> String {
        // Hash of key safety settings
        let safetyString = [
            "networkEntitlementsEnabled:false",
            "backgroundModesEnabled:false",
            "analyticsEnabled:false",
            "telemetryEnabled:false",
            "deterministicFallbackRequired:true"
        ].joined(separator: "|")
        
        let data = Data(safetyString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }
}

// MARK: - UIKit Import for Device Info

#if canImport(UIKit)
import UIKit
#endif
