import Foundation
import CryptoKit

// ============================================================================
// INTEGRITY SEAL (Phase 9C)
//
// Cryptographic-grade integrity signals for quality records.
// Provides tamper-evident, verifiable, and externally auditable records.
//
// IMPORTANT: This is INTEGRITY ONLY, not security.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No blocking, gating, or enforcement
// ❌ No networking, cloud, or background tasks
// ❌ No cryptographic key management
// ❌ No user content storage or hashing
// ❌ No security claims ("secure", "protected", "encrypted")
// ✅ Metadata-only
// ✅ Advisory / informational only
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

// MARK: - Integrity Seal

/// Content-free integrity structure that proves consistency, not secrecy.
///
/// The seal is computed over canonical JSON encoding of quality metadata only:
/// - QualitySignature
/// - SafetyContractSnapshot status
/// - QualityGateResult
/// - CoverageSummary
/// - QualityTrendSummary
///
/// NEVER hashes: user content, raw eval case data, draft text
public struct IntegritySeal: Codable, Equatable {
    
    /// Hash algorithm used (always "sha256")
    public let algorithm: String
    
    /// When the seal was created
    public let sealedAt: Date
    
    /// Names of sections included in the hash
    public let inputsHashed: [String]
    
    /// Hex-encoded SHA-256 digest
    public let digest: String
    
    /// Schema version for migration
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Initialization
    
    public init(
        algorithm: String = "sha256",
        sealedAt: Date = Date(),
        inputsHashed: [String],
        digest: String
    ) {
        self.algorithm = algorithm
        self.sealedAt = sealedAt
        self.inputsHashed = inputsHashed
        self.digest = digest
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    /// Creates an "unavailable" seal when sealing fails
    public static func unavailable(reason: String) -> IntegritySeal {
        IntegritySeal(
            algorithm: "sha256",
            sealedAt: Date(),
            inputsHashed: [],
            digest: "unavailable:\(reason)"
        )
    }
    
    /// Whether this seal is valid (not marked unavailable)
    public var isAvailable: Bool {
        !digest.hasPrefix("unavailable:")
    }
}

// MARK: - Integrity Status

/// Status of integrity verification (read-only)
/// ❌ No throwing
/// ❌ No blocking
/// ❌ No UI side effects
public enum IntegrityStatus: String, Codable {
    case valid = "Verified"
    case mismatch = "Mismatch"
    case unavailable = "Not Available"
    
    public var displayText: String {
        "Integrity: \(rawValue)"
    }
    
    public var systemImage: String {
        switch self {
        case .valid: return "checkmark.seal"
        case .mismatch: return "exclamationmark.triangle"
        case .unavailable: return "questionmark.circle"
        }
    }
    
    public var colorName: String {
        switch self {
        case .valid: return "green"
        case .mismatch: return "orange"
        case .unavailable: return "gray"
        }
    }
}

// MARK: - Sealable Input

/// Protocol for types that can be included in integrity seal computation
protocol IntegritySealable {
    /// Returns canonical JSON data for hashing (deterministic ordering)
    func canonicalJSONForSeal() throws -> Data
    
    /// Name of this input for inputsHashed array
    static var sealInputName: String { get }
}

// MARK: - Integrity Seal Factory

/// Factory for creating integrity seals from quality metadata
///
/// INVARIANT: Only hashes metadata, never user content
/// INVARIANT: Seal creation is synchronous
/// INVARIANT: Deterministic ordering required
/// INVARIANT: Failure to seal → export still succeeds, seal marked "unavailable"
public final class IntegritySealFactory {
    
    /// Sections that are always included in the seal
    public static let standardInputNames = [
        "QualitySignature",
        "SafetyContractStatus",
        "QualityGateResult",
        "CoverageSummary",
        "QualityTrendSummary"
    ]
    
    public init() {}
    
    /// Creates an integrity seal from quality packet components
    ///
    /// - Parameters:
    ///   - signature: Quality signature (metadata)
    ///   - safetyStatus: Safety contract status (metadata)
    ///   - gateResult: Quality gate result (metadata)
    ///   - coverageScore: Overall coverage score
    ///   - trend: Quality trend export (metadata)
    /// - Returns: IntegritySeal, or unavailable seal on failure
    public func createSeal(
        signature: QualitySignature?,
        safetyStatus: EvalSafetyContractExport,
        gateResult: EvalQualityGateExport,
        coverageScore: Int,
        trend: QualityTrendExport
    ) -> IntegritySeal {
        do {
            // Build canonical input for hashing
            let canonicalInput = try buildCanonicalInput(
                signature: signature,
                safetyStatus: safetyStatus,
                gateResult: gateResult,
                coverageScore: coverageScore,
                trend: trend
            )
            
            // Compute SHA-256 hash
            let hash = SHA256.hash(data: canonicalInput)
            let digest = hash.compactMap { String(format: "%02x", $0) }.joined()
            
            return IntegritySeal(
                inputsHashed: Self.standardInputNames,
                digest: digest
            )
        } catch {
            // Failure to seal → export still succeeds, seal marked "unavailable"
            return IntegritySeal.unavailable(reason: "encoding_failed")
        }
    }
    
    // MARK: - Canonical Input Building
    
    /// Builds deterministically-ordered canonical JSON for hashing
    private func buildCanonicalInput(
        signature: QualitySignature?,
        safetyStatus: EvalSafetyContractExport,
        gateResult: EvalQualityGateExport,
        coverageScore: Int,
        trend: QualityTrendExport
    ) throws -> Data {
        // Create a canonical structure with deterministic ordering
        let canonical = CanonicalSealInput(
            qualitySignature: signature.map { CanonicalQualitySignature(from: $0) },
            safetyContractStatus: CanonicalSafetyStatus(from: safetyStatus),
            qualityGateResult: CanonicalGateResult(from: gateResult),
            coverageScore: coverageScore,
            trendSummary: CanonicalTrendSummary(from: trend)
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]  // Deterministic ordering
        encoder.dateEncodingStrategy = .iso8601
        
        return try encoder.encode(canonical)
    }
}

// MARK: - Canonical Structures (Internal)

/// Canonical wrapper for seal input (ensures deterministic encoding)
private struct CanonicalSealInput: Codable {
    let qualitySignature: CanonicalQualitySignature?
    let safetyContractStatus: CanonicalSafetyStatus
    let qualityGateResult: CanonicalGateResult
    let coverageScore: Int
    let trendSummary: CanonicalTrendSummary
}

/// Canonical quality signature (selected fields only)
private struct CanonicalQualitySignature: Codable {
    let appVersion: String
    let buildNumber: String
    let releaseMode: String
    let safetyContractHash: String
    let qualityGateConfigVersion: Int
    let deterministicModelVersion: String
    
    init(from signature: QualitySignature) {
        self.appVersion = signature.appVersion
        self.buildNumber = signature.buildNumber
        self.releaseMode = signature.releaseMode
        self.safetyContractHash = signature.safetyContractHash
        self.qualityGateConfigVersion = signature.qualityGateConfigVersion
        self.deterministicModelVersion = signature.deterministicModelVersion
    }
}

/// Canonical safety status
private struct CanonicalSafetyStatus: Codable {
    let currentHash: String
    let expectedHash: String
    let isUnchanged: Bool
    
    init(from export: EvalSafetyContractExport) {
        self.currentHash = export.currentHash
        self.expectedHash = export.expectedHash
        self.isUnchanged = export.isUnchanged
    }
}

/// Canonical gate result
private struct CanonicalGateResult: Codable {
    let status: String
    let goldenCaseCount: Int
    let latestPassRate: Double?
    let driftLevel: String?
    
    init(from export: EvalQualityGateExport) {
        self.status = export.status
        self.goldenCaseCount = export.goldenCaseCount
        self.latestPassRate = export.latestPassRate
        self.driftLevel = export.driftLevel
    }
}

/// Canonical trend summary
private struct CanonicalTrendSummary: Codable {
    let passRateDirection: String
    let driftDirection: String
    let averagePassRate: Double
    let dataPoints: Int
    
    init(from export: QualityTrendExport) {
        self.passRateDirection = export.passRateDirection
        self.driftDirection = export.driftDirection
        self.averagePassRate = export.averagePassRate
        self.dataPoints = export.dataPoints
    }
}

// MARK: - Integrity Verifier

/// Read-only verifier for integrity seals
///
/// INVARIANT: Recomputes digest and compares to stored seal
/// INVARIANT: Returns status only
/// ❌ No throwing
/// ❌ No blocking
/// ❌ No UI side effects
public final class IntegrityVerifier {
    
    private let factory = IntegritySealFactory()
    
    public init() {}
    
    /// Verifies an integrity seal by recomputing the digest
    ///
    /// - Parameters:
    ///   - seal: The integrity seal to verify
    ///   - signature: Quality signature used in original seal
    ///   - safetyStatus: Safety contract status used in original seal
    ///   - gateResult: Quality gate result used in original seal
    ///   - coverageScore: Coverage score used in original seal
    ///   - trend: Trend summary used in original seal
    /// - Returns: IntegrityStatus indicating verification result
    public func verify(
        seal: IntegritySeal,
        signature: QualitySignature?,
        safetyStatus: EvalSafetyContractExport,
        gateResult: EvalQualityGateExport,
        coverageScore: Int,
        trend: QualityTrendExport
    ) -> IntegrityStatus {
        // Check if seal is available
        guard seal.isAvailable else {
            return .unavailable
        }
        
        // Recompute the seal
        let recomputedSeal = factory.createSeal(
            signature: signature,
            safetyStatus: safetyStatus,
            gateResult: gateResult,
            coverageScore: coverageScore,
            trend: trend
        )
        
        // Check if recomputation succeeded
        guard recomputedSeal.isAvailable else {
            return .unavailable
        }
        
        // Compare digests
        if seal.digest == recomputedSeal.digest {
            return .valid
        } else {
            return .mismatch
        }
    }
    
    /// Simplified verification using a quality packet
    public func verify(packet: ExportQualityPacket) -> IntegrityStatus {
        guard let seal = packet.integritySeal else {
            return .unavailable
        }
        
        return verify(
            seal: seal,
            signature: packet.qualitySignature,
            safetyStatus: packet.safetyContractStatus,
            gateResult: packet.qualityGateResult,
            coverageScore: packet.coverageScore,
            trend: packet.trend
        )
    }
}

// MARK: - Eval Run Lineage

/// Optional lineage metadata for chronological linking of eval runs
///
/// Allows chronological linking without:
/// ❌ Branching logic
/// ❌ Enforcement
/// ❌ Execution reference
public struct EvalRunLineage: Codable, Equatable {
    
    /// ID of the previous eval run (if any)
    public let previousRunId: UUID?
    
    /// Hash of the quality signature at time of run
    public let qualitySignatureHash: String
    
    /// When this lineage record was created
    public let createdAt: Date
    
    /// Schema version for migration
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public init(
        previousRunId: UUID?,
        qualitySignatureHash: String,
        createdAt: Date = Date()
    ) {
        self.previousRunId = previousRunId
        self.qualitySignatureHash = qualitySignatureHash
        self.createdAt = createdAt
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    /// Creates lineage from the current state
    public static func create(
        previousRunId: UUID?,
        signature: QualitySignature
    ) -> EvalRunLineage {
        // Compute hash of signature for lineage
        let signatureHash = computeSignatureHash(signature)
        
        return EvalRunLineage(
            previousRunId: previousRunId,
            qualitySignatureHash: signatureHash
        )
    }
    
    /// Computes a hash of the quality signature for lineage tracking
    private static func computeSignatureHash(_ signature: QualitySignature) -> String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(signature)
            
            let hash = SHA256.hash(data: data)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        } catch {
            return "hash_unavailable"
        }
    }
}
