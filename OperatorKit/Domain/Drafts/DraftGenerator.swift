import Foundation

/// Generates drafts using the on-device model pipeline
/// INVARIANT: All outputs are drafts first
/// INVARIANT: Uses ModelRouter for on-device generation
/// INVARIANT: No network calls
@MainActor
final class DraftGenerator: ObservableObject {
    
    static let shared = DraftGenerator()
    
    // MARK: - Dependencies
    
    private let modelRouter = ModelRouter.shared
    
    // MARK: - Published State
    
    @Published private(set) var isGenerating: Bool = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastDraftOutput: DraftOutput?
    @Published private(set) var lastModelMetadata: ModelMetadata?
    
    private init() {}
    
    // MARK: - Generation
    
    /// Generate a draft from intent and context using ModelRouter
    /// INVARIANT: Uses on-device model only (no network calls)
    func generate(
        intent: IntentRequest,
        context: ContextPacket,
        recipient: String? = nil
    ) async throws -> Draft {
        isGenerating = true
        lastError = nil
        
        defer { isGenerating = false }
        
        log("DraftGenerator: Starting generation for \(intent.intentType.rawValue)")
        
        // Build model input
        let input = ModelInput.from(intent: intent, context: context)
        
        do {
            // Generate using ModelRouter
            let output = try await modelRouter.generate(input: input)
            
            // Store for reference
            lastDraftOutput = output
            lastModelMetadata = modelRouter.currentModelMetadata
            
            // Determine recipient from context if not provided
            let finalRecipient = recipient ?? extractRecipient(from: context, intent: intent)
            
            // Convert to Draft
            let draft = Draft.from(
                output: output,
                recipient: finalRecipient,
                modelMetadata: lastModelMetadata
            )
            
            log("DraftGenerator: Generated \(draft.type.rawValue) with confidence \(draft.confidencePercentage)%")
            
            return draft
            
        } catch {
            lastError = error.localizedDescription
            logError("DraftGenerator: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Generate from plan (uses plan's intent and context)
    func generate(from plan: ExecutionPlan, recipient: String? = nil) async throws -> Draft {
        try await generate(
            intent: plan.intent,
            context: plan.context,
            recipient: recipient
        )
    }
    
    // MARK: - Confidence Routing
    
    /// Check if generated output requires fallback
    var requiresFallback: Bool {
        guard let output = lastDraftOutput else { return false }
        return output.requiresFallbackConfirmation
    }
    
    /// Check if generated output is blocked
    var isBlocked: Bool {
        guard let output = lastDraftOutput else { return false }
        return output.isBlocked
    }
    
    /// Get fallback reason
    var fallbackReason: String? {
        guard let output = lastDraftOutput else { return nil }
        
        if output.isBlocked {
            return "Confidence too low (\(output.confidencePercentage)%). Please add more context or clarify your intent."
        } else if output.requiresFallbackConfirmation {
            return "Moderate confidence (\(output.confidencePercentage)%). Review carefully before proceeding."
        }
        
        return nil
    }
    
    // MARK: - Helpers
    
    /// Extract recipient from context
    private func extractRecipient(from context: ContextPacket, intent: IntentRequest) -> String? {
        // From email threads
        if let email = context.emailItems.first {
            return email.sender
        }
        
        // From calendar attendees
        if let meeting = context.calendarItems.first,
           let attendee = meeting.attendees.first {
            return attendee
        }
        
        return nil
    }
    
    /// Get the DraftOutput for current generation
    var currentOutput: DraftOutput? {
        lastDraftOutput
    }
    
    /// Get model info for audit
    var modelInfo: ModelMetadata? {
        lastModelMetadata
    }
}

// MARK: - Legacy Support

extension DraftGenerator {
    /// Legacy method for backward compatibility
    func createDraft(plan: ExecutionPlan) -> Draft {
        // Synchronous wrapper - uses template fallback
        let output = DraftOutput(
            draftBody: generateLegacyBody(for: plan),
            subject: generateLegacySubject(for: plan),
            actionItems: [],
            confidence: plan.context.isEmpty ? 0.55 : 0.85,
            citations: generateLegacyCitations(from: plan.context),
            safetyNotes: ["You must review before sending."],
            outputType: mapIntentType(plan.intent.intentType)
        )
        
        return Draft.from(
            output: output,
            recipient: extractLegacyRecipient(from: plan),
            modelMetadata: ModelMetadata(
                modelId: "legacy_sync",
                displayName: "Legacy Sync Generator",
                version: "0.0.1"
            )
        )
    }
    
    private func generateLegacyBody(for plan: ExecutionPlan) -> String {
        switch plan.intent.intentType {
        case .draftEmail:
            return "Hi,\n\nFollowing up on our recent conversation.\n\n[Add your message here]\n\nBest regards"
        case .summarizeMeeting:
            return "# Meeting Summary\n\n[Add summary details]"
        case .extractActionItems:
            return "# Action Items\n\n- [ ] [Add action item]"
        case .reviewDocument:
            return "# Document Review\n\n[Add review notes]"
        case .createReminder:
            return "Reminder: \(plan.intent.rawText)"
        case .unknown:
            return "[Generated content]"
        }
    }
    
    private func generateLegacySubject(for plan: ExecutionPlan) -> String {
        if let meeting = plan.context.calendarItems.first {
            return "Follow-up: \(meeting.title)"
        }
        return "Follow-up"
    }
    
    private func generateLegacyCitations(from context: ContextPacket) -> [Citation] {
        var citations: [Citation] = []
        
        for item in context.calendarItems {
            citations.append(Citation.fromCalendarItem(item))
        }
        for item in context.emailItems {
            citations.append(Citation.fromEmailItem(item))
        }
        for item in context.fileItems {
            citations.append(Citation.fromFileItem(item))
        }
        
        return citations
    }
    
    private func extractLegacyRecipient(from plan: ExecutionPlan) -> String? {
        plan.context.emailItems.first?.sender ?? plan.context.calendarItems.first?.attendees.first
    }
    
    private func mapIntentType(_ intentType: IntentRequest.IntentType) -> DraftOutput.OutputType {
        switch intentType {
        case .draftEmail: return .emailDraft
        case .summarizeMeeting: return .meetingSummary
        case .extractActionItems: return .taskList
        case .reviewDocument: return .documentSummary
        case .createReminder: return .reminder
        case .unknown: return .meetingSummary
        }
    }
}
