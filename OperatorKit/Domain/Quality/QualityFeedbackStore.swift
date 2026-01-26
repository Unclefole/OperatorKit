import Foundation

// ============================================================================
// QUALITY FEEDBACK STORE (Phase 8A)
//
// Local-only, append-only storage for quality feedback.
// INVARIANT: No network transmission
// INVARIANT: Append-only (new records, no mutation)
// INVARIANT: User can delete their own feedback
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Local store for quality feedback entries
/// Uses UserDefaults for simplicity; could migrate to SwiftData if needed
public final class QualityFeedbackStore: ObservableObject {
    
    public static let shared = QualityFeedbackStore()
    
    private let storageKey = "com.operatorkit.qualityFeedback"
    private let defaults: UserDefaults
    
    @Published public private(set) var entries: [QualityFeedbackEntry] = []
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadEntries()
    }
    
    // MARK: - CRUD Operations
    
    /// Adds a new feedback entry (append-only)
    /// INVARIANT: Validates no raw content before storing
    public func addFeedback(_ entry: QualityFeedbackEntry) -> Result<Void, FeedbackStoreError> {
        // Validate no raw content
        guard entry.validateNoRawContent() else {
            return .failure(.rawContentDetected)
        }
        
        // Check for duplicate
        if entries.contains(where: { $0.id == entry.id }) {
            return .failure(.duplicateEntry)
        }
        
        // Append-only: add new entry
        entries.append(entry)
        saveEntries()
        
        logDebug("Added feedback entry \(entry.id) for memory item \(entry.memoryItemId)", category: .audit)
        
        return .success(())
    }
    
    /// Gets feedback for a specific memory item
    public func getFeedback(for memoryItemId: UUID) -> QualityFeedbackEntry? {
        entries.first { $0.memoryItemId == memoryItemId }
    }
    
    /// Checks if feedback exists for a memory item
    public func hasFeedback(for memoryItemId: UUID) -> Bool {
        entries.contains { $0.memoryItemId == memoryItemId }
    }
    
    /// Deletes a single feedback entry
    /// INVARIANT: User-initiated only
    public func deleteFeedback(id: UUID) -> Result<Void, FeedbackStoreError> {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return .failure(.entryNotFound)
        }
        
        entries.remove(at: index)
        saveEntries()
        
        logDebug("Deleted feedback entry \(id)", category: .audit)
        
        return .success(())
    }
    
    /// Deletes all feedback entries
    /// INVARIANT: User-initiated only, requires confirmation in UI
    public func deleteAllFeedback() {
        entries.removeAll()
        saveEntries()
        
        logDebug("Deleted all feedback entries", category: .audit)
    }
    
    // MARK: - Export
    
    /// Exports all feedback as JSON
    /// INVARIANT: Export format excludes raw user content
    public func exportAsJSON() throws -> Data {
        let export = QualityFeedbackExport(entries: entries)
        return try export.toJSON()
    }
    
    /// Exports as a file URL for sharing
    public func exportToFile() throws -> URL {
        let data = try exportAsJSON()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: Date())
        
        let fileName = "operatorkit-feedback-\(timestamp).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try data.write(to: tempURL)
        return tempURL
    }
    
    // MARK: - Statistics
    
    /// Total number of feedback entries
    public var totalCount: Int {
        entries.count
    }
    
    /// Feedback entries by rating
    public func count(for rating: QualityRating) -> Int {
        entries.filter { $0.rating == rating }.count
    }
    
    /// Feedback entries by backend
    public func count(forBackend backend: String) -> Int {
        entries.filter { $0.modelBackend == backend }.count
    }
    
    /// Feedback entries in confidence band
    public func count(inConfidenceBand lower: Double, upper: Double) -> Int {
        entries.filter { entry in
            guard let confidence = entry.confidence else { return false }
            return confidence >= lower && confidence < upper
        }.count
    }
    
    // MARK: - Persistence
    
    private func loadEntries() {
        guard let data = defaults.data(forKey: storageKey) else {
            entries = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([QualityFeedbackEntry].self, from: data)
        } catch {
            logError("Failed to load feedback entries: \(error)", category: .audit)
            entries = []
        }
    }
    
    private func saveEntries() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            defaults.set(data, forKey: storageKey)
        } catch {
            logError("Failed to save feedback entries: \(error)", category: .audit)
        }
    }
    
    // MARK: - Error Types
    
    public enum FeedbackStoreError: Error, LocalizedError {
        case rawContentDetected
        case duplicateEntry
        case entryNotFound
        case exportFailed
        
        public var errorDescription: String? {
            switch self {
            case .rawContentDetected:
                return "Feedback cannot contain personal information"
            case .duplicateEntry:
                return "Feedback already exists for this item"
            case .entryNotFound:
                return "Feedback entry not found"
            case .exportFailed:
                return "Failed to export feedback"
            }
        }
    }
}

// MARK: - Factory Method for Creating Feedback

extension QualityFeedbackStore {
    
    /// Creates a feedback entry from a memory item with metadata
    /// INVARIANT: Captures only metadata, not content
    public func createFeedbackEntry(
        for memoryItemId: UUID,
        rating: QualityRating,
        issueTags: [QualityIssueTag] = [],
        optionalNote: String? = nil,
        modelBackend: String? = nil,
        confidence: Double? = nil,
        usedFallback: Bool = false,
        timeoutOccurred: Bool = false,
        validationPass: Bool? = nil,
        citationValidityPass: Bool? = nil
    ) -> QualityFeedbackEntry {
        QualityFeedbackEntry(
            id: UUID(),
            memoryItemId: memoryItemId,
            rating: rating,
            issueTags: issueTags,
            optionalNote: optionalNote,
            createdAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            modelBackend: modelBackend,
            confidence: confidence,
            usedFallback: usedFallback,
            timeoutOccurred: timeoutOccurred,
            validationPass: validationPass,
            citationValidityPass: citationValidityPass
        )
    }
}
