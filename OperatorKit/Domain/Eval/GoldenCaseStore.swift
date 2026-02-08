import Foundation

// ============================================================================
// GOLDEN CASE STORE (Phase 8B)
//
// Local-only storage for golden cases.
// INVARIANT: No network transmission
// INVARIANT: User can delete at any time
// INVARIANT: Duplicate prevention by memoryItemId
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Local store for golden cases
public final class GoldenCaseStore: ObservableObject {
    
    public static let shared = GoldenCaseStore()
    
    private let storageKey = "com.operatorkit.goldenCases"
    private let defaults: UserDefaults
    
    @Published public private(set) var cases: [GoldenCase] = []
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadCases()
    }
    
    // MARK: - CRUD Operations
    
    /// Adds a new golden case
    /// INVARIANT: Prevents duplicates by memoryItemId unless explicitly allowed
    public func addCase(_ goldenCase: GoldenCase, allowDuplicate: Bool = false) -> Result<Void, GoldenCaseStoreError> {
        // Check for duplicate by memoryItemId
        if !allowDuplicate && cases.contains(where: { $0.memoryItemId == goldenCase.memoryItemId }) {
            return .failure(.duplicateMemoryItem)
        }
        
        // Check for duplicate by ID
        if cases.contains(where: { $0.id == goldenCase.id }) {
            return .failure(.duplicateId)
        }
        
        cases.append(goldenCase)
        saveCases()
        
        logDebug("Added golden case \(goldenCase.id) from memory item \(goldenCase.memoryItemId)", category: .audit)
        
        return .success(())
    }
    
    /// Renames a golden case
    public func renameCase(id: UUID, newTitle: String) -> Result<Void, GoldenCaseStoreError> {
        guard let index = cases.firstIndex(where: { $0.id == id }) else {
            return .failure(.caseNotFound)
        }
        
        cases[index].rename(newTitle)
        saveCases()
        
        logDebug("Renamed golden case \(id)", category: .audit)
        
        return .success(())
    }
    
    /// Deletes a single golden case
    public func deleteCase(id: UUID) -> Result<Void, GoldenCaseStoreError> {
        guard let index = cases.firstIndex(where: { $0.id == id }) else {
            return .failure(.caseNotFound)
        }
        
        cases.remove(at: index)
        saveCases()
        
        logDebug("Deleted golden case \(id)", category: .audit)
        
        return .success(())
    }
    
    /// Deletes all golden cases
    public func deleteAllCases() {
        cases.removeAll()
        saveCases()
        
        logDebug("Deleted all golden cases", category: .audit)
    }
    
    /// Gets a golden case by ID
    public func getCase(id: UUID) -> GoldenCase? {
        cases.first { $0.id == id }
    }
    
    /// Checks if a memory item is already pinned
    public func isPinned(memoryItemId: UUID) -> Bool {
        cases.contains { $0.memoryItemId == memoryItemId }
    }
    
    /// Gets the golden case for a memory item
    public func getCase(forMemoryItemId memoryItemId: UUID) -> GoldenCase? {
        cases.first { $0.memoryItemId == memoryItemId }
    }
    
    // MARK: - Export
    
    /// Exports all golden cases as JSON
    public func exportAsJSON() throws -> Data {
        let export = GoldenCaseExport(cases: cases)
        return try export.toJSON()
    }
    
    /// Exports as a file URL for sharing
    public func exportToFile() throws -> URL {
        let data = try exportAsJSON()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: Date())
        
        let fileName = "operatorkit-golden-cases-\(timestamp).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try data.write(to: tempURL)
        return tempURL
    }
    
    // MARK: - Statistics
    
    public var totalCount: Int {
        cases.count
    }
    
    public func countByBackend(_ backend: String) -> Int {
        cases.filter { $0.snapshot.backendUsed == backend }.count
    }
    
    public func countByConfidenceBand(_ band: String) -> Int {
        cases.filter { $0.snapshot.confidenceBand == band }.count
    }
    
    // MARK: - Persistence
    
    private func loadCases() {
        guard let data = defaults.data(forKey: storageKey) else {
            cases = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            cases = try decoder.decode([GoldenCase].self, from: data)
        } catch {
            logError("Failed to load golden cases: \(error)", category: .audit)
            cases = []
        }
    }
    
    private func saveCases() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cases)
            defaults.set(data, forKey: storageKey)
        } catch {
            logError("Failed to save golden cases: \(error)", category: .audit)
        }
    }
    
    // MARK: - Error Types
    
    public enum GoldenCaseStoreError: Error, LocalizedError, Equatable {
        case duplicateMemoryItem
        case duplicateId
        case caseNotFound
        case exportFailed
        
        public var errorDescription: String? {
            switch self {
            case .duplicateMemoryItem:
                return "This memory item is already pinned as a golden case"
            case .duplicateId:
                return "Golden case ID already exists"
            case .caseNotFound:
                return "Golden case not found"
            case .exportFailed:
                return "Failed to export golden cases"
            }
        }
    }
}

// MARK: - Factory Method

extension GoldenCaseStore {
    
    /// Creates a golden case from a memory item
    /// INVARIANT: Extracts metadata only, never raw content
    func createGoldenCase(
        from memoryItem: PersistedMemoryItem,
        title: String? = nil
    ) -> GoldenCase {
        let snapshot = GoldenCaseSnapshot.from(memoryItem: memoryItem)
        
        // Generate default title from metadata
        let defaultTitle = "\(memoryItem.type.rawValue) - \(snapshot.contextCounts.summary)"
        
        return GoldenCase(
            id: UUID(),
            createdAt: Date(),
            title: title ?? String(defaultTitle.prefix(GoldenCase.maxTitleLength)),
            source: .memoryItem,
            memoryItemId: memoryItem.id,
            snapshot: snapshot
        )
    }
}
