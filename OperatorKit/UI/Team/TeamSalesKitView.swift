import SwiftUI

// ============================================================================
// TEAM SALES KIT VIEW (Phase 10M, Updated Phase 10N, Phase 10O)
//
// B2B sales kit with procurement packet access and trial request.
// No execution triggers, no identifiers in mailto.
// Phase 10N: Added team trial section and procurement templates.
// Phase 10O: Added Pilot Mode entry point.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No auto-send
// ❌ No device identifiers
// ❌ No user identifiers
// ❌ No execution triggers
// ✅ mailto: for email draft (user sends)
// ✅ Read-only information
// ✅ Navigation to procurement packet
// ✅ Process-only trial (Phase 10N)
// ✅ Pilot Mode (Phase 10O)
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct TeamSalesKitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var trialStore = TeamTrialStore.shared
    
    @State private var showingEnterpriseReadiness = false
    @State private var showingTeamTrial = false
    @State private var showingTemplateSelector = false
    @State private var showingPilotMode = false  // Phase 10O
    
    var body: some View {
        NavigationView {
            List {
                // Team Trial Section (Phase 10N)
                teamTrialSection
                
                // Pilot Mode Section (Phase 10O)
                pilotModeSection
                
                // Team Plan Overview
                planOverviewSection
                
                // Procurement Packet
                procurementSection
                
                // Procurement Email Templates (Phase 10N)
                procurementTemplatesSection
                
                // Admin Rollout Checklist
                rolloutChecklistSection
                
                // Disclaimer
                disclaimerSection
            }
            .navigationTitle("Enterprise & Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingEnterpriseReadiness) {
                EnterpriseReadinessView()
            }
            .sheet(isPresented: $showingTeamTrial) {
                TeamTrialView()
            }
            .sheet(isPresented: $showingTemplateSelector) {
                ProcurementTemplateSelector(onSelect: { template in
                    openTemplate(template)
                    showingTemplateSelector = false
                })
            }
            .sheet(isPresented: $showingPilotMode) {
                PilotModeView()
            }
        }
    }
    
    // MARK: - Pilot Mode Section (Phase 10O)
    
    private var pilotModeSection: some View {
        Section {
            Button {
                showingPilotMode = true
            } label: {
                HStack {
                    Image(systemName: "airplane.circle")
                        .foregroundColor(.blue)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pilot Mode")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("7-day evaluation framework")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        } header: {
            Text("Enterprise Pilot")
        } footer: {
            Text("Structured pilot with checklist and unified export.")
        }
    }
    
    // MARK: - Team Trial Section (Phase 10N)
    
    private var teamTrialSection: some View {
        Section {
            Button {
                showingTeamTrial = true
            } label: {
                HStack {
                    Image(systemName: trialStore.hasActiveTrial ? "checkmark.seal.fill" : "gift")
                        .foregroundColor(trialStore.hasActiveTrial ? .green : .purple)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trialStore.hasActiveTrial ? "Team Trial Active" : "Start Team Trial")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(trialStore.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        } header: {
            Text("Team Trial")
        } footer: {
            Text("Process-only trial. Does not change execution safety guarantees.")
        }
    }
    
    // MARK: - Plan Overview Section
    
    private var planOverviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("Team Plan")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    featureBullet("All Pro features included")
                    featureBullet("Team governance and policies")
                    featureBullet("Shared policy templates")
                    featureBullet("Team diagnostics dashboards")
                    featureBullet("Quality summaries for teams")
                    featureBullet("Procurement-ready evidence exports")
                    featureBullet("Priority support")
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Team Plan Overview")
        } footer: {
            Text("Team features are metadata-only. No shared execution, no shared drafts, no shared user content.")
        }
    }
    
    // MARK: - Procurement Section
    
    private var procurementSection: some View {
        Section {
            Button {
                showingEnterpriseReadiness = true
            } label: {
                HStack {
                    Image(systemName: "doc.badge.checkmark")
                        .foregroundColor(.green)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Procurement Packet")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Safety, quality, and governance evidence")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        } header: {
            Text("Procurement")
        } footer: {
            Text("Export contains metadata only. No user content, no identifiers.")
        }
    }
    
    // MARK: - Procurement Templates Section (Phase 10N)
    
    private var procurementTemplatesSection: some View {
        Section {
            Button {
                showingTemplateSelector = true
            } label: {
                HStack {
                    Image(systemName: "envelope.open")
                        .foregroundColor(.blue)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Email Templates")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Security review, pilot, invoice requests")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        } header: {
            Text("Procurement Templates")
        } footer: {
            Text("Opens your email app with a draft. You control when to send.")
        }
    }
    
    // MARK: - Rollout Checklist Section
    
    private var rolloutChecklistSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                checklistItem(1, "Evaluate with free tier", done: true)
                checklistItem(2, "Review procurement packet", done: false)
                checklistItem(3, "Request team trial", done: false)
                checklistItem(4, "Configure team policies", done: false)
                checklistItem(5, "Onboard team members", done: false)
                checklistItem(6, "Review team diagnostics", done: false)
                checklistItem(7, "Subscribe to team tier", done: false)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Admin Rollout Checklist")
        } footer: {
            Text("Recommended steps for team deployment")
        }
    }
    
    // MARK: - Disclaimer Section
    
    private var disclaimerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Enterprise Ready", systemImage: "building.2")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("OperatorKit is designed for enterprise deployment with strong privacy guarantees. No user content is ever shared, synced, or exported. Team features are governance-only.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func featureBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.green)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
    
    private func checklistItem(_ number: Int, _ text: String, done: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(done ? .green : .gray)
            
            Text("\(number). \(text)")
                .font(.subheadline)
                .foregroundColor(done ? .secondary : .primary)
        }
    }
    
    // MARK: - Actions
    
    private func openTemplate(_ template: ProcurementEmailTemplates.TemplateInfo) {
        let mailto = createMailtoURL(
            to: template.emailAddress,
            subject: template.subject,
            body: template.body
        )
        if let url = mailto {
            openURL(url)
        }
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

// MARK: - Procurement Template Selector

private struct ProcurementTemplateSelector: View {
    @Environment(\.dismiss) private var dismiss
    
    let onSelect: (ProcurementEmailTemplates.TemplateInfo) -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(ProcurementEmailTemplates.allTemplates) { template in
                        Button {
                            onSelect(template)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: template.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text(template.templateDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                } footer: {
                    Text("Templates use placeholders. No device or user identifiers.")
                }
            }
            .navigationTitle("Email Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TeamSalesKitView()
}
