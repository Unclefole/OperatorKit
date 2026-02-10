import SwiftUI
import SwiftData

@main
struct OperatorKitApp: App {

    @StateObject private var appState = AppState()
    @StateObject private var nav = AppNavigationState()
    @StateObject private var templateStore = TemplateStoreObservable.shared

    init() {
        // INVARIANT: Siri is routing-only. Never executes business logic.

        // Register background tasks (must happen before app finishes launching)
        BackgroundScheduler.registerTasks()

        #if DEBUG
        // Phase 7A — Startup safety + invariant validation
        ReleaseSafetyConfig.runStartupValidation()
        InvariantCheckRunner.shared.runAndAssert()

        // Phase 7C — Regression sentinel
        RegressionSentinel.shared.runAtLaunch()

        // Image + asset verification (DEBUG only)
        // Dispatched to MainActor for thread safety
        Task { @MainActor in
            SFSymbolVerifier.verifyAllUsedSymbols()
            AssetCatalogVerifier.verifyCriticalAssets()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .environmentObject(nav)
                .environmentObject(templateStore)
                .modelContainer(SwiftDataProvider.sharedModelContainer)
                .launchTrustCalibration()
                .preferredColorScheme(.dark)
                .background(OKColor.backgroundPrimary)
                .onAppear {
                    SiriRoutingBridge.shared.configure(appState: appState, nav: nav)

                    // EXECUTION PERSISTENCE: Configure store + crash recovery
                    ExecutionRecordStore.shared.configure(with: SwiftDataProvider.sharedModelContainer)
                    let recovered = ExecutionRecordStore.shared.recoverFromCrash()
                    if recovered > 0 {
                        log("[APP LAUNCH] Crash recovery: \(recovered) interrupted execution(s) marked as failed")
                    }

                    // BACKGROUND QUEUE: Configure persistent task queue
                    BackgroundTaskQueue.shared.configure(with: SwiftDataProvider.sharedModelContainer)

                    // KERNEL INTEGRITY: Self-integrity check on every launch
                    KernelIntegrityGuard.shared.performFullCheck()

                    // EVIDENCE CHAIN: Verify hash chain integrity on launch
                    EvidenceEngine.shared.verifyOnLaunch()

                    // NOTIFICATIONS: Request authorization
                    Task {
                        await NotificationBridge.shared.requestAuthorization()
                    }

                    // BACKGROUND: Schedule periodic tasks
                    BackgroundScheduler.scheduleProposalPreparation()
                    BackgroundScheduler.scheduleMirrorAttestation()
                    if EnterpriseFeatureFlags.scoutModeEnabled {
                        BackgroundScheduler.scheduleScoutRun()
                    }
                }
                .task {
                    await templateStore.load()
                }
                // SIRI NAVIGATION BRIDGE: When launched from Siri, navigate to intent input
                .onChange(of: appState.wasLaunchedFromSiri) { _, isFromSiri in
                    if isFromSiri {
                        // Navigate to intent input with prefilled text
                        nav.navigate(to: .intent)
                    }
                }
        }
    }
}
