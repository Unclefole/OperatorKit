import Foundation

// ============================================================================
// PROCEDURE STORE (Phase 13B)
//
// Local-only storage for procedure templates.
// No syncing, no network, no background operations.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking
// ❌ No background sync
// ❌ No cloud storage
// ❌ No sharing outside device
// ✅ Local UserDefaults only
// ✅ Max count enforced
// ✅ CRUD requires explicit confirmation
// ============================================================================

@MainActor
public final class ProcedureStore: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = ProcedureStore()
    
    // MARK: - Configuration
    
    public static let maxProcedureCount = 50
    private static let storageKey = "com.operatorkit.procedures.v1"
    
    // MARK: - State
    
    @Published public private(set) var procedures: [ProcedureTemplate] = []
    
    // MARK: - Init
    
    private init() {
        load()
    }
    
    // MARK: - Load
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else {
            procedures = []
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([ProcedureTemplate].self, from: data)
            procedures = decoded
        } catch {
            procedures = []
        }
    }
    
    // MARK: - Save
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(procedures)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            // Silent fail - local storage only
        }
    }
    
    // MARK: - CRUD Operations (All Require Explicit Confirmation)
    
    /// Add a procedure (requires confirmation via return of confirmation token)
    public func add(_ procedure: ProcedureTemplate, confirmed: Bool) -> AddResult {
        guard ProcedureSharingFeatureFlag.isEnabled else {
            return .failure("Procedure sharing is not enabled")
        }
        
        guard confirmed else {
            return .requiresConfirmation
        }
        
        // Validate
        let validation = ProcedureTemplateValidator.validate(procedure)
        guard validation.isValid else {
            return .failure("Validation failed: \(validation.errors.joined(separator: ", "))")
        }
        
        // Check max count
        guard procedures.count < Self.maxProcedureCount else {
            return .failure("Maximum procedure count (\(Self.maxProcedureCount)) reached")
        }
        
        // Check for duplicate
        if procedures.contains(where: { $0.id == procedure.id }) {
            return .failure("Procedure with this ID already exists")
        }
        
        // Runtime assertion: no user content
        procedure.intentSkeleton.assertNoUserContent()
        
        procedures.append(procedure)
        save()
        
        return .success
    }
    
    /// Remove a procedure by ID (requires confirmation)
    public func remove(id: UUID, confirmed: Bool) -> RemoveResult {
        guard ProcedureSharingFeatureFlag.isEnabled else {
            return .failure("Procedure sharing is not enabled")
        }
        
        guard confirmed else {
            return .requiresConfirmation
        }
        
        guard let index = procedures.firstIndex(where: { $0.id == id }) else {
            return .failure("Procedure not found")
        }
        
        procedures.remove(at: index)
        save()
        
        return .success
    }
    
    /// Get procedure by ID
    public func get(id: UUID) -> ProcedureTemplate? {
        procedures.first { $0.id == id }
    }
    
    /// Get all procedures in a category
    public func procedures(in category: ProcedureCategory) -> [ProcedureTemplate] {
        procedures.filter { $0.category == category }
    }
    
    /// Clear all procedures (requires confirmation)
    public func clearAll(confirmed: Bool) -> ClearResult {
        guard ProcedureSharingFeatureFlag.isEnabled else {
            return .failure("Procedure sharing is not enabled")
        }
        
        guard confirmed else {
            return .requiresConfirmation
        }
        
        procedures.removeAll()
        save()
        
        return .success
    }
    
    // MARK: - Result Types
    
    public enum AddResult {
        case success
        case requiresConfirmation
        case failure(String)
    }
    
    public enum RemoveResult {
        case success
        case requiresConfirmation
        case failure(String)
    }
    
    public enum ClearResult {
        case success
        case requiresConfirmation
        case failure(String)
    }
    
    // MARK: - Stats
    
    public var count: Int { procedures.count }
    public var remainingCapacity: Int { max(0, Self.maxProcedureCount - procedures.count) }
    public var isAtCapacity: Bool { procedures.count >= Self.maxProcedureCount }
}
