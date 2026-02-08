import SwiftUI

// ============================================================================
// SETTINGS TAB — WRAPS REAL PrivacyControlsView
// ============================================================================
// PrivacyControlsView IS the production settings hub.
// It contains all sub-screen navigation: Policies, Privacy, Sync,
// Team, Diagnostics, Quality & Trust, App Store Readiness, etc.
// This tab simply embeds it inside a NavigationStack so sheet
// presentation and NavigationLinks push correctly.
// ============================================================================

struct SettingsTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState

    var body: some View {
        PrivacyControlsView(isTabRoot: true)
    }
}
