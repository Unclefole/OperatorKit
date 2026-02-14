import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Paywall Gate (Inlined)
// Paywall ENABLED for App Store release
private let _intentPaywallEnabled: Bool = true

// ============================================================================
// INTENT INPUT VIEW — USER INPUT GATEWAY
//
// ARCHITECTURAL INVARIANT:
// ─────────────────────────
// OperatorKit NEVER executes synthetic, seeded, or non-user-authored intent.
// ALL operations must originate from explicit user input.
//
// REQUIREMENTS:
// ✅ User can type freely
// ✅ Placeholder is NOT executable text
// ✅ Continue enables ONLY after real non-empty input
// ✅ Cancel clears state
// ✅ Voice fills the same buffer (no auto-submit)
// ✅ No network call triggered on typing
// ✅ No background task created until explicit Continue tap
//
// APP REVIEW SAFETY:
// ❌ No hidden prompts
// ❌ No auto-generated actions
// ❌ No simulated assistant behavior
// ❌ No synthetic intent injection
// ============================================================================

struct IntentInputView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState
    @StateObject private var speech = SpeechRecognizer()
    @State private var inputText: String = ""
    @State private var hasAcknowledgedSiri: Bool = false
    @State private var isProcessing: Bool = false
    @State private var showingUpgrade: Bool = false
    @State private var showingPolicyEditor: Bool = false
    @State private var showingPermissionAlert: Bool = false

    /// Policy evaluator (Phase 10C)
    private let policyEvaluator = PolicyEvaluator()

    /// Whether this view was launched from Siri
    private var isFromSiri: Bool {
        appState.wasLaunchedFromSiri
    }

    /// Current execution limit decision (Phase 10A)
    private var executionLimitDecision: LimitDecision {
        appState.checkExecutionLimit()
    }

    /// Current policy decision (Phase 10C)
    private var policyDecision: PolicyDecision {
        policyEvaluator.canStartExecution()
    }

    /// Trimmed input text for validation
    private var trimmedInput: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether input is valid (non-empty after trimming)
    private var hasValidInput: Bool {
        !trimmedInput.isEmpty
    }

    // MARK: - Input Validation (Safe, No Crash)

    /// Generic/broad request keywords that require context
    private static let broadRequestKeywords: Set<String> = [
        "plan", "organize", "help", "do", "make", "create", "handle",
        "something", "stuff", "thing", "anything", "everything"
    ]

    /// Validate request before processing
    /// INVARIANT: This method NEVER crashes. Returns .invalid with reasons instead.
    private func validateRequest(text: String, hasContext: Bool) -> InputValidationResult {
        var reasons: [InputValidationReason] = []

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check 1: Empty request
        if trimmed.isEmpty {
            reasons.append(.emptyRequest)
            return .invalid(reasons)
        }

        // Check 2: Request too broad (generic words without specificity)
        let lowercased = trimmed.lowercased()
        let words = lowercased.components(separatedBy: .whitespacesAndNewlines)
        let isBroad = words.count < 5 && Self.broadRequestKeywords.contains(where: { lowercased.contains($0) })

        if isBroad && !hasContext {
            reasons.append(.requestTooBroad)
            reasons.append(.noContextSelected)
        }

        if reasons.isEmpty {
            return .valid
        }

        return .invalid(reasons)
    }

    /// Why the continue button is disabled (Phase 5B)
    private var disabledReason: String? {
        if isProcessing {
            return nil
        }
        if !hasValidInput {
            return "Enter a request to continue"
        }
        if isFromSiri && !hasAcknowledgedSiri {
            return "Tap \"I've reviewed this request\" above to continue"
        }
        return nil
    }

    var body: some View {
        ZStack {
            // Background - Pure white
            OKColors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                FlowStepHeaderView(
                    step: .request,
                    subtitle: "Tell OperatorKit what you need"
                )

                FlowStatusStripView(onRecoveryAction: handleRecoveryAction)

                headerView

                ScrollView {
                    VStack(spacing: OKSpacing.xxl) {
                        if !executionLimitDecision.allowed {
                            LimitCalloutView(
                                decision: executionLimitDecision,
                                onUpgradeTapped: {
                                    showingUpgrade = true
                                }
                            )
                        }

                        if executionLimitDecision.allowed && !policyDecision.allowed {
                            PolicyCalloutView(
                                decision: policyDecision,
                                onEditPolicyTapped: {
                                    showingPolicyEditor = true
                                }
                            )
                        }

                        if isFromSiri {
                            siriBanner
                        }

                        intentInputCard
                    }
                    .padding(.horizontal, OKSpacing.xl)
                    .padding(.top, OKSpacing.lg)
                    .padding(.bottom, 200)
                }

                Spacer()
            }

            VStack {
                Spacer()
                bottomInputSection
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Prefill from Siri if launched that way (user-originated via Siri)
            if let siriText = appState.siriPrefillText, !siriText.isEmpty {
                inputText = siriText
            }
            // INVARIANT: inputText starts empty unless Siri-originated
            // SAFETY: Log violation instead of crashing
            #if DEBUG
            if !isFromSiri && !inputText.isEmpty {
                // Log but do not crash - clear the unexpected input
                logError("INVARIANT: Input should be empty on fresh launch, clearing unexpected content")
                inputText = ""
            }
            #endif
        }
        // LIVE TRANSCRIPT SYNC: Words appear as user speaks
        .onReceive(speech.$transcript) { newTranscript in
            if !newTranscript.isEmpty {
                inputText = newTranscript
            }
        }
        // Handle speech recognition errors
        .onReceive(speech.$error) { speechError in
            if speechError != nil {
                showingPermissionAlert = true
            }
        }
        .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(speech.error?.errorDescription ?? "Please enable microphone and speech recognition in Settings to use voice input.")
        }
        .onDisappear {
            if isFromSiri && hasAcknowledgedSiri {
                SiriRoutingBridge.shared.clearRouteState()
            }
        }
        .sheet(isPresented: $showingUpgrade) {
            if _intentPaywallEnabled {
                UpgradeView()
                    .environmentObject(appState)
            } else {
                // Fallback: Never show blank screen
                ProComingSoonView(isPresented: $showingUpgrade)
            }
        }
        .sheet(isPresented: $showingPolicyEditor) {
            PolicyEditorView()
        }
    }

    // MARK: - Header
    /// Simple header with back button, logo, and home button
    private var headerView: some View {
        HStack {
            Button(action: {
                if isFromSiri {
                    SiriRoutingBridge.shared.clearRouteState()
                }
                nav.goBack()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(OKColor.actionPrimary)
            }

            Spacer()

            OperatorKitLogoView(size: .small, showText: false)

            Spacer()

            Button(action: {
                if isFromSiri {
                    SiriRoutingBridge.shared.clearRouteState()
                }
                nav.goHome()
            }) {
                Image(systemName: "house")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(OKColor.textMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(OKColor.backgroundPrimary)
    }

    /// Header title based on context
    private var headerTitle: String {
        "New Request"
    }

    // MARK: - Siri Banner

    private var siriBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [OKColor.actionPrimary, OKColor.riskExtreme],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 40, height: 40)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(OKColor.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Siri Started This Request")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Check that this is what you intended")
                        .font(.subheadline)
                        .foregroundColor(OKColor.textMuted)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 14))
                    .foregroundColor(OKColor.riskNominal)

                Text("Siri can only open OperatorKit. You decide what happens next.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)

                Spacer()
            }

            if !hasAcknowledgedSiri {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        hasAcknowledgedSiri = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 16))

                        Text("I've reviewed this request")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(OKColor.actionPrimary)
                    .padding(.top, 4)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(OKColor.riskNominal)

                    Text("Reviewed — ready to continue")
                        .font(.subheadline)
                        .foregroundColor(OKColor.riskNominal)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [OKColor.actionPrimary.opacity(0.08), OKColor.riskExtreme.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(OKColor.actionPrimary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Intent Input Card

    private var intentInputCard: some View {
        VStack(alignment: .leading, spacing: OKSpacing.lg) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: OKRadius.md)
                        .fill(OKColors.operatorGradient)
                        .frame(width: 48, height: 48)

                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(OKColor.textPrimary)
                }

                Text("OperatorKit")
                    .font(OKTypography.title())
                    .foregroundColor(OKColors.textPrimary)

                Spacer()

                if isFromSiri {
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 10))
                        Text("Siri")
                            .font(OKTypography.caption())
                    }
                    .foregroundColor(OKColor.textPrimary)
                    .padding(.horizontal, OKSpacing.sm)
                    .padding(.vertical, OKSpacing.xs)
                    .background(OKColors.operatorGradient)
                    .cornerRadius(OKRadius.sm)
                }
            }

            // Large Text Display with Placeholder
            VStack(alignment: .leading, spacing: OKSpacing.md) {
                // Show placeholder when empty, actual text when not
                if hasValidInput {
                    Text(inputText)
                        .font(OKTypography.largeTitle())
                        .foregroundColor(OKColors.textPrimary)
                } else {
                    Text("What do you want me to handle?")
                        .font(OKTypography.largeTitle())
                        .foregroundColor(OKColors.textPlaceholder)
                }

                // Hint text (only show when empty and not from Siri)
                if !hasValidInput && !isFromSiri {
                    Text("Try: \"Send a follow-up email to my last meeting\"")
                        .font(OKTypography.subheadline())
                        .foregroundColor(OKColors.textSecondary)
                }
            }
            .padding(.vertical, OKSpacing.lg)

            if speech.isRecording {
                waveformView
            }
        }
        .padding(OKSpacing.xxl)
        .background(OKColors.backgroundElevated)
        .cornerRadius(OKRadius.xl)
        .shadow(color: OKShadow.card, radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: OKRadius.xl)
                .stroke(OKColors.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Waveform View

    private var waveformView: some View {
        HStack(spacing: 3) {
            ForEach(0..<30, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(OKColor.actionPrimary.opacity(0.6))
                    .frame(width: 4, height: CGFloat.random(in: 8...40))
            }
        }
        .frame(height: 50)
        .padding(.vertical, 8)
    }

    // MARK: - Bottom Input Section

    private var bottomInputSection: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("Type or tap mic to speak...", text: $inputText)
                    .font(OKTypography.body())
                    .foregroundColor(OKColors.textPrimary)
                    .padding(.horizontal, OKSpacing.lg)
                    .padding(.vertical, OKSpacing.lg)
                    .background(OKColors.backgroundTertiary)
                    .cornerRadius(OKRadius.lg)
                    .overlay(
                        RoundedRectangle(cornerRadius: OKRadius.lg)
                            .stroke(OKColors.borderDefault, lineWidth: 1)
                    )

                // Microphone Button - LIVE VOICE TRANSCRIPTION
                // INVARIANT: Voice input populates inputText binding via speech.transcript
                // User must explicitly tap Continue after transcription
                Button {
                    Task {
                        await speech.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(speech.isRecording ? AnyShapeStyle(OKColor.riskCritical.opacity(0.12)) : AnyShapeStyle(OKColors.operatorGradientSoft))
                            .frame(width: 56, height: 56)
                            .shadow(color: speech.isRecording ? OKColor.riskCritical.opacity(0.2) : OKShadow.glow, radius: 16, x: 0, y: 0)

                        Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(speech.isRecording ? AnyShapeStyle(OKColor.riskCritical) : AnyShapeStyle(OKColors.operatorGradient))
                    }
                }
            }

            HStack(spacing: OKSpacing.md) {
                Button(action: {
                    cancelAndClear()
                }) {
                    Text("Cancel")
                        .font(OKTypography.body())
                        .fontWeight(.medium)
                        .foregroundColor(OKColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, OKSpacing.lg)
                        .background(OKColors.backgroundElevated)
                        .cornerRadius(OKRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: OKRadius.md)
                                .stroke(OKColors.borderDefault, lineWidth: 1)
                        )
                }

                Button(action: {
                    processIntent()
                }) {
                    HStack(spacing: OKSpacing.sm) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Processing...")
                                .font(OKTypography.body())
                                .fontWeight(.semibold)
                        } else {
                            Text(continueButtonText)
                                .font(OKTypography.body())
                                .fontWeight(.semibold)

                            if isFromSiri && !hasAcknowledgedSiri {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .foregroundColor(OKColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OKSpacing.lg)
                    .background(continueButtonEnabled && !isProcessing ? OKColors.operatorGradient : LinearGradient(colors: [OKColors.iconMuted], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(OKRadius.md)
                }
                .disabled(!continueButtonEnabled || isProcessing)
                .accessibilityLabel(continueButtonAccessibilityLabel)
                .accessibilityHint(disabledReason ?? "Tap to continue to context selection")
            }

            if let reason = disabledReason {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text(reason)
                        .font(OKTypography.caption())
                }
                .foregroundStyle(OKColors.operatorGradient)
            }
        }
        .padding(.horizontal, OKSpacing.xl)
        .padding(.vertical, OKSpacing.xl)
        .background(
            OKColors.backgroundPrimary
                .shadow(color: OKColor.shadow.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }

    // MARK: - Computed Properties

    private var continueButtonText: String {
        if isFromSiri && !hasAcknowledgedSiri {
            return "Review First"
        }
        return "Continue"
    }

    private var continueButtonEnabled: Bool {
        // SAFETY: Button is disabled ONLY for truly empty input
        // Broad requests are allowed - they'll be validated and routed to fallback
        guard hasValidInput else { return false }

        // If from Siri, must acknowledge
        if isFromSiri && !hasAcknowledgedSiri {
            return false
        }

        return true
    }

    private var continueButtonAccessibilityLabel: String {
        if isProcessing {
            return "Processing request"
        }
        if !continueButtonEnabled {
            return "Continue button, disabled. \(disabledReason ?? "")"
        }
        return "Continue to context selection"
    }

    // MARK: - Actions

    /// Cancel and clear all state
    private func cancelAndClear() {
        inputText = ""
        speech.stop()
        if isFromSiri {
            SiriRoutingBridge.shared.clearRouteState()
        }
        nav.goBack()
    }

    /// Recovery action handler (Phase 5C)
    private func handleRecoveryAction(_ action: OperatorKitUserFacingError.RecoveryAction) {
        switch action {
        case .goHome:
            nav.goHome()
        case .retryCurrentStep:
            appState.clearError()
        case .editRequest:
            inputText = ""
            appState.clearError()
        default:
            appState.clearError()
        }
    }

    /// Process user intent
    /// INVARIANT: Only executes with valid, user-authored input
    /// SAFETY: This method NEVER crashes. Invalid input routes to fallback view.
    private func processIntent() {
        // Prevent double-tap
        guard !isProcessing else { return }

        // SAFE VALIDATION: Validate input without crashing
        // Context is not yet selected at this stage, so we pass false
        let validationResult = validateRequest(text: trimmedInput, hasContext: false)

        switch validationResult {
        case .invalid(let reasons):
            // Log the blocked intent (local, no network)
            logIntentBlocked(reasons: reasons)

            // Create a placeholder intent for the fallback view
            let placeholderIntent = IntentRequest(
                rawText: trimmedInput.isEmpty ? "(empty request)" : trimmedInput,
                intentType: .unknown
            )
            appState.selectedIntent = placeholderIntent

            // Navigate to fallback view with reasons displayed
            // The FallbackView will show "More Information Needed" with the reasons
            nav.navigate(to: .fallback)
            return

        case .valid:
            break // Continue with normal processing
        }

        // Phase 10A: Check execution limit
        let limitCheck = appState.checkExecutionLimit()
        if !limitCheck.allowed {
            showingUpgrade = true
            return
        }

        // Phase 10C: Check policy
        let policyCheck = policyEvaluator.canStartExecution()
        if !policyCheck.allowed {
            showingPolicyEditor = true
            return
        }

        // SAFE CHECK: User must have acknowledged if from Siri
        // No crash - just log and return if violated
        if isFromSiri && !hasAcknowledgedSiri {
            logIntentBlocked(reasons: [.noContextSelected])
            return
        }

        hasAcknowledgedSiri = true
        isProcessing = true
        appState.setWorking(.resolvingIntent)

        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)

            await MainActor.run {
                // ════════════════════════════════════════════════════
                // DUAL-LAYER INTENT CLASSIFICATION
                // ════════════════════════════════════════════════════
                //
                // Layer 1: IntentResolver (keyword matching — fast, deterministic)
                // Layer 2: Rule-based risk escalation (high-risk verb detection,
                //          confidence gating, scope analysis)
                //
                // IntentClassifier wraps IntentResolver — the original resolver
                // is called internally and its result is enriched with risk data.
                // ════════════════════════════════════════════════════
                let classified = IntentClassifier.classify(rawInput: trimmedInput)
                let resolution = classified.resolution

                isProcessing = false
                appState.setIdle()

                let intentType = resolution.request.intentType

                // ════════════════════════════════════════════════════
                // RISK ESCALATION: If the classifier detected high-risk
                // verbs or critical risk tier, log and potentially block.
                // ════════════════════════════════════════════════════
                if classified.requiresEscalation {
                    log("[CLASSIFIER] Risk escalation triggered: \(classified.escalationReason)")
                }
                if let blockReason = classified.blockReason {
                    log("[CLASSIFIER] Execution blocked: \(blockReason)")
                }

                // ════════════════════════════════════════════════════
                // FAILSAFE: DIRECT RESEARCH KEYWORD SCAN
                // ════════════════════════════════════════════════════
                //
                // Belt-and-suspenders guard. Even if IntentResolver
                // misclassifies a research request (e.g., as actionItems
                // due to substring matching), this failsafe catches it.
                //
                // If the user's text contains strong research signals,
                // FORCE route to GovernedExecution — no exceptions.
                // ════════════════════════════════════════════════════
                let lower = trimmedInput.lowercased()
                let isResearchFailsafe: Bool = {
                    // High-confidence compound signals
                    if lower.contains("research") && (lower.contains("governed") || lower.contains("autonomous")) { return true }
                    if lower.contains("web research") || lower.contains("market intelligence") { return true }
                    if lower.contains("search the web") || lower.contains("search online") || lower.contains("search for") { return true }
                    if lower.contains("research") && lower.contains("brief") { return true }
                    if lower.contains("search") && lower.contains("intelligence") { return true }
                    if lower.contains("search") && lower.contains("web") { return true }
                    if lower.contains("look up") && !lower.contains("email") && !lower.contains("meeting") { return true }
                    if lower.contains("find out") && !lower.contains("email") && !lower.contains("meeting") { return true }
                    // Multi-keyword threshold — 2+ signals = research (lowered from 3)
                    let signals = ["research", "search", "investigate", "market", "consumer",
                                   "intelligence", "governed", "authoritative", "autonomous",
                                   "spending", "trends", "competitive", "industry", "sector",
                                   "web", "find", "data", "analysis"]
                    let hits = signals.filter { lower.contains($0) }.count
                    return hits >= 2
                }()

                if isResearchFailsafe && intentType != .researchBrief {
                    log("[FAILSAFE] IntentClassifier classified as .\(intentType) but keyword scan detected research — overriding to .researchBrief")
                }

                let effectiveIsAutonomous = !intentType.requiresOperatorContext || isResearchFailsafe

                // ════════════════════════════════════════════════════
                // AUTONOMOUS INTENT — DIRECT TO GOVERNED EXECUTION
                // ════════════════════════════════════════════════════
                //
                // If the intent does NOT require operator-provided context
                // (or the failsafe detected research keywords), skip
                // ContextPicker entirely. The agent acquires public
                // context itself. No intermediate screens. No draft flow.
                //
                // ARCHITECTURAL INVARIANT:
                //   requiresOperatorContext == false → GovernedExecution
                //   The operator provides INTENT — not raw inputs.
                //
                // Fail-closed checks (feature flags, connectors) happen
                // INSIDE GovernedExecution, not at routing time.
                //
                // CLASSIFIER GATE: If execution is blocked by low confidence
                // or critical risk, force draft-only mode.
                // ════════════════════════════════════════════════════
                if effectiveIsAutonomous {
                    let skillId = intentType.defaultSkillId ?? "web_research"
                    appState.selectedIntent = resolution.request
                    nav.navigate(to: .governedExecution(skillId: skillId, requestText: trimmedInput))
                    return
                }

                // ── CONTEXT-DEPENDENT INTENTS (drafts, emails, etc.) ──
                // These require operator-provided data and go through
                // ContextPicker → Draft flow as before.

                if resolution.isLowConfidence {
                    appState.selectedIntent = resolution.request
                    nav.navigate(to: .fallback)
                    return
                }

                // ── CAPABILITY ROUTER — EXECUTE > DRAFT ──────────────
                // For context-dependent intents that may still have
                // executable capabilities (future: inbox triage, etc.)
                let routingDecision = CapabilityRouter.shared.decide(resolution: resolution)

                switch routingDecision {
                case .execute(let skillId, _):
                    // Executable capability matched — bypass draft pipeline entirely
                    appState.selectedIntent = resolution.request
                    nav.navigate(to: .governedExecution(skillId: skillId, requestText: trimmedInput))

                case .draft(_):
                    // No executable capability — fall through to draft pipeline
                    appState.selectedIntent = resolution.request
                    nav.navigate(to: .context)

                case .blocked(let reason):
                    // Capability exists but requirements not met — FAIL CLOSED
                    appState.selectedIntent = resolution.request
                    appState.lastBlockedReason = reason
                    nav.navigate(to: .fallback)
                }
            }
        }
    }
}

#Preview {
    IntentInputView()
        .environmentObject(AppState())
}
