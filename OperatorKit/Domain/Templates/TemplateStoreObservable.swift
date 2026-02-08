import Foundation
import SwiftUI

// ============================================================================
// TEMPLATE STORE OBSERVABLE
//
// @MainActor ObservableObject wrapper for SwiftUI integration.
//
// - Bridges TemplateStoreActor to SwiftUI's @Published property wrappers
// - All UI updates happen on MainActor
// - Provides loading state for UI feedback
// - Exposes errors for user-facing alerts
//
// USAGE:
// @StateObject private var templateStore = TemplateStoreObservable.shared
// or
// @EnvironmentObject var templateStore: TemplateStoreObservable
// ============================================================================

@MainActor
final class TemplateStoreObservable: ObservableObject {

    // MARK: - Singleton

    static let shared = TemplateStoreObservable()

    // MARK: - Published State

    /// All custom templates, sorted by creation date (newest first)
    @Published private(set) var templates: [CustomWorkflowTemplate] = []

    /// Loading indicator for UI spinners
    @Published private(set) var isLoading: Bool = false

    /// Most recent error (cleared on next successful operation)
    @Published private(set) var lastError: Error?

    /// True if initial load has completed (successful or not)
    @Published private(set) var hasLoaded: Bool = false

    // MARK: - Computed Properties

    /// Number of custom templates
    var templateCount: Int { templates.count }

    /// True if there are no custom templates
    var isEmpty: Bool { templates.isEmpty }

    // MARK: - Initialization

    private init() {}

    // MARK: - Load

    /// Load templates from disk. Call this on view appearance.
    func load() async {
        guard !isLoading else { return }

        isLoading = true
        lastError = nil
        debugLog("📥 Loading templates...")

        do {
            let loaded = try await TemplateStoreActor.shared.loadTemplates()
            templates = loaded.sorted { $0.createdAt > $1.createdAt }
            hasLoaded = true
            debugLog("✅ Loaded \(templates.count) templates")
        } catch {
            lastError = error
            hasLoaded = true
            debugLog("❌ Load failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Force refresh from disk
    func refresh() async {
        isLoading = true
        lastError = nil

        do {
            let loaded = try await TemplateStoreActor.shared.refresh()
            templates = loaded.sorted { $0.createdAt > $1.createdAt }
        } catch {
            lastError = error
        }

        isLoading = false
    }

    // MARK: - Add

    /// Add a new template. Returns true on success.
    @discardableResult
    func add(_ template: CustomWorkflowTemplate) async -> Bool {
        lastError = nil
        debugLog("➕ Adding template: \(template.name)")

        do {
            try await TemplateStoreActor.shared.save(template)
            debugLog("✅ Template saved to actor")
            // Reload to sync cache
            let loaded = try await TemplateStoreActor.shared.loadTemplates()
            templates = loaded.sorted { $0.createdAt > $1.createdAt }
            debugLog("✅ Template count: \(templates.count)")
            return true
        } catch {
            lastError = error
            debugLog("❌ Add failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Update

    /// Update an existing template. Returns true on success.
    @discardableResult
    func update(_ template: CustomWorkflowTemplate) async -> Bool {
        lastError = nil

        do {
            try await TemplateStoreActor.shared.save(template)
            let loaded = try await TemplateStoreActor.shared.loadTemplates()
            templates = loaded.sorted { $0.createdAt > $1.createdAt }
            return true
        } catch {
            lastError = error
            return false
        }
    }

    // MARK: - Delete

    /// Delete a template by ID. Returns true on success.
    @discardableResult
    func delete(_ templateId: UUID) async -> Bool {
        lastError = nil

        do {
            try await TemplateStoreActor.shared.delete(templateId)
            let loaded = try await TemplateStoreActor.shared.loadTemplates()
            templates = loaded.sorted { $0.createdAt > $1.createdAt }
            return true
        } catch {
            lastError = error
            return false
        }
    }

    /// Delete multiple templates. Returns true on success.
    @discardableResult
    func deleteMultiple(_ templateIds: Set<UUID>) async -> Bool {
        lastError = nil

        do {
            try await TemplateStoreActor.shared.deleteMultiple(templateIds)
            let loaded = try await TemplateStoreActor.shared.loadTemplates()
            templates = loaded.sorted { $0.createdAt > $1.createdAt }
            return true
        } catch {
            lastError = error
            return false
        }
    }

    // MARK: - Lookup

    /// Find a template by ID
    func template(for id: UUID) -> CustomWorkflowTemplate? {
        templates.first { $0.id == id }
    }

    // MARK: - Error Handling

    /// Clear the last error
    func clearError() {
        lastError = nil
    }

    // MARK: - Debug Logging

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[TemplateStoreObservable] \(message)")
        #endif
    }
}

// MARK: - Environment Key

/// Environment key for injecting TemplateStoreObservable
private struct TemplateStoreKey: EnvironmentKey {
    static let defaultValue: TemplateStoreObservable = .shared
}

extension EnvironmentValues {
    var templateStore: TemplateStoreObservable {
        get { self[TemplateStoreKey.self] }
        set { self[TemplateStoreKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Inject TemplateStoreObservable as environment object
    func withTemplateStore(_ store: TemplateStoreObservable = .shared) -> some View {
        self.environmentObject(store)
    }
}
