import Foundation
import SwiftData

// ============================================================================
// BACKGROUND TASK RECORD — Persistent Queue for Background Intelligence
//
// INVARIANT: Background tasks NEVER call ExecutionEngine or write Services.
// INVARIANT: Background tasks NEVER issue AuthorizationTokens.
// INVARIANT: Background tasks respect EconomicGovernor budget gates.
// INVARIANT: Tasks persist across app restarts via SwiftData.
// ============================================================================

@Model
public final class BackgroundTaskRecord {
    @Attribute(.unique) public var id: UUID
    public var kind: String           // TaskKind raw value
    public var payloadRef: String     // UUID or key referencing the payload
    public var dedupKey: String       // Deduplication key: kind + payloadRef hash
    public var createdAt: Date
    public var runAt: Date            // Earliest time this task should run
    public var status: String         // TaskStatus raw value
    public var attempts: Int
    public var maxAttempts: Int
    public var lastError: String?
    public var completedAt: Date?

    public init(
        kind: TaskKind,
        payloadRef: String,
        runAt: Date = Date(),
        maxAttempts: Int = 3
    ) {
        self.id = UUID()
        self.kind = kind.rawValue
        self.payloadRef = payloadRef
        self.dedupKey = "\(kind.rawValue):\(payloadRef)"
        self.createdAt = Date()
        self.runAt = runAt
        self.status = TaskStatus.pending.rawValue
        self.attempts = 0
        self.maxAttempts = maxAttempts
        self.lastError = nil
        self.completedAt = nil
    }

    // MARK: - Enums

    public enum TaskKind: String, Codable, CaseIterable {
        case prepareProposalPack = "prepare_proposal_pack"
        case mirrorAuditAttestation = "mirror_audit_attestation"
        case deliverNotification = "deliver_notification"
    }

    public enum TaskStatus: String, Codable, CaseIterable {
        case pending = "pending"
        case running = "running"
        case completed = "completed"
        case failed = "failed"
        case cancelled = "cancelled"
    }

    // MARK: - Computed

    public var taskKind: TaskKind? { TaskKind(rawValue: kind) }
    public var taskStatus: TaskStatus? { TaskStatus(rawValue: status) }
    public var canRetry: Bool { attempts < maxAttempts && status != TaskStatus.completed.rawValue }
}
