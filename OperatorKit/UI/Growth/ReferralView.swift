import SwiftUI

// ============================================================================
// REFERRAL VIEW (Phase 11A)
//
// UI for sharing referral code.
// Local interest tracking only. No server validation.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No server validation
// ❌ No recipient tracking
// ❌ No message content storage
// ✅ Local counts only
// ✅ User-initiated sharing
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct ReferralView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var codeStore = ReferralCodeStore.shared
    @StateObject private var ledger = ReferralLedger.shared
    
    @State private var showingShare = false
    @State private var copied = false
    @State private var showingHowItWorks = false
    
    var body: some View {
        NavigationView {
            List {
                // Code Section
                codeSection
                
                // Share Actions
                shareActionsSection
                
                // How It Works
                howItWorksSection
                
                // Stats
                statsSection
            }
            .scrollContentBackground(.hidden)
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                ledger.recordAction(.viewed)
            }
            .sheet(isPresented: $showingShare) {
                if let code = codeStore.currentCode {
                    ShareSheet(items: [shareMessage(code: code.code)])
                }
            }
        }
    }
    
    // MARK: - Code Section
    
    private var codeSection: some View {
        Section {
            VStack(spacing: 16) {
                Text("Your Referral Code")
                    .font(.subheadline)
                    .foregroundColor(OKColor.textSecondary)
                
                let code = codeStore.getOrGenerateCode()
                
                Text(code.code)
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(OKColor.actionPrimary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(OKColor.actionPrimary.opacity(0.1))
                    .cornerRadius(12)
                
                if copied {
                    Label("Copied!", systemImage: "checkmark")
                        .font(.caption)
                        .foregroundColor(OKColor.riskNominal)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Share Actions Section
    
    private var shareActionsSection: some View {
        Section {
            // Copy Button
            Button {
                copyCode()
            } label: {
                Label("Copy Code", systemImage: "doc.on.doc")
            }
            
            // Share Button
            Button {
                shareCode()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            // Email Invite
            Button {
                openEmailInvite()
            } label: {
                Label("Invite via Email", systemImage: "envelope")
            }
            
            // Message Invite
            Button {
                openMessageInvite()
            } label: {
                Label("Invite via Message", systemImage: "message")
            }
        } header: {
            Text("Share")
        }
    }
    
    // MARK: - How It Works Section
    
    private var howItWorksSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showingHowItWorks) {
                VStack(alignment: .leading, spacing: 12) {
                    HowItWorksRow(
                        number: 1,
                        text: "Share your code with friends"
                    )
                    HowItWorksRow(
                        number: 2,
                        text: "They download OperatorKit"
                    )
                    HowItWorksRow(
                        number: 3,
                        text: "Everyone gets the best experience"
                    )
                }
                .padding(.vertical, 8)
            } label: {
                Label("How Referrals Work", systemImage: "questionmark.circle")
            }
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        Section {
            HStack {
                Text("Times Shared")
                Spacer()
                Text("\(ledger.shareTappedCount)")
                    .foregroundColor(OKColor.textSecondary)
            }
            
            HStack {
                Text("Times Copied")
                Spacer()
                Text("\(ledger.copyTappedCount)")
                    .foregroundColor(OKColor.textSecondary)
            }
        } header: {
            Text("Your Activity")
        } footer: {
            Text("Counts are stored locally on this device only.")
        }
    }
    
    // MARK: - Actions
    
    private func copyCode() {
        let code = codeStore.getOrGenerateCode()
        UIPasteboard.general.string = code.code
        ledger.recordAction(.copyTapped)
        
        withAnimation {
            copied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }
    
    private func shareCode() {
        ledger.recordAction(.shareTapped)
        showingShare = true
    }
    
    private func openEmailInvite() {
        let code = codeStore.getOrGenerateCode()
        let subject = "Check out OperatorKit"
        let body = shareMessage(code: code.code)
        
        let encoded = "mailto:?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: encoded) {
            UIApplication.shared.open(url)
            ledger.recordAction(.inviteEmailOpened)
        }
    }
    
    private func openMessageInvite() {
        let code = codeStore.getOrGenerateCode()
        let body = shareMessage(code: code.code)
        
        let encoded = "sms:&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: encoded) {
            UIApplication.shared.open(url)
            ledger.recordAction(.inviteMessageOpened)
        }
    }
    
    private func shareMessage(code: String) -> String {
        """
        Try OperatorKit - draft-first task assistance that you control.
        
        My referral code: \(code)
        
        Download: [App Store Link]
        """
    }
}

// MARK: - How It Works Row

private struct HowItWorksRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(OKColor.textPrimary)
                .frame(width: 24, height: 24)
                .background(OKColor.actionPrimary)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    ReferralView()
}
