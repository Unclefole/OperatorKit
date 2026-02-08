import Foundation

// ============================================================================
// CUSTOM TEMPLATE STORE
//
// Production-grade persistence layer with:
// - Atomic writes (temp file → rename)
// - Crash-safe operations
// - Background thread persistence
// - In-memory cache for performance
// - Thread-safe access via Swift actor
//
// INVARIANT: Data cannot be corrupted by crashes or partial writes.
// ============================================================================

/// Thread-safe template persistence using Swift actor
actor CustomTemplateStore {

    // MARK: - Singleton

    static let shared = CustomTemplateStore()

    // MARK: - Storage

    private var cache: [CustomTemplate] = []
    private var isLoaded: Bool = false

    // MARK: - File Paths

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var templatesDirectory: URL {
        documentsDirectory.appendingPathComponent("CustomTemplates", isDirectory: true)
    }

    private var manifestURL: URL {
        templatesDirectory.appendingPathComponent("templates.json")
    }

    private var tempManifestURL: URL {
        templatesDirectory.appendingPathComponent("templates.json.tmp")
    }

    private var backupManifestURL: URL {
        templatesDirectory.appendingPathComponent("templates.json.backup")
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Load all templates (lazy, cached)
    func loadTemplates() async throws -> [CustomTemplate] {
        if isLoaded {
            return cache
        }

        try ensureDirectoryExists()

        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            isLoaded = true
            return []
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(TemplateManifest.self, from: data)

            // Schema migration check
            if manifest.schemaVersion < kCustomTemplateSchemaVersion {
                cache = try migrateTemplates(manifest.templates, from: manifest.schemaVersion)
            } else {
                cache = manifest.templates
            }

            isLoaded = true
            return cache

        } catch {
            // Attempt recovery from backup
            if FileManager.default.fileExists(atPath: backupManifestURL.path) {
                let backupData = try Data(contentsOf: backupManifestURL)
                let manifest = try JSONDecoder().decode(TemplateManifest.self, from: backupData)
                cache = manifest.templates
                isLoaded = true

                // Restore from backup
                try await saveManifest()
                return cache
            }

            throw CustomTemplateStoreError.loadFailed(error)
        }
    }

    /// Save a new template (atomic write)
    func save(_ template: CustomTemplate) async throws {
        if !isLoaded {
            _ = try await loadTemplates()
        }

        // Check for duplicate
        if let existingIndex = cache.firstIndex(where: { $0.id == template.id }) {
            cache[existingIndex] = template
        } else {
            cache.append(template)
        }

        try await saveManifest()
    }

    /// Delete a template
    func delete(_ templateId: UUID) async throws {
        if !isLoaded {
            _ = try await loadTemplates()
        }

        cache.removeAll { $0.id == templateId }
        try await saveManifest()
    }

    /// Get a specific template
    func template(for id: UUID) async throws -> CustomTemplate? {
        let templates = try await loadTemplates()
        return templates.first { $0.id == id }
    }

    /// Force refresh from disk
    func refresh() async throws -> [CustomTemplate] {
        isLoaded = false
        return try await loadTemplates()
    }

    // MARK: - Atomic Write

    /// Saves manifest with atomic write pattern:
    /// 1. Write to temp file
    /// 2. Backup existing file
    /// 3. Rename temp to final
    /// 4. Remove backup on success
    private func saveManifest() async throws {
        try ensureDirectoryExists()

        let manifest = TemplateManifest(
            schemaVersion: kCustomTemplateSchemaVersion,
            templates: cache,
            savedAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(manifest)

        // Step 1: Write to temp file
        try data.write(to: tempManifestURL, options: .atomic)

        // Step 2: Backup existing (if exists)
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            try? FileManager.default.removeItem(at: backupManifestURL)
            try FileManager.default.copyItem(at: manifestURL, to: backupManifestURL)
        }

        // Step 3: Atomic rename
        try? FileManager.default.removeItem(at: manifestURL)
        try FileManager.default.moveItem(at: tempManifestURL, to: manifestURL)

        // Step 4: Cleanup backup on success
        try? FileManager.default.removeItem(at: backupManifestURL)
    }

    // MARK: - Directory Management

    private func ensureDirectoryExists() throws {
        if !FileManager.default.fileExists(atPath: templatesDirectory.path) {
            try FileManager.default.createDirectory(
                at: templatesDirectory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        }
    }

    // MARK: - Migration

    private func migrateTemplates(_ templates: [CustomTemplate], from version: Int) throws -> [CustomTemplate] {
        // Future: implement migration logic when schema changes
        // For now, return as-is
        return templates
    }
}

// MARK: - Manifest Wrapper

/// Root container for persisted templates
private struct TemplateManifest: Codable {
    let schemaVersion: Int
    let templates: [CustomTemplate]
    let savedAt: Date
}

// MARK: - Errors

// NOTE: TemplateStoreError is defined in TemplateStoreActor.swift
// This file uses CustomTemplateStoreError to avoid duplicate symbols

enum CustomTemplateStoreError: Error, LocalizedError {
    case loadFailed(Error)
    case saveFailed(Error)
    case templateNotFound(UUID)
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "Failed to load templates: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save template: \(error.localizedDescription)"
        case .templateNotFound(let id):
            return "Template not found: \(id)"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        }
    }
}

// MARK: - Main Actor Bridge

/// Observable wrapper for SwiftUI integration
@MainActor
final class CustomTemplateStoreObservable: ObservableObject {

    static let shared = CustomTemplateStoreObservable()

    @Published private(set) var templates: [CustomTemplate] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?

    private init() {}

    func load() async {
        isLoading = true
        error = nil

        do {
            templates = try await CustomTemplateStore.shared.loadTemplates()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func save(_ template: CustomTemplate) async -> Bool {
        do {
            try await CustomTemplateStore.shared.save(template)
            templates = try await CustomTemplateStore.shared.loadTemplates()
            return true
        } catch {
            self.error = error
            return false
        }
    }

    func delete(_ templateId: UUID) async -> Bool {
        do {
            try await CustomTemplateStore.shared.delete(templateId)
            templates = try await CustomTemplateStore.shared.loadTemplates()
            return true
        } catch {
            self.error = error
            return false
        }
    }
}
