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
    private static let kGeminiEnabled      = "ok_gemini_enabled"
    private static let kGroqEnabled        = "ok_groq_enabled"
    private static let kLlamaEnabled       = "ok_llama_enabled"

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

    /// Google Gemini provider enabled. Requires cloudModelsEnabled = true.
    public static var geminiEnabled: Bool {
        cloudModelsEnabled && UserDefaults.standard.bool(forKey: kGeminiEnabled)
    }

    public static func setGeminiEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: kGeminiEnabled)
    }

    /// Groq provider enabled. Requires cloudModelsEnabled = true.
    public static var groqEnabled: Bool {
        cloudModelsEnabled && UserDefaults.standard.bool(forKey: kGroqEnabled)
    }

    public static func setGroqEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: kGroqEnabled)
    }

    /// Meta Llama provider enabled (via Together AI). Requires cloudModelsEnabled = true.
    public static var llamaEnabled: Bool {
        cloudModelsEnabled && UserDefaults.standard.bool(forKey: kLlamaEnabled)
    }

    public static func setLlamaEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: kLlamaEnabled)
    }

    // ── Convenience ──────────────────────────────────────
    /// True if any cloud provider is enabled and ready.
    public static var anyCloudProviderEnabled: Bool {
        openAIEnabled || anthropicEnabled || geminiEnabled || groqEnabled || llamaEnabled
    }

    /// Check if a specific provider is enabled.
    public static func isProviderEnabled(_ provider: ModelProvider) -> Bool {
        switch provider {
        case .onDevice:       return true
        case .cloudOpenAI:    return openAIEnabled
        case .cloudAnthropic: return anthropicEnabled
        case .cloudGemini:    return geminiEnabled
        case .cloudGroq:      return groqEnabled
        case .cloudLlama:     return llamaEnabled
        }
    }

    /// Set a specific provider enabled/disabled.
    public static func setProviderEnabled(_ provider: ModelProvider, enabled: Bool) {
        switch provider {
        case .onDevice:       break
        case .cloudOpenAI:    setOpenAIEnabled(enabled)
        case .cloudAnthropic: setAnthropicEnabled(enabled)
        case .cloudGemini:    setGeminiEnabled(enabled)
        case .cloudGroq:      setGroqEnabled(enabled)
        case .cloudLlama:     setLlamaEnabled(enabled)
        }
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

    // ── Web Research Flags ──────────────────────────

    private static let kWebResearchEnabled = "ok_enterprise_web_research"
    private static let kResearchHostAllowlistEnabled = "ok_enterprise_research_host_allowlist"

    /// Web Research — governed web document fetching (OFF by default).
    /// When ON, NetworkPolicyEnforcer allowlists public research domains.
    /// Only GET + HTTPS + read-only. No auth. No form submissions.
    /// DUAL-GATE: Both webResearchEnabled AND researchHostAllowlistEnabled must be ON.
    public static var webResearchEnabled: Bool {
        UserDefaults.standard.bool(forKey: kWebResearchEnabled)
    }
    public static func setWebResearchEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kWebResearchEnabled)
        log("[FEATURE_FLAG] webResearchEnabled = \(on)")
    }

    /// Research Host Allowlist — second gate for web research (OFF by default).
    /// MUST be ON alongside webResearchEnabled for any research host to be allowlisted.
    public static var researchHostAllowlistEnabled: Bool {
        UserDefaults.standard.bool(forKey: kResearchHostAllowlistEnabled)
    }
    public static func setResearchHostAllowlistEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kResearchHostAllowlistEnabled)
        log("[FEATURE_FLAG] researchHostAllowlistEnabled = \(on)")
    }

    /// Convenience: both flags must be true for research domains to be active.
    public static var webResearchFullyEnabled: Bool {
        webResearchEnabled && researchHostAllowlistEnabled
    }

    // ── Credential / Dev Key Flags ──────────────────────────

    private static let kModelDevKeysEnabled = "ok_enterprise_model_dev_keys"
    private static let kEnterpriseOnboardingComplete = "ok_enterprise_onboarding_complete"

    /// Dev mode API keys — allow Keychain-stored dev keys for testing (OFF by default).
    public static var modelDevKeysEnabled: Bool {
        UserDefaults.standard.bool(forKey: kModelDevKeysEnabled)
    }
    public static func setModelDevKeysEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kModelDevKeysEnabled)
    }

    /// Enterprise onboarding complete — indicates org provisioning is done.
    /// When true, CredentialBroker uses enterprise tokens instead of dev keys.
    public static var enterpriseOnboardingComplete: Bool {
        UserDefaults.standard.bool(forKey: kEnterpriseOnboardingComplete)
    }
    public static func setEnterpriseOnboardingComplete(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kEnterpriseOnboardingComplete)
    }
}

// ============================================================================
// AUTOPILOT FEATURE FLAGS — OFF BY DEFAULT
// ============================================================================

public enum AutopilotFeatureFlags {

    private static let kAutopilotEnabled = "ok_autopilot_enabled"
    private static let kAutoContextEnabled = "ok_autopilot_auto_context"

    /// Master switch for autopilot mode. OFF by default.
    /// When ON, Siri routing and Skill triggers auto-advance the pipeline to ApprovalView.
    /// When OFF, app behaves exactly as before (manual navigation).
    public static var autopilotEnabled: Bool {
        UserDefaults.standard.bool(forKey: kAutopilotEnabled)
    }
    public static func setAutopilotEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kAutopilotEnabled)
    }

    /// Auto-context: allow autopilot to gather local-only context automatically.
    /// Only read-only sources (no network, no external side effects).
    /// ON by default when autopilot is enabled.
    public static var autoContextEnabled: Bool {
        UserDefaults.standard.object(forKey: kAutoContextEnabled) == nil
            ? true  // default ON
            : UserDefaults.standard.bool(forKey: kAutoContextEnabled)
    }
    public static func setAutoContextEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kAutoContextEnabled)
    }
}

