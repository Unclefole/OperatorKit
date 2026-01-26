import SwiftUI

// ============================================================================
// ARTIFACT SHARING VIEW (Phase 10E)
//
// Shows what is shared with the team and what is not.
// Clear disclosure of metadata-only sharing.
//
// See: docs/SAFETY_CONTRACT.md (Section 14)
// ============================================================================

struct ArtifactSharingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var teamStore = TeamStore.shared
    
    // Artifact toggles (per-type upload preference)
    @AppStorage("team.share.policyTemplate") private var sharePolicyTemplates = false
    @AppStorage("team.share.diagnostics") private var shareDiagnostics = false
    @AppStorage("team.share.quality") private var shareQuality = false
    @AppStorage("team.share.evidence") private var shareEvidence = false
    @AppStorage("team.share.releases") private var shareReleases = false
    
    // Upload state
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showingUploadError = false
    @State private var uploadSuccess: String?
    @State private var showingUploadSuccess = false
    
    // Team artifacts
    @State private var teamArtifacts: [TeamArtifactMetadata] = []
    @State private var isLoadingArtifacts = false
    
    var body: some View {
        NavigationView {
            List {
                // What CAN be shared
                whatCanShareSection
                
                // What is NEVER shared
                whatNeverSharesSection
                
                // Upload toggles
                uploadTogglesSection
                
                // Team artifacts
                if teamStore.hasTeam {
                    teamArtifactsSection
                }
                
                // Manual upload
                if teamStore.hasTeam {
                    uploadNowSection
                }
            }
            .navigationTitle("Artifact Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Upload Error", isPresented: $showingUploadError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(uploadError ?? "Unknown error")
            }
            .alert("Upload Complete", isPresented: $showingUploadSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(uploadSuccess ?? "Artifacts uploaded successfully")
            }
            .refreshable {
                await loadTeamArtifacts()
            }
            .task {
                await loadTeamArtifacts()
            }
        }
    }
    
    // MARK: - What Can Share
    
    private var whatCanShareSection: some View {
        Section {
            ForEach(TeamSafetyConfig.TeamArtifactType.allCases, id: \.self) { type in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(type.displayName)
                            .font(.subheadline)
                        Text(type.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("What Teams Can Share")
        } footer: {
            Text("These are metadata-only artifacts. They contain settings, metrics, and references — never your personal content.")
        }
    }
    
    // MARK: - What Never Shares
    
    private var whatNeverSharesSection: some View {
        Section {
            neverShareRow("Drafts", description: "Email, calendar, reminder drafts", icon: "envelope")
            neverShareRow("Memory Items", description: "Your saved preferences", icon: "brain.head.profile")
            neverShareRow("Context Packets", description: "Selected calendar events", icon: "calendar")
            neverShareRow("User Inputs", description: "Your requests and prompts", icon: "text.bubble")
            neverShareRow("Execution State", description: "What you're working on", icon: "play.circle")
        } header: {
            Text("What Is NEVER Shared")
        } footer: {
            Text("Your personal content, drafts, and execution activity are never uploaded or shared with your team.")
        }
    }
    
    private func neverShareRow(_ title: String, description: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Upload Toggles
    
    private var uploadTogglesSection: some View {
        Section {
            Toggle(isOn: $sharePolicyTemplates) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Policy Templates")
                        .font(.subheadline)
                    Text("Share policy settings with team")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Toggle(isOn: $shareDiagnostics) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Diagnostics Snapshots")
                        .font(.subheadline)
                    Text("Share execution stats")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Toggle(isOn: $shareQuality) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quality Summaries")
                        .font(.subheadline)
                    Text("Share quality metrics")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Toggle(isOn: $shareEvidence) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Evidence References")
                        .font(.subheadline)
                    Text("Share audit hashes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Toggle(isOn: $shareReleases) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Release Acknowledgements")
                        .font(.subheadline)
                    Text("Share release sign-offs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Auto-Upload Settings")
        } footer: {
            Text("When enabled, these artifact types will be included when you tap \"Upload to Team\".")
        }
        .disabled(!teamStore.hasTeam)
    }
    
    // MARK: - Team Artifacts
    
    private var teamArtifactsSection: some View {
        Section {
            if isLoadingArtifacts {
                HStack {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
            } else if teamArtifacts.isEmpty {
                Text("No team artifacts yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(teamArtifacts) { artifact in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(artifact.artifactTypeDisplayName)
                                .font(.subheadline)
                            Text("\(artifact.formattedSize) • \(artifact.uploadedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if teamStore.canManageMembers {
                            Button(role: .destructive) {
                                Task { await deleteArtifact(artifact) }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            Button {
                Task { await loadTeamArtifacts() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
            }
        } header: {
            Text("Team Artifacts (\(teamArtifacts.count))")
        }
    }
    
    // MARK: - Upload Now
    
    private var uploadNowSection: some View {
        Section {
            Button {
                Task { await uploadSelectedArtifacts() }
            } label: {
                HStack {
                    if isUploading {
                        ProgressView()
                            .padding(.trailing, 8)
                    } else {
                        Image(systemName: "icloud.and.arrow.up")
                    }
                    Text("Upload to Team")
                    Spacer()
                }
            }
            .disabled(!hasSelectedTypes || isUploading)
        } header: {
            Text("Manual Upload")
        } footer: {
            Text("Upload selected artifact types to your team. This is a manual action — no automatic uploads.")
        }
    }
    
    // MARK: - Helpers
    
    private var hasSelectedTypes: Bool {
        sharePolicyTemplates || shareDiagnostics || shareQuality || shareEvidence || shareReleases
    }
    
    private func loadTeamArtifacts() async {
        guard let team = teamStore.currentTeam else { return }
        
        isLoadingArtifacts = true
        do {
            teamArtifacts = try await TeamSupabaseClient.shared.listTeamArtifacts(teamId: team.id)
        } catch {
            // Handle silently
        }
        isLoadingArtifacts = false
    }
    
    private func deleteArtifact(_ artifact: TeamArtifactMetadata) async {
        do {
            try await TeamSupabaseClient.shared.deleteTeamArtifact(artifactId: artifact.id)
            teamArtifacts.removeAll { $0.id == artifact.id }
        } catch {
            uploadError = error.localizedDescription
            showingUploadError = true
        }
    }
    
    private func uploadSelectedArtifacts() async {
        guard let team = teamStore.currentTeam,
              let userId = SupabaseClient.shared.currentUser?.id else { return }
        
        isUploading = true
        var uploadedCount = 0
        var errorMessages: [String] = []
        
        // Upload policy template if enabled
        if sharePolicyTemplates {
            do {
                let policy = OperatorPolicyStore.shared.currentPolicy
                let template = TeamPolicyTemplate.fromPolicy(
                    policy,
                    name: "Policy from \(Date().formatted(date: .abbreviated, time: .shortened))",
                    description: "Shared policy template",
                    createdBy: userId
                )
                let data = try template.exportJSON()
                _ = try await TeamSupabaseClient.shared.uploadTeamArtifact(
                    teamId: team.id,
                    artifactType: .policyTemplate,
                    jsonData: data
                )
                uploadedCount += 1
            } catch {
                errorMessages.append("Policy: \(error.localizedDescription)")
            }
        }
        
        // Upload diagnostics if enabled
        if shareDiagnostics {
            do {
                let diagnostics = DiagnosticsExportBuilder().buildPacket()
                let snapshot = TeamDiagnosticsSnapshot.fromDiagnostics(diagnostics, capturedBy: userId)
                let data = try snapshot.exportJSON()
                _ = try await TeamSupabaseClient.shared.uploadTeamArtifact(
                    teamId: team.id,
                    artifactType: .diagnosticsSnapshot,
                    jsonData: data
                )
                uploadedCount += 1
            } catch {
                errorMessages.append("Diagnostics: \(error.localizedDescription)")
            }
        }
        
        // TODO: Add quality, evidence, releases when those artifacts are available
        
        isUploading = false
        
        if errorMessages.isEmpty && uploadedCount > 0 {
            uploadSuccess = "Uploaded \(uploadedCount) artifact(s)"
            showingUploadSuccess = true
            await loadTeamArtifacts()
        } else if !errorMessages.isEmpty {
            uploadError = errorMessages.joined(separator: "\n")
            showingUploadError = true
        }
    }
}

#Preview {
    ArtifactSharingView()
}
