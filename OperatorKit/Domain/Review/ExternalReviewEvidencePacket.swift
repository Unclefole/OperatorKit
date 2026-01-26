import Foundation
import CryptoKit

// ============================================================================
// EXTERNAL REVIEW EVIDENCE PACKET (Phase 9D)
//
// Unified export artifact that aggregates everything reviewers need,
// without content. Verifiable, internally consistent, reviewer-friendly.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content fields
// ❌ No raw notes, prompt text, draft text
// ❌ No networking, uploads, telemetry
// ❌ No runtime behavior changes
// ✅ Manual, user-initiated export only
// ✅ Metadata-only evidence
// ✅ Hashes of docs, counts, booleans, status enums, version strings allowed
//
// See: docs/SAFETY_CONTRACT.md, docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - External Review Evidence Packet

/// Complete evidence packet for external reviewers
/// Contains METADATA ONLY - no user content
public struct ExternalReviewEvidencePacket: Codable {
    
    // MARK: - Schema & Export Metadata
    
    public let schemaVersion: Int
    public let exportedAt: Date
    public let exportedAtDayRounded: String  // yyyy-MM-dd
    
    // MARK: - App Identity
    
    public let appVersion: String
    public let buildNumber: String
    public let releaseMode: String  // debug/testflight/appstore
    
    // MARK: - Safety & Governance
    
    public let safetyContractSnapshot: SafetyContractExport
    public let claimRegistrySummary: ClaimRegistrySummaryExport
    public let phaseBoundariesHash: String?  // SHA-256 of docs/PHASE_BOUNDARIES.md (optional)
    public let releaseAcknowledgement: ReleaseAcknowledgementExport?
    
    // MARK: - Invariant Proof
    
    public let invariantCheckSummary: InvariantCheckSummaryExport
    public let preflightSummary: PreflightSummaryExport
    public let regressionSentinelSummary: RegressionSentinelExport?
    
    // MARK: - Quality Proof (Metadata-Only)
    
    public let qualityPacket: ExportQualityPacket
    public let integritySealStatus: IntegrityStatusExport?
    public let latestQualitySignature: QualitySignature?
    
    // MARK: - Reviewer Guidance
    
    public let reviewerTestPlan: ReviewerTestPlanExport
    public let reviewerFAQ: [ReviewerFAQItemExport]
    
    // MARK: - Disclaimers
    
    public let disclaimers: [String]
    
    // MARK: - Doc Hashes (Advisory)
    
    public let docHashes: DocHashesExport
    
    public static let currentSchemaVersion = 1
}

// MARK: - Claim Registry Summary Export

public struct ClaimRegistrySummaryExport: Codable {
    public let schemaVersion: Int
    public let totalClaims: Int
    public let claimIds: [String]  // e.g., ["CLAIM-001", "CLAIM-002", ...]
    public let lastUpdated: String
    
    public init(
        schemaVersion: Int,
        totalClaims: Int,
        claimIds: [String],
        lastUpdated: String
    ) {
        self.schemaVersion = schemaVersion
        self.totalClaims = totalClaims
        self.claimIds = claimIds
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Invariant Check Summary Export

public struct InvariantCheckSummaryExport: Codable {
    public let totalChecks: Int
    public let passedChecks: Int
    public let failedChecks: Int
    public let status: String  // PASS/FAIL
    public let checkNames: [String]
    public let failedCheckNames: [String]
    
    public init(
        totalChecks: Int,
        passedChecks: Int,
        failedChecks: Int,
        status: String,
        checkNames: [String],
        failedCheckNames: [String]
    ) {
        self.totalChecks = totalChecks
        self.passedChecks = passedChecks
        self.failedChecks = failedChecks
        self.status = status
        self.checkNames = checkNames
        self.failedCheckNames = failedCheckNames
    }
}

// MARK: - Preflight Summary Export

public struct PreflightSummaryExport: Codable {
    public let totalChecks: Int
    public let passedChecks: Int
    public let blockers: Int
    public let warnings: Int
    public let status: String  // PASS/WARN/FAIL
    public let releaseMode: String
    public let categories: [String]
    public let blockerNames: [String]
    
    public init(
        totalChecks: Int,
        passedChecks: Int,
        blockers: Int,
        warnings: Int,
        status: String,
        releaseMode: String,
        categories: [String],
        blockerNames: [String]
    ) {
        self.totalChecks = totalChecks
        self.passedChecks = passedChecks
        self.blockers = blockers
        self.warnings = warnings
        self.status = status
        self.releaseMode = releaseMode
        self.categories = categories
        self.blockerNames = blockerNames
    }
}

// MARK: - Regression Sentinel Export

public struct RegressionSentinelExport: Codable {
    public let totalChecks: Int
    public let passedChecks: Int
    public let status: String  // ALL_CLEAR / REGRESSION_DETECTED
    public let checkNames: [String]
    public let failedCheckNames: [String]
    
    public init(
        totalChecks: Int,
        passedChecks: Int,
        status: String,
        checkNames: [String],
        failedCheckNames: [String]
    ) {
        self.totalChecks = totalChecks
        self.passedChecks = passedChecks
        self.status = status
        self.checkNames = checkNames
        self.failedCheckNames = failedCheckNames
    }
}

// MARK: - Integrity Status Export

public struct IntegrityStatusExport: Codable {
    public let status: String  // Verified/Mismatch/Not Available
    public let algorithm: String?
    public let inputsHashed: [String]?
    public let sealedAt: Date?
    
    public init(
        status: String,
        algorithm: String?,
        inputsHashed: [String]?,
        sealedAt: Date?
    ) {
        self.status = status
        self.algorithm = algorithm
        self.inputsHashed = inputsHashed
        self.sealedAt = sealedAt
    }
    
    public init(from integrityStatus: IntegrityStatus, seal: IntegritySeal?) {
        self.status = integrityStatus.rawValue
        self.algorithm = seal?.algorithm
        self.inputsHashed = seal?.inputsHashed
        self.sealedAt = seal?.sealedAt
    }
}

// MARK: - Reviewer Test Plan Export

public struct ReviewerTestPlanExport: Codable {
    public let title: String
    public let estimatedMinutes: Int
    public let steps: [ReviewerTestStepExport]
    
    public init(title: String, estimatedMinutes: Int, steps: [ReviewerTestStepExport]) {
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.steps = steps
    }
}

public struct ReviewerTestStepExport: Codable {
    public let stepNumber: Int
    public let title: String
    public let action: String
    public let expectedResult: String
    public let duration: String
    
    public init(stepNumber: Int, title: String, action: String, expectedResult: String, duration: String) {
        self.stepNumber = stepNumber
        self.title = title
        self.action = action
        self.expectedResult = expectedResult
        self.duration = duration
    }
}

// MARK: - Reviewer FAQ Export

public struct ReviewerFAQItemExport: Codable {
    public let question: String
    public let answer: String
    
    public init(question: String, answer: String) {
        self.question = question
        self.answer = answer
    }
}

// MARK: - Doc Hashes Export

public struct DocHashesExport: Codable {
    public let safetyContractHash: String?
    public let claimRegistryHash: String?
    public let executionGuaranteesHash: String?
    public let appReviewPacketHash: String?
    public let phaseBoundariesHash: String?
    public let status: String  // all_available / partial / unavailable
    
    public init(
        safetyContractHash: String?,
        claimRegistryHash: String?,
        executionGuaranteesHash: String?,
        appReviewPacketHash: String?,
        phaseBoundariesHash: String?,
        status: String
    ) {
        self.safetyContractHash = safetyContractHash
        self.claimRegistryHash = claimRegistryHash
        self.executionGuaranteesHash = executionGuaranteesHash
        self.appReviewPacketHash = appReviewPacketHash
        self.phaseBoundariesHash = phaseBoundariesHash
        self.status = status
    }
}

// MARK: - Export Helper

extension ExternalReviewEvidencePacket {
    
    /// Exports as JSON data
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    
    /// Exports as JSON string
    public func toJSONString() throws -> String {
        let data = try toJSON()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
