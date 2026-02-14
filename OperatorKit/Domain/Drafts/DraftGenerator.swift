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
    
    // MARK: - State (governed routing)
    
    @Published private(set) var lastProvider: ModelProvider = .onDevice
    @Published private(set) var pendingApprovalDecision: ModelCallDecision?
    
    // MARK: - Generation (Governed Path)
    
    /// Generate a draft using governed intelligence routing.
    /// Kernel decides provider. Cloud is token-gated. All calls evidence-logged.
    func generate(
        intent: IntentRequest,
        context: ContextPacket,
        recipient: String? = nil,
        riskTierHint: String? = nil
    ) async throws -> Draft {
        isGenerating = true
        lastError = nil
        pendingApprovalDecision = nil
        
        defer { isGenerating = false }
        
        log("DraftGenerator: Starting governed generation for \(intent.intentType.rawValue)")
        
        do {
            // Use governed path through ModelRouter
            let result = try await modelRouter.generateGoverned(
                intent: intent,
                context: context,
                riskTierHint: riskTierHint
            )
            
            switch result {
            case .success(let output, let provider):
                lastDraftOutput = output
                // Use cloud-specific metadata for cloud providers, on-device metadata otherwise
                if provider.isCloud {
                    lastModelMetadata = modelRouter.cloudModelMetadata(
                        provider: provider,
                        modelId: provider.displayName,
                        latencyMs: modelRouter.lastGenerationTimeMs
                    )
                } else {
                    lastModelMetadata = modelRouter.currentModelMetadata()
                }
                lastProvider = provider
                
                let finalRecipient = recipient ?? extractRecipient(from: context, intent: intent)
                let draft = Draft.from(
                    output: output,
                    recipient: finalRecipient,
                    modelMetadata: lastModelMetadata
                )
                
                log("DraftGenerator: Generated \(draft.type.rawValue) via \(provider.displayName) with confidence \(draft.confidencePercentage)%")
                return draft
                
            case .denied(let reason):
                throw ModelError.generationFailed("Kernel denied model call: \(reason)")
                
            case .requiresApproval(let decision):
                // Surface to UI — caller should check pendingApprovalDecision
                pendingApprovalDecision = decision
                log("DraftGenerator: Cloud call requires human approval — surfacing to UI")
                throw CloudModelError.requiresHumanApproval
            }
            
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
        case .researchBrief:
            return "# Executive Market Brief\n\n[Generating research brief via cloud AI...]\n\nThis is a draft for internal review only."
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
        case .researchBrief: return .researchBrief
        case .unknown: return .meetingSummary
        }
    }
}
