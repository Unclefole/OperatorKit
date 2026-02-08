import SwiftUI

// ============================================================================
// DETERMINISTIC NAVIGATION ROW
//
// RELIABILITY INVARIANT: Every tappable row MUST have a deterministic action.
// This wrapper enforces that pattern and makes inert UI impossible to ship.
//
// In DEBUG builds, an empty action triggers assertionFailure.
// In RELEASE builds, the row is automatically disabled with reduced opacity.
// ============================================================================

/// A navigation row that enforces deterministic tap behavior
/// Use this for any list row that should navigate somewhere
struct DeterministicNavigationRow<Content: View>: View {
    let action: (() -> Void)?
    let content: () -> Content

    /// Creates a navigation row with a required action
    /// - Parameters:
    ///   - action: The navigation action. Pass nil to explicitly disable the row.
    ///   - content: The row content
    init(
        action: (() -> Void)?,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.action = action
        self.content = content

        #if DEBUG
        // INVARIANT: In DEBUG, catch nil actions at initialization time
        if action == nil {
            assertionFailure("""
            ⚠️ RELIABILITY VIOLATION: DeterministicNavigationRow created without action.
            Either:
            1. Provide a navigation action
            2. Use .disabled(true) on a regular Button if intentionally disabled
            This assertion helps prevent shipping inert UI.
            """)
        }
        #endif
    }

    var body: some View {
        if let action = action {
            Button(action: action) {
                content()
            }
        } else {
            // In RELEASE: show disabled state instead of crash
            Button(action: {}) {
                content()
            }
            .disabled(true)
            .opacity(0.4)
        }
    }
}

/// A chevron navigation row with enforced action
/// Convenience wrapper for common navigation row pattern
struct ChevronNavigationRow<Content: View>: View {
    let action: (() -> Void)?
    let content: () -> Content

    init(
        action: (() -> Void)?,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.action = action
        self.content = content

        #if DEBUG
        if action == nil {
            assertionFailure("""
            ⚠️ RELIABILITY VIOLATION: ChevronNavigationRow created without action.
            Navigation rows with chevrons MUST navigate somewhere.
            """)
        }
        #endif
    }

    var body: some View {
        DeterministicNavigationRow(action: action) {
            HStack {
                content()
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.4))
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DeterministicNavigationRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Valid row with action
            DeterministicNavigationRow(action: { print("Tapped") }) {
                Text("Valid Row")
                    .padding()
            }

            // Chevron row
            ChevronNavigationRow(action: { print("Navigate") }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .padding()
            }
        }
        .padding()
    }
}
#endif
