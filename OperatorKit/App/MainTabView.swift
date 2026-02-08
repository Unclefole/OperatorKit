import SwiftUI

// ============================================================================
// MAIN TAB VIEW — FOUR-TAB BOTTOM NAVIGATION
// ============================================================================
// Home (default) | Tasks | Analytics | Settings
// Clean, institutional tab bar. Home is always the default selected tab.
//
// WIRING:
// Tab 1 — HomeView (with NavigationStack + Route-based navigation)
// Tab 2 — MemoryView (real operations history / task ledger)
// Tab 3 — QualityReportView (real analytics surface)
// Tab 4 — PrivacyControlsView (real settings hub with all sub-screens)
//
// ZERO placeholders. All tabs route to production views.
// ============================================================================

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState

    var body: some View {
        TabView(selection: $nav.selectedTab) {

            // ── Tab 1: Home ──────────────────────────────────
            // Primary execution surface. NavigationStack with
            // Route-based destinations for the full workflow flow.
            NavigationStack(path: $nav.path) {
                HomeView()
                    .navigationDestination(for: Route.self) { route in
                        route.destinationView
                    }
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)

            // ── Tab 2: Tasks ─────────────────────────────────
            // MemoryView = real operations history / task ledger.
            // MemoryView manages its own header (.navigationBarHidden).
            NavigationStack {
                TasksTabView()
            }
            .tabItem {
                Image(systemName: "checklist")
                Text("Tasks")
            }
            .tag(1)

            // ── Tab 3: Analytics ─────────────────────────────
            // QualityReportView = real analytics.
            // QualityReportView contains its own NavigationView,
            // so we do NOT wrap it in another NavigationStack.
            AnalyticsTabView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Analytics")
                }
                .tag(2)

            // ── Tab 4: Settings ──────────────────────────────
            // PrivacyControlsView = real settings hub.
            // Contains sheets for: Policies, Sync, Team, Diagnostics,
            // Quality & Trust, App Store Readiness, Customer Proof, etc.
            // Manages its own header (.navigationBarHidden).
            NavigationStack {
                SettingsTabView()
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Settings")
            }
            .tag(3)
        }
        .tint(OKColors.intelligenceStart)
    }
}
