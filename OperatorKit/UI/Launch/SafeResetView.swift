import SwiftUI

// ============================================================================
// SAFE RESET VIEW (Phase 10Q)
//
// User-initiated reset controls with confirmation.
// No effect on execution safety. No data leaves device.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No effect on execution safety
// ❌ No data export
// ❌ No background effects
// ✅ Confirmation required
// ✅ User-initiated only
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct SafeResetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var resetController = SafeResetController.shared
    
    @State private var selectedAction: ResetAction?
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                // Warning Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(OKColor.riskWarning)
                            
                            Text("Data Reset Options")
                                .font(.headline)
                        }
                        
                        Text("These actions permanently delete local data. They do not affect your subscription or execution safety.")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Reset Actions
                Section {
                    ForEach(ResetAction.allCases) { action in
                        ResetActionRow(action: action) {
                            selectedAction = action
                            showingConfirmation = true
                        }
                    }
                } header: {
                    Text("Available Resets")
                }
                
                // Last Reset Info
                if let lastAction = resetController.lastResetAction,
                   let lastDate = resetController.lastResetDate {
                    Section {
                        HStack {
                            Text("Last reset:")
                                .foregroundColor(OKColor.textSecondary)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text(lastAction.displayName)
                                    .font(.caption)
                                
                                Text(lastDate, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(OKColor.textSecondary)
                            }
                        }
                    } header: {
                        Text("History")
                    }
                }
            }
            .navigationTitle("Reset Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                selectedAction?.confirmationTitle ?? "Confirm Reset",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                if let action = selectedAction {
                    Button(action.displayName, role: .destructive) {
                        resetController.performReset(action)
                        selectedAction = nil
                    }
                    Button("Cancel", role: .cancel) {
                        selectedAction = nil
                    }
                }
            } message: {
                Text(selectedAction?.confirmationMessage ?? "")
            }
        }
    }
}

// MARK: - Reset Action Row

private struct ResetActionRow: View {
    let action: ResetAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                    .foregroundColor(OKColor.riskWarning)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.displayName)
                        .font(.subheadline)
                        .foregroundColor(OKColor.textPrimary)
                    
                    Text(action.description)
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if action.affectsSupport {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(OKColor.actionPrimary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SafeResetView()
}
