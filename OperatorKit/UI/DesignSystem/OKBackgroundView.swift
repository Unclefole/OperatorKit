import SwiftUI

// MARK: - OperatorKit Background View
/// Consistent light background for all OperatorKit screens
/// Provides the signature soft blue/ice gradient look

public struct OKBackgroundView: View {

    public init() {}

    public var body: some View {
        ZStack {
            // Base: Pure white
            OKColors.backgroundPrimary

            // Overlay: Subtle blue/purple ice gradient
            LinearGradient(
                colors: [
                    Color(hex: "EEF4FF").opacity(0.7),  // Soft ice blue
                    Color(hex: "F5F3FF").opacity(0.5),  // Soft lavender
                    OKColors.backgroundPrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - View Extension for Easy Application

public extension View {
    /// Apply the standard OperatorKit light background
    /// - Parameter isHome: Set to true for Home screen (uses its own styling)
    func okScreenBackground(isHome: Bool = false) -> some View {
        ZStack {
            if isHome {
                // Home uses its own background - don't override
                self
            } else {
                // Standard OperatorKit light background
                OKBackgroundView()
                self
            }
        }
        .preferredColorScheme(ColorScheme.light) // Force light mode for consistency
    }
}

#Preview {
    VStack {
        Text("OperatorKit")
            .font(.largeTitle)
        Text("Consistent Light Background")
    }
    .okScreenBackground()
}
