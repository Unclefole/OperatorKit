import SwiftUI

// ============================================================================
// CONSEQUENCE MODELING — Risk quadrant display
// Driven by real risk assessment data from EvidenceEngine
// ============================================================================

struct ConsequenceModelingView: View {
    let riskCounts: [RiskTier: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CONSEQUENCE MODELING")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(OKColor.textSecondary)
                    .tracking(1.2)

                Spacer()

                Text("LIVE RISK")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(OKColor.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(OKColor.riskCritical)
                    .cornerRadius(4)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                riskCard(tier: .critical, label: "CRITICAL", count: riskCounts[.critical, default: 0], color: OKColor.riskCritical, icon: "exclamationmark.triangle.fill")
                riskCard(tier: .high, label: "EXTREME", count: riskCounts[.high, default: 0], color: Color(hex: "6B21A8"), icon: "bolt.fill")
                riskCard(tier: .medium, label: "OPERATIONAL", count: riskCounts[.medium, default: 0], color: OKColor.riskNominal, icon: "chart.line.uptrend.xyaxis")
                riskCard(tier: .low, label: "NOMINAL", count: riskCounts[.low, default: 0], color: Color(hex: "059669"), icon: "shield.fill")
            }
        }
    }

    private func riskCard(tier: RiskTier, label: String, count: Int, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(color.opacity(0.8))
                .tracking(0.8)

            Spacer()

            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                }
            }
        }
        .padding(12)
        .frame(height: 100)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}
