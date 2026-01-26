import SwiftUI

// ============================================================================
// EXTERNAL REVIEW READINESS VIEW (Phase 9D)
//
// Read-only, reviewer-friendly UI for external review evidence.
// Accessible from: Settings → External Review Readiness
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No controls that affect behavior
// ❌ No toggles
// ❌ No debug-only content in production UI
// ❌ No security claims
// ✅ Read-only UI surfaces
// ✅ Manual export only via ShareLink
// ✅ App Store-safe copy
//
// Copy rules:
// - Plain language
// - Non-anthropomorphic (no "AI thinks/learns/decides")
// - No "secure/encrypted"
// - Never implies data leaves device
// - Use: "processed on-device", "not transmitted", "only when you select"
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct ExternalReviewReadinessView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var isLoading = true
    @State private var evidencePacket: ExternalReviewEvidencePacket?
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Live proof status
    @State private var preflightStatus: String = "..."
    @State private var invariantStatus: String = "..."
    @State private var qualityGateStatus: String = "..."
    @State private var integrityStatus: String = "..."
    
    var body: some View {
        NavigationView {
            List {
                // Summary Section
                summarySection
                
                // Data Access Section
                dataAccessSection
                
                // Guarantees Section
                guaranteesSection
                
                // Live Proof Snapshot
                liveProofSection
                
                // Reviewer Test Plan
                testPlanSection
                
                // FAQ Section
                faqSection
                
                // Export Section
                exportSection
                
                // Disclaimers
                disclaimersSection
            }
            .navigationTitle("External Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadData()
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Export Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        isLoading = true
        
        // Build evidence packet
        let builder = ExternalReviewEvidenceBuilder.shared
        evidencePacket = builder.build()
        
        // Update live status
        if let packet = evidencePacket {
            preflightStatus = packet.preflightSummary.status
            invariantStatus = packet.invariantCheckSummary.status
            qualityGateStatus = packet.qualityPacket.qualityGateResult.status
            integrityStatus = packet.integritySealStatus?.status ?? "Not Available"
        }
        
        isLoading = false
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        Section("About OperatorKit") {
            Text("""
            OperatorKit is an on-device task assistant that helps draft emails, create reminders, and manage calendar events. All processing happens locally on your device. The app generates drafts for your review—no action is taken without your explicit approval.
            """)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Data Access Section
    
    private var dataAccessSection: some View {
        Section("Data Access") {
            dataAccessRow(
                icon: "calendar",
                title: "Calendar",
                trigger: "When you open Context Picker and select events",
                scope: "±7 days, max 50 events"
            )
            
            dataAccessRow(
                icon: "checklist",
                title: "Reminders",
                trigger: "When you approve and confirm reminder creation",
                scope: "Creates only, does not read existing"
            )
            
            dataAccessRow(
                icon: "envelope",
                title: "Email",
                trigger: "When you tap 'Open Email Composer'",
                scope: "Opens Mail app; you control sending"
            )
            
            dataAccessRow(
                icon: "mic",
                title: "Siri",
                trigger: "When you say 'Ask OperatorKit...'",
                scope: "Routes to app only; cannot execute"
            )
            
            Text("Data is processed on-device and not transmitted externally.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func dataAccessRow(icon: String, title: String, trigger: String, scope: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text("When: \(trigger)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Scope: \(scope)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Guarantees Section
    
    private var guaranteesSection: some View {
        Section("What Never Happens") {
            ForEach(DisclaimersRegistry.guaranteeDisclaimers.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .leading)
                    
                    Text(DisclaimersRegistry.guaranteeDisclaimers[index])
                        .font(.subheadline)
                }
            }
            
            Text("These are enforced by code and verified by automated tests.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Live Proof Section
    
    private var liveProofSection: some View {
        Section("Live Proof Snapshot") {
            if isLoading {
                ProgressView("Loading...")
            } else {
                proofRow(title: "Preflight", status: preflightStatus)
                proofRow(title: "Invariants", status: invariantStatus)
                proofRow(title: "Quality Gate", status: qualityGateStatus)
                proofRow(title: "Integrity", status: integrityStatus)
            }
            
            Text("These checks run locally on-device. Status is informational only.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func proofRow(title: String, status: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(status)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(statusColor(status))
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "PASS", "ALL_CLEAR", "VERIFIED":
            return .green
        case "WARN", "SKIPPED", "MISMATCH":
            return .orange
        case "FAIL", "REGRESSION_DETECTED":
            return .red
        default:
            return .secondary
        }
    }
    
    // MARK: - Test Plan Section
    
    private var testPlanSection: some View {
        Section("2-Minute Reviewer Test Plan") {
            ForEach(ReviewerTestPlan.twoMinutePlan.steps, id: \.stepNumber) { step in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Step \(step.stepNumber): \(step.title)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(step.duration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(step.action)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Expected: \(step.expectedResult)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    // MARK: - FAQ Section
    
    private var faqSection: some View {
        Section("Common Questions") {
            DisclosureGroup("Reviewer FAQ") {
                ForEach(ReviewerFAQ.items.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Q: \(ReviewerFAQ.items[index].question)")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("A: \(ReviewerFAQ.items[index].answer)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section("Export Evidence Packet") {
            Button {
                exportEvidencePacket()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Evidence Packet")
                }
            }
            
            Text("The export contains metadata only—version numbers, check results, and status indicators. It never contains calendar events, email content, or any personal data.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Navigation to reviewer checklist
            NavigationLink {
                ReviewerSimulationChecklistView()
            } label: {
                HStack {
                    Image(systemName: "checklist")
                    Text("View Reviewer Checklist")
                }
            }
        }
    }
    
    // MARK: - Disclaimers Section
    
    private var disclaimersSection: some View {
        Section("Disclaimers") {
            ForEach(DisclaimersRegistry.uiDisclaimers.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text(DisclaimersRegistry.uiDisclaimers[index])
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Export Action
    
    private func exportEvidencePacket() {
        do {
            let builder = ExternalReviewEvidenceBuilder.shared
            let url = try builder.exportToFile()
            exportURL = url
            showShareSheet = true
        } catch {
            errorMessage = "Failed to export: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExternalReviewReadinessView()
}
