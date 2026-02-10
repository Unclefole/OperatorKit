import Foundation
import SwiftUI

/// A unified wrapper that represents either a static workflow template or a custom user-created template.
/// Enables displaying both types in a single list with deterministic sorting.
enum UnifiedWorkflowItem: Identifiable, Equatable {
    case staticTemplate(WorkflowTemplate)
    case customTemplate(CustomWorkflowTemplate)

    // MARK: - Identifiable

    var id: String {
        switch self {
        case .staticTemplate(let template):
            return "static-\(template.id.uuidString)"
        case .customTemplate(let template):
            return "custom-\(template.id.uuidString)"
        }
    }

    // MARK: - Common Properties

    var name: String {
        switch self {
        case .staticTemplate(let template):
            return template.name
        case .customTemplate(let template):
            return template.name
        }
    }

    var descriptionText: String {
        switch self {
        case .staticTemplate(let template):
            return template.description
        case .customTemplate(let template):
            return template.description ?? "Custom workflow template"
        }
    }

    var icon: String {
        switch self {
        case .staticTemplate(let template):
            return template.icon
        case .customTemplate(let template):
            return template.icon
        }
    }

    var iconColor: Color {
        switch self {
        case .staticTemplate(let template):
            switch template.iconColor {
            case .blue: return OKColor.actionPrimary
            case .pink: return OKColor.riskCritical
            case .green: return OKColor.riskNominal
            case .orange: return OKColor.riskWarning
            case .purple: return OKColor.riskExtreme
            }
        case .customTemplate(let template):
            return template.color.swiftUIColor
        }
    }

    var stepsCount: Int {
        switch self {
        case .staticTemplate(let template):
            return template.steps.count
        case .customTemplate(let template):
            return template.steps.count
        }
    }

    var isCustom: Bool {
        switch self {
        case .staticTemplate:
            return false
        case .customTemplate:
            return true
        }
    }

    /// For custom templates, returns updatedAt; for static, returns distant past to sort first
    var sortDate: Date {
        switch self {
        case .staticTemplate:
            return Date.distantPast
        case .customTemplate(let template):
            return template.updatedAt
        }
    }

    /// Sort order index for static templates (preserves original order)
    var staticSortIndex: Int? {
        switch self {
        case .staticTemplate(let template):
            return WorkflowTemplate.allTemplates.firstIndex(where: { $0.id == template.id })
        case .customTemplate:
            return nil
        }
    }

    // MARK: - Factory Methods

    /// Creates a unified list from static templates and custom templates.
    /// Sorting: static templates first (original order), custom templates second (by updatedAt desc).
    static func unifiedList(
        staticTemplates: [WorkflowTemplate] = WorkflowTemplate.allTemplates,
        customTemplates: [CustomWorkflowTemplate]
    ) -> [UnifiedWorkflowItem] {
        // Static templates maintain their original order
        let staticItems = staticTemplates.map { UnifiedWorkflowItem.staticTemplate($0) }

        // Custom templates sorted by updatedAt descending (most recent first)
        let customItems = customTemplates
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { UnifiedWorkflowItem.customTemplate($0) }

        return staticItems + customItems
    }
}
