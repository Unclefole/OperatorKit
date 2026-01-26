import Foundation

/// A predefined workflow template
struct WorkflowTemplate: Identifiable, Equatable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let iconColor: TemplateColor
    let steps: [WorkflowStep]
    let settings: WorkflowSettings
    
    enum TemplateColor: String {
        case blue
        case pink
        case green
        case orange
        case purple
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        icon: String,
        iconColor: TemplateColor,
        steps: [WorkflowStep],
        settings: WorkflowSettings = WorkflowSettings()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.iconColor = iconColor
        self.steps = steps
        self.settings = settings
    }
    
    static func == (lhs: WorkflowTemplate, rhs: WorkflowTemplate) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Workflow Step

struct WorkflowStep: Identifiable, Equatable {
    let id: UUID
    var stepNumber: Int
    var title: String
    var instructions: String
    var attachmentName: String?
    var options: [StepOption]
    
    init(
        id: UUID = UUID(),
        stepNumber: Int,
        title: String,
        instructions: String,
        attachmentName: String? = nil,
        options: [StepOption] = []
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.title = title
        self.instructions = instructions
        self.attachmentName = attachmentName
        self.options = options
    }
}

// MARK: - Step Option

struct StepOption: Identifiable, Equatable {
    let id: UUID
    let name: String
    var isEnabled: Bool
    
    init(id: UUID = UUID(), name: String, isEnabled: Bool = false) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
    }
}

// MARK: - Workflow Settings

struct WorkflowSettings: Equatable {
    var confidenceRequired: ConfidenceLevel
    var verifyBeforeExecution: Bool
    
    enum ConfidenceLevel: String, CaseIterable {
        case auto = "Auto"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }
    
    init(confidenceRequired: ConfidenceLevel = .auto, verifyBeforeExecution: Bool = true) {
        self.confidenceRequired = confidenceRequired
        self.verifyBeforeExecution = verifyBeforeExecution
    }
}

// MARK: - Predefined Templates

extension WorkflowTemplate {
    static let clientFollowUp = WorkflowTemplate(
        name: "Client Follow-Up",
        description: "Summarize meeting & draft follow-up email",
        icon: "envelope.fill",
        iconColor: .blue,
        steps: [
            WorkflowStep(
                stepNumber: 1,
                title: "Summarize the meeting",
                instructions: "Generate a brief summary of the meeting",
                attachmentName: "All Research Memory"
            ),
            WorkflowStep(
                stepNumber: 2,
                title: "Extract action items",
                instructions: "Identify action items and timeline changes for follow-up",
                attachmentName: "Project Roadmap",
                options: [StepOption(name: "Include timeline changes", isEnabled: true)]
            )
        ]
    )
    
    static let documentReview = WorkflowTemplate(
        name: "Document Review",
        description: "Compare drafts and suggest changes",
        icon: "doc.text.fill",
        iconColor: .blue,
        steps: [
            WorkflowStep(
                stepNumber: 1,
                title: "Analyze document",
                instructions: "Read and understand document content"
            ),
            WorkflowStep(
                stepNumber: 2,
                title: "Suggest changes",
                instructions: "Propose improvements and corrections"
            )
        ]
    )
    
    static let fallbackPrompt = WorkflowTemplate(
        name: "Fallback Prompt",
        description: "Prepare a backup plan when uncertain",
        icon: "gearshape.fill",
        iconColor: .pink,
        steps: [
            WorkflowStep(
                stepNumber: 1,
                title: "Analyze uncertainty",
                instructions: "Identify what caused low confidence"
            ),
            WorkflowStep(
                stepNumber: 2,
                title: "Suggest alternatives",
                instructions: "Propose alternative approaches"
            )
        ]
    )
    
    static let allTemplates: [WorkflowTemplate] = [
        .clientFollowUp,
        .documentReview,
        .fallbackPrompt
    ]
}
