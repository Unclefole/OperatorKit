import SwiftUI

// ============================================================================
// SYNC SETTINGS VIEW (Phase 10D)
//
// User interface for opt-in cloud sync settings.
// Sync is OFF by default. Manual upload only.
//
// SECTIONS:
// - Account (sign in/out)
// - Sync toggle (OFF by default)
// - What Sync Uploads (explicit list)
// - Staged Packets (list + sizes)
// - Upload Now button
// - Delete from cloud button
// - Disclaimers
//
// See: docs/SAFETY_CONTRACT.md (Section 13)
// ============================================================================

struct SyncSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabaseClient = SupabaseClient.shared
    @StateObject private var syncQueue = SyncQueue.shared
    
    // Sync enabled toggle (OFF by default)
    @AppStorage(SyncFeatureFlag.storageKey) private var syncEnabled = SyncFeatureFlag.defaultToggleState
    
    // Sign in flow
    @State private var showingSignIn = false
    @State private var email = ""
    @State private var otpCode = ""
    @State private var isAwaitingOTP = false
    @State private var signInError: String?
    
    // Upload flow
    @State private var isUploading = false
    @State private var showingUploadConfirmation = false
    @State private var uploadResult: UploadResult?
    
    // Cloud packets
    @State private var cloudPackets: [SyncPacketMetadata] = []
    @State private var isLoadingCloudPackets = false
    @State private var showingDeleteConfirmation = false
    @State private var packetToDelete: SyncPacketMetadata?
    
    var body: some View {
        NavigationView {
            List {
                // Sync toggle
                syncToggleSection
                
                if syncEnabled {
                    // Account
                    accountSection
                    
                    // What syncs
                    whatSyncsSection
                    
                    // Staged packets
                    if !syncQueue.stagedPackets.isEmpty {
                        stagedPacketsSection
                    }
                    
                    // Cloud packets (if signed in)
                    if supabaseClient.isSignedIn {
                        cloudPacketsSection
                    }
                    
                    // Disclaimers
                    disclaimerSection
                }
            }
            .navigationTitle("Cloud Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSignIn) {
                signInSheet
            }
            .alert("Upload Packets?", isPresented: $showingUploadConfirmation) {
                Button("Upload", role: .none) {
                    Task { await performUpload() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(preFlightMessage)
            }
            .alert("Delete Packet?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let packet = packetToDelete {
                        Task { await deleteCloudPacket(packet) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let packet = packetToDelete {
                    Text("Delete \(packet.packetTypeDisplayName) from cloud? This cannot be undone.")
                }
            }
            .refreshable {
                if supabaseClient.isSignedIn {
                    await loadCloudPackets()
                }
            }
        }
    }
    
    // MARK: - Sync Toggle Section
    
    private var syncToggleSection: some View {
        Section {
            Toggle(isOn: $syncEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Cloud Sync")
                        .font(.body)
                    Text("Sync metadata-only packets to the cloud")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !syncEnabled {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    Text("All data stays on your device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Sync")
        } footer: {
            if !syncEnabled {
                Text("When disabled, no data leaves your device. OperatorKit works fully offline.")
            }
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section {
            if supabaseClient.isSignedIn {
                // Signed in
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(supabaseClient.currentUser?.email ?? "Signed In")
                            .font(.subheadline)
                        Text("Tap to sign out")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if supabaseClient.isLoading {
                        ProgressView()
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Task { await signOut() }
                }
            } else {
                // Not signed in
                Button {
                    showingSignIn = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.blue)
                        Text("Sign In")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                if !supabaseClient.isConfigured {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Cloud sync not configured")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Account")
        }
    }
    
    // MARK: - What Syncs Section
    
    private var whatSyncsSection: some View {
        Section {
            ForEach(SyncSafetyConfig.SyncablePacketType.allCases, id: \.self) { type in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(displayName(for: type))
                        .font(.subheadline)
                }
            }
            
            Divider()
            
            // What does NOT sync
            VStack(alignment: .leading, spacing: 8) {
                Text("Never Uploaded:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                ForEach(["Drafts", "Memory items", "User inputs", "Calendar/email content"], id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text(item)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("What Syncs")
        } footer: {
            Text("Only metadata-only packets are uploaded. Your drafts and personal content never leave your device.")
        }
    }
    
    // MARK: - Staged Packets Section
    
    private var stagedPacketsSection: some View {
        Section {
            ForEach(syncQueue.stagedPackets) { packet in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(packet.packetTypeDisplayName)
                            .font(.subheadline)
                        Text("\(packet.formattedSize) • Schema v\(packet.schemaVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        syncQueue.removePacket(id: packet.id)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Upload button
            Button {
                showingUploadConfirmation = true
            } label: {
                HStack {
                    if isUploading {
                        ProgressView()
                            .padding(.trailing, 8)
                    } else {
                        Image(systemName: "icloud.and.arrow.up")
                    }
                    Text("Upload Now")
                    Spacer()
                    Text(syncQueue.summary.formattedTotalSize)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!supabaseClient.isSignedIn || isUploading)
            
            // Upload result
            if let result = uploadResult {
                HStack(spacing: 8) {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(result.success ? .green : .orange)
                    Text(result.summaryText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Staged for Upload (\(syncQueue.stagedPackets.count))")
        } footer: {
            Text("Packets are uploaded only when you tap \"Upload Now\". No automatic or background uploads.")
        }
    }
    
    // MARK: - Cloud Packets Section
    
    private var cloudPacketsSection: some View {
        Section {
            if isLoadingCloudPackets {
                HStack {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
            } else if cloudPackets.isEmpty {
                Text("No packets in cloud")
                    .foregroundColor(.secondary)
            } else {
                ForEach(cloudPackets) { packet in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(packet.packetTypeDisplayName)
                                .font(.subheadline)
                            Text("\(packet.formattedSize) • \(packet.uploadedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            packetToDelete = packet
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Button {
                Task { await loadCloudPackets() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
            }
        } header: {
            Text("In Cloud (\(cloudPackets.count))")
        }
    }
    
    // MARK: - Disclaimer Section
    
    private var disclaimerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.blue)
                    Text("Privacy Guarantees")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    guaranteeRow("Uploads metadata-only packets")
                    guaranteeRow("Manual upload only — you control when")
                    guaranteeRow("No background sync")
                    guaranteeRow("No drafts or content uploaded")
                    guaranteeRow("You can delete cloud data anytime")
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func guaranteeRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.caption)
                .foregroundColor(.green)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Sign In Sheet
    
    private var signInSheet: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(isAwaitingOTP)
                    
                    if isAwaitingOTP {
                        TextField("Enter code from email", text: $otpCode)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                    }
                    
                    if let error = signInError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Sign In with Email")
                } footer: {
                    Text(isAwaitingOTP ? "Check your email for the verification code." : "We'll send you a one-time code.")
                }
                
                Section {
                    Button {
                        Task { await handleSignInAction() }
                    } label: {
                        HStack {
                            if supabaseClient.isLoading {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isAwaitingOTP ? "Verify Code" : "Send Code")
                        }
                    }
                    .disabled(supabaseClient.isLoading || email.isEmpty || (isAwaitingOTP && otpCode.isEmpty))
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        resetSignInState()
                        showingSignIn = false
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleSignInAction() async {
        signInError = nil
        
        do {
            if isAwaitingOTP {
                try await supabaseClient.verifyOTP(email: email, token: otpCode)
                resetSignInState()
                showingSignIn = false
                await loadCloudPackets()
            } else {
                try await supabaseClient.requestOTP(email: email)
                isAwaitingOTP = true
            }
        } catch {
            signInError = error.localizedDescription
        }
    }
    
    private func signOut() async {
        do {
            try await supabaseClient.signOut()
            cloudPackets = []
        } catch {
            // Handle silently
        }
    }
    
    private func resetSignInState() {
        email = ""
        otpCode = ""
        isAwaitingOTP = false
        signInError = nil
    }
    
    private func performUpload() async {
        isUploading = true
        uploadResult = await syncQueue.uploadStagedPacketsNow()
        isUploading = false
        
        if uploadResult?.success == true {
            await loadCloudPackets()
        }
    }
    
    private func loadCloudPackets() async {
        guard supabaseClient.isSignedIn else { return }
        
        isLoadingCloudPackets = true
        do {
            cloudPackets = try await supabaseClient.listPackets()
        } catch {
            // Handle silently
        }
        isLoadingCloudPackets = false
    }
    
    private func deleteCloudPacket(_ packet: SyncPacketMetadata) async {
        do {
            try await supabaseClient.deletePacket(id: packet.id)
            cloudPackets.removeAll { $0.id == packet.id }
        } catch {
            // Handle silently
        }
    }
    
    // MARK: - Helpers
    
    private var preFlightMessage: String {
        let report = SyncPacketValidator.shared.preFlightCheck(packets: syncQueue.stagedPackets)
        return report.summaryText
    }
    
    private func displayName(for type: SyncSafetyConfig.SyncablePacketType) -> String {
        switch type {
        case .qualityExport: return "Quality Exports"
        case .diagnosticsExport: return "Diagnostics Exports"
        case .policyExport: return "Policy Exports"
        case .releaseAcknowledgement: return "Release Acknowledgements"
        case .evidencePacket: return "Evidence Packets"
        }
    }
}

// MARK: - Preview

#Preview {
    SyncSettingsView()
}
