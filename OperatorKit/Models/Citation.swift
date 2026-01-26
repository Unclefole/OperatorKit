import Foundation

/// A citation referencing user-selected context used in draft generation
/// INVARIANT: Citations must only reference explicitly selected context
/// INVARIANT: Snippets must be derived only from selected context (never unselected data)
struct Citation: Identifiable, Equatable, Codable {
    let id: UUID
    let sourceType: SourceType
    let sourceId: String  // eventIdentifier, file URL bookmark, message ID, etc.
    let snippet: String   // Short excerpt used (<=200 chars)
    let label: String     // Human-readable label: "Meeting title", "Agenda line", etc.
    let timestamp: Date   // When the source was created/modified
    
    /// The type of source being cited
    enum SourceType: String, Codable, CaseIterable {
        case calendarEvent = "calendar_event"
        case emailThread = "email_thread"
        case file = "file"
        case note = "note"
        
        var displayName: String {
            switch self {
            case .calendarEvent: return "Calendar Event"
            case .emailThread: return "Email Thread"
            case .file: return "File"
            case .note: return "Note"
            }
        }
        
        var icon: String {
            switch self {
            case .calendarEvent: return "calendar"
            case .emailThread: return "envelope"
            case .file: return "doc.fill"
            case .note: return "note.text"
            }
        }
        
        var color: String {
            switch self {
            case .calendarEvent: return "red"
            case .emailThread: return "blue"
            case .file: return "orange"
            case .note: return "yellow"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        sourceType: SourceType,
        sourceId: String,
        snippet: String,
        label: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceId = sourceId
        // Enforce snippet length limit
        self.snippet = String(snippet.prefix(200))
        self.label = label
        self.timestamp = timestamp
    }
    
    // MARK: - Factory Methods
    
    /// Create citation from a calendar context item
    static func fromCalendarItem(_ item: CalendarContextItem) -> Citation {
        var snippetParts: [String] = []
        
        snippetParts.append(item.title)
        
        if !item.attendees.isEmpty {
            snippetParts.append("with \(item.attendees.prefix(3).joined(separator: ", "))")
        }
        
        if let notes = item.notes, !notes.isEmpty {
            snippetParts.append(String(notes.prefix(50)))
        }
        
        return Citation(
            sourceType: .calendarEvent,
            sourceId: item.eventIdentifier ?? item.id.uuidString,
            snippet: snippetParts.joined(separator: " - "),
            label: "Meeting: \(item.title)",
            timestamp: item.date
        )
    }
    
    /// Create citation from an email context item
    static func fromEmailItem(_ item: EmailContextItem) -> Citation {
        Citation(
            sourceType: .emailThread,
            sourceId: item.messageIdentifier ?? item.id.uuidString,
            snippet: "\(item.subject) - \(item.bodyPreview.prefix(100))",
            label: "Email from \(item.sender)",
            timestamp: item.date
        )
    }
    
    /// Create citation from a file context item
    static func fromFileItem(_ item: FileContextItem) -> Citation {
        Citation(
            sourceType: .file,
            sourceId: item.fileURL?.absoluteString ?? item.id.uuidString,
            snippet: "\(item.name) (\(item.fileType.uppercased()))",
            label: "File: \(item.name)",
            timestamp: item.modifiedDate
        )
    }
    
    // MARK: - Display Helpers
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var truncatedSnippet: String {
        if snippet.count > 80 {
            return String(snippet.prefix(77)) + "..."
        }
        return snippet
    }
    
    static func == (lhs: Citation, rhs: Citation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Citation Collection Extensions

extension Array where Element == Citation {
    /// Group citations by source type
    var groupedByType: [Citation.SourceType: [Citation]] {
        Dictionary(grouping: self, by: { $0.sourceType })
    }
    
    /// Summary string for display
    var summary: String {
        let types = Set(self.map { $0.sourceType })
        var parts: [String] = []
        
        for type in types {
            let count = self.filter { $0.sourceType == type }.count
            parts.append("\(count) \(type.displayName.lowercased())\(count > 1 ? "s" : "")")
        }
        
        return parts.joined(separator: ", ")
    }
}
