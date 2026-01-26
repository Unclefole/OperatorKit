import Foundation

/// Resolves raw user input into structured IntentRequest
/// Uses keyword matching (no ML in Phase 1)
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
        
        // Action items keywords
        let actionKeywords = ["action", "task", "todo", "to-do", "items", "extract"]
        if actionKeywords.contains(where: { text.contains($0) }) {
            return (.extractActionItems, 0.85)
        }
        
        // Document review keywords
        let documentKeywords = ["document", "review", "contract", "file", "read", "analyze"]
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
        case .unknown:
            return nil
        }
    }
}
