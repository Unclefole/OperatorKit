import Foundation

/// Resolves raw user input into structured IntentRequest
/// Uses keyword matching (no ML in Phase 1)
///
/// P0 FIX: Research/web queries were misclassified because:
///   1. "web" was not in the research keywords list
///   2. Compound phrase "search the web" was not detected
///   3. Single high-signal words like "search" fell through to other categories
///
/// PRIORITY ORDER:
///   1. Autonomous intents (research/intelligence) — checked FIRST
///   2. Context-dependent intents (email, meeting, etc.)
///   3. Fallback to .unknown
///
/// This ordering is CRITICAL because research queries often contain
/// words that match other categories ("analyze", "report", "brief").
final class IntentResolver {

    static let shared = IntentResolver()

    private init() {}

    func resolve(rawInput: String) -> IntentResolution {
        let lowercased = rawInput.lowercased()

        let (intentType, confidence) = detectIntentType(from: lowercased)

        let request = IntentRequest(
            rawText: rawInput,
            intentType: intentType
        )

        return IntentResolution(
            request: request,
            confidence: confidence,
            suggestedWorkflow: suggestedWorkflow(for: intentType)
        )
    }

    private func detectIntentType(from text: String) -> (IntentRequest.IntentType, Double) {

        // ════════════════════════════════════════════════════════════
        // PRIORITY 1: AUTONOMOUS INTENTS (RESEARCH / INTELLIGENCE)
        // ════════════════════════════════════════════════════════════
        // These are checked FIRST because:
        //   - Research queries often contain words that match other
        //     categories ("analyze", "report", "brief", "extract")
        //   - Autonomous execution has the highest routing priority
        //   - Misclassification causes ContextPicker to appear (P0 bug)
        //
        // RULE: If ANY compound research phrase OR 2+ research
        //       keywords match, this IS research. No other category
        //       can override it.
        // ════════════════════════════════════════════════════════════

        // High-confidence command phrases — instant match
        if text.contains("governed") && text.contains("research") {
            return (.researchBrief, 0.98)
        }
        if text.contains("autonomous") && text.contains("research") {
            return (.researchBrief, 0.98)
        }

        // Compound phrase detection — these are unambiguously research
        let researchPhrases = [
            "web research", "market intelligence", "search the web",
            "search online", "look up", "find out about", "find out",
            "research brief", "competitive analysis", "market research",
            "industry research", "consumer research", "search for recent",
            "search for data", "search for information", "search for",
            "investigate the", "investigate how", "investigate why",
            "go to web", "go to the web", "search about",
            "latest data on", "recent data on", "what is the latest"
        ]
        for phrase in researchPhrases {
            if text.contains(phrase) {
                return (.researchBrief, 0.95)
            }
        }

        // Keyword threshold — 2+ signals = research
        let researchKeywords = [
            "search", "research", "find", "identify", "investigate",
            "market", "consumer", "spending", "trends", "analysis",
            "analyze", "data", "report", "brief", "insight", "segment",
            "landscape", "competitive", "industry", "demographic",
            "emerging", "growth", "strategic", "recommendation",
            "governed", "authoritative", "sector", "footwear",
            "intelligence", "autonomous", "sources", "regulatory",
            "scanning", "public", "web", "pricing", "competitor"
        ]
        let researchHits = researchKeywords.filter { text.contains($0) }.count
        if researchHits >= 2 {
            let confidence = min(0.98, 0.7 + Double(researchHits) * 0.05)
            return (.researchBrief, confidence)
        }

        // Single high-signal word with negative guard
        // "search" alone (not in email/meeting context) is research
        if text.contains("search") && !text.contains("email") && !text.contains("meeting") && !text.contains("calendar") {
            return (.researchBrief, 0.80)
        }

        // ════════════════════════════════════════════════════════════
        // PRIORITY 2: CONTEXT-DEPENDENT INTENTS
        // ════════════════════════════════════════════════════════════

        // Email-related keywords
        let emailKeywords = ["email", "mail", "send", "reply", "respond", "draft", "write to", "message"]
        if emailKeywords.contains(where: { text.contains($0) }) {
            let confidence = text.contains("draft") || text.contains("follow-up") ? 0.95 : 0.85
            return (.draftEmail, confidence)
        }

        // Meeting-related keywords
        let meetingKeywords = ["meeting", "summarize", "summary", "recap", "notes"]
        if meetingKeywords.contains(where: { text.contains($0) }) {
            let confidence = text.contains("summarize") ? 0.9 : 0.8
            return (.summarizeMeeting, confidence)
        }

        // Action items keywords — tightened to require COMPOUND matches
        // to prevent false positives on research queries
        let actionPhrases = ["action items", "action item", "to-do list", "todo list", "extract tasks", "extract action"]
        if actionPhrases.contains(where: { text.contains($0) }) {
            return (.extractActionItems, 0.90)
        }
        // Single keyword fallback — only if no research signal
        let actionKeywords = ["task list", "todo", "to-do"]
        if actionKeywords.contains(where: { text.contains($0) }) {
            return (.extractActionItems, 0.80)
        }

        // Document review keywords
        let documentKeywords = ["document", "review", "contract", "file", "read"]
        if documentKeywords.contains(where: { text.contains($0) }) {
            return (.reviewDocument, 0.8)
        }

        // Reminder keywords
        let reminderKeywords = ["remind", "reminder", "remember", "follow up", "follow-up"]
        if reminderKeywords.contains(where: { text.contains($0) }) {
            return (.createReminder, 0.85)
        }

        return (.unknown, 0.3)
    }

    private func suggestedWorkflow(for intentType: IntentRequest.IntentType) -> String? {
        switch intentType {
        case .draftEmail:
            return "Client Follow-Up"
        case .summarizeMeeting:
            return "Meeting Summary"
        case .extractActionItems:
            return "Action Items Extraction"
        case .reviewDocument:
            return "Document Review"
        case .createReminder:
            return "Reminder Creation"
        case .researchBrief:
            return "Research & Analysis Brief"
        case .unknown:
            return nil
        }
    }
}
