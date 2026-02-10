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
// ============================================================================

struct OperatorKitLogoView: View {

    enum Size {
        case small
        case medium
        case large
        case extraLarge

        var dimension: CGFloat {
            switch self {
            case .small: return 24
            case .medium: return 32
            case .large: return 48
            case .extraLarge: return 64
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 24
            case .extraLarge: return 32
            }
        }
    }

    let size: Size
    let showText: Bool

    init(size: Size = .medium, showText: Bool = false) {
        self.size = size
        self.showText = showText
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(OKColors.operatorGradient)
                    .frame(width: size.dimension, height: size.dimension)

                Image(systemName: "mic.fill")
                    .font(.system(size: size.iconSize, weight: .medium))
                    .foregroundColor(OKColor.textPrimary)
            }

            if showText {
                Text("OperatorKit")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(OKColor.textPrimary)
            }
        }
        .accessibilityLabel("OperatorKit")
    }
}
