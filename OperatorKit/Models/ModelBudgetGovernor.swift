import Foundation
import os.log

// ============================================================================
// MODEL BUDGET GOVERNOR — HARD GATE FOR COST CONTROL
//
// Extends EconomicGovernor with per-task and per-session budgets.
// Every model call MUST pass through this gate before dispatch.
//
// INVARIANT: Budget denial → FAIL CLOSED + Evidence entry.
// INVARIANT: Spend is persisted and survives app restart.
// INVARIANT: No model call may fire without BudgetGovernor clearance.
// ============================================================================

// MARK: - Allowance Decision

public struct BudgetAllowanceDecision: Sendable {
    public let allowed: Bool
    public let reason: String
    public let estimatedCostCents: Double
    public let remainingTaskBudgetCents: Double
    public let remainingDailyBudgetCents: Double
    public let recommendedCostTier: ModelCostTier?

    public static func allow(
        estimatedCostCents: Double,
        remainingTaskBudget: Double,
        remainingDailyBudget: Double
    ) -> BudgetAllowanceDecision {
        BudgetAllowanceDecision(
            allowed: true,
            reason: "Within budget",
            estimatedCostCents: estimatedCostCents,
            remainingTaskBudgetCents: remainingTaskBudget,
            remainingDailyBudgetCents: remainingDailyBudget,
            recommendedCostTier: nil
        )
    }

    public static func deny(
        reason: String,
        estimatedCostCents: Double,
        remainingTaskBudget: Double,
        remainingDailyBudget: Double,
        recommendedCostTier: ModelCostTier? = nil
    ) -> BudgetAllowanceDecision {
        BudgetAllowanceDecision(
            allowed: false,
            reason: reason,
            estimatedCostCents: estimatedCostCents,
            remainingTaskBudgetCents: remainingTaskBudget,
            remainingDailyBudgetCents: remainingDailyBudget,
            recommendedCostTier: recommendedCostTier
        )
    }
}

// MARK: - Budget Governor

@MainActor
public final class ModelBudgetGovernor: ObservableObject {

    public static let shared = ModelBudgetGovernor()

    private static let logger = Logger(subsystem: "com.operatorkit", category: "BudgetGovernor")

    // ── Per-org daily cap (cents) ───────────────────────────
    @Published public var perOrgDailyCapCents: Double {
        didSet { UserDefaults.standard.set(perOrgDailyCapCents, forKey: kOrgDailyCap) }
    }

    // ── Per-session cap (cents, resets each app launch) ─────
    @Published public var perSessionCapCents: Double {
        didSet { UserDefaults.standard.set(perSessionCapCents, forKey: kSessionCap) }
    }

    // ── Per-task daily caps (overrides defaults if set) ─────
    @Published public private(set) var taskOverrides: [String: Int] = [:]

    // ── Spend tracking ──────────────────────────────────────
    @Published public private(set) var dailySpendByTaskCents: [String: Double] = [:]
    @Published public private(set) var sessionSpendCents: Double = 0
    @Published public private(set) var dailyTotalSpendCents: Double = 0
    @Published public private(set) var dailyCallCount: Int = 0
    @Published public private(set) var lastResetDate: Date

    // ── Constants ───────────────────────────────────────────
    private let kOrgDailyCap    = "ok_budget_org_daily_cap_cents"
    private let kSessionCap     = "ok_budget_session_cap_cents"
    private let kDailySpend     = "ok_budget_daily_spend_cents"
    private let kDailyCallCount = "ok_budget_daily_call_count"
    private let kLastReset      = "ok_budget_last_reset"
    private let kTaskSpend      = "ok_budget_task_spend"

    private init() {
        let d = UserDefaults.standard
        self.perOrgDailyCapCents = d.double(forKey: kOrgDailyCap) > 0
            ? d.double(forKey: kOrgDailyCap)
            : 100.0  // $1.00 default
        self.perSessionCapCents = d.double(forKey: kSessionCap) > 0
            ? d.double(forKey: kSessionCap)
            : 50.0   // $0.50 default per session
        self.dailyTotalSpendCents = d.double(forKey: kDailySpend)
        self.dailyCallCount = d.integer(forKey: kDailyCallCount)
        self.lastResetDate = d.object(forKey: kLastReset) as? Date ?? Date()

        // Restore task spend
        if let data = d.data(forKey: kTaskSpend),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            self.dailySpendByTaskCents = decoded
        }

        resetIfNewDay()
    }

    // MARK: - Request Allowance

    /// Ask whether a model call with estimated cost is allowed.
    /// Returns allow/deny with reason. Deny = FAIL CLOSED.
    public func requestAllowance(
        taskType: ModelTaskType,
        estimatedCostCents: Double
    ) -> BudgetAllowanceDecision {
        resetIfNewDay()

        // 0. On-device (free) always passes
        if estimatedCostCents <= 0 {
            return .allow(
                estimatedCostCents: 0,
                remainingTaskBudget: taskRemainingCents(taskType),
                remainingDailyBudget: dailyRemainingCents
            )
        }

        let taskKey = taskType.rawValue
        let taskSpent = dailySpendByTaskCents[taskKey] ?? 0
        let taskCap = Double(taskOverrides[taskKey] ?? taskType.defaultBudgetCents * 20)
        // Per-task daily cap = 20x single-call default (allows ~20 calls per task type/day)
        let taskRemaining = taskCap - taskSpent

        // 1. Per-task daily cap
        if estimatedCostCents > taskRemaining {
            let decision = BudgetAllowanceDecision.deny(
                reason: "Task '\(taskType.displayName)' daily budget exhausted (\(fmt(taskSpent))¢ / \(fmt(taskCap))¢)",
                estimatedCostCents: estimatedCostCents,
                remainingTaskBudget: taskRemaining,
                remainingDailyBudget: dailyRemainingCents,
                recommendedCostTier: .free
            )
            logDenial(decision, taskType: taskType)
            return decision
        }

        // 2. Per-session cap
        if sessionSpendCents + estimatedCostCents > perSessionCapCents {
            let decision = BudgetAllowanceDecision.deny(
                reason: "Session budget exhausted (\(fmt(sessionSpendCents))¢ / \(fmt(perSessionCapCents))¢)",
                estimatedCostCents: estimatedCostCents,
                remainingTaskBudget: taskRemaining,
                remainingDailyBudget: dailyRemainingCents,
                recommendedCostTier: .free
            )
            logDenial(decision, taskType: taskType)
            return decision
        }

        // 3. Per-org daily cap
        if dailyTotalSpendCents + estimatedCostCents > perOrgDailyCapCents {
            let decision = BudgetAllowanceDecision.deny(
                reason: "Org daily budget exhausted (\(fmt(dailyTotalSpendCents))¢ / \(fmt(perOrgDailyCapCents))¢)",
                estimatedCostCents: estimatedCostCents,
                remainingTaskBudget: taskRemaining,
                remainingDailyBudget: dailyRemainingCents,
                recommendedCostTier: .free
            )
            logDenial(decision, taskType: taskType)
            return decision
        }

        // Allowed
        return .allow(
            estimatedCostCents: estimatedCostCents,
            remainingTaskBudget: taskRemaining,
            remainingDailyBudget: dailyRemainingCents
        )
    }

    // MARK: - Record Spend

    /// Record actual spend after a model call completes.
    public func recordSpend(
        taskType: ModelTaskType,
        actualCostCents: Double,
        provider: ModelProvider,
        modelId: String
    ) {
        resetIfNewDay()

        let taskKey = taskType.rawValue
        dailySpendByTaskCents[taskKey, default: 0] += actualCostCents
        dailyTotalSpendCents += actualCostCents
        sessionSpendCents += actualCostCents
        dailyCallCount += 1

        persist()

        // Evidence
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "model_budget_spend",
            planId: UUID(),
            jsonString: """
            {"taskType":"\(taskKey)","costCents":\(actualCostCents),"provider":"\(provider.rawValue)","modelId":"\(modelId)","dailyTotal":\(dailyTotalSpendCents),"sessionTotal":\(sessionSpendCents),"callCount":\(dailyCallCount)}
            """
        )

        Self.logger.info("Budget spend: \(self.fmt(actualCostCents))¢ for \(taskKey) via \(provider.rawValue). Daily: \(self.fmt(self.dailyTotalSpendCents))¢/\(self.fmt(self.perOrgDailyCapCents))¢")
    }

    // MARK: - Task Budget Override

    /// Set a custom per-task daily cap in cents.
    public func setTaskCap(_ taskType: ModelTaskType, capCents: Int) {
        taskOverrides[taskType.rawValue] = capCents
    }

    // MARK: - Helpers

    public var dailyRemainingCents: Double {
        max(0, perOrgDailyCapCents - dailyTotalSpendCents)
    }

    public var sessionRemainingCents: Double {
        max(0, perSessionCapCents - sessionSpendCents)
    }

    public func taskRemainingCents(_ taskType: ModelTaskType) -> Double {
        let taskKey = taskType.rawValue
        let taskSpent = dailySpendByTaskCents[taskKey] ?? 0
        let taskCap = Double(taskOverrides[taskKey] ?? taskType.defaultBudgetCents * 20)
        return max(0, taskCap - taskSpent)
    }

    public var budgetUtilization: Double {
        guard perOrgDailyCapCents > 0 else { return 0 }
        return dailyTotalSpendCents / perOrgDailyCapCents
    }

    private func fmt(_ v: Double) -> String { String(format: "%.2f", v) }

    // MARK: - Persistence

    private func resetIfNewDay() {
        let cal = Calendar.current
        guard !cal.isDateInToday(lastResetDate) else { return }
        dailySpendByTaskCents = [:]
        dailyTotalSpendCents = 0
        dailyCallCount = 0
        lastResetDate = Date()
        // Session spend intentionally NOT reset (per-launch)
        persist()
        Self.logger.info("Budget daily reset")
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(dailyTotalSpendCents, forKey: kDailySpend)
        d.set(dailyCallCount, forKey: kDailyCallCount)
        d.set(lastResetDate, forKey: kLastReset)
        if let data = try? JSONEncoder().encode(dailySpendByTaskCents) {
            d.set(data, forKey: kTaskSpend)
        }
    }

    // MARK: - Evidence

    private func logDenial(_ decision: BudgetAllowanceDecision, taskType: ModelTaskType) {
        Self.logger.warning("Budget DENIED: \(decision.reason)")
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "model_budget_denied",
            planId: UUID(),
            jsonString: """
            {"taskType":"\(taskType.rawValue)","reason":"\(decision.reason)","estimatedCost":\(decision.estimatedCostCents),"dailyRemaining":\(decision.remainingDailyBudgetCents),"taskRemaining":\(decision.remainingTaskBudgetCents)}
            """
        )
    }
}
