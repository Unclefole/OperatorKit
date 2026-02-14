import SwiftUI

// ============================================================================
// MAIN TAB VIEW — ADAPTIVE MULTI-DEVICE NAVIGATION
// ============================================================================
//
// LAYOUT STRATEGY:
//   iPhone  → Bottom tab bar (compact)
//   iPad    → Sidebar navigation (regular width) with detail pane
//   Mac     → Sidebar navigation (regular width) — feels like Linear/Palantir
//
// When horizontal size class is .regular (iPad landscape, Mac), we use
// NavigationSplitView with a sidebar for navigation and a detail pane.
// When .compact (iPhone, iPad portrait), we use the standard TabView.
//
// INVARIANT: Same underlying views. Same data. Different layout primitives.
// INVARIANT: Navigation state preserved across size class transitions.
// ============================================================================

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .regular {
                // iPad / Mac — Sidebar + Detail layout
                adaptiveSplitView
            } else {
                // iPhone — Bottom tab bar
                compactTabView
            }
        }
        .tint(OKColor.riskOperational)
    }

    // MARK: - Compact (iPhone)

    private var compactTabView: some View {
        TabView(selection: $nav.selectedTab) {

            // ── Tab 0: Control ───────────────────────────────
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
            NavigationStack {
                TasksTabView()
                    .navigationDestination(for: Route.self) { route in
                        route.destinationView
                    }
            }
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("Insights")
            }
            .tag(1)

            // ── Tab 2: Policies ──────────────────────────────
            NavigationStack {
                PolicyEditorView()
                    .navigationDestination(for: Route.self) { route in
                        route.destinationView
                    }
            }
            .tabItem {
                Image(systemName: "doc.text.fill")
                Text("Policies")
            }
            .tag(2)

            // ── Tab 3: Config ────────────────────────────────
            NavigationStack {
                SettingsTabView()
                    .navigationDestination(for: Route.self) { route in
                        route.destinationView
                    }
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Config")
            }
            .tag(3)
        }
        .toolbarBackground(OKColor.backgroundSecondary, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    // MARK: - Regular (iPad / Mac) — Sidebar + Detail

    private var adaptiveSplitView: some View {
        NavigationSplitView {
            // ── SIDEBAR ─────────────────────────────────────
            sidebarContent
                .navigationTitle("OperatorKit")
                .navigationBarTitleDisplayMode(.large)
        } detail: {
            // ── DETAIL PANE ─────────────────────────────────
            NavigationStack(path: $nav.path) {
                detailContent
                    .navigationDestination(for: Route.self) { route in
                        route.destinationView
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebarContent: some View {
        List {
            // Mission Control
            Section {
                sidebarButton(label: "Control", icon: "shield.checkered", tag: 0)
                sidebarButton(label: "Insights", icon: "chart.bar.fill", tag: 1)
            } header: {
                Text("OPERATIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
            }

            // Governance
            Section {
                sidebarButton(label: "Policies", icon: "doc.text.fill", tag: 2)
            } header: {
                Text("GOVERNANCE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
            }

            // System
            Section {
                sidebarButton(label: "Config", icon: "gearshape.fill", tag: 3)
                sidebarButton(label: "Security", icon: "lock.shield", tag: 4)
            } header: {
                Text("SYSTEM")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
            }
        }
        .listStyle(.sidebar)
    }

    private func sidebarButton(label: String, icon: String, tag: Int) -> some View {
        Button {
            nav.selectedTab = tag
        } label: {
            Label(label, systemImage: icon)
                .foregroundStyle(nav.selectedTab == tag ? OKColor.actionPrimary : OKColor.textPrimary)
        }
        .listRowBackground(nav.selectedTab == tag ? OKColor.actionPrimary.opacity(0.1) : Color.clear)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch nav.selectedTab {
        case 0:
            ControlDashboardView()
        case 1:
            TasksTabView()
        case 2:
            PolicyEditorView()
        case 3:
            SettingsTabView()
        case 4:
            SecurityDashboardView()
        default:
            ControlDashboardView()
        }
    }
}
