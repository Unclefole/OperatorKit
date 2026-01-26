import Foundation
import CryptoKit

// ============================================================================
// STORE LISTING SNAPSHOT (Phase 10K)
//
// Hash snapshot for store listing copy drift detection.
// Tests fail if copy changes without updating hash and reason.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No prompts or drafts
// ✅ Deterministic hashing
// ✅ Change tracking with reason
// ✅ Test-enforced lockdown
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Store Listing Snapshot

public enum StoreListingSnapshot {
    
    // MARK: - Expected Hash
    
    /// Expected SHA256 hash of StoreListingCopy.concatenatedContent
    /// Update this when intentionally changing store listing copy
    public static let expectedHash = "UPDATE_ON_FIRST_RUN"
    
    /// Reason for last hash update
    public static let lastUpdateReason = "Phase 10K: Initial store listing copy"
    
    /// When hash was last updated
    public static let lastUpdatePhase = "10K"
    
    /// Schema version
    public static let schemaVersion = 1
    
    // MARK: - Hash Calculation
    
    /// Calculates SHA256 hash of store listing content
    public static func calculateCurrentHash() -> String {
        let content = StoreListingCopy.concatenatedContent
        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Verifies current content matches expected hash
    public static func verifyHash() -> StoreListingHashResult {
        let currentHash = calculateCurrentHash()
        
        // Special case: first run with placeholder hash
        if expectedHash == "UPDATE_ON_FIRST_RUN" {
            return StoreListingHashResult(
                isValid: false,
                currentHash: currentHash,
                expectedHash: expectedHash,
                message: "Expected hash needs to be set to: \(currentHash)"
            )
        }
        
        let matches = currentHash == expectedHash
        
        return StoreListingHashResult(
            isValid: matches,
            currentHash: currentHash,
            expectedHash: expectedHash,
            message: matches ? "Hash matches" : "Store listing copy has changed without updating hash"
        )
    }
    
    // MARK: - Snapshot Export
    
    /// Creates exportable snapshot
    public static func createSnapshot() -> StoreListingSnapshotData {
        return StoreListingSnapshotData(
            schemaVersion: schemaVersion,
            createdAt: dayRoundedDate(),
            currentHash: calculateCurrentHash(),
            expectedHash: expectedHash,
            lastUpdateReason: lastUpdateReason,
            lastUpdatePhase: lastUpdatePhase,
            isValid: verifyHash().isValid,
            copyLengths: CopyLengths(
                title: StoreListingCopy.title.count,
                subtitle: StoreListingCopy.subtitle.count,
                description: StoreListingCopy.description.count,
                keywords: StoreListingCopy.keywords.count,
                promotional: StoreListingCopy.promotionalText.count
            )
        )
    }
    
    private static func dayRoundedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}

// MARK: - Hash Result

public struct StoreListingHashResult {
    public let isValid: Bool
    public let currentHash: String
    public let expectedHash: String
    public let message: String
}

// MARK: - Snapshot Data

public struct StoreListingSnapshotData: Codable {
    public let schemaVersion: Int
    public let createdAt: String
    public let currentHash: String
    public let expectedHash: String
    public let lastUpdateReason: String
    public let lastUpdatePhase: String
    public let isValid: Bool
    public let copyLengths: CopyLengths
    
    public struct CopyLengths: Codable {
        public let title: Int
        public let subtitle: Int
        public let description: Int
        public let keywords: Int
        public let promotional: Int
    }
}
