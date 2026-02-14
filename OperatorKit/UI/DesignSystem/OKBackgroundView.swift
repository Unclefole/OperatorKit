import SwiftUI

// MARK: - OperatorKit Background View
/// Consistent adaptive background for all OperatorKit screens.
/// Automatically adapts to Light Mode and Dark Mode via OKColor tokens.

public struct OKBackgroundView: View {

    public init() {}

    public var body: some View {
        OKColor.backgroundPrimary
            .ignoresSafeArea()
    }
}

// MARK: - View Extension for Easy Application

public extension View {
    /// Apply the standard OperatorKit adaptive background
    /// - Parameter isHome: Set to true for Home screen (uses its own styling)
    func okScreenBackground(isHome: Bool = false) -> some View {
        ZStack {
            if isHome {
                // Home uses its own background - don't override
                self
            } else {
                OKBackgroundView()
                self
            }
        }
    }
}

#Preview("Light") {
    VStack {
        Text("OperatorKit")
            .font(.largeTitle)
            .foregroundColor(OKColor.textPrimary)
        Text("Adaptive Background")
            .foregroundColor(OKColor.textSecondary)
    }
    .okScreenBackground()
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack {
        Text("OperatorKit")
            .font(.largeTitle)
            .foregroundColor(OKColor.textPrimary)
        Text("Adaptive Background")
            .foregroundColor(OKColor.textSecondary)
    }
    .okScreenBackground()
    .preferredColorScheme(.dark)
}
