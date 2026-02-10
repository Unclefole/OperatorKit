import SwiftUI

// MARK: - OperatorKit Background View
/// Consistent dark background for all OperatorKit screens
/// Uses the design token system for the unified mission-control aesthetic.

public struct OKBackgroundView: View {

    public init() {}

    public var body: some View {
        OKColor.backgroundPrimary
            .ignoresSafeArea()
    }
}

// MARK: - View Extension for Easy Application

public extension View {
    /// Apply the standard OperatorKit dark background
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
        .preferredColorScheme(.dark)
    }
}

#Preview {
    VStack {
        Text("OperatorKit")
            .font(.largeTitle)
            .foregroundColor(OKColor.textPrimary)
        Text("Consistent Dark Background")
            .foregroundColor(OKColor.textSecondary)
    }
    .okScreenBackground()
}
