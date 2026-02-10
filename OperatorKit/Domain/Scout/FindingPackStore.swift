import Foundation

// ============================================================================
// FINDING PACK STORE — Persistent Local Storage for Scout Findings
//
// INVARIANT: Read/write of FindingPacks only. No execution references.
// ============================================================================

@MainActor
public final class FindingPackStore: ObservableObject {

    public static let shared = FindingPackStore()

    @Published private(set) var packs: [FindingPack] = []

    private let storageURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = docs.appendingPathComponent("ScoutFindings.json")
        loadPacks()
    }

    public func save(_ pack: FindingPack) {
        packs.insert(pack, at: 0)
        // Keep last 50
        if packs.count > 50 { packs = Array(packs.prefix(50)) }
        persist()
    }

    public func latest(count: Int = 10) -> [FindingPack] {
        Array(packs.prefix(count))
    }

    public func findingPack(by id: UUID) -> FindingPack? {
        packs.first { $0.id == id }
    }

    public func clear() {
        packs = []
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(packs) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func loadPacks() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        packs = (try? decoder.decode([FindingPack].self, from: data)) ?? []
    }
}
