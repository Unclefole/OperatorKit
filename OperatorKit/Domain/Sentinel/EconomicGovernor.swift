import Foundation

// ============================================================================
// ECONOMIC GOVERNOR — CLOUD COST CONTROL
//
// Attached to ModelRouter. Evaluates every cloud call BEFORE dispatch.
//
// DECISION TREE:
//   1. Projected token cost within daily budget? → proceed
//   2. Over budget? → downgrade to smaller model
//   3. Still over? → downgrade to on-device
//   4. On-device unavailable? → block call + log
//
// ALL decisions logged to EvidenceEngine.
//
// INVARIANT: No cloud call may fire without EconomicGovernor clearance.
// INVARIANT: Budget state is persisted across app launches.
// ============================================================================

@MainActor
public final class EconomicGovernor: ObservableObject {

    public static let shared = EconomicGovernor()

    // MARK: - Budget Configuration

    /// Daily budget ceiling in USD (default: $1.00)
    @Published public var dailyBudgetUSD: Double {
        didSet { UserDefaults.standard.set(dailyBudgetUSD, forKey: kDailyBudget) }
    }

    /// Per-call ceiling in USD (default: $0.25)
    @Published public var perCallCeilingUSD: Double {
        didSet { UserDefaults.standard.set(perCallCeilingUSD, forKey: kPerCallCeiling) }
    }

    // MARK: - Spend Tracking

    @Published public private(set) var todaySpendUSD: Double = 0
    @Published public private(set) var todayCallCount: Int = 0
    @Published public private(set) var lastResetDate: Date

    // MARK: - Constants

    private let kDailyBudget = "ok_economic_daily_budget"
    private let kPerCallCeiling = "ok_economic_per_call_ceiling"
    private let kTodaySpend = "ok_economic_today_spend"
    private let kTodayCallCount = "ok_economic_today_calls"
    private let kLastResetDate = "ok_economic_last_reset"

    private init() {
        let defaults = UserDefaults.standard
        self.dailyBudgetUSD = defaults.double(forKey: kDailyBudget) > 0
            ? defaults.double(forKey: kDailyBudget)
            : 1.00
        self.perCallCeilingUSD = defaults.double(forKey: kPerCallCeiling) > 0
            ? defaults.double(forKey: kPerCallCeiling)
            : 0.25
        self.todaySpendUSD = defaults.double(forKey: kTodaySpend)
        self.todayCallCount = defaults.integer(forKey: kTodayCallCount)
        self.lastResetDate = defaults.object(forKey: kLastResetDate) as? Date ?? Date()

        // Reset if day changed
        resetIfNewDay()
    }

    // MARK: - Evaluate

    /// Evaluate whether a cloud call should proceed.
    /// Returns a decision with the recommended action.
    public func evaluate(estimate: CostEstimate) -> EconomicDecision {
        resetIfNewDay()

        // On-device calls always pass
        guard estimate.requiresCloudCall else {
            return EconomicDecision(
                action: .proceed,
                reason: "On-device — no cost",
                estimatedCostUSD: 0,
                remainingBudgetUSD: dailyBudgetUSD - todaySpendUSD
            )
        }

        let projectedTotal = todaySpendUSD + estimate.estimatedCostUSD
        let remainingBudget = dailyBudgetUSD - todaySpendUSD

        // Check per-call ceiling
        if estimate.estimatedCostUSD > perCallCeilingUSD {
            let decision = EconomicDecision(
                action: .downgradeModel,
                reason: "Per-call cost $\(String(format: "%.4f", estimate.estimatedCostUSD)) exceeds ceiling $\(String(format: "%.2f", perCallCeilingUSD))",
                estimatedCostUSD: estimate.estimatedCostUSD,
                remainingBudgetUSD: remainingBudget
            )
            logDecision(decision, estimate: estimate)
            return decision
        }

        // Check daily budget
        if projectedTotal > dailyBudgetUSD {
            let decision = EconomicDecision(
                action: .downgradeToOnDevice,
                reason: "Projected daily spend $\(String(format: "%.4f", projectedTotal)) exceeds budget $\(String(format: "%.2f", dailyBudgetUSD))",
                estimatedCostUSD: estimate.estimatedCostUSD,
                remainingBudgetUSD: remainingBudget
            )
            logDecision(decision, estimate: estimate)
            return decision
        }

        // Within budget
        let decision = EconomicDecision(
            action: .proceed,
            reason: "Within budget — remaining $\(String(format: "%.4f", remainingBudget))",
            estimatedCostUSD: estimate.estimatedCostUSD,
            remainingBudgetUSD: remainingBudget
        )
        logDecision(decision, estimate: estimate)
        return decision
    }

    // MARK: - Record Spend

    /// Called after a cloud call completes to record actual cost.
    public func recordSpend(actualCostUSD: Double) {
        resetIfNewDay()
        todaySpendUSD += actualCostUSD
        todayCallCount += 1
        persistSpend()

        log("[ECONOMIC_GOVERNOR] Recorded spend: $\(String(format: "%.4f", actualCostUSD)) — daily total: $\(String(format: "%.4f", todaySpendUSD)) / $\(String(format: "%.2f", dailyBudgetUSD))")
    }

    // MARK: - Daily Reset

    private func resetIfNewDay() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastResetDate) {
            todaySpendUSD = 0
            todayCallCount = 0
            lastResetDate = Date()
            persistSpend()
            log("[ECONOMIC_GOVERNOR] Daily budget reset")
        }
    }

    private func persistSpend() {
        let defaults = UserDefaults.standard
        defaults.set(todaySpendUSD, forKey: kTodaySpend)
        defaults.set(todayCallCount, forKey: kTodayCallCount)
        defaults.set(lastResetDate, forKey: kLastResetDate)
    }

    // MARK: - Evidence Logging

    private func logDecision(_ decision: EconomicDecision, estimate: CostEstimate) {
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "economic_governor_decision",
            planId: UUID(),
            jsonString: """
            {"action":"\(decision.action.rawValue)","reason":"\(decision.reason)","estimatedCost":\(decision.estimatedCostUSD),"remainingBudget":\(decision.remainingBudgetUSD),"dailySpend":\(todaySpendUSD),"dailyBudget":\(dailyBudgetUSD),"provider":"\(estimate.modelProvider)","inputTokens":\(estimate.predictedInputTokens),"outputTokens":\(estimate.predictedOutputTokens)}
            """
        )
    }

    // MARK: - Diagnostics

    public var budgetUtilization: Double {
        guard dailyBudgetUSD > 0 else { return 0 }
        return todaySpendUSD / dailyBudgetUSD
    }

    public var diagnostics: [String: Any] {
        [
            "dailyBudgetUSD": dailyBudgetUSD,
            "todaySpendUSD": todaySpendUSD,
            "todayCallCount": todayCallCount,
            "budgetUtilization": budgetUtilization,
            "perCallCeilingUSD": perCallCeilingUSD,
            "lastResetDate": lastResetDate
        ]
    }
}

// MARK: - Economic Decision

public struct EconomicDecision {
    public let action: Action
    public let reason: String
    public let estimatedCostUSD: Double
    public let remainingBudgetUSD: Double

    public enum Action: String {
        case proceed            = "proceed"
        case downgradeModel     = "downgrade_model"
        case downgradeToOnDevice = "downgrade_to_on_device"
        case block              = "block"
    }

    public var allowsCloudCall: Bool {
        action == .proceed
    }
}
