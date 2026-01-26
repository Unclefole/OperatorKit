import SwiftUI

// ============================================================================
// REVIEWER QUICK PATH VIEW (Phase 10K)
//
// Read-only guide for App Store reviewers (2 minutes).
// Shows key screens without triggering execution or requesting permissions.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No execution triggers
// ❌ No automatic permission requests
// ❌ No behavior toggles
// ✅ Read-only navigation guide
// ✅ Clear "what to expect" documentation
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct ReviewerQuickPathView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Introduction
                introSection
                
                // Quick Path Steps
                quickPathSection
                
                // What NOT to Expect
                notExpectedSection
                
                // Safety Guarantees
                guaranteesSection
                
                // Testing Notes
                testingNotesSection
            }
            .navigationTitle("Reviewer Quick Path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Introduction
    
    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                    Text("Estimated time: 2 minutes")
                        .font(.headline)
                }
                
                Text("This guide shows the key screens a reviewer should see when testing OperatorKit.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        } header: {
            Text("For App Store Reviewers")
        }
    }
    
    // MARK: - Quick Path Steps
    
    private var quickPathSection: some View {
        Section {
            QuickPathStep(
                number: 1,
                title: "First Launch → Onboarding",
                description: "5 screens explaining safety model, data access, and pricing",
                icon: "1.circle.fill",
                color: .blue
            )
            
            QuickPathStep(
                number: 2,
                title: "Type a Request",
                description: "Enter 'Draft an email about tomorrow's meeting'",
                icon: "2.circle.fill",
                color: .blue
            )
            
            QuickPathStep(
                number: 3,
                title: "Review Draft",
                description: "See generated draft card with edit/cancel options",
                icon: "3.circle.fill",
                color: .blue
            )
            
            QuickPathStep(
                number: 4,
                title: "Approval Gate",
                description: "Confirm 'Run', 'Edit', or 'Cancel' dialog appears",
                icon: "4.circle.fill",
                color: .blue
            )
            
            QuickPathStep(
                number: 5,
                title: "Settings → Pricing",
                description: "View Free/Pro/Team tiers with restore option",
                icon: "5.circle.fill",
                color: .blue
            )
            
            QuickPathStep(
                number: 6,
                title: "Settings → Help Center",
                description: "FAQ, troubleshooting, contact support (opens Mail)",
                icon: "6.circle.fill",
                color: .blue
            )
            
            QuickPathStep(
                number: 7,
                title: "Settings → Privacy",
                description: "Permission states, safety guarantees list",
                icon: "7.circle.fill",
                color: .blue
            )
        } header: {
            Text("Quick Path (7 Steps)")
        } footer: {
            Text("Each step demonstrates a core feature. No account required.")
        }
    }
    
    // MARK: - What NOT to Expect
    
    private var notExpectedSection: some View {
        Section {
            NotExpectedRow(
                icon: "xmark.circle",
                text: "No automatic email sending",
                detail: "Drafts require explicit approval"
            )
            
            NotExpectedRow(
                icon: "xmark.circle",
                text: "No background processing",
                detail: "App only runs when open"
            )
            
            NotExpectedRow(
                icon: "xmark.circle",
                text: "No network prompts on launch",
                detail: "Network only used if sync enabled (opt-in)"
            )
            
            NotExpectedRow(
                icon: "xmark.circle",
                text: "No automatic permission requests",
                detail: "Permissions requested only when needed"
            )
            
            NotExpectedRow(
                icon: "xmark.circle",
                text: "No forced paywall",
                detail: "'Not Now' always available, free tier functional"
            )
            
            NotExpectedRow(
                icon: "xmark.circle",
                text: "No data collection popups",
                detail: "No analytics or tracking"
            )
        } header: {
            Text("What Reviewers Should NOT See")
        }
    }
    
    // MARK: - Safety Guarantees
    
    private var guaranteesSection: some View {
        Section {
            GuaranteeRow(text: "Every action requires explicit user approval")
            GuaranteeRow(text: "All processing happens on-device")
            GuaranteeRow(text: "No data sent to external servers without consent")
            GuaranteeRow(text: "Free tier is fully functional (with usage limits)")
            GuaranteeRow(text: "Restore purchases is accessible")
            GuaranteeRow(text: "Auto-renewal terms are disclosed")
        } header: {
            Text("Safety Guarantees")
        }
    }
    
    // MARK: - Testing Notes
    
    private var testingNotesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Subscription Testing")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Use sandbox account to test purchase flow. Restore purchases available in Settings → Subscription.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Permission Testing")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Permissions are requested only when needed (e.g., Calendar access when creating an event). Deny permissions to see graceful handling.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Contact Support")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Help Center → Contact Support opens Mail composer. User must manually tap Send. No auto-send.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Testing Notes")
        }
    }
}

// MARK: - Quick Path Step

private struct QuickPathStep: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Not Expected Row

private struct NotExpectedRow: View {
    let icon: String
    let text: String
    let detail: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.subheadline)
                
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Guarantee Row

private struct GuaranteeRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .foregroundColor(.green)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    ReviewerQuickPathView()
}
