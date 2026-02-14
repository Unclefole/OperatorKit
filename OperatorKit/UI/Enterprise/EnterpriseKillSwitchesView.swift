import SwiftUI

// ============================================================================
// ENTERPRISE KILL SWITCHES — Admin-Only Safety Controls
//
// INVARIANT: Kill switches immediately enforce their effect. No delay.
// INVARIANT: Execution kill switch forces LOCKDOWN.
// ============================================================================

struct EnterpriseKillSwitchesView: View {

    @State private var executionKill = EnterpriseFeatureFlags.executionKillSwitch
    @State private var cloudKill = EnterpriseFeatureFlags.cloudKillSwitch
    @State private var bgAutonomy = EnterpriseFeatureFlags.backgroundAutonomyEnabled
    @State private var apns = EnterpriseFeatureFlags.apnsEnabled
    @State private var mirror = EnterpriseFeatureFlags.mirrorEnabled
    @State private var orgCoSign = EnterpriseFeatureFlags.orgCoSignEnabled
    @State private var webResearch = EnterpriseFeatureFlags.webResearchEnabled
    @State private var researchAllowlist = EnterpriseFeatureFlags.researchHostAllowlistEnabled

    @StateObject private var integrityGuard = KernelIntegrityGuard.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Posture Banner
                if integrityGuard.isLocked {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                        Text("EXECUTION LOCKDOWN ACTIVE")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(OKColor.emergencyStop)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Kill Switches
                sectionHeader("KILL SWITCHES")

                killSwitchCard(
                    icon: "xmark.octagon.fill",
                    title: "Disable All Execution",
                    subtitle: "Forces immediate LOCKDOWN. No tokens issued, no side effects.",
                    isOn: $executionKill,
                    destructive: true
                ) {
                    EnterpriseFeatureFlags.setExecutionKillSwitch(executionKill)
                }

                killSwitchCard(
                    icon: "cloud.slash.fill",
                    title: "Disable Cloud Model Calls",
                    subtitle: "Blocks all outbound AI requests. On-device only.",
                    isOn: $cloudKill,
                    destructive: false
                ) {
                    EnterpriseFeatureFlags.setCloudKillSwitch(cloudKill)
                }

                killSwitchCard(
                    icon: "moon.fill",
                    title: "Disable Background Autonomy",
                    subtitle: "Stops Sentinel from preparing proposals in background.",
                    isOn: Binding(
                        get: { !bgAutonomy },
                        set: { bgAutonomy = !$0 }
                    ),
                    destructive: false
                ) {
                    EnterpriseFeatureFlags.setBackgroundAutonomyEnabled(bgAutonomy)
                }

                // Feature Flags
                sectionHeader("ENTERPRISE FEATURES")

                featureFlagRow(title: "Push Notifications (APNs)", isOn: $apns) {
                    EnterpriseFeatureFlags.setAPNsEnabled(apns)
                }
                featureFlagRow(title: "Audit Mirror", isOn: $mirror) {
                    EnterpriseFeatureFlags.setMirrorEnabled(mirror)
                }
                featureFlagRow(title: "Org Co-Signer (Quorum)", isOn: $orgCoSign) {
                    EnterpriseFeatureFlags.setOrgCoSignEnabled(orgCoSign)
                }

                // Web Research (Dual-Gate)
                sectionHeader("WEB RESEARCH (READ-ONLY)")

                featureFlagRow(title: "Web Research Enabled", isOn: $webResearch) {
                    EnterpriseFeatureFlags.setWebResearchEnabled(webResearch)
                }
                featureFlagRow(title: "Research Host Allowlist", isOn: $researchAllowlist) {
                    EnterpriseFeatureFlags.setResearchHostAllowlistEnabled(researchAllowlist)
                }

                if webResearch && researchAllowlist {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(OKColor.riskNominal)
                        Text("Web Research active — \(NetworkPolicyEnforcer.shared.activeResearchHosts.count) hosts allowlisted")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(OKColor.riskNominal)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OKColor.riskNominal.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.shield.fill")
                            .foregroundStyle(OKColor.textMuted)
                        Text("Both flags required. Web Research is OFF.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(OKColor.textMuted)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OKColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Recovery
                if integrityGuard.isLocked {
                    sectionHeader("RECOVERY")
                    Button("Attempt System Recovery") {
                        executionKill = false
                        EnterpriseFeatureFlags.setExecutionKillSwitch(false)
                        UserDefaults.standard.removeObject(forKey: "ok_enterprise_execution_kill")
                        _ = integrityGuard.attemptRecovery()
                    }
                    .buttonStyle(OKPrimaryButtonStyle())
                }
            }
            .padding()
        }
        .background(OKColor.backgroundPrimary)
        .navigationTitle("Kill Switches")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Components

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .tracking(1.0)
            .foregroundStyle(OKColor.textMuted)
    }

    private func killSwitchCard(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        destructive: Bool,
        onChange: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(destructive && isOn.wrappedValue ? OKColor.emergencyStop : OKColor.textMuted)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OKColor.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(OKColor.textMuted)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(destructive ? OKColor.emergencyStop : OKColor.actionPrimary)
                .onChange(of: isOn.wrappedValue) { _, _ in
                    onChange()
                }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(destructive && isOn.wrappedValue ? OKColor.emergencyStop.opacity(0.5) : OKColor.borderSubtle, lineWidth: 1)
        )
    }

    private func featureFlagRow(
        title: String,
        isOn: Binding<Bool>,
        onChange: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(OKColor.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(OKColor.actionPrimary)
                .onChange(of: isOn.wrappedValue) { _, _ in
                    onChange()
                }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }
}
