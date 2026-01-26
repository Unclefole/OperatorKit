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
        case unknown = "unknown"
    }
    
    init(id: UUID = UUID(), rawText: String, intentType: IntentType, timestamp: Date = Date()) {
        self.id = id
        self.rawText = rawText
        self.intentType = intentType
        self.timestamp = timestamp
    }
}
