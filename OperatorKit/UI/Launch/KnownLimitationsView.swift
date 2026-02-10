import SwiftUI

// ============================================================================
// KNOWN LIMITATIONS VIEW (Phase 10Q)
//
// Displays known limitations to reduce confusion.
// Read-only. No behavior toggles.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No behavior changes
// ❌ No blocking
// ✅ Read-only display
// ✅ Dismissible
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct KnownLimitationsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Header
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What OperatorKit Does NOT Do")
                            .font(.headline)
                        
                        Text("This list clarifies what OperatorKit cannot do. These are intentional design decisions, not bugs.")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Limitations by category
                ForEach(LimitationCategory.allCases, id: \.self) { category in
                    if let limitations = KnownLimitations.byCategory[category], !limitations.isEmpty {
                        Section {
                            ForEach(limitations) { limitation in
                                LimitationRow(limitation: limitation)
                            }
                        } header: {
                            Label(category.displayName, systemImage: category.icon)
                        }
                    }
                }
            }
            .navigationTitle("Known Limitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Limitation Row

private struct LimitationRow: View {
    let limitation: KnownLimitation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: limitation.icon)
                    .foregroundColor(OKColor.riskWarning)
                    .font(.caption)
                
                Text(limitation.statement)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(limitation.explanation)
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    KnownLimitationsView()
}
