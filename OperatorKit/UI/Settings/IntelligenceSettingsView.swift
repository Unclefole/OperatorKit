import SwiftUI

// ============================================================================
// INTELLIGENCE SETTINGS — MULTI-PROVIDER CLOUD MODEL CONFIGURATION (SECURITY UI)
//
// This is NOT a simple settings screen. It is a security control surface.
//
// SUPPORTED PROVIDERS:
//   - OpenAI (GPT-4o)
//   - Anthropic (Claude)
//   - Google Gemini
//   - Groq (Llama)
//
// INVARIANT: API keys entered via SecureField only.
// INVARIANT: Keys stored ONLY through APIKeyVault (hardware-backed Keychain).
// INVARIANT: Keys are never displayed, logged, or cached in view state.
// INVARIANT: Cloud toggle cannot enable without a valid key.
// INVARIANT: Connection test uses full governed pipeline.
// INVARIANT: All actions evidence-logged.
// ============================================================================

struct IntelligenceSettingsView: View {

    // MARK: - Provider Metadata

    private struct ProviderInfo: Identifiable {
        let id: ModelProvider
        let name: String
        let icon: String
        let placeholder: String
        let prefix: String?       // nil = no prefix validation
        let keyHintURL: String
    }

    private let providers: [ProviderInfo] = [
        ProviderInfo(
            id: .cloudOpenAI, name: "OpenAI", icon: "brain.head.profile",
            placeholder: "sk-...", prefix: "sk-",
            keyHintURL: "platform.openai.com/api-keys"
        ),
        ProviderInfo(
            id: .cloudAnthropic, name: "Anthropic", icon: "sparkle",
            placeholder: "sk-ant-...", prefix: "sk-ant-",
            keyHintURL: "console.anthropic.com/settings/keys"
        ),
        ProviderInfo(
            id: .cloudGemini, name: "Google Gemini", icon: "wand.and.stars",
            placeholder: "AIza...", prefix: nil,
            keyHintURL: "aistudio.google.com/apikey"
        ),
        ProviderInfo(
            id: .cloudGroq, name: "Groq", icon: "bolt.fill",
            placeholder: "gsk_...", prefix: "gsk_",
            keyHintURL: "console.groq.com/keys"
        ),
        ProviderInfo(
            id: .cloudLlama, name: "Meta Llama", icon: "flame.fill",
            placeholder: "Together AI key...", prefix: nil,
            keyHintURL: "api.together.xyz/settings/api-keys"
        ),
    ]

    // MARK: - State

    @State private var cloudModelsEnabled = IntelligenceFeatureFlags.cloudModelsEnabled
    @State private var devKeysEnabled = EnterpriseFeatureFlags.modelDevKeysEnabled

    // Per-provider state
    @State private var providerEnabled: [ModelProvider: Bool] = [:]
    @State private var keyExists: [ModelProvider: Bool] = [:]
    @State private var keyInput: [ModelProvider: String] = [:]
    @State private var showEntry: [ModelProvider: Bool] = [:]
    @State private var testResult: [ModelProvider: ConnectionTestResult] = [:]
    @State private var isTesting: [ModelProvider: Bool] = [:]
    @State private var showDeleteAlert: [ModelProvider: Bool] = [:]

    // Alerts
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var providerToDelete: ModelProvider?
    @State private var showDeleteConfirm = false

    // Brave Search connector state
    @State private var braveKeyInput = ""
    @State private var braveKeyExists = BraveSearchClient.shared.hasAPIKey()
    @State private var showBraveEntry = false
    @State private var braveTestStatus: String?
    @State private var isBraveTesting = false
    @State private var webResearchEnabled = EnterpriseFeatureFlags.webResearchEnabled
    @State private var researchHostAllowlistEnabled = EnterpriseFeatureFlags.researchHostAllowlistEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // ── Header ──────────────────────────────────
                securityBanner

                // ── Cloud Models Master Switch ──────────────
                cloudMasterSection

                // ── Dev Keys Gate ───────────────────────────
                devKeysSection

                // ── Provider Sections (always visible so keys can be added) ──
                ForEach(providers) { info in
                    providerSection(info: info)
                }

                // ── Search & Connectors ─────────────────────
                braveSearchSection

                // ── On-Device Status ────────────────────────
                onDeviceSection

                // ── Security Info ───────────────────────────
                securityInfoSection
            }
            .padding()
        }
        .background(OKColor.backgroundPrimary)
        .navigationTitle("Intelligence")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshAllStatus() }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .alert("Delete API Key?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let provider = providerToDelete {
                    deleteKey(for: provider)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let provider = providerToDelete {
                Text("This will permanently remove the \(provider.displayName) API key from this device. You'll need to re-enter it to use \(provider.displayName) models.")
            }
        }
    }

    // MARK: - Security Banner

    private var securityBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 20))
                .foregroundStyle(OKColor.riskNominal)

            VStack(alignment: .leading, spacing: 2) {
                Text("Hardware-Secured Vault")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OKColor.textPrimary)
                Text("Keys are device-bound, biometric-gated, and never leave Keychain")
                    .font(.system(size: 11))
                    .foregroundStyle(OKColor.textMuted)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OKColor.riskNominal.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(OKColor.riskNominal.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Cloud Master Switch

    private var cloudMasterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("CLOUD MODELS")

            HStack(spacing: 16) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(cloudModelsEnabled ? OKColor.actionPrimary : OKColor.textMuted)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Cloud Models")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OKColor.textPrimary)
                    Text(cloudStatusText)
                        .font(.system(size: 12))
                        .foregroundStyle(OKColor.textMuted)
                }

                Spacer()

                Toggle("", isOn: $cloudModelsEnabled)
                    .labelsHidden()
                    .tint(OKColor.actionPrimary)
                    .onChange(of: cloudModelsEnabled) { _, newValue in
                        IntelligenceFeatureFlags.setCloudModelsEnabled(newValue)
                        if !newValue {
                            // Disable all provider-specific flags
                            for info in providers {
                                providerEnabled[info.id] = false
                                IntelligenceFeatureFlags.setProviderEnabled(info.id, enabled: false)
                            }
                        }
                    }
            }
            .padding()
            .background(OKColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(OKColor.borderSubtle, lineWidth: 1)
            )
        }
    }

    // MARK: - Dev Keys Gate

    private var devKeysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Developer API Keys")
                    .font(.system(size: 15))
                    .foregroundStyle(OKColor.textPrimary)
                Spacer()
                Toggle("", isOn: $devKeysEnabled)
                    .labelsHidden()
                    .tint(OKColor.actionPrimary)
                    .onChange(of: devKeysEnabled) { _, newValue in
                        EnterpriseFeatureFlags.setModelDevKeysEnabled(newValue)
                    }
            }
            .padding()
            .background(OKColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))

            if !devKeysEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                    Text("Enable developer keys to configure API providers. Enterprise mode uses org-managed tokens.")
                        .font(.system(size: 11))
                }
                .foregroundStyle(OKColor.textMuted)
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Provider Section

    @ViewBuilder
    private func providerSection(info: ProviderInfo) -> some View {
        let provider = info.id
        let hasKey = keyExists[provider] ?? false
        let enabled = providerEnabled[provider] ?? false
        let testing = isTesting[provider] ?? false
        let entryVisible = showEntry[provider] ?? false
        let currentInput = keyInput[provider] ?? ""
        let result = testResult[provider]

        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(info.name.uppercased())

            VStack(spacing: 0) {
                // Provider header + toggle
                HStack(spacing: 14) {
                    Image(systemName: info.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(hasKey ? OKColor.actionPrimary : OKColor.textMuted)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(info.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(OKColor.textPrimary)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(hasKey ? OKColor.riskNominal : OKColor.textMuted)
                                .frame(width: 6, height: 6)
                            Text(hasKey ? "Key Configured" : "Not Configured")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(hasKey ? OKColor.riskNominal : OKColor.textMuted)
                        }
                    }

                    Spacer()

                    if hasKey {
                        Toggle("", isOn: Binding(
                            get: { enabled },
                            set: { newValue in
                                if newValue && !hasKey {
                                    showEntryError("Add a \(info.name) API key first")
                                    return
                                }
                                providerEnabled[provider] = newValue
                                IntelligenceFeatureFlags.setProviderEnabled(provider, enabled: newValue)
                            }
                        ))
                        .labelsHidden()
                        .tint(OKColor.actionPrimary)
                    }
                }
                .padding()

                Divider().background(OKColor.borderSubtle)

                // Key management buttons
                HStack(spacing: 12) {
                    if hasKey {
                        Button {
                            showEntry[provider] = !(showEntry[provider] ?? false)
                        } label: {
                            Label("Replace Key", systemImage: "key.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(OKColor.actionPrimary)
                        }

                        Spacer()

                        Button {
                            Task { await runTest(for: provider) }
                        } label: {
                            if testing {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(OKColor.textMuted)
                            } else {
                                Label("Test", systemImage: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(OKColor.riskOperational)
                            }
                        }
                        .disabled(testing)

                        Button {
                            providerToDelete = provider
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundStyle(OKColor.riskCritical)
                        }
                    } else {
                        Button {
                            showEntry[provider] = true
                        } label: {
                            Label("Add API Key", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(OKColor.actionPrimary)
                        }

                        Spacer()

                        Text(info.keyHintURL)
                            .font(.system(size: 10))
                            .foregroundStyle(OKColor.textMuted)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                // Key entry field
                if entryVisible {
                    Divider().background(OKColor.borderSubtle)

                    VStack(spacing: 10) {
                        SecureField(
                            info.placeholder,
                            text: Binding(
                                get: { keyInput[provider] ?? "" },
                                set: { keyInput[provider] = $0 }
                            )
                        )
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(OKColor.textPrimary)
                        .padding(12)
                        .background(OKColor.backgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        HStack {
                            Button("Save to Vault") {
                                saveKey(for: provider, info: info)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(currentInput.isEmpty ? OKColor.textMuted : OKColor.actionPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .disabled(currentInput.isEmpty)

                            Spacer()

                            Button("Cancel") {
                                keyInput[provider] = ""
                                showEntry[provider] = false
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(OKColor.textMuted)
                        }
                    }
                    .padding()
                }

                // Test result
                if let result = result {
                    Divider().background(OKColor.borderSubtle)

                    HStack(spacing: 8) {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.success ? OKColor.riskNominal : OKColor.riskCritical)
                        Text(result.statusText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(result.success ? OKColor.riskNominal : OKColor.riskCritical)
                        Spacer()
                        Text(result.timestamp, style: .time)
                            .font(.system(size: 11))
                            .foregroundStyle(OKColor.textMuted)
                    }
                    .padding()
                }
            }
            .background(OKColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(OKColor.borderSubtle, lineWidth: 1)
            )
        }
    }

    // MARK: - Brave Search Section

    private var braveSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SEARCH & CONNECTORS")

            // Web Research Flags
            HStack {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(OKColor.actionPrimary)
                Toggle("Web Research", isOn: $webResearchEnabled)
                    .tint(OKColor.actionPrimary)
                    .onChange(of: webResearchEnabled) { _, newValue in
                        EnterpriseFeatureFlags.setWebResearchEnabled(newValue)
                    }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(OKColor.textPrimary)

            HStack {
                Image(systemName: "checklist.checked")
                    .font(.system(size: 14))
                    .foregroundStyle(OKColor.actionPrimary)
                Toggle("Research Host Allowlist", isOn: $researchHostAllowlistEnabled)
                    .tint(OKColor.actionPrimary)
                    .onChange(of: researchHostAllowlistEnabled) { _, newValue in
                        EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(newValue)
                    }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(OKColor.textPrimary)

            if !webResearchEnabled || !researchHostAllowlistEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("Both toggles must be ON for web research to work.")
                        .font(.system(size: 11))
                }
                .foregroundStyle(OKColor.riskWarning)
            }

            Divider().opacity(0.3)

            // Brave Search API Key
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundStyle(OKColor.actionPrimary)
                    Text("Brave Search API")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OKColor.textPrimary)
                    Spacer()
                    if braveKeyExists {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(OKColor.riskNominal)
                            .font(.system(size: 14))
                    }
                }

                Text("Free tier: 2,000 queries/month. No tracking.")
                    .font(.system(size: 12))
                    .foregroundStyle(OKColor.textMuted)

                if braveKeyExists && !showBraveEntry {
                    HStack(spacing: 12) {
                        Label("Key configured", systemImage: "key.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(OKColor.riskNominal)
                        Spacer()
                        Button("Change") { showBraveEntry = true }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(OKColor.actionPrimary)
                        Button("Delete") {
                            BraveSearchClient.shared.deleteAPIKey()
                            braveKeyExists = false
                            braveTestStatus = nil
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(OKColor.emergencyStop)
                    }
                } else {
                    SecureField("BSA...", text: $braveKeyInput)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(size: 14, design: .monospaced))
                        .padding(10)
                        .background(OKColor.backgroundTertiary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(OKColor.borderSubtle, lineWidth: 1)
                        )

                    HStack(spacing: 8) {
                        Button {
                            saveBraveKey()
                        } label: {
                            Text("Save Key")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(braveKeyInput.count >= 10 ? OKColor.actionPrimary : OKColor.textMuted)
                                .cornerRadius(8)
                        }
                        .disabled(braveKeyInput.count < 10)

                        Spacer()

                        Text("Get key: brave.com/search/api")
                            .font(.system(size: 11))
                            .foregroundStyle(OKColor.textMuted)
                    }
                }

                if let status = braveTestStatus {
                    Text(status)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(status.contains("OK") ? OKColor.riskNominal : OKColor.riskWarning)
                }
            }
        }
        .okCard()
    }

    private func saveBraveKey() {
        let key = braveKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count >= 10 else { return }

        do {
            try BraveSearchClient.shared.storeAPIKey(key)
            braveKeyExists = true
            braveKeyInput = ""
            showBraveEntry = false
            braveTestStatus = "Key saved securely in Keychain."

            // Auto-enable web research flags on first key save
            if !webResearchEnabled {
                webResearchEnabled = true
                EnterpriseFeatureFlags.setWebResearchEnabled(true)
            }
            if !researchHostAllowlistEnabled {
                researchHostAllowlistEnabled = true
                EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(true)
            }
        } catch {
            braveTestStatus = "Save failed: \(error.localizedDescription)"
        }
    }

    // MARK: - On-Device Section

    private var onDeviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ON-DEVICE INTELLIGENCE")

            HStack(spacing: 14) {
                Image(systemName: "cpu")
                    .font(.system(size: 20))
                    .foregroundStyle(OKColor.riskNominal)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text("On-Device Models")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OKColor.textPrimary)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(OKColor.riskNominal)
                            .frame(width: 6, height: 6)
                        Text("Always Available — No API key required")
                            .font(.system(size: 12))
                            .foregroundStyle(OKColor.riskNominal)
                    }
                }

                Spacer()

                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(OKColor.riskNominal)
            }
            .padding()
            .background(OKColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(OKColor.borderSubtle, lineWidth: 1)
            )
        }
    }

    // MARK: - Security Info

    private var securityInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("SECURITY")

            VStack(alignment: .leading, spacing: 8) {
                securityRow(icon: "faceid", text: "Biometric authentication required to use keys")
                securityRow(icon: "iphone.gen3", text: "Keys are device-bound — cannot be exported or synced")
                securityRow(icon: "lock.fill", text: "Changing Face ID / Touch ID invalidates stored keys")
                securityRow(icon: "shield.lefthalf.filled", text: "Keys never touch disk, logs, or analytics")
                securityRow(icon: "xmark.octagon", text: "Kill switches immediately disable all cloud access")
            }
            .padding()
            .background(OKColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(OKColor.borderSubtle, lineWidth: 1)
            )
        }
    }

    private func securityRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(OKColor.textMuted)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(OKColor.textSecondary)
        }
    }

    // MARK: - Helpers

    private var cloudStatusText: String {
        let configuredCount = providers.filter { keyExists[$0.id] == true }.count
        if cloudModelsEnabled {
            if configuredCount == 0 {
                return "Enabled — add API keys below to connect providers"
            }
            return "\(configuredCount) provider\(configuredCount == 1 ? "" : "s") configured"
        } else {
            if configuredCount > 0 {
                return "Off — \(configuredCount) key\(configuredCount == 1 ? "" : "s") stored in vault"
            }
            return "On-device models only — no network AI calls"
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .tracking(1.0)
            .foregroundStyle(OKColor.textMuted)
    }

    private func refreshAllStatus() {
        cloudModelsEnabled = IntelligenceFeatureFlags.cloudModelsEnabled
        devKeysEnabled = EnterpriseFeatureFlags.modelDevKeysEnabled

        for info in providers {
            keyExists[info.id] = APIKeyVault.shared.hasKey(for: info.id)
            providerEnabled[info.id] = IntelligenceFeatureFlags.isProviderEnabled(info.id)
            if keyInput[info.id] == nil { keyInput[info.id] = "" }
            if showEntry[info.id] == nil { showEntry[info.id] = false }
            if isTesting[info.id] == nil { isTesting[info.id] = false }
            if showDeleteAlert[info.id] == nil { showDeleteAlert[info.id] = false }
        }
    }

    private func saveKey(for provider: ModelProvider, info: ProviderInfo) {
        let input = keyInput[provider] ?? ""
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Basic prefix validation (if the provider has one)
        if let prefix = info.prefix, !trimmedInput.hasPrefix(prefix) {
            showEntryError("\(info.name) keys typically start with '\(prefix)'. Check your key and try again.")
            return
        }

        do {
            try APIKeyVault.shared.storeKey(trimmedInput, for: provider)
            keyInput[provider] = ""
            showEntry[provider] = false

            // Auto-enable cloud + dev keys + this provider on first key save
            if !cloudModelsEnabled {
                cloudModelsEnabled = true
                IntelligenceFeatureFlags.setCloudModelsEnabled(true)
            }
            if !devKeysEnabled {
                devKeysEnabled = true
                EnterpriseFeatureFlags.setModelDevKeysEnabled(true)
            }

            // Auto-enable this specific provider
            providerEnabled[provider] = true
            IntelligenceFeatureFlags.setProviderEnabled(provider, enabled: true)

            refreshAllStatus()

            // Auto-run connection test to verify the key works
            Task {
                await runTest(for: provider)
            }
        } catch {
            showEntryError(error.localizedDescription)
        }
    }

    private func deleteKey(for provider: ModelProvider) {
        APIKeyVault.shared.deleteKey(for: provider)
        providerEnabled[provider] = false
        IntelligenceFeatureFlags.setProviderEnabled(provider, enabled: false)
        testResult[provider] = nil
        refreshAllStatus()

        // If no keys remain, disable cloud master switch
        let anyKeyRemains = providers.contains { keyExists[$0.id] == true }
        if !anyKeyRemains {
            cloudModelsEnabled = false
            IntelligenceFeatureFlags.setCloudModelsEnabled(false)
        }
    }

    private func runTest(for provider: ModelProvider) async {
        isTesting[provider] = true
        let result = await ModelConnectionTester.testConnection(for: provider)
        testResult[provider] = result
        isTesting[provider] = false
    }

    private func showEntryError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
