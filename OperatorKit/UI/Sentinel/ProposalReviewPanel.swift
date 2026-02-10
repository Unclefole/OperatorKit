import SwiftUI

// ============================================================================
// PROPOSAL REVIEW PANEL — HUMAN AUTHORITY UI
//
// Displays:
//   • Proposed actions (ToolPlan steps)
//   • Permission scopes
//   • Risk tier + blast radius
//   • Cost estimate
//   • Evidence citations
//
// Controls:
//   • Approve
//   • Approve Step 1 (partial)
//   • Request Changes
//   • Escalate
//   • Reject
//
// INVARIANT: Approval NEVER skipped.
// INVARIANT: UI reflects real ProposalPack data.
// ============================================================================

struct ProposalReviewPanel: View {
    let proposal: ProposalPack
    let session: ApprovalSession
    let onDecision: (ApprovalSession.Decision) -> Void

    @State private var showingEscalateConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: OKSpacing.lg) {
                // Header
                proposalHeader

                // Execution Tracker
                executionTracker

                // Proposed Actions
                actionsSection

                // Permissions
                permissionsSection

                // Risk Analysis
                riskSection

                // Cost Estimate
                costSection

                // Evidence Citations
                citationsSection

                // Decision Buttons
                decisionButtons
            }
            .padding(OKSpacing.md)
        }
        .background(OKColor.backgroundPrimary)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var proposalHeader: some View {
        VStack(spacing: OKSpacing.sm) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.title2)
                    .foregroundStyle(OKColor.actionPrimary)
                Text("PROPOSAL READY")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(OKColor.textMuted)
                Spacer()
                riskBadge(tier: proposal.riskAnalysis.consequenceTier)
            }

            Text(proposal.humanSummary)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OKColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: OKSpacing.md) {
                metadataChip(
                    icon: "clock",
                    label: "Expires in \(Int(session.expiresAt.timeIntervalSinceNow))s"
                )
                metadataChip(
                    icon: "arrow.uturn.backward.circle",
                    label: proposal.riskAnalysis.reversibilityClass.rawValue
                )
                metadataChip(
                    icon: "person.wave.2",
                    label: proposal.riskAnalysis.blastRadius.rawValue
                )
            }
        }
        .padding(OKSpacing.md)
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OKRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: OKRadius.card)
                .stroke(OKColor.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Execution Tracker

    private var executionTracker: some View {
        HStack(spacing: 0) {
            trackerStep("PROPOSAL", isActive: true, isComplete: true)
            trackerConnector()
            trackerStep("APPROVAL", isActive: true, isComplete: false)
            trackerConnector()
            trackerStep("TOKEN", isActive: false, isComplete: false)
            trackerConnector()
            trackerStep("EXECUTION", isActive: false, isComplete: false)
        }
        .padding(.vertical, OKSpacing.sm)
    }

    private func trackerStep(_ label: String, isActive: Bool, isComplete: Bool) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isComplete ? OKColor.riskNominal : (isActive ? OKColor.actionPrimary : OKColor.backgroundTertiary))
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(isActive ? OKColor.textPrimary : OKColor.textMuted)
        }
    }

    private func trackerConnector() -> some View {
        Rectangle()
            .fill(OKColor.borderSubtle)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
    }

    // MARK: - Proposed Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: OKSpacing.sm) {
            sectionHeader("PROPOSED ACTIONS")

            ForEach(Array(proposal.toolPlan.executionSteps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: OKSpacing.sm) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(OKColor.actionPrimary)
                        .frame(width: 24, height: 24)
                        .background(OKColor.backgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.action)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OKColor.textPrimary)
                        Text(step.description)
                            .font(.system(size: 12))
                            .foregroundStyle(OKColor.textSecondary)
                    }

                    Spacer()

                    if step.isMutation {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 12))
                            .foregroundStyle(OKColor.riskWarning)
                    }
                }
                .padding(OKSpacing.sm)
                .background(OKColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OKRadius.small))
            }
        }
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: OKSpacing.sm) {
            sectionHeader("PERMISSIONS REQUIRED")

            ForEach(proposal.permissionManifest.scopes) { scope in
                HStack(spacing: OKSpacing.sm) {
                    Image(systemName: permissionIcon(for: scope.domain))
                        .font(.system(size: 14))
                        .foregroundStyle(OKColor.riskOperational)
                        .frame(width: 24)

                    Text("\(scope.domain.rawValue).\(scope.access.rawValue)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(OKColor.textPrimary)

                    Text("(\(scope.detail))")
                        .font(.system(size: 12))
                        .foregroundStyle(OKColor.textMuted)

                    Spacer()
                }
            }
        }
        .padding(OKSpacing.md)
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OKRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: OKRadius.card)
                .stroke(OKColor.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Risk

    private var riskSection: some View {
        VStack(alignment: .leading, spacing: OKSpacing.sm) {
            sectionHeader("RISK ANALYSIS")

            HStack(spacing: OKSpacing.lg) {
                riskMetric(label: "SCORE", value: "\(proposal.riskAnalysis.riskScore)/100")
                riskMetric(label: "TIER", value: proposal.riskAnalysis.consequenceTier.rawValue)
                riskMetric(label: "REVERSIBLE", value: proposal.riskAnalysis.reversibilityClass.rawValue)
                riskMetric(label: "BLAST", value: proposal.riskAnalysis.blastRadius.rawValue.replacingOccurrences(of: "_", with: " "))
            }

            if !proposal.riskAnalysis.reasons.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
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
        }
        .padding(OKSpacing.md)
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OKRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: OKRadius.card)
                .stroke(riskColor(for: proposal.riskAnalysis.consequenceTier).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Cost

    private var costSection: some View {
        VStack(alignment: .leading, spacing: OKSpacing.sm) {
            sectionHeader("COST ESTIMATE")

            if proposal.costEstimate.requiresCloudCall {
                HStack(spacing: OKSpacing.lg) {
                    costMetric(label: "INPUT", value: "\(proposal.costEstimate.predictedInputTokens) tokens")
                    costMetric(label: "OUTPUT", value: "\(proposal.costEstimate.predictedOutputTokens) tokens")
                    costMetric(label: "COST", value: "$\(String(format: "%.4f", proposal.costEstimate.estimatedCostUSD))")
                    costMetric(label: "CONFIDENCE", value: proposal.costEstimate.confidenceBand.rawValue)
                }
                .padding(OKSpacing.sm)
                .background(OKColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OKRadius.small))
            } else {
                HStack(spacing: OKSpacing.sm) {
                    Image(systemName: "cpu")
                        .foregroundStyle(OKColor.riskNominal)
                    Text("On-device processing — no cloud cost")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OKColor.textSecondary)
                }
                .padding(OKSpacing.sm)
                .background(OKColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OKRadius.small))
            }
        }
    }

    // MARK: - Citations

    private var citationsSection: some View {
        VStack(alignment: .leading, spacing: OKSpacing.sm) {
            sectionHeader("EVIDENCE CITATIONS")

            if proposal.evidenceCitations.isEmpty {
                Text("No external context referenced")
                    .font(.system(size: 12))
                    .foregroundStyle(OKColor.textMuted)
            } else {
                ForEach(proposal.evidenceCitations) { citation in
                    HStack(spacing: OKSpacing.sm) {
                        Image(systemName: citationIcon(for: citation.sourceType))
                            .font(.system(size: 12))
                            .foregroundStyle(OKColor.textSecondary)
                        Text(citation.redactedSummary.prefix(80))
                            .font(.system(size: 12))
                            .foregroundStyle(OKColor.textSecondary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Decision Buttons

    private var decisionButtons: some View {
        VStack(spacing: OKSpacing.sm) {
            // Primary: Approve
            Button {
                onDecision(.approve)
            } label: {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                    Text("Approve All")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(OKColor.actionPrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: OKRadius.button))
            }
            .disabled(session.isExpired)

            // Secondary row
            HStack(spacing: OKSpacing.sm) {
                // Approve Step 1
                if proposal.toolPlan.executionSteps.count > 1 {
                    Button {
                        onDecision(.approvePartial)
                    } label: {
                        Text("Approve Step 1")
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(OKColor.backgroundTertiary)
                            .foregroundStyle(OKColor.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: OKRadius.button))
                            .overlay(
                                RoundedRectangle(cornerRadius: OKRadius.button)
                                    .stroke(OKColor.borderSubtle, lineWidth: 1)
                            )
                    }
                    .disabled(session.isExpired)
                }

                // Request Changes
                Button {
                    onDecision(.requestRevision)
                } label: {
                    Text("Request Changes")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(OKColor.backgroundTertiary)
                        .foregroundStyle(OKColor.riskWarning)
                        .clipShape(RoundedRectangle(cornerRadius: OKRadius.button))
                        .overlay(
                            RoundedRectangle(cornerRadius: OKRadius.button)
                                .stroke(OKColor.borderSubtle, lineWidth: 1)
                        )
                }
            }

            // Tertiary row
            HStack(spacing: OKSpacing.sm) {
                Button {
                    onDecision(.escalate)
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.circle")
                        Text("Escalate")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(OKColor.backgroundTertiary)
                    .foregroundStyle(OKColor.escalate)
                    .clipShape(RoundedRectangle(cornerRadius: OKRadius.button))
                    .overlay(
                        RoundedRectangle(cornerRadius: OKRadius.button)
                            .stroke(OKColor.borderSubtle, lineWidth: 1)
                    )
                }

                Button {
                    onDecision(.reject)
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Reject")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(OKColor.backgroundTertiary)
                    .foregroundStyle(OKColor.emergencyStop)
                    .clipShape(RoundedRectangle(cornerRadius: OKRadius.button))
                    .overlay(
                        RoundedRectangle(cornerRadius: OKRadius.button)
                            .stroke(OKColor.borderSubtle, lineWidth: 1)
                    )
                }
            }

            if session.isExpired {
                Text("Session expired — submit new intent")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(OKColor.riskCritical)
            }
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.0)
            .foregroundStyle(OKColor.textMuted)
    }

    private func riskBadge(tier: RiskTier) -> some View {
        Text(tier.rawValue)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(riskColor(for: tier))
            .clipShape(Capsule())
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
