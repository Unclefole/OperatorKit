import SwiftUI

// ============================================================================
// OPERATION DETAIL VIEW — DEMO OPERATION DETAIL
// ============================================================================
// Navigated to from recent operations cards on Home screen.
// Home screen shows hardcoded demo operations (not from MemoryStore),
// so this view displays meaningful demo detail — NOT a placeholder stub.
//
// When real MemoryStore data is shown on Home, this view should be
// replaced with MemoryDetailView or adapted to accept PersistedMemoryItem.
// ============================================================================

struct OperationDetailView: View {
    let operationTitle: String
    let statusText: String
    let statusColor: Color

    @Environment(\.dismiss) private var dismiss

    // ── Deterministic View State ──────────────────────
    // White screens are forbidden. Every render state is explicit.
    enum ViewState {
        case loading
        case loaded
        case empty
        case error(String)
    }

    @State private var viewState: ViewState = .loading

    /// Derived icon based on status
    private var typeIcon: String {
        switch statusText {
        case "SENT":
            return "envelope.fill"
        case "APPROVED":
            return "doc.text.fill"
        case "PENDING":
            return "calendar"
        default:
            return "doc.text.magnifyingglass"
        }
    }

    /// Derived operation type label
    private var typeLabel: String {
        switch statusText {
        case "SENT":
            return "Email Draft"
        case "APPROVED":
            return "Document Review"
        case "PENDING":
            return "Meeting Scheduling"
        default:
            return "Operation"
        }
    }

    /// Derived summary based on the operation
    private var summaryText: String {
        switch statusText {
        case "SENT":
            return "This email draft was reviewed, approved, and sent via the Mail Composer. The user manually confirmed delivery."
        case "APPROVED":
            return "This document review was completed. The generated summary and action items were approved by the operator."
        case "PENDING":
            return "This meeting scheduling request is awaiting your review and approval before any calendar events are created."
        default:
            return "This operation is stored locally on your device."
        }
    }

    /// Derived next-step text
    private var nextStepText: String {
        switch statusText {
        case "SENT":
            return "No further action required."
        case "APPROVED":
            return "No further action required."
        case "PENDING":
            return "Open a new request from the Home screen to continue."
        default:
            return "Review the operation details above."
        }
    }

    var body: some View {
        Group {
            switch viewState {
            // ── LOADING STATE ──────────────────────────────
            case .loading:
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Loading document…")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(OKColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── EMPTY STATE ────────────────────────────────
            case .empty:
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(OKColors.textTertiary)
                    Text("This document has no content yet.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(OKColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── ERROR STATE ────────────────────────────────
            case .error(let message):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(OKColors.statusPending)
                    Text("Unable to load document.")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(OKColors.textPrimary)
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(OKColors.textSecondary)
                    Button("Retry") {
                        loadOperation()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(OKColors.intelligenceGradient)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── LOADED STATE ───────────────────────────────
            case .loaded:
                loadedContent
            }
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("Operation Detail")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            logDebug("[OperationDetail] onAppear — title: \(operationTitle), status: \(statusText)", category: .flow)
            loadOperation()
        }
    }

    // ── Data Loading ──────────────────────────────────────
    private func loadOperation() {
        logDebug("[OperationDetail] loadOperation START — title: \(operationTitle)", category: .flow)
        viewState = .loading

        // Validate inputs are non-empty
        guard !operationTitle.isEmpty else {
            logDebug("[OperationDetail] EMPTY — title is empty", category: .flow)
            viewState = .empty
            return
        }

        // Simulate brief load (real app: fetch from MemoryStore)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            logDebug("[OperationDetail] LOADED — rendering: \(operationTitle), status: \(statusText)", category: .flow)
            viewState = .loaded
        }
    }

    // ── Loaded Content ────────────────────────────────────
    private var loadedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // ── Header Card ──────────────────────────────
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: typeIcon)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(statusColor)
                    }

                    Text(operationTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(OKColors.textPrimary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Text(statusText)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(statusColor))

                        Text(typeLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(OKColors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
                )

                detailSection(title: "Summary", icon: "text.alignleft", content: summaryText)

                detailSection(
                    title: "Trust & Safety",
                    icon: "checkmark.shield.fill",
                    content: "All operations require explicit approval before execution. Nothing was auto-executed. Data is stored on-device only."
                )

                detailSection(title: "Next Steps", icon: "arrow.forward.circle.fill", content: nextStepText)

                // ── Demo Notice ──────────────────────────────
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(OKColors.textTertiary)
                    Text("This is a sample operation shown for demonstration purposes.")
                        .font(.system(size: 13))
                        .foregroundColor(OKColors.textTertiary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Detail Section Card

    private func detailSection(title: String, icon: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(OKColors.intelligenceStart)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(OKColors.textPrimary)
            }

            Text(content)
                .font(.system(size: 14))
                .foregroundColor(OKColors.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }
}
