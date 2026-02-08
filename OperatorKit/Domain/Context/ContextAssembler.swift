import Foundation

/// Assembles context from user selections into a ContextPacket
/// INVARIANT: Never queries data without user action
/// INVARIANT: Only assembles explicitly selected items
@MainActor
final class ContextAssembler: ObservableObject {
    
    static let shared = ContextAssembler()
    
    // MARK: - Dependencies
    
    private let calendarService = CalendarService.shared
    
    // MARK: - Published State
    
    @Published private(set) var availableCalendarEvents: [CalendarEventModel] = []
    @Published private(set) var availableEmails: [EmailContextItem] = []
    @Published private(set) var availableFiles: [FileContextItem] = []
    @Published private(set) var isLoading: Bool = false
    
    private init() {}
    
    // MARK: - Load Available Context (User-Initiated Only)
    
    /// Loads available calendar events for selection
    /// INVARIANT: Only called when user opens ContextPicker
    func loadAvailableCalendarEvents() async {
        isLoading = true
        defer { isLoading = false }
        
        // Check if we have calendar access
        if calendarService.isAuthorized {
            availableCalendarEvents = await calendarService.fetchEventsForSelection(
                daysBack: 7,
                daysForward: 7,
                limit: 50
            )
            log("Loaded \(availableCalendarEvents.count) real calendar events")
        } else {
            // Fall back to mock data if not authorized
            availableCalendarEvents = []
            log("Calendar not authorized - no events loaded")
        }
    }
    
    /// Loads available emails for selection (mock for Phase 2B)
    func loadAvailableEmails() {
        // Phase 2B: Still using mock data for emails
        // Mail integration is draft-only via MessageUI
        availableEmails = getMockEmailItems()
        log("Loaded \(availableEmails.count) mock email items")
    }
    
    /// Loads available files for selection (mock for Phase 2B)
    func loadAvailableFiles() {
        // Phase 2B: Still using mock data for files
        availableFiles = getMockFileItems()
        log("Loaded \(availableFiles.count) mock file items")
    }
    
    /// Loads all available context items
    /// INVARIANT: Only called when user opens ContextPicker
    func loadAllAvailableContext() async {
        await loadAvailableCalendarEvents()
        loadAvailableEmails()
        loadAvailableFiles()
    }
    
    // MARK: - Assemble Context Packet
    
    /// Assembles a context packet from user-selected items
    /// INVARIANT: All items must be explicitly selected by user
    func assemble(
        selectedCalendarEventIds: Set<String>,
        selectedEmailIds: Set<UUID>,
        selectedFileIds: Set<UUID>
    ) async -> ContextPacket {
        var calendarItems: [CalendarContextItem] = []
        
        // Get real calendar events
        if !selectedCalendarEventIds.isEmpty && calendarService.isAuthorized {
            let events = await calendarService.fetchSelectedEvents(identifiers: selectedCalendarEventIds)
            calendarItems = events.map { $0.toContextItem() }
            log("Assembled \(calendarItems.count) real calendar items")
        }
        
        // Get selected emails (from mock data)
        let emailItems = availableEmails.filter { selectedEmailIds.contains($0.id) }
        
        // Get selected files (from mock data)
        let fileItems = availableFiles.filter { selectedFileIds.contains($0.id) }
        
        return ContextPacket(
            calendarItems: calendarItems,
            emailItems: emailItems,
            fileItems: fileItems,
            wasExplicitlySelected: true // User selected these items
        )
    }
    
    /// Legacy method for backward compatibility
    func assemble(
        selectedCalendarIds: Set<UUID>,
        selectedEmailIds: Set<UUID>,
        selectedFileIds: Set<UUID>
    ) -> ContextPacket {
        // For mock data selected by UUID
        let calendarItems = getAvailableCalendarItems().filter { selectedCalendarIds.contains($0.id) }
        let emailItems = availableEmails.filter { selectedEmailIds.contains($0.id) }
        let fileItems = availableFiles.filter { selectedFileIds.contains($0.id) }
        
        return ContextPacket(
            calendarItems: calendarItems,
            emailItems: emailItems,
            fileItems: fileItems,
            wasExplicitlySelected: true
        )
    }
    
    // MARK: - Calendar Authorization
    
    var calendarAuthorizationStatus: String {
        if calendarService.isAuthorized {
            return "Authorized"
        } else {
            switch calendarService.authorizationState {
            case .notDetermined:
                return "Not Requested"
            case .denied:
                return "Denied"
            case .restricted:
                return "Restricted"
            default:
                return "Unknown"
            }
        }
    }
    
    var isCalendarAuthorized: Bool {
        calendarService.isAuthorized
    }
    
    /// Request calendar access (user-initiated only)
    func requestCalendarAccess() async -> Bool {
        await calendarService.requestAccess()
    }
    
    // MARK: - Mock Data (For items without real integration yet)
    
    func getAvailableCalendarItems() -> [CalendarContextItem] {
        // Convert real events to context items if available
        if !availableCalendarEvents.isEmpty {
            return availableCalendarEvents.map { $0.toContextItem() }
        }
        
        // Fall back to mock data
        return [
            CalendarContextItem(
                title: "Client Check-In",
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                duration: 3600,
                attendees: ["client@example.com", "john@company.com"],
                notes: "Discussed Q3 planning and project roadmap"
            ),
            CalendarContextItem(
                title: "Team Standup",
                date: Date(),
                duration: 1800,
                attendees: ["team@company.com"]
            ),
            CalendarContextItem(
                title: "Product Review",
                date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
                duration: 5400,
                attendees: ["product@company.com", "engineering@company.com"]
            )
        ]
    }
    
    private func getMockEmailItems() -> [EmailContextItem] {
        [
            EmailContextItem(
                subject: "Re: Q3 Planning",
                sender: "client@example.com",
                recipients: ["john@company.com"],
                date: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!,
                bodyPreview: "Thanks for the meeting yesterday. I wanted to follow up on..."
            ),
            EmailContextItem(
                subject: "Project Update",
                sender: "manager@company.com",
                recipients: ["team@company.com"],
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                bodyPreview: "Here's the latest status on our project milestones..."
            )
        ]
    }
    
    private func getMockFileItems() -> [FileContextItem] {
        [
            FileContextItem(
                name: "Project Roadmap",
                fileType: "pdf",
                path: "/Documents/Project Roadmap.pdf",
                size: 1024 * 500,
                modifiedDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            ),
            FileContextItem(
                name: "Meeting Notes",
                fileType: "txt",
                path: "/Documents/Meeting Notes.txt",
                size: 1024 * 10
            ),
            FileContextItem(
                name: "Contract Draft",
                fileType: "docx",
                path: "/Documents/Contract Draft.docx",
                size: 1024 * 200,
                modifiedDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!
            )
        ]
    }
}
