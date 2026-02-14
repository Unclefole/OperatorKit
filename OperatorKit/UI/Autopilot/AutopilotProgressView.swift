import SwiftUI

// ============================================================================
// AUTOPILOT PROGRESS VIEW — LIVE PIPELINE UI
//
// Shows the autopilot state machine progressing through:
//   Intent → Context → Proposal → Draft → Approval
//
// Auto-navigates to ApprovalView when readyForApproval.
// Shows FailClosedView on error.
// "Stop" button triggers abort + returns to idle.
//
// INVARIANT: This view NEVER calls ExecutionEngine or mints tokens.
// ============================================================================

struct AutopilotProgressView: View {
    @StateObject private var orchestrator = AutopilotOrchestrator.shared
    @Environment(\.dismiss) private var dismiss

    @State private var hasNavigatedToApproval = false
    @State private var showProposalReview = false

    var body: some View {
        ZStack {
            OKColor.backgroundPrimary.ignoresSafeArea()

            if orchestrator.state == .halted, let reason = orchestrator.errorReason {
                // FAIL CLOSED
                FailClosedView(
                    context: "Autopilot",
                    reason: reason,
                    suggestion: "Go back and try again, or run the skill manually."
                )
            } else if orchestrator.state == .readyForApproval {
                // SUCCESS — show proposal summary + approval trigger
                readyForApprovalView
            } else {
                // IN PROGRESS
                progressView
            }
        }
        .navigationTitle("Autopilot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if orchestrator.state != .idle && orchestrator.state != .readyForApproval {
                    Button("Stop") {
                        orchestrator.abort()
                    }
                    .foregroundStyle(OKColor.emergencyStop)
                    .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showProposalReview) {
            if let proposal = orchestrator.proposal, let session = orchestrator.session {
                NavigationStack {
                    ProposalReviewPanel(
                        proposal: proposal,
                        session: session,
                        onDecision: { decision in
                            handleDecision(decision, session: session)
                        }
                    )
                    .navigationTitle("Approval Required")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Dismiss") { showProposalReview = false }
                                .foregroundStyle(OKColor.textSecondary)
                        }
                    }
                }
                .presentationDetents([.large])
            } else {
                FailClosedView(
                    context: "AutopilotProgressView.sheet",
                    reason: "Proposal or session is nil when approval sheet opened."
                )
            }
        }
        .onDisappear {
            // If user navigates away, reset so next run starts clean
            if orchestrator.state == .halted || orchestrator.state == .readyForApproval {
                orchestrator.reset()
            }
        }
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated indicator
            ZStack {
                Circle()
                    .stroke(OKColor.borderSubtle, lineWidth: 3)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: orchestrator.progress)
                    .stroke(OKColor.actionPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: orchestrator.progress)

                Image(systemName: iconForState(orchestrator.state))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(OKColor.actionPrimary)
            }

            // Status message
            Text(orchestrator.statusMessage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OKColor.textPrimary)
                .multilineTextAlignment(.center)

            // Step indicators
            stepsIndicator

            Spacer()

            // Percentage
            Text("\(Int(orchestrator.progress * 100))%")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(OKColor.textMuted)
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }

    private var stepsIndicator: some View {
        VStack(spacing: 12) {
            stepRow("Parse Intent", state: stepState(for: .receivedIntent))
            stepRow("Gather Context", state: stepState(for: .gatheringContext))
            stepRow("Generate Proposal", state: stepState(for: .generatingProposal))
            stepRow("Prepare Draft", state: stepState(for: .generatingDraft))
            stepRow("Approval Required", state: stepState(for: .readyForApproval))
        }
        .padding(16)
        .background(OKColor.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(OKColor.borderSubtle, lineWidth: 1)
        )
        .cornerRadius(14)
    }

    private func stepRow(_ label: String, state: StepState) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(state.backgroundColor)
                    .frame(width: 24, height: 24)
                Image(systemName: state.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(state.iconColor)
            }

            Text(label)
                .font(.system(size: 14, weight: state == .active ? .semibold : .regular))
                .foregroundStyle(state == .pending ? OKColor.textMuted : OKColor.textPrimary)

            Spacer()

            if state == .active {
                ProgressView()
                    .tint(OKColor.actionPrimary)
                    .scaleEffect(0.7)
            }
        }
    }

    // MARK: - Ready For Approval

    private var readyForApprovalView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success indicator
            ZStack {
                Circle()
                    .fill(OKColor.riskNominal.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(OKColor.riskNominal)
            }

            Text("Proposal Ready")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(OKColor.textPrimary)

            if let proposal = orchestrator.proposal {
                // Summary card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        riskBadge(proposal.riskAnalysis.consequenceTier)
                        Spacer()
                        Text("\(proposal.toolPlan.executionSteps.count) steps")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(OKColor.textMuted)
                    }

                    Text(proposal.humanSummary)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(OKColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Label("\(proposal.toolPlan.requiredApprovals.multiSignerCount) signer(s)", systemImage: "person.badge.shield.checkmark")
                            .font(.system(size: 12))
                            .foregroundStyle(OKColor.textSecondary)
                        Spacer()
                        Text(proposal.riskAnalysis.reversibilityClass.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(OKColor.riskNominal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(OKColor.riskNominal.opacity(0.12))
                            .cornerRadius(6)
                    }
                }
                .okCard()

                // ── Research Brief Preview (if enriched draft available) ──
                if let briefBody = orchestrator.enrichedDraftBody, !briefBody.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass.circle.fill")
                                .foregroundStyle(OKColor.actionPrimary)
                            Text("Research Brief Draft")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(OKColor.textPrimary)
                            Spacer()
                            Text("INTERNAL ONLY")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(OKColor.riskWarning)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(OKColor.riskWarning.opacity(0.12))
                                .cornerRadius(4)
                        }

                        ScrollView {
                            Text(briefBody)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(OKColor.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxHeight: 300)

                        // Safety footer
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(OKColor.riskOperational)
                            Text("Draft for internal review only. Verify data against primary sources. Stopped before external distribution.")
                                .font(.system(size: 10))
                                .foregroundStyle(OKColor.textMuted)
                        }
                    }
                    .padding(14)
                    .background(OKColor.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(OKColor.borderSubtle, lineWidth: 1)
                    )
                    .cornerRadius(14)
                }
            }

            Spacer()

            // Approval button
            Button {
                showProposalReview = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                    Text("Review & Approve")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(OKColor.actionPrimary)
                .cornerRadius(14)
            }

            Button {
                orchestrator.reset()
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OKColor.textMuted)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Decision Handling

    private func handleDecision(_ decision: ApprovalSession.Decision, session: ApprovalSession) {
        ApprovalSessionStore.shared.recordDecision(session.id, decision: decision)
        showProposalReview = false

        switch decision {
        case .approve, .approvePartial:
            // Navigate to normal execution flow — the existing kernel gates handle execution
            orchestrator.reset()
            dismiss()
        case .reject, .requestRevision, .escalate:
            orchestrator.reset()
            dismiss()
        }
    }

    // MARK: - Helpers

    private enum StepState {
        case pending, active, complete

        var icon: String {
            switch self {
            case .pending: return ""
            case .active: return "ellipsis"
            case .complete: return "checkmark"
            }
        }

        var backgroundColor: Color {
            switch self {
            case .pending: return OKColor.backgroundTertiary
            case .active: return OKColor.actionPrimary.opacity(0.2)
            case .complete: return OKColor.riskNominal.opacity(0.2)
            }
        }

        var iconColor: Color {
            switch self {
            case .pending: return OKColor.textMuted
            case .active: return OKColor.actionPrimary
            case .complete: return OKColor.riskNominal
            }
        }
    }

    private func stepState(for target: AutopilotState) -> StepState {
        let order: [AutopilotState] = [.receivedIntent, .gatheringContext, .generatingProposal, .generatingDraft, .readyForApproval]
        guard let currentIdx = order.firstIndex(of: orchestrator.state),
              let targetIdx = order.firstIndex(of: target) else {
            return .pending
        }

        if targetIdx < currentIdx { return .complete }
        if targetIdx == currentIdx { return .active }
        return .pending
    }

    private func iconForState(_ state: AutopilotState) -> String {
        switch state {
        case .idle: return "circle"
        case .receivedIntent: return "text.magnifyingglass"
        case .gatheringContext: return "square.stack.3d.up"
        case .generatingProposal: return "brain.head.profile"
        case .generatingDraft: return "doc.text"
        case .readyForApproval: return "checkmark.shield"
        case .halted: return "exclamationmark.triangle"
        }
    }

    private func riskBadge(_ tier: RiskTier) -> some View {
        let color: Color = {
            switch tier {
            case .low: return OKColor.riskNominal
            case .medium: return OKColor.riskOperational
            case .high: return OKColor.riskWarning
            case .critical: return OKColor.riskCritical
            }
        }()

        return Text(tier.rawValue)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(6)
    }
}
