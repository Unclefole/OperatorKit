import Foundation

// ============================================================================
// CUSTOM TEMPLATE MODEL
//
// Production-grade template model with:
// - Schema versioning for migration safety
// - Full Codable support for persistence
// - Validation at construction time
// - Audit timestamps
//
// INVARIANT: Invalid templates cannot be constructed.
// ============================================================================

/// Schema version for migration support
/// Increment when model structure changes
let kCustomTemplateSchemaVersion: Int = 1

/// User-created workflow template (persisted)
struct CustomTemplate: Identifiable, Codable, Equatable {

    // MARK: - Identity

    let id: UUID
    let schemaVersion: Int

    // MARK: - Content

    let name: String
    let templateDescription: String
    let icon: String
    let iconColor: TemplateIconColor
    let steps: [CustomTemplateStep]

    // MARK: - Audit

    let createdAt: Date
    var updatedAt: Date

    // MARK: - Failable Initializer (Enforces Validity)

    /// Creates a validated template. Returns nil if validation fails.
    /// INVARIANT: If this returns non-nil, the template is guaranteed valid.
    init?(
        id: UUID = UUID(),
        name: String,
        description: String,
        icon: String,
        iconColor: TemplateIconColor,
        steps: [CustomTemplateStep] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        // Validation: name cannot be empty or whitespace-only
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        // Validation: icon must be non-empty
        guard !icon.isEmpty else { return nil }

        self.id = id
        self.schemaVersion = kCustomTemplateSchemaVersion
        self.name = trimmedName
        self.templateDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.icon = icon
        self.iconColor = iconColor
        self.steps = steps
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Mutation (Returns New Instance)

    /// Creates an updated copy with new modification timestamp
    func updated(
        name: String? = nil,
        description: String? = nil,
        icon: String? = nil,
        iconColor: TemplateIconColor? = nil,
        steps: [CustomTemplateStep]? = nil
    ) -> CustomTemplate? {
        return CustomTemplate(
            id: self.id,
            name: name ?? self.name,
            description: description ?? self.templateDescription,
            icon: icon ?? self.icon,
            iconColor: iconColor ?? self.iconColor,
            steps: steps ?? self.steps,
            createdAt: self.createdAt,
            updatedAt: Date()
        )
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion
        case name
        case templateDescription = "description"
        case icon
        case iconColor
        case steps
        case createdAt
        case updatedAt
    }
}

// MARK: - Template Step

struct CustomTemplateStep: Identifiable, Codable, Equatable {
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

// MARK: - Icon Color (Shared)

/// Unified icon color enum used across template system
/// Codable with stable raw values for persistence
enum TemplateIconColor: String, Codable, CaseIterable {
    case blue
    case pink
    case green
    case orange
    case purple
}

// MARK: - Conversion from WorkflowTemplate

extension CustomTemplate {
    /// Convert static WorkflowTemplate to persistable CustomTemplate
    init?(from workflow: WorkflowTemplate) {
        let iconColor: TemplateIconColor
        switch workflow.iconColor {
        case .blue: iconColor = .blue
        case .pink: iconColor = .pink
        case .green: iconColor = .green
        case .orange: iconColor = .orange
        case .purple: iconColor = .purple
        }

        let steps = workflow.steps.map { step in
            CustomTemplateStep(
                id: step.id,
                order: step.stepNumber,
                title: step.title,
                instructions: step.instructions
            )
        }

        self.init(
            id: workflow.id,
            name: workflow.name,
            description: workflow.description,
            icon: workflow.icon,
            iconColor: iconColor,
            steps: steps
        )
    }
}
