import SwiftUI

// ============================================================================
// AUDIT STATUS VIEW — Evidence Chain Status + Compliance Export
// ============================================================================

struct AuditStatusView: View {

    @StateObject private var mirrorClient = EvidenceMirrorClient.shared
    @State private var chainReport: ChainIntegrityReport?
    @State private var showExportSheet = false
    @State private var compliancePacket: EvidenceMirrorClient.ComplianceAuditPacket?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                chainStatusCard
                attestationCard
                complianceExportCard
            }
            .padding()
        }
        .background(OKColor.backgroundPrimary)
        .navigationTitle("Audit Status")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadChainReport()
        }
    }

    // MARK: - Chain Status

    private var chainStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EVIDENCE CHAIN")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            if let report = chainReport {
                HStack {
                    Image(systemName: report.overallValid ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(report.overallValid ? OKColor.riskNominal : OKColor.riskCritical)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(report.overallValid ? "Chain Valid" : "CHAIN CORRUPTED")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(report.overallValid ? OKColor.riskNominal : OKColor.riskCritical)
                        Text("\(report.totalEntries) entries · \(report.validEntries) valid")
                            .font(.system(size: 13))
                            .foregroundStyle(OKColor.textMuted)
                    }
                }

                if !report.violations.isEmpty {
                    ForEach(report.violations) { violation in
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(OKColor.riskCritical)
                                .font(.system(size: 12))
                            Text(violation.description)
                                .font(.system(size: 12))
                                .foregroundStyle(OKColor.riskCritical)
                        }
                    }
                }
            } else {
                ProgressView()
                    .tint(OKColor.actionPrimary)
            }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    // MARK: - Attestations

    private var attestationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MIRROR ATTESTATIONS")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            let history = EvidenceMirror.shared.attestationHistory
            if history.isEmpty {
                Text("No attestations created yet")
                    .font(.system(size: 14))
                    .foregroundStyle(OKColor.textMuted)
            } else {
                Text("\(history.count) attestation(s)")
                    .font(.system(size: 14))
                    .foregroundStyle(OKColor.textSecondary)

                ForEach(history.suffix(5), id: \.id) { att in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hash: \(att.chainHash.prefix(24))...")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(OKColor.textSecondary)
                            Text("Epoch \(att.epoch) · Key v\(att.keyVersion)")
                                .font(.system(size: 11))
                                .foregroundStyle(OKColor.textMuted)
                        }
                        Spacer()
                        Text(att.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundStyle(OKColor.textMuted)
                    }
                }
            }

            Button("Create Attestation Now") {
                Task {
                    _ = await EvidenceMirror.shared.createAttestation()
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(OKColor.actionPrimary)
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    // MARK: - Compliance Export

    private var complianceExportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMPLIANCE EXPORT")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            Text("Generate an audit packet for compliance review.")
                .font(.system(size: 14))
                .foregroundStyle(OKColor.textSecondary)

            Button("Generate Audit Packet") {
                compliancePacket = mirrorClient.generateCompliancePacket()
                showExportSheet = true
            }
            .buttonStyle(OKPrimaryButtonStyle())
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
        .sheet(isPresented: $showExportSheet) {
            if let packet = compliancePacket {
                CompliancePacketPreviewSheet(packet: packet)
            }
        }
    }

    // MARK: - Helpers

    private func loadChainReport() {
        chainReport = try? EvidenceEngine.shared.verifyChainIntegrity()
    }
}

// MARK: - Compliance Preview Sheet

struct CompliancePacketPreviewSheet: View {
    let packet: EvidenceMirrorClient.ComplianceAuditPacket
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    row("Device", packet.deviceFingerprint.prefix(24) + "...")
                    row("Epoch", "\(packet.trustEpoch)")
                    row("Key Version", "v\(packet.activeKeyVersion)")
                    row("Evidence Entries", "\(packet.evidenceEntryCount)")
                    row("Chain Valid", packet.evidenceChainValid ? "YES" : "NO")
                    row("Violations", "\(packet.evidenceViolations)")
                    row("System Posture", packet.systemPosture.uppercased())
                    row("Mirror Status", packet.mirrorSyncStatus.uppercased())
                    row("Attestations", "\(packet.attestationCount)")
                    row("Devices", "\(packet.registeredDevices.count)")
                }
                .padding()
            }
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Audit Packet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(OKColor.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(OKColor.textPrimary)
        }
        .padding(.vertical, 4)
    }
}
