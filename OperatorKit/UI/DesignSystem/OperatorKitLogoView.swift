import SwiftUI

// ============================================================================
// OPERATOR KIT LOGO VIEW — PURE VISUAL COMPONENT
// ============================================================================
// This is a VISUAL-ONLY component. It does NOT contain navigation logic.
// To make it tappable for "go home", wrap it in a Button at the header level:
//
//   Button(action: { nav.goHome() }) {
//       OperatorKitLogoView()
//   }
//
// Uses the OperatorKitLogo image from Assets.xcassets.
// The logo image ALREADY contains the "OperatorKit" wordmark — do NOT add
// a separate Text("OperatorKit") beside it or the name will repeat.
// ============================================================================

struct OperatorKitLogoView: View {

    enum Size {
        case small
        case medium
        case large
        case hero

        /// Height of the logo image (the logo includes the wordmark)
        var height: CGFloat {
            switch self {
            case .small: return 28
            case .medium: return 36
            case .large: return 48
            case .hero: return 56
            }
        }
    }

    let size: Size

    init(size: Size = .medium) {
        self.size = size
    }

    /// Legacy initializer — showText and textColor are ignored because the
    /// logo image already contains the "OperatorKit" wordmark.
    init(size: Size = .medium, showText: Bool = false, textColor: Color? = nil) {
        self.size = size
    }

    var body: some View {
        Image("OperatorKitLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: size.height)
            .accessibilityLabel("OperatorKit")
    }
}

#Preview("Light") {
    OperatorKitLogoView(size: .hero)
        .padding()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    OperatorKitLogoView(size: .hero)
        .padding()
        .background(OKColor.backgroundPrimary)
        .preferredColorScheme(.dark)
}
