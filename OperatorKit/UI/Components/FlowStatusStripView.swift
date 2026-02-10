import SwiftUI

/// Unified status strip showing working/blocked/error states (Phase 5C)
/// Uses FlowStatus from AppState for consistent display across all screens
struct FlowStatusStripView: View {
    @EnvironmentObject var appState: AppState
    let onRecoveryAction: ((OperatorKitUserFacingError.RecoveryAction) -> Void)?
    
    init(onRecoveryAction: ((OperatorKitUserFacingError.RecoveryAction) -> Void)? = nil) {
        self.onRecoveryAction = onRecoveryAction
    }
    
    var body: some View {
        Group {
            switch appState.flowStatus {
            case .idle, .completed:
                EmptyView()
                
            case .working(let step):
                workingStrip(step: step)
                
            case .blocked(let reason):
                blockedStrip(reason: reason)
                
            case .failed(let message, _):
                if let error = appState.currentError {
                    errorStrip(error: error)
                } else {
                    blockedStrip(reason: message)
                }
            }
        }
    }
    
    // MARK: - Working Strip
    private func workingStrip(step: AppState.FlowWorkStep) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: OKColor.actionPrimary))
                .scaleEffect(0.8)
            
            Text(step.displayText)
                .font(.subheadline)
                .foregroundColor(OKColor.textPrimary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(OKColor.actionPrimary.opacity(0.05))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Working: \(step.displayText)")
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Blocked Strip
    private func blockedStrip(reason: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(OKColor.riskWarning)
            
            Text(reason)
                .font(.subheadline)
                .foregroundColor(OKColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(OKColor.riskWarning.opacity(0.05))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Blocked: \(reason)")
    }
    
    // MARK: - Error Strip
    private func errorStrip(error: OperatorKitUserFacingError) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(OKColor.riskCritical)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(error.message)
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Dismiss button
                Button(action: {
                    appState.clearError()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(OKColor.textMuted.opacity(0.5))
                }
                .accessibilityLabel("Dismiss error")
            }
            
            // Recovery actions
            if !error.recoveryActions.isEmpty, let onRecovery = onRecoveryAction {
                HStack(spacing: 10) {
                    ForEach(error.recoveryActions.prefix(2), id: \.self) { action in
                        Button(action: {
                            onRecovery(action)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: action.icon)
                                    .font(.system(size: 11))
                                Text(action.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(action == error.recoveryActions.first ? OKColor.textPrimary : OKColor.riskCritical)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                action == error.recoveryActions.first
                                    ? OKColor.riskCritical
                                    : OKColor.riskCritical.opacity(0.1)
                            )
                            .cornerRadius(6)
                        }
                        .accessibilityLabel("\(action.rawValue) button")
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(OKColor.riskCritical.opacity(0.05))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(error.title). \(error.message)")
    }
}

// MARK: - View Modifier for Easy Integration

extension View {
    /// Adds a flow status strip at the top of the view
    func flowStatusStrip(
        onRecoveryAction: ((OperatorKitUserFacingError.RecoveryAction) -> Void)? = nil
    ) -> some View {
        VStack(spacing: 0) {
            FlowStatusStripView(onRecoveryAction: onRecoveryAction)
            self
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Working state
        FlowStatusStripView()
            .environmentObject({
                let state = AppState()
                state.flowStatus = .working(step: .generatingDraft)
                return state
            }())
        
        // Blocked state
        FlowStatusStripView()
            .environmentObject({
                let state = AppState()
                state.flowStatus = .blocked(reason: "Calendar access is currently off")
                return state
            }())
    }
}
