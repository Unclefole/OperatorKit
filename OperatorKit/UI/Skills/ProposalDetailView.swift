import SwiftUI

// ============================================================================
// PROPOSAL DETAIL VIEW — READ-ONLY PROPOSAL INSPECTION
//
// Displays the full ProposalPack when a user taps a recent proposal.
// Shows: summary, risk, proposed actions, permissions, cost, evidence.
// Provides "Route for Approval" to enter the approval pipeline.
//
// INVARIANT: Never renders blank. Uses FailClosedView if data is nil.
// ============================================================================

struct ProposalDetailView: View {
    let proposal: ProposalPack

    @State private var showApprovalReview = false
    @State private var activeSession: ApprovalSession?
    @State private var decisionConfirmation: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                #if DEBUG
                debugOverlay
                #endif

                headerCard
                riskCard
                actionsCard
                permissionsCard
                costCard
                citationsCard
                approvalButton

                if let confirmation = decisionConfirmation {
                    confirmationBanner(confirmation)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(OKColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Proposal Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
        .sheet(isPresented: $showApprovalReview) {
            if let session = activeSession {
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
                            Button("Dismiss") { showApprovalReview = false }
                                .foregroundStyle(OKColor.textSecondary)
                        }
                    }
                }
                .presentationDetents([.large])
            } else {
                FailClosedView(
                    context: "ProposalDetail.sheet",
                    reason: "ApprovalSession is nil when sheet was presented."
                )
            }
        }
    }

    // MARK: - Debug Overlay

    #if DEBUG
    private var debugOverlay: some View {
        HStack(spacing: 6) {
            Image(systemName: "ladybug.fill")
                .font(.system(size: 10))
                .foregroundStyle(OKColor.riskWarning)
            Text("ID: \(proposal.id.uuidString.prefix(8))...")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(OKColor.riskWarning)
            Spacer()
            Text(proposal.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(OKColor.textMuted)
        }
        .padding(8)
        .background(OKColor.riskWarning.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(OKColor.riskWarning.opacity(0.2), lineWidth: 0.5)
        )
        .cornerRadius(6)
    }
    #endif

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                riskBadge(proposal.riskAnalysis.consequenceTier)
                Spacer()
                Text(proposal.toolPlan.originatingAction
                    .replacingOccurrences(of: "_skill", with: "")
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OKColor.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(OKColor.backgroundTertiary)
                    .cornerRadius(6)
            }

            Text(proposal.humanSummary)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OKColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                metadataChip(icon: "arrow.uturn.backward.circle", label: proposal.riskAnalysis.reversibilityClass.rawValue)
                metadataChip(icon: "person.wave.2", label: proposal.riskAnalysis.blastRadius.rawValue)
                metadataChip(icon: "person.badge.shield.checkmark", label: "\(proposal.toolPlan.requiredApprovals.multiSignerCount) signer(s)")
            }
        }
        .okCard()
    }

    // MARK: - Risk

    private var riskCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("RISK ANALYSIS")

            HStack(spacing: 16) {
                riskMetric(label: "SCORE", value: "\(proposal.riskAnalysis.riskScore)/100")
                riskMetric(label: "TIER", value: proposal.riskAnalysis.consequenceTier.rawValue)
                riskMetric(label: "REVERSIBLE", value: proposal.riskAnalysis.reversibilityClass.rawValue)
                riskMetric(label: "BLAST", value: proposal.riskAnalysis.blastRadius.rawValue
                    .replacingOccurrences(of: "_", with: " "))
            }

            if !proposal.riskAnalysis.reasons.isEmpty {
                Divider().background(OKColor.borderSubtle)

                ForEach(proposal.riskAnalysis.reasons, id: \.self) { reason in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(riskColor(for: proposal.riskAnalysis.consequenceTier))
                            .frame(width: 5, height: 5)
                        Text(reason)
                            .font(.system(size: 12))
                            .foregroundStyle(OKColor.textSecondary)
                    }
                }
            }
        }
        .padding(14)
        .background(OKColor.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(riskColor(for: proposal.riskAnalysis.consequenceTier).opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(14)
    }

    // MARK: - Proposed Actions

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("PROPOSED ACTIONS (\(proposal.toolPlan.executionSteps.count))")

            if proposal.toolPlan.executionSteps.isEmpty {
                Text("No execution steps defined.")
                    .font(.system(size: 13))
                    .foregroundStyle(OKColor.textMuted)
                    .padding(.vertical, 8)
            } else {
                ForEach(proposal.toolPlan.executionSteps) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(step.order)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(OKColor.actionPrimary)
                            .frame(width: 22, height: 22)
                            .background(OKColor.backgroundTertiary)
                            .cornerRadius(6)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(step.action)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(OKColor.textPrimary)
                                if step.isMutation {
                                    Image(systemName: "lock.shield")
                                        .font(.system(size: 11))
                                        .foregroundStyle(OKColor.riskWarning)
                                }
                            }
                            Text(step.description)
                                .font(.system(size: 12))
                                .foregroundStyle(OKColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(10)
                    .background(OKColor.backgroundTertiary.opacity(0.5))
                    .cornerRadius(8)
                }
            }
        }
        .okCard()
    }

    // MARK: - Permissions

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("PERMISSIONS REQUIRED")

            if proposal.permissionManifest.scopes.isEmpty {
                Text("No special permissions required.")
                    .font(.system(size: 13))
                    .foregroundStyle(OKColor.textMuted)
            } else {
                ForEach(proposal.permissionManifest.scopes) { scope in
                    HStack(spacing: 8) {
                        Image(systemName: permissionIcon(for: scope.domain))
                            .font(.system(size: 13))
                            .foregroundStyle(OKColor.riskOperational)
                            .frame(width: 20)

                        Text("\(scope.domain.rawValue).\(scope.access.rawValue)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(OKColor.textPrimary)

                        Text("(\(scope.detail))")
                            .font(.system(size: 11))
                            .foregroundStyle(OKColor.textMuted)

                        Spacer()
                    }
                }
            }
        }
        .okCard()
    }

    // MARK: - Cost

    private var costCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("COST ESTIMATE")

            if proposal.costEstimate.requiresCloudCall {
                HStack(spacing: 16) {
                    costMetric(label: "INPUT", value: "\(proposal.costEstimate.predictedInputTokens) tok")
                    costMetric(label: "OUTPUT", value: "\(proposal.costEstimate.predictedOutputTokens) tok")
                    costMetric(label: "COST", value: "$\(String(format: "%.4f", proposal.costEstimate.estimatedCostUSD))")
                    costMetric(label: "CONF", value: proposal.costEstimate.confidenceBand.rawValue)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .foregroundStyle(OKColor.riskNominal)
                    Text("On-device processing — no cloud cost")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OKColor.textSecondary)
                }
            }
        }
        .okCard()
    }

    // MARK: - Citations

    private var citationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("EVIDENCE CITATIONS")

            if proposal.evidenceCitations.isEmpty {
                Text("No external context referenced.")
                    .font(.system(size: 13))
                    .foregroundStyle(OKColor.textMuted)
            } else {
                ForEach(proposal.evidenceCitations) { citation in
                    HStack(spacing: 8) {
                        Image(systemName: citationIcon(for: citation.sourceType))
                            .font(.system(size: 12))
                            .foregroundStyle(OKColor.textSecondary)
                            .frame(width: 18)
                        Text(citation.redactedSummary)
                            .font(.system(size: 12))
                            .foregroundStyle(OKColor.textSecondary)
                            .lineLimit(2)
                        Spacer()
                    }
                }
            }
        }
        .okCard()
    }

    // MARK: - Approval Button

    private var approvalButton: some View {
        Button {
            routeToApproval()
        } label: {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                Text("Route for Approval")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(OKColor.actionPrimary)
            .cornerRadius(12)
        }
    }

    // MARK: - Confirmation

    private func confirmationBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(OKColor.riskNominal)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OKColor.textPrimary)
            Spacer()
            Button {
                withAnimation { decisionConfirmation = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundStyle(OKColor.textMuted)
            }
        }
        .padding(12)
        .background(OKColor.riskNominal.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(OKColor.riskNominal.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    // MARK: - Actions

    private func routeToApproval() {
        let session = ApprovalSession(proposal: proposal)
        ApprovalSessionStore.shared.register(session)

        try? EvidenceEngine.shared.logGenericArtifact(
            type: "proposal_detail_routed_to_approval",
            planId: proposal.id,
            jsonString: """
            {"proposalId":"\(proposal.id)","sessionId":"\(session.id)","source":"ProposalDetailView"}
            """
        )

        activeSession = session
        showApprovalReview = true
    }

    private func handleDecision(_ decision: ApprovalSession.Decision, session: ApprovalSession) {
        ApprovalSessionStore.shared.recordDecision(session.id, decision: decision)

        withAnimation(.easeInOut(duration: 0.2)) {
            switch decision {
            case .approve, .approvePartial:
                decisionConfirmation = "Approved — ready for governed execution."
            case .requestRevision:
                decisionConfirmation = "Revision requested — proposal returned."
            case .escalate:
                decisionConfirmation = "Escalated — awaiting additional authority."
            case .reject:
                decisionConfirmation = "Rejected — no execution will occur."
            }
            showApprovalReview = false
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.0)
            .foregroundStyle(OKColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func riskBadge(_ tier: RiskTier) -> some View {
        Text(tier.rawValue)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(riskColor(for: tier))
            .cornerRadius(6)
    }

    private func metadataChip(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(OKColor.textMuted)
    }

    private func riskMetric(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(OKColor.textMuted)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(OKColor.textPrimary)
        }
    }

    private func costMetric(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(OKColor.textMuted)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OKColor.textPrimary)
        }
    }

    private func riskColor(for tier: RiskTier) -> Color {
        switch tier {
        case .low:      return OKColor.riskNominal
        case .medium:   return OKColor.riskOperational
        case .high:     return OKColor.riskWarning
        case .critical: return OKColor.riskCritical
        }
    }

    private func permissionIcon(for domain: PermissionDomain) -> String {
        switch domain {
        case .calendar:   return "calendar"
        case .mail:       return "envelope"
        case .reminders:  return "checklist"
        case .files:      return "doc"
        case .network:    return "network"
        case .memory:     return "brain.head.profile"
        }
    }

    private func citationIcon(for type: CitationSourceType) -> String {
        switch type {
        case .email:         return "envelope"
        case .calendarEvent: return "calendar"
        case .document:      return "doc.text"
        case .reminder:      return "checklist"
        case .memoryItem:    return "brain"
        case .userInput:     return "person"
        }
    }
}
