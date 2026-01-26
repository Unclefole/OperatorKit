import SwiftUI

// ============================================================================
// LAUNCH TRUST CALIBRATION MODIFIER (Phase L2)
//
// View modifier that presents the trust calibration ceremony on first launch.
// Apply to the app's root view for automatic one-time presentation.
//
// USAGE:
//   ContentView()
//       .launchTrustCalibration()
//
// CONSTRAINTS:
// ❌ No enforcement
// ❌ No networking
// ✅ One-time only
// ✅ Non-skippable until complete
// ============================================================================

public struct LaunchTrustCalibrationModifier: ViewModifier {
    
    @State private var showCalibration: Bool = false
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                // Check if calibration should be shown
                if LaunchTrustCalibrationState.shouldShowCalibration {
                    showCalibration = true
                }
            }
            .fullScreenCover(isPresented: $showCalibration) {
                LaunchTrustCalibrationView {
                    // Dismiss on completion
                    showCalibration = false
                }
            }
    }
}

// MARK: - View Extension

public extension View {
    
    /// Apply first-launch trust calibration ceremony
    /// Shows a one-time verification screen on first launch
    func launchTrustCalibration() -> some View {
        modifier(LaunchTrustCalibrationModifier())
    }
}
