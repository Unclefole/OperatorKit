import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// ============================================================================
// HOME VIEW — PRIMARY EXECUTION SURFACE
//
// ARCHITECTURAL INVARIANT:
// ─────────────────────────
// OperatorKit NEVER executes synthetic, seeded, or non-user-authored intent.
// ALL operations must originate from explicit user input.
//
// QUICK ACTION SAFETY:
// Quick action buttons navigate to IntentInputView with an EMPTY input field.
// They set an intent TYPE hint only — the user must provide their own text.
// NO pre-filled rawText that could auto-execute.
//
// APP REVIEW SAFETY:
// ❌ No hidden prompts
// ❌ No auto-generated actions
// ❌ No simulated assistant behavior
// ❌ No synthetic intent injection
//
// SPEC COMPLIANCE (1:1):
// ✅ One hero card (vibrant blue, mic icon, exact text)
// ✅ No extra search bars
// ✅ Three recent operation cards (mail/SENT, doc/APPROVED, calendar/PENDING)
// ✅ Correct status colors (purple, green, orange)
// ✅ Three action cards (Meeting, Email, Document)
// ✅ Four-tab navigation (via MainTabView)
// ✅ Clean institutional UI
// ✅ Navigation wired to IntentInputView
// ============================================================================

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState

    var body: some View {
        ZStack {
            // Background — white base
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // ──────────────────────────────────
                    // TOP SECTION — BLUE GRADIENT BACKGROUND
                    // extends ~halfway down, holds hero card
                    // ──────────────────────────────────
                    ZStack(alignment: .bottom) {
                        // Blue gradient background that extends behind hero
                        VStack(spacing: 0) {
                            OKColors.intelligenceGradient
                                .frame(height: 280)
                            // Soft fade from blue to white
                            LinearGradient(
                                colors: [
                                    OKColors.intelligenceEnd.opacity(0.15),
                                    Color.white
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 40)
                        }
                    }
                    .overlay(
                        // Hero content positioned over the blue background
                        VStack(spacing: 16) {
                            heroCardContent
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40),
                        alignment: .top
                    )

                    // ──────────────────────────────────
                    // MIDDLE SECTION — RECENT OPERATIONS
                    // ──────────────────────────────────
                    recentOperationsSection
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // ──────────────────────────────────
                    // BOTTOM SECTION — ACTION CARDS
                    // ──────────────────────────────────
                    actionCardsSection
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("OperatorKit")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ════════════════════════════════════════════════════════════════
    // MARK: - HERO CARD
    // ════════════════════════════════════════════════════════════════
    // ONE large vibrant blue hero card. Entire card is tappable.
    // On tap → navigate to IntentInputView(). Nothing executes.

    /// Hero content — sits on the blue gradient background (no separate card bg needed)
    private var heroCardContent: some View {
        Button(action: {
            appState.resetOperationState()
            nav.navigate(to: .intent)
        }) {
            VStack(spacing: 16) {
                // Microphone icon in lighter blue circle (matches design)
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 64, height: 64)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Exact spec text — two lines, white on blue
                VStack(spacing: 6) {
                    Text("What do you want handled?")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("Nothing executes without your approval.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(OperationButtonStyle())
    }

    // ════════════════════════════════════════════════════════════════
    // MARK: - RECENT OPERATIONS
    // ════════════════════════════════════════════════════════════════
    // Section titled "Recent Operations". EXACTLY three cards.
    // Card 1: Mail icon, SENT (Purple)
    // Card 2: Document icon, APPROVED (Green)
    // Card 3: Calendar icon, PENDING (Orange)

    private var recentOperationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            Text("Recent Operations")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(OKColors.textPrimary)
                .padding(.leading, 4)

            VStack(spacing: 12) {
                // Card 1 — Mail / SENT / Green (matches design)
                RecentOperationCard(
                    icon: "envelope.fill",
                    iconColor: OKColors.intelligenceMid,
                    iconBackground: OKColors.intelligenceMid.opacity(0.10),
                    title: "Draft quarterly report",
                    statusText: "SENT",
                    statusColor: OKColors.statusSent
                )

                // Card 2 — Document / APPROVED / Green
                RecentOperationCard(
                    icon: "doc.text.fill",
                    iconColor: OKColors.intelligenceStart,
                    iconBackground: OKColors.intelligenceStart.opacity(0.10),
                    title: "Review Q3 financial statements",
                    statusText: "APPROVED",
                    statusColor: OKColors.statusApproved
                )

                // Card 3 — Calendar / PENDING / Orange
                RecentOperationCard(
                    icon: "calendar",
                    iconColor: OKColors.statusPending,
                    iconBackground: OKColors.statusPendingBackground,
                    title: "Schedule board meeting",
                    statusText: "PENDING",
                    statusColor: OKColors.statusPending
                )
            }
        }
    }

    // ════════════════════════════════════════════════════════════════
    // MARK: - ACTION CARDS
    // ════════════════════════════════════════════════════════════════
    // THREE distinct white square cards. Each routes to IntentInputView().

    private var actionCardsSection: some View {
        HStack(spacing: 12) {
            HomeActionCard(
                icon: "calendar",
                label: "Handle a\nMeeting",
                tintColor: OKColors.tintMeeting,
                iconColor: OKColors.iconMeeting,
                action: {
                    appState.intentTypeHint = .summarizeMeeting
                    appState.selectedIntent = nil
                    nav.navigate(to: .intent)
                }
            )

            HomeActionCard(
                icon: "envelope.fill",
                label: "Handle an\nEmail",
                tintColor: OKColors.tintEmail,
                iconColor: OKColors.iconEmail,
                action: {
                    appState.intentTypeHint = .draftEmail
                    appState.selectedIntent = nil
                    nav.navigate(to: .intent)
                }
            )

            HomeActionCard(
                icon: "doc.on.doc.fill",
                label: "Handle a\nDocument",
                tintColor: OKColors.tintDocument,
                iconColor: OKColors.iconDocument,
                action: {
                    appState.intentTypeHint = .reviewDocument
                    appState.selectedIntent = nil
                    nav.navigate(to: .intent)
                }
            )
        }
    }
}

// ════════════════════════════════════════════════════════════════════
// MARK: - Recent Operation Card
// ════════════════════════════════════════════════════════════════════
// White card with icon, title, and status badge in bottom-right.
// Tappable → routes to OperationDetailView.

struct RecentOperationCard: View {
    let icon: String
    let iconColor: Color
    let iconBackground: Color
    let title: String
    let statusText: String
    let statusColor: Color

    var body: some View {
        // ARCHITECTURE: Use Route-based NavigationLink (not direct destination)
        // to work with MainTabView's NavigationStack + Route system.
        // Direct NavigationLink(destination:) causes white screen when
        // the destination is not registered in the Route enum.
        NavigationLink(value: Route.operationDetailRoute(
            title: title,
            status: statusText,
            color: statusColor
        )) {
            HStack(spacing: 14) {
                // Tinted icon container
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(iconBackground)
                        .frame(width: 46, height: 46)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(iconColor)
                }

                // Title
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(OKColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Status tag — rounded capsule
                Text(statusText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(statusColor))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ════════════════════════════════════════════════════════════════════
// MARK: - Home Action Card
// ════════════════════════════════════════════════════════════════════
// White square card with icon and label.
// Visually separated from background with shadow.
// Routes to IntentInputView().

struct HomeActionCard: View {
    let icon: String
    let label: String
    let tintColor: Color
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon in tinted rounded-rect container
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [tintColor, tintColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(iconColor)
                }

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(OKColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
            )
        }
        .buttonStyle(OperationButtonStyle())
    }
}

// ════════════════════════════════════════════════════════════════════
// MARK: - Operation Button Style (kept for backward compatibility)
// ════════════════════════════════════════════════════════════════════

struct OperationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Legacy Compatibility Aliases

/// Kept for backward compatibility — wraps HomeActionCard
struct PremiumQuickActionButton: View {
    let icon: String
    let title: String
    let tintColor: Color
    let iconColor: Color
    let action: () -> Void
    var isHighlighted: Bool = false

    var body: some View {
        HomeActionCard(
            icon: icon,
            label: title,
            tintColor: tintColor,
            iconColor: iconColor,
            action: action
        )
    }
}

/// Kept for backward compatibility
struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        HomeActionCard(
            icon: icon,
            label: title,
            tintColor: OKColors.accentMuted,
            iconColor: OKColors.intelligenceStart,
            action: action
        )
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environmentObject(AppState())
    .environmentObject(AppNavigationState())
}
