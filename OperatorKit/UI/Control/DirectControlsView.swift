import SwiftUI

// ============================================================================
// DIRECT CONTROLS — Emergency Stop / Undo / Escalate
//
// Emergency Stop → CapabilityKernel.emergencyStop() → .halted phase
// Escalate → CapabilityKernel.escalatePendingPlans() → human review
// Undo → ActionHistory.undoLast() → reversal of last reversible action
//
// NO dead buttons. Disabled state means no valid target — never silent fail.
// ============================================================================

struct DirectControlsView: View {
    let canEmergencyStop: Bool
    let canEscalate: Bool
    let canUndo: Bool
    let isHalted: Bool
    let onEmergencyStop: () -> Void
    let onEscalate: () -> Void
    let onUndo: () -> Void
    let onResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DIRECT CONTROL")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(OKColor.textMuted)
                .tracking(1.2)

            HStack(spacing: 12) {
                // Emergency Stop / Resume
                if isHalted {
                    Button(action: onResume) {
                        controlButton(
                            icon: "play.fill",
                            label: "RESUME",
                            foreground: .white,
                            background: OKColor.riskNominal
                        )
                    }
                } else {
                    Button(action: onEmergencyStop) {
                        controlButton(
                            icon: "hand.raised.fill",
                            label: "EMERGENCY\nSTOP",
                            foreground: .white,
                            background: canEmergencyStop
                                ? OKColor.emergencyStop
                                : OKColor.emergencyStop.opacity(0.25)
                        )
                    }
                    .disabled(!canEmergencyStop)
                }

                // Undo
                Button(action: onUndo) {
                    controlButton(
                        icon: "arrow.uturn.backward",
                        label: "UNDO",
                        foreground: canUndo ? OKColor.textPrimary : OKColor.textMuted,
                        background: OKColor.backgroundSecondary,
                        bordered: true
                    )
                }
                .disabled(!canUndo)

                // Escalate
                Button(action: onEscalate) {
                    controlButton(
                        icon: "arrow.up.circle.fill",
                        label: "ESCALATE",
                        foreground: canEscalate ? OKColor.textPrimary : OKColor.textMuted,
                        background: OKColor.backgroundSecondary,
                        bordered: true
                    )
                }
                .disabled(!canEscalate)
            }
        }
    }

    @ViewBuilder
    private func controlButton(
        icon: String,
        label: String,
        foreground: Color,
        background: Color,
        bordered: Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .multilineTextAlignment(.center)
                .tracking(0.5)
        }
        .foregroundColor(foreground)
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(background)
        .cornerRadius(12)
        .overlay(
            bordered
                ? RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(OKColor.borderSubtle, lineWidth: 1)
                : nil
        )
    }
}
