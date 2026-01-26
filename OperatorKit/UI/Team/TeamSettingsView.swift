import SwiftUI

// ============================================================================
// TEAM SETTINGS VIEW (Phase 10E)
//
// User interface for team management and artifact sharing.
// Clear disclosure: "No drafts, no content, no execution is shared"
//
// See: docs/SAFETY_CONTRACT.md (Section 14)
// ============================================================================

struct TeamSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var teamStore = TeamStore.shared
    @StateObject private var supabaseClient = SupabaseClient.shared
    
    // Team creation/join
    @State private var showingCreateTeam = false
    @State private var showingJoinTeam = false
    @State private var newTeamName = ""
    @State private var inviteCode = ""
    
    // Member management
    @State private var showingInviteMember = false
    @State private var inviteEmail = ""
    @State private var inviteRole: TeamRole = .member
    
    // Artifact sharing
    @State private var showingArtifactSharing = false
    
    // Error handling
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            List {
                if !supabaseClient.isSignedIn {
                    signInRequiredSection
                } else if let team = teamStore.currentTeam {
                    teamInfoSection(team)
                    membersSection
                    artifactSharingSection
                    leaveTeamSection
                } else {
                    noTeamSection
                }
                
                // Always show disclosure
                disclosureSection
            }
            .navigationTitle("Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCreateTeam) {
                createTeamSheet
            }
            .sheet(isPresented: $showingJoinTeam) {
                joinTeamSheet
            }
            .sheet(isPresented: $showingInviteMember) {
                inviteMemberSheet
            }
            .sheet(isPresented: $showingArtifactSharing) {
                ArtifactSharingView()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .refreshable {
                await teamStore.refreshTeam()
            }
            .task {
                await teamStore.refreshTeam()
            }
        }
    }
    
    // MARK: - Sign In Required
    
    private var signInRequiredSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                
                Text("Sign In Required")
                    .font(.headline)
                
                Text("Sign in to your account to access team features.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }
    
    // MARK: - No Team
    
    private var noTeamSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "person.3")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("No Team")
                    .font(.headline)
                
                Text("Create a team or join an existing one to share governance artifacts.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            
            Button {
                showingCreateTeam = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Team")
                    Spacer()
                }
            }
            
            Button {
                showingJoinTeam = true
            } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Join Team")
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Team Info
    
    private func teamInfoSection(_ team: TeamAccount) -> some View {
        Section {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(team.name)
                        .font(.headline)
                    Text("Team ID: \(team.shortId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: team.memberRole.icon)
                            .font(.caption)
                        Text(team.memberRole.displayName)
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        } header: {
            Text("Your Team")
        }
    }
    
    // MARK: - Members
    
    private var membersSection: some View {
        Section {
            ForEach(teamStore.members) { member in
                HStack {
                    Image(systemName: member.role.icon)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.displayName)
                            .font(.subheadline)
                        Text(member.role.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if teamStore.canManageMembers && member.userId != supabaseClient.currentUser?.id {
                        Menu {
                            ForEach(TeamRole.allCases, id: \.self) { role in
                                Button {
                                    updateRole(member: member, to: role)
                                } label: {
                                    Label(role.displayName, systemImage: role.icon)
                                }
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                removeMember(member)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            if teamStore.canManageMembers {
                Button {
                    showingInviteMember = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.blue)
                        Text("Invite Member")
                    }
                }
            }
        } header: {
            Text("Members (\(teamStore.members.count))")
        }
    }
    
    // MARK: - Artifact Sharing
    
    private var artifactSharingSection: some View {
        Section {
            Button {
                showingArtifactSharing = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shared Artifacts")
                            .foregroundColor(.primary)
                        Text("View and manage team artifacts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        } header: {
            Text("Sharing")
        } footer: {
            Text("Share governance artifacts like policies, diagnostics, and quality summaries with your team.")
        }
    }
    
    // MARK: - Leave Team
    
    private var leaveTeamSection: some View {
        Section {
            Button(role: .destructive) {
                Task { await leaveTeam() }
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Leave Team")
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Disclosure
    
    private var disclosureSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    Text("Team Sharing Safety")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    disclosureRow("No drafts shared", safe: true)
                    disclosureRow("No content shared", safe: true)
                    disclosureRow("No execution shared", safe: true)
                    disclosureRow("No memory shared", safe: true)
                    disclosureRow("Metadata-only artifacts", safe: true)
                }
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Teams share governance artifacts only. Your drafts, personal content, and execution history are never shared.")
        }
    }
    
    private func disclosureRow(_ text: String, safe: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: safe ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(safe ? .green : .red)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Sheets
    
    private var createTeamSheet: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Team Name", text: $newTeamName)
                } header: {
                    Text("Create Team")
                } footer: {
                    Text("Choose a name for your team. You'll be the owner.")
                }
                
                Section {
                    Button {
                        Task { await createTeam() }
                    } label: {
                        HStack {
                            if teamStore.isLoading {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text("Create Team")
                        }
                    }
                    .disabled(newTeamName.isEmpty || teamStore.isLoading)
                }
            }
            .navigationTitle("New Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showingCreateTeam = false }
                }
            }
        }
    }
    
    private var joinTeamSheet: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Invite Code", text: $inviteCode)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Join Team")
                } footer: {
                    Text("Enter the invite code you received from a team admin.")
                }
                
                Section {
                    Button {
                        Task { await joinTeam() }
                    } label: {
                        HStack {
                            if teamStore.isLoading {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text("Join Team")
                        }
                    }
                    .disabled(inviteCode.isEmpty || teamStore.isLoading)
                }
            }
            .navigationTitle("Join Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showingJoinTeam = false }
                }
            }
        }
    }
    
    private var inviteMemberSheet: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $inviteEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    
                    Picker("Role", selection: $inviteRole) {
                        ForEach([TeamRole.member, TeamRole.admin], id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                } header: {
                    Text("Invite Member")
                } footer: {
                    Text("The member will receive an invite code via email.")
                }
                
                Section {
                    Button {
                        Task { await inviteMember() }
                    } label: {
                        HStack {
                            if teamStore.isLoading {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text("Send Invite")
                        }
                    }
                    .disabled(inviteEmail.isEmpty || teamStore.isLoading)
                }
            }
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showingInviteMember = false }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func createTeam() async {
        do {
            try await teamStore.createTeam(name: newTeamName)
            newTeamName = ""
            showingCreateTeam = false
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func joinTeam() async {
        do {
            try await teamStore.joinTeam(inviteCode: inviteCode)
            inviteCode = ""
            showingJoinTeam = false
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func leaveTeam() async {
        do {
            try await teamStore.leaveTeam()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func inviteMember() async {
        do {
            try await teamStore.inviteMember(email: inviteEmail, role: inviteRole)
            inviteEmail = ""
            showingInviteMember = false
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func updateRole(member: TeamMembership, to role: TeamRole) {
        Task {
            do {
                try await teamStore.updateMemberRole(userId: member.userId, newRole: role)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func removeMember(_ member: TeamMembership) {
        Task {
            do {
                try await teamStore.removeMember(userId: member.userId)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

#Preview {
    TeamSettingsView()
}
