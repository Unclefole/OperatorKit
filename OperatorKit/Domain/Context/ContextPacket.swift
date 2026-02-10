import Foundation

/// Common protocol for context items (used by SentinelProposalEngine)
protocol ContextItemProtocol {
    var id: UUID { get }
    var displayText: String { get }
}

/// A packet of user-selected context for processing
/// INVARIANT: Context must be explicitly selected by user
/// INVARIANT: wasExplicitlySelected must be true for any execution
struct ContextPacket: Identifiable, Equatable {
    let id: UUID
    let calendarItems: [CalendarContextItem]
    let emailItems: [EmailContextItem]
    let fileItems: [FileContextItem]
    let timestamp: Date
    
    /// CRITICAL: This flag ensures context was explicitly selected by user
    /// INVARIANT: Must be true - context cannot be inferred or auto-selected
    let wasExplicitlySelected: Bool
    
    init(
        id: UUID = UUID(),
        calendarItems: [CalendarContextItem] = [],
        emailItems: [EmailContextItem] = [],
        fileItems: [FileContextItem] = [],
        wasExplicitlySelected: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.calendarItems = calendarItems
        self.emailItems = emailItems
        self.fileItems = fileItems
        self.wasExplicitlySelected = wasExplicitlySelected
        self.timestamp = timestamp
    }
    
    var isEmpty: Bool {
        calendarItems.isEmpty && emailItems.isEmpty && fileItems.isEmpty
    }
    
    var totalItemCount: Int {
        calendarItems.count + emailItems.count + fileItems.count
    }
    
    /// All context items as a flat array (used by Sentinel for cost estimation + citations)
    var allContextItems: [any ContextItemProtocol] {
        (calendarItems as [any ContextItemProtocol]) +
        (emailItems as [any ContextItemProtocol]) +
        (fileItems as [any ContextItemProtocol])
    }

    static func == (lhs: ContextPacket, rhs: ContextPacket) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Calendar Context Item

struct CalendarContextItem: Identifiable, Equatable, ContextItemProtocol {
    var displayText: String { "\(title) on \(formattedDate) with \(attendees.joined(separator: ", "))" }
    let id: UUID
    let title: String
    let date: Date
    let endDate: Date?
    let duration: TimeInterval
    let attendees: [String]
    let notes: String?
    let location: String?
    
    /// Link to EventKit event (for real calendar integration)
    let eventIdentifier: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        endDate: Date? = nil,
        duration: TimeInterval = 3600,
        attendees: [String] = [],
        notes: String? = nil,
        location: String? = nil,
        eventIdentifier: String? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.endDate = endDate
        self.duration = duration
        self.attendees = attendees
        self.notes = notes
        self.location = location
        self.eventIdentifier = eventIdentifier
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours) hour\(hours > 1 ? "s" : "")"
        } else {
            return "\(minutes) min"
        }
    }
    
    /// Whether this item is from real EventKit data
    var isRealCalendarEvent: Bool {
        eventIdentifier != nil
    }
}

// MARK: - Email Context Item

struct EmailContextItem: Identifiable, Equatable, ContextItemProtocol {
    var displayText: String { "Email: \(subject) from \(sender)" }
    let id: UUID
    let subject: String
    let sender: String
    let recipients: [String]
    let date: Date
    let bodyPreview: String
    
    /// Link to Mail message (future integration)
    let messageIdentifier: String?
    
    init(
        id: UUID = UUID(),
        subject: String,
        sender: String,
        recipients: [String] = [],
        date: Date,
        bodyPreview: String,
        messageIdentifier: String? = nil
    ) {
        self.id = id
        self.subject = subject
        self.sender = sender
        self.recipients = recipients
        self.date = date
        self.bodyPreview = bodyPreview
        self.messageIdentifier = messageIdentifier
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - File Context Item

struct FileContextItem: Identifiable, Equatable, ContextItemProtocol {
    var displayText: String { "File: \(name) (\(fileType))" }
    let id: UUID
    let name: String
    let fileType: String
    let path: String
    let size: Int64
    let modifiedDate: Date
    
    /// URL for file access (future integration)
    let fileURL: URL?
    
    init(
        id: UUID = UUID(),
        name: String,
        fileType: String,
        path: String,
        size: Int64 = 0,
        modifiedDate: Date = Date(),
        fileURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.fileType = fileType
        self.path = path
        self.size = size
        self.modifiedDate = modifiedDate
        self.fileURL = fileURL
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
