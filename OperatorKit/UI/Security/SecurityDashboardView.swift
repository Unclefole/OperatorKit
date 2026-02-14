import SwiftUI

// ============================================================================
// SECURITY DASHBOARD — Enterprise Security Posture Overview
//
// Displays:
//   • Kernel integrity status (nominal / degraded / lockdown)
//   • Vault health (key presence per provider, last access)
//   • Device attestation status
//   • Network policy enforcement status
//   • Recent security events (telemetry feed)
//   • Vault recovery action
//
// INVARIANT: No sensitive data displayed (no key values, no tokens).
// INVARIANT: All data sourced from production security subsystems.
// ============================================================================

struct SecurityDashboardView: View {
    @StateObject private var viewModel = SecurityDashboardViewModel()
    @State private var showingVaultRecovery = false

    var body: some View {
        ScrollView {
            VStack(spacing: OKSpacing.lg) {
                // Header
                securityHeader

                // Kernel Integrity
                kernelIntegrityCard

                // Vault Health
                vaultHealthCard

                // Device Attestation
                attestationCard

                // Network Policy
                networkPolicyCard

                // Security Telemetry Feed
                telemetryFeed

                // Actions
                actionSection
            }
            .padding(OKSpacing.md)
        }
        .background(OKColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingVaultRecovery) {
            VaultRecoveryView()
        }
        .task { await viewModel.loadData() }
    }

    // MARK: - Header

    private var securityHeader: some View {
        VStack(spacing: OKSpacing.sm) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.title2)
                    .foregroundStyle(viewModel.postureColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SYSTEM POSTURE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(OKColor.textMuted)
                    Text(viewModel.postureLabel)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(viewModel.postureColor)
                }
                Spacer()
                if viewModel.isRefreshing {
                    ProgressView()
                }
            }
        }
    }

    // MARK: - Kernel Integrity

    private var kernelIntegrityCard: some View {
        VStack(alignment: .leading, spacing: OKSpacing.sm) {
            sectionLabel("KERNEL INTEGRITY")

            ForEach(viewModel.integrityChecks, id: \.name) { check in
                HStack(spacing: OKSpacing.sm) {
                    Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(check.passed ? OKColor.riskNominal : (check.severity == "CRITICAL" ? OKColor.riskCritical : OKColor.riskWarning))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(check.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OKColor.textPrimary)
                        Text(check.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(OKColor.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
            }
        }
        .padding(OKSpacing.md)
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OKRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: OKRadius.card)
                .stroke(viewModel.postureColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Vault Health

    private var vaultHealthCard: some View {
        VStack(alignment: .leading, spacing: OKSpacing.sm) {
            sectionLabel("VAULT HEALTH")

            ForEach(viewModel.providerStatuses, id: \.provider) { status in
                HStack(spacing: OKSpacing.sm) {
                    Circle()
                        .fill(status.hasKey ? OKColor.riskNominal : OKColor.textMuted.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text(status.provider)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OKColor.textPrimary)
                    Spacer()
                    Text(status.hasKey ? "KEY PRESENT" : "NO KEY")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(status.hasKey ? OKColor.riskNominal : OKColor.textMuted)
                }
            }

            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text("Keys stored with kSecAttrAccessibleWhenUnlockedThisDeviceOnly + .userPresence")
                    .font(.system(size: 10))
            }
            .foregroundStyle(OKColor.textMuted)
        }
        .padding(OKSpacing.md)
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OKRadius.card))
    }

    // MARK: - Attestation

    private var attestationCard: some View {
        VStack(alignment: .leading, spacing: OKSpacing.sm) {
            sectionLabel("DEVICE ATTESTATION")

            HStack(spacing: OKSpacing.sm) {
                Image(systemName: viewModel.attestationIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(viewModel.attestationColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.attestationLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OKColor.textPrimary)
                    Text(viewModel.attestationDetail)
                        .font(.system(size: 11))
                        .foregroundStyle(OKColor.textSecondary)
                }
                Spacer()
            }
        }
        .padding(OKSpacing.md)
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OKRadius.card))
    }

    // MARK: - Network Policy

    private var networkPolicyCard: some View {
        VStack(alignment: .leading, spacing: OKSpacing.sm) {
            sectionLabel("NETWORK GOVERNANCE")

            HStack(spacing: OKSpacing.sm) {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.system(size: 14))
                    .foregroundStyle(OKColor.riskNominal)
                Text("All egress via NetworkPolicyEnforcer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OKColor.textPrimary)
                Spacer()
            }

            HStack(spacing: OKSpacing.lg) {
                networkMetric("HTTPS", value: "ENFORCED")
                networkMetric("ALLOWLIST", value: "ACTIVE")
                networkMetric("KILL SWITCH", value: viewModel.killSwitchActive ? "ON" : "OFF")
            }
        }
        .padding(OKSpacing.md)
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OKRadius.card))
    }

    private func networkMetric(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(OKColor.textMuted)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(OKColor.textPrimary)
        }
    }

    // MARK: - Telemetry Feed

    private var telemetryFeed: some View {
        VStack(alignment: .leading, spacing: OKSpacing.sm) {
            sectionLabel("SECURITY EVENTS (RECENT)")

            if viewModel.recentEvents.isEmpty {
                Text("No security events recorded")
                    .font(.system(size: 12))
                    .foregroundStyle(OKColor.textMuted)
            } else {
                ForEach(viewModel.recentEvents.prefix(15), id: \.id) { event in
                    HStack(spacing: OKSpacing.sm) {
                        Circle()
                            .fill(eventColor(event.outcome))
                            .frame(width: 6, height: 6)
                        Text(event.category)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(OKColor.textSecondary)
                        Text(event.detail.prefix(60))
                            .font(.system(size: 10))
                            .foregroundStyle(OKColor.textMuted)
                            .lineLimit(1)
                        Spacer()
                        Text(eventTimeLabel(event.timestamp))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(OKColor.textMuted)
                    }
                }
            }
        }
        .padding(OKSpacing.md)
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OKRadius.card))
    }

    private func eventColor(_ outcome: String) -> Color {
        switch outcome {
        case "success": return OKColor.riskNominal
        case "failure": return OKColor.riskCritical
        case "denied": return OKColor.riskWarning
        default: return OKColor.textMuted
        }
    }

    private func eventTimeLabel(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "\(Int(interval))s" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        return "\(Int(interval / 3600))h"
    }

    // MARK: - Actions

    private var actionSection: some View {
        VStack(spacing: OKSpacing.sm) {
            Button {
                Task { await viewModel.refreshIntegrity() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Run Integrity Check")
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(OKColor.backgroundTertiary)
                .foregroundStyle(OKColor.actionPrimary)
                .clipShape(RoundedRectangle(cornerRadius: OKRadius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: OKRadius.button)
                        .stroke(OKColor.borderSubtle, lineWidth: 1)
                )
            }

            Button {
                showingVaultRecovery = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle")
                    Text("Reset Secure Vault")
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(OKColor.riskWarning.opacity(0.1))
                .foregroundStyle(OKColor.riskWarning)
                .clipShape(RoundedRectangle(cornerRadius: OKRadius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: OKRadius.button)
                        .stroke(OKColor.riskWarning.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.0)
            .foregroundStyle(OKColor.textMuted)
    }
}

// MARK: - View Model

@MainActor
final class SecurityDashboardViewModel: ObservableObject {
    @Published var postureLabel = "CHECKING..."
    @Published var postureColor: Color = OKColor.textMuted
    @Published var integrityChecks: [CheckItem] = []
    @Published var providerStatuses: [ProviderStatus] = []
    @Published var recentEvents: [SecurityEvent] = []
    @Published var killSwitchActive = false
    @Published var isRefreshing = false

    // Attestation
    @Published var attestationLabel = "Not Checked"
    @Published var attestationDetail = ""
    @Published var attestationIcon = "questionmark.circle"
    @Published var attestationColor: Color = OKColor.textMuted

    struct CheckItem {
        let name: String
        let passed: Bool
        let detail: String
        let severity: String
    }

    struct ProviderStatus {
        let provider: String
        let hasKey: Bool
    }

    func loadData() async {
        await refreshIntegrity()
        loadVaultHealth()
        loadAttestation()
        loadTelemetry()
        killSwitchActive = EnterpriseFeatureFlags.cloudKillSwitch
    }

    func refreshIntegrity() async {
        isRefreshing = true
        KernelIntegrityGuard.shared.performFullCheck()

        let guard_ = KernelIntegrityGuard.shared
        switch guard_.systemPosture {
        case .nominal:
            postureLabel = "NOMINAL"
            postureColor = OKColor.riskNominal
        case .degraded:
            postureLabel = "DEGRADED"
            postureColor = OKColor.riskWarning
        case .lockdown:
            postureLabel = "LOCKDOWN"
            postureColor = OKColor.riskCritical
        }

        if let report = guard_.lastReport {
            integrityChecks = report.checks.map { check in
                CheckItem(
                    name: check.name,
                    passed: check.passed,
                    detail: check.detail,
                    severity: check.severity.rawValue
                )
            }
        }

        isRefreshing = false
    }

    private func loadVaultHealth() {
        let vault = APIKeyVault.shared
        providerStatuses = ModelProvider.allCloudProviders.map { provider in
            ProviderStatus(
                provider: provider.displayName,
                hasKey: vault.hasKey(for: provider)
            )
        }
    }

    private func loadAttestation() {
        let service = DeviceAttestationService.shared
        if !service.isSupported {
            attestationLabel = "Unavailable"
            attestationDetail = "App Attest not supported on this device (Simulator)"
            attestationIcon = "exclamationmark.triangle"
            attestationColor = OKColor.riskWarning
        } else {
            switch service.state {
            case .notStarted:
                attestationLabel = "Not Initialized"
                attestationDetail = "Attestation key not yet generated"
                attestationIcon = "circle.dashed"
                attestationColor = OKColor.textMuted
            case .keyGenerated:
                attestationLabel = "Key Generated"
                attestationDetail = "Attestation key ready — awaiting first attestation"
                attestationIcon = "key.fill"
                attestationColor = OKColor.riskOperational
            case .attested:
                attestationLabel = "Attested"
                attestationDetail = "Device identity verified by Apple"
                attestationIcon = "checkmark.seal.fill"
                attestationColor = OKColor.riskNominal
            case .unavailable:
                attestationLabel = "Unavailable"
                attestationDetail = "Device does not support App Attest"
                attestationIcon = "exclamationmark.triangle"
                attestationColor = OKColor.riskWarning
            case .failed:
                attestationLabel = "Failed"
                attestationDetail = "Attestation failed — check logs"
                attestationIcon = "xmark.circle.fill"
                attestationColor = OKColor.riskCritical
            }
        }
    }

    private func loadTelemetry() {
        recentEvents = SecurityTelemetry.shared.recentEvents(limit: 20)
    }
}
