import SwiftUI

/// Global application state - single source of truth for the app flow
@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Monetization State (Phase 10A)
    
    /// Current subscription status
    @Published var subscriptionStatus: SubscriptionStatus = .free
    
    /// Reference to entitlement manager (singleton)
    let entitlementManager = EntitlementManager.shared
    
    /// Reference to usage ledger (singleton)
    let usageLedger = UsageLedger.shared
    
    /// Current subscription tier (computed)
    var currentTier: SubscriptionTier {
        subscriptionStatus.tier
    }
    
    /// Whether user has Pro subscription
    var isPro: Bool {
        currentTier == .pro && subscriptionStatus.isActive
    }
    
    // MARK: - Flow Step (Navigation)
    
    enum FlowStep: String, CaseIterable {
        case onboarding
        case home
        case intentInput
        case contextPicker
        case planPreview
        case draftOutput
        case approval
        case executionProgress
        case executionComplete
        case memory
        case workflows
        case workflowDetail
        case customTemplateDetail
        case manageTemplates
        case fallback
        case privacy
    }
    
    // MARK: - Flow Status (UI State Machine) — Phase 5B
    
    /// Describes the current operational status for UI
    enum FlowStatus: Equatable {
        case idle
        case working(step: FlowWorkStep)
        case blocked(reason: String)
        case failed(userMessage: String, recovery: RecoveryAction)
        case completed
        
        var isWorking: Bool {
            if case .working = self { return true }
            return false
        }
        
        var workStep: FlowWorkStep? {
            if case .working(let step) = self { return step }
            return nil
        }
    }
    
    /// Describes which async step is in progress
    enum FlowWorkStep: String, Equatable {
        case resolvingIntent = "Understanding your request..."
        case assemblingContext = "Gathering context..."
        case planning = "Creating execution plan..."
        case generatingDraft = "Generating draft..."
        case awaitingApproval = "Waiting for your approval..."
        case executing = "Executing..."
        case savingToMemory = "Saving to memory..."
        
        var displayText: String { rawValue }
    }
    
    /// Actions user can take to recover from errors
    enum RecoveryAction: String, Equatable, CaseIterable {
        case retryCurrentStep = "Try Again"
        case editRequest = "Edit Request"
        case addMoreContext = "Add More Context"
        case goHome = "Back to Home"
        case openSettings = "Open Settings"
        case viewMemory = "View Memory"
        
        var icon: String {
            switch self {
            case .retryCurrentStep: return "arrow.clockwise"
            case .editRequest: return "pencil"
            case .addMoreContext: return "plus.circle"
            case .goHome: return "house"
            case .openSettings: return "gear"
            case .viewMemory: return "clock.arrow.circlepath"
            }
        }
    }
    
    @Published var currentFlow: FlowStep = .onboarding
    @Published var hasCompletedOnboarding: Bool = false
    @Published var navigationPath: [FlowStep] = []
    
    /// Current operational status (Phase 5B)
    @Published var flowStatus: FlowStatus = .idle
    
    /// Current error for display (Phase 5B)
    @Published var currentError: OperatorKitUserFacingError?
    
    /// Flag to prevent double-tap execution (Phase 5B)
    @Published var isExecutionInProgress: Bool = false
    
    #if DEBUG
    /// Flag to use synthetic demo data instead of real user data (Phase 6B)
    /// When enabled, ContextPicker shows synthetic items and audit trail is marked as synthetic
    @Published var useSyntheticDemoData: Bool = false
    #endif
    
    // MARK: - Domain State
    
    @Published var selectedIntent: IntentRequest?
    @Published var selectedContext: ContextPacket?
    @Published var lastBlockedReason: String?
    @Published var executionPlan: ExecutionPlan?
    @Published var currentDraft: Draft?
    @Published var approvalGranted: Bool = false
    @Published var executionResult: ExecutionResultModel?
    
    // MARK: - Two-Key Confirmation State (Phase 5B)
    @Published var pendingTwoKeyConfirmations: [UUID: Date] = [:]
    
    // MARK: - Workflow State

    @Published var selectedWorkflowTemplate: WorkflowTemplate?
    @Published var selectedCustomTemplate: CustomWorkflowTemplate?
    
    // MARK: - Siri Routing State

    /// Text prefilled by Siri (must be reviewed by user)
    @Published var siriPrefillText: String?

    /// Source of Siri route
    @Published var siriRouteSource: SiriRouteSource?

    /// Whether this flow was launched from Siri
    var wasLaunchedFromSiri: Bool {
        siriRouteSource != nil
    }

    // MARK: - Intent Type Hint (Quick Actions)

    /// Optional hint for intent type from quick action buttons
    /// INVARIANT: This is a HINT only — user must still provide their own input text
    /// NO pre-filled rawText is injected from quick actions
    @Published var intentTypeHint: IntentRequest.IntentType?
    
    // MARK: - Navigation Actions
    
    func navigateTo(_ step: FlowStep) {
        navigationPath.append(step)
        currentFlow = step
    }
    
    func navigateBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
        currentFlow = navigationPath.last ?? (hasCompletedOnboarding ? .home : .onboarding)
    }
    
    func navigateToRoot() {
        navigationPath.removeAll()
        currentFlow = hasCompletedOnboarding ? .home : .onboarding
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        navigationPath.removeAll()
        currentFlow = .home
    }
    
    // MARK: - Flow Actions
    
    func startNewOperation() {
        // Reset operation state
        resetOperationState()
        navigateTo(.intentInput)
    }

    func resetOperationState() {
        selectedIntent = nil
        selectedContext = nil
        executionPlan = nil
        currentDraft = nil
        approvalGranted = false
        executionResult = nil
        intentTypeHint = nil
    }

    func setIntent(_ intent: IntentRequest) {
        selectedIntent = intent
        navigateTo(.contextPicker)
    }
    
    func setContext(_ context: ContextPacket) {
        assertContextWasUserSelected(context)
        selectedContext = context
        navigateTo(.planPreview)
    }
    
    func setPlan(_ plan: ExecutionPlan) {
        executionPlan = plan
        navigateTo(.draftOutput)
    }
    
    func setDraft(_ draft: Draft) {
        currentDraft = draft
        navigateTo(.approval)
    }
    
    func grantApproval() {
        approvalGranted = true
    }
    
    func executeApproved() {
        assertApprovalWasGranted()
        navigateTo(.executionProgress)
    }
    
    func completeExecution(result: ExecutionResultModel) {
        executionResult = result
        currentFlow = .executionComplete
    }
    
    func returnHome() {
        // Reset all operation state
        resetFlow(keepOnboardingSeen: true)
        clearSiriState()
        navigationPath.removeAll()
        currentFlow = .home
    }
    
    /// Reset all operation state (Phase 5B - Enhanced)
    /// - Parameter keepOnboardingSeen: If true, preserves onboarding completion state
    func resetFlow(keepOnboardingSeen: Bool = true) {
        // Clear domain state
        selectedIntent = nil
        selectedContext = nil
        executionPlan = nil
        currentDraft = nil
        approvalGranted = false
        executionResult = nil

        // Clear intent type hint (quick actions)
        intentTypeHint = nil

        // Clear flow status (Phase 5B)
        flowStatus = .idle
        currentError = nil
        isExecutionInProgress = false

        // Clear two-key confirmations (Phase 5B)
        pendingTwoKeyConfirmations.removeAll()

        // Clear Siri state
        clearSiriState()

        // Optionally reset onboarding
        if !keepOnboardingSeen {
            hasCompletedOnboarding = false
        }

        log("AppState: Flow reset (keepOnboardingSeen: \(keepOnboardingSeen))")
    }
    
    // MARK: - Flow Status Helpers (Phase 5B)
    
    /// Set flow to working state with specific step
    func setWorking(_ step: FlowWorkStep) {
        flowStatus = .working(step: step)
        currentError = nil
    }
    
    /// Set flow to blocked state with reason
    func setBlocked(reason: String) {
        flowStatus = .blocked(reason: reason)
    }
    
    /// Set flow to failed state with user-facing error
    func setFailed(error: OperatorKitUserFacingError) {
        flowStatus = .failed(userMessage: error.message, recovery: error.primaryRecovery)
        currentError = error
        isExecutionInProgress = false
    }
    
    /// Set flow to completed state
    func setCompleted() {
        flowStatus = .completed
        isExecutionInProgress = false
    }
    
    /// Set flow back to idle
    func setIdle() {
        flowStatus = .idle
        currentError = nil
    }
    
    /// Clear current error
    func clearError() {
        currentError = nil
        if case .failed = flowStatus {
            flowStatus = .idle
        }
    }
    
    /// Cancel current operation and return to safe state
    func cancelCurrentOperation() {
        // Don't write anything
        // Don't mark approval
        // Clear partial outputs based on current step
        
        let previousStep = navigationPath.dropLast().last ?? .home
        
        switch currentFlow {
        case .draftOutput, .approval:
            // Clear draft-related state
            currentDraft = nil
            approvalGranted = false
        case .planPreview:
            // Clear plan
            executionPlan = nil
            currentDraft = nil
        case .contextPicker:
            // Clear context
            selectedContext = nil
            executionPlan = nil
        case .intentInput:
            // Clear intent
            selectedIntent = nil
        default:
            break
        }
        
        // Reset flow status
        flowStatus = .idle
        isExecutionInProgress = false
        
        // Navigate back
        navigateBack()
        
        log("AppState: Operation cancelled, returned to \(previousStep)")
    }
    
    // MARK: - Siri Routing Actions
    
    /// Navigate from Siri entry point
    /// INVARIANT: Only navigates to intentInput - user must continue manually
    func navigateFromSiri() {
        // Reset any existing flow state
        resetFlow()
        
        // Navigate to intent input - NOT past it
        // User must review prefilled text and tap continue
        navigationPath.removeAll()
        navigateTo(.intentInput)
        
        log("AppState: Navigated from Siri to intentInput")
    }
    
    /// Clear Siri-related state
    func clearSiriState() {
        siriPrefillText = nil
        siriRouteSource = nil
    }
    
    // MARK: - Invariant Assertions (DEBUG only)
    
    private func assertContextWasUserSelected(_ context: ContextPacket) {
        #if DEBUG
        assert(context.wasExplicitlySelected, "INVARIANT VIOLATION: Context must be explicitly selected by user")
        #endif
    }
    
    private func assertApprovalWasGranted() {
        #if DEBUG
        assert(approvalGranted, "INVARIANT VIOLATION: Cannot execute without explicit user approval")
        assert(currentDraft != nil, "INVARIANT VIOLATION: Cannot execute without a draft")
        #endif
    }
    
    func assertFlowOrder(expectedPrevious: FlowStep, current: FlowStep) {
        #if DEBUG
        let validTransitions: [FlowStep: [FlowStep]] = [
            .onboarding: [.home],
            .home: [.intentInput, .memory, .workflows, .privacy],
            .intentInput: [.contextPicker, .home],
            .contextPicker: [.planPreview, .intentInput],
            .planPreview: [.draftOutput, .contextPicker],
            .draftOutput: [.approval, .planPreview],
            .approval: [.executionProgress, .draftOutput],
            .executionProgress: [.executionComplete],
            .executionComplete: [.home, .memory],
            .memory: [.home],
            .workflows: [.workflowDetail, .home],
            .workflowDetail: [.workflows],
            .fallback: [.planPreview, .home],
            .privacy: [.home]
        ]
        
        if let valid = validTransitions[expectedPrevious] {
            assert(valid.contains(current), "INVARIANT VIOLATION: Invalid flow transition from \(expectedPrevious) to \(current)")
        }
        #endif
    }
    
    // MARK: - Monetization Helpers (Phase 10A)
    //
    // IMPORTANT: These helpers are for UI boundary checks ONLY.
    // They do NOT affect ExecutionEngine, ApprovalGate, or any core execution logic.
    // Monetization is orthogonal to execution behavior.
    //
    
    /// Refresh subscription status on app launch
    func refreshSubscriptionStatus() async {
        subscriptionStatus = await entitlementManager.checkCurrentEntitlements()
        usageLedger.resetWindowIfNeeded()
        log("AppState: Subscription status refreshed - tier: \(currentTier)")
    }
    
    /// Check if execution is allowed (for UI display only)
    /// IMPORTANT: Call from UI only, NOT from ExecutionEngine or ApprovalGate
    func checkExecutionLimit() -> LimitDecision {
        usageLedger.canExecute(tier: currentTier)
    }
    
    /// Check if memory save is allowed (for UI display only)
    /// - Parameter currentCount: Current number of memory items
    /// IMPORTANT: Call from UI only, NOT from MemoryStore internals
    func checkMemoryLimit(currentCount: Int) -> LimitDecision {
        usageLedger.canSaveMemoryItem(tier: currentTier, currentCount: currentCount)
    }
    
    /// Record an execution (call after successful execution from UI)
    func recordExecution() {
        usageLedger.recordExecution()
    }
    
    // MARK: - Diagnostics (Phase 10B)
    //
    // IMPORTANT: These methods are READ-ONLY.
    // They do NOT modify any state or increment any counters.
    // They exist solely for operator visibility.
    //
    
    /// Captures current execution diagnostics snapshot
    /// INVARIANT: Read-only, does not modify state
    func currentExecutionDiagnostics() -> ExecutionDiagnosticsSnapshot {
        let collector = ExecutionDiagnosticsCollector(
            usageLedger: usageLedger,
            memoryStore: MemoryStore.shared
        )
        return collector.captureSnapshot()
    }
    
    /// Captures current usage diagnostics snapshot
    /// INVARIANT: Read-only, does not modify state
    func currentUsageDiagnostics() -> UsageDiagnosticsSnapshot {
        let collector = UsageDiagnosticsCollector(
            usageLedger: usageLedger,
            entitlementManager: entitlementManager,
            memoryStore: MemoryStore.shared
        )
        return collector.captureSnapshot()
    }
}
