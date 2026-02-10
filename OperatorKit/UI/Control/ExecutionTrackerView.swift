import SwiftUI

// ============================================================================
// EXECUTION TRACKER — Real-time pipeline visualization
// Driven by CapabilityKernel.currentPhase (KernelPhase enum)
// ============================================================================

struct ExecutionTrackerView: View {
    let phase: KernelPhase

    private let stages: [(id: String, label: String, detail: String, phases: [KernelPhase])] = [
        ("ingest", "Data Ingestion", "Context assembly & classification", [.intake, .classify]),
        ("policy", "Policy Validation", "Risk scoring & compliance check", [.riskScore, .reversibilityCheck, .policyMapping]),
        ("plan", "Execution Planning", "Probes & verification", [.probes]),
        ("dispatch", "Action Dispatch", "Approval & execution", [.approval, .awaitingApproval, .execute, .logEvidence, .complete])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EXECUTION TRACKER")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(OKColor.textSecondary)
                .tracking(1.2)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                    let state = stageState(for: stage.phases)

                    HStack(alignment: .top, spacing: 12) {
                        // Vertical line + indicator
                        VStack(spacing: 0) {
                            Circle()
                                .fill(indicatorColor(for: state))
                                .frame(width: 24, height: 24)
                                .overlay(indicatorIcon(for: state))

                            if index < stages.count - 1 {
                                Rectangle()
                                    .fill(lineColor(for: state))
                                    .frame(width: 2, height: 32)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.label)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(state == .idle ? OKColor.textMuted : OKColor.textPrimary)

                            Text(stageDetail(for: stage, state: state))
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        .padding(.top, 2)

                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(OKColor.backgroundSecondary)
            .cornerRadius(12)
        }
    }

    // MARK: - State Logic

    private enum StageState {
        case completed, active, idle
    }

    private func stageState(for phases: [KernelPhase]) -> StageState {
        if phase == .idle {
            return .idle
        }

        let phaseOrder = allPhaseOrder()
        guard let currentIndex = phaseOrder.firstIndex(of: phase) else { return .idle }

        let stageIndices = phases.compactMap { phaseOrder.firstIndex(of: $0) }
        guard let minIndex = stageIndices.min(), let maxIndex = stageIndices.max() else { return .idle }

        if currentIndex > maxIndex {
            return .completed
        } else if currentIndex >= minIndex {
            return .active
        }
        return .idle
    }

    private func allPhaseOrder() -> [KernelPhase] {
        [.halted, .intake, .classify, .riskScore, .reversibilityCheck, .policyMapping, .probes, .approval, .awaitingApproval, .execute, .logEvidence, .complete]
    }

    private func indicatorColor(for state: StageState) -> Color {
        switch state {
        case .completed: return OKColor.riskNominal
        case .active: return OKColor.riskWarning
        case .idle: return OKColor.textMuted.opacity(0.3)
        }
    }

    private func lineColor(for state: StageState) -> Color {
        switch state {
        case .completed: return OKColor.riskNominal.opacity(0.5)
        case .active: return OKColor.riskWarning.opacity(0.5)
        case .idle: return OKColor.textMuted.opacity(0.2)
        }
    }

    @ViewBuilder
    private func indicatorIcon(for state: StageState) -> some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(OKColor.textPrimary)
        case .active:
            Circle()
                .fill(OKColor.textPrimary)
                .frame(width: 8, height: 8)
        case .idle:
            Circle()
                .fill(OKColor.textMuted.opacity(0.5))
                .frame(width: 6, height: 6)
        }
    }

    private func stageDetail(for stage: (id: String, label: String, detail: String, phases: [KernelPhase]), state: StageState) -> String {
        switch state {
        case .completed: return "Completed"
        case .active: return "Processing..."
        case .idle: return stage.detail
        }
    }
}
