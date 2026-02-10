import SwiftUI

// ============================================================================
// PILOT MODE VIEW (Phase 10O)
//
// Enterprise pilot mode UI with checklist and exports.
// Read-only + export only. Does not change execution behavior.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No execution changes
// ❌ No auto-send
// ❌ No networking
// ✅ Read-only checklist
// ✅ Export links
// ✅ mailto with placeholders
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct PilotModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    @State private var showingSharePack = false
    @State private var sharePackURL: URL?
    @State private var exportError: String?
    
    @State private var showingEnterpriseReadiness = false
    @State private var showingQualityPacket = false
    @State private var showingDiagnostics = false
    
    var body: some View {
        NavigationView {
            List {
                // Overview
                overviewSection
                
                // 7-Day Checklist
                checklistSection
                
                // Export Artifacts
                exportSection
                
                // Email Templates
                emailTemplatesSection
                
                // Safety Note
                safetyNoteSection
            }
            .scrollContentBackground(.hidden)
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Pilot Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSharePack) {
                if let url = sharePackURL {
                    PilotModeShareSheet(activityItems: [url])
                }
            }
            .sheet(isPresented: $showingEnterpriseReadiness) {
                EnterpriseReadinessView()
            }
            .alert("Export Error", isPresented: .constant(exportError != nil)) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "airplane.circle.fill")
                        .font(.title)
                        .foregroundColor(OKColor.actionPrimary)
                    
                    VStack(alignment: .leading) {
                        Text("Enterprise Pilot")
                            .font(.headline)
                        
                        Text("7-day evaluation framework")
                            .font(.subheadline)
                            .foregroundColor(OKColor.textSecondary)
                    }
                }
                
                Text("Use this checklist to run a structured pilot evaluation. Export all artifacts at the end for stakeholder review.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Checklist Section
    
    private var checklistSection: some View {
        Section {
            ForEach(PilotChecklist.items) { item in
                ChecklistRow(item: item)
            }
        } header: {
            Text("7-Day Pilot Checklist")
        } footer: {
            Text("Checklist is read-only. Track progress externally or in notes.")
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section {
            Button {
                showingEnterpriseReadiness = true
            } label: {
                ExportRow(
                    icon: "building.2",
                    title: "Enterprise Readiness",
                    subtitle: "Safety, governance, quality"
                )
            }
            
            Button {
                exportPilotSharePack()
            } label: {
                ExportRow(
                    icon: "shippingbox",
                    title: "Pilot Share Pack",
                    subtitle: "All artifacts in one export"
                )
            }
            
            NavigationLink {
                PilotExportDetailView()
            } label: {
                ExportRow(
                    icon: "doc.on.doc",
                    title: "Individual Exports",
                    subtitle: "Quality, diagnostics, policy"
                )
            }
        } header: {
            Text("Export Artifacts")
        } footer: {
            Text("All exports are metadata-only. No user content included.")
        }
    }
    
    // MARK: - Email Templates Section
    
    private var emailTemplatesSection: some View {
        Section {
            Button {
                openPilotKickoff()
            } label: {
                HStack {
                    Image(systemName: "envelope.badge")
                        .foregroundColor(OKColor.actionPrimary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pilot Kickoff Email")
                            .font(.subheadline)
                            .foregroundColor(OKColor.textPrimary)
                        
                        Text("Share pilot plan with stakeholders")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(OKColor.textMuted)
                }
            }
            
            Button {
                openSecurityFollowUp()
            } label: {
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(OKColor.riskNominal)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Security Review Follow-Up")
                            .font(.subheadline)
                            .foregroundColor(OKColor.textPrimary)
                        
                        Text("Request security assessment")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(OKColor.textMuted)
                }
            }
        } header: {
            Text("Email Templates")
        } footer: {
            Text("Opens your email app with a draft. You control when to send.")
        }
    }
    
    // MARK: - Safety Note Section
    
    private var safetyNoteSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Pilot Mode Is Read-Only", systemImage: "info.circle")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Pilot mode provides a structured evaluation framework and export tools. It does not change execution behavior, safety guarantees, or approval requirements.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
    }
    
    // MARK: - Actions
    
    private func exportPilotSharePack() {
        Task { @MainActor in
            do {
                let builder = PilotSharePackBuilder()
                let pack = builder.build()
                let jsonData = try pack.toJSONData()
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(pack.filename)
                try jsonData.write(to: tempURL)
                
                sharePackURL = tempURL
                showingSharePack = true
            } catch {
                exportError = error.localizedDescription
            }
        }
    }
    
    private func openPilotKickoff() {
        let mailto = createMailtoURL(
            to: "",
            subject: "OperatorKit Pilot Kickoff - [Organization]",
            body: PilotEmailTemplates.pilotKickoff
        )
        if let url = mailto { openURL(url) }
    }
    
    private func openSecurityFollowUp() {
        let mailto = createMailtoURL(
            to: "security@operatorkit.app",
            subject: "Security Review Follow-Up - [Organization]",
            body: PilotEmailTemplates.securityFollowUp
        )
        if let url = mailto { openURL(url) }
    }
    
    private func createMailtoURL(to: String, subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = to
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

// MARK: - Checklist Row

private struct ChecklistRow: View {
    let item: PilotChecklistItem
    
    var body: some View {
        HStack(spacing: 12) {
            Text("Day \(item.day)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(OKColor.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(OKColor.actionPrimary)
                .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.taskTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(item.taskDescription)
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
    }
}

// MARK: - Export Row

private struct ExportRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(OKColor.actionPrimary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(OKColor.textPrimary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(OKColor.textMuted)
        }
    }
}

// MARK: - Pilot Export Detail View

private struct PilotExportDetailView: View {
    var body: some View {
        List {
            Section {
                Text("Use individual exports to share specific artifacts with different stakeholders.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            Section {
                NavigationLink("Quality Packet") {
                    Text("Quality Packet Export")
                        .navigationTitle("Quality")
                }
                
                NavigationLink("Diagnostics") {
                    Text("Diagnostics Export")
                        .navigationTitle("Diagnostics")
                }
                
                NavigationLink("Policy Export") {
                    Text("Policy Export")
                        .navigationTitle("Policy")
                }
            } header: {
                Text("Available Exports")
            }
        }
        .navigationTitle("Individual Exports")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

// MARK: - Pilot Checklist

public struct PilotChecklistItem: Identifiable {
    public let id: String
    public let day: Int
    public let taskTitle: String
    public let taskDescription: String
}

public enum PilotChecklist {
    public static let items: [PilotChecklistItem] = [
        PilotChecklistItem(
            id: "day-1",
            day: 1,
            taskTitle: "Setup & Review",
            taskDescription: "Install app, review safety documentation, configure initial policy"
        ),
        PilotChecklistItem(
            id: "day-2",
            day: 2,
            taskTitle: "Basic Workflows",
            taskDescription: "Test email drafts and reminders with approval flow"
        ),
        PilotChecklistItem(
            id: "day-3",
            day: 3,
            taskTitle: "Context Testing",
            taskDescription: "Test different context sources and verify privacy controls"
        ),
        PilotChecklistItem(
            id: "day-4",
            day: 4,
            taskTitle: "Team Scenarios",
            taskDescription: "Evaluate team governance features and policy templates"
        ),
        PilotChecklistItem(
            id: "day-5",
            day: 5,
            taskTitle: "Quality Review",
            taskDescription: "Review quality metrics and diagnostics dashboards"
        ),
        PilotChecklistItem(
            id: "day-6",
            day: 6,
            taskTitle: "Export & Document",
            taskDescription: "Export all artifacts, document findings"
        ),
        PilotChecklistItem(
            id: "day-7",
            day: 7,
            taskTitle: "Stakeholder Report",
            taskDescription: "Prepare pilot summary and recommendations"
        )
    ]
}

// MARK: - Pilot Email Templates

public enum PilotEmailTemplates {
    
    public static let pilotKickoff = """
    Hello Team,
    
    We are starting a 7-day pilot evaluation of OperatorKit.
    
    Pilot Details:
    - Duration: 7 days
    - Participants: [List participants]
    - Objectives: [List objectives]
    
    Daily Tasks:
    Day 1: Setup & Review
    Day 2: Basic Workflows
    Day 3: Context Testing
    Day 4: Team Scenarios
    Day 5: Quality Review
    Day 6: Export & Document
    Day 7: Stakeholder Report
    
    Please track your observations and report any concerns.
    
    Organization: [Your Organization]
    Pilot Lead: [Your Name]
    """
    
    public static let securityFollowUp = """
    Hello,
    
    We have completed [X] days of our OperatorKit pilot and would like to follow up on security questions.
    
    Pilot Status:
    - Days completed: [Number]
    - Participants: [Number]
    - Key findings: [Brief summary]
    
    Questions:
    1. [Question 1]
    2. [Question 2]
    
    We have exported the Enterprise Readiness packet and can share upon request.
    
    Organization: [Your Organization]
    Contact: [Your Name]
    """
}

// MARK: - Share Sheet

private struct PilotModeShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    PilotModeView()
}
