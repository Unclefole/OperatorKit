import Foundation
import CryptoKit
import Security

// ============================================================================
// EVIDENCE ENGINE — PHASE 1 CAPABILITY KERNEL
//
// This is the enterprise wedge.
// Log EVERYTHING needed for reconstruction.
//
// INVARIANT: Write atomically
// INVARIANT: Append-only log design
// INVARIANT: Future SOC2 depends on this
// INVARIANT: Do NOT ship weak logging
//
// Required Artifact Chain:
// - ToolPlan
// - RiskAssessment
// - ProbeResults
// - Approvals
// - ExecutionResult
// - RollbackData (if applicable)
// ============================================================================

import SwiftUI

// MARK: - Evidence Engine

/// Append-only evidence logging for audit trail.
/// SOC2-ready design.
@MainActor
public final class EvidenceEngine: ObservableObject {
    
    public static let shared = EvidenceEngine()
    
    // MARK: - Storage
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    @Published private(set) var entryCount: Int = 0
    @Published private(set) var chainIntegrityValid: Bool = true
    @Published private(set) var lastIntegrityReport: ChainIntegrityReport?

    /// The hash of the last appended entry — used for hash chaining.
    private var lastEntryHash: String = "GENESIS"

    private var evidenceDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("EvidenceChain", isDirectory: true)
    }
    
    private var currentChainFile: URL {
        evidenceDirectory.appendingPathComponent("chain.jsonl")
    }
    
    private var indexFile: URL {
        evidenceDirectory.appendingPathComponent("index.json")
    }
    
    // MARK: - Initialization
    
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        setupEvidenceDirectory()
        loadEntryCount()
    }
    
    private func setupEvidenceDirectory() {
        try? fileManager.createDirectory(at: evidenceDirectory, withIntermediateDirectories: true)
    }
    
    /// Call on app launch to verify evidence chain integrity.
    /// If broken, sets chainIntegrityValid = false and publishes the report.
    /// UI should surface this prominently — tampered evidence is a SEV-0.
    public func verifyOnLaunch() {
        do {
            let report = try verifyChainIntegrity()
            lastIntegrityReport = report
            if !report.overallValid {
                logError("[EVIDENCE] INTEGRITY VIOLATION DETECTED ON LAUNCH: \(report.violations.count) issue(s)")
                try? logViolation(PolicyViolation(
                    violationType: .dataCorruption,
                    description: "Evidence chain integrity failed on launch: \(report.violations.count) violation(s)",
                    severity: .critical
                ), planId: UUID())
            }
        } catch {
            logError("[EVIDENCE] Failed to verify chain integrity: \(error)")
            chainIntegrityValid = false
        }
    }

    private func loadEntryCount() {
        guard let data = try? Data(contentsOf: indexFile),
              let index = try? decoder.decode(EvidenceIndex.self, from: data) else {
            entryCount = 0
            return
        }
        entryCount = index.totalEntries

        // Restore last entry hash for chain continuity
        if let entries = try? loadAllEntries(), let last = entries.last {
            lastEntryHash = last.currentHash
        }
    }
    
    // MARK: - Public API
    
    /// Log a complete execution chain
    public func logExecutionChain(_ chain: ExecutionEvidenceChain) throws {
        // Validate chain completeness
        guard chain.isComplete else {
            throw EvidenceError.incompleteChain(missing: chain.missingComponents)
        }
        
        // Create evidence entry
        let entry = EvidenceEntry(
            id: UUID(),
            chainId: chain.id,
            type: .executionChain,
            payload: chain,
            signature: signEntry(chain),
            createdAt: Date()
        )
        
        // Append atomically
        try appendEntry(entry)
        
        // Update index
        try updateIndex(with: entry)
        
        entryCount += 1
    }
    
    /// Log a tool plan creation
    public func logToolPlanCreated(_ plan: ToolPlan) throws {
        let artifact = EvidenceArtifact(
            artifactType: .toolPlan,
            planId: plan.id,
            data: try encoder.encode(plan),
            timestamp: Date()
        )
        
        let entry = EvidenceEntry(
            id: UUID(),
            chainId: plan.id,
            type: .artifact,
            payload: artifact,
            signature: signArtifact(artifact),
            createdAt: Date()
        )
        
        try appendEntry(entry)
        entryCount += 1
    }
    
    /// Log a risk assessment
    public func logRiskAssessment(_ assessment: RiskAssessment, planId: UUID) throws {
        let artifact = EvidenceArtifact(
            artifactType: .riskAssessment,
            planId: planId,
            data: try encoder.encode(assessment),
            timestamp: Date()
        )
        
        let entry = EvidenceEntry(
            id: UUID(),
            chainId: planId,
            type: .artifact,
            payload: artifact,
            signature: signArtifact(artifact),
            createdAt: Date()
        )
        
        try appendEntry(entry)
        entryCount += 1
    }
    
    /// Log verification result
    public func logVerificationResult(_ result: KernelVerificationResult, planId: UUID) throws {
        let artifact = EvidenceArtifact(
            artifactType: .verificationResult,
            planId: planId,
            data: try encoder.encode(result),
            timestamp: Date()
        )
        
        let entry = EvidenceEntry(
            id: UUID(),
            chainId: planId,
            type: .artifact,
            payload: artifact,
            signature: signArtifact(artifact),
            createdAt: Date()
        )
        
        try appendEntry(entry)
        entryCount += 1
    }
    
    /// Log approval decision
    public func logApproval(_ approval: ApprovalRecord, planId: UUID) throws {
        let artifact = EvidenceArtifact(
            artifactType: .approval,
            planId: planId,
            data: try encoder.encode(approval),
            timestamp: Date()
        )
        
        let entry = EvidenceEntry(
            id: UUID(),
            chainId: planId,
            type: .artifact,
            payload: artifact,
            signature: signArtifact(artifact),
            createdAt: Date()
        )
        
        try appendEntry(entry)
        entryCount += 1
    }
    
    /// Log execution outcome
    public func logExecutionOutcome(_ outcome: KernelExecutionOutcome, planId: UUID) throws {
        let artifact = EvidenceArtifact(
            artifactType: .executionResult,
            planId: planId,
            data: try encoder.encode(outcome),
            timestamp: Date()
        )
        
        let entry = EvidenceEntry(
            id: UUID(),
            chainId: planId,
            type: .artifact,
            payload: artifact,
            signature: signArtifact(artifact),
            createdAt: Date()
        )
        
        try appendEntry(entry)
        entryCount += 1
    }
    
    /// Log policy violation
    public func logViolation(_ violation: PolicyViolation, planId: UUID?) throws {
        let entry = EvidenceEntry(
            id: UUID(),
            chainId: planId ?? UUID(),
            type: .violation,
            payload: violation,
            signature: signViolation(violation),
            createdAt: Date()
        )
        
        try appendEntry(entry)
        entryCount += 1
    }
    
    /// Bridge: Log a token issuance event
    /// Called when KernelBridge issues a token for execution
    func logTokenIssuance(_ token: KernelAuthorizationToken, draft: Draft?) throws {
        let tokenData: [String: Any] = [
            "tokenId": token.id.uuidString,
            "planId": token.planId.uuidString,
            "riskTier": token.riskTier.rawValue,
            "approvalType": token.approvalType.rawValue,
            "issuedAt": token.issuedAt.timeIntervalSince1970,
            "expiresAt": token.expiresAt.timeIntervalSince1970,
            "draftTitle": draft?.title ?? "unknown"
        ]
        
        let artifact = EvidenceArtifact(
            artifactType: .approval,
            planId: token.planId,
            data: (try? JSONSerialization.data(withJSONObject: tokenData)) ?? Data(),
            timestamp: Date()
        )
        
        let entry = EvidenceEntry(
            id: UUID(),
            chainId: token.planId,
            type: .systemEvent,
            payload: artifact,
            signature: signArtifact(artifact),
            createdAt: Date()
        )
        
        try appendEntry(entry)
        entryCount += 1
    }
    
    // ════════════════════════════════════════════════════════════════
    // MARK: - Model Call Evidence Logging
    // ════════════════════════════════════════════════════════════════

    /// Log a generic artifact by type (used for model call governance).
    public func logGenericArtifact(type: String, planId: UUID, jsonString: String) throws {
        let artifact = EvidenceArtifact(
            artifactType: .toolPlan, // reuse existing artifact type
            planId: planId,
            data: jsonString.data(using: .utf8) ?? Data(),
            timestamp: Date()
        )

        let entry = EvidenceEntry(
            id: UUID(),
            chainId: planId,
            type: .systemEvent,
            payload: artifact,
            signature: signArtifact(artifact),
            createdAt: Date()
        )

        try appendEntry(entry)
        entryCount += 1
    }

    /// Log a model call decision from CapabilityKernel.
    public func logModelCallDecision(_ decision: ModelCallDecision) throws {
        let json = "{\"type\":\"model_call_decision\",\"requestId\":\"\(decision.requestId)\",\"allowed\":\(decision.allowed),\"provider\":\"\(decision.provider.rawValue)\",\"requiresApproval\":\(decision.requiresHumanApproval),\"riskTier\":\"\(decision.riskTier)\",\"reason\":\"\(decision.reason)\"}"
        try logGenericArtifact(type: "model_call_decision", planId: decision.requestId, jsonString: json)
    }

    /// Log a model call request (redacted payload).
    public func logModelCallRequest(_ request: ModelCallRequest, provider: ModelProvider) throws {
        let json = "{\"type\":\"model_call_request\",\"requestId\":\"\(request.id)\",\"intentType\":\"\(request.intentType)\",\"provider\":\"\(provider.rawValue)\",\"contextSummary\":\"\(request.contextSummaryRedacted)\"}"
        try logGenericArtifact(type: "model_call_request", planId: request.id, jsonString: json)
    }

    /// Log a model call response (redacted — no raw output).
    public func logModelCallResponse(_ response: ModelCallResponseRecord) throws {
        let json = "{\"type\":\"model_call_response\",\"requestId\":\"\(response.requestId)\",\"provider\":\"\(response.provider.rawValue)\",\"success\":\(response.success),\"latencyMs\":\(response.latencyMs),\"outputLengthChars\":\(response.outputLengthChars),\"confidence\":\(response.confidence ?? -1)}"
        try logGenericArtifact(type: "model_call_response", planId: response.requestId, jsonString: json)
    }

    /// Query evidence by chain ID
    public func queryByChainId(_ chainId: UUID) throws -> [EvidenceEntry<AnyCodable>] {
        let entries = try loadAllEntries()
        return entries.filter { $0.chainId == chainId }
    }
    
    /// Query evidence by date range
    public func queryByDateRange(from: Date, to: Date) throws -> [EvidenceEntry<AnyCodable>] {
        let entries = try loadAllEntries()
        return entries.filter { $0.createdAt >= from && $0.createdAt <= to }
    }
    
    /// Export evidence for audit
    public func exportForAudit(from: Date? = nil, to: Date? = nil) throws -> EvidenceExportPacket {
        var entries = try loadAllEntries()
        
        if let from = from {
            entries = entries.filter { $0.createdAt >= from }
        }
        if let to = to {
            entries = entries.filter { $0.createdAt <= to }
        }
        
        let chainHash = computeChainHash(entries: entries)
        
        return EvidenceExportPacket(
            exportId: UUID(),
            exportedAt: Date(),
            fromDate: from,
            toDate: to,
            totalEntries: entries.count,
            chainHash: chainHash,
            entries: entries
        )
    }
    
    /// Verify chain integrity — validates hash chain link-by-link.
    /// If any entry's previousHash does not match the prior entry's currentHash,
    /// or if currentHash recomputation fails, an integrity violation is raised.
    public func verifyChainIntegrity() throws -> ChainIntegrityReport {
        let entries = try loadAllEntries()
        var violations: [IntegrityViolation] = []
        var expectedPreviousHash = "GENESIS"

        for (index, entry) in entries.enumerated() {
            // Verify signature is non-empty
            if entry.signature.isEmpty {
                violations.append(IntegrityViolation(
                    entryId: entry.id,
                    type: .signatureMismatch,
                    description: "Entry \(index) has empty signature"
                ))
            }

            // Verify hash chain link
            if entry.previousHash != expectedPreviousHash {
                violations.append(IntegrityViolation(
                    entryId: entry.id,
                    type: .sequenceGap,
                    description: "Entry \(index) previousHash mismatch — expected '\(expectedPreviousHash.prefix(16))...' got '\(entry.previousHash.prefix(16))...'"
                ))
            }

            // Verify currentHash recomputation
            let material = "\(entry.id.uuidString)|\(entry.chainId.uuidString)|\(entry.type.rawValue)|\(entry.signature)|\(entry.createdAt.timeIntervalSince1970)|\(entry.previousHash)"
            let digest = SHA256.hash(data: material.data(using: .utf8)!)
            let recomputed = digest.compactMap { String(format: "%02x", $0) }.joined()

            if entry.currentHash != recomputed {
                violations.append(IntegrityViolation(
                    entryId: entry.id,
                    type: .dataCorruption,
                    description: "Entry \(index) currentHash recomputation failed — data tampered"
                ))
            }

            expectedPreviousHash = entry.currentHash
        }

        let valid = violations.isEmpty
        chainIntegrityValid = valid

        return ChainIntegrityReport(
            checkedAt: Date(),
            totalEntries: entries.count,
            validEntries: entries.count - violations.count,
            violations: violations,
            overallValid: valid
        )
    }
    
    // MARK: - Internal Operations
    
    private func appendEntry<T: Codable>(_ entry: EvidenceEntry<T>) throws {
        // Hash-chain: create a new entry that includes the previous hash
        let chainedEntry = EvidenceEntry(
            id: entry.id,
            chainId: entry.chainId,
            type: entry.type,
            payload: entry.payload,
            signature: entry.signature,
            createdAt: entry.createdAt,
            previousHash: lastEntryHash
        )

        let data = try encoder.encode(chainedEntry)
        let line = data + Data("\n".utf8)
        
        // Atomic append
        if fileManager.fileExists(atPath: currentChainFile.path) {
            let handle = try FileHandle(forWritingTo: currentChainFile)
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
            try handle.close()
        } else {
            try line.write(to: currentChainFile)
        }

        // Advance the chain
        lastEntryHash = chainedEntry.currentHash
    }
    
    private func updateIndex(with entry: EvidenceEntry<ExecutionEvidenceChain>) throws {
        var index: EvidenceIndex
        
        if let data = try? Data(contentsOf: indexFile),
           let existing = try? decoder.decode(EvidenceIndex.self, from: data) {
            index = existing
        } else {
            index = EvidenceIndex(
                createdAt: Date(),
                lastUpdatedAt: Date(),
                totalEntries: 0,
                chainIds: []
            )
        }
        
        index = EvidenceIndex(
            createdAt: index.createdAt,
            lastUpdatedAt: Date(),
            totalEntries: index.totalEntries + 1,
            chainIds: index.chainIds + [entry.chainId]
        )
        
        let data = try encoder.encode(index)
        try data.write(to: indexFile, options: .atomic)
    }
    
    private func loadAllEntries() throws -> [EvidenceEntry<AnyCodable>] {
        guard fileManager.fileExists(atPath: currentChainFile.path) else {
            return []
        }
        
        let data = try Data(contentsOf: currentChainFile)
        let lines = String(data: data, encoding: .utf8)?.split(separator: "\n") ?? []
        
        var entries: [EvidenceEntry<AnyCodable>] = []
        for line in lines {
            if let lineData = line.data(using: .utf8),
               let entry = try? decoder.decode(EvidenceEntry<AnyCodable>.self, from: lineData) {
                entries.append(entry)
            }
        }
        
        return entries
    }
    
    // MARK: - Signing (Keychain-Backed)
    //
    // INVARIANT: Evidence signing key is generated on first launch, stored in Keychain,
    // and NEVER exported. Same pattern as CapabilityKernel token signing key.
    // INVARIANT: Key never appears in source code.

    private static let evidenceKeychainService = "com.operatorkit.evidence-signing-key"
    private static let evidenceKeychainAccount = "evidence-hmac-v1"

    private let signingKey: SymmetricKey = {
        // Attempt to load from Keychain
        if let existing = EvidenceEngine.loadEvidenceKey() {
            return existing
        }
        // First launch: generate and store
        let newKey = SymmetricKey(size: .bits256)
        EvidenceEngine.storeEvidenceKey(newKey)
        return newKey
    }()

    private nonisolated static func loadEvidenceKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: evidenceKeychainService,
            kSecAttrAccount as String: evidenceKeychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    private nonisolated static func storeEvidenceKey(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: evidenceKeychainService,
            kSecAttrAccount as String: evidenceKeychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func signEntry(_ chain: ExecutionEvidenceChain) -> String {
        let payload = "\(chain.id.uuidString)|\(chain.planId.uuidString)|\(chain.createdAt.timeIntervalSince1970)"
        let payloadData = payload.data(using: .utf8)!
        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: signingKey)
        return Data(signature).base64EncodedString()
    }
    
    private func signArtifact(_ artifact: EvidenceArtifact) -> String {
        let payload = "\(artifact.artifactType.rawValue)|\(artifact.planId.uuidString)|\(artifact.timestamp.timeIntervalSince1970)"
        let payloadData = payload.data(using: .utf8)!
        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: signingKey)
        return Data(signature).base64EncodedString()
    }
    
    private func signViolation(_ violation: PolicyViolation) -> String {
        let payload = "\(violation.id.uuidString)|\(violation.violationType.rawValue)|\(violation.occurredAt.timeIntervalSince1970)"
        let payloadData = payload.data(using: .utf8)!
        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: signingKey)
        return Data(signature).base64EncodedString()
    }
    
    private func verifyEntrySignature<T>(_ entry: EvidenceEntry<T>) -> Bool {
        // For now, trust the signature (full verification requires original payload)
        return !entry.signature.isEmpty
    }
    
    private func computeChainHash(entries: [EvidenceEntry<AnyCodable>]) -> String {
        let combined = entries.map { $0.signature }.joined(separator: "|")
        let data = combined.data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Evidence Entry

public struct EvidenceEntry<T: Codable>: Codable, Identifiable {
    public let id: UUID
    public let chainId: UUID
    public let type: EvidenceEntryType
    public let payload: T
    public let signature: String
    public let createdAt: Date

    // HASH-CHAIN FIELDS — tamper-evident ledger
    /// SHA256 of the previous entry's currentHash. Genesis entry uses "GENESIS".
    public let previousHash: String
    /// SHA256(id + chainId + type + signature + createdAt + previousHash)
    public let currentHash: String
    
    public init(
        id: UUID,
        chainId: UUID,
        type: EvidenceEntryType,
        payload: T,
        signature: String,
        createdAt: Date,
        previousHash: String = "GENESIS",
        currentHash: String = ""
    ) {
        self.id = id
        self.chainId = chainId
        self.type = type
        self.payload = payload
        self.signature = signature
        self.createdAt = createdAt
        self.previousHash = previousHash
        // Compute current hash if not provided
        if currentHash.isEmpty {
            let material = "\(id.uuidString)|\(chainId.uuidString)|\(type.rawValue)|\(signature)|\(createdAt.timeIntervalSince1970)|\(previousHash)"
            let digest = SHA256.hash(data: material.data(using: .utf8)!)
            self.currentHash = digest.compactMap { String(format: "%02x", $0) }.joined()
        } else {
            self.currentHash = currentHash
        }
    }

    // Custom Decodable: handles legacy entries that don't have hash chain fields
    enum CodingKeys: String, CodingKey {
        case id, chainId, type, payload, signature, createdAt, previousHash, currentHash
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        chainId = try container.decode(UUID.self, forKey: .chainId)
        type = try container.decode(EvidenceEntryType.self, forKey: .type)
        payload = try container.decode(T.self, forKey: .payload)
        signature = try container.decode(String.self, forKey: .signature)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        // Legacy entries may not have these fields
        previousHash = (try? container.decode(String.self, forKey: .previousHash)) ?? "GENESIS"
        currentHash = (try? container.decode(String.self, forKey: .currentHash)) ?? ""
    }
}

public enum EvidenceEntryType: String, Codable {
    case executionChain = "execution_chain"
    case artifact = "artifact"
    case violation = "violation"
    case systemEvent = "system_event"
}

// MARK: - Execution Evidence Chain

public struct ExecutionEvidenceChain: Codable, Identifiable {
    public let id: UUID
    public let planId: UUID
    public let createdAt: Date
    
    // Chain components
    public let toolPlan: ToolPlan
    public let riskAssessment: RiskAssessment
    public let verificationResult: KernelVerificationResult
    public let policyDecision: KernelPolicyDecision
    public let approvalRecord: ApprovalRecord
    public let executionOutcome: KernelExecutionOutcome
    public let rollbackData: RollbackData?
    
    public init(
        id: UUID = UUID(),
        planId: UUID,
        toolPlan: ToolPlan,
        riskAssessment: RiskAssessment,
        verificationResult: KernelVerificationResult,
        policyDecision: KernelPolicyDecision,
        approvalRecord: ApprovalRecord,
        executionOutcome: KernelExecutionOutcome,
        rollbackData: RollbackData? = nil
    ) {
        self.id = id
        self.planId = planId
        self.createdAt = Date()
        self.toolPlan = toolPlan
        self.riskAssessment = riskAssessment
        self.verificationResult = verificationResult
        self.policyDecision = policyDecision
        self.approvalRecord = approvalRecord
        self.executionOutcome = executionOutcome
        self.rollbackData = rollbackData
    }
    
    /// Check if chain has all required components
    public var isComplete: Bool {
        // All non-optional fields are present by construction
        // Rollback data is optional
        return true
    }
    
    /// List missing components (for incomplete chains)
    public var missingComponents: [String] {
        // Since all fields are required at init, this is always empty
        return []
    }
}

// MARK: - Evidence Artifact

public struct EvidenceArtifact: Codable {
    public let artifactType: ArtifactType
    public let planId: UUID
    public let data: Data
    public let timestamp: Date
    
    public init(
        artifactType: ArtifactType,
        planId: UUID,
        data: Data,
        timestamp: Date
    ) {
        self.artifactType = artifactType
        self.planId = planId
        self.data = data
        self.timestamp = timestamp
    }
}

public enum ArtifactType: String, Codable {
    case toolPlan = "tool_plan"
    case riskAssessment = "risk_assessment"
    case verificationResult = "verification_result"
    case approval = "approval"
    case executionResult = "execution_result"
    case rollback = "rollback"
}

// MARK: - Approval Record

// MARK: - Cryptographic Approver Principal
//
// INVARIANT: Approvals are PROVABLE, not asserted.
// An ApproverPrincipal binds to a real cryptographic identity —
// not a string label. Ready for quorum-based multi-signer authority.

public struct ApproverPrincipal: Codable {
    /// SHA256 fingerprint of the approver's public key
    public let publicKeyFingerprint: String
    /// Unique device identifier (derived from SE public key hash)
    public let deviceId: String
    /// Attestation type: how the principal was verified
    public let attestation: AttestationType

    public enum AttestationType: String, Codable {
        case secureEnclave = "secure_enclave"   // Hardware-backed (Face ID / Touch ID)
        case keychain = "keychain"               // Software-backed fallback
        case kernelAuto = "kernel_auto"          // Automatic low-risk (no human)
        case legacy = "legacy"                   // Pre-SE migration compatibility
    }

    /// Build from the current device's Secure Enclave identity.
    /// nonisolated: SecureEnclaveApprover.deviceFingerprint is nonisolated.
    public static func fromCurrentDevice() -> ApproverPrincipal {
        let fingerprint = SecureEnclaveApprover.shared.deviceFingerprint ?? "unknown" // nonisolated property
        return ApproverPrincipal(
            publicKeyFingerprint: fingerprint,
            deviceId: fingerprint,
            attestation: fingerprint != "unknown" ? .secureEnclave : .legacy
        )
    }

    /// Build for kernel auto-approval (low-risk actions).
    public static var kernelAutomatic: ApproverPrincipal {
        ApproverPrincipal(
            publicKeyFingerprint: "KERNEL_AUTO",
            deviceId: "local",
            attestation: .kernelAuto
        )
    }

    /// Legacy compatibility — converts a string identifier into a principal.
    public static func legacy(_ identifier: String) -> ApproverPrincipal {
        ApproverPrincipal(
            publicKeyFingerprint: identifier,
            deviceId: "local",
            attestation: .legacy
        )
    }
}

public struct ApprovalRecord: Codable, Identifiable {
    public let id: UUID
    public let planId: UUID
    public let approved: Bool
    public let approvalType: ApprovalType
    /// Legacy string-based approver identifier — kept for backward compatibility.
    public let approverIdentifier: String
    /// Cryptographic approver principal — provable identity.
    public let approverPrincipal: ApproverPrincipal?
    public let reason: String?
    public let approvedAt: Date
    public let expiresAt: Date?

    // SECURE ENCLAVE ROOT AUTHORITY — Phase 11
    /// ECDSA signature from Secure Enclave over the plan hash.
    /// The signature IS the authority artifact. Biometric presence alone is insufficient.
    public let humanSignature: Data?
    /// Public key fingerprint of the signer (SHA256 of SE public key).
    public let signerPublicKeyFingerprint: String?
    /// Trust epoch at the time of approval.
    public let trustEpoch: Int?
    /// Key version at the time of approval.
    public let keyVersion: Int?
    
    public init(
        id: UUID = UUID(),
        planId: UUID,
        approved: Bool,
        approvalType: ApprovalType,
        approverIdentifier: String,
        approverPrincipal: ApproverPrincipal? = nil,
        reason: String? = nil,
        approvedAt: Date = Date(),
        expiresAt: Date? = nil,
        humanSignature: Data? = nil,
        signerPublicKeyFingerprint: String? = nil,
        trustEpoch: Int? = nil,
        keyVersion: Int? = nil
    ) {
        self.id = id
        self.planId = planId
        self.approved = approved
        self.approvalType = approvalType
        self.approverIdentifier = approverIdentifier
        self.approverPrincipal = approverPrincipal ?? .legacy(approverIdentifier)
        self.reason = reason
        self.approvedAt = approvedAt
        self.expiresAt = expiresAt
        self.humanSignature = humanSignature
        self.signerPublicKeyFingerprint = signerPublicKeyFingerprint
        self.trustEpoch = trustEpoch
        self.keyVersion = keyVersion
    }
}

public enum ApprovalType: String, Codable {
    case automatic = "automatic"
    case userConfirm = "user_confirm"
    case biometric = "biometric"
    case multiSig = "multi_sig"
    case denied = "denied"
}

// MARK: - Kernel Execution Outcome
// Named KernelExecutionOutcome to avoid collision with existing ExecutionOutcome in ExecutionDiagnostics.swift

public struct KernelExecutionOutcome: Codable, Identifiable {
    public let id: UUID
    public let planId: UUID
    public let success: Bool
    public let status: ExecutionStatus
    public let startedAt: Date
    public let completedAt: Date
    public let duration: TimeInterval
    public let errorMessage: String?
    public let resultSummary: String
    
    public init(
        id: UUID = UUID(),
        planId: UUID,
        success: Bool,
        status: ExecutionStatus,
        startedAt: Date,
        completedAt: Date = Date(),
        errorMessage: String? = nil,
        resultSummary: String
    ) {
        self.id = id
        self.planId = planId
        self.success = success
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.duration = completedAt.timeIntervalSince(startedAt)
        self.errorMessage = errorMessage
        self.resultSummary = resultSummary
    }
}

public enum ExecutionStatus: String, Codable {
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    case timedOut = "timed_out"
    case rolledBack = "rolled_back"
}

// MARK: - Rollback Data

public struct RollbackData: Codable, Identifiable {
    public let id: UUID
    public let planId: UUID
    public let rollbackType: RollbackType
    public let previousState: Data?
    public let rollbackSuccessful: Bool
    public let rolledBackAt: Date
    public let details: String
    
    public init(
        id: UUID = UUID(),
        planId: UUID,
        rollbackType: RollbackType,
        previousState: Data?,
        rollbackSuccessful: Bool,
        rolledBackAt: Date = Date(),
        details: String
    ) {
        self.id = id
        self.planId = planId
        self.rollbackType = rollbackType
        self.previousState = previousState
        self.rollbackSuccessful = rollbackSuccessful
        self.rolledBackAt = rolledBackAt
        self.details = details
    }
}

public enum RollbackType: String, Codable {
    case automatic = "automatic"
    case manual = "manual"
    case partial = "partial"
    case notPossible = "not_possible"
}

// MARK: - Evidence Index

public struct EvidenceIndex: Codable {
    public let createdAt: Date
    public let lastUpdatedAt: Date
    public let totalEntries: Int
    public let chainIds: [UUID]
}

// MARK: - Evidence Export Packet

public struct EvidenceExportPacket: Codable, Identifiable {
    public let id: UUID
    public let exportId: UUID
    public let exportedAt: Date
    public let fromDate: Date?
    public let toDate: Date?
    public let totalEntries: Int
    public let chainHash: String
    public let entries: [EvidenceEntry<AnyCodable>]
    
    public init(
        exportId: UUID,
        exportedAt: Date,
        fromDate: Date?,
        toDate: Date?,
        totalEntries: Int,
        chainHash: String,
        entries: [EvidenceEntry<AnyCodable>]
    ) {
        self.id = exportId
        self.exportId = exportId
        self.exportedAt = exportedAt
        self.fromDate = fromDate
        self.toDate = toDate
        self.totalEntries = totalEntries
        self.chainHash = chainHash
        self.entries = entries
    }
}

// MARK: - Chain Integrity Report

public struct ChainIntegrityReport: Codable {
    public let checkedAt: Date
    public let totalEntries: Int
    public let validEntries: Int
    public let violations: [IntegrityViolation]
    public let overallValid: Bool
}

public struct IntegrityViolation: Codable, Identifiable {
    public let id: UUID
    public let entryId: UUID
    public let type: IntegrityViolationType
    public let description: String
    
    public init(
        id: UUID = UUID(),
        entryId: UUID,
        type: IntegrityViolationType,
        description: String
    ) {
        self.id = id
        self.entryId = entryId
        self.type = type
        self.description = description
    }
}

public enum IntegrityViolationType: String, Codable {
    case signatureMismatch = "signature_mismatch"
    case sequenceGap = "sequence_gap"
    case timestampAnomaly = "timestamp_anomaly"
    case dataCorruption = "data_corruption"
}

// MARK: - Evidence Errors

public enum EvidenceError: Error, LocalizedError {
    case incompleteChain(missing: [String])
    case signatureVerificationFailed
    case storageError(underlying: Error)
    case integrityViolation
    
    public var errorDescription: String? {
        switch self {
        case .incompleteChain(let missing):
            return "Incomplete evidence chain - missing: \(missing.joined(separator: ", "))"
        case .signatureVerificationFailed:
            return "Evidence signature verification failed"
        case .storageError(let underlying):
            return "Evidence storage error: \(underlying.localizedDescription)"
        case .integrityViolation:
            return "Evidence chain integrity violation detected"
        }
    }
}

// MARK: - AnyCodable Helper

public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
