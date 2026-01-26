import Foundation

// ============================================================================
// RELEASE ACKNOWLEDGEMENT STORE (Phase 9B)
//
// Local-only storage for release owner acknowledgements.
// This is PROCESS ONLY and does NOT gate any runtime behavior.
//
// INVARIANT: Does not affect execution, approval, two-key, or any user flow
// INVARIANT: Contains metadata only (no user content)
// INVARIANT: Local-only persistence
//
// See: docs/SAFETY_CONTRACT.md, docs/RELEASE_APPROVAL.md
// ============================================================================

/// A release owner acknowledgement record
public struct ReleaseAcknowledgement: Codable, Identifiable, Equatable {
    public let id: UUID
    public let acknowledgedAt: Date
    public let appVersion: String
    public let buildNumber: String
    public let safetyContractHash: String
    public let qualityGateStatus: String
    public let qualityGateSummary: String
    public let goldenCaseCount: Int
    public let latestEvalPassRate: Double?
    public let driftLevel: String?
    public let preflightPassed: Bool
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public init(
        id: UUID = UUID(),
        acknowledgedAt: Date = Date(),
        appVersion: String,
        buildNumber: String,
        safetyContractHash: String,
        qualityGateStatus: String,
        qualityGateSummary: String,
        goldenCaseCount: Int,
        latestEvalPassRate: Double?,
        driftLevel: String?,
        preflightPassed: Bool
    ) {
        self.id = id
        self.acknowledgedAt = acknowledgedAt
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.safetyContractHash = safetyContractHash
        self.qualityGateStatus = qualityGateStatus
        self.qualityGateSummary = qualityGateSummary
        self.goldenCaseCount = goldenCaseCount
        self.latestEvalPassRate = latestEvalPassRate
        self.driftLevel = driftLevel
        self.preflightPassed = preflightPassed
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    /// Creates an acknowledgement from current system state
    public static func captureCurrentState() -> ReleaseAcknowledgement {
        let gateResult = QualityGateEvaluator().evaluate()
        let safetyStatus = SafetyContractSnapshot.getStatus()
        let preflightReport = PreflightValidator.shared.runAllChecks()
        
        return ReleaseAcknowledgement(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            safetyContractHash: safetyStatus.currentHash ?? "unknown",
            qualityGateStatus: gateResult.status.rawValue,
            qualityGateSummary: gateResult.summary,
            goldenCaseCount: gateResult.metrics.goldenCaseCount,
            latestEvalPassRate: gateResult.metrics.latestPassRate,
            driftLevel: gateResult.metrics.driftLevel,
            preflightPassed: preflightReport.blockers.isEmpty
        )
    }
    
    /// Human-readable summary
    public var summary: String {
        """
        v\(appVersion) (\(buildNumber))
        Gate: \(qualityGateStatus)
        Golden Cases: \(goldenCaseCount)
        Pass Rate: \(latestEvalPassRate.map { String(format: "%.0f%%", $0 * 100) } ?? "N/A")
        """
    }
}

/// Store for release acknowledgements
/// IMPORTANT: This is process-only and does NOT affect runtime behavior
public final class ReleaseAcknowledgementStore: ObservableObject {
    
    public static let shared = ReleaseAcknowledgementStore()
    
    private let storageKey = "com.operatorkit.releaseAcknowledgements"
    private let defaults: UserDefaults
    
    @Published public private(set) var acknowledgements: [ReleaseAcknowledgement] = []
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadAcknowledgements()
    }
    
    // MARK: - Query
    
    /// Gets the most recent acknowledgement
    public var latestAcknowledgement: ReleaseAcknowledgement? {
        acknowledgements.sorted { $0.acknowledgedAt > $1.acknowledgedAt }.first
    }
    
    /// Gets acknowledgement for a specific version
    public func acknowledgement(forVersion version: String, build: String) -> ReleaseAcknowledgement? {
        acknowledgements.first { $0.appVersion == version && $0.buildNumber == build }
    }
    
    /// Checks if current version has been acknowledged
    public var isCurrentVersionAcknowledged: Bool {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return acknowledgement(forVersion: currentVersion, build: currentBuild) != nil
    }
    
    // MARK: - Record
    
    /// Records a new acknowledgement
    /// - Returns: The recorded acknowledgement
    public func recordAcknowledgement() -> ReleaseAcknowledgement {
        let ack = ReleaseAcknowledgement.captureCurrentState()
        acknowledgements.append(ack)
        saveAcknowledgements()
        
        logInfo("Release acknowledgement recorded for v\(ack.appVersion) (\(ack.buildNumber))", category: .audit)
        
        return ack
    }
    
    /// Checks if recording is allowed
    /// Recording is only allowed when quality gate is not FAIL and preflight has no blockers
    /// NOTE: This is advisory only - it does not gate the release itself
    public var canRecordAcknowledgement: Bool {
        let gateResult = QualityGateEvaluator().evaluate()
        let preflightReport = PreflightValidator.shared.runAllChecks()
        
        // Allow recording unless obviously broken
        return gateResult.status != .fail && preflightReport.blockers.isEmpty
    }
    
    /// Reason why recording is not allowed (if any)
    public var recordingBlockedReason: String? {
        let gateResult = QualityGateEvaluator().evaluate()
        let preflightReport = PreflightValidator.shared.runAllChecks()
        
        if gateResult.status == .fail {
            return "Quality gate is failing"
        }
        if !preflightReport.blockers.isEmpty {
            return "Preflight has blocking issues"
        }
        return nil
    }
    
    // MARK: - Persistence
    
    private func loadAcknowledgements() {
        guard let data = defaults.data(forKey: storageKey) else {
            acknowledgements = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            acknowledgements = try decoder.decode([ReleaseAcknowledgement].self, from: data)
        } catch {
            logError("Failed to load acknowledgements: \(error)", category: .audit)
            acknowledgements = []
        }
    }
    
    private func saveAcknowledgements() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(acknowledgements)
            defaults.set(data, forKey: storageKey)
        } catch {
            logError("Failed to save acknowledgements: \(error)", category: .audit)
        }
    }
    
    // MARK: - Clear (for testing)
    
    #if DEBUG
    public func clearAll() {
        acknowledgements.removeAll()
        saveAcknowledgements()
    }
    #endif
}

// MARK: - Export

extension ReleaseAcknowledgement {
    
    /// Exports as JSON data
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
