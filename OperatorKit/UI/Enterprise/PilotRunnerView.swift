import SwiftUI

// ============================================================================
// PILOT RUNNER VIEW — Enterprise Demo Execution + Artifact Viewer
// ============================================================================

struct PilotRunnerView: View {

    @StateObject private var pilot = PilotRunner.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                controlCard
                if !pilot.transcript.isEmpty {
                    transcriptCard
                }
                if pilot.lastRunAt != nil {
                    artifactsCard
                }
            }
            .padding()
        }
        .background(OKColor.backgroundPrimary)
        .navigationTitle("Pilot Runner")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ENTERPRISE PILOT")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)
            Text("Run a complete governed execution lifecycle with verifiable artifacts.")
                .font(.system(size: 15))
                .foregroundStyle(OKColor.textSecondary)
        }
    }

    // MARK: - Controls

    private var controlCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if pilot.isRunning {
                HStack {
                    ProgressView()
                        .tint(OKColor.actionPrimary)
                    Text("Step \(pilot.currentStep) of \(pilot.totalSteps)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OKColor.textPrimary)
                }
            } else if let lastRun = pilot.lastRunAt {
                HStack {
                    Image(systemName: pilot.allPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(pilot.allPassed ? OKColor.riskNominal : OKColor.riskCritical)
                    Text(pilot.allPassed ? "ALL PASSED" : "FAILURES DETECTED")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(pilot.allPassed ? OKColor.riskNominal : OKColor.riskCritical)
                    Spacer()
                    Text(lastRun.formatted(date: .omitted, time: .standard))
                        .font(.system(size: 12))
                        .foregroundStyle(OKColor.textMuted)
                }
            }

            Button(pilot.isRunning ? "Running..." : "Run Full Pilot") {
                Task {
                    await pilot.runFullPilot()
                }
            }
            .buttonStyle(OKPrimaryButtonStyle())
            .disabled(pilot.isRunning)
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    // MARK: - Transcript

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRANSCRIPT")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            ForEach(pilot.transcript) { entry in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: entry.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(entry.passed ? OKColor.riskNominal : OKColor.riskCritical)
                        .font(.system(size: 14))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Step \(entry.step): \(entry.name)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OKColor.textPrimary)
                        Text(entry.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(OKColor.textMuted)
                            .lineLimit(3)
                    }
                }
            }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    // MARK: - Artifacts

    private var artifactsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ARTIFACTS")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            Group {
                artifactRow("PilotTranscript.jsonl")
                artifactRow("CompliancePacket.json")
                artifactRow("LatestAttestationReceipt.json")
                artifactRow("IntegrityReport.json")
            }

            Text(pilot.artifactPath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(OKColor.textMuted)
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    private func artifactRow(_ filename: String) -> some View {
        let url = URL(fileURLWithPath: pilot.artifactPath).appendingPathComponent(filename)
        let exists = FileManager.default.fileExists(atPath: url.path)
        return HStack {
            Image(systemName: exists ? "doc.fill" : "doc")
                .foregroundStyle(exists ? OKColor.riskNominal : OKColor.textMuted)
            Text(filename)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(OKColor.textPrimary)
            Spacer()
            Text(exists ? "OK" : "—")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(exists ? OKColor.riskNominal : OKColor.textMuted)
        }
    }
}
