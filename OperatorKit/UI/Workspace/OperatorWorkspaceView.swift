import SwiftUI

// ============================================================================
// OPERATOR WORKSPACE — PRODUCTIVITY SURFACE
//
// Entry point for all user-initiated actions.
// Flow: User picks action type → IntentInputView → ContextPicker →
//       DraftGenerator → ModelRouter.generateGoverned() → ApprovalView →
//       Kernel → ExecutionEngine
//
// NO bypasses. Every path goes through the governed pipeline.
// ============================================================================

struct OperatorWorkspaceView: View {
    @EnvironmentObject var nav: AppNavigationState
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                actionCardsSection
                recentDraftsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(OKColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("New Action")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT WOULD YOU LIKE TO DO?")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(OKColor.textMuted)
                .tracking(1.0)

            Text("Select an action type. All outputs are drafts that require your approval before execution.")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Action Cards

    private var actionCardsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                actionCard(
                    icon: "envelope.fill",
                    title: "Draft Email",
                    subtitle: "Compose a follow-up or reply",
                    color: OKColor.riskOperational
                ) {
                    appState.intentTypeHint = .draftEmail
                    nav.navigate(to: .intent)
                }

                actionCard(
                    icon: "calendar.badge.plus",
                    title: "Schedule Meeting",
                    subtitle: "Create a calendar event",
                    color: OKColor.riskNominal
                ) {
                    appState.intentTypeHint = .createReminder
                    nav.navigate(to: .intent)
                }
            }

            HStack(spacing: 12) {
                actionCard(
                    icon: "bell.fill",
                    title: "Create Reminder",
                    subtitle: "Set a follow-up reminder",
                    color: OKColor.riskWarning
                ) {
                    appState.intentTypeHint = .createReminder
                    nav.navigate(to: .intent)
                }

                actionCard(
                    icon: "doc.text.magnifyingglass",
                    title: "Summarize",
                    subtitle: "Summarize meeting or document",
                    color: OKColor.riskExtreme
                ) {
                    appState.intentTypeHint = .summarizeMeeting
                    nav.navigate(to: .intent)
                }
            }

            // Free-form intent
            Button {
                nav.navigate(to: .intent)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "text.cursor")
                        .font(.title3)
                        .foregroundColor(OKColor.actionPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom Request")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(OKColor.textPrimary)
                        Text("Type a free-form intent")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                }
                .padding(16)
                .background(OKColor.backgroundSecondary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(OKColor.borderSubtle, lineWidth: 1)
                )
            }
        }
    }

    private func actionCard(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(OKColor.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(OKColor.backgroundSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(OKColor.borderSubtle, lineWidth: 1)
            )
        }
    }

    // MARK: - Recent Drafts

    private var recentDraftsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT DRAFTS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(OKColor.textMuted)
                .tracking(1.0)

            if let lastDraft = DraftGenerator.shared.lastDraftOutput {
                HStack(spacing: 12) {
                    Image(systemName: lastDraft.outputType.icon)
                        .font(.title3)
                        .foregroundColor(OKColor.actionPrimary)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lastDraft.subject ?? lastDraft.outputType.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(OKColor.textPrimary)
                            .lineLimit(1)

                        Text(lastDraft.draftBody.prefix(80) + "...")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(14)
                .background(OKColor.backgroundSecondary)
                .cornerRadius(12)
            } else {
                Text("No recent drafts. Start a new action above.")
                    .font(.caption)
                    .foregroundColor(OKColor.textMuted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OKColor.backgroundSecondary)
                    .cornerRadius(12)
            }
        }
    }
}
