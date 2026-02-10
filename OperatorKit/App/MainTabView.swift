import SwiftUI

// ============================================================================
// MAIN TAB VIEW — MISSION CONTROL FOUR-TAB NAVIGATION
// ============================================================================
// Control (default) | Insights | Policies | Config
//
// WIRING:
// Tab 0 — ControlDashboardView (mission control: execution tracker, risk,
//          high-risk actions, direct controls, audit trail)
//          + HomeView with Route-based navigation for execution flow
// Tab 1 — AnalyticsTabView → Insights (operations history + analytics)
// Tab 2 — PolicyEditorView → Policies (governance rules)
// Tab 3 — SettingsTabView → Config (privacy, sync, team, diagnostics)
//
// ZERO placeholders. All tabs route to production views.
// ============================================================================

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState

    var body: some View {
        TabView(selection: $nav.selectedTab) {

            // ── Tab 0: Control ───────────────────────────────
            // Mission-control dashboard. Primary execution surface.
            // NavigationStack with Route-based destinations for workflow.
            NavigationStack(path: $nav.path) {
                ControlDashboardView()
                    .navigationDestination(for: Route.self) { route in
                        route.destinationView
                    }
            }
            .tabItem {
                Image(systemName: "shield.checkered")
                Text("Control")
            }
            .tag(0)

            // ── Tab 1: Insights ──────────────────────────────
            // Operations history, quality analytics, memory view.
            NavigationStack {
                TasksTabView()
            }
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("Insights")
            }
            .tag(1)

            // ── Tab 2: Policies ──────────────────────────────
            // Governance rules and policy editor.
            NavigationStack {
                PolicyEditorView()
            }
            .tabItem {
                Image(systemName: "doc.text.fill")
                Text("Policies")
            }
            .tag(2)

            // ── Tab 3: Config ────────────────────────────────
            // Privacy controls, sync, team, diagnostics, app store.
            NavigationStack {
                SettingsTabView()
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Config")
            }
            .tag(3)
        }
        .tint(OKColor.riskOperational)
        .toolbarBackground(OKColor.backgroundSecondary, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}
