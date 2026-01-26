import Foundation

// ============================================================================
// NETWORK ALLOWANCE (Phase 10D)
//
// This file governs the ONLY exception to OperatorKit's "no network" rule.
// Networking is ONLY permitted in the Sync module, and ONLY for:
// - User-initiated metadata packet uploads
// - Authentication (sign-in/sign-out)
//
// HARD INVARIANTS (NON-NEGOTIABLE):
// ✅ Sync module is the ONLY place that may use URLSession
// ✅ No background networking
// ✅ No autonomous uploads (user-initiated only)
// ✅ Only metadata packets (no user content)
// ✅ Fail closed (block if uncertain)
//
// See: docs/SAFETY_CONTRACT.md (Section 13 - Opt-In Cloud Sync)
// ============================================================================

// MARK: - Network Allowance Registry

/// Documents what networking is permitted in OperatorKit
/// This enum serves as compile-time documentation
public enum NetworkAllowance {
    
    /// The ONLY module permitted to use URLSession
    public static let allowedModule = "Sync"
    
    /// Permitted network operations
    public enum PermittedOperation: String, CaseIterable {
        case signIn = "Sign in with email OTP or Apple Sign-In"
        case signOut = "Sign out"
        case uploadMetadataPacket = "Upload metadata-only packet (user-initiated)"
        case listPackets = "List user's uploaded packets"
        case deletePacket = "Delete a packet from cloud"
    }
    
    /// Forbidden network operations (for documentation)
    public enum ForbiddenOperation: String, CaseIterable {
        case backgroundUpload = "Background or automatic uploads"
        case contentUpload = "Upload user content (drafts, emails, events)"
        case analytics = "Analytics or telemetry"
        case crashReporting = "External crash reporting"
        case remoteConfig = "Remote configuration"
        case pushNotifications = "Push notifications"
    }
    
    /// Modules that are FORBIDDEN from using URLSession
    public static let forbiddenModules = [
        "Domain/Execution",
        "Domain/Approval",
        "Domain/Drafts",
        "Domain/Context",
        "Domain/Memory",
        "Domain/Quality",
        "Domain/Eval",
        "Models",
        "Services",
        "Safety",
        "Diagnostics",
        "Policies"
    ]
}

// MARK: - Sync Feature Flag

/// Feature flag for opt-in cloud sync
public enum SyncFeatureFlag {
    
    /// Whether sync feature is compiled in
    /// Set to false to completely remove sync capability from build
    #if SYNC_DISABLED
    public static let isEnabled = false
    #else
    public static let isEnabled = true
    #endif
    
    /// Default state for sync toggle (OFF by default)
    public static let defaultToggleState = false
    
    /// Storage key for sync enabled preference
    public static let storageKey = "com.operatorkit.sync.enabled"
}

// MARK: - Sync Safety Configuration

/// Configuration constants for sync safety
public enum SyncSafetyConfig {
    
    /// Maximum payload size in bytes (200KB)
    public static let maxPayloadSizeBytes = 200 * 1024
    
    /// Request timeout in seconds
    public static let requestTimeoutSeconds: TimeInterval = 30
    
    /// Forbidden keys that indicate user content
    public static let forbiddenContentKeys = [
        "body",
        "subject",
        "email",
        "recipient",
        "attendees",
        "title",
        "description",
        "prompt",
        "context",
        "draft",
        "content",
        "message",
        "text",
        "note",
        "name",
        "address",
        "location"
    ]
    
    /// Required metadata keys for valid packets
    public static let requiredMetadataKeys = [
        "schemaVersion",
        "exportedAt"
    ]
    
    /// Syncable packet types (metadata only)
    public enum SyncablePacketType: String, CaseIterable {
        case qualityExport = "quality_export"
        case diagnosticsExport = "diagnostics_export"
        case policyExport = "policy_export"
        case releaseAcknowledgement = "release_acknowledgement"
        case evidencePacket = "evidence_packet"
    }
}

// MARK: - Compile-Time Documentation Guard

/// This enum exists solely to document at compile-time that
/// URLSession usage is ONLY permitted in the Sync module
///
/// If you see this and are thinking of using URLSession elsewhere:
/// STOP. Read docs/SAFETY_CONTRACT.md Section 13.
/// 
/// The Sync module is the ONLY exception to the "no network" rule,
/// and it is heavily constrained:
/// - OFF by default
/// - User-initiated only
/// - Metadata packets only
/// - No background sync
enum URLSessionUsageGuard {
    /// The ONLY file that may import and use URLSession for network requests
    /// is within the Sync module. All other network usage is FORBIDDEN.
    ///
    /// Enforced by: SyncInvariantTests.swift
    static let documentationOnly = true
}

// MARK: - Runtime Verification

extension NetworkAllowance {
    
    /// Verifies that sync is properly configured
    public static func verifySyncConfiguration() -> [String] {
        var issues: [String] = []
        
        // Verify feature flag
        if !SyncFeatureFlag.isEnabled {
            // Sync disabled at compile time - this is fine
            return []
        }
        
        // Verify default state
        if SyncFeatureFlag.defaultToggleState != false {
            issues.append("VIOLATION: Sync must be OFF by default")
        }
        
        // Verify forbidden keys list is not empty
        if SyncSafetyConfig.forbiddenContentKeys.isEmpty {
            issues.append("VIOLATION: Forbidden content keys list is empty")
        }
        
        // Verify required metadata keys list is not empty
        if SyncSafetyConfig.requiredMetadataKeys.isEmpty {
            issues.append("VIOLATION: Required metadata keys list is empty")
        }
        
        return issues
    }
}
