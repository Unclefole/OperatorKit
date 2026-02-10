import Foundation

// ============================================================================
// INTELLIGENCE FEATURE FLAGS — SINGLE SOURCE OF TRUTH
//
// INVARIANT: Cloud models are OFF by default.
// INVARIANT: Only CapabilityKernel and ModelRouter read these flags.
// INVARIANT: Changing a flag does NOT bypass kernel authority.
// ============================================================================

public enum IntelligenceFeatureFlags {

    // ── Keys ─────────────────────────────────────────────
    private static let kCloudModelsEnabled = "ok_cloud_models_enabled"
    private static let kOpenAIEnabled      = "ok_openai_enabled"
    private static let kAnthropicEnabled   = "ok_anthropic_enabled"

    // ── On-Device (always ON) ────────────────────────────
    public static let onDeviceModelEnabled: Bool = true

    // ── Cloud Master Switch ──────────────────────────────
    /// Master switch for ALL cloud model calls.
    /// OFF by default. Must be explicitly enabled by user.
    public static var cloudModelsEnabled: Bool {
        UserDefaults.standard.bool(forKey: kCloudModelsEnabled)
    }

    public static func setCloudModelsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: kCloudModelsEnabled)
    }

    // ── Provider-Specific ────────────────────────────────
    /// OpenAI provider enabled. Requires cloudModelsEnabled = true.
    public static var openAIEnabled: Bool {
        cloudModelsEnabled && UserDefaults.standard.bool(forKey: kOpenAIEnabled)
    }

    public static func setOpenAIEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: kOpenAIEnabled)
    }

    /// Anthropic provider enabled. Requires cloudModelsEnabled = true.
    public static var anthropicEnabled: Bool {
        cloudModelsEnabled && UserDefaults.standard.bool(forKey: kAnthropicEnabled)
    }

    public static func setAnthropicEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: kAnthropicEnabled)
    }

    // ── Convenience ──────────────────────────────────────
    /// True if any cloud provider is enabled and ready.
    public static var anyCloudProviderEnabled: Bool {
        openAIEnabled || anthropicEnabled
    }
}

// ============================================================================
// ENTERPRISE FEATURE FLAGS — ALL OFF BY DEFAULT
// ============================================================================

public enum EnterpriseFeatureFlags {

    private static let kAPNsEnabled = "ok_enterprise_apns_enabled"
    private static let kMirrorEnabled = "ok_enterprise_mirror_enabled"
    private static let kOrgCoSignEnabled = "ok_enterprise_org_cosign_enabled"
    private static let kBackgroundAutonomyEnabled = "ok_enterprise_bg_autonomy_enabled"
    private static let kExecutionKillSwitch = "ok_enterprise_execution_kill"
    private static let kCloudKillSwitch = "ok_enterprise_cloud_kill"
    private static let kScoutModeEnabled = "ok_enterprise_scout_mode"
    private static let kSlackIntegrationEnabled = "ok_enterprise_slack_enabled"
    private static let kSlackHostAllowlistEnabled = "ok_enterprise_slack_host_allowlist"

    /// Push notifications (APNs) — OFF by default
    public static var apnsEnabled: Bool {
        UserDefaults.standard.bool(forKey: kAPNsEnabled)
    }
    public static func setAPNsEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kAPNsEnabled)
    }

    /// Remote audit mirror — OFF by default
    public static var mirrorEnabled: Bool {
        UserDefaults.standard.bool(forKey: kMirrorEnabled)
    }
    public static func setMirrorEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kMirrorEnabled)
    }

    /// Organization co-signer for quorum — OFF by default
    public static var orgCoSignEnabled: Bool {
        UserDefaults.standard.bool(forKey: kOrgCoSignEnabled)
    }
    public static func setOrgCoSignEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kOrgCoSignEnabled)
    }

    /// Background autonomy (Sentinel draft mode) — OFF by default
    public static var backgroundAutonomyEnabled: Bool {
        UserDefaults.standard.bool(forKey: kBackgroundAutonomyEnabled)
    }
    public static func setBackgroundAutonomyEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kBackgroundAutonomyEnabled)
    }

    // ── Kill Switches (Admin-Only) ──────────────────────
    /// Execution kill switch — forces lockdown
    public static var executionKillSwitch: Bool {
        UserDefaults.standard.bool(forKey: kExecutionKillSwitch)
    }
    public static func setExecutionKillSwitch(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kExecutionKillSwitch)
        if on {
            // Immediately force lockdown (dispatch to MainActor)
            Task { @MainActor in
                KernelIntegrityGuard.shared.forceLockdown(reason: "Execution kill switch activated by admin")
            }
        }
    }

    /// Cloud model kill switch — blocks all cloud calls
    public static var cloudKillSwitch: Bool {
        UserDefaults.standard.bool(forKey: kCloudKillSwitch)
    }
    public static func setCloudKillSwitch(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kCloudKillSwitch)
    }

    /// Scout Mode — autonomous read-only monitoring (OFF by default)
    public static var scoutModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: kScoutModeEnabled)
    }
    public static func setScoutModeEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kScoutModeEnabled)
    }

    /// Slack integration — webhook delivery (OFF by default)
    public static var slackIntegrationEnabled: Bool {
        UserDefaults.standard.bool(forKey: kSlackIntegrationEnabled)
    }
    public static func setSlackIntegrationEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kSlackIntegrationEnabled)
    }

    /// Slack host allowlist — MUST be ON for Slack sends to succeed (OFF by default)
    /// Dual-gate: slackIntegrationEnabled AND slackHostAllowlistEnabled must both be true.
    public static var slackHostAllowlistEnabled: Bool {
        UserDefaults.standard.bool(forKey: kSlackHostAllowlistEnabled)
    }
    public static func setSlackHostAllowlistEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kSlackHostAllowlistEnabled)
        if on {
            NetworkPolicyEnforcer.shared.registerEnterpriseHost("hooks.slack.com")
        } else {
            NetworkPolicyEnforcer.shared.removeEnterpriseHost("hooks.slack.com")
        }
    }

    /// Combined convenience: both flags must be true for Slack delivery.
    public static var slackDeliveryPermitted: Bool {
        slackIntegrationEnabled && slackHostAllowlistEnabled
    }
}
