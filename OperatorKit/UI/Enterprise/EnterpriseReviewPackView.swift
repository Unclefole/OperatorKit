import SwiftUI

// ============================================================================
// ENTERPRISE REVIEW PACK VIEW — Export + Preview Security Artifacts
// ============================================================================

struct EnterpriseReviewPackView: View {

    @StateObject private var builder = EnterpriseReviewPackBuilder.shared
    @State private var showExportSuccess = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                // Export Button
                exportCard

                // Claims Preview
                claimsPreview

                // Threat Model Preview
                threatModelPreview

                // Runbook Preview
                runbookPreview

                // Last Export
                if let path = builder.lastExportPath {
                    lastExportCard(path: path)
                }
            }
            .padding()
        }
        .background(OKColor.backgroundPrimary)
        .navigationTitle("Review Pack")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ENTERPRISE REVIEW PACK")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)
            Text("Generate exportable security claims, threat model, runbook, and compliance artifacts for enterprise evaluation.")
                .font(.system(size: 14))
                .foregroundStyle(OKColor.textSecondary)
        }
    }

    private var exportCard: some View {
        VStack(spacing: 12) {
            Button(builder.isExporting ? "Exporting..." : "Export Enterprise Review Pack") {
                _ = builder.exportReviewPack()
                showExportSuccess = true
            }
            .buttonStyle(OKPrimaryButtonStyle())
            .disabled(builder.isExporting)

            if showExportSuccess, builder.lastExportAt != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(OKColor.riskNominal)
                    Text("Pack exported at \(builder.lastExportAt!.formatted(date: .omitted, time: .standard))")
                        .font(.system(size: 13))
                        .foregroundStyle(OKColor.textSecondary)
                }
            }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    private var claimsPreview: some View {
        let claims = builder.generateSecurityClaims()
        return VStack(alignment: .leading, spacing: 10) {
            Text("SECURITY CLAIMS (\(claims.count))")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            ForEach(claims.prefix(5)) { claim in
                HStack(alignment: .top, spacing: 8) {
                    Text(claim.id)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(OKColor.actionPrimary)
                        .frame(width: 50, alignment: .leading)
                    Text(claim.invariant)
                        .font(.system(size: 13))
                        .foregroundStyle(OKColor.textPrimary)
                }
            }
            if claims.count > 5 {
                Text("+ \(claims.count - 5) more claims")
                    .font(.system(size: 12))
                    .foregroundStyle(OKColor.textMuted)
            }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    private var threatModelPreview: some View {
        let threats = builder.generateThreatModel()
        return VStack(alignment: .leading, spacing: 10) {
            Text("THREAT MODEL (\(threats.count))")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            ForEach(threats.prefix(3)) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.id): \(entry.threat)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OKColor.textPrimary)
                    Text("Asset: \(entry.asset) | Mitigation: \(entry.mitigation.prefix(60))...")
                        .font(.system(size: 11))
                        .foregroundStyle(OKColor.textMuted)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    private var runbookPreview: some View {
        let entries = builder.generateRunbook()
        return VStack(alignment: .leading, spacing: 10) {
            Text("INCIDENT RUNBOOK (\(entries.count))")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.trigger)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OKColor.riskWarning)
                    Text(entry.immediateAction)
                        .font(.system(size: 12))
                        .foregroundStyle(OKColor.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    private func lastExportCard(path: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXPORT LOCATION")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            Group {
                artifactFile("SecurityClaimsMatrix.json")
                artifactFile("ThreatModel.json")
                artifactFile("IncidentRunbook.json")
                artifactFile("CompliancePacket.json")
                artifactFile("EnterpriseReviewPack.json")
            }

            Text(path)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(OKColor.textMuted)
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    private func artifactFile(_ name: String) -> some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundStyle(OKColor.actionPrimary)
                .font(.system(size: 12))
            Text(name)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(OKColor.textPrimary)
        }
    }
}
