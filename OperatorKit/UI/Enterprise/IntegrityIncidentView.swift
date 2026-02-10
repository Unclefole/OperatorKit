import SwiftUI

// ============================================================================
// INTEGRITY INCIDENT VIEW — System Integrity + Lockdown Status
// ============================================================================

struct IntegrityIncidentView: View {

    @StateObject private var integrityGuard = KernelIntegrityGuard.shared
    @StateObject private var mirrorClient = EvidenceMirrorClient.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                postureCard
                checksCard
                mirrorCard
                actionsCard
            }
            .padding()
        }
        .background(OKColor.backgroundPrimary)
        .navigationTitle("System Integrity")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Posture

    private var postureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SYSTEM POSTURE")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            HStack {
                Circle()
                    .fill(postureColor)
                    .frame(width: 16, height: 16)
                Text(integrityGuard.systemPosture.rawValue.uppercased())
                    .font(.system(size: 22, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(postureColor)
            }

            if integrityGuard.isLocked {
                Text("EXECUTION LOCKDOWN — All token issuance and execution blocked.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OKColor.emergencyStop)
            }

            if let checkAt = integrityGuard.lastCheckAt {
                Text("Last check: \(checkAt.formatted(date: .abbreviated, time: .standard))")
                    .font(.system(size: 12))
                    .foregroundStyle(OKColor.textMuted)
            }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(postureColor.opacity(0.5), lineWidth: 1))
    }

    // MARK: - Checks

    private var checksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INTEGRITY CHECKS")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            if let report = integrityGuard.lastReport {
                ForEach(report.checks, id: \.name) { check in
                    HStack {
                        Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(check.passed ? OKColor.riskNominal : OKColor.riskCritical)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(OKColor.textPrimary)
                            if !check.detail.isEmpty {
                                Text(check.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(OKColor.textMuted)
                            }
                        }
                        Spacer()
                        Text(check.passed ? "PASS" : "FAIL")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(check.passed ? OKColor.riskNominal : OKColor.riskCritical)
                    }
                }
            } else {
                Text("No checks run yet")
                    .foregroundStyle(OKColor.textMuted)
            }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    // MARK: - Mirror Status

    private var mirrorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AUDIT MIRROR STATUS")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            HStack {
                Text("Sync Status")
                    .foregroundStyle(OKColor.textMuted)
                Spacer()
                Text(mirrorClient.syncStatus.rawValue.uppercased())
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(mirrorStatusColor)
            }

            if let lastSync = mirrorClient.lastSyncAt {
                HStack {
                    Text("Last Sync")
                        .foregroundStyle(OKColor.textMuted)
                    Spacer()
                    Text(lastSync.formatted(date: .abbreviated, time: .standard))
                        .foregroundStyle(OKColor.textSecondary)
                }
            }
        }
        .font(.system(size: 14))
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    // MARK: - Actions

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADMIN ACTIONS")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            Button("Run Integrity Check") {
                integrityGuard.performFullCheck()
            }
            .buttonStyle(OKPrimaryButtonStyle())

            if integrityGuard.isLocked {
                Button("Attempt Recovery") {
                    _ = integrityGuard.attemptRecovery()
                }
                .foregroundStyle(OKColor.riskWarning)
                .font(.system(size: 15, weight: .semibold))
            }

            Button("Rotate Keys") {
                OrgProvisioningService.shared.rotateKeys(reason: "Manual admin rotation")
            }
            .foregroundStyle(OKColor.textSecondary)
            .font(.system(size: 15, weight: .medium))
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    // MARK: - Helpers

    private var postureColor: Color {
        switch integrityGuard.systemPosture {
        case .nominal: return OKColor.riskNominal
        case .degraded: return OKColor.riskWarning
        case .lockdown: return OKColor.emergencyStop
        }
    }

    private var mirrorStatusColor: Color {
        switch mirrorClient.syncStatus {
        case .synced: return OKColor.riskNominal
        case .syncing: return OKColor.actionPrimary
        case .divergent: return OKColor.emergencyStop
        case .failed: return OKColor.riskCritical
        case .idle: return OKColor.textMuted
        }
    }
}
