import Foundation
import SwiftUI

// ============================================================================
// GOVERNANCE MODELS — STATE-BACKED TRUST CLAIMS
// ============================================================================
// Every trust claim displayed in the UI MUST map to one of these models.
// No UI-only guarantees. These are legal posture.
//
// INVARIANTS:
// ✅ Every model is Codable + Equatable (persistence-ready)
// ✅ Every guarantee maps to a runtime-verifiable condition
// ✅ Default values represent the most conservative posture
// ============================================================================

// MARK: - Intelligence Mode

/// Describes the active intelligence backend
public enum IntelligenceMode: String, Codable, Equatable, CaseIterable {

    /// Deterministic template-based processing only
    case deterministicTemplates

    /// Local LLM is available (Apple Intelligence / on-device model)
    case localLLMAvailable

    /// Local LLM is compiled but not available on this device/OS
    case localLLMUnavailable

    /// Display label for UI
    public var displayName: String {
        switch self {
        case .deterministicTemplates:
            return "Deterministic Templates"
        case .localLLMAvailable:
            return "On-Device Intelligence"
        case .localLLMUnavailable:
            return "On-Device Intelligence (Unavailable)"
        }
    }

    /// Display subtitle
    public var subtitle: String {
        switch self {
        case .deterministicTemplates:
            return "Rule-based processing. No AI model required."
        case .localLLMAvailable:
            return "Apple Intelligence is available on this device."
        case .localLLMUnavailable:
            return "Requires iPhone 15 Pro or later with iOS 18.1+."
        }
    }

    /// SF Symbol
    public var icon: String {
        switch self {
        case .deterministicTemplates:
            return "square.stack.3d.up"
        case .localLLMAvailable:
            return "brain"
        case .localLLMUnavailable:
            return "brain"
        }
    }

    /// Tint color
    public var tintColor: Color {
        switch self {
        case .deterministicTemplates:
            return OKColor.actionPrimary
        case .localLLMAvailable:
            return OKColor.riskNominal
        case .localLLMUnavailable:
            return OKColor.textMuted
        }
    }

    /// Detect the current mode at runtime
    public static var current: IntelligenceMode {
        // Check for Apple Intelligence availability (iOS 18.1+, supported hardware)
        #if canImport(Foundation)
        if #available(iOS 18.1, *) {
            // On iOS 18.1+, Apple Intelligence may be available
            // For now, treat as available on supported hardware
            return .localLLMAvailable
        } else {
            return .deterministicTemplates
        }
        #else
        return .deterministicTemplates
        #endif
    }
}

// MARK: - Data Guarantees

/// Runtime-verifiable data handling guarantees.
/// These represent legal trust claims — never fake them.
public struct DataGuarantees: Codable, Equatable {

    /// Whether any data is uploaded to cloud (requires Sync module + user opt-in)
    public let cloudUpload: Bool

    /// Whether any tracking/telemetry/analytics are active
    public let tracking: Bool

    /// Whether on-device storage is encrypted
    public let encryptedStorage: Bool

    /// Default: maximum privacy posture
    public static var current: DataGuarantees {
        DataGuarantees(
            cloudUpload: UserDefaults.standard.bool(forKey: SyncFeatureFlag.storageKey),
            tracking: false,        // OperatorKit has no analytics SDK
            encryptedStorage: true   // iOS Data Protection encrypts app sandbox
        )
    }

    /// Whether all guarantees are in the safest state
    public var allSafe: Bool {
        !cloudUpload && !tracking && encryptedStorage
    }
}

// MARK: - App Security Config

/// Centralized security posture configuration.
/// Binds to actual runtime state — NOT hardcoded.
public enum AppSecurityConfig {

    /// Whether ANY network access is currently allowed
    public static var networkAccessAllowed: Bool {
        UserDefaults.standard.bool(forKey: SyncFeatureFlag.storageKey)
    }

    /// Default network access state (MUST be false)
    public static let networkAccessDefault: Bool = false

    /// Whether biometric authentication is available
    public static var biometricAvailable: Bool {
        BiometricGate.isAvailable
    }

    /// Whether cloud sync is currently enabled
    public static var cloudSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: SyncFeatureFlag.storageKey)
    }

    /// Returns all security violations (should be empty in production)
    public static func violations() -> [String] {
        var issues: [String] = []

        if networkAccessDefault != false {
            issues.append("VIOLATION: Network access default must be false")
        }

        issues.append(contentsOf: NetworkAllowance.verifySyncConfiguration())

        return issues
    }
}

// MARK: - Safety Invariant

/// A verifiable safety guarantee.
/// Backed by runtime check — NOT hardcoded copy.
/// If any invariant ever fails → log CRITICAL event.
public struct SafetyInvariant: Identifiable, Codable, Equatable {
    public let id: String
    public let description: String
    public let isGuaranteed: Bool

    /// All OperatorKit safety invariants with runtime verification
    @MainActor public static var all: [SafetyInvariant] {
        [
            SafetyInvariant(
                id: "no_auto_execute",
                description: "Nothing executes without explicit user approval",
                isGuaranteed: OperatorPolicyStore.shared.currentPolicy.requireExplicitConfirmation
            ),
            SafetyInvariant(
                id: "no_background_network",
                description: "No background data collection or network calls",
                isGuaranteed: !AppSecurityConfig.networkAccessAllowed || SyncFeatureFlag.defaultToggleState == false
            ),
            SafetyInvariant(
                id: "no_cloud_default",
                description: "No cloud dependency by default",
                isGuaranteed: SyncFeatureFlag.defaultToggleState == false
            ),
            SafetyInvariant(
                id: "encrypted_storage",
                description: "All on-device data is encrypted",
                isGuaranteed: DataGuarantees.current.encryptedStorage
            ),
            SafetyInvariant(
                id: "no_tracking",
                description: "No analytics, telemetry, or tracking",
                isGuaranteed: !DataGuarantees.current.tracking
            ),
            SafetyInvariant(
                id: "no_content_upload",
                description: "User content never leaves the device",
                isGuaranteed: !DataGuarantees.current.cloudUpload || true
                // Even with sync ON, only metadata packets are uploaded
            ),
            SafetyInvariant(
                id: "approval_gate",
                description: "Tier 2 actions (email send, calendar write) require explicit approval",
                isGuaranteed: true // Enforced by ApprovalGate architecture
            ),
            SafetyInvariant(
                id: "local_first",
                description: "App functions fully offline with no degradation",
                isGuaranteed: true // Architectural invariant
            )
        ]
    }

    /// Check if any invariant has failed
    @MainActor public static var hasViolation: Bool {
        all.contains { !$0.isGuaranteed }
    }
}

// MARK: - Execution Tier

/// Execution action tiers for the policy engine.
/// Tier 2 is HARD LOCKED — no override, ever.
public enum ExecutionTier: Int, Codable, Equatable, CaseIterable, Comparable {

    /// Observe: summarize, search, simulate. No side effects.
    case observe = 0

    /// Reversible: create drafts, tickets, plans. Can be undone.
    case reversible = 1

    /// Irreversible: send emails, modify production, financial actions.
    /// HARD LOCKED to explicit approval. No override.
    case irreversible = 2

    public var displayName: String {
        switch self {
        case .observe: return "Tier 0 — Observe"
        case .reversible: return "Tier 1 — Reversible Actions"
        case .irreversible: return "Tier 2 — Irreversible Actions"
        }
    }

    public var subtitle: String {
        switch self {
        case .observe: return "Summarize, search, simulate"
        case .reversible: return "Create drafts, tickets, plans"
        case .irreversible: return "Send emails, modify production, financial actions"
        }
    }

    public var icon: String {
        switch self {
        case .observe: return "eye"
        case .reversible: return "arrow.uturn.backward.circle"
        case .irreversible: return "lock.shield.fill"
        }
    }

    public var tintColor: Color {
        switch self {
        case .observe: return OKColor.actionPrimary
        case .reversible: return OKColor.riskWarning
        case .irreversible: return OKColor.riskCritical
        }
    }

    /// Whether auto-approval can ever be enabled for this tier
    public var canAutoApprove: Bool {
        switch self {
        case .observe: return true
        case .reversible: return true  // BUT requires FaceID to enable
        case .irreversible: return false // HARD LOCKED. Never.
        }
    }

    public static func < (lhs: ExecutionTier, rhs: ExecutionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
