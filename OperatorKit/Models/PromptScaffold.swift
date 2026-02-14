import Foundation
import CryptoKit

// MARK: - Prompt Scaffold
//
// Creates structured instruction strings for model backends.
// INVARIANT: No chat UI patterns - task-focused only.
// INVARIANT: Constraints are always injected (draft-first, no autonomous send, cite selected context).
// INVARIANT: Scaffold hash is stored for audit traceability.

/// Structured prompt scaffold for model backends
struct PromptScaffold {
    
    // MARK: - Properties
    
    let intentText: String
    let outputType: DraftOutput.OutputType
    let contextSummary: String
    let constraints: [String]
    let generatedAt: Date
    
    /// The full scaffold string sent to the model
    var scaffoldString: String {
        buildScaffoldString()
    }
    
    /// SHA256 hash of the scaffold string for audit trail
    /// Stores only the hash to avoid storing full prompt content
    var scaffoldHash: String {
        let data = Data(scaffoldString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Initialization
    
    init(from input: ModelInput) {
        self.intentText = input.intentText
        self.outputType = input.outputType
        self.contextSummary = input.contextSummary
        self.constraints = input.constraints
        self.generatedAt = Date()
    }
    
    init(
        intentText: String,
        outputType: DraftOutput.OutputType,
        contextSummary: String,
        constraints: [String] = ModelInput.defaultConstraints
    ) {
        self.intentText = intentText
        self.outputType = outputType
        self.contextSummary = contextSummary
        self.constraints = constraints
        self.generatedAt = Date()
    }
    
    // MARK: - Scaffold Building
    
    private func buildScaffoldString() -> String {
        var sections: [String] = []
        
        // Section 1: Task Instruction
        sections.append(buildTaskInstruction())
        
        // Section 2: Intent
        if !intentText.isEmpty {
            sections.append(buildIntentSection())
        }
        
        // Section 3: Context (if available)
        if !contextSummary.isEmpty {
            sections.append(buildContextSection())
        }
        
        // Section 4: Constraints (always included)
        sections.append(buildConstraintsSection())
        
        // Section 5: Output Format Guidance
        sections.append(buildOutputFormatSection())
        
        return sections.joined(separator: "\n\n")
    }
    
    private func buildTaskInstruction() -> String {
        let taskDescription: String
        
        switch outputType {
        case .emailDraft:
            taskDescription = "Draft a professional email based on the provided intent and context."
        case .meetingSummary:
            taskDescription = "Generate a concise summary of the meeting, including key discussion points and action items."
        case .documentSummary:
            taskDescription = "Summarize the key points from the provided document."
        case .taskList:
            taskDescription = "Extract and organize action items from the provided context."
        case .reminder:
            taskDescription = "Create a reminder based on the intent and context provided."
        case .researchBrief:
            taskDescription = """
            You are a senior market research analyst. Based on the user's research request, generate a concise, \
            data-driven 1-page executive market brief. Use your knowledge of recent market data, consumer trends, \
            industry reports, and cultural dynamics. Structure the brief professionally with clear sections. \
            Include specific data points, percentages, and dollar figures where possible. \
            Cite well-known sources (e.g., Statista, NPD Group, Euromonitor, McKinsey, Bureau of Labor Statistics) \
            where your knowledge allows. This is a draft for internal review only — not for external distribution.
            """
        }
        
        return """
        ## Task
        \(taskDescription)
        """
    }
    
    private func buildIntentSection() -> String {
        return """
        ## Intent
        \(intentText)
        """
    }
    
    private func buildContextSection() -> String {
        // Compact context to reasonable length
        let compactContext = contextSummary.count > 2000 
            ? String(contextSummary.prefix(2000)) + "..."
            : contextSummary
        
        return """
        ## Context
        \(compactContext)
        """
    }
    
    private func buildConstraintsSection() -> String {
        var constraintLines = constraints.map { "- \($0)" }
        
        // Always include core invariant constraints
        let coreConstraints = [
            "Output is a draft that the user must review before any action.",
            "Do not send, execute, or finalize anything automatically.",
            "Only cite information from the provided context; do not fabricate sources.",
            "Include a safety reminder that the user should review the content."
        ]
        
        for core in coreConstraints {
            if !constraintLines.contains("- \(core)") {
                constraintLines.append("- \(core)")
            }
        }
        
        return """
        ## Requirements
        \(constraintLines.joined(separator: "\n"))
        """
    }
    
    private func buildOutputFormatSection() -> String {
        let formatGuidance: String
        
        switch outputType {
        case .emailDraft:
            formatGuidance = """
            - Begin with a greeting
            - Include the main content addressing the intent
            - End with an appropriate closing
            - Keep tone professional unless context indicates otherwise
            """
        case .meetingSummary:
            formatGuidance = """
            - Start with meeting title and date (if available)
            - List key discussion points
            - Include a separate "Action Items" section with checkboxes
            - Note any decisions made
            """
        case .documentSummary:
            formatGuidance = """
            - Provide a brief overview paragraph
            - Highlight key points as bullet list
            - Note any action items or follow-ups if applicable
            """
        case .taskList:
            formatGuidance = """
            - List items with checkboxes (- [ ])
            - Group related tasks if possible
            - Include owners/assignees if mentioned in context
            """
        case .reminder:
            formatGuidance = """
            - Clear, actionable title
            - Brief note with relevant details
            - Reference source context if applicable
            """
        case .researchBrief:
            formatGuidance = """
            Structure as a 1-page executive market brief:

            **EXECUTIVE SUMMARY** (2-3 sentences)

            **MARKET OVERVIEW**
            - Market size and growth rate
            - Key data points with figures

            **KEY FINDINGS**
            1. Fastest-growing segments (with % growth)
            2. Emerging brands and disruptors
            3. Pricing trends and sweet spots
            4. Cultural and behavioral drivers

            **COMPETITIVE LANDSCAPE**
            - Top players and market share shifts
            - Emerging challengers

            **STRATEGIC RECOMMENDATIONS**
            - 3-5 actionable recommendations with rationale

            **SOURCES & METHODOLOGY**
            - List data sources referenced

            IMPORTANT: This is a DRAFT for internal review only. Do NOT distribute externally. \
            All data should be verified against primary sources before any business decisions.
            """
        }
        
        return """
        ## Output Format
        \(formatGuidance)
        """
    }
}

// MARK: - Scaffold Metadata for Audit

/// Metadata about the scaffold for audit trail storage
struct PromptScaffoldMetadata: Equatable, Codable {
    let scaffoldHash: String
    let outputType: String
    let constraintCount: Int
    let hasContext: Bool
    let generatedAt: Date
    
    init(from scaffold: PromptScaffold) {
        self.scaffoldHash = scaffold.scaffoldHash
        self.outputType = scaffold.outputType.rawValue
        self.constraintCount = scaffold.constraints.count
        self.hasContext = !scaffold.contextSummary.isEmpty
        self.generatedAt = scaffold.generatedAt
    }
}

// MARK: - ModelInput Extension

extension ModelInput {
    /// Create a prompt scaffold from this input
    var promptScaffold: PromptScaffold {
        PromptScaffold(from: self)
    }
}
