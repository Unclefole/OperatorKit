import SwiftUI

// ============================================================================
// GOVERNED EXECUTION VIEW — SUPERVISED AUTONOMY UI
//
// This view runs the GovernedAgentLoop and displays live progress:
//   Pass 1: Model reasons → searches/fetches → results shown
//   Pass 2: Model evaluates gaps → more search/fetch
//   Pass 3: Model synthesizes executive artifact
//   → ProposalPack generated → Human Approval REQUIRED
//
// ARCHITECTURAL INVARIANT:
// ─────────────────────────
// This view is ONLY reachable when CapabilityRouter returns .execute().
// No DraftGenerator is invoked. The GovernedAgentLoop orchestrates
// AI reasoning + governed tool execution within strict bounds.
//
// "The model can think. Only the kernel can act."
//
// SAFETY:
// ❌ No DraftGenerator
// ❌ No autonomous side effects
// ❌ No network calls outside ConnectorGate + NetworkPolicyEnforcer
// ❌ No recursive task spawning
// ✅ Bounded agent loop (max 3 passes, max 8 tool calls)
// ✅ Human approval required before any action
// ✅ Evidence logged at every stage
// ✅ Model NEVER executes tools directly
// ============================================================================

struct GovernedExecutionView: View {
    let skillId: String
    let requestText: String

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState

    @StateObject private var agentLoop = GovernedAgentLoop()

    @State private var proposal: ProposalPack?
    @State private var session: ApprovalSession?
    @State private var errorReason: String?
    @State private var showProposalReview: Bool = false
    @State private var showArtifact: Bool = false
    @State private var executionTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            OKColor.backgroundPrimary.ignoresSafeArea()

            if let reason = errorReason {
                FailClosedView(
                    context: "Governed Execution",
                    reason: reason,
                    suggestion: "Check feature flags and API keys, then try again."
                )
            } else if agentLoop.isComplete && proposal != nil {
                approvalReadyView
            } else if agentLoop.isComplete && showArtifact {
                artifactPreviewView
            } else {
                agentProgressView
            }
        }
        .navigationTitle("Autonomous Execution")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if !agentLoop.isComplete && agentLoop.phase != .idle {
                    Button("Abort") {
                        abort()
                    }
                    .foregroundStyle(OKColor.emergencyStop)
                    .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showProposalReview) {
            if let proposal = proposal, let session = session {
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
                    context: "GovernedExecutionView.sheet",
                    reason: "Proposal or session is nil when approval sheet opened."
                )
            }
        }
        .onAppear {
            startAgentLoop()
        }
        .onDisappear {
            executionTask?.cancel()
        }
    }

    // MARK: - Agent Progress View

    private var agentProgressView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Autonomous mode trust banner
                autonomousModeBanner

                // Header with pass indicator
                headerSection

                // Live status
                statusSection

                // Step indicators
                stepsSection

                // Tool call log
                if !agentLoop.toolCallLog.isEmpty {
                    toolCallLogSection
                }

                // Pass history
                if !agentLoop.passes.isEmpty {
                    passHistorySection
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    // MARK: - Autonomous Mode Banner (Critical UX Trust Signal)

    private var autonomousModeBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(OKColor.actionPrimary.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(OKColor.actionPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AUTONOMOUS MODE")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .kerning(1.5)
                        .foregroundStyle(OKColor.actionPrimary)

                    Text("No privileged data required. OperatorKit is gathering public intelligence using governed connectors.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(OKColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 16) {
                Label("ConnectorGate", systemImage: "lock.shield")
                Label("DataDiode", systemImage: "shield.checkered")
                Label("Bounded", systemImage: "timer")
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(OKColor.riskNominal)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(OKColor.actionPrimary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(OKColor.actionPrimary.opacity(0.2), lineWidth: 1)
        )
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            // Animated ring showing pass progress
            ZStack {
                Circle()
                    .stroke(OKColor.borderSubtle, lineWidth: 3)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: passProgress)
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: passProgress)

                Image(systemName: phaseIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(phaseColor)
            }

            Text("Pass \(max(1, agentLoop.currentPass)) of \(AgentLoopLimits.maxPasses)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(OKColor.textSecondary)
        }
    }

    private var statusSection: some View {
        VStack(spacing: 6) {
            Text(agentLoop.statusMessage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OKColor.textPrimary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: agentLoop.statusMessage)

            if agentLoop.phase != .idle && agentLoop.phase != .complete {
                ProgressView()
                    .tint(phaseColor)
                    .scaleEffect(0.8)
            }
        }
    }

    private var stepsSection: some View {
        VStack(spacing: 10) {
            stepRow("Agent Pass 1 — Generating search queries",
                    done: agentLoop.currentPass >= 1,
                    active: agentLoop.phase == .planning)
            stepRow("Agent Pass 2 — Fetching authoritative sources",
                    done: searchComplete,
                    active: agentLoop.phase == .searching)
            stepRow("Agent Pass 3 — Extracting intelligence",
                    done: fetchComplete,
                    active: agentLoop.phase == .fetching)
            stepRow("Agent Pass 4 — Evaluating gaps",
                    done: agentLoop.currentPass >= 2,
                    active: agentLoop.phase == .evaluating)
            stepRow("Agent Pass 5 — Synthesizing executive brief",
                    done: agentLoop.phase == .complete,
                    active: agentLoop.phase == .synthesizing)
            stepRow("Human Approval Required",
                    done: proposal != nil,
                    active: false)
        }
        .padding(16)
        .background(OKColor.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(OKColor.borderSubtle, lineWidth: 1)
        )
        .cornerRadius(14)
    }

    private var toolCallLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "terminal")
                    .font(.system(size: 12, weight: .bold))
                Text("TOOL CALLS")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.2)
                Spacer()
                Text("\(agentLoop.toolCallLog.count)/\(AgentLoopLimits.maxToolCalls)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(OKColor.textMuted)

            ForEach(Array(agentLoop.toolCallLog.enumerated()), id: \.offset) { idx, result in
                toolCallRow(index: idx + 1, result: result)
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

    private func toolCallRow(index: Int, result: AgentToolResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(result.success ? OKColor.riskNominal : OKColor.emergencyStop)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(toolCallLabel(result.toolCall))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OKColor.textPrimary)
                    Spacer()
                    Text("\(result.durationMs)ms")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(OKColor.textMuted)
                }

                Text(String(result.output.prefix(120)) + (result.output.count > 120 ? "..." : ""))
                    .font(.system(size: 11))
                    .foregroundStyle(OKColor.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var passHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12, weight: .bold))
                Text("REASONING PASSES")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.2)
                Spacer()
            }
            .foregroundStyle(OKColor.textMuted)

            ForEach(agentLoop.passes) { pass in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Pass \(pass.id)")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                        Text("\(pass.toolCalls.count) tool call(s)")
                            .font(.system(size: 11, weight: .medium))
                        Text("\(pass.durationMs)ms")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(OKColor.textMuted)
                    }
                    .foregroundStyle(OKColor.textSecondary)

                    Text(String(pass.modelReasoning.prefix(200)))
                        .font(.system(size: 11))
                        .foregroundStyle(OKColor.textMuted)
                        .lineLimit(3)
                }
                .padding(10)
                .background(OKColor.backgroundTertiary)
                .cornerRadius(8)
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

    // MARK: - Artifact Preview View

    private var artifactPreviewView: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(OKColor.riskNominal.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 28))
                        .foregroundStyle(OKColor.riskNominal)
                }

                Text("Research Artifact")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(OKColor.textPrimary)

                // Artifact content
                if let artifact = agentLoop.synthesizedArtifact {
                    Text(artifact)
                        .font(.system(size: 14))
                        .foregroundStyle(OKColor.textPrimary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(OKColor.backgroundSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(OKColor.borderSubtle, lineWidth: 1)
                        )
                        .cornerRadius(14)
                }

                // Provenance footer
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 10))
                        Text("Supervised autonomy — \(agentLoop.passes.count) pass(es), \(agentLoop.toolCallLog.count) tool call(s)")
                            .font(.system(size: 10))
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 10))
                        Text("All tool calls executed through ConnectorGate + NetworkPolicyEnforcer")
                            .font(.system(size: 10))
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 10))
                        Text("Human approval required before any external distribution")
                            .font(.system(size: 10))
                    }
                }
                .foregroundStyle(OKColor.textMuted)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(OKColor.backgroundTertiary)
                .cornerRadius(10)

                // Action buttons
                Button {
                    generateProposalFromArtifact()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                        Text("Submit for Approval")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(OKColor.actionPrimary)
                    .cornerRadius(14)
                }

                Button {
                    nav.goBack()
                } label: {
                    Text("Discard & Go Back")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(OKColor.textMuted)
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    // MARK: - Approval Ready View

    private var approvalReadyView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(OKColor.riskNominal.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(OKColor.riskNominal)
            }

            Text("Research Complete")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(OKColor.textPrimary)

            Text("Supervised autonomy loop finished. Proposal ready for review.")
                .font(.system(size: 15))
                .foregroundStyle(OKColor.textSecondary)
                .multilineTextAlignment(.center)

            if let proposal = proposal {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        riskBadge(proposal.riskAnalysis.consequenceTier)
                        Spacer()
                        Text("\(agentLoop.passes.count) pass(es), \(agentLoop.toolCallLog.count) tools")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(OKColor.textMuted)
                    }

                    Text(proposal.humanSummary)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(OKColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 10))
                        Text("Bounded agent loop. Model reasoned; kernel executed. No DraftGenerator.")
                            .font(.system(size: 10))
                            .foregroundStyle(OKColor.textMuted)
                    }
                }
                .okCard()
            }

            Spacer()

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
                nav.goBack()
            } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OKColor.textMuted)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Pipeline Execution

    private func startAgentLoop() {
        executionTask = Task { @MainActor in
            do {
                let result = try await agentLoop.execute(request: requestText)

                // Show artifact preview first
                showArtifact = true

                logEvidence(type: "governed_agent_loop_complete",
                           detail: "passes=\(result.passes.count), tools=\(result.totalToolCalls), duration=\(result.totalDurationMs)ms")
            } catch {
                if !Task.isCancelled {
                    errorReason = error.localizedDescription
                    logEvidence(type: "governed_agent_loop_failed", detail: error.localizedDescription)
                }
            }
        }
    }

    private func generateProposalFromArtifact() {
        guard let artifact = agentLoop.synthesizedArtifact else { return }

        // Build ProposalPack from the synthesized artifact
        let steps = [
            ExecutionStepDefinition(
                order: 1,
                action: "Review synthesized research artifact",
                description: "AI-generated executive brief based on governed web research",
                isMutation: false,
                rollbackAction: nil
            )
        ]

        let toolPlan = ToolPlan(
            intent: ToolPlanIntent(
                type: .reviewDocument,
                summary: "Supervised autonomy research: \(agentLoop.passes.count) pass(es), \(agentLoop.toolCallLog.count) tool call(s)",
                targetDescription: "AI-synthesized research artifact"
            ),
            originatingAction: "governed_agent_loop",
            riskScore: 30,
            riskTier: .medium,
            riskReasons: [
                "AI-generated content requires human review",
                "Sources from public web — verify accuracy",
                "Stop before external distribution"
            ],
            reversibility: .reversible,
            reversibilityReason: "Read-only research — no side effects",
            requiredApprovals: ApprovalRequirement(
                approvalsNeeded: 1,
                requiresBiometric: false,
                requiresPreview: true
            ),
            probes: [],
            executionSteps: steps
        )

        let permissions = PermissionManifest(scopes: [
            PermissionScope(domain: .network, access: .read, detail: "governed_web_research")
        ])

        let risk = RiskConsequenceAnalysis(
            riskScore: 30,
            consequenceTier: .medium,
            reversibilityClass: .reversible,
            blastRadius: .selfOnly,
            reasons: [
                "AI-synthesized content — human must verify",
                "Used Brave Search API + GovernedWebFetcher",
                "Content redacted through DataDiode"
            ]
        )

        // Build rich evidence citations with connector metadata + source URLs
        let searchResults = agentLoop.toolCallLog.filter {
            if case .search = $0.toolCall { return true }; return false
        }
        let fetchResults = agentLoop.toolCallLog.filter {
            if case .fetchPage = $0.toolCall { return true }; return false
        }
        let hasRealSources = !searchResults.isEmpty || !fetchResults.isEmpty
        let provenanceLabel = hasRealSources ? "FETCHED-BACKED" : "MODEL-ONLY"

        var citations: [EvidenceCitation] = []

        // Connector-level evidence
        citations.append(EvidenceCitation(
            sourceType: .document,
            reference: "Connector: brave_search v1.0 via ConnectorGate",
            redactedSummary: "\(searchResults.count) search queries executed, \(fetchResults.count) pages fetched. Provenance: \(provenanceLabel)"
        ))

        // Individual tool call evidence with source URLs
        for result in agentLoop.toolCallLog.prefix(10) {
            let reference: String
            switch result.toolCall {
            case .search(let query):
                reference = "[search] connectorId=brave_search, query=\"\(String(query.prefix(50)))\""
            case .fetchPage(let url):
                reference = "[fetch] connectorId=web_fetcher, url=\(String(url.prefix(80)))"
            case .synthesize:
                reference = "[synthesize] model-generated final artifact"
            }
            citations.append(EvidenceCitation(
                sourceType: .document,
                reference: reference,
                redactedSummary: DataDiode.redact(String(result.output.prefix(200)))
            ))
        }

        let pack = ProposalPack(
            source: .user,
            toolPlan: toolPlan,
            permissionManifest: permissions,
            riskAnalysis: risk,
            costEstimate: CostEstimate.onDevice,
            evidenceCitations: citations,
            humanSummary: "[\(provenanceLabel)] Supervised Autonomy Research (\(agentLoop.passes.count) passes, \(agentLoop.toolCallLog.count) tools): \(String(artifact.prefix(180)))"
        )

        self.proposal = pack

        // Create approval session
        let approvalSession = ApprovalSession(proposal: pack)
        ApprovalSessionStore.shared.register(approvalSession)
        self.session = approvalSession

        // Log comprehensive evidence with connector IDs and source URLs
        let fetchedURLs = agentLoop.toolCallLog.compactMap { result -> String? in
            if case .fetchPage(let url) = result.toolCall, result.success { return url }
            return nil
        }
        let searchQueries = agentLoop.toolCallLog.compactMap { result -> String? in
            if case .search(let q) = result.toolCall, result.success { return q }
            return nil
        }
        logEvidence(type: "governed_agent_proposal_ready",
                   detail: "proposalId=\(pack.id), sessionId=\(approvalSession.id), provenance=\(provenanceLabel), connectors=[brave_search,web_fetcher], searches=\(searchQueries.count), fetches=\(fetchedURLs.count), urls=\(fetchedURLs.prefix(5).joined(separator: ",").prefix(200))")

        // Show approval
        showArtifact = false
    }

    // MARK: - Decision Handling

    private func handleDecision(_ decision: ApprovalSession.Decision, session: ApprovalSession) {
        ApprovalSessionStore.shared.recordDecision(session.id, decision: decision)
        showProposalReview = false
        logEvidence(type: "governed_execution_decision", detail: "decision=\(decision)")
        nav.goBack()
    }

    private func abort() {
        executionTask?.cancel()
        agentLoop.abort()
        errorReason = "Aborted by operator."
        logEvidence(type: "governed_execution_aborted", detail: "Operator aborted supervised autonomy loop.")
    }

    // MARK: - Computed Properties

    private var passProgress: Double {
        guard agentLoop.currentPass > 0 else { return 0 }
        let phaseProgress: Double
        switch agentLoop.phase {
        case .idle: phaseProgress = 0
        case .planning: phaseProgress = 0.15
        case .searching: phaseProgress = 0.35
        case .fetching: phaseProgress = 0.55
        case .evaluating: phaseProgress = 0.70
        case .synthesizing: phaseProgress = 0.85
        case .complete: phaseProgress = 1.0
        case .failed, .aborted: phaseProgress = 0
        }
        return phaseProgress
    }

    private var phaseColor: Color {
        switch agentLoop.phase {
        case .idle: return OKColor.textMuted
        case .planning: return OKColor.actionPrimary
        case .searching: return OKColor.riskOperational
        case .fetching: return OKColor.riskOperational
        case .evaluating: return OKColor.actionPrimary
        case .synthesizing: return OKColor.riskNominal
        case .complete: return OKColor.riskNominal
        case .failed, .aborted: return OKColor.emergencyStop
        }
    }

    private var phaseIcon: String {
        switch agentLoop.phase {
        case .idle: return "circle"
        case .planning: return "brain.head.profile"
        case .searching: return "magnifyingglass"
        case .fetching: return "globe"
        case .evaluating: return "brain"
        case .synthesizing: return "doc.text"
        case .complete: return "checkmark.shield.fill"
        case .failed, .aborted: return "xmark.shield"
        }
    }

    private var searchComplete: Bool {
        agentLoop.toolCallLog.contains { if case .search = $0.toolCall { return true }; return false }
    }

    private var fetchComplete: Bool {
        agentLoop.toolCallLog.contains { if case .fetchPage = $0.toolCall { return true }; return false }
    }

    // MARK: - Helpers

    private func stepRow(_ label: String, done: Bool, active: Bool = false) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(done ? OKColor.riskNominal.opacity(0.2) : active ? OKColor.actionPrimary.opacity(0.2) : OKColor.backgroundTertiary)
                    .frame(width: 24, height: 24)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(OKColor.riskNominal)
                } else if active {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(OKColor.actionPrimary)
                }
            }

            Text(label)
                .font(.system(size: 14, weight: active ? .semibold : .regular))
                .foregroundStyle(done || active ? OKColor.textPrimary : OKColor.textMuted)

            Spacer()

            if active {
                ProgressView()
                    .tint(OKColor.actionPrimary)
                    .scaleEffect(0.7)
            }
        }
    }

    private func toolCallLabel(_ call: AgentToolCall) -> String {
        switch call {
        case .search(let query): return "Search: \(String(query.prefix(50)))"
        case .fetchPage(let url): return "Fetch: \(String(url.prefix(50)))"
        case .synthesize: return "Synthesize"
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

    private func logEvidence(type: String, detail: String) {
        try? EvidenceEngine.shared.logGenericArtifact(
            type: type,
            planId: proposal?.id ?? UUID(),
            jsonString: """
            {"skillId":"\(skillId)","detail":"\(detail)","timestamp":"\(Date().ISO8601Format())"}
            """
        )
    }
}

// MARK: - Execution Phase (kept for backward compat)

enum ExecutionPhase: Int, Comparable {
    case preparing = 0
    case observing = 1
    case analyzing = 2
    case proposing = 3
    case readyForApproval = 4

    static func < (lhs: ExecutionPhase, rhs: ExecutionPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Errors

enum GovernedExecutionError: LocalizedError {
    case skillNotFound(String)
    case connectorFailed(String)

    var errorDescription: String? {
        switch self {
        case .skillNotFound(let id): return "Skill '\(id)' not found in registry."
        case .connectorFailed(let reason): return "Connector failed: \(reason)"
        }
    }
}
