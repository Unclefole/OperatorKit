import SwiftUI

// ============================================================================
// TRUST REGISTRY VIEW — Admin Device Management
// ============================================================================

struct TrustRegistryView: View {

    @StateObject private var registry = TrustedDeviceRegistry.shared
    @State private var showRevokeAlert = false
    @State private var revokeTarget: String?
    @State private var revokeReason = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader("TRUSTED DEVICES")

                if registry.devices.isEmpty {
                    emptyState
                } else {
                    ForEach(registry.devices, id: \.devicePublicKeyFingerprint) { device in
                        deviceRow(device)
                    }
                }

                sectionHeader("EPOCH STATUS")
                epochStatus
            }
            .padding()
        }
        .background(OKColor.backgroundPrimary)
        .navigationTitle("Trust Registry")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Revoke Device", isPresented: $showRevokeAlert) {
            TextField("Reason", text: $revokeReason)
            Button("Revoke", role: .destructive) {
                if let fingerprint = revokeTarget {
                    OrgProvisioningService.shared.revokeDevice(fingerprint: fingerprint, reason: revokeReason)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will immediately revoke trust for the device. It cannot execute or receive tokens.")
        }
    }

    // MARK: - Components

    private func deviceRow(_ device: TrustedDeviceRegistry.TrustedDevice) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(trustColor(device.trustState))
                        .frame(width: 8, height: 8)
                    Text(device.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OKColor.textPrimary)
                }

                Text(device.devicePublicKeyFingerprint.prefix(24) + "...")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(OKColor.textMuted)

                Text("Registered: \(device.registeredAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 12))
                    .foregroundStyle(OKColor.textMuted)

                Text("State: \(device.trustState.rawValue.uppercased())")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(trustColor(device.trustState))
            }
            Spacer()

            if device.trustState == .trusted {
                Button("Revoke") {
                    revokeTarget = device.devicePublicKeyFingerprint
                    showRevokeAlert = true
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OKColor.emergencyStop)
            }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    private var epochStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Trust Epoch")
                    .foregroundStyle(OKColor.textMuted)
                Spacer()
                Text("\(TrustEpochManager.shared.trustEpoch)")
                    .foregroundStyle(OKColor.textPrimary)
                    .font(.system(size: 15, design: .monospaced))
            }
            HStack {
                Text("Active Key Version")
                    .foregroundStyle(OKColor.textMuted)
                Spacer()
                Text("v\(TrustEpochManager.shared.activeKeyVersion)")
                    .foregroundStyle(OKColor.textPrimary)
                    .font(.system(size: 15, design: .monospaced))
            }
            HStack {
                Text("Revoked Keys")
                    .foregroundStyle(OKColor.textMuted)
                Spacer()
                Text("\(TrustEpochManager.shared.revokedKeyVersions.count)")
                    .foregroundStyle(TrustEpochManager.shared.revokedKeyVersions.isEmpty ? OKColor.riskNominal : OKColor.riskWarning)
                    .font(.system(size: 15, design: .monospaced))
            }
        }
        .font(.system(size: 14))
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.slash")
                .font(.system(size: 32))
                .foregroundStyle(OKColor.textMuted)
            Text("No devices registered")
                .foregroundStyle(OKColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }

    // MARK: - Helpers

    private func trustColor(_ state: TrustedDeviceRegistry.TrustedDevice.TrustState) -> Color {
        switch state {
        case .trusted: return OKColor.riskNominal
        case .revoked: return OKColor.riskCritical
        case .suspended: return OKColor.riskWarning
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .tracking(1.0)
            .foregroundStyle(OKColor.textMuted)
    }
}
