import SwiftUI

// ============================================================================
// ANALYTICS TAB — WRAPS REAL QualityReportView
// ============================================================================
// QualityReportView IS the production analytics surface.
// It shows quality metrics, trust scores, and operational analytics.
// ============================================================================

struct AnalyticsTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState

    var body: some View {
        QualityReportView()
    }
}
