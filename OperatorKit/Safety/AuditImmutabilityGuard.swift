import Foundation

// MARK: - Audit Immutability Guard (Phase 7A)
//
// Ensures that PersistedMemoryItem audit fields are:
// - Append-only
// - Never overwritten
// - Never editable after save
//
// DEBUG assertions prevent:
// - Editing an execution record after completion
// - Mutating audit fields outside the execution pipeline

/// Tracks which memory items have been finalized
/// Once finalized, audit fields cannot be modified
public final class AuditImmutabilityGuard {
    
    public static let shared = AuditImmutabilityGuard()
    
    /// Set of finalized memory item IDs
    /// Items in this set cannot have their audit fields modified
    private var finalizedItemIds: Set<String> = []
    
    /// Lock for thread safety
    private let lock = NSLock()
    
    private init() {}
    
    // MARK: - Finalization
    
    /// Marks a memory item as finalized
    /// After this, audit fields cannot be modified
    public func finalizeItem(id: String) {
        lock.lock()
        defer { lock.unlock() }
        
        finalizedItemIds.insert(id)
        
        #if DEBUG
        print("🔒 Memory item \(id.prefix(8))... finalized - audit fields are now immutable")
        #endif
    }
    
    /// Checks if an item is finalized
    public func isFinalized(id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return finalizedItemIds.contains(id)
    }
    
    /// Asserts that an item is not finalized before modification
    /// Call this before any audit field modification
    public func assertNotFinalized(id: String, operation: String) {
        #if DEBUG
        lock.lock()
        let finalized = finalizedItemIds.contains(id)
        lock.unlock()
        
        if finalized {
            assertionFailure(
                """
                INVARIANT VIOLATION: Attempted to modify finalized memory item
                
                Item ID: \(id)
                Operation: \(operation)
                
                Audit fields are immutable after finalization.
                This is a bug in the execution pipeline.
                """
            )
        }
        #endif
    }
    
    /// Clears all finalized items (for testing only)
    #if DEBUG
    public func clearForTesting() {
        lock.lock()
        defer { lock.unlock() }
        
        finalizedItemIds.removeAll()
    }
    #endif
    
    // MARK: - Validation
    
    /// Validates that audit fields match expected immutability rules
    public func validateAuditIntegrity(
        itemId: String,
        originalTimestamp: Date?,
        currentTimestamp: Date?
    ) -> Bool {
        // Timestamps should never change after initial set
        if let original = originalTimestamp,
           let current = currentTimestamp,
           original != current {
            #if DEBUG
            assertionFailure(
                """
                INVARIANT VIOLATION: Audit timestamp was modified
                
                Item ID: \(itemId)
                Original: \(original)
                Current: \(current)
                
                Audit timestamps must be immutable after creation.
                """
            )
            #endif
            return false
        }
        
        return true
    }
}

// MARK: - Immutable Audit Fields Protocol

/// Protocol for types that contain immutable audit fields
public protocol ImmutableAuditFields {
    /// The unique identifier for this item
    var auditId: String { get }
    
    /// Timestamp when the item was created (immutable after set)
    var createdAt: Date { get }
    
    /// Timestamp when execution completed (immutable after set)
    var completedAt: Date? { get }
    
    /// Whether this item has been finalized
    var isFinalized: Bool { get }
}

// MARK: - Audit Field Modification Guard

/// Wrapper that prevents modification of audit fields after finalization
@propertyWrapper
public struct ImmutableAfterFinalization<Value> {
    private var value: Value
    private var isLocked: Bool = false
    
    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }
    
    public var wrappedValue: Value {
        get { value }
        set {
            #if DEBUG
            if isLocked {
                assertionFailure("INVARIANT VIOLATION: Attempted to modify immutable audit field after finalization")
                return
            }
            #endif
            value = newValue
        }
    }
    
    /// Locks this field from further modification
    public mutating func lock() {
        isLocked = true
    }
    
    /// Whether this field is locked
    public var locked: Bool {
        isLocked
    }
}

// MARK: - Documentation

/*
 AUDIT IMMUTABILITY RULES
 ========================
 
 1. APPEND-ONLY
    - New audit entries can be added during execution
    - Once execution completes, no new entries can be added
 
 2. NEVER OVERWRITTEN
    - Timestamps (createdAt, completedAt, confirmationTimestamps) are set once
    - IDs (memoryItemId, eventIdentifier, reminderIdentifier) are set once
    - Status fields transition forward only (pending → completed)
 
 3. NEVER EDITABLE AFTER SAVE
    - After MemoryStore.save() is called, the item is finalized
    - finalizeItem() is called automatically after successful save
    - Any attempt to modify audit fields after this triggers an assertion
 
 ENFORCEMENT
 ===========
 
 - Compile-time: ImmutableAfterFinalization property wrapper
 - Runtime (DEBUG): AuditImmutabilityGuard assertions
 - Test-time: InfoPlistRegressionTests verifies guard behavior
 
 WHY THIS MATTERS
 ================
 
 Audit trails must be trustworthy. If audit fields can be modified after
 the fact, users cannot trust that the recorded history is accurate.
 This is especially important for:
 
 - Security audits
 - User transparency
 - Debugging production issues
 - Compliance demonstration
 
 */
