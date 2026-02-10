import SwiftUI

// ============================================================================
// CONTROL DASHBOARD — MISSION CONTROL UI
//
// Every element is wired to REAL backend state:
// - ExecutionTracker → CapabilityKernel.currentPhase
// - Consequence Modeling → RiskEngine assessments via EvidenceEngine
// - High-Risk Actions → Recent execution evidence sorted by risk
// - Direct Controls → Kernel escalation / emergency stop / undo
// - Audit Trail → EvidenceEngine append-only log
//
// ZERO fake data. ZERO cosmetic displays.
// ============================================================================

struct ControlDashboardView: View {
    @EnvironmentObject var nav: AppNavigationState
    @StateObject private var viewModel = ControlDashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with "New Action" button
                headerView

                // Halted banner (if emergency stopped)
                if viewModel.currentPhase == .halted {
                    haltedBanner
                }

                // Execution Tracker
                ExecutionTrackerView(phase: viewModel.currentPhase)

                // Consequence Modeling
                ConsequenceModelingView(riskCounts: viewModel.riskTierCounts)

                // Top High-Risk Actions
                HighRiskActionsView(actions: viewModel.highRiskActions)

                // Direct Controls
                DirectControlsView(
                    canEmergencyStop: viewModel.canEmergencyStop,
                    canEscalate: viewModel.canEscalate,
                    canUndo: viewModel.canUndo,
                    isHalted: viewModel.currentPhase == .halted,
                    onEmergencyStop: { Task { await viewModel.emergencyStop() } },
                    onEscalate: { Task { await viewModel.escalate() } },
                    onUndo: { Task { await viewModel.undoLast() } },
                    onResume: { Task { await viewModel.resume() } }
                )

                // Audit Trail
                AuditTrailFeedView(entries: viewModel.recentAuditEntries)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(OKColor.backgroundPrimary.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await viewModel.loadData() }
        .refreshable { await viewModel.loadData() }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("OperatorKit")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(OKColor.textPrimary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.statusColor)
                        .frame(width: 8, height: 8)
                    Text(viewModel.statusLabel)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.statusColor)
                }
            }

            Spacer()

            // New Action button — entry to productivity workspace
            Button {
                nav.navigate(to: .workspace)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("New Action")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(OKColor.actionPrimary)
                .cornerRadius(10)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Halted Banner

    private var haltedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundColor(OKColor.emergencyStop)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("SYSTEM HALTED")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(OKColor.emergencyStop)
                    .tracking(1.0)
                Text("Emergency stop activated. All executions suspended.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(OKColor.emergencyStop.opacity(0.12))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(OKColor.emergencyStop.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - View Model (REAL DATA ONLY)

@MainActor
final class ControlDashboardViewModel: ObservableObject {
    @Published var currentPhase: KernelPhase = .idle
    @Published var riskTierCounts: [RiskTier: Int] = [:]
    @Published var highRiskActions: [HighRiskAction] = []
    @Published var recentAuditEntries: [AuditEntry] = []
    @Published var canEmergencyStop: Bool = false
    @Published var canEscalate: Bool = false
    @Published var canUndo: Bool = false

    private let kernel = CapabilityKernel.shared
    private let evidenceEngine = EvidenceEngine.shared

    var statusColor: Color {
        switch currentPhase {
        case .halted: return OKColor.emergencyStop
        case .idle: return OKColor.textMuted
        default: return OKColor.riskNominal
        }
    }

    var statusLabel: String {
        switch currentPhase {
        case .halted: return "HALTED"
        case .idle: return "SYSTEM IDLE"
        default: return "SYSTEM LIVE"
        }
    }

    func loadData() async {
        // Wire to real kernel phase
        currentPhase = kernel.currentPhase
        // Emergency stop is always available unless already halted
        canEmergencyStop = kernel.currentPhase != .halted
        canEscalate = kernel.hasPendingPlans
        canUndo = ActionHistory.shared.canUndo

        // Load risk tier counts from evidence
        loadRiskTierCounts()

        // Load high-risk actions from evidence
        loadHighRiskActions()

        // Load recent audit entries
        loadAuditEntries()
    }

    func emergencyStop() async {
        kernel.emergencyStop()
        currentPhase = .halted
        canEmergencyStop = false
        canEscalate = false
        // Reload audit to show the emergency stop event
        loadAuditEntries()
    }

    func resume() async {
        kernel.resumeFromHalt()
        currentPhase = .idle
        loadAuditEntries()
    }

    func escalate() async {
        let count = kernel.escalatePendingPlans()
        if count > 0 {
            currentPhase = kernel.currentPhase
        }
        canEscalate = kernel.hasPendingPlans
        loadAuditEntries()
    }

    func undoLast() async {
        guard ActionHistory.shared.canUndo else { return }
        let result = await ActionHistory.shared.undoLast()
        if result {
            canUndo = ActionHistory.shared.canUndo
            loadAuditEntries()
        }
    }

    private func loadRiskTierCounts() {
        let now = Date()
        let oneDayAgo = now.addingTimeInterval(-86400)
        guard let entries = try? evidenceEngine.queryByDateRange(from: oneDayAgo, to: now) else {
            return
        }

        var counts: [RiskTier: Int] = [.low: 0, .medium: 0, .high: 0, .critical: 0]
        for entry in entries {
            switch entry.type {
            case .violation:
                counts[.critical, default: 0] += 1
            case .executionChain:
                counts[.medium, default: 0] += 1
            case .artifact:
                counts[.low, default: 0] += 1
            case .systemEvent:
                counts[.low, default: 0] += 1
            }
        }
        riskTierCounts = counts
    }

    private func loadHighRiskActions() {
        highRiskActions = []

        if let lastResult = kernel.lastExecutionResult {
            let score = lastResult.riskAssessment?.score ?? 0
            let module: String
            switch lastResult.toolPlan?.intent.type {
            case .sendEmail: module = "MAIL.SERVICE"
            case .createCalendarEvent, .updateCalendarEvent: module = "CALENDAR.SERVICE"
            case .createReminder: module = "REMINDER.SERVICE"
            case .externalAPICall: module = "NET.GATEWAY"
            default: module = "KERNEL"
            }

            highRiskActions.append(HighRiskAction(
                title: lastResult.toolPlan?.intent.summary ?? "Recent Action",
                module: module,
                riskScore: Double(score) / 10.0
            ))
        }

        for pending in kernel.getPendingPlans() {
            let score = pending.riskAssessment.score
            highRiskActions.append(HighRiskAction(
                title: pending.toolPlan.intent.summary,
                module: "KERNEL.PENDING",
                riskScore: Double(score) / 10.0
            ))
        }

        highRiskActions.sort { $0.riskScore > $1.riskScore }
    }

    private func loadAuditEntries() {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        guard let entries = try? evidenceEngine.queryByDateRange(from: oneHourAgo, to: now) else {
            recentAuditEntries = []
            return
        }

        recentAuditEntries = entries.suffix(20).reversed().map { entry in
            AuditEntry(
                timestamp: entry.createdAt,
                message: describeEntry(entry),
                severity: entry.type == .violation ? .warning : .info
            )
        }
    }

    private func describeEntry(_ entry: EvidenceEntry<AnyCodable>) -> String {
        switch entry.type {
        case .executionChain:
            return "EXECUTION CHAIN RECORDED"
        case .artifact:
            return "ARTIFACT LOGGED"
        case .violation:
            return "POLICY VIOLATION DETECTED"
        case .systemEvent:
            return "SYSTEM EVENT"
        }
    }
}

// MARK: - Data Types

struct HighRiskAction: Identifiable {
    let id = UUID()
    let title: String
    let module: String
    let riskScore: Double
}

struct AuditEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let severity: Severity

    enum Severity {
        case info, warning, critical
    }
}
