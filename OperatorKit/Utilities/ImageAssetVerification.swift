import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// ============================================================================
// IMAGE ASSET VERIFICATION (DEBUG-ONLY)
//
// OperatorKit uses ONLY SF Symbols (system-provided icons).
// No custom image assets exist in Assets.xcassets.
//
// DEBUG-only verification ensures invalid SF Symbols are detected early
// without crashing app initialization.
// ============================================================================

// MARK: - SF Symbol Verification

#if DEBUG
@MainActor
public enum SFSymbolVerifier {

   /// All SF Symbols used in OperatorKit (iOS 16+ safe)
   public static let usedSymbols: Set<String> = [

       // Core UI
       "chevron.left", "chevron.right", "xmark", "xmark.circle.fill",
       "checkmark", "checkmark.circle", "checkmark.circle.fill",
       "plus", "plus.circle.fill", "minus.circle",

       // Security & Trust
       "shield.fill", "shield.lefthalf.filled", "shield.slash",
       "lock.fill", "lock.circle.fill", "lock.doc.fill",
       "checkmark.shield.fill",
       "exclamationmark.shield.fill",
       "key.fill",

       // Documents & Export
       "doc.fill", "doc.text", "doc.text.fill",
       "doc.on.clipboard", "doc.on.doc.fill",
       "shippingbox", "shippingbox.fill",
       "archivebox", "archivebox.fill",
       "square.and.arrow.up",

       // Communication
       "envelope.fill", "envelope.open",
       "bell", "bell.fill",

       // Calendar & Time
       "calendar", "calendar.badge.clock",
       "clock", "clock.fill",

       // System & Settings
       "gearshape", "gearshape.fill",
       "cpu", "brain",
       "slider.horizontal.3",

       // Status & Indicators
       "circle", "circle.fill",
       "exclamationmark.circle.fill",
       "exclamationmark.triangle.fill",
       "info.circle.fill",
       "questionmark.circle",

       // Navigation & Actions
       "arrow.right", "arrow.right.circle",
       "arrow.clockwise", "arrow.counterclockwise",
       "magnifyingglass", "ellipsis",

       // People & Teams
       "person.fill", "person.circle.fill",
       "person.3.fill", "person.badge.plus",

       // Media & Input
       "mic.fill", "play.fill", "play.circle.fill",

       // Misc
       "airplane.circle.fill",
       "star.fill", "star.circle.fill",
       "hand.raised.fill", "hand.tap.fill",
       "pin.fill", "pin.circle.fill",
       "trash", "tray",
       "paperclip", "link",
       "pencil.circle.fill",
       "eye.fill", "eye.slash",
       "bolt", "sparkles", "flame.fill",
       "lightbulb", "gift", "graduationcap",
       "building.2", "briefcase.fill", "creditcard",
       "chart.bar", "chart.line.uptrend.xyaxis",
       "checklist", "list.bullet",
       "icloud", "icloud.and.arrow.up", "icloud.slash",
       "network.slash",
       "infinity.circle",
       "apple.logo",
       "ant.fill",
       "mappin.and.ellipse",
       "rectangle.portrait.and.arrow.right",
       "square.split.2x1",
       "seal", "book.closed"
   ]

   /// Verify a single SF Symbol (used by VerifiedSystemImage)
   public static func verify(
       _ symbolName: String,
       file: StaticString = #file,
       line: UInt = #line
   ) {
       #if canImport(UIKit)
       assert(
           UIImage(systemName: symbolName) != nil,
           "❌ MISSING SF SYMBOL: \(symbolName)",
           file: file,
           line: line
       )
       #endif
   }

   /// Verify all known symbols at app launch (DEBUG only)
   public static func verifyAllUsedSymbols() {
       print("🔍 [DEBUG] Verifying \(usedSymbols.count) SF Symbols…")

       #if canImport(UIKit)
       let invalid = usedSymbols.filter { UIImage(systemName: $0) == nil }

       if !invalid.isEmpty {
           print("❌ [DEBUG] INVALID SF SYMBOLS DETECTED:")
           invalid.forEach { print("   • \($0)") }
       } else {
           print("✅ [DEBUG] All SF Symbols verified")
       }
       #endif
   }
}
#endif

// MARK: - Verified System Image (DEBUG)

#if DEBUG
public struct VerifiedSystemImage: View {
   let name: String

   public init(
       _ name: String,
       file: StaticString = #file,
       line: UInt = #line
   ) {
       self.name = name
       SFSymbolVerifier.verify(name, file: file, line: line)
   }

   public var body: some View {
       Image(systemName: name)
   }
}
#endif

// MARK: - Asset Catalog Verification

#if DEBUG
@MainActor
public enum AssetCatalogVerifier {

   public static func verifyCriticalAssets() {
       print("🔍 [DEBUG] Verifying asset catalog…")

       #if canImport(UIKit)
       if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] {
           print("✅ [DEBUG] App icon configured: \(icons)")
       } else {
           print("⚠️ [DEBUG] No explicit CFBundleIcons found (asset catalog expected)")
       }
       #endif

       print("✅ [DEBUG] Asset catalog verification complete (SF Symbols only)")
   }
}
#endif
