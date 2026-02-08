import SwiftUI

// ============================================================================
// TASKS TAB — WRAPS REAL MemoryView
// ============================================================================
// MemoryView IS the production operations history.
// It shows completed/pending/draft operations with search,
// filtering, and deletion. This is the real task ledger.
// ============================================================================

struct TasksTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState

    var body: some View {
        MemoryView(isTabRoot: true)
    }
}
