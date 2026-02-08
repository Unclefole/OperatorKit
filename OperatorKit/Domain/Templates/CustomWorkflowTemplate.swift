import Foundation
import SwiftUI

// ============================================================================
// CUSTOM WORKFLOW TEMPLATE - CANONICAL MODEL
//
// Production-grade, schema-stable model for user-created workflow templates.
//
// INVARIANTS:
// 1. name is never empty (enforced at construction)
// 2. icon is never empty (enforced at construction)
// 3. schemaVersion is always set for migration support
// 4. All timestamps are non-nil
//
// CODABLE: Safe for JSON persistence with stable keys
// ============================================================================

/// Current schema version - increment when model structure changes
let kCustomWorkflowTemplateSchemaVersion: Int = 1

// MARK: - Canonical Color Enum

/// Unified template color enum - the SINGLE source of truth for template colors.
/// Used by CustomWorkflowTemplate and should be referenced by all UI components.
/// DO NOT create duplicate color enums elsewhere.
enum TemplateColor: String, Codable, CaseIterable, Sendable {
    case blue
    case pink
    case green
    case orange
    case purple

    /// SwiftUI Color representation
    var swiftUIColor: Color {
        switch self {
        case .blue: return .blue
        case .pink: return .pink
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        }
    }
}

// MARK: - Custom Workflow Template

/// User-created workflow template with full persistence support
struct CustomWorkflowTemplate: Identifiable, Codable, Equatable, Sendable {

    // MARK: - Identity

    let id: UUID
    let schemaVersion: Int

    // MARK: - Content

    let name: String
    let description: String?
    let icon: String
    let color: TemplateColor
    let steps: [TemplateStep]

    // MARK: - Audit Timestamps

    let createdAt: Date
    let updatedAt: Date

    // MARK: - Failable Initializer

    /// Creates a validated template. Returns nil if validation fails.
    /// INVARIANT: Non-nil result guarantees valid template state.
    init?(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        icon: String,
        color: TemplateColor,
        steps: [TemplateStep] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        // VALIDATION: name cannot be empty or whitespace-only
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        // VALIDATION: icon must be non-empty
        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIcon.isEmpty else { return nil }

        self.id = id
        self.schemaVersion = kCustomWorkflowTemplateSchemaVersion
        self.name = trimmedName
        self.description = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.icon = trimmedIcon
        self.color = color
        self.steps = steps
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Update (Returns New Instance)

    /// Creates an updated copy with new modification timestamp.
    /// Returns nil if the update would result in invalid state.
    func withUpdates(
        name: String? = nil,
        description: String?? = nil,  // Double optional: nil = no change, .some(nil) = clear
        icon: String? = nil,
        color: TemplateColor? = nil,
        steps: [TemplateStep]? = nil
    ) -> CustomWorkflowTemplate? {
        let newDescription: String?
        if let descUpdate = description {
            newDescription = descUpdate
        } else {
            newDescription = self.description
        }

        return CustomWorkflowTemplate(
            id: self.id,
            name: name ?? self.name,
            description: newDescription,
            icon: icon ?? self.icon,
            color: color ?? self.color,
            steps: steps ?? self.steps,
            createdAt: self.createdAt,
            updatedAt: Date()
        )
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion
        case name
        case description
        case icon
        case color
        case steps
        case createdAt
        case updatedAt
    }
}

// MARK: - Template Step

/// A single step within a workflow template
struct TemplateStep: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let order: Int
    let title: String
    let instructions: String

    init(
        id: UUID = UUID(),
        order: Int,
        title: String,
        instructions: String
    ) {
        self.id = id
        self.order = order
        self.title = title
        self.instructions = instructions
    }
}

// MARK: - Conversion from Legacy WorkflowTemplate

extension CustomWorkflowTemplate {
    /// Convert static WorkflowTemplate to persistable CustomWorkflowTemplate
    init?(from workflow: WorkflowTemplate) {
        let color: TemplateColor
        switch workflow.iconColor {
        case .blue: color = .blue
        case .pink: color = .pink
        case .green: color = .green
        case .orange: color = .orange
        case .purple: color = .purple
        }

        let steps = workflow.steps.enumerated().map { index, step in
            TemplateStep(
                id: step.id,
                order: index,
                title: step.title,
                instructions: step.instructions
            )
        }

        self.init(
            id: workflow.id,
            name: workflow.name,
            description: workflow.description,
            icon: workflow.icon,
            color: color,
            steps: steps
        )
    }
}

// MARK: - Validation Result

/// Typed validation errors for template creation
enum TemplateValidationError: Error, LocalizedError, Sendable {
    case emptyName
    case emptyIcon
    case invalidStep(Int, String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Template name cannot be empty"
        case .emptyIcon:
            return "Template icon cannot be empty"
        case .invalidStep(let index, let reason):
            return "Step \(index + 1) is invalid: \(reason)"
        }
    }
}
