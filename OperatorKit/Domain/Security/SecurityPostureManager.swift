import Foundation

// ============================================================================
// SECURITY POSTURE MANAGER — Enterprise Trust Level Configuration
//
// Defines three operational trust levels:
//   • Consumer      — basic security, attestation optional
//   • Professional  — attestation required, cert pinning optional
//   • Enterprise    — full enforcement: attestation, pinning, SE required,
//                     biometric for ALL tiers, org kill switch
//
// INVARIANT: Posture can only be RAISED without biometric.
// INVARIANT: Lowering posture requires biometric authentication.
// INVARIANT: Enterprise posture enables all security gates.
// INVARIANT: Posture is persisted across launches.
// ============================================================================

public enum SecurityPosture: String, Sendable, CaseIterable {
    case consumer      = "consumer"
    case professional  = "professional"
    case enterprise    = "enterprise"

    public var displayName: String {
        switch self {
        case .consumer:     return "Consumer"
        case .professional: return "Professional"
        case .enterprise:   return "Enterprise"
        }
    }

    public var description: String {
        switch self {
        case .consumer:
            return "Basic security. Attestation advisory. Suitable for personal use."
        case .professional:
            return "Attestation enforced. Certificate pinning active. Suitable for professional work."
        case .enterprise:
            return "Maximum enforcement. SE required. Biometric on all tiers. Org kill switch. Suitable for regulated environments."
        }
    }

    /// Numeric rank for comparison
    var rank: Int {
        switch self {
        case .consumer: return 0
        case .professional: return 1
        case .enterprise: return 2
        }
    }
}

public final class SecurityPostureManager: @unchecked Sendable {

    public static let shared = SecurityPostureManager()

    private static let postureKey = "com.operatorkit.security.posture"

    private let queue = DispatchQueue(label: "com.operatorkit.posture", qos: .userInitiated)
    private var _posture: SecurityPosture

    public var currentPosture: SecurityPosture {
        queue.sync { _posture }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.postureKey) ?? SecurityPosture.professional.rawValue
        _posture = SecurityPosture(rawValue: raw) ?? .professional
    }

    // MARK: - Posture Change

    /// Set the security posture. Raising is free. Lowering requires biometric
    /// (caller must gate).
    public func setPosture(_ newPosture: SecurityPosture) {
        queue.sync {
            _posture = newPosture
            UserDefaults.standard.set(newPosture.rawValue, forKey: Self.postureKey)
        }
        SecurityTelemetry.shared.record(
            category: .integrityCheck,
            detail: "Security posture changed to \(newPosture.rawValue)",
            outcome: .success,
            metadata: ["posture": newPosture.rawValue]
        )
    }

    /// Whether lowering from current to target requires biometric
    public func requiresBiometricToChange(to target: SecurityPosture) -> Bool {
        target.rank < currentPosture.rank
    }

    // MARK: - Posture-Driven Policy

    /// Whether attestation is hard-enforced (deny on failure)
    public var attestationRequired: Bool {
        currentPosture.rank >= SecurityPosture.professional.rank
    }

    /// Whether certificate pinning is enforced
    public var certificatePinningRequired: Bool {
        currentPosture.rank >= SecurityPosture.professional.rank
    }

    /// Whether Secure Enclave is required for token issuance
    public var secureEnclaveRequired: Bool {
        currentPosture == .enterprise
    }

    /// Whether biometric is required for ALL execution tiers (including low-risk)
    public var biometricRequiredForAllTiers: Bool {
        currentPosture == .enterprise
    }

    /// Whether org kill switch override is available
    public var orgKillSwitchAvailable: Bool {
        currentPosture == .enterprise
    }

    /// Whether unsigned connectors are allowed
    public var unsignedConnectorsAllowed: Bool {
        currentPosture == .consumer
    }
}
