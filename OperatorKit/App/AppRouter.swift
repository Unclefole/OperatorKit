import SwiftUI

/// Main app router that handles all navigation
struct AppRouter: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                NavigationStack(path: $appState.navigationPath) {
                    HomeView()
                        .navigationDestination(for: AppState.FlowStep.self) { step in
                            destinationView(for: step)
                        }
                }
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for step: AppState.FlowStep) -> some View {
        switch step {
        case .onboarding:
            OnboardingView()
        case .home:
            HomeView()
        case .intentInput:
            IntentInputView()
        case .contextPicker:
            ContextPickerView()
        case .planPreview:
            PlanPreviewView()
        case .draftOutput:
            DraftOutputView()
        case .approval:
            ApprovalView()
        case .executionProgress:
            ExecutionProgressView()
        case .executionComplete:
            ExecutionProgressView() // Same view handles completion
        case .memory:
            MemoryView()
        case .workflows:
            WorkflowTemplatesView()
        case .workflowDetail:
            WorkflowDetailView()
        case .fallback:
            FallbackView()
        case .privacy:
            PrivacyControlsView()
        }
    }
}

#Preview {
    AppRouter()
        .environmentObject(AppState())
}
