import SwiftUI

// ============================================================================
// SCOUT DASHBOARD — Phone-Friendly Scout Mode Control + Findings
// ============================================================================

struct ScoutDashboardView: View {

    @StateObject private var scoutEngine = ScoutEngine.shared
    @StateObject private var store = FindingPackStore.shared
    @StateObject private var slack = SlackNotifier.shared
    @State private var slackURL: String = ""
    @State private var showSlackConfig = false
    @State private var testResult: Bool?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                controlCard
                slackCard
                if scoutEngine.isRunning { runningIndicator }
                findingsListCard
            }
            .padding()
        }
        .background(OKColor.backgroundPrimary)
        .navigationTitle("Scout Mode")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: FindingPack.self) { pack in
            FindingPackDetailView(pack: pack)
        }
    }

    // MARK: - Control Card

    private var controlCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "binoculars.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(EnterpriseFeatureFlags.scoutModeEnabled ? OKColor.riskNominal : OKColor.textMuted)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scout Mode")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(OKColor.textPrimary)
                    Text("Autonomous read-only monitoring")
                        .font(.system(size: 12))
                        .foregroundStyle(OKColor.textMuted)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { EnterpriseFeatureFlags.scoutModeEnabled },
                    set: {
                        EnterpriseFeatureFlags.setScoutModeEnabled($0)
                        if $0 { BackgroundScheduler.scheduleScoutRun() }
                    }
                ))
                .labelsHidden()
                .tint(OKColor.riskNominal)
            }

            Button("Run Scout Now") {
                Task {
                    let pack = await scoutEngine.run()
                    store.save(pack)
                    if EnterpriseFeatureFlags.slackDeliveryPermitted {
                        await slack.sendFindingPack(pack)
                    }
                }
            }
            .buttonStyle(OKPrimaryButtonStyle())
            .disabled(scoutEngine.isRunning)

            if let lastRun = scoutEngine.lastRunAt {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text("Last run: \(lastRun.formatted(date: .abbreviated, time: .standard))")
                        .font(.system(size: 12))
                }
                .foregroundStyle(OKColor.textMuted)
            }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    // MARK: - Slack Card

    private var slackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .foregroundStyle(OKColor.actionPrimary)
                Text("Slack Integration")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OKColor.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { EnterpriseFeatureFlags.slackIntegrationEnabled },
                    set: { EnterpriseFeatureFlags.setSlackIntegrationEnabled($0) }
                ))
                .labelsHidden()
                .tint(OKColor.actionPrimary)
            }

            // Host allowlist toggle (dual-gate)
            HStack {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.system(size: 14))
                    .foregroundStyle(OKColor.textMuted)
                Text("Allow Slack Host")
                    .font(.system(size: 13))
                    .foregroundStyle(OKColor.textSecondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { EnterpriseFeatureFlags.slackHostAllowlistEnabled },
                    set: { EnterpriseFeatureFlags.setSlackHostAllowlistEnabled($0) }
                ))
                .labelsHidden()
                .tint(OKColor.riskNominal)
            }

            if !EnterpriseFeatureFlags.slackDeliveryPermitted {
                Text("Both toggles must be ON to send findings to Slack.")
                    .font(.system(size: 11))
                    .foregroundStyle(OKColor.riskWarning)
            }

            if slack.isConfigured {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(OKColor.riskNominal)
                    Text("Webhook configured")
                        .font(.system(size: 13))
                        .foregroundStyle(OKColor.textSecondary)
                }
            }

            if showSlackConfig || !slack.isConfigured {
                TextField("Paste Slack webhook URL", text: $slackURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(OKColor.textPrimary)
                    .padding(10)
                    .background(OKColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 12) {
                    Button("Save Webhook") {
                        slack.configureWebhook(url: slackURL)
                        showSlackConfig = false
                    }
                    .buttonStyle(OKPrimaryButtonStyle())
                    .disabled(slackURL.isEmpty)

                    if slack.isConfigured {
                        Button("Send Test") {
                            Task {
                                testResult = await slack.sendTestMessage()
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OKColor.actionPrimary)
                    }
                }
            } else {
                Button("Change Webhook") { showSlackConfig = true }
                    .font(.system(size: 13))
                    .foregroundStyle(OKColor.actionPrimary)
            }

            if let err = slack.lastError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(OKColor.riskCritical)
            }
            if let sent = slack.lastSentAt {
                Text("Last sent: \(sent.formatted(date: .omitted, time: .standard))")
                    .font(.system(size: 11))
                    .foregroundStyle(OKColor.textMuted)
            }
            if let r = testResult {
                Text(r ? "Test message sent!" : "Test failed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(r ? OKColor.riskNominal : OKColor.riskCritical)
            }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    // MARK: - Running Indicator

    private var runningIndicator: some View {
        HStack {
            ProgressView()
                .tint(OKColor.actionPrimary)
            Text("Scout is analyzing…")
                .font(.system(size: 14))
                .foregroundStyle(OKColor.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Findings List

    private var findingsListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT FINDINGS")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            if store.packs.isEmpty {
                HStack {
                    Image(systemName: "binoculars")
                        .foregroundStyle(OKColor.textMuted)
                    Text("No findings yet. Run Scout to start monitoring.")
                        .font(.system(size: 14))
                        .foregroundStyle(OKColor.textMuted)
                }
                .padding()
            } else {
                ForEach(store.packs.prefix(10)) { pack in
                    NavigationLink(value: pack) {
                        findingPackRow(pack)
                    }
                }
            }
        }
    }

    private func findingPackRow(_ pack: FindingPack) -> some View {
        HStack(alignment: .top, spacing: 12) {
            severityDot(pack.severity)
            VStack(alignment: .leading, spacing: 4) {
                Text(pack.summary)
                    .font(.system(size: 14))
                    .foregroundStyle(OKColor.textPrimary)
                    .lineLimit(2)
                HStack {
                    Text(pack.createdAt.formatted(date: .abbreviated, time: .shortened))
                    Text("·")
                    Text("\(pack.findings.count) finding(s)")
                }
                .font(.system(size: 11))
                .foregroundStyle(OKColor.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(OKColor.textMuted)
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    private func severityDot(_ s: FindingSeverity) -> some View {
        Circle()
            .fill(severityColor(s))
            .frame(width: 10, height: 10)
            .padding(.top, 5)
    }

    private func severityColor(_ s: FindingSeverity) -> Color {
        switch s {
        case .critical: return OKColor.riskCritical
        case .warning: return OKColor.riskWarning
        case .info: return OKColor.riskOperational
        case .nominal: return OKColor.riskNominal
        }
    }
}

// MARK: - FindingPack Detail View

struct FindingPackDetailView: View {
    let pack: FindingPack

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(pack.severity.rawValue.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(severityColor(pack.severity).opacity(0.2))
                            .foregroundStyle(severityColor(pack.severity))
                            .clipShape(Capsule())
                        Text(pack.scope.rawValue)
                            .font(.system(size: 11))
                            .foregroundStyle(OKColor.textMuted)
                    }
                    Text(pack.summary)
                        .font(.system(size: 15))
                        .foregroundStyle(OKColor.textPrimary)
                    Text(pack.createdAt.formatted(date: .long, time: .standard))
                        .font(.system(size: 12))
                        .foregroundStyle(OKColor.textMuted)
                }

                Divider().background(OKColor.borderSubtle)

                // Findings
                Text("FINDINGS (\(pack.findings.count))")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(OKColor.textMuted)

                ForEach(pack.findings) { finding in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(finding.category.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(OKColor.textMuted)
                            Spacer()
                            Text("\(Int(finding.confidence * 100))% confidence")
                                .font(.system(size: 10))
                                .foregroundStyle(OKColor.textMuted)
                        }
                        Text(finding.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OKColor.textPrimary)
                        Text(finding.detail)
                            .font(.system(size: 13))
                            .foregroundStyle(OKColor.textSecondary)
                        if !finding.signals.isEmpty {
                            HStack {
                                ForEach(finding.signals.prefix(3), id: \.self) { signal in
                                    Text(signal)
                                        .font(.system(size: 10, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(OKColor.backgroundTertiary)
                                        .clipShape(Capsule())
                                        .foregroundStyle(OKColor.textMuted)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(OKColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(OKColor.borderSubtle, lineWidth: 1))
                }

                // Recommended Actions
                if !pack.recommendedActions.isEmpty {
                    Divider().background(OKColor.borderSubtle)
                    Text("RECOMMENDED ACTIONS")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(OKColor.textMuted)

                    ForEach(pack.recommendedActions) { action in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(action.label)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(OKColor.textPrimary)
                            Text(action.nextStep)
                                .font(.system(size: 13))
                                .foregroundStyle(OKColor.textSecondary)
                            if action.requiresHumanApproval {
                                Text("Requires human approval")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(OKColor.riskWarning)
                            }
                        }
                        .padding()
                        .background(OKColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Generate Proposal — routes to Skills Dashboard to create ProposalPack
                NavigationLink(value: Route.skillsDashboard) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                        Text("Generate ProposalPack from Findings")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OKColor.actionPrimary)
                }
            }
            .padding()
        }
        .background(OKColor.backgroundPrimary)
        .navigationTitle("Finding Pack")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func severityColor(_ s: FindingSeverity) -> Color {
        switch s {
        case .critical: return OKColor.riskCritical
        case .warning: return OKColor.riskWarning
        case .info: return OKColor.riskOperational
        case .nominal: return OKColor.riskNominal
        }
    }
}
