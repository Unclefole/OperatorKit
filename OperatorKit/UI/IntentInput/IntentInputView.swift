import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct IntentInputView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText: String = ""
    @State private var isRecording: Bool = false
    @State private var showTranscript: Bool = false
    @State private var hasAcknowledgedSiri: Bool = false
    @State private var isProcessing: Bool = false  // Phase 5B: Loading state
    @State private var showingUpgrade: Bool = false  // Phase 10A: Paywall sheet
    @State private var showingPolicyEditor: Bool = false  // Phase 10C: Policy editor
    
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
    
    /// Why the continue button is disabled (Phase 5B)
    private var disabledReason: String? {
        if isProcessing {
            return nil // Button shows loading, not disabled
        }
        if inputText.isEmpty {
            return "Enter a request to continue"
        }
        if isFromSiri && !hasAcknowledgedSiri {
            return "Tap \"I've reviewed this request\" above to continue"
        }
        return nil
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Flow Step Header (Phase 5C)
                FlowStepHeaderView(
                    step: .request,
                    subtitle: "Tell OperatorKit what you need"
                )
                
                // Status Strip (Phase 5C)
                FlowStatusStripView(onRecoveryAction: handleRecoveryAction)
                
                // Header
                headerView
                
                // Main Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Execution Limit Callout (Phase 10A)
                        if !executionLimitDecision.allowed {
                            LimitCalloutView(
                                decision: executionLimitDecision,
                                onUpgradeTapped: {
                                    showingUpgrade = true
                                }
                            )
                        }
                        
                        // Policy Callout (Phase 10C)
                        if executionLimitDecision.allowed && !policyDecision.allowed {
                            PolicyCalloutView(
                                decision: policyDecision,
                                onEditPolicyTapped: {
                                    showingPolicyEditor = true
                                }
                            )
                        }
                        
                        // Siri Banner (when launched from Siri)
                        if isFromSiri {
                            siriBanner
                        }
                        
                        // Intent Input Card
                        intentInputCard
                        
                        // Transcript Bar (shows when voice input is used)
                        if showTranscript {
                            transcriptBar
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 200)
                }
                
                Spacer()
            }
            
            // Bottom Section
            VStack {
                Spacer()
                bottomInputSection
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Prefill from Siri if launched that way
            if let siriText = appState.siriPrefillText, !siriText.isEmpty {
                inputText = siriText
            }
        }
        .onDisappear {
            // Clear Siri state when leaving (user has reviewed)
            if isFromSiri && hasAcknowledgedSiri {
                SiriRoutingBridge.shared.clearRouteState()
            }
        }
        .sheet(isPresented: $showingUpgrade) {
            UpgradeView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingPolicyEditor) {
            PolicyEditorView()
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: {
                // Clear Siri state on back
                if isFromSiri {
                    SiriRoutingBridge.shared.clearRouteState()
                }
                appState.navigateBack()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("New Request")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                // Show Siri source indicator
                if let source = appState.siriRouteSource {
                    HStack(spacing: 4) {
                        Image(systemName: source.icon)
                            .font(.system(size: 10))
                        Text("via \(source.displayName)")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Button(action: {
                // Clear Siri state on close
                if isFromSiri {
                    SiriRoutingBridge.shared.clearRouteState()
                }
                appState.returnHome()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Siri Banner
    /// Banner shown when launched from Siri
    /// INVARIANT: User must acknowledge and tap Continue - no auto-advance
    private var siriBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Siri Started This Request")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Check that this is what you intended")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // Invariant explanation
            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                
                Text("Siri can only open OperatorKit. You decide what happens next.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Acknowledge checkbox (optional but good UX)
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
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                    
                    Text("Reviewed — ready to continue")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Intent Input Card
    private var intentInputCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                Text("OperatorKit")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Siri badge
                if isFromSiri {
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 10))
                        Text("Siri")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                }
            }
            
            // Large Text Input Display
            VStack(alignment: .leading, spacing: 12) {
                if inputText.isEmpty {
                    Text("What do you want me to handle?")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.primary)
                } else {
                    Text(inputText)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                // Placeholder subtext (hide when prefilled from Siri)
                if !isFromSiri || inputText.isEmpty {
                    Text("Try: \"Send a follow-up email to my last meeting\"")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 16)
            
            // Waveform (when recording)
            if isRecording {
                waveformView
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Waveform View
    private var waveformView: some View {
        HStack(spacing: 3) {
            ForEach(0..<30, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 4, height: CGFloat.random(in: 8...40))
            }
        }
        .frame(height: 50)
        .padding(.vertical, 8)
    }
    
    // MARK: - Transcript Bar
    private var transcriptBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 16))
                .foregroundColor(.blue)
            
            Text("\"Send a follow-up email to my client about the meeting yesterday\"")
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: {
                showTranscript = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Bottom Input Section
    private var bottomInputSection: some View {
        VStack(spacing: 16) {
            // Text Input Field
            HStack {
                TextField("Type or tap mic to speak...", text: $inputText)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                
                // Microphone Button
                Button(action: {
                    // Simulate voice input
                    isRecording.toggle()
                    if !isRecording {
                        inputText = "Send a follow-up email to my client about the meeting yesterday"
                        showTranscript = true
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.blue)
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: {
                    // Clear Siri state on cancel
                    if isFromSiri {
                        SiriRoutingBridge.shared.clearRouteState()
                    }
                    appState.navigateBack()
                }) {
                    Text("Cancel")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
                
                Button(action: {
                    processIntent()
                }) {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Processing...")
                                .font(.body)
                                .fontWeight(.semibold)
                        } else {
                            Text(continueButtonText)
                                .font(.body)
                                .fontWeight(.semibold)
                            
                            if isFromSiri && !hasAcknowledgedSiri {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(continueButtonEnabled && !isProcessing ? Color.blue : Color.gray.opacity(0.4))
                    .cornerRadius(12)
                }
                .disabled(!continueButtonEnabled || isProcessing)
                .accessibilityLabel(continueButtonAccessibilityLabel)
                .accessibilityHint(disabledReason ?? "Tap to continue to context selection")
            }
            
            // Why blocked explanation (Phase 5B)
            if let reason = disabledReason {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text(reason)
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            Color(UIColor.systemGroupedBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
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
        // Must have text
        guard !inputText.isEmpty else { return false }
        
        // If from Siri, must acknowledge
        if isFromSiri && !hasAcknowledgedSiri {
            return false
        }
        
        return true
    }
    
    /// Accessibility label for continue button (Phase 5C)
    private var continueButtonAccessibilityLabel: String {
        if isProcessing {
            return "Processing request"
        }
        if !continueButtonEnabled {
            return "Continue button, disabled. \(disabledReason ?? "")"
        }
        return "Continue to context selection"
    }
    
    // MARK: - Recovery Action Handler (Phase 5C)
    private func handleRecoveryAction(_ action: OperatorKitUserFacingError.RecoveryAction) {
        switch action {
        case .goHome:
            appState.returnHome()
        case .retryCurrentStep:
            appState.clearError()
        case .editRequest:
            inputText = ""
            appState.clearError()
        default:
            appState.clearError()
        }
    }
    
    // MARK: - Actions
    private func processIntent() {
        // Prevent double-tap (Phase 5B)
        guard !isProcessing else { return }
        
        // Phase 10A: Check execution limit at UI boundary
        // IMPORTANT: This does NOT affect ExecutionEngine or ApprovalGate
        let limitCheck = appState.checkExecutionLimit()
        if !limitCheck.allowed {
            // Limit reached, show upgrade
            showingUpgrade = true
            return
        }
        
        // Phase 10C: Check policy at UI boundary
        // IMPORTANT: This does NOT affect ExecutionEngine or ApprovalGate
        let policyCheck = policyEvaluator.canStartExecution()
        if !policyCheck.allowed {
            // Policy blocks execution, show policy editor
            showingPolicyEditor = true
            return
        }
        
        // INVARIANT: User must have acknowledged if from Siri
        #if DEBUG
        if isFromSiri {
            assert(hasAcknowledgedSiri, "INVARIANT VIOLATION: Siri flow continued without user acknowledgment")
        }
        #endif
        
        // Mark as acknowledged for cleanup
        hasAcknowledgedSiri = true
        
        // Set loading state (Phase 5B)
        isProcessing = true
        appState.setWorking(.resolvingIntent)
        
        // Simulate async processing (in real app, this might be async)
        Task {
            // Small delay to show loading state
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            
            await MainActor.run {
                let resolution = IntentResolver.shared.resolve(rawInput: inputText)
                
                // Clear loading state
                isProcessing = false
                appState.setIdle()
                
                if resolution.isLowConfidence {
                    // Route to fallback
                    appState.selectedIntent = resolution.request
                    appState.navigateTo(.fallback)
                } else {
                    // Continue normal flow
                    appState.selectedIntent = resolution.request
                    appState.navigateTo(.contextPicker)
                }
            }
        }
    }
}

#Preview {
    IntentInputView()
        .environmentObject(AppState())
}
