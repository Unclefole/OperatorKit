import SwiftUI

// ============================================================================
// APP STORE READINESS VIEW (Phase 10J)
//
// Read-only view for App Store submission readiness status.
// Exports submission packet and copy pack.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No behavior toggles
// ❌ No user content display
// ❌ No execution module references
// ✅ Read-only status display
// ✅ Export via ShareSheet only
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct AppStoreReadinessView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var packet: AppStoreSubmissionPacket?
    @State private var riskReport: AppReviewRiskReport?
    @State private var isLoading = true
    @State private var showingPacketExport = false
    @State private var showingCopyExport = false
    @State private var showingRiskExport = false
    @State private var showingReviewerQuickPath = false
    @State private var showingLaunchReadiness = false  // Phase 10Q
    @State private var exportURL: URL?
    @State private var expandedScreenshots = false
    @State private var expandedRiskFindings = false
    
    var body: some View {
        NavigationView {
            List {
                // Launch Checklist (Phase 10Q)
                launchChecklistSection
                
                // Risk Status (Phase 10K)
                riskStatusSection
                
                // Reviewer Quick Path (Phase 10K)
                reviewerQuickPathSection
                
                // Overview
                overviewSection
                
                // Doc Integrity
                docIntegritySection
                
                // Store Listing Lockdown (Phase 10K)
                storeListingSection
                
                // Copy Previews
                copyPreviewsSection
                
                // Screenshot Checklist
                screenshotSection
                
                // Export
                exportSection
                
                // Disclaimers
                disclaimerSection
            }
            .scrollContentBackground(.hidden)
            .background(OKColor.backgroundPrimary)
            .navigationTitle("App Store Readiness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadPacket()
                riskReport = AppReviewRiskScanner.scanSubmissionCopy()
            }
            .sheet(isPresented: $showingPacketExport) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingCopyExport) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingRiskExport) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingReviewerQuickPath) {
                ReviewerQuickPathView()
            }
            .sheet(isPresented: $showingLaunchReadiness) {
                LaunchReadinessView()
            }
        }
    }
    
    // MARK: - Launch Checklist Section (Phase 10Q)
    
    private var launchChecklistSection: some View {
        Section {
            Button {
                showingLaunchReadiness = true
            } label: {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundColor(OKColor.actionPrimary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch Checklist")
                            .font(.subheadline)
                            .foregroundColor(OKColor.textPrimary)
                        
                        Text("Comprehensive launch readiness validation")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
        } header: {
            Text("Launch Readiness")
        } footer: {
            Text("Advisory checklist for internal readiness. Does not affect app functionality.")
        }
    }
    
    // MARK: - Risk Status Section (Phase 10K)
    
    private var riskStatusSection: some View {
        Section {
            if let report = riskReport {
                HStack {
                    Label("Risk Status", systemImage: riskStatusIcon(for: report.status))
                    Spacer()
                    Text(report.status.rawValue)
                        .fontWeight(.semibold)
                        .foregroundColor(riskStatusColor(for: report.status))
                }
                
                if !report.findings.isEmpty {
                    DisclosureGroup(isExpanded: $expandedRiskFindings) {
                        ForEach(report.findings, id: \.id) { finding in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: severityIcon(for: finding.severity))
                                        .foregroundColor(severityColor(for: finding.severity))
                                    Text(finding.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                Text(finding.message)
                                    .font(.caption)
                                    .foregroundColor(OKColor.textSecondary)
                                Text("Fix: \(finding.suggestedFix)")
                                    .font(.caption2)
                                    .foregroundColor(OKColor.actionPrimary)
                            }
                            .padding(.vertical, 4)
                        }
                    } label: {
                        HStack {
                            Text("Findings")
                            Spacer()
                            Text("\(report.findings.count)")
                                .foregroundColor(OKColor.textSecondary)
                        }
                    }
                }
                
                Button {
                    exportRiskReport()
                } label: {
                    Label("Export Risk Report", systemImage: "square.and.arrow.up")
                }
            } else {
                Text("Scanning...")
                    .foregroundColor(OKColor.textSecondary)
            }
        } header: {
            Text("Review Risk Status")
        } footer: {
            Text("Scans copy for App Store guideline violations.")
        }
    }
    
    private func riskStatusIcon(for status: RiskStatus) -> String {
        switch status {
        case .pass: return "checkmark.seal.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.seal.fill"
        }
    }
    
    private func riskStatusColor(for status: RiskStatus) -> Color {
        switch status {
        case .pass: return OKColor.riskNominal
        case .warn: return OKColor.riskWarning
        case .fail: return OKColor.riskCritical
        }
    }
    
    private func severityIcon(for severity: RiskSeverity) -> String {
        switch severity {
        case .info: return "info.circle"
        case .warn: return "exclamationmark.triangle"
        case .fail: return "xmark.circle"
        }
    }
    
    private func severityColor(for severity: RiskSeverity) -> Color {
        switch severity {
        case .info: return OKColor.actionPrimary
        case .warn: return OKColor.riskWarning
        case .fail: return OKColor.riskCritical
        }
    }
    
    // MARK: - Reviewer Quick Path Section (Phase 10K)
    
    private var reviewerQuickPathSection: some View {
        Section {
            Button {
                showingReviewerQuickPath = true
            } label: {
                HStack {
                    Label("Reviewer Quick Path", systemImage: "person.badge.clock")
                    Spacer()
                    Text("2 min")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                    Image(systemName: "chevron.right")
                        .foregroundColor(OKColor.textMuted)
                }
            }
        } header: {
            Text("For Reviewers")
        } footer: {
            Text("Quick guide for App Store reviewers.")
        }
    }
    
    // MARK: - Store Listing Section (Phase 10K)
    
    private var storeListingSection: some View {
        Section {
            let hashResult = StoreListingSnapshot.verifyHash()
            
            ReadinessRow(
                label: "Store Listing Copy",
                value: hashResult.isValid ? "Locked" : "Drifted",
                icon: "lock.doc",
                status: hashResult.isValid ? .pass : .warn
            )
            
            if !hashResult.isValid {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Copy has changed")
                        .font(.caption)
                        .foregroundColor(OKColor.riskWarning)
                    Text("Update StoreListingSnapshot.expectedHash")
                        .font(.caption2)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
            
            ReadinessRow(
                label: "Last Update",
                value: StoreListingSnapshot.lastUpdatePhase,
                icon: "clock"
            )
            
            NavigationLink {
                CopyPreviewView(
                    title: "Store Listing",
                    content: StoreListingCopy.concatenatedContent
                )
            } label: {
                Label("View Store Listing Copy", systemImage: "doc.text")
            }
        } header: {
            Text("Store Listing Lockdown")
        } footer: {
            Text("Hash-locked to prevent accidental drift.")
        }
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        Section {
            ReadinessRow(
                label: "App Version",
                value: packet?.appVersion ?? "Loading...",
                icon: "app.badge"
            )
            
            ReadinessRow(
                label: "Build Number",
                value: packet?.buildNumber ?? "Loading...",
                icon: "hammer"
            )
            
            ReadinessRow(
                label: "Release Mode",
                value: packet?.releaseMode.capitalized ?? "Loading...",
                icon: "flag"
            )
            
            ReadinessRow(
                label: "Schema Version",
                value: "\(packet?.schemaVersion ?? 0)",
                icon: "doc.text"
            )
        } header: {
            Text("Build Information")
        }
    }
    
    // MARK: - Doc Integrity Section
    
    private var docIntegritySection: some View {
        Section {
            if let docIntegrity = packet?.docIntegrity {
                ReadinessRow(
                    label: "Required Docs",
                    value: "\(docIntegrity.presentCount)/\(docIntegrity.requiredDocsCount)",
                    icon: "doc.on.doc",
                    status: docIntegrity.status == "valid" ? .pass : .fail
                )
                
                if !docIntegrity.missingDocs.isEmpty {
                    ForEach(docIntegrity.missingDocs, id: \.self) { doc in
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(OKColor.riskWarning)
                            Text("Missing: \(doc)")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                    }
                }
                
                ForEach(Array(docIntegrity.sectionValidation.keys.sorted()), id: \.self) { key in
                    let isValid = docIntegrity.sectionValidation[key] ?? false
                    ReadinessRow(
                        label: key,
                        value: isValid ? "Valid" : "Issues",
                        icon: "checkmark.circle",
                        status: isValid ? .pass : .warn
                    )
                }
            } else {
                Text("Loading...")
                    .foregroundColor(OKColor.textSecondary)
            }
        } header: {
            Text("Documentation Integrity")
        }
    }
    
    // MARK: - Copy Previews Section
    
    private var copyPreviewsSection: some View {
        Section {
            NavigationLink {
                CopyPreviewView(
                    title: "Review Notes",
                    content: SubmissionCopy.reviewNotesTemplate(
                        version: packet?.appVersion ?? "1.0",
                        build: packet?.buildNumber ?? "1"
                    )
                )
            } label: {
                Label("Review Notes", systemImage: "doc.plaintext")
            }
            
            NavigationLink {
                CopyPreviewView(
                    title: "What's New",
                    content: SubmissionCopy.whatsNewTemplate(
                        version: packet?.appVersion ?? "1.0",
                        highlights: SubmissionCopy.defaultHighlights
                    )
                )
            } label: {
                Label("What's New", systemImage: "star")
            }
            
            NavigationLink {
                CopyPreviewView(
                    title: "Privacy Disclosure",
                    content: SubmissionCopy.privacyDisclosureBlurb
                )
            } label: {
                Label("Privacy Disclosure", systemImage: "hand.raised")
            }
            
            NavigationLink {
                CopyPreviewView(
                    title: "Monetization Disclosure",
                    content: SubmissionCopy.monetizationDisclosureBlurb
                )
            } label: {
                Label("Monetization Disclosure", systemImage: "creditcard")
            }
        } header: {
            Text("Copy Previews")
        } footer: {
            Text("Templates only. Edit as needed before submission.")
        }
    }
    
    // MARK: - Screenshot Section
    
    private var screenshotSection: some View {
        Section {
            DisclosureGroup(isExpanded: $expandedScreenshots) {
                ForEach(ScreenshotChecklist.requiredShots, id: \.order) { shot in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(shot.order). \(shot.name)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        Text(shot.captionTemplate)
                            .font(.caption)
                            .foregroundColor(OKColor.actionPrimary)
                            .italic()
                        Text(shot.notes)
                            .font(.caption2)
                            .foregroundColor(OKColor.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            } label: {
                HStack {
                    Label("Screenshots", systemImage: "photo.on.rectangle")
                    Spacer()
                    Text("\(ScreenshotChecklist.requiredShots.count) required")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
            
            HStack {
                Label("Required Sizes", systemImage: "rectangle.portrait")
                Spacer()
                Text("\(ScreenshotChecklist.requiredSizes.filter { $0.required }.count)")
                    .foregroundColor(OKColor.textSecondary)
            }
        } header: {
            Text("Screenshot Checklist")
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section {
            Button {
                exportSubmissionPacket()
            } label: {
                Label("Export Submission Packet (JSON)", systemImage: "square.and.arrow.up")
            }
            
            Button {
                exportCopyPack()
            } label: {
                Label("Export Copy Pack (Text)", systemImage: "doc.text")
            }
        } header: {
            Text("Export")
        } footer: {
            Text("Exports contain metadata only. No user data is included.")
        }
    }
    
    // MARK: - Disclaimer Section
    
    private var disclaimerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Templates Only", systemImage: "info.circle")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("All copy is provided as templates. Review and customize before App Store submission.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Label("No User Data", systemImage: "lock.shield")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Exports contain only metadata and status information. No user content is ever included.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
        } header: {
            Text("Disclaimers")
        }
    }
    
    // MARK: - Actions
    
    @MainActor
    private func loadPacket() async {
        isLoading = true
        packet = AppStoreSubmissionBuilder.shared.build()
        isLoading = false
    }
    
    private func exportSubmissionPacket() {
        guard let packet = packet else { return }
        
        do {
            let jsonData = try packet.exportJSON()
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(packet.exportFilename)
            try jsonData.write(to: tempURL)
            exportURL = tempURL
            showingPacketExport = true
        } catch {
            // Handle error silently
        }
    }
    
    private func exportCopyPack() {
        let copyPack = SubmissionCopyPack(
            version: packet?.appVersion ?? "1.0",
            build: packet?.buildNumber ?? "1"
        )
        
        let text = copyPack.exportText()
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(copyPack.exportFilename)
        
        do {
            try text.write(to: tempURL, atomically: true, encoding: .utf8)
            exportURL = tempURL
            showingCopyExport = true
        } catch {
            // Handle error silently
        }
    }
    
    private func exportRiskReport() {
        guard let report = riskReport else { return }
        
        do {
            let jsonData = try report.exportJSON()
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(report.exportFilename)
            try jsonData.write(to: tempURL)
            exportURL = tempURL
            showingRiskExport = true
        } catch {
            // Handle error silently
        }
    }
}

// MARK: - Readiness Row

private struct ReadinessRow: View {
    let label: String
    let value: String
    let icon: String
    var status: ReadinessStatus = .neutral
    
    enum ReadinessStatus {
        case pass, warn, fail, neutral
        
        var color: Color {
            switch self {
            case .pass: return OKColor.riskNominal
            case .warn: return OKColor.riskWarning
            case .fail: return OKColor.riskCritical
            case .neutral: return .primary
            }
        }
    }
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundColor(status.color)
        }
    }
}

// MARK: - Copy Preview View

private struct CopyPreviewView: View {
    let title: String
    let content: String
    
    @State private var showingShare = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    UIPasteboard.general.string = content
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AppStoreReadinessView()
}
