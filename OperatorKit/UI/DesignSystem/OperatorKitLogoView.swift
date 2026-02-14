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
// Uses the OperatorKitLogo image from Assets.xcassets (the shield + mic mark).
// Falls back to the programmatic gradient icon if the asset is missing.
// ============================================================================

struct OperatorKitLogoView: View {

    enum Size {
        case small
        case medium
        case large
        case hero

        var dimension: CGFloat {
            switch self {
            case .small: return 28
            case .medium: return 36
            case .large: return 48
            case .hero: return 56
            }
        }

        var textSize: CGFloat {
            switch self {
            case .small: return 15
            case .medium: return 17
            case .large: return 20
            case .hero: return 22
            }
        }

        var fallbackIconSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 24
            case .hero: return 28
            }
        }
    }

    let size: Size
    let showText: Bool
    /// Override text color (useful when logo sits on a colored background)
    let textColor: Color?

    init(size: Size = .medium, showText: Bool = false, textColor: Color? = nil) {
        self.size = size
        self.showText = showText
        self.textColor = textColor
    }

    var body: some View {
        HStack(spacing: 10) {
            // Logo image from asset catalog
            Image("OperatorKitLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: size.dimension)

            if showText {
                Text("OperatorKit")
                    .font(.system(size: size.textSize, weight: .bold))
                    .foregroundColor(textColor ?? OKColor.textPrimary)
            }
        }
        .accessibilityLabel("OperatorKit")
    }
}

#Preview("Light") {
    OperatorKitLogoView(size: .hero, showText: true)
        .padding()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    OperatorKitLogoView(size: .hero, showText: true)
        .padding()
        .background(OKColor.backgroundPrimary)
        .preferredColorScheme(.dark)
}
