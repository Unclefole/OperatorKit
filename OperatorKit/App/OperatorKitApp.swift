import SwiftUI
import SwiftData

@main
struct OperatorKitApp: App {

    @StateObject private var appState = AppState()
    @StateObject private var nav = AppNavigationState()
    @StateObject private var templateStore = TemplateStoreObservable.shared

    init() {
        // INVARIANT: Siri is routing-only. Never executes business logic.

        // Register sensible defaults for feature flags.
        // Web research is read-only (GET + HTTPS) so it's safe to enable by default.
        // Existing users who explicitly turned it off keep their setting.
        UserDefaults.standard.register(defaults: [
            "ok_enterprise_web_research": true,
            "ok_enterprise_research_host_allowlist": true
        ])

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
                .preferredColorScheme(appState.appearanceMode.colorScheme)
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

                    // CATALYST + MULTI-DEVICE SECURITY HARDENING
                    // Apply pasteboard clearing, window snapshot protection,
                    // environment variable validation, Keychain access group checks.
                    CatalystSecurityHardening.applyAll()
                    CatalystSecurityHardening.validateKeychainAccessGroup()

                    // DEVICE ATTESTATION: Generate App Attest key + verify on first launch
                    Task {
                        try? await DeviceAttestationService.shared.generateKeyIfNeeded()
                        _ = await AppAttestVerifier.shared.verify()
                    }

                    // TAMPER DETECTION: Lightweight anti-tamper scan
                    // Checks: writable system paths, injected libraries,
                    // debugger in release, sandbox integrity, jailbreak artifacts.
                    // On failure → KernelIntegrityGuard.enterLockdown()
                    let tamperReport = TamperDetection.performFullScan(triggerLockdownOnFailure: true)
                    if tamperReport.isCompromised {
                        log("[APP LAUNCH] ⛔ TAMPER DETECTED — \(tamperReport.failedCount) signal(s)")
                    }

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

                    // SKILLS: Register Day-One Micro-Operators
                    SkillRegistry.shared.registerDayOneSkills()
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
