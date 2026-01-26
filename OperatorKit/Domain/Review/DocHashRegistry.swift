import Foundation
import CryptoKit

// ============================================================================
// DOC HASH REGISTRY (Phase 9D)
//
// Hashes governance documents for tamper-evident documentation.
// Advisory only — does not enforce or block anything.
//
// Documents hashed:
// - SAFETY_CONTRACT.md
// - CLAIM_REGISTRY.md
// - EXECUTION_GUARANTEES.md
// - APP_REVIEW_PACKET.md
// - PHASE_BOUNDARIES.md
//
// CONSTRAINTS:
// ❌ No enforcement behavior
// ❌ No failure states that block export
// ✅ Advisory only
// ✅ If file missing, mark unavailable
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Registry for computing hashes of governance documents
public final class DocHashRegistry {
    
    public static let shared = DocHashRegistry()
    
    /// Document names that are hashed
    public static let documentNames = [
        "SAFETY_CONTRACT.md",
        "CLAIM_REGISTRY.md",
        "EXECUTION_GUARANTEES.md",
        "APP_REVIEW_PACKET.md",
        "PHASE_BOUNDARIES.md"
    ]
    
    private init() {}
    
    // MARK: - Hash Computation
    
    /// Computes SHA-256 hash of a document
    /// - Returns: Hex-encoded hash, or nil if file not found
    public func hashDocument(_ filename: String) -> String? {
        guard let fileURL = locateDocument(filename) else {
            return nil
        }
        
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Computes all document hashes
    public func computeAllHashes() -> DocHashesExport {
        let safetyHash = hashDocument("SAFETY_CONTRACT.md")
        let claimHash = hashDocument("CLAIM_REGISTRY.md")
        let executionHash = hashDocument("EXECUTION_GUARANTEES.md")
        let appReviewHash = hashDocument("APP_REVIEW_PACKET.md")
        let phaseHash = hashDocument("PHASE_BOUNDARIES.md")
        
        // Determine status
        let allHashes = [safetyHash, claimHash, executionHash, appReviewHash, phaseHash]
        let availableCount = allHashes.compactMap { $0 }.count
        
        let status: String
        if availableCount == allHashes.count {
            status = "all_available"
        } else if availableCount > 0 {
            status = "partial"
        } else {
            status = "unavailable"
        }
        
        return DocHashesExport(
            safetyContractHash: safetyHash,
            claimRegistryHash: claimHash,
            executionGuaranteesHash: executionHash,
            appReviewPacketHash: appReviewHash,
            phaseBoundariesHash: phaseHash,
            status: status
        )
    }
    
    /// Gets hash status for a specific document
    public func getHashStatus(_ filename: String) -> DocHashStatus {
        if let hash = hashDocument(filename) {
            return DocHashStatus(filename: filename, hash: hash, available: true)
        } else {
            return DocHashStatus(filename: filename, hash: nil, available: false)
        }
    }
    
    /// Gets all hash statuses
    public func getAllHashStatuses() -> [DocHashStatus] {
        Self.documentNames.map { getHashStatus($0) }
    }
    
    // MARK: - File Location
    
    /// Locates a document in the project
    private func locateDocument(_ filename: String) -> URL? {
        // Remove .md extension for bundle resource lookup
        let resourceName = filename.replacingOccurrences(of: ".md", with: "")
        
        // Try bundle resources first (for tests)
        if let bundlePath = Bundle.main.path(forResource: resourceName, ofType: "md") {
            return URL(fileURLWithPath: bundlePath)
        }
        
        // Try relative paths for development
        let possiblePaths = [
            "docs/\(filename)",
            "../docs/\(filename)",
            "../../docs/\(filename)",
            "../../../docs/\(filename)"
        ]
        
        let fileManager = FileManager.default
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

// MARK: - Hash Status

/// Status of a document hash
public struct DocHashStatus: Codable {
    public let filename: String
    public let hash: String?
    public let available: Bool
    
    public var displayStatus: String {
        available ? "Available" : "Not Found"
    }
    
    public var shortHash: String? {
        hash.map { String($0.prefix(16)) + "..." }
    }
}

// MARK: - Convenience

extension DocHashRegistry {
    
    /// Quick check if all documents are available
    public var allDocumentsAvailable: Bool {
        getAllHashStatuses().allSatisfy { $0.available }
    }
    
    /// Count of available documents
    public var availableDocumentCount: Int {
        getAllHashStatuses().filter { $0.available }.count
    }
    
    /// Total document count
    public var totalDocumentCount: Int {
        Self.documentNames.count
    }
}
