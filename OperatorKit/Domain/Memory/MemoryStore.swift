import Foundation
import SwiftData
import SwiftUI

/// Persistent memory store using SwiftData
/// Replaces in-memory storage with durable on-device persistence
@MainActor
final class MemoryStore: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = MemoryStore()
    
    // MARK: - Published State
    
    @Published private(set) var items: [PersistedMemoryItem] = []
    @Published private(set) var isLoaded: Bool = false
    
    // MARK: - SwiftData Container
    
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    private init() {
        setupSwiftData()
    }
    
    private func setupSwiftData() {
        do {
            let schema = Schema([PersistedMemoryItem.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false, // Persist to disk
                allowsSave: true
            )
            
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            if let container = modelContainer {
                modelContext = ModelContext(container)
                loadItems()
            }
            
            log("SwiftData initialized successfully")
        } catch {
            logError("Failed to initialize SwiftData: \(error.localizedDescription)")
            // Fall back to in-memory only
            setupInMemoryFallback()
        }
    }
    
    private func setupInMemoryFallback() {
        do {
            let schema = Schema([PersistedMemoryItem.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            if let container = modelContainer {
                modelContext = ModelContext(container)
            }
            log("SwiftData fallback to in-memory storage")
        } catch {
            logError("Failed to create in-memory fallback: \(error)")
        }
    }
    
    // MARK: - Load Items
    
    private func loadItems() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<PersistedMemoryItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            items = try context.fetch(descriptor)
            isLoaded = true
            log("Loaded \(items.count) memory items from persistent storage")
            
            // If empty, add initial demo data
            if items.isEmpty {
                loadDemoData()
            }
        } catch {
            logError("Failed to fetch memory items: \(error)")
            items = []
            isLoaded = true
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Add a new memory item
    func add(_ item: PersistedMemoryItem) {
        guard let context = modelContext else {
            logError("No model context available")
            return
        }
        
        context.insert(item)
        saveContext()
        loadItems() // Refresh list
        
        log("Added memory item: \(item.title)")
    }
    
    /// Add from execution result (converts domain model to persisted model)
    /// Phase 2C: Includes model metadata in audit trail
    func addFromExecution(
        result: ExecutionResultModel,
        intent: IntentRequest?,
        context: ContextPacket?,
        approvalTimestamp: Date
    ) {
        let type: PersistedMemoryItem.MemoryItemType
        switch result.draft.type {
        case .email:
            type = result.status == .savedDraftOnly ? .draftedEmail : .sentEmail
        case .summary:
            type = .summary
        case .actionItems:
            type = .actionItems
        case .reminder:
            type = .reminder
        case .documentReview:
            type = .documentReview
        }
        
        let item = PersistedMemoryItem(
            type: type,
            title: result.draft.title,
            preview: String(result.draft.content.body.prefix(150)) + (result.draft.content.body.count > 150 ? "..." : "")
        )
        
        // Audit trail
        item.intentSummary = intent?.rawText
        item.contextSummary = buildContextSummary(context)
        item.approvalTimestamp = approvalTimestamp
        
        // Draft content
        item.draftType = mapDraftType(result.draft.type)
        item.draftTitle = result.draft.title
        item.draftRecipient = result.draft.content.recipient
        item.draftSubject = result.draft.content.subject
        item.draftBody = result.draft.content.body
        item.draftSignature = result.draft.content.signature
        item.draftConfidence = result.draft.confidence
        
        // Model metadata (Phase 2C + Phase 4A + Phase 4C)
        item.modelBackendUsed = result.auditTrail.modelMetadata?.backend.rawValue ?? result.auditTrail.modelBackendUsed
        item.modelId = result.auditTrail.modelMetadata?.modelId ?? result.auditTrail.confidenceSnapshot?.modelId
        item.modelVersion = result.auditTrail.modelMetadata?.version ?? result.auditTrail.confidenceSnapshot?.modelVersion
        item.confidenceAtDraft = result.auditTrail.confidenceAtDraft
        item.citationsCount = result.auditTrail.citationsCount
        item.safetyNotesAtDraft = result.draft.safetyNotes
        item.generationLatencyMs = result.auditTrail.generationLatencyMs
        item.fallbackReason = result.auditTrail.fallbackReason
        item.usedFallback = result.auditTrail.usedFallback
        
        // Phase 4C: Quality hardening fields
        item.validationPass = result.auditTrail.validationPass
        item.timeoutOccurred = result.auditTrail.timeoutOccurred
        item.citationValidityPass = result.auditTrail.citationValidityPass
        item.promptScaffoldHash = result.auditTrail.promptScaffoldHash
        
        // Execution result
        item.executionStatus = mapExecutionStatus(result.status)
        item.executionMessage = result.message
        item.executionTimestamp = result.timestamp
        
        // Side effects
        item.executedSideEffects = result.executedSideEffects.map { executed in
            PersistedSideEffect(
                id: executed.id,
                type: mapSideEffectType(executed.sideEffect.type),
                description: executed.sideEffect.description,
                wasExecuted: executed.wasExecuted,
                resultMessage: executed.resultMessage
            )
        }
        
        // Attachments
        item.attachments = result.draft.attachments.map { $0.name }
        
        add(item)
    }
    
    /// Remove a memory item
    func remove(_ item: PersistedMemoryItem) {
        guard let context = modelContext else { return }
        
        context.delete(item)
        saveContext()
        loadItems()
        
        log("Removed memory item: \(item.title)")
    }
    
    /// Remove by ID
    func remove(id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        remove(item)
    }
    
    /// Clear all memory (user-initiated)
    func clearAll() {
        guard let context = modelContext else { return }
        
        for item in items {
            context.delete(item)
        }
        saveContext()
        loadItems()
        
        log("Cleared all memory items")
    }
    
    // MARK: - Search & Filter
    
    func search(query: String) -> [PersistedMemoryItem] {
        guard !query.isEmpty else { return items }
        let lowercased = query.lowercased()
        return items.filter {
            $0.title.lowercased().contains(lowercased) ||
            $0.preview.lowercased().contains(lowercased) ||
            ($0.intentSummary?.lowercased().contains(lowercased) ?? false)
        }
    }
    
    func filter(by type: PersistedMemoryItem.MemoryItemType?) -> [PersistedMemoryItem] {
        guard let type = type else { return items }
        return items.filter { $0.type == type }
    }
    
    func getItem(by id: UUID) -> PersistedMemoryItem? {
        items.first { $0.id == id }
    }
    
    // MARK: - Persistence
    
    private func saveContext() {
        guard let context = modelContext else { return }
        
        do {
            try context.save()
            log("SwiftData context saved successfully")
        } catch {
            logError("Failed to save SwiftData context: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func buildContextSummary(_ context: ContextPacket?) -> String? {
        guard let context = context else { return nil }
        
        var parts: [String] = []
        
        if !context.calendarItems.isEmpty {
            let names = context.calendarItems.map { $0.title }.joined(separator: ", ")
            parts.append("Calendar: \(names)")
        }
        
        if !context.emailItems.isEmpty {
            let subjects = context.emailItems.map { $0.subject }.joined(separator: ", ")
            parts.append("Email: \(subjects)")
        }
        
        if !context.fileItems.isEmpty {
            let files = context.fileItems.map { $0.name }.joined(separator: ", ")
            parts.append("Files: \(files)")
        }
        
        return parts.isEmpty ? nil : parts.joined(separator: " | ")
    }
    
    private func mapDraftType(_ type: Draft.DraftType) -> PersistedMemoryItem.DraftType {
        switch type {
        case .email: return .email
        case .summary: return .summary
        case .actionItems: return .actionItems
        case .documentReview: return .documentReview
        case .reminder: return .reminder
        }
    }
    
    private func mapExecutionStatus(_ status: ExecutionResultModel.ExecutionStatus) -> PersistedMemoryItem.ExecutionStatus {
        switch status {
        case .success: return .success
        case .partialSuccess: return .partialSuccess
        case .failed: return .failed
        case .savedDraftOnly: return .savedDraftOnly
        }
    }
    
    private func mapSideEffectType(_ type: SideEffect.SideEffectType) -> PersistedSideEffect.SideEffectType {
        switch type {
        case .sendEmail: return .sendEmail
        case .presentEmailDraft: return .sendEmail  // Map to sendEmail for persistence
        case .saveDraft: return .saveDraft
        case .createReminder: return .createReminder
        case .previewReminder: return .previewReminder
        case .previewCalendarEvent: return .previewCalendarEvent
        case .createCalendarEvent: return .createCalendarEvent
        case .updateCalendarEvent: return .updateCalendarEvent
        case .saveToMemory: return .saveToMemory
        }
    }
    
    // MARK: - Demo Data
    
    private func loadDemoData() {
        let calendar = Calendar.current
        
        // Demo item 1
        let item1 = PersistedMemoryItem(
            type: .draftedEmail,
            title: "Follow-Up on Client Meeting",
            preview: "I hope you're doing well. I wanted to follow up on our meeting yesterday regarding the Q3 planning session...",
            createdAt: calendar.date(byAdding: .hour, value: -2, to: Date())!
        )
        item1.intentSummary = "Draft follow-up email for client meeting"
        item1.contextSummary = "Calendar: Client Check-In | Files: Project Roadmap"
        item1.approvalTimestamp = calendar.date(byAdding: .hour, value: -2, to: Date())
        item1.draftType = .email
        item1.draftRecipient = "client@example.com"
        item1.draftSubject = "Follow-Up on Client Meeting"
        item1.draftBody = "I hope you're doing well. I wanted to follow up on our meeting yesterday..."
        item1.draftConfidence = 0.92
        item1.executionStatus = .savedDraftOnly
        item1.executionMessage = "Draft saved successfully"
        item1.attachments = ["Project Roadmap"]
        add(item1)
        
        // Demo item 2
        let item2 = PersistedMemoryItem(
            type: .summary,
            title: "Q3 Planning Meeting Summary",
            preview: "Key decisions: Approved new timeline, allocated additional resources for Phase 2...",
            createdAt: calendar.date(byAdding: .day, value: -1, to: Date())!
        )
        item2.intentSummary = "Summarize Q3 planning meeting"
        item2.contextSummary = "Calendar: Q3 Planning Meeting"
        item2.approvalTimestamp = calendar.date(byAdding: .day, value: -1, to: Date())
        item2.draftType = .summary
        item2.draftConfidence = 0.88
        item2.executionStatus = .success
        add(item2)
        
        // Demo item 3
        let item3 = PersistedMemoryItem(
            type: .actionItems,
            title: "Team Standup Action Items",
            preview: "1. Update project roadmap - Due Friday. 2. Send status update to stakeholders...",
            createdAt: calendar.date(byAdding: .day, value: -2, to: Date())!
        )
        item3.intentSummary = "Extract action items from standup"
        item3.draftType = .actionItems
        item3.draftConfidence = 0.85
        item3.executionStatus = .success
        add(item3)
    }
}

// MARK: - Model Container Provider

/// Provides the SwiftData model container for the app
enum SwiftDataProvider {

    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([PersistedMemoryItem.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        // ATTEMPT 1: Normal persistent storage
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch let primaryError {
            logError("SwiftDataProvider: Persistent storage failed: \(primaryError)", category: .storageFailure)

            // ATTEMPT 2: In-memory fallback
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch let fallbackError {
                logError("CRITICAL: SwiftData container failed. Attempting store reset.", category: .storageFailure)
                logError("In-memory error: \(fallbackError)", category: .storageFailure)

                // ATTEMPT 3: Delete corrupted store and recreate
                deleteCorruptedSwiftDataStore()

                do {
                    return try ModelContainer(for: schema, configurations: [modelConfiguration])
                } catch let resetError {
                    logError("UNRECOVERABLE: Store reset failed: \(resetError)", category: .storageFailure)
                    fatalError("UNRECOVERABLE: SwiftData container could not be recreated after reset. Error: \(resetError)")
                }
            }
        }
    }()

    /// Deletes corrupted SwiftData store files safely
    private static func deleteCorruptedSwiftDataStore() {
        let fileManager = FileManager.default

        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logError("Could not locate Application Support directory", category: .storageFailure)
            return
        }

        let storeExtensions = [".sqlite", ".sqlite-shm", ".sqlite-wal"]
        let storePrefix = "default.store" // SwiftData default store name

        do {
            let contents = try fileManager.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil)
            for file in contents {
                let filename = file.lastPathComponent
                // Only delete SwiftData store files
                if filename.hasPrefix(storePrefix) || storeExtensions.contains(where: { filename.hasSuffix($0) }) {
                    do {
                        try fileManager.removeItem(at: file)
                        log("Deleted corrupted store file: \(filename)")
                    } catch {
                        logError("Failed to delete \(filename): \(error)", category: .storageFailure)
                    }
                }
            }
        } catch {
            logError("Failed to enumerate Application Support: \(error)", category: .storageFailure)
        }
    }
}
