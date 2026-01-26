import Foundation

// ============================================================================
// QUALITY HISTORY STORE (Phase 9A)
//
// Stores aggregated quality summaries over time for trend analysis.
// Contains NO per-case details, NO user content.
//
// INVARIANT: Metadata-only aggregates
// INVARIANT: Local-only storage
// INVARIANT: Safe for export
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Daily quality summary (aggregate, no content)
public struct DailyQualitySummary: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let evalRunCount: Int
    public let totalCasesEvaluated: Int
    public let passCount: Int
    public let failCount: Int
    public let passRate: Double
    public let driftLevel: String?
    public let fallbackDriftCount: Int
    public let averageLatencyMs: Int?
    public let dominantBackend: String?
    public let releaseMode: String
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public init(
        id: UUID = UUID(),
        date: Date,
        evalRunCount: Int,
        totalCasesEvaluated: Int,
        passCount: Int,
        failCount: Int,
        passRate: Double,
        driftLevel: String?,
        fallbackDriftCount: Int,
        averageLatencyMs: Int?,
        dominantBackend: String?,
        releaseMode: String
    ) {
        self.id = id
        self.date = date
        self.evalRunCount = evalRunCount
        self.totalCasesEvaluated = totalCasesEvaluated
        self.passCount = passCount
        self.failCount = failCount
        self.passRate = passRate
        self.driftLevel = driftLevel
        self.fallbackDriftCount = fallbackDriftCount
        self.averageLatencyMs = averageLatencyMs
        self.dominantBackend = dominantBackend
        self.releaseMode = releaseMode
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    /// Normalized date (start of day) for grouping
    public var normalizedDate: Date {
        Calendar.current.startOfDay(for: date)
    }
}

/// Store for quality history summaries
public final class QualityHistoryStore: ObservableObject {
    
    public static let shared = QualityHistoryStore()
    
    private let storageKey = "com.operatorkit.qualityHistory"
    private let defaults: UserDefaults
    
    @Published public private(set) var summaries: [DailyQualitySummary] = []
    
    /// Maximum history retention (days)
    public let maxRetentionDays = 90
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadSummaries()
    }
    
    // MARK: - Append Summary
    
    /// Appends a summary after an eval run
    public func appendSummary(from evalRun: EvalRun, driftSummary: DriftSummary) {
        // Check if we already have a summary for today
        let today = Calendar.current.startOfDay(for: Date())
        
        if let existingIndex = summaries.firstIndex(where: { 
            Calendar.current.isDate($0.normalizedDate, inSameDayAs: today) &&
            $0.releaseMode == (evalRun.qualitySignature?.releaseMode ?? ReleaseMode.current.rawValue)
        }) {
            // Update existing summary for today
            var existing = summaries[existingIndex]
            let merged = mergeSummary(existing: existing, newRun: evalRun, driftSummary: driftSummary)
            summaries[existingIndex] = merged
        } else {
            // Create new summary
            let summary = createSummary(from: evalRun, driftSummary: driftSummary)
            summaries.append(summary)
        }
        
        // Prune old data
        pruneOldSummaries()
        
        saveSummaries()
    }
    
    private func createSummary(from evalRun: EvalRun, driftSummary: DriftSummary) -> DailyQualitySummary {
        let fallbackDriftCount = driftSummary.failuresByCategory[.fallback] ?? 0
        
        // Compute average latency from results
        let latencies = evalRun.results.compactMap { $0.metrics.latencyDeltaMs }
        let avgLatency = latencies.isEmpty ? nil : latencies.reduce(0, +) / latencies.count
        
        // Determine dominant backend
        var backendCounts: [String: Int] = [:]
        for result in evalRun.results {
            backendCounts[result.metrics.backendUsed, default: 0] += 1
        }
        let dominantBackend = backendCounts.max(by: { $0.value < $1.value })?.key
        
        return DailyQualitySummary(
            date: Date(),
            evalRunCount: 1,
            totalCasesEvaluated: evalRun.results.count,
            passCount: evalRun.passCount,
            failCount: evalRun.failCount,
            passRate: evalRun.passRate,
            driftLevel: driftSummary.driftLevel.rawValue,
            fallbackDriftCount: fallbackDriftCount,
            averageLatencyMs: avgLatency,
            dominantBackend: dominantBackend,
            releaseMode: evalRun.qualitySignature?.releaseMode ?? ReleaseMode.current.rawValue
        )
    }
    
    private func mergeSummary(
        existing: DailyQualitySummary,
        newRun: EvalRun,
        driftSummary: DriftSummary
    ) -> DailyQualitySummary {
        let totalCases = existing.totalCasesEvaluated + newRun.results.count
        let totalPass = existing.passCount + newRun.passCount
        let totalFail = existing.failCount + newRun.failCount
        let newPassRate = totalCases > 0 ? Double(totalPass) / Double(totalCases) : 0.0
        let fallbackDriftCount = existing.fallbackDriftCount + (driftSummary.failuresByCategory[.fallback] ?? 0)
        
        return DailyQualitySummary(
            id: existing.id,
            date: existing.date,
            evalRunCount: existing.evalRunCount + 1,
            totalCasesEvaluated: totalCases,
            passCount: totalPass,
            failCount: totalFail,
            passRate: newPassRate,
            driftLevel: driftSummary.driftLevel.rawValue,
            fallbackDriftCount: fallbackDriftCount,
            averageLatencyMs: existing.averageLatencyMs,
            dominantBackend: existing.dominantBackend,
            releaseMode: existing.releaseMode
        )
    }
    
    // MARK: - Trend Queries
    
    /// Gets summaries for the last N days
    public func summariesForLast(days: Int) -> [DailyQualitySummary] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return summaries.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }
    
    /// Gets summaries for a specific release mode
    public func summaries(forReleaseMode mode: String) -> [DailyQualitySummary] {
        summaries.filter { $0.releaseMode == mode }.sorted { $0.date < $1.date }
    }
    
    /// Computes pass rate trend for last N days
    public func passRateTrend(days: Int) -> [Date: Double] {
        let recent = summariesForLast(days: days)
        var trend: [Date: Double] = [:]
        for summary in recent {
            trend[summary.normalizedDate] = summary.passRate
        }
        return trend
    }
    
    /// Gets the most recent summary
    public var mostRecentSummary: DailyQualitySummary? {
        summaries.sorted { $0.date > $1.date }.first
    }
    
    // MARK: - Pruning
    
    private func pruneOldSummaries() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxRetentionDays, to: Date()) ?? Date()
        summaries.removeAll { $0.date < cutoff }
    }
    
    // MARK: - Persistence
    
    private func loadSummaries() {
        guard let data = defaults.data(forKey: storageKey) else {
            summaries = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            summaries = try decoder.decode([DailyQualitySummary].self, from: data)
        } catch {
            logError("Failed to load quality history: \(error)", category: .audit)
            summaries = []
        }
    }
    
    private func saveSummaries() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(summaries)
            defaults.set(data, forKey: storageKey)
        } catch {
            logError("Failed to save quality history: \(error)", category: .audit)
        }
    }
    
    // MARK: - Export
    
    public func exportAsJSON() throws -> Data {
        let export = QualityHistoryExport(summaries: summaries)
        return try export.toJSON()
    }
    
    // MARK: - Clear
    
    public func clearAll() {
        summaries.removeAll()
        saveSummaries()
    }
}

// MARK: - Export Format

public struct QualityHistoryExport: Codable {
    public let schemaVersion: Int
    public let exportedAt: Date
    public let appVersion: String?
    public let totalSummaries: Int
    public let summaries: [DailyQualitySummary]
    
    public init(summaries: [DailyQualitySummary]) {
        self.schemaVersion = DailyQualitySummary.currentSchemaVersion
        self.exportedAt = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        self.totalSummaries = summaries.count
        self.summaries = summaries
    }
    
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
