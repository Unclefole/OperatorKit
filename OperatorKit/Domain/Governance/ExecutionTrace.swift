import Foundation
import CryptoKit

// ============================================================================
// EXECUTION TRACE — Machine-Verifiable Execution Path Proof
//
// Consolidates all key hashes from a single execution into one exportable,
// machine-verifiable trace. This is the COMPLETE proof that an execution
// followed the governed pipeline from intent → policy → approval → token →
// connector → certificate.
//
// INVARIANT: Trace is immutable after creation.
// INVARIANT: Contains ONLY hashes — never raw data, prompts, or PII.
// INVARIANT: Exportable as JSON for external audit.
// INVARIANT: Each trace links to exactly one ExecutionCertificate.
//
// EVIDENCE TAGS:
//   execution_trace_created, execution_trace_exported
// ============================================================================

// MARK: - Execution Trace

/// Machine-verifiable proof of a governed execution path.
/// Aggregates all key hashes from intent through certificate.
public struct ExecutionTrace: Sendable, Identifiable, Codable {

    // ── Identity ──────────────────────────────────────
    public let id: UUID
    public let timestamp: Date

    // ── Pipeline Hashes ───────────────────────────────
    /// SHA256 of the classified intent (action + target).
    public let intentHash: String

    /// SHA256 of the ExecutionPolicy that authorized execution.
    public let policyHash: String

    /// UUID of the ApprovalSession that approved execution.
    public let approvalId: String

    /// SHA256 of the AuthorizationToken (id + planId + signature).
    public let tokenHash: String

    /// Connector ID used for execution (nil if no connector involved).
    public let connectorId: String?

    /// SHA256 of the ExecutionCertificate.
    public let certificateHash: String

    // ── Metadata ──────────────────────────────────────
    /// Risk tier at execution time.
    public let riskTier: String

    /// Whether the certificate was SE-backed.
    public let enclaveBacked: Bool

    /// Execution duration in milliseconds.
    public let executionDurationMs: Int

    /// Whether all pipeline gates passed.
    public let allGatesPassed: Bool

    // ── Trace Hash ────────────────────────────────────
    /// SHA256 of the entire trace (for tamper detection).
    public let traceHash: String

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        intentHash: String,
        policyHash: String,
        approvalId: String,
        tokenHash: String,
        connectorId: String?,
        certificateHash: String,
        riskTier: String,
        enclaveBacked: Bool,
        executionDurationMs: Int,
        allGatesPassed: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.intentHash = intentHash
        self.policyHash = policyHash
        self.approvalId = approvalId
        self.tokenHash = tokenHash
        self.connectorId = connectorId
        self.certificateHash = certificateHash
        self.riskTier = riskTier
        self.enclaveBacked = enclaveBacked
        self.executionDurationMs = executionDurationMs
        self.allGatesPassed = allGatesPassed

        // Compute trace hash from all fields
        let material = [
            id.uuidString,
            timestamp.ISO8601Format(),
            intentHash,
            policyHash,
            approvalId,
            tokenHash,
            connectorId ?? "none",
            certificateHash,
            riskTier,
            "\(enclaveBacked)",
            "\(executionDurationMs)",
            "\(allGatesPassed)"
        ].joined(separator: "|")
        let hash = SHA256.hash(data: Data(material.utf8))
        self.traceHash = hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Export

    /// Generate a JSON export of this trace (no sensitive data).
    public func generateReport() -> Data {
        let report = ExecutionTraceReport(
            traceId: id.uuidString,
            timestamp: timestamp.ISO8601Format(),
            intentHash: intentHash,
            policyHash: policyHash,
            approvalId: approvalId,
            tokenHash: tokenHash,
            connectorId: connectorId,
            certificateHash: certificateHash,
            riskTier: riskTier,
            enclaveBacked: enclaveBacked,
            executionDurationMs: executionDurationMs,
            allGatesPassed: allGatesPassed,
            traceHash: traceHash,
            exportedAt: Date().ISO8601Format(),
            schemaVersion: "1.0.0"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(report)) ?? Data()
    }
}

// MARK: - Execution Trace Report (Export Format)

/// JSON-serializable export format for external audit.
private struct ExecutionTraceReport: Codable {
    let traceId: String
    let timestamp: String
    let intentHash: String
    let policyHash: String
    let approvalId: String
    let tokenHash: String
    let connectorId: String?
    let certificateHash: String
    let riskTier: String
    let enclaveBacked: Bool
    let executionDurationMs: Int
    let allGatesPassed: Bool
    let traceHash: String
    let exportedAt: String
    let schemaVersion: String
}

// MARK: - Trace Builder

/// Builds an ExecutionTrace from execution pipeline artifacts.
public enum ExecutionTraceBuilder {

    /// Build a trace after successful execution and certificate generation.
    ///
    /// - Parameters:
    ///   - intentAction: The intent action string (will be hashed).
    ///   - intentTarget: The intent target (will be hashed).
    ///   - policyHash: The formal policy hash from PolicyCodeEngine.
    ///   - approvalSessionId: UUID of the ApprovalSession.
    ///   - token: The AuthorizationToken used for execution.
    ///   - connectorId: Connector ID if a connector was involved.
    ///   - certificate: The generated ExecutionCertificate.
    ///   - executionDurationMs: How long execution took.
    /// - Returns: A complete ExecutionTrace.
    public static func build(
        intentAction: String,
        intentTarget: String?,
        policyHash: String,
        approvalSessionId: UUID?,
        tokenId: UUID,
        tokenPlanId: UUID,
        tokenSignature: String,
        connectorId: String?,
        certificate: ExecutionCertificate,
        executionDurationMs: Int
    ) -> ExecutionTrace {
        let intentHash = ExecutionCertificate.sha256Hex(
            "\(intentAction)|\(intentTarget ?? "none")"
        )
        let tokenHash = ExecutionCertificate.sha256Hex(
            "\(tokenId.uuidString)|\(tokenPlanId.uuidString)|\(tokenSignature)"
        )

        let trace = ExecutionTrace(
            intentHash: intentHash,
            policyHash: policyHash,
            approvalId: approvalSessionId?.uuidString ?? "direct_approval",
            tokenHash: tokenHash,
            connectorId: connectorId,
            certificateHash: certificate.certificateHash,
            riskTier: certificate.riskTier.rawValue,
            enclaveBacked: certificate.enclaveBacked,
            executionDurationMs: executionDurationMs,
            allGatesPassed: true
        )

        // Log evidence
        Task { @MainActor in
            try? EvidenceEngine.shared.logGenericArtifact(
                type: "execution_trace_created",
                planId: tokenPlanId,
                jsonString: """
                {"traceId":"\(trace.id)","intentHash":"\(intentHash.prefix(16))","policyHash":"\(policyHash.prefix(16))","certHash":"\(certificate.certificateHash.prefix(16))","traceHash":"\(trace.traceHash.prefix(16))","enclave":\(certificate.enclaveBacked),"timestamp":"\(Date().ISO8601Format())"}
                """
            )
        }

        return trace
    }
}

// MARK: - Trace Store

/// In-memory store for execution traces (current session).
public final class ExecutionTraceStore: @unchecked Sendable {
    public static let shared = ExecutionTraceStore()

    private let lock = NSLock()
    private var traces: [ExecutionTrace] = []

    private init() {}

    /// Append a trace to the store.
    public func append(_ trace: ExecutionTrace) {
        lock.lock()
        defer { lock.unlock() }
        traces.append(trace)
    }

    /// All traces in the current session.
    public var allTraces: [ExecutionTrace] {
        lock.lock()
        defer { lock.unlock() }
        return traces
    }

    /// Most recent trace.
    public var lastTrace: ExecutionTrace? {
        lock.lock()
        defer { lock.unlock() }
        return traces.last
    }

    /// Export all traces as a consolidated JSON report.
    public func exportAllTraces() -> Data {
        let allTraces = self.allTraces
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(allTraces)) ?? Data()
    }
}
