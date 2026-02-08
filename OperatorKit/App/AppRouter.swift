import SwiftUI

// ============================================================================
// APP ROUTER — NAVIGATION FLOW COORDINATOR
// ============================================================================
// Provides workflow-level navigation helpers that coordinate multi-step flows.
// Works alongside AppNavigationState for complex routing scenarios.
// ============================================================================

struct AppRouter {

    // MARK: - Workflow Flow Helpers

    /// Standard workflow creation flow: Intent → Context → Preview → Draft → Approval
    static let workflowCreationFlow: [Route] = [
        .intent,
        .context,
        .preview,
        .draft,
        .approval
    ]

    /// Template-based quick start flow: Templates → Preview → Draft → Approval
    static let templateQuickStartFlow: [Route] = [
        .templates,
        .preview,
        .draft,
        .approval
    ]

    /// Execution flow: Approval → Execution
    static let executionFlow: [Route] = [
        .approval,
        .execution
    ]

    // MARK: - Navigation Helpers

    /// Returns the next route in a standard workflow flow
    static func nextRoute(after current: Route) -> Route? {
        guard let index = workflowCreationFlow.firstIndex(of: current),
              index + 1 < workflowCreationFlow.count else {
            return nil
        }
        return workflowCreationFlow[index + 1]
    }

    /// Returns the previous route in a standard workflow flow
    static func previousRoute(before current: Route) -> Route? {
        guard let index = workflowCreationFlow.firstIndex(of: current),
              index > 0 else {
            return nil
        }
        return workflowCreationFlow[index - 1]
    }

    /// Check if a route is part of the main workflow creation flow
    static func isWorkflowRoute(_ route: Route) -> Bool {
        workflowCreationFlow.contains(route)
    }

    /// Check if a route is a settings/utility route
    static func isUtilityRoute(_ route: Route) -> Bool {
        switch route {
        case .memory, .templates, .manageTemplates, .privacy:
            return true
        default:
            return false
        }
    }

    // MARK: - Deep Link Handling

    /// Parse a deep link URL into a Route
    static func route(from url: URL) -> Route? {
        guard let host = url.host else { return nil }

        switch host {
        case "intent": return .intent
        case "context": return .context
        case "preview": return .preview
        case "draft": return .draft
        case "approval": return .approval
        case "execution": return .execution
        case "memory": return .memory
        case "templates": return .templates
        case "privacy": return .privacy
        case "fallback": return .fallback
        default: return nil
        }
    }

    /// Generate a deep link URL for a route
    static func deepLink(for route: Route) -> URL? {
        let host: String
        switch route {
        case .intent: host = "intent"
        case .context: host = "context"
        case .preview: host = "preview"
        case .draft: host = "draft"
        case .approval: host = "approval"
        case .execution: host = "execution"
        case .memory: host = "memory"
        case .templates: host = "templates"
        case .manageTemplates: host = "manage-templates"
        case .privacy: host = "privacy"
        case .fallback: host = "fallback"
        case .workflowDetail: host = "workflow-detail"
        case .customTemplateDetail: host = "custom-template-detail"
        case .operationDetail: host = "operation-detail"
        }
        return URL(string: "operatorkit://\(host)")
    }
}

// MARK: - AppNavigationState Extension

extension AppNavigationState {

    /// Navigate through an entire flow sequence
    func navigateFlow(_ flow: [Route]) {
        for route in flow {
            path.append(route)
        }
    }

    /// Navigate to the next step in the workflow creation flow
    func navigateToNextWorkflowStep(from current: Route) {
        if let next = AppRouter.nextRoute(after: current) {
            navigate(to: next)
        }
    }

    /// Handle deep link navigation
    func handleDeepLink(_ url: URL) {
        if let route = AppRouter.route(from: url) {
            // Reset to home first, then navigate to destination
            goHome()
            navigate(to: route)
        }
    }
}
