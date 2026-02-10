import SwiftUI

// ============================================================================
// OUTBOUND KIT VIEW (Phase 11A)
//
// UI for outbound email templates.
// Copy to clipboard. Open Mail with placeholders only.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No auto-send
// ❌ No auto-filled personal info
// ✅ User-initiated only
// ✅ Placeholder-based templates
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct OutboundKitView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ledger = OutboundTemplatesLedger.shared
    
    @State private var selectedTemplate: OutboundTemplate?
    @State private var showingTemplateDetail = false
    @State private var copied = false
    
    var body: some View {
        NavigationView {
            List {
                // Overview
                overviewSection
                
                // Templates by Category
                ForEach(OutboundTemplateCategory.allCases, id: \.self) { category in
                    if let templates = OutboundTemplates.byCategory[category], !templates.isEmpty {
                        Section {
                            ForEach(templates) { template in
                                TemplateRow(template: template) {
                                    selectedTemplate = template
                                    showingTemplateDetail = true
                                }
                            }
                        } header: {
                            Label(category.displayName, systemImage: category.icon)
                        }
                    }
                }
                
                // Stats
                statsSection
            }
            .navigationTitle("Outbound Kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingTemplateDetail) {
                if let template = selectedTemplate {
                    TemplateDetailView(template: template)
                }
            }
        }
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Templates for Sales")
                    .font(.headline)
                
                Text("Ready-to-use templates with placeholders. Copy to clipboard or open in Mail.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        Section {
            HStack {
                Text("Templates Copied")
                Spacer()
                Text("\(ledger.totalCopies)")
                    .foregroundColor(OKColor.textSecondary)
            }
            
            HStack {
                Text("Emails Opened")
                Spacer()
                Text("\(ledger.totalMailOpens)")
                    .foregroundColor(OKColor.textSecondary)
            }
            
            if let mostUsed = ledger.mostUsedTemplateId(),
               let template = OutboundTemplates.all.first(where: { $0.id == mostUsed }) {
                HStack {
                    Text("Most Used")
                    Spacer()
                    Text(template.templateName)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
        } header: {
            Text("Usage")
        } footer: {
            Text("Counts are stored locally on this device only.")
        }
    }
}

// MARK: - Template Row

private struct TemplateRow: View {
    let template: OutboundTemplate
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.templateName)
                        .font(.subheadline)
                        .foregroundColor(OKColor.textPrimary)
                    
                    Text(template.subjectTemplate)
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
    }
}

// MARK: - Template Detail View

private struct TemplateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ledger = OutboundTemplatesLedger.shared
    
    let template: OutboundTemplate
    
    @State private var copied = false
    
    var body: some View {
        NavigationView {
            List {
                // Subject
                Section {
                    Text(template.subjectTemplate)
                        .font(.subheadline)
                } header: {
                    Text("Subject")
                }
                
                // Body
                Section {
                    Text(template.bodyTemplate)
                        .font(.caption)
                } header: {
                    Text("Body")
                } footer: {
                    Text("Replace [placeholders] with your information before sending.")
                }
                
                // Actions
                Section {
                    Button {
                        copyTemplate()
                    } label: {
                        HStack {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                            
                            Spacer()
                            
                            if copied {
                                Text("Copied!")
                                    .font(.caption)
                                    .foregroundColor(OKColor.riskNominal)
                            }
                        }
                    }
                    
                    Button {
                        openInMail()
                    } label: {
                        Label("Open in Mail", systemImage: "envelope")
                    }
                } header: {
                    Text("Actions")
                }
            }
            .navigationTitle(template.templateName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func copyTemplate() {
        let fullText = """
        Subject: \(template.subjectTemplate)
        
        \(template.bodyTemplate)
        """
        
        UIPasteboard.general.string = fullText
        ledger.recordCopy(templateId: template.id)
        
        withAnimation {
            copied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }
    
    private func openInMail() {
        let subject = template.subjectTemplate
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = template.bodyTemplate
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Note: No recipient pre-filled - user must add
        let urlString = "mailto:?subject=\(subject)&body=\(body)"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
            ledger.recordMailOpen(templateId: template.id)
        }
    }
}

// MARK: - Preview

#Preview {
    OutboundKitView()
}
