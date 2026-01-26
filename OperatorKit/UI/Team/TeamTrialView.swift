import SwiftUI

// ============================================================================
// TEAM TRIAL VIEW (Phase 10N)
//
// Shows team trial status and start flow.
// Explains trial is process-only, no execution changes.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No execution behavior changes
// ❌ No silent tier changes
// ❌ No forced interactions
// ✅ Clear process-only explanation
// ✅ Requires acknowledgement
// ✅ Always skippable
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

struct TeamTrialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var trialStore = TeamTrialStore.shared
    
    @State private var showingAcknowledgement = false
    @State private var hasAcknowledged = false
    
    var body: some View {
        NavigationView {
            List {
                // Status Section
                statusSection
                
                // What's Included Section
                whatsIncludedSection
                
                // Safety Guarantees Section
                safetySection
                
                // Actions Section
                actionsSection
                
                // Contact Section
                contactSection
            }
            .navigationTitle("Team Trial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAcknowledgement) {
                TrialAcknowledgementSheet(
                    onAccept: {
                        _ = trialStore.startTrial()
                        showingAcknowledgement = false
                    },
                    onDecline: {
                        showingAcknowledgement = false
                    }
                )
            }
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        Section {
            if trialStore.hasActiveTrial {
                // Active trial status
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("Trial Active")
                                .font(.headline)
                            Text(trialStore.statusMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    ProgressView(value: trialStore.trialProgress)
                        .tint(.green)
                }
                .padding(.vertical, 8)
            } else if trialStore.canStartTrial() {
                // Can start trial
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "gift")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("Free \(TeamTrialState.defaultTrialDays)-Day Trial")
                                .font(.headline)
                            Text("Explore team governance features")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            } else {
                // Trial limit reached
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.orange)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("Trial Limit Reached")
                                .font(.headline)
                            Text("Subscribe to Team tier for full access")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        } header: {
            Text("Trial Status")
        }
    }
    
    // MARK: - What's Included Section
    
    private var whatsIncludedSection: some View {
        Section {
            FeatureRow(
                icon: "doc.badge.gearshape",
                title: "Policy Templates",
                description: "Apply team governance policies"
            )
            
            FeatureRow(
                icon: "chart.bar",
                title: "Team Diagnostics",
                description: "View aggregate team metrics"
            )
            
            FeatureRow(
                icon: "doc.text.magnifyingglass",
                title: "Quality Summaries",
                description: "Review team quality reports"
            )
            
            FeatureRow(
                icon: "building.2",
                title: "Enterprise Readiness",
                description: "Export procurement packets"
            )
        } header: {
            Text("What's Included")
        } footer: {
            Text("Trial features are governance-only and do not affect execution safety.")
        }
    }
    
    // MARK: - Safety Section
    
    private var safetySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label("Process-Only Trial", systemImage: "shield.checkered")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(TeamTrialAcknowledgement.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Safety Guarantees")
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        Section {
            if trialStore.canStartTrial() && !trialStore.hasActiveTrial {
                Button {
                    showingAcknowledgement = true
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Free Trial")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            
            if trialStore.hasActiveTrial {
                Button(role: .destructive) {
                    trialStore.endTrial()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("End Trial Early")
                    }
                }
            }
        }
    }
    
    // MARK: - Contact Section
    
    private var contactSection: some View {
        Section {
            Button {
                requestTrialExtension()
            } label: {
                Label("Request Trial Extension", systemImage: "envelope")
            }
            
            Button {
                requestInvoice()
            } label: {
                Label("Request Invoice", systemImage: "doc.text")
            }
        } header: {
            Text("Contact")
        } footer: {
            Text("Opens your email app with a draft. You control when to send.")
        }
    }
    
    // MARK: - Actions
    
    private func requestTrialExtension() {
        let mailto = createMailtoURL(
            to: "team@operatorkit.app",
            subject: "Team Trial Extension Request",
            body: """
            Hello,
            
            I would like to request an extension to my team trial.
            
            Organization: [Your Organization]
            Current trial status: [Active/Ended]
            
            Thank you.
            """
        )
        if let url = mailto { openURL(url) }
    }
    
    private func requestInvoice() {
        let mailto = createMailtoURL(
            to: "billing@operatorkit.app",
            subject: "Team Subscription Invoice Request",
            body: ProcurementEmailTemplates.invoiceRequest
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

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Trial Acknowledgement Sheet

private struct TrialAcknowledgementSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @State private var acknowledged = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Before You Start")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Please review the trial terms")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Terms
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(TeamTrialAcknowledgement.terms, id: \.self) { term in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            
                            Text(term)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Acknowledgement Toggle
                Toggle(isOn: $acknowledged) {
                    Text("I understand this is a process-only trial")
                        .font(.subheadline)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    Button {
                        onAccept()
                    } label: {
                        Text("Start Trial")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!acknowledged)
                    
                    Button {
                        onDecline()
                    } label: {
                        Text("Not Now")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Trial Terms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { onDecline() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TeamTrialView()
}
