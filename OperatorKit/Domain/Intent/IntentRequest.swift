import Foundation

/// Represents a parsed user intent
struct IntentRequest: Identifiable, Equatable {
    let id: UUID
    let rawText: String
    let intentType: IntentType
    let timestamp: Date
    
    enum IntentType: String, CaseIterable {
        case draftEmail = "draft_email"
        case summarizeMeeting = "summarize_meeting"
        case extractActionItems = "extract_action_items"
        case reviewDocument = "review_document"
        case createReminder = "create_reminder"
        case researchBrief = "research_brief"
        case unknown = "unknown"

        // ════════════════════════════════════════════════════════════
        // MARK: - requiresOperatorContext
        // ════════════════════════════════════════════════════════════
        //
        // FALSE → Autonomous intent. The system acquires public context
        //         itself. MUST NEVER be blocked by ContextPicker.
        //         Routes DIRECTLY to GovernedExecution.
        //
        // TRUE  → Requires operator-provided data (emails, transcripts,
        //         documents). Must go through ContextPicker → Draft flow.
        //
        // ARCHITECTURAL INVARIANT:
        //   Autonomous intents bypass the ContextPicker entirely.
        //   The operator provides INTENT — not raw inputs.
        //   The agent acquires its own context from public sources.
        // ════════════════════════════════════════════════════════════
        var requiresOperatorContext: Bool {
            switch self {
            // ── AUTONOMOUS — system acquires public context ──────
            case .researchBrief:       return false  // web research, market intel
            case .reviewDocument:      return false  // public document analysis

            // ── OPERATOR CONTEXT REQUIRED ────────────────────────
            case .draftEmail:          return true   // needs email thread
            case .summarizeMeeting:    return true   // needs transcript
            case .extractActionItems:  return true   // needs meeting notes
            case .createReminder:      return true   // needs user specifics
            case .unknown:             return true   // ambiguous → context needed
            }
        }

        /// Default skill ID for autonomous execution when no CapabilityRouter match
        var defaultSkillId: String? {
            switch self {
            case .researchBrief:   return "web_research"
            case .reviewDocument:  return "web_research"
            default:               return nil
            }
        }
    }
    
    init(id: UUID = UUID(), rawText: String, intentType: IntentType, timestamp: Date = Date()) {
        self.id = id
        self.rawText = rawText
        self.intentType = intentType
        self.timestamp = timestamp
    }
}
