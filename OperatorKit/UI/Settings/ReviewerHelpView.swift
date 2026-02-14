import SwiftUI

/// In-app help screen for App Store reviewers (Phase 6B)
/// This view is accessible in production builds and provides a quick overview
/// of what the app does and how to test it
struct ReviewerHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingDataUseDisclosure: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Introduction
                    introSection
                    
                    Divider()
                    
                    // Quick Test Plan
                    testPlanSection
                    
                    Divider()
                    
                    // Key Guarantees Summary
                    guaranteesSection
                    
                    Divider()
                    
                    // Common Questions
                    faqSection
                    
                    Divider()
                    
                    // Links
                    linksSection
                }
                .padding(20)
            }
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Reviewer Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDataUseDisclosure) {
                DataUseDisclosureView()
            }
        }
    }
    
    // MARK: - Introduction
    
    private var introSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "person.badge.shield.checkmark")
                    .font(.system(size: 24))
                    .foregroundColor(OKColor.actionPrimary)
                
                Text("For App Reviewers")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text("OperatorKit is an on-device task assistant. It helps users draft emails, create reminders, and manage calendar events. All processing happens locally—nothing is sent to external servers.")
                .font(.body)
                .foregroundColor(OKColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Key point callout
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield")
                    .foregroundColor(OKColor.riskNominal)
                Text("No action is taken without explicit user approval")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(12)
            .background(OKColor.riskNominal.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Test Plan Section
    
    private var testPlanSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "2-Minute Test Plan", icon: "checklist")
            
            testStep(
                number: 1,
                title: "Test Siri Route",
                duration: "30 sec",
                steps: [
                    "Say: \"Hey Siri, ask OperatorKit to draft an email\"",
                    "Verify: App opens with text pre-filled",
                    "Verify: Banner shows \"Siri Started This Request\"",
                    "Verify: User must acknowledge before continuing"
                ],
                expected: "No action is taken until user taps Continue"
            )
            
            testStep(
                number: 2,
                title: "Test Calendar Read",
                duration: "30 sec",
                steps: [
                    "Open app and enter a request",
                    "Tap Continue to reach Context Picker",
                    "Grant calendar permission when prompted",
                    "Select 1-2 calendar events"
                ],
                expected: "Only selected events appear in the draft"
            )
            
            testStep(
                number: 3,
                title: "Test Reminder Write",
                duration: "30 sec",
                steps: [
                    "Complete flow to Approval screen",
                    "Enable \"Create Reminder\" toggle",
                    "Tap \"Approve & Execute\"",
                    "Verify: Confirmation modal appears",
                    "Tap \"Confirm Create\""
                ],
                expected: "Two distinct confirmation steps required"
            )
            
            testStep(
                number: 4,
                title: "Test Email Draft",
                duration: "20 sec",
                steps: [
                    "Complete flow to Execution Complete",
                    "Tap \"Open Email Composer\"",
                    "Verify: Mail app opens with content"
                ],
                expected: "User must manually tap Send in Mail"
            )
            
            testStep(
                number: 5,
                title: "Test Memory Audit",
                duration: "10 sec",
                steps: [
                    "Go to Memory tab",
                    "Select any completed operation",
                    "Review Trust Summary section"
                ],
                expected: "Complete audit trail of what was done"
            )
        }
    }
    
    // MARK: - Guarantees Section
    
    private var guaranteesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Execution Guarantees", icon: "shield.checkered")
            
            guaranteeRow(
                icon: "doc.text",
                title: "Draft-First",
                description: "Every action produces a draft for user review before execution"
            )
            
            guaranteeRow(
                icon: "hand.raised",
                title: "Approval Required",
                description: "No execution without explicit user approval"
            )
            
            guaranteeRow(
                icon: "lock.shield",
                title: "Two-Key Writes",
                description: "Creating reminders or calendar events requires a second confirmation"
            )
            
            guaranteeRow(
                icon: "mic.badge.xmark",
                title: "Siri Routes Only",
                description: "Siri opens the app but cannot execute actions or access data"
            )
            
            guaranteeRow(
                icon: "iphone",
                title: "On-Device Processing",
                description: "All text generation happens locally. No data is sent externally."
            )
            
            guaranteeRow(
                icon: "moon.stars",
                title: "No Background Access",
                description: "OperatorKit has no background modes enabled"
            )
        }
    }
    
    // MARK: - FAQ Section
    
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Common Questions", icon: "questionmark.circle")
            
            faqItem(
                question: "Does it send email automatically?",
                answer: "No. OperatorKit opens the system Mail composer. The user must manually tap Send."
            )
            
            faqItem(
                question: "Does it read calendar in the background?",
                answer: "No. Calendar access only occurs when the user opens Context Picker and selects events."
            )
            
            faqItem(
                question: "Does it upload data?",
                answer: "No. All processing is on-device. There is no analytics, telemetry, or cloud sync."
            )
            
            faqItem(
                question: "Does it auto-create reminders?",
                answer: "No. Creating reminders requires user approval plus a second confirmation step."
            )
            
            faqItem(
                question: "Can Siri execute actions?",
                answer: "No. Siri only opens the app and pre-fills text. All approvals are still required."
            )
        }
    }
    
    // MARK: - Links Section
    
    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "More Information", icon: "link")
            
            Button(action: {
                showingDataUseDisclosure = true
            }) {
                linkRow(
                    icon: "doc.text.magnifyingglass",
                    title: "Full Data Use Disclosure",
                    subtitle: "Complete explanation of data practices"
                )
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(OKColor.actionPrimary)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
    
    private func testStep(number: Int, title: String, duration: String, steps: [String], expected: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(OKColor.actionPrimary)
                        .frame(width: 28, height: 28)
                    
                    Text("\(number)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(OKColor.textPrimary)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(duration)
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(OKColor.textMuted.opacity(0.1))
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(steps, id: \.self) { step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(OKColor.textSecondary)
                        Text(step)
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 36)
            
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(OKColor.riskNominal)
                Text("Expected: \(expected)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(OKColor.riskNominal)
            }
            .padding(.leading, 36)
        }
        .padding(12)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(10)
    }
    
    private func guaranteeRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(OKColor.actionPrimary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(answer)
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(8)
    }
    
    private func linkRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(OKColor.actionPrimary)
                .frame(width: 40, height: 40)
                .background(OKColor.actionPrimary.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(OKColor.textPrimary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(OKColor.textMuted)
        }
        .padding(12)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(10)
    }
}

// MARK: - Preview

#Preview {
    ReviewerHelpView()
}
