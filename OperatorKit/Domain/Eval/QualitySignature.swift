import Foundation

// ============================================================================
// QUALITY SIGNATURE (Phase 9A)
//
// Content-free fingerprint of the system state at time of evaluation.
// Used for reproducibility tracking and release comparison.
//
// INVARIANT: Contains NO user content, NO identifiers, only generic metadata
// INVARIANT: Safe for export and cross-run comparison
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Content-free fingerprint of system state at evaluation time
public struct QualitySignature: Codable, Equatable {
    
    // MARK: - App Identity
    
    /// App version (e.g., "1.0.0")
    public let appVersion: String
    
    /// Build number (e.g., "42")
    public let buildNumber: String
    
    /// Release mode (debug/testflight/appstore)
    public let releaseMode: String
    
    // MARK: - Safety & Contract
    
    /// SHA-256 hash of SAFETY_CONTRACT.md
    public let safetyContractHash: String
    
    /// Quality gate configuration version
    public let qualityGateConfigVersion: Int
    
    // MARK: - Model Configuration
    
    /// Prompt scaffold version
    public let promptScaffoldVersion: Int
    
    /// Prompt scaffold hash (content-free)
    public let promptScaffoldHash: String?
    
    /// Backend availability map (backend name -> available)
    public let backendAvailability: [String: Bool]
    
    /// Deterministic model version
    public let deterministicModelVersion: String
    
    // MARK: - Metadata
    
    /// When this signature was created
    public let createdAt: Date
    
    /// Schema version for migration
    public let schemaVersion: Int
    
    /// Current schema version
    public static let currentSchemaVersion = 1
    
    // MARK: - Initialization
    
    public init(
        appVersion: String? = nil,
        buildNumber: String? = nil,
        releaseMode: String? = nil,
        safetyContractHash: String? = nil,
        qualityGateConfigVersion: Int = 1,
        promptScaffoldVersion: Int = 1,
        promptScaffoldHash: String? = nil,
        backendAvailability: [String: Bool]? = nil,
        deterministicModelVersion: String = "1.0",
        createdAt: Date = Date()
    ) {
        self.appVersion = appVersion ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.buildNumber = buildNumber ?? Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        self.releaseMode = releaseMode ?? ReleaseMode.current.rawValue
        self.safetyContractHash = safetyContractHash ?? SafetyContractSnapshot.currentHash() ?? "unknown"
        self.qualityGateConfigVersion = qualityGateConfigVersion
        self.promptScaffoldVersion = promptScaffoldVersion
        self.promptScaffoldHash = promptScaffoldHash
        self.backendAvailability = backendAvailability ?? Self.computeBackendAvailability()
        self.deterministicModelVersion = deterministicModelVersion
        self.createdAt = createdAt
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    // MARK: - Factory
    
    /// Creates a signature capturing current system state
    public static func capture() -> QualitySignature {
        QualitySignature(
            appVersion: nil,  // Auto-detect
            buildNumber: nil, // Auto-detect
            releaseMode: nil, // Auto-detect
            safetyContractHash: nil, // Auto-compute
            qualityGateConfigVersion: QualityGateThresholds.configVersion,
            promptScaffoldVersion: PromptScaffold.version,
            promptScaffoldHash: nil, // Optional, filled per-generation
            backendAvailability: nil, // Auto-compute
            deterministicModelVersion: DeterministicTemplateModel.modelVersion
        )
    }
    
    // MARK: - Backend Availability
    
    private static func computeBackendAvailability() -> [String: Bool] {
        var availability: [String: Bool] = [:]
        
        // Check each backend
        availability["DeterministicTemplateModel"] = true // Always available
        
        let appleBackend = AppleOnDeviceModelBackend()
        availability["AppleOnDeviceModelBackend"] = appleBackend.isAvailable
        
        let coreMLBackend = CoreMLModelBackend()
        availability["CoreMLModelBackend"] = coreMLBackend.isAvailable
        
        return availability
    }
    
    // MARK: - Comparison
    
    /// Checks if two signatures are from the same configuration
    public func isSameConfiguration(as other: QualitySignature) -> Bool {
        appVersion == other.appVersion &&
        buildNumber == other.buildNumber &&
        releaseMode == other.releaseMode &&
        safetyContractHash == other.safetyContractHash &&
        deterministicModelVersion == other.deterministicModelVersion
    }
    
    /// Checks if two signatures are from the same release channel
    public func isSameReleaseChannel(as other: QualitySignature) -> Bool {
        releaseMode == other.releaseMode
    }
    
    /// Returns differences between signatures
    public func diff(from other: QualitySignature) -> [SignatureDiff] {
        var diffs: [SignatureDiff] = []
        
        if appVersion != other.appVersion {
            diffs.append(.appVersion(from: other.appVersion, to: appVersion))
        }
        if buildNumber != other.buildNumber {
            diffs.append(.buildNumber(from: other.buildNumber, to: buildNumber))
        }
        if releaseMode != other.releaseMode {
            diffs.append(.releaseMode(from: other.releaseMode, to: releaseMode))
        }
        if safetyContractHash != other.safetyContractHash {
            diffs.append(.safetyContractHash(from: other.safetyContractHash, to: safetyContractHash))
        }
        if backendAvailability != other.backendAvailability {
            diffs.append(.backendAvailability(from: other.backendAvailability, to: backendAvailability))
        }
        if deterministicModelVersion != other.deterministicModelVersion {
            diffs.append(.deterministicModelVersion(from: other.deterministicModelVersion, to: deterministicModelVersion))
        }
        
        return diffs
    }
    
    // MARK: - Display
    
    /// Human-readable summary
    public var summary: String {
        """
        App: \(appVersion) (\(buildNumber))
        Mode: \(releaseMode)
        Backends: \(backendAvailability.filter { $0.value }.keys.sorted().joined(separator: ", "))
        """
    }
    
    /// Short identifier for grouping
    public var shortId: String {
        "\(appVersion)-\(buildNumber)-\(releaseMode)"
    }
}

// MARK: - Signature Diff

/// Represents a difference between two signatures
public enum SignatureDiff: Equatable {
    case appVersion(from: String, to: String)
    case buildNumber(from: String, to: String)
    case releaseMode(from: String, to: String)
    case safetyContractHash(from: String, to: String)
    case backendAvailability(from: [String: Bool], to: [String: Bool])
    case deterministicModelVersion(from: String, to: String)
    
    public var description: String {
        switch self {
        case .appVersion(let from, let to):
            return "App version: \(from) → \(to)"
        case .buildNumber(let from, let to):
            return "Build: \(from) → \(to)"
        case .releaseMode(let from, let to):
            return "Mode: \(from) → \(to)"
        case .safetyContractHash(let from, let to):
            return "Safety contract: \(from.prefix(8))... → \(to.prefix(8))..."
        case .backendAvailability(let from, let to):
            let fromAvailable = from.filter { $0.value }.keys.sorted()
            let toAvailable = to.filter { $0.value }.keys.sorted()
            return "Backends: [\(fromAvailable.joined(separator: ","))] → [\(toAvailable.joined(separator: ","))]"
        case .deterministicModelVersion(let from, let to):
            return "Model version: \(from) → \(to)"
        }
    }
}

// MARK: - Extensions for Versioning

extension QualityGateThresholds {
    /// Configuration version for signatures
    public static let configVersion = 1
}

extension PromptScaffold {
    /// Scaffold version for signatures
    public static let version = 1
}

extension DeterministicTemplateModel {
    /// Model version for signatures
    public static let modelVersion = "1.0.0"
}
