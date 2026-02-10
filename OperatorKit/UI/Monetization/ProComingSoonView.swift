import SwiftUI

// ============================================================================
// PRO COMING SOON VIEW
// ============================================================================
// Safe fallback view when paywall is disabled.
// NEVER shows a blank screen - always gives user a way back.
// ============================================================================

struct ProComingSoonView: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Pro badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [OKColor.actionPrimary, OKColor.riskExtreme],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "star.fill")
                        .font(.system(size: 36))
                        .foregroundColor(OKColor.textPrimary)
                }

                Text("Pro Coming Soon")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Pro features will be available in a future update. Stay tuned!")
                    .font(.body)
                    .foregroundColor(OKColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Done button
                Button(action: {
                    isPresented = false
                    dismiss()
                }) {
                    Text("Done")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(OKColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(OKColor.actionPrimary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(OKColor.backgroundPrimary)
            .navigationTitle("OperatorKit Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProComingSoonView(isPresented: .constant(true))
}
