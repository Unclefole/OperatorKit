import SwiftUI
import os.log

// ============================================================================
// FAIL CLOSED VIEW — SAFETY NET FOR NIL / MISSING DATA
//
// Invariant: OperatorKit NEVER renders a blank screen.
// If any detail view receives nil data, this view appears instead,
// with a clear error message + evidence log entry.
//
// Usage:
//   if let pack = optionalPack {
//       ProposalDetailView(proposal: pack)
//   } else {
//       FailClosedView(context: "ProposalDetail", reason: "ProposalPack is nil")
//   }
// ============================================================================

struct FailClosedView: View {
    let context: String
    let reason: String
    let suggestion: String

    init(context: String, reason: String, suggestion: String = "Navigate back and try again.") {
        self.context = context
        self.reason = reason
        self.suggestion = suggestion

        // Log immediately on creation
        Self.logFailure(context: context, reason: reason)
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(OKColor.riskCritical.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(OKColor.riskCritical)
            }

            // Title
            Text("FAIL CLOSED")
                .font(.system(size: 13, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(OKColor.riskCritical)

            // Context
            Text("Missing data in \(context)")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OKColor.textPrimary)
                .multilineTextAlignment(.center)

            // Reason
            Text(reason)
                .font(.system(size: 14))
                .foregroundStyle(OKColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Suggestion
            Text(suggestion)
                .font(.system(size: 13))
                .foregroundStyle(OKColor.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            #if DEBUG
            // Debug info
            VStack(alignment: .leading, spacing: 4) {
                Text("DEBUG")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(OKColor.riskWarning)
                Text("context: \(context)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(OKColor.textMuted)
                Text("reason: \(reason)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(OKColor.textMuted)
                Text("time: \(Date().formatted(date: .omitted, time: .complete))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(OKColor.textMuted)
            }
            .padding(12)
            .background(OKColor.backgroundTertiary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(OKColor.riskWarning.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(8)
            .padding(.horizontal, 24)
            #endif

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OKColor.backgroundPrimary.ignoresSafeArea())
    }

    // MARK: - Logging

    private static let logger = Logger(subsystem: "com.operatorkit", category: "FailClosed")

    static func logFailure(context: String, reason: String) {
        logger.error("FAIL CLOSED — context: \(context), reason: \(reason)")

        // Also log to EvidenceEngine for audit trail
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "fail_closed_view_rendered",
            planId: UUID(),
            jsonString: """
            {"context":"\(context)","reason":"\(reason)","timestamp":"\(Date().ISO8601Format())"}
            """
        )
    }
}

#if DEBUG
#Preview {
    FailClosedView(
        context: "ProposalDetail",
        reason: "ProposalPack was nil — data may have been deallocated."
    )
}
#endif
