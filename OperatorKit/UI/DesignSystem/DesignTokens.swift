import SwiftUI

// ============================================================================
// OPERATORKIT DESIGN SYSTEM v2.0
// Trust-First Interface — Apple × Palantir × Linear
//
// DESIGN PHILOSOPHY:
// OperatorKit is infrastructure, not entertainment.
// The interface signals: control, safety, intelligence, precision.
// ============================================================================

// MARK: - Color Tokens

public enum OKColors {

    // MARK: - Backgrounds

    /// Pure white background - #FFFFFF
    public static let backgroundPrimary = Color(hex: "FFFFFF")

    /// Card surfaces, subtle backgrounds - #F7F8FA
    public static let backgroundSecondary = Color(hex: "F7F8FA")

    /// Input field backgrounds - #F1F5F9
    public static let backgroundTertiary = Color(hex: "F1F5F9")

    /// Elevated surfaces (modals, floating elements) - #FFFFFF
    public static let backgroundElevated = Color(hex: "FFFFFF")

    // MARK: - Text

    /// Primary text - near-black #0B0B0C
    public static let textPrimary = Color(hex: "0B0B0C")

    /// Secondary text - #6B7280
    public static let textSecondary = Color(hex: "6B7280")

    /// Tertiary text (timestamps, metadata) - #94A3B8
    public static let textTertiary = Color(hex: "94A3B8")

    /// Placeholder text - #94A3B8
    public static let textPlaceholder = Color(hex: "94A3B8")

    // MARK: - Borders & Dividers

    /// Subtle borders - #E6E8EC
    public static let borderSubtle = Color(hex: "E6E8EC")

    /// Default borders - #E2E8F0
    public static let borderDefault = Color(hex: "E2E8F0")

    /// Focus state border - #5B8CFF
    public static let borderFocus = Color(hex: "5B8CFF")

    // MARK: - Accent (Operator Gradient)

    /// Gradient start - #2563EB (royal blue)
    public static let accentStart = Color(hex: "2563EB")

    /// Gradient end - #1E3A8A (navy blue)
    public static let accentEnd = Color(hex: "1E3A8A")

    // MARK: - Intelligence Card (Navy Blue → Medium Blue)

    /// Intelligence card gradient start - navy blue #1E3A8A
    public static let intelligenceStart = Color(red: 30/255, green: 58/255, blue: 138/255)

    /// Intelligence card gradient mid - royal blue #2563EB
    public static let intelligenceMid = Color(red: 37/255, green: 99/255, blue: 235/255)

    /// Intelligence card gradient end - medium blue #3B82F6
    public static let intelligenceEnd = Color(red: 59/255, green: 130/255, blue: 246/255)

    /// Intelligence card gradient - navy → royal blue
    public static var intelligenceGradient: LinearGradient {
        LinearGradient(
            colors: [intelligenceStart, intelligenceMid, intelligenceEnd],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Status Badges (Professional Muted)

    /// SENT status - green #10B981 (matches design comp)
    public static let statusSent = Color(red: 16/255, green: 185/255, blue: 129/255)
    public static let statusSentBackground = Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.12)

    /// APPROVED status - muted green #10B981 at 15%
    public static let statusApproved = Color(red: 16/255, green: 185/255, blue: 129/255)
    public static let statusApprovedBackground = Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.12)

    /// PENDING status - warm amber #F59E0B at 15%
    public static let statusPending = Color(red: 245/255, green: 158/255, blue: 11/255)
    public static let statusPendingBackground = Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.12)

    // MARK: - Quick Action Tints (Blue Family — Matches Design Comp)

    /// Meeting action - light blue
    public static let tintMeeting = Color(red: 37/255, green: 99/255, blue: 235/255).opacity(0.10)

    /// Email action - light royal blue
    public static let tintEmail = Color(red: 59/255, green: 130/255, blue: 246/255).opacity(0.10)

    /// Document action - light indigo-blue
    public static let tintDocument = Color(red: 99/255, green: 102/255, blue: 241/255).opacity(0.10)

    /// Meeting icon color - blue
    public static let iconMeeting = Color(red: 37/255, green: 99/255, blue: 235/255)

    /// Email icon color - royal blue
    public static let iconEmail = Color(red: 59/255, green: 130/255, blue: 246/255)

    /// Document icon color - indigo-blue
    public static let iconDocument = Color(red: 99/255, green: 102/255, blue: 241/255)

    /// Muted accent for backgrounds - 8% opacity
    public static let accentMuted = Color(hex: "5B8CFF", opacity: 0.08)

    /// Glow effect - 15% opacity
    public static let accentGlow = Color(hex: "5B8CFF", opacity: 0.15)

    // MARK: - Icons

    /// Primary icons - #6B7280
    public static let iconPrimary = Color(hex: "6B7280")

    /// Secondary icons (settings, navigation) - #9AA0A6
    public static let iconSecondary = Color(hex: "9AA0A6")

    /// Muted icons - #B8BCC4
    public static let iconMuted = Color(hex: "B8BCC4")

    // MARK: - Status (Muted)

    /// Success indicator - muted green
    public static let statusSuccess = Color(hex: "10B981")

    // MARK: - Operator Gradient

    /// The signature Operator gradient for action moments
    public static var operatorGradient: LinearGradient {
        LinearGradient(
            colors: [accentStart, accentEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Soft gradient for mic button (10-15% intensity)
    public static var operatorGradientSoft: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "5B8CFF", opacity: 0.12), Color(hex: "7C5CFF", opacity: 0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Premium home background gradient (Bloomberg meets Apple Intelligence)
    public static var premiumBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 245/255, green: 247/255, blue: 252/255),
                Color.white
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Solid blue gradient for floating mic (matches design comp)
    public static var premiumMicGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 37/255, green: 99/255, blue: 235/255),
                Color(red: 30/255, green: 58/255, blue: 138/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Typography Scale

public enum OKTypography {

    /// Large Title - 28pt Semibold
    public static func largeTitle() -> Font {
        .system(size: 28, weight: .semibold, design: .default)
    }

    /// Title - 22pt Semibold
    public static func title() -> Font {
        .system(size: 22, weight: .semibold, design: .default)
    }

    /// Headline - 17pt Semibold
    public static func headline() -> Font {
        .system(size: 17, weight: .semibold, design: .default)
    }

    /// Body - 16pt Regular
    public static func body() -> Font {
        .system(size: 16, weight: .regular, design: .default)
    }

    /// Callout - 15pt Regular
    public static func callout() -> Font {
        .system(size: 15, weight: .regular, design: .default)
    }

    /// Subheadline - 14pt Medium
    public static func subheadline() -> Font {
        .system(size: 14, weight: .medium, design: .default)
    }

    /// Footnote - 13pt Regular
    public static func footnote() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    /// Caption - 12pt Medium
    public static func caption() -> Font {
        .system(size: 12, weight: .medium, design: .default)
    }
}

// MARK: - Spacing Scale

public enum OKSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 24
    public static let xxxl: CGFloat = 32
}

// MARK: - Radius Scale

public enum OKRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let full: CGFloat = 9999
}

// MARK: - Shadows

public enum OKShadow {

    /// Subtle shadow for minimal elevation
    public static let subtle = Color.black.opacity(0.03)

    /// Card shadow
    public static let card = Color.black.opacity(0.04)

    /// Elevated shadow for hover/modals
    public static let elevated = Color.black.opacity(0.06)

    /// Glow shadow for mic button
    public static let glow = Color(hex: "5B8CFF", opacity: 0.12)
}

// MARK: - View Modifiers

public struct OKCardStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(OKColors.backgroundElevated)
            .cornerRadius(OKRadius.xl)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: OKRadius.xl)
                    .stroke(OKColors.borderSubtle, lineWidth: 1)
            )
    }
}

public struct OKInputFieldStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, OKSpacing.lg)
            .padding(.vertical, OKSpacing.lg)
            .background(OKColors.backgroundTertiary)
            .cornerRadius(OKRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: OKRadius.lg)
                    .stroke(OKColors.borderDefault, lineWidth: 1)
            )
    }
}

extension View {
    public func okCardStyle() -> some View {
        modifier(OKCardStyle())
    }

    public func okInputFieldStyle() -> some View {
        modifier(OKInputFieldStyle())
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    init(hex: String, opacity: Double) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: opacity
        )
    }
}
