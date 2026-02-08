import SwiftUI
import SwiftData

@main
struct OperatorKitApp: App {

    @StateObject private var appState = AppState()
    @StateObject private var nav = AppNavigationState()
    @StateObject private var templateStore = TemplateStoreObservable.shared

    init() {
        // INVARIANT: Siri is routing-only. Never executes business logic.

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
                .preferredColorScheme(ColorScheme.light)
                .background(Color.white)
                .onAppear {
                    SiriRoutingBridge.shared.configure(appState: appState, nav: nav)
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
