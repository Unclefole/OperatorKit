import Foundation

// ============================================================================
// ACTION HISTORY — Minimal reversible action store for Undo
//
// Records executed side effects with optional reversal closures.
// Only the LAST action can be undone (single-level undo).
//
// INVARIANTS:
// - Only ExecutionEngine writes to this store.
// - Undo calls the reversal closure if one was provided.
// - If no reversal exists → undo is disabled, never faked.
// - All undo events are evidence-logged.
// ============================================================================

@MainActor
final class ActionHistory: ObservableObject {
    static let shared = ActionHistory()

    // MARK: - Types

    struct ActionRecord: Identifiable {
        let id: UUID
        let tool: String
        let summary: String
        let executedAt: Date
        /// Links to the persistent ExecutionRecord for lifecycle tracking.
        let executionRecordId: UUID?
        /// Reversal closure. `nil` means action is irreversible.
        let reversal: (@MainActor () async -> Bool)?

        var isReversible: Bool { reversal != nil }
    }

    // MARK: - State

    @Published private(set) var history: [ActionRecord] = []

    private let maxHistory = 20

    private init() {}

    // MARK: - Record

    /// Record an executed action. Called by ExecutionEngine after side effect.
    func record(
        id: UUID = UUID(),
        tool: String,
        summary: String,
        executionRecordId: UUID? = nil,
        reversal: (@MainActor () async -> Bool)? = nil
    ) {
        let record = ActionRecord(
            id: id,
            tool: tool,
            summary: summary,
            executedAt: Date(),
            executionRecordId: executionRecordId,
            reversal: reversal
        )
        history.append(record)
        if history.count > maxHistory {
            history.removeFirst()
        }
    }

    // MARK: - Undo

    var canUndo: Bool {
        guard let last = history.last else { return false }
        return last.isReversible
    }

    var lastActionSummary: String? {
        history.last?.summary
    }

    /// Attempt to undo the last action.
    /// Returns true if reversal succeeded, false otherwise.
    @discardableResult
    func undoLast() async -> Bool {
        guard let last = history.last, let reversal = last.reversal else {
            return false
        }

        let success = await reversal()

        if success {
            // Mark the persistent ExecutionRecord as reversed
            if let execId = last.executionRecordId {
                ExecutionRecordStore.shared.markReversed(execId)
            }

            history.removeLast()
            // Log undo to evidence
            try? EvidenceEngine.shared.logGenericArtifact(
                type: "undo_action",
                planId: last.id,
                jsonString: "{\"tool\":\"\(last.tool)\",\"summary\":\"\(last.summary)\",\"undoneAt\":\"\(Date())\"}"
            )
        }

        return success
    }

    /// Clear all history (e.g. on emergency stop)
    func clearHistory() {
        history.removeAll()
    }
}
