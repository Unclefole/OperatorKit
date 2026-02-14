import Foundation

/// Creates execution plans from intent and context
/// Phase 1: Template-based planning (no ML)
final class Planner {
    
    static let shared = Planner()
    
    private init() {}
    
    /// Creates an execution plan from intent and context
    /// INVARIANT: Context must have been explicitly selected
    func createPlan(intent: IntentRequest, context: ContextPacket) -> ExecutionPlan {
        #if DEBUG
        assert(context.wasExplicitlySelected, "INVARIANT VIOLATION: Context must be explicitly selected")
        #endif
        
        let steps = generateSteps(for: intent, with: context)
        
        return ExecutionPlan(
            intent: intent,
            context: context,
            steps: steps
        )
    }
    
    private func generateSteps(for intent: IntentRequest, with context: ContextPacket) -> [PlanStep] {
        switch intent.intentType {
        case .draftEmail:
            return createEmailDraftSteps(context: context)
        case .summarizeMeeting:
            return createMeetingSummarySteps(context: context)
        case .extractActionItems:
            return createActionItemSteps(context: context)
        case .reviewDocument:
            return createDocumentReviewSteps(context: context)
        case .createReminder:
            return createReminderSteps(context: context)
        case .researchBrief:
            return createResearchBriefSteps(context: context)
        case .unknown:
            return createFallbackSteps()
        }
    }
    
    private func createEmailDraftSteps(context: ContextPacket) -> [PlanStep] {
        var steps: [PlanStep] = []
        var stepNumber = 1
        
        if !context.calendarItems.isEmpty {
            steps.append(PlanStep(
                stepNumber: stepNumber,
                title: "Summarize the meeting",
                description: "Generate a brief summary of the meeting context",
                requiresPermission: .calendar,
                estimatedConfidence: 0.9
            ))
            stepNumber += 1
        }
        
        steps.append(PlanStep(
            stepNumber: stepNumber,
            title: "Extract action items",
            description: "Identify key action items and timeline changes for follow-up",
            estimatedConfidence: 0.85
        ))
        stepNumber += 1
        
        steps.append(PlanStep(
            stepNumber: stepNumber,
            title: "Draft a follow-up email",
            description: "Create email draft based on meeting summary and action items",
            requiresPermission: .email,
            estimatedConfidence: 0.9
        ))
        stepNumber += 1
        
        steps.append(PlanStep(
            stepNumber: stepNumber,
            title: "Suggest reminders",
            description: "Add task reminders to follow up on action items",
            requiresPermission: .reminders,
            estimatedConfidence: 0.8
        ))
        
        return steps
    }
    
    private func createMeetingSummarySteps(context: ContextPacket) -> [PlanStep] {
        [
            PlanStep(
                stepNumber: 1,
                title: "Analyze meeting content",
                description: "Review calendar event details and notes",
                requiresPermission: .calendar,
                estimatedConfidence: 0.9
            ),
            PlanStep(
                stepNumber: 2,
                title: "Generate summary",
                description: "Create concise meeting summary",
                estimatedConfidence: 0.85
            ),
            PlanStep(
                stepNumber: 3,
                title: "Extract key decisions",
                description: "Identify important decisions made",
                estimatedConfidence: 0.8
            )
        ]
    }
    
    private func createActionItemSteps(context: ContextPacket) -> [PlanStep] {
        [
            PlanStep(
                stepNumber: 1,
                title: "Scan context for tasks",
                description: "Analyze selected items for actionable tasks",
                estimatedConfidence: 0.85
            ),
            PlanStep(
                stepNumber: 2,
                title: "Extract action items",
                description: "Compile list of action items with owners",
                estimatedConfidence: 0.9
            ),
            PlanStep(
                stepNumber: 3,
                title: "Suggest deadlines",
                description: "Propose reasonable deadlines based on context",
                estimatedConfidence: 0.75
            )
        ]
    }
    
    private func createDocumentReviewSteps(context: ContextPacket) -> [PlanStep] {
        [
            PlanStep(
                stepNumber: 1,
                title: "Read document",
                description: "Analyze selected document content",
                requiresPermission: .files,
                estimatedConfidence: 0.9
            ),
            PlanStep(
                stepNumber: 2,
                title: "Identify key points",
                description: "Extract main points and sections",
                estimatedConfidence: 0.85
            ),
            PlanStep(
                stepNumber: 3,
                title: "Suggest changes",
                description: "Propose improvements or corrections",
                estimatedConfidence: 0.7
            )
        ]
    }
    
    private func createReminderSteps(context: ContextPacket) -> [PlanStep] {
        [
            PlanStep(
                stepNumber: 1,
                title: "Analyze context",
                description: "Review selected items for reminder content",
                estimatedConfidence: 0.9
            ),
            PlanStep(
                stepNumber: 2,
                title: "Preview reminder",
                description: "Show reminder draft for your review (does not save to Reminders)",
                requiresPermission: .reminders,
                estimatedConfidence: 0.85
            )
        ]
    }
    
    /// Suggests reminders based on draft content
    /// Phase 2B: Preview only - does not save
    func suggestReminder(from draft: Draft) -> ReminderPreview? {
        switch draft.type {
        case .email:
            // Suggest follow-up reminder for email drafts
            if let recipient = draft.content.recipient {
                return ReminderPreview(
                    title: "Follow up on email to \(recipient)",
                    notes: "Check if \(recipient) has responded to your email about: \(draft.title)",
                    dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
                    priority: .medium
                )
            }
            return nil
            
        case .summary, .actionItems:
            // Suggest review reminder for summaries
            return ReminderPreview(
                title: "Review: \(draft.title)",
                notes: "Review action items and follow up on any outstanding tasks",
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                priority: .low
            )
            
        case .reminder:
            // Already a reminder - use the draft content
            return ReminderPreview(
                title: draft.title,
                notes: draft.content.body,
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                priority: .medium
            )
            
        case .documentReview:
            return ReminderPreview(
                title: "Complete review: \(draft.title)",
                notes: "Finish reviewing and provide feedback",
                dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
                priority: .medium
            )
        case .researchBrief:
            return ReminderPreview(
                title: "Review research brief: \(draft.title)",
                notes: "Verify data sources and finalize strategic recommendations",
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                priority: .high
            )
        }
    }
    
    private func createResearchBriefSteps(context: ContextPacket) -> [PlanStep] {
        [
            PlanStep(
                stepNumber: 1,
                title: "Analyze research request",
                description: "Parse the research question and identify key topics, segments, and data needs",
                estimatedConfidence: 0.9
            ),
            PlanStep(
                stepNumber: 2,
                title: "Generate market intelligence",
                description: "Use cloud AI to synthesize market data, consumer trends, and industry insights",
                estimatedConfidence: 0.85
            ),
            PlanStep(
                stepNumber: 3,
                title: "Draft executive brief",
                description: "Produce a structured 1-page executive market brief with strategic recommendations",
                estimatedConfidence: 0.8
            ),
            PlanStep(
                stepNumber: 4,
                title: "Hold for review",
                description: "Present draft for your review — stopped before any external distribution",
                estimatedConfidence: 0.95
            )
        ]
    }

    private func createFallbackSteps() -> [PlanStep] {
        [
            PlanStep(
                stepNumber: 1,
                title: "Analyze request",
                description: "Attempt to understand the request",
                estimatedConfidence: 0.4
            )
        ]
    }
}
