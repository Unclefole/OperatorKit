import SwiftUI

// ============================================================================
// APP NAVIGATION STATE — SINGLE SOURCE OF TRUTH
// ============================================================================

@MainActor
final class AppNavigationState: ObservableObject {
    @Published var path = NavigationPath()
    @Published var selectedTab: Int = 0

    /// True when the Home tab's NavigationStack has routes pushed onto it.
    /// Views should check this to know if goBack() will actually do anything.
    var isInsideRoutePath: Bool {
        !path.isEmpty
    }

    /// Pop the last route off the Home tab's NavigationStack.
    /// Only effective when a Route has been pushed (i.e. isInsideRoutePath == true).
    func goBack() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    /// Reset the Home tab's NavigationStack to root.
    /// Only affects Tab 1's bound path — does NOT switch tabs.
    func goHome() {
        path = NavigationPath()
    }

    /// Switch to the Home tab AND reset the navigation stack to root.
    /// This is the correct action for "Home" buttons on non-Home tabs.
    func goHomeTab() {
        path = NavigationPath()
        selectedTab = 0
    }

    func navigate(to route: Route) {
        path.append(route)
    }
}

// ============================================================================
// ROUTE — TYPE-SAFE NAVIGATION
// ============================================================================

enum Route: Hashable {
    case intent
    case context
    case preview
    case draft
    case approval
    case fallback
    case memory
    case templates
    case manageTemplates
    case privacy
    case execution
    case workflowDetail
    case customTemplateDetail
    case workspace
    case operatorChannel
    case enterpriseOnboarding
    case trustRegistry
    case integrityIncident
    case auditStatus
    case pilotRunner
    case killSwitches
    case reviewPack
    case scoutDashboard
    case operationDetail(title: String, status: String, colorHex: String)

    // Color is not Hashable — we encode as hex string for Hashable conformance
    static func operationDetailRoute(title: String, status: String, color: Color) -> Route {
        let hex: String
        switch status {
        case "SENT":    hex = "10B981"
        case "APPROVED": hex = "10B981"
        case "PENDING":  hex = "F59E0B"
        default:         hex = "6B7280"
        }
        return .operationDetail(title: title, status: status, colorHex: hex)
    }

    @ViewBuilder
    var destinationView: some View {
        switch self {
        case .intent:
            IntentInputView()
        case .context:
            ContextPickerView()
        case .preview:
            PlanPreviewView()
        case .draft:
            DraftOutputView()
        case .approval:
            ApprovalView()
        case .fallback:
            FallbackView()
        case .memory:
            MemoryView()
        case .templates:
            WorkflowTemplatesView()
        case .manageTemplates:
            ManageTemplatesView()
        case .privacy:
            PrivacyControlsView()
        case .execution:
            ExecutionProgressView()
        case .workspace:
            OperatorWorkspaceView()
        case .operatorChannel:
            OperatorChannelView()
        case .enterpriseOnboarding:
            EnterpriseOnboardingView()
        case .trustRegistry:
            TrustRegistryView()
        case .integrityIncident:
            IntegrityIncidentView()
        case .auditStatus:
            AuditStatusView()
        case .pilotRunner:
            PilotRunnerView()
        case .killSwitches:
            EnterpriseKillSwitchesView()
        case .reviewPack:
            EnterpriseReviewPackView()
        case .scoutDashboard:
            ScoutDashboardView()
        case .workflowDetail:
            WorkflowDetailView()
        case .customTemplateDetail:
            CustomTemplateDetailView()
        case .operationDetail(let title, let status, let colorHex):
            OperationDetailView(
                operationTitle: title,
                statusText: status,
                statusColor: Color(hex: colorHex)
            )
        }
    }
}
