import SwiftUI
import SwiftData

@main
struct OperatorKitApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        // Configure Siri routing bridge on app launch
        // INVARIANT: Siri is router only - never executes logic
        
        #if DEBUG
        // Phase 7A: Run startup validation in DEBUG builds
        // This verifies all invariants and safety guards are in place
        ReleaseSafetyConfig.runStartupValidation()
        InvariantCheckRunner.shared.runAndAssert()
        
        // Phase 7C: Run regression sentinel
        // Detects any safety guarantee violations
        RegressionSentinel.shared.runAtLaunch()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environmentObject(appState)
                .modelContainer(SwiftDataProvider.sharedModelContainer)
                .launchTrustCalibration()
                .onAppear {
                    // Configure Siri routing bridge with app state
                    SiriRoutingBridge.shared.configure(appState: appState)
                }
        }
    }
}
