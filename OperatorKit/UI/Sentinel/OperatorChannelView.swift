import SwiftUI

// ============================================================================
// OPERATOR CHANNEL VIEW — HIGH-AUTHORITY PROPOSAL SURFACE
//
// NOT chat. A structured proposal + approval interface.
//
// FLOW:
//   Intent submitted → Sentinel generates ProposalPack → Proposal Card shown
//   → Human reviews → Human decides → Kernel processes decision
//
// INVARIANT: Approval NEVER skipped.
// ============================================================================

struct OperatorChannelView: View {
    @StateObject private var channel = OperatorChannel.shared
    @StateObject private var kernel = CapabilityKernel.shared

    @State private var inputText: String = ""
    @State private var selectedIntentType: IntentRequest.IntentType = .draftEmail
    @State private var showingProposal = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Channel State Banner
                channelStateBanner

                ScrollView {
                    VStack(spacing: OKSpacing.lg) {
                        // Active Proposal
                        if let proposal = channel.pendingProposal,
                           let session = channel.activeSession {
                            ProposalReviewPanel(
                                proposal: proposal,
                                session: session,
                                onDecision: handleDecision
                            )
                        } else {
                            // Intent Input
                            intentInputSection
                        }

                        // History
                        if !channel.history.isEmpty {
                            historySection
                        }
                    }
                    .padding(OKSpacing.md)
                }
            }
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Operator Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if channel.channelState == .generatingProposal {
                        ProgressView()
                            .tint(OKColor.actionPrimary)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Channel State Banner

    private var channelStateBanner: some View {
        HStack(spacing: OKSpacing.sm) {
            Circle()
                .fill(channelStateColor)
                .frame(width: 8, height: 8)
            Text(channelStateLabel)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(OKColor.textSecondary)
            Spacer()
            Text("SENTINEL")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(OKColor.actionPrimary)
        }
        .padding(.horizontal, OKSpacing.md)
        .padding(.vertical, OKSpacing.sm)
        .background(OKColor.backgroundSecondary)
    }

    private var channelStateColor: Color {
        switch channel.channelState {
        case .idle: return OKColor.textMuted
        case .generatingProposal: return OKColor.riskOperational
        case .awaitingApproval: return OKColor.riskWarning
        case .approved: return OKColor.riskNominal
        case .rejected: return OKColor.riskCritical
        }
    }

    private var channelStateLabel: String {
        switch channel.channelState {
        case .idle: return "READY"
        case .generatingProposal: return "GENERATING PROPOSAL..."
        case .awaitingApproval: return "AWAITING APPROVAL"
        case .approved: return "APPROVED — EXECUTING"
        case .rejected: return "REJECTED"
        }
    }

    // MARK: - Intent Input

    private var intentInputSection: some View {
        VStack(spacing: OKSpacing.md) {
            // Intent type picker
            VStack(alignment: .leading, spacing: OKSpacing.sm) {
                Text("ACTION TYPE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(OKColor.textMuted)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: OKSpacing.sm) {
                        intentChip(.draftEmail, icon: "envelope", label: "Draft Email")
                        intentChip(.createReminder, icon: "checklist", label: "Reminder")
                        intentChip(.summarizeMeeting, icon: "calendar", label: "Meeting")
                        intentChip(.reviewDocument, icon: "doc.text", label: "Document")
                    }
                }
            }

            // Text input
            VStack(alignment: .leading, spacing: OKSpacing.sm) {
                Text("DESCRIBE INTENT")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(OKColor.textMuted)

                TextField("What do you want to do?", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(OKColor.textPrimary)
                    .padding(OKSpacing.md)
                    .background(OKColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: OKRadius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: OKRadius.card)
                            .stroke(OKColor.borderSubtle, lineWidth: 1)
                    )
                    .lineLimit(3...6)
            }

            // Submit
            Button {
                submitIntent()
            } label: {
                HStack {
                    Image(systemName: "shield.checkered")
                    Text("Generate Proposal")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(inputText.isEmpty ? OKColor.backgroundTertiary : OKColor.actionPrimary)
                .foregroundStyle(inputText.isEmpty ? OKColor.textMuted : .white)
                .clipShape(RoundedRectangle(cornerRadius: OKRadius.button))
            }
            .disabled(inputText.isEmpty || channel.channelState == .generatingProposal)
        }
        .padding(OKSpacing.md)
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OKRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: OKRadius.card)
                .stroke(OKColor.borderSubtle, lineWidth: 1)
        )
    }

    private func intentChip(
        _ type: IntentRequest.IntentType,
        icon: String,
        label: String
    ) -> some View {
        Button {
            selectedIntentType = type
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selectedIntentType == type ? OKColor.actionPrimary.opacity(0.2) : OKColor.backgroundTertiary)
            .foregroundStyle(selectedIntentType == type ? OKColor.actionPrimary : OKColor.textSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    selectedIntentType == type ? OKColor.actionPrimary.opacity(0.5) : OKColor.borderSubtle,
                    lineWidth: 1
                )
            )
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: OKSpacing.sm) {
            Text("RECENT DECISIONS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            ForEach(channel.history.suffix(10).reversed()) { entry in
                HStack(spacing: OKSpacing.sm) {
                    Circle()
                        .fill(decisionColor(entry.decision))
                        .frame(width: 6, height: 6)
                    Text(entry.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(OKColor.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    if let decision = entry.decision {
                        Text(decision.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(decisionColor(entry.decision))
                    }
                }
                .padding(OKSpacing.sm)
                .background(OKColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OKRadius.small))
            }
        }
    }

    private func decisionColor(_ decision: ApprovalSession.Decision?) -> Color {
        switch decision {
        case .approve, .approvePartial: return OKColor.riskNominal
        case .requestRevision: return OKColor.riskWarning
        case .escalate: return OKColor.escalate
        case .reject: return OKColor.riskCritical
        case .none: return OKColor.textMuted
        }
    }

    // MARK: - Actions

    private func submitIntent() {
        let text = inputText
        let type = selectedIntentType
        inputText = ""

        Task {
            let intent = IntentRequest(rawText: text, intentType: type)
            _ = await channel.submitIntent(intent, context: nil, source: .operatorChannel)
        }
    }

    private func handleDecision(_ decision: ApprovalSession.Decision) {
        channel.recordDecision(decision)

        // If approved, forward to existing kernel pipeline
        if decision.allowsExecution,
           let proposal = channel.pendingProposal,
           let session = channel.activeSession {
            // Mint hardened token through kernel
            if let token = kernel.issueHardenedToken(proposal: proposal, session: session) {
                log("[OPERATOR_CHANNEL_VIEW] Hardened token minted: \(token.id)")
                // Token is now available for ExecutionEngine via the existing approval flow
            }
            channel.reset()
        }
    }
}
