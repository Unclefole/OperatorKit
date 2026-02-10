import SwiftUI

// ============================================================================
// AUDIT TRAIL FEED — Streaming log from EvidenceEngine
// Real append-only evidence entries, not simulated
// ============================================================================

struct AuditTrailFeedView: View {
    let entries: [AuditEntry]

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AUDIT TRAIL")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(OKColor.textSecondary)
                .tracking(1.2)

            if entries.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(entries) { entry in
                        entryRow(entry)
                    }
                }
                .padding(12)
                .background(OKColor.backgroundSecondary)
                .cornerRadius(12)
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(OKColor.textMuted)
            Text("No audit entries in the last hour")
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OKColor.backgroundSecondary)
        .cornerRadius(12)
    }

    private func entryRow(_ entry: AuditEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("[\(timeFormatter.string(from: entry.timestamp))]")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(OKColor.textMuted)

            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(severityColor(entry.severity))
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private func severityColor(_ severity: AuditEntry.Severity) -> Color {
        switch severity {
        case .info: return OKColor.textSecondary
        case .warning: return OKColor.riskWarning
        case .critical: return OKColor.riskCritical
        }
    }
}
