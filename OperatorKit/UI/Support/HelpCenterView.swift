import SwiftUI
import MessageUI

// ============================================================================
// HELP CENTER VIEW (Phase 10I)
//
// In-app support and FAQ. App Store safe, no auto-send.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No auto-send emails
// ❌ No new permissions
// ❌ No analytics
// ✅ User-initiated contact only
// ✅ Plain language FAQ
// ✅ Apple refund flow instructions (no promises)
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct HelpCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingMailComposer = false
    @State private var showingMailError = false
    @State private var expandedFAQ: String?
    @State private var showingKnownLimitations = false  // Phase 10Q
    @State private var showingSupportExport = false  // Phase 10Q
    @State private var showingSafeReset = false  // Phase 10Q
    
    var body: some View {
        NavigationView {
            List {
                // FAQ Section
                faqSection
                
                // Known Limitations Section (Phase 10Q)
                knownLimitationsSection
                
                // Troubleshooting Section
                troubleshootingSection
                
                // Contact Section
                contactSection
                
                // Support Export Section (Phase 10Q)
                supportExportSection
                
                // Data Management Section (Phase 10Q)
                dataManagementSection
                
                // Refund Section
                refundSection
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingMailComposer) {
                MailComposerView(
                    subject: SupportCopy.emailSubjectTemplate,
                    body: SupportCopy.emailBodyWithDeviceInfo(),
                    recipient: SupportCopy.supportEmail
                )
            }
            .alert("Cannot Send Email", isPresented: $showingMailError) {
                Button("OK") {}
            } message: {
                Text("Please configure an email account in Settings, or email us at \(SupportCopy.supportEmail)")
            }
            .sheet(isPresented: $showingKnownLimitations) {
                KnownLimitationsView()
            }
            .sheet(isPresented: $showingSupportExport) {
                SupportExportView()
            }
            .sheet(isPresented: $showingSafeReset) {
                SafeResetView()
            }
        }
    }
    
    // MARK: - Known Limitations Section (Phase 10Q)
    
    private var knownLimitationsSection: some View {
        Section {
            Button {
                showingKnownLimitations = true
            } label: {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Known Limitations")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text("What OperatorKit does not do")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Capabilities")
        }
    }
    
    // MARK: - Support Export Section (Phase 10Q)
    
    private var supportExportSection: some View {
        Section {
            Button {
                showingSupportExport = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export Support Packet")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text("Share diagnostic info with support")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Support Tools")
        } footer: {
            Text("Export contains metadata only. No user content is included.")
        }
    }
    
    // MARK: - Data Management Section (Phase 10Q)
    
    private var dataManagementSection: some View {
        Section {
            Button {
                showingSafeReset = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset Data")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text("Clear local data with confirmation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Data Management")
        }
    }
    
    // MARK: - FAQ Section
    
    private var faqSection: some View {
        Section {
            ForEach(SupportCopy.faqItems, id: \.question) { item in
                FAQRow(
                    item: item,
                    isExpanded: expandedFAQ == item.question,
                    onTap: {
                        withAnimation {
                            if expandedFAQ == item.question {
                                expandedFAQ = nil
                            } else {
                                expandedFAQ = item.question
                            }
                        }
                    }
                )
            }
        } header: {
            Text("Frequently Asked Questions")
        }
    }
    
    // MARK: - Troubleshooting Section
    
    private var troubleshootingSection: some View {
        Section {
            NavigationLink {
                TroubleshootingDetailView(topic: .permissions)
            } label: {
                Label("Permissions Denied", systemImage: "lock.shield")
            }
            
            NavigationLink {
                TroubleshootingDetailView(topic: .siri)
            } label: {
                Label("Siri & Shortcuts", systemImage: "mic")
            }
            
            NavigationLink {
                TroubleshootingDetailView(topic: .restore)
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
            }
            
            NavigationLink {
                TroubleshootingDetailView(topic: .sync)
            } label: {
                Label("Sync Issues", systemImage: "icloud.slash")
            }
        } header: {
            Text("Troubleshooting")
        }
    }
    
    // MARK: - Contact Section
    
    private var contactSection: some View {
        Section {
            Button {
                if PermissionManager.shared.canSendMail {
                    showingMailComposer = true
                } else {
                    showingMailError = true
                }
            } label: {
                Label("Contact Support", systemImage: "envelope")
            }
            
            Link(destination: URL(string: SupportCopy.documentationURL)!) {
                Label("Documentation", systemImage: "book")
            }
        } header: {
            Text("Get Help")
        } footer: {
            Text("We typically respond within 24-48 hours.\n\(SupportCopy.supportEmail)")
        }
    }
    
    // MARK: - Refund Section
    
    private var refundSection: some View {
        Section {
            NavigationLink {
                RefundInstructionsView()
            } label: {
                Label("Request a Refund", systemImage: "dollarsign.arrow.circlepath")
            }
        } header: {
            Text("Purchases")
        } footer: {
            Text("Refunds are processed by Apple, not by us directly.")
        }
    }
}

// MARK: - FAQ Row

private struct FAQRow: View {
    let item: FAQItem
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onTap) {
                HStack {
                    Text(item.question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }
            
            if isExpanded {
                Text(item.answer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Troubleshooting Detail

private struct TroubleshootingDetailView: View {
    enum Topic {
        case permissions
        case siri
        case restore
        case sync
    }
    
    let topic: Topic
    
    var body: some View {
        List {
            Section {
                ForEach(steps, id: \.self) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(steps.firstIndex(of: step)! + 1).")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text(step)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text(title)
            } footer: {
                Text(footer)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var title: String {
        switch topic {
        case .permissions: return "Permissions"
        case .siri: return "Siri & Shortcuts"
        case .restore: return "Restore Purchases"
        case .sync: return "Sync Issues"
        }
    }
    
    private var steps: [String] {
        switch topic {
        case .permissions:
            return SupportCopy.troubleshootingPermissions
        case .siri:
            return SupportCopy.troubleshootingSiri
        case .restore:
            return SupportCopy.troubleshootingRestore
        case .sync:
            return SupportCopy.troubleshootingSync
        }
    }
    
    private var footer: String {
        "If these steps don't help, please contact support."
    }
}

// MARK: - Refund Instructions

private struct RefundInstructionsView: View {
    var body: some View {
        List {
            Section {
                Text(SupportCopy.refundInstructions)
                    .font(.subheadline)
            } header: {
                Text("How to Request a Refund")
            }
            
            Section {
                Link(destination: URL(string: "https://reportaproblem.apple.com")!) {
                    Label("Report a Problem (Apple)", systemImage: "arrow.up.right")
                }
            } header: {
                Text("Apple Support")
            } footer: {
                Text("Refund requests are reviewed and processed by Apple. We cannot guarantee or expedite refunds.")
            }
        }
        .navigationTitle("Refunds")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Mail Composer

struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let recipient: String
    
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([recipient])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView
        
        init(_ parent: MailComposerView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    HelpCenterView()
}
