import Foundation
import SwiftData

// ============================================================================
// BACKGROUND TASK QUEUE — Manages persistent background work
//
// INVARIANT: This queue NEVER imports ExecutionEngine or write-capable Services.
// INVARIANT: This queue NEVER issues AuthorizationTokens.
// INVARIANT: Only reads + intelligence + notifications.
// ============================================================================

@MainActor
public final class BackgroundTaskQueue: ObservableObject {

    public static let shared = BackgroundTaskQueue()

    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var lastProcessedAt: Date?

    private var modelContext: ModelContext?

    private init() {}

    // MARK: - Configuration

    public func configure(with container: ModelContainer) {
        self.modelContext = ModelContext(container)
        recoverStaleTasks()
    }

    /// On launch: any task stuck in "running" was interrupted by crash/termination.
    /// Transition to failed or re-queue based on retry budget.
    private func recoverStaleTasks() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<BackgroundTaskRecord>(
            predicate: #Predicate<BackgroundTaskRecord> { $0.status == "running" }
        )
        guard let stale = try? ctx.fetch(descriptor), !stale.isEmpty else { return }

        for task in stale {
            if task.canRetry {
                task.status = BackgroundTaskRecord.TaskStatus.pending.rawValue
                task.lastError = "Interrupted — recovered on launch"
                task.runAt = Date() // Retry immediately
            } else {
                task.status = BackgroundTaskRecord.TaskStatus.failed.rawValue
                task.lastError = "Interrupted — max retries exceeded"
            }
            log("[BG_QUEUE] Recovered stale task \(task.kind): \(task.status)")
        }
        try? ctx.save()
        refreshCount()
    }

    /// Tracks in-flight task IDs to prevent concurrent processing of the same task
    private var inFlightTaskIds: Set<UUID> = []

    /// Tracks chain hashes that have been successfully mirrored (exactly-once)
    private var mirroredChainHashes: Set<String> = []

    // MARK: - Enqueue (Idempotent with Dedup)

    public func enqueue(kind: BackgroundTaskRecord.TaskKind, payloadRef: String, runAt: Date = Date()) {
        guard let ctx = modelContext else {
            logError("[BG_QUEUE] Not configured — cannot enqueue")
            return
        }

        // Dedup: check if a pending/running task with same dedup key already exists
        let dedupKey = "\(kind.rawValue):\(payloadRef)"
        let descriptor = FetchDescriptor<BackgroundTaskRecord>(
            predicate: #Predicate<BackgroundTaskRecord> {
                $0.dedupKey == dedupKey && ($0.status == "pending" || $0.status == "running")
            }
        )
        if let existing = try? ctx.fetch(descriptor), !existing.isEmpty {
            log("[BG_QUEUE] Dedup: task already pending/running for \(kind.rawValue)")
            return
        }

        let record = BackgroundTaskRecord(kind: kind, payloadRef: payloadRef, runAt: runAt)
        ctx.insert(record)
        try? ctx.save()
        refreshCount()

        log("[BG_QUEUE] Enqueued \(kind.rawValue): \(payloadRef)")
    }

    // MARK: - Process Next

    /// Process the next pending task. Returns true if a task was processed.
    /// Called by BGProcessingTask handler or foreground scheduler.
    /// CONCURRENCY: Uses in-flight set to prevent duplicate concurrent processing.
    public func processNext() async -> Bool {
        guard let ctx = modelContext else { return false }

        // Fetch oldest pending task that is ready to run
        let now = Date()
        let descriptor = FetchDescriptor<BackgroundTaskRecord>(
            predicate: #Predicate<BackgroundTaskRecord> {
                $0.status == "pending" && $0.runAt <= now
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        guard let task = (try? ctx.fetch(descriptor))?.first else {
            return false
        }

        // In-flight guard: prevent concurrent processing of same task
        guard !inFlightTaskIds.contains(task.id) else {
            log("[BG_QUEUE] Task \(task.id) already in-flight, skipping")
            return false
        }
        inFlightTaskIds.insert(task.id)
        defer { inFlightTaskIds.remove(task.id) }

        // Atomic: mark running
        task.status = BackgroundTaskRecord.TaskStatus.running.rawValue
        task.attempts += 1
        try? ctx.save()

        // Dispatch by kind
        do {
            switch task.taskKind {
            case .prepareProposalPack:
                try await handlePrepareProposal(payloadRef: task.payloadRef)
            case .mirrorAuditAttestation:
                try await handleMirrorAttestation()
            case .deliverNotification:
                handleDeliverNotification(payloadRef: task.payloadRef)
            case .none:
                throw BackgroundTaskError.unknownKind(task.kind)
            }

            // Atomic: mark completed
            task.status = BackgroundTaskRecord.TaskStatus.completed.rawValue
            task.completedAt = Date()
            try? ctx.save()
            lastProcessedAt = Date()
            refreshCount()
            return true

        } catch {
            // Atomic: mark failed or re-queue
            task.lastError = error.localizedDescription
            if task.canRetry {
                task.status = BackgroundTaskRecord.TaskStatus.pending.rawValue
                // Exponential backoff: 30s, 60s, 120s
                task.runAt = Date().addingTimeInterval(30 * pow(2, Double(task.attempts - 1)))
            } else {
                task.status = BackgroundTaskRecord.TaskStatus.failed.rawValue
            }
            try? ctx.save()
            refreshCount()
            logError("[BG_QUEUE] Task \(task.kind) failed: \(error)")
            return false
        }
    }

    // MARK: - Process All Pending

    public func processAllPending() async -> Int {
        var processed = 0
        while await processNext() {
            processed += 1
        }
        return processed
    }

    // MARK: - Task Handlers

    /// Prepare a ProposalPack via SentinelProposalEngine.
    /// INVARIANT: Only reads + intelligence. No execution. No tokens.
    private func handlePrepareProposal(payloadRef: String) async throws {
        // payloadRef is the intent summary text
        let intent = IntentRequest(rawText: payloadRef, intentType: .unknown)

        // SentinelProposalEngine is read-only intelligence — safe for background
        let pack = await SentinelProposalEngine.shared.generateProposal(
            intent: intent,
            context: nil
        )

        // Evidence log
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "bg_proposal_prepared",
            planId: pack.toolPlan.id,
            jsonString: """
            {"proposalId":"\(pack.id)","intent":"\(payloadRef.prefix(100))","riskTier":"\(pack.riskAnalysis.consequenceTier.rawValue)","preparedAt":"\(Date())"}
            """
        )

        // Deliver local notification
        NotificationBridge.shared.scheduleProposalReady(proposalId: pack.id)
    }

    /// Mirror audit attestation via EvidenceMirror.
    /// INVARIANT: Only reads evidence chain + signs. No execution.
    /// EXACTLY-ONCE: Dedup by chain hash to prevent duplicate pushes.
    private func handleMirrorAttestation() async throws {
        guard let attestation = await EvidenceMirror.shared.createAttestation() else {
            throw BackgroundTaskError.attestationFailed
        }

        // Exactly-once: check if this chain hash was already mirrored
        guard !mirroredChainHashes.contains(attestation.chainHash) else {
            log("[BG_QUEUE] Mirror attestation dedup: chainHash already sent")
            return
        }

        let success = await EvidenceMirrorClient.shared.pushAttestation(attestation)
        if success {
            mirroredChainHashes.insert(attestation.chainHash)
        } else {
            throw BackgroundTaskError.mirrorPushFailed
        }
    }

    /// Deliver a local notification.
    private func handleDeliverNotification(payloadRef: String) {
        NotificationBridge.shared.scheduleGeneric(title: "OperatorKit", body: payloadRef)
    }

    // MARK: - Helpers

    private func refreshCount() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<BackgroundTaskRecord>(
            predicate: #Predicate<BackgroundTaskRecord> { $0.status == "pending" }
        )
        pendingCount = (try? ctx.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Errors

    enum BackgroundTaskError: Error, LocalizedError {
        case unknownKind(String)
        case proposalGenerationFailed
        case attestationFailed
        case mirrorPushFailed

        var errorDescription: String? {
            switch self {
            case .unknownKind(let kind): return "Unknown task kind: \(kind)"
            case .proposalGenerationFailed: return "Sentinel failed to generate ProposalPack"
            case .attestationFailed: return "Failed to create attestation"
            case .mirrorPushFailed: return "Failed to push attestation to mirror"
            }
        }
    }
}
