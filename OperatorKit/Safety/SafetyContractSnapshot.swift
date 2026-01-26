import Foundation
import CryptoKit

// ============================================================================
// SAFETY CONTRACT SNAPSHOT (Phase 8C)
//
// Captures a canonical fingerprint of docs/SAFETY_CONTRACT.md
// to detect unintentional safety guarantee drift.
//
// INVARIANT: Any safety guarantee change must:
//   1. Update the expected hash
//   2. Update documentation
//   3. Pass review process
//
// This creates intentional friction to prevent silent drift.
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Safety contract snapshot for detecting unintentional drift
public struct SafetyContractSnapshot {
    
    // =========================================================================
    // EXPECTED HASH
    //
    // This hash MUST be updated whenever SAFETY_CONTRACT.md is intentionally
    // modified. The update process:
    //
    // 1. Make changes to docs/SAFETY_CONTRACT.md
    // 2. Run SafetyContractDiffTests - it will fail
    // 3. Copy the "current hash" from the test output
    // 4. Update expectedHash below
    // 5. Document the change in SAFETY_CONTRACT.md changelog
    // 6. Run tests again - should pass
    //
    // This friction is intentional and ensures all safety changes are deliberate.
    // =========================================================================
    
    /// Expected SHA-256 hash of SAFETY_CONTRACT.md
    /// Last updated: Phase 8B (added Golden Cases guarantee #12)
    public static let expectedHash = "PENDING_INITIAL_HASH"
    
    /// Schema version for the snapshot mechanism itself
    public static let schemaVersion = 1
    
    /// Last known update reason
    public static let lastUpdateReason = "Phase 8B: Added Golden Cases (Guarantee #12)"
    
    // MARK: - Hash Computation
    
    /// Computes the current SHA-256 hash of SAFETY_CONTRACT.md
    /// - Returns: Hex-encoded SHA-256 hash, or nil if file not found
    public static func currentHash() -> String? {
        guard let fileURL = locateSafetyContract() else {
            logWarning("SAFETY_CONTRACT.md not found", category: .safety)
            return nil
        }
        
        guard let data = try? Data(contentsOf: fileURL) else {
            logError("Failed to read SAFETY_CONTRACT.md", category: .safety)
            return nil
        }
        
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Checks if the safety contract is unchanged from expected
    /// - Returns: true if unchanged, false if modified or not found
    public static func isUnchanged() -> Bool {
        guard let current = currentHash() else {
            return false
        }
        return current == expectedHash
    }
    
    /// Gets detailed status of the safety contract
    public static func getStatus() -> SafetyContractStatus {
        guard let current = currentHash() else {
            return SafetyContractStatus(
                isValid: false,
                currentHash: nil,
                expectedHash: expectedHash,
                matchStatus: .notFound,
                lastUpdateReason: lastUpdateReason
            )
        }
        
        let matches = current == expectedHash
        return SafetyContractStatus(
            isValid: matches,
            currentHash: current,
            expectedHash: expectedHash,
            matchStatus: matches ? .matched : .modified,
            lastUpdateReason: lastUpdateReason
        )
    }
    
    // MARK: - File Location
    
    /// Locates SAFETY_CONTRACT.md in the project
    private static func locateSafetyContract() -> URL? {
        // Try bundle resources first (for tests)
        if let bundlePath = Bundle.main.path(forResource: "SAFETY_CONTRACT", ofType: "md") {
            return URL(fileURLWithPath: bundlePath)
        }
        
        // Try relative paths for development
        let possiblePaths = [
            "docs/SAFETY_CONTRACT.md",
            "../docs/SAFETY_CONTRACT.md",
            "../../docs/SAFETY_CONTRACT.md",
            "../../../docs/SAFETY_CONTRACT.md"
        ]
        
        let fileManager = FileManager.default
        
        // Get current directory
        let currentDir = fileManager.currentDirectoryPath
        
        for relativePath in possiblePaths {
            let fullPath = (currentDir as NSString).appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: fullPath) {
                return URL(fileURLWithPath: fullPath)
            }
        }
        
        // Try from the app bundle location
        if let bundleURL = Bundle.main.bundleURL.deletingLastPathComponent() as URL? {
            for relativePath in possiblePaths {
                let fullURL = bundleURL.appendingPathComponent(relativePath)
                if fileManager.fileExists(atPath: fullURL.path) {
                    return fullURL
                }
            }
        }
        
        return nil
    }
}

// MARK: - Status Types

/// Detailed status of the safety contract
public struct SafetyContractStatus {
    public let isValid: Bool
    public let currentHash: String?
    public let expectedHash: String
    public let matchStatus: MatchStatus
    public let lastUpdateReason: String
    
    public enum MatchStatus: String {
        case matched = "Matched"
        case modified = "Modified"
        case notFound = "Not Found"
        
        public var displayName: String { rawValue }
        
        public var systemImage: String {
            switch self {
            case .matched: return "checkmark.shield.fill"
            case .modified: return "exclamationmark.shield.fill"
            case .notFound: return "questionmark.diamond.fill"
            }
        }
    }
}

// MARK: - Export Format

/// Export format for safety contract status
public struct SafetyContractExport: Codable {
    public let schemaVersion: Int
    public let exportedAt: Date
    public let appVersion: String?
    public let expectedHash: String
    public let currentHash: String?
    public let isUnchanged: Bool
    public let matchStatus: String
    public let lastUpdateReason: String
    
    public init() {
        let status = SafetyContractSnapshot.getStatus()
        self.schemaVersion = SafetyContractSnapshot.schemaVersion
        self.exportedAt = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        self.expectedHash = status.expectedHash
        self.currentHash = status.currentHash
        self.isUnchanged = status.isValid
        self.matchStatus = status.matchStatus.rawValue
        self.lastUpdateReason = status.lastUpdateReason
    }
    
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
