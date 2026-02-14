import SwiftUI

// ============================================================================
// OPERATOR SKILLS DASHBOARD — MICRO-OPERATORS CONTROL SURFACE
//
// Displays Day-One Micro-Operators:
//   1. Inbox Triage (decisions from inbound communication)
//   2. Meeting Actions (extract commitments/owners/deadlines)
//   3. Approval Router (prepare approval packets)
//
// Users input text → skills observe/analyze/generate ProposalPacks.
// NO side effects. Proposal-only intelligence.
// ============================================================================

public struct OperatorSkillsDashboardView: View {

    @StateObject private var registry = SkillRegistry.shared
    @StateObject private var calendarConnector = CalendarSignalConnector.shared

    @State private var selectedSkillId: String?
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var latestProposal: ProposalPack?
    @State private var showApprovalReview: Bool = false
    @State private var activeSession: ApprovalSession?
    @State private var decisionConfirmation: String?
    @State private var errorMessage: String?
    @State private var showAutopilot: Bool = false

    @State private var webResearchURL: String = ""

    private let skills: [(id: String, icon: String, color: Color)] = [
        ("inbox_triage", "envelope.open.fill", OKColor.riskOperational),
        ("meeting_actions", "person.3.fill", OKColor.riskNominal),
        ("approval_router", "checkmark.seal.fill", OKColor.riskWarning),
        ("web_research", "globe.americas.fill", OKColor.actionPrimary)
    ]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                skillSelector
                inputSection
                if isProcessing {
                    processingIndicator
                }
                if let error = errorMessage {
                    errorBanner(error)
                }
                if let confirmation = decisionConfirmation {
                    decisionBanner(confirmation)
                }
                if let proposal = latestProposal {
                    proposalResultCard(proposal)
                }
                recentProposalsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(OKColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Micro-Operators")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ProposalPack.self) { proposal in
            ProposalDetailView(proposal: proposal)
        }
        .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
        .sheet(isPresented: $showApprovalReview) {
            if let proposal = latestProposal, let session = activeSession {
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
            }
        }
        .fullScreenCover(isPresented: $showAutopilot) {
            NavigationStack {
                AutopilotProgressView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                AutopilotOrchestrator.shared.reset()
                                showAutopilot = false
                            }
                            .foregroundStyle(OKColor.textSecondary)
                        }
                    }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(OKColor.actionPrimary)
                Text("Skill OS")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(OKColor.textPrimary)
                Spacer()
                Text("\(registry.registeredSkills.count) Active")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OKColor.riskNominal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(OKColor.riskNominal.opacity(0.15))
                    .cornerRadius(8)
            }

            Text("Observe. Analyze. Propose. Never execute.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OKColor.textMuted)
        }
        .okCard()
    }

    // MARK: - Skill Selector

    private var skillSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            OKSectionHeader("SELECT OPERATOR")

            HStack(spacing: 10) {
                ForEach(skills, id: \.id) { skill in
                    skillButton(skill)
                }
            }
        }
    }

    private func skillButton(_ skill: (id: String, icon: String, color: Color)) -> some View {
        let isSelected = selectedSkillId == skill.id
        let skillObj = registry.skill(for: skill.id)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSkillId = skill.id
                errorMessage = nil
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: skill.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : skill.color)

                Text(skillObj?.displayName ?? skill.id)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : OKColor.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? skill.color.opacity(0.8) : OKColor.backgroundTertiary)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? skill.color : OKColor.borderSubtle, lineWidth: 1)
            )
            .cornerRadius(12)
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OKSectionHeader("INPUT")

            if selectedSkillId == nil {
                Text("Select a Micro-Operator above to begin.")
                    .font(.system(size: 14))
                    .foregroundStyle(OKColor.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .okCard()
            } else if selectedSkillId == "web_research" {
                webResearchInputSection
            } else {
                VStack(spacing: 12) {
                    inputHintText

                    // Live Calendar Connector
                    if selectedSkillId == "inbox_triage" || selectedSkillId == "meeting_actions" {
                        calendarQuickAction
                    }

                    TextEditor(text: $inputText)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(OKColor.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 140, maxHeight: 200)
                        .padding(10)
                        .background(OKColor.backgroundTertiary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(OKColor.borderSubtle, lineWidth: 1)
                        )
                        .cornerRadius(10)

                    HStack(spacing: 10) {
                        Button {
                            Task { await runSkill() }
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Generate Decisions")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? OKColor.textMuted.opacity(0.3) : OKColor.actionPrimary)
                            .cornerRadius(12)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)

                        if AutopilotFeatureFlags.autopilotEnabled {
                            Button {
                                Task { await runSkill() }
                            } label: {
                                HStack {
                                    Image(systemName: "bolt.circle.fill")
                                    Text("Autopilot")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                            ? OKColor.textMuted.opacity(0.3) : OKColor.riskOperational)
                                .cornerRadius(12)
                            }
                            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                        }
                    }
                }
                .okCard()
            }
        }
    }

    @ViewBuilder
    private var inputHintText: some View {
        switch selectedSkillId {
        case "inbox_triage":
            Text("Paste email thread, message export, or shared inbox content.")
                .font(.system(size: 12)).foregroundStyle(OKColor.textMuted)
        case "meeting_actions":
            Text("Paste meeting transcript, notes, or action items.")
                .font(.system(size: 12)).foregroundStyle(OKColor.textMuted)
        case "approval_router":
            Text("Paste proposal content or decision requiring approval routing.")
                .font(.system(size: 12)).foregroundStyle(OKColor.textMuted)
        default:
            Text("Paste content for analysis.")
                .font(.system(size: 12)).foregroundStyle(OKColor.textMuted)
        }
    }

    // MARK: - Web Research Input

    private var webResearchInputSection: some View {
        VStack(spacing: 12) {
            // Dual-gate status
            webResearchGateStatus

            VStack(alignment: .leading, spacing: 4) {
                Text("Paste a public HTTPS URL from an allowlisted domain (.gov, etc.)")
                    .font(.system(size: 12))
                    .foregroundStyle(OKColor.textMuted)

                TextField("https://www.justice.gov/...", text: $webResearchURL)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(OKColor.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(12)
                    .background(OKColor.backgroundTertiary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(webResearchURL.hasPrefix("https://") ? OKColor.actionPrimary.opacity(0.5) : OKColor.borderSubtle, lineWidth: 1)
                    )
                    .cornerRadius(10)
            }

            // Optional research query
            VStack(alignment: .leading, spacing: 4) {
                Text("What are you looking for? (optional)")
                    .font(.system(size: 12))
                    .foregroundStyle(OKColor.textMuted)

                TextEditor(text: $inputText)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(OKColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80, maxHeight: 120)
                    .padding(10)
                    .background(OKColor.backgroundTertiary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(OKColor.borderSubtle, lineWidth: 1)
                    )
                    .cornerRadius(10)
            }

            // Security badges
            HStack(spacing: 8) {
                Label("GET only", systemImage: "arrow.down.circle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(OKColor.riskNominal)
                Label("HTTPS", systemImage: "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(OKColor.riskNominal)
                Label("No cookies", systemImage: "xmark.shield")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(OKColor.riskNominal)
                Label("Read-only", systemImage: "eye")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(OKColor.riskNominal)
                Spacer()
            }

            Button {
                Task { await runWebResearch() }
            } label: {
                HStack {
                    Image(systemName: "globe.americas.fill")
                    Text("Fetch & Analyze")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(webResearchReady ? OKColor.actionPrimary : OKColor.textMuted.opacity(0.3))
                .cornerRadius(12)
            }
            .disabled(!webResearchReady || isProcessing)
        }
        .okCard()
    }

    private var webResearchReady: Bool {
        let url = webResearchURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return url.hasPrefix("https://")
            && EnterpriseFeatureFlags.webResearchEnabled
            && EnterpriseFeatureFlags.researchHostAllowlistEnabled
    }

    private var webResearchGateStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: EnterpriseFeatureFlags.webResearchEnabled
                      ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(EnterpriseFeatureFlags.webResearchEnabled
                                    ? OKColor.riskNominal : OKColor.riskCritical)
                    .font(.system(size: 13))
                Text("Web Research")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OKColor.textSecondary)

                Spacer()

                Image(systemName: EnterpriseFeatureFlags.researchHostAllowlistEnabled
                      ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(EnterpriseFeatureFlags.researchHostAllowlistEnabled
                                    ? OKColor.riskNominal : OKColor.riskCritical)
                    .font(.system(size: 13))
                Text("Host Allowlist")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OKColor.textSecondary)
            }

            if !EnterpriseFeatureFlags.webResearchEnabled || !EnterpriseFeatureFlags.researchHostAllowlistEnabled {
                Text("Enable both flags in Settings > Kill Switches to use Web Research.")
                    .font(.system(size: 11))
                    .foregroundStyle(OKColor.riskWarning)
            }
        }
        .padding(10)
        .background(OKColor.backgroundTertiary)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(OKColor.borderSubtle, lineWidth: 0.5)
        )
        .cornerRadius(8)
    }

    // MARK: - Web Research Action

    @MainActor
    private func runWebResearch() async {
        guard webResearchReady else {
            errorMessage = "Enable both Web Research flags and enter a valid HTTPS URL."
            return
        }

        isProcessing = true
        errorMessage = nil
        latestProposal = nil

        let combinedInput = "\(webResearchURL)\n\(inputText)"
        let input = SkillInput(inputType: .webResearchQuery, textContent: combinedInput)

        if AutopilotFeatureFlags.autopilotEnabled {
            let autopilotInput = AutopilotInput(
                rawIntentText: combinedInput,
                skillId: "web_research",
                skillInput: input,
                source: .skill
            )
            AutopilotOrchestrator.shared.start(input: autopilotInput)
            isProcessing = false
            showAutopilot = true
            return
        }

        let proposal = await registry.runSkill("web_research", input: input)

        withAnimation(.easeInOut(duration: 0.2)) {
            if let proposal {
                latestProposal = proposal
            } else {
                errorMessage = "Web research failed. Verify URL is on allowlist and accessible."
            }
            isProcessing = false
        }
    }

    // MARK: - Calendar Quick Action

    private var calendarQuickAction: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(OKColor.riskOperational)
                .font(.system(size: 14))

            if calendarConnector.isAuthorized {
                Button {
                    Task { await loadCalendarData() }
                } label: {
                    Text(selectedSkillId == "meeting_actions" ? "Load Today's Meetings" : "Scan Calendar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OKColor.actionPrimary)
                }

                Spacer()

                if calendarConnector.eventCount > 0 {
                    Text("\(calendarConnector.eventCount) events")
                        .font(.system(size: 11))
                        .foregroundStyle(OKColor.textMuted)
                }
            } else {
                Button {
                    Task { await calendarConnector.requestAccess() }
                } label: {
                    Text("Grant Calendar Access (read-only)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OKColor.riskWarning)
                }
                Spacer()
            }
        }
        .padding(10)
        .background(OKColor.backgroundTertiary)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(OKColor.borderSubtle, lineWidth: 0.5)
        )
        .cornerRadius(8)
    }

    @MainActor
    private func loadCalendarData() async {
        let input: SkillInput?
        if selectedSkillId == "meeting_actions" {
            input = await calendarConnector.fetchTodaysMeetingsInput()
        } else {
            input = await calendarConnector.fetchUpcomingEventsInput()
        }

        if let input {
            withAnimation(.easeInOut(duration: 0.2)) {
                inputText = input.textContent
            }
        } else {
            errorMessage = "No calendar events found. Paste text instead."
        }
    }

    // MARK: - Processing

    private var processingIndicator: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(OKColor.actionPrimary)
            Text("Analyzing...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OKColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .okCard()
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(OKColor.riskCritical)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(OKColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(OKColor.riskCritical.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(OKColor.riskCritical.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    // MARK: - Decision Confirmation

    private func decisionBanner(_ message: String) -> some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(OKColor.riskNominal.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(OKColor.riskNominal.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    // MARK: - Proposal Result Card

    private func proposalResultCard(_ proposal: ProposalPack) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            OKSectionHeader("LATEST PROPOSAL")

            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    riskBadge(proposal.riskAnalysis.consequenceTier)
                    Spacer()
                    Text(proposal.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundStyle(OKColor.textMuted)
                }

                // Summary
                Text(proposal.humanSummary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OKColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                // Steps
                if !proposal.toolPlan.executionSteps.isEmpty {
                    Divider().background(OKColor.borderSubtle)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("PROPOSED ACTIONS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(OKColor.textMuted)
                            .tracking(0.8)

                        ForEach(proposal.toolPlan.executionSteps) { step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(step.order).")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(OKColor.actionPrimary)
                                    .frame(width: 20, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.action)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(OKColor.textPrimary)
                                    Text(step.description)
                                        .font(.system(size: 12))
                                        .foregroundStyle(OKColor.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }

                // Approvals
                Divider().background(OKColor.borderSubtle)

                HStack {
                    Label {
                        Text("Signers: \(proposal.toolPlan.requiredApprovals.multiSignerCount)")
                            .font(.system(size: 12, weight: .medium))
                    } icon: {
                        Image(systemName: "person.badge.shield.checkmark")
                    }
                    .foregroundStyle(OKColor.textSecondary)

                    Spacer()

                    if proposal.toolPlan.requiredApprovals.requiresBiometric {
                        Label("Biometric", systemImage: "faceid")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(OKColor.riskWarning)
                    }

                    Text(proposal.riskAnalysis.reversibilityClass.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(OKColor.riskNominal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(OKColor.riskNominal.opacity(0.12))
                        .cornerRadius(6)
                }

                // Route to approval
                Button {
                    // Route to ProposalReviewPanel / ApprovalSession pipeline
                    routeToApproval(proposal)
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Route for Approval")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(OKColor.actionPrimary)
                    .cornerRadius(10)
                }
            }
            .okCard()
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

    // MARK: - Recent Proposals

    private var recentProposalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !registry.recentProposals.isEmpty {
                OKSectionHeader("RECENT PROPOSALS")

                ForEach(registry.recentProposals.prefix(10)) { proposal in
                    NavigationLink(value: proposal) {
                        HStack(spacing: 10) {
                            riskBadge(proposal.riskAnalysis.consequenceTier)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(proposal.toolPlan.originatingAction.replacingOccurrences(of: "_skill", with: "").replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(OKColor.textPrimary)
                                Text(proposal.humanSummary.prefix(80))
                                    .font(.system(size: 12))
                                    .foregroundStyle(OKColor.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Text(proposal.createdAt.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 11))
                                    .foregroundStyle(OKColor.textMuted)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(OKColor.textMuted.opacity(0.5))
                            }
                        }
                        .padding(12)
                        .background(OKColor.backgroundSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(OKColor.borderSubtle, lineWidth: 0.5)
                        )
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 20))
                        .foregroundStyle(OKColor.textMuted.opacity(0.5))
                    Text("No proposals yet. Run a skill above to generate decisions.")
                        .font(.system(size: 13))
                        .foregroundStyle(OKColor.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func runSkill() async {
        guard let skillId = selectedSkillId else { return }
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // ── Autopilot path: auto-advance to approval ─────────
        if AutopilotFeatureFlags.autopilotEnabled {
            let inputType: SkillInputType = {
                switch skillId {
                case "inbox_triage": return .emailThread
                case "meeting_actions": return .meetingTranscript
                case "approval_router": return .proposalPack
                case "web_research": return .webResearchQuery
                default: return .pastedText
                }
            }()

            let skillInput = SkillInput(inputType: inputType, textContent: inputText)
            let input = AutopilotInput(
                rawIntentText: inputText,
                skillId: skillId,
                skillInput: skillInput,
                source: .skill
            )
            AutopilotOrchestrator.shared.start(input: input)
            showAutopilot = true
            return
        }

        // ── Manual path: run skill inline ────────────────────
        isProcessing = true
        errorMessage = nil
        latestProposal = nil

        let inputType: SkillInputType = {
            switch skillId {
            case "inbox_triage": return .emailThread
            case "meeting_actions": return .meetingTranscript
            case "approval_router": return .proposalPack
            case "web_research": return .webResearchQuery
            default: return .pastedText
            }
        }()

        let input = SkillInput(inputType: inputType, textContent: inputText)
        let proposal = await registry.runSkill(skillId, input: input)

        withAnimation(.easeInOut(duration: 0.2)) {
            if let proposal {
                latestProposal = proposal
            } else {
                errorMessage = "Skill failed to generate proposal."
            }
            isProcessing = false
        }
    }

    private func routeToApproval(_ proposal: ProposalPack) {
        let session = ApprovalSession(proposal: proposal)
        ApprovalSessionStore.shared.register(session)

        try? EvidenceEngine.shared.logGenericArtifact(
            type: "skill_proposal_routed_to_approval",
            planId: proposal.id,
            jsonString: """
            {"proposalId":"\(proposal.id)","sessionId":"\(session.id)","riskTier":"\(proposal.riskAnalysis.consequenceTier.rawValue)"}
            """
        )

        // Present the approval review panel
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
}
