import SwiftUI

// ============================================================================
// OPERATORKIT DESIGN SYSTEM — MISSION CONTROL DARK THEME
// SINGLE SOURCE OF TRUTH. NO INLINE COLORS ANYWHERE ELSE.
//
// This is not a cosmetic layer. This is an enforcement surface.
// Every view in OperatorKit uses these tokens or FAILS review.
// ============================================================================

// MARK: - Unified Dark Theme Tokens

public enum OKColor {

    // ── Surfaces ─────────────────────────────────────────
    /// App root background — #0B0F14
    public static let backgroundPrimary = Color(hex: "0B0F14")
    /// Cards, panels, grouped content — #121821
    public static let backgroundSecondary = Color(hex: "121821")
    /// Elevated controls, popovers, modals — #18212B
    public static let backgroundTertiary = Color(hex: "18212B")

    // ── Borders ──────────────────────────────────────────
    /// Subtle card/section borders — #223041
    public static let borderSubtle = Color(hex: "223041")
    /// Strong/interactive borders — #2F4156
    public static let borderStrong = Color(hex: "2F4156")

    // ── Text ─────────────────────────────────────────────
    /// Primary text (titles, body) — #E6EDF3
    public static let textPrimary = Color(hex: "E6EDF3")
    /// Secondary text (descriptions) — #9FB0C3
    public static let textSecondary = Color(hex: "9FB0C3")
    /// Muted text (timestamps, metadata, labels) — #6B7C8F
    public static let textMuted = Color(hex: "6B7C8F")

    // ── Risk / Authority ─────────────────────────────────
    /// Nominal / success / safe — #00C853
    public static let riskNominal = Color(hex: "00C853")
    /// Operational / informational / blue — #3A86FF
    public static let riskOperational = Color(hex: "3A86FF")
    /// Warning / amber — #FFAB00
    public static let riskWarning = Color(hex: "FFAB00")
    /// Critical / red — #FF3B30
    public static let riskCritical = Color(hex: "FF3B30")
    /// Extreme / purple — #7C4DFF
    public static let riskExtreme = Color(hex: "7C4DFF")

    // ── Controls ─────────────────────────────────────────
    /// Emergency stop — #FF453A
    public static let emergencyStop = Color(hex: "FF453A")
    /// Primary action buttons — #4C8DFF
    public static let actionPrimary = Color(hex: "4C8DFF")
    /// Escalation — #FF9F0A
    public static let escalate = Color(hex: "FF9F0A")

    // ── Utility ──────────────────────────────────────────
    /// Shadow color for dark theme cards
    public static let shadow = Color(hex: "000000")
    /// Overlay/scrim for modals
    public static let overlay = Color(hex: "000000")
    /// Bright white for icon tints on colored backgrounds
    public static let iconOnColor = Color(hex: "FFFFFF")
}

// MARK: - Legacy Aliases (OKDark → OKColor)

public enum OKDark {
    public static let backgroundPrimary = OKColor.backgroundPrimary
    public static let backgroundSecondary = OKColor.backgroundSecondary
    public static let cardBackground = OKColor.backgroundSecondary
    public static let textPrimary = OKColor.textPrimary
    public static let textSecondary = OKColor.textSecondary
    public static let textTertiary = OKColor.textMuted
    public static let borderSubtle = OKColor.borderSubtle
    public static let borderDefault = OKColor.borderStrong
    public static let accent = OKColor.actionPrimary
    public static let accentPurple = OKColor.riskExtreme
}

// MARK: - Legacy Aliases (OKColors → OKColor)

public enum OKColors {
    public static let backgroundPrimary = OKColor.backgroundPrimary
    public static let backgroundSecondary = OKColor.backgroundSecondary
    public static let backgroundTertiary = OKColor.backgroundTertiary
    public static let backgroundElevated = OKColor.backgroundTertiary
    public static let textPrimary = OKColor.textPrimary
    public static let textSecondary = OKColor.textSecondary
    public static let textTertiary = OKColor.textMuted
    public static let textPlaceholder = OKColor.textMuted
    public static let borderSubtle = OKColor.borderSubtle
    public static let borderDefault = OKColor.borderSubtle
    public static let borderFocus = OKColor.actionPrimary
    public static let accentStart = OKColor.actionPrimary
    public static let accentEnd = OKColor.actionPrimary
    public static let intelligenceStart = OKColor.actionPrimary
    public static let intelligenceEnd = OKColor.riskExtreme
    public static let intelligenceGradient = LinearGradient(
        colors: [OKColor.actionPrimary, OKColor.riskExtreme],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    public static let operatorGradient = LinearGradient(
        colors: [OKColor.actionPrimary, OKColor.riskExtreme],
        startPoint: .leading,
        endPoint: .trailing
    )
    public static let statusSuccess = OKColor.riskNominal
    public static let statusWarning = OKColor.riskWarning
    public static let statusError = OKColor.riskCritical
    public static let statusInfo = OKColor.riskOperational
    public static let safetyGreen = OKColor.riskNominal
    public static let safetyAmber = OKColor.riskWarning
    public static let safetyRed = OKColor.riskCritical
    public static let statusPending = OKColor.riskWarning
    public static let statusPendingBackground = OKColor.riskWarning.opacity(0.15)
    public static let statusSent = OKColor.riskNominal
    public static let statusApproved = OKColor.riskNominal
    public static let intelligenceMid = OKColor.riskExtreme
    public static let tintMeeting = OKColor.riskOperational.opacity(0.12)
    public static let iconMeeting = OKColor.riskOperational
    public static let accentMuted = OKColor.actionPrimary.opacity(0.12)
    public static let tintEmail = OKColor.riskNominal.opacity(0.12)
    public static let iconEmail = OKColor.riskNominal
    public static let tintDocument = OKColor.riskWarning.opacity(0.12)
    public static let iconDocument = OKColor.riskWarning
    public static let iconMuted = OKColor.textMuted
    public static let operatorGradientSoft = LinearGradient(
        colors: [OKColor.actionPrimary.opacity(0.15), OKColor.riskExtreme.opacity(0.15)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    public static let trustSurface = OKColor.backgroundSecondary
    public static let trustBorder = OKColor.borderSubtle
    public static let trustText = OKColor.textSecondary
}

// MARK: - Typography

public enum OKTypography {
    public static func largeTitle() -> Font {
        .system(size: 28, weight: .bold)
    }
    public static func title() -> Font {
        .system(size: 22, weight: .bold)
    }
    public static func headline() -> Font {
        .system(size: 17, weight: .semibold)
    }
    public static func sectionHeader() -> Font {
        .system(size: 13, weight: .semibold)
    }
    public static func body() -> Font {
        .system(size: 15, weight: .regular)
    }
    public static func bodySemibold() -> Font {
        .system(size: 15, weight: .semibold)
    }
    public static func subheadline() -> Font {
        .system(size: 15, weight: .regular)
    }
    public static func caption() -> Font {
        .system(size: 12, weight: .regular)
    }
}

// MARK: - Spacing + Radius + Shadow

public enum OKSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
}

public enum OKRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let full: CGFloat = 999
    // Semantic aliases
    public static let small: CGFloat = sm
    public static let card: CGFloat = 14
    public static let button: CGFloat = 10
}

public enum OKShadow {
    public static let sm = OKColor.shadow.opacity(0.15)
    public static let md = OKColor.shadow.opacity(0.25)
    public static let lg = OKColor.shadow.opacity(0.35)
    public static let card = OKColor.shadow.opacity(0.2)
    public static let glow = OKColor.actionPrimary.opacity(0.3)
}

// MARK: - Card Modifiers

public struct OKCardModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(16)
            .background(OKColor.backgroundSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(OKColor.borderSubtle, lineWidth: 1)
            )
            .cornerRadius(14)
    }
}

public struct OKCardElevatedModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(16)
            .background(OKColor.backgroundTertiary)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(OKColor.borderStrong, lineWidth: 1)
            )
            .cornerRadius(14)
    }
}

extension View {
    public func okCard() -> some View {
        modifier(OKCardModifier())
    }
    public func okCardElevated() -> some View {
        modifier(OKCardElevatedModifier())
    }
}

// MARK: - Section Header Style

public struct OKSectionHeader: View {
    let title: String
    public init(_ title: String) { self.title = title }
    public var body: some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(OKColor.textMuted)
            .tracking(1.0)
    }
}

// MARK: - Button Styles

/// Primary action button — dark theme, actionPrimary background
struct OKPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(OKColor.actionPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.18), value: configuration.isPressed)
    }
}

/// Emergency action button — emergencyStop background with glow
struct OKEmergencyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(OKColor.emergencyStop)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: OKColor.emergencyStop.opacity(0.35), radius: 10)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.18), value: configuration.isPressed)
    }
}

// MARK: - Color(hex:) Initializer

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
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
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
