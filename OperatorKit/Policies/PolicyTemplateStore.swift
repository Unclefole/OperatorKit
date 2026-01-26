import Foundation

// ============================================================================
// POLICY TEMPLATE STORE (Phase 10M)
//
// Local-only storage for policy templates.
// Ships with 4 conservative default templates.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking
// ❌ No user content
// ✅ Local-only (UserDefaults)
// ✅ Conservative defaults
// ✅ User-initiated apply with confirmation
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

@MainActor
public final class PolicyTemplateStore: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = PolicyTemplateStore()
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let storageKey = "com.operatorkit.policy.templates"
    
    // MARK: - State
    
    @Published public private(set) var templates: [PolicyTemplate]
    
    // MARK: - Default Templates
    
    public static let defaultTemplates: [PolicyTemplate] = [
        PolicyTemplate(
            id: "template-conservative",
            name: "Conservative",
            templateDescription: "Most restrictive settings. Email drafts only, no calendar or task writes. 25 executions/day limit. Recommended for initial rollout.",
            policyPayload: .conservative()
        ),
        PolicyTemplate(
            id: "template-standard",
            name: "Standard",
            templateDescription: "Balanced settings for typical use. All features enabled with reasonable limits. 100 executions/day, 50 memory items.",
            policyPayload: .standard()
        ),
        PolicyTemplate(
            id: "template-privacy-first",
            name: "Privacy First",
            templateDescription: "Maximum privacy settings. All features but strictly local processing only. No sync capability.",
            policyPayload: PolicyPayload(
                allowEmailDrafts: true,
                allowCalendarWrites: true,
                allowTaskCreation: true,
                allowMemoryWrites: true,
                maxExecutionsPerDay: 50,
                maxMemoryItems: 25,
                requireExplicitConfirmation: true,
                localProcessingOnly: true
            )
        ),
        PolicyTemplate(
            id: "template-read-only",
            name: "Read Only",
            templateDescription: "No write operations allowed. Useful for evaluation period. Only email drafts (which don't auto-send).",
            policyPayload: PolicyPayload(
                allowEmailDrafts: true,
                allowCalendarWrites: false,
                allowTaskCreation: false,
                allowMemoryWrites: false,
                maxExecutionsPerDay: 10,
                maxMemoryItems: 5,
                requireExplicitConfirmation: true,
                localProcessingOnly: true
            )
        )
    ]
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        
        // Load custom templates or use defaults
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([PolicyTemplate].self, from: data) {
            self.templates = Self.defaultTemplates + saved.filter { custom in
                !Self.defaultTemplates.contains(where: { $0.id == custom.id })
            }
        } else {
            self.templates = Self.defaultTemplates
        }
    }
    
    // MARK: - Public API
    
    /// Gets a template by ID
    public func template(byId id: String) -> PolicyTemplate? {
        templates.first { $0.id == id }
    }
    
    /// Adds a custom template
    public func addTemplate(_ template: PolicyTemplate) {
        guard !templates.contains(where: { $0.id == template.id }) else { return }
        templates.append(template)
        saveCustomTemplates()
    }
    
    /// Removes a custom template (cannot remove defaults)
    public func removeTemplate(id: String) {
        guard !Self.defaultTemplates.contains(where: { $0.id == id }) else { return }
        templates.removeAll { $0.id == id }
        saveCustomTemplates()
    }
    
    /// Resets to default templates only
    public func resetToDefaults() {
        templates = Self.defaultTemplates
        defaults.removeObject(forKey: storageKey)
    }
    
    // MARK: - Apply Template
    
    /// Applies a template to the current policy
    /// REQUIRES: User confirmation before calling
    /// NOTE: Does NOT affect execution engine (policy is UI boundary only)
    public func applyTemplate(
        _ template: PolicyTemplate,
        to policyStore: OperatorPolicyStore
    ) {
        let policy = template.toOperatorPolicy()
        policyStore.updatePolicy(policy)
        
        logDebug("Policy template applied: \(template.name)", category: .policy)
    }
    
    // MARK: - Private
    
    private func saveCustomTemplates() {
        let customTemplates = templates.filter { template in
            !Self.defaultTemplates.contains(where: { $0.id == template.id })
        }
        
        if let data = try? JSONEncoder().encode(customTemplates) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
