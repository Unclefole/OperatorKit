import SwiftUI

// ============================================================================
// HIGH-RISK ACTIONS — Ranked list by risk score
// Driven by real kernel results and evidence data
// ============================================================================

struct HighRiskActionsView: View {
    let actions: [HighRiskAction]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOP HIGH-RISK ACTIONS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(OKColor.textSecondary)
                .tracking(1.2)

            if actions.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(actions.prefix(5).enumerated()), id: \.element.id) { index, action in
                        actionRow(action, index: index)

                        if index < min(actions.count - 1, 4) {
                            Divider()
                                .background(OKColor.borderSubtle)
                        }
                    }
                }
                .background(OKColor.backgroundSecondary)
                .cornerRadius(12)
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.checkered")
                .foregroundColor(OKColor.riskNominal)
            Text("System nominal — no high-risk actions.")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OKColor.backgroundSecondary)
        .cornerRadius(12)
    }

    private func actionRow(_ action: HighRiskAction, index: Int) -> some View {
        HStack(spacing: 12) {
            // Risk indicator
            Circle()
                .fill(riskColor(for: action.riskScore))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: riskIcon(for: action.riskScore))
                        .font(.caption)
                        .foregroundColor(OKColor.textPrimary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(OKColor.textPrimary)
                    .lineLimit(1)

                Text("MODULE: \(action.module)")
                    .font(.caption2)
                    .foregroundColor(OKColor.textMuted)
                    .tracking(0.5)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", action.riskScore))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(riskColor(for: action.riskScore))

                Text("RISK SCORE")
                    .font(.system(size: 7))
                    .foregroundColor(OKColor.textMuted)
                    .tracking(0.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func riskColor(for score: Double) -> Color {
        if score >= 8.0 { return OKColor.riskCritical }
        if score >= 6.0 { return OKColor.riskWarning }
        if score >= 4.0 { return OKColor.riskWarning }
        return OKColor.riskNominal
    }

    private func riskIcon(for score: Double) -> String {
        if score >= 8.0 { return "exclamationmark.triangle.fill" }
        if score >= 6.0 { return "bolt.fill" }
        return "shield.fill"
    }
}
