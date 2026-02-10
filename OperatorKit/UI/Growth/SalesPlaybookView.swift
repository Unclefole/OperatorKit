import SwiftUI

// ============================================================================
// SALES PLAYBOOK VIEW (Phase 11B)
//
// Read-only sales playbook for founders.
// Searchable by section title.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No editing
// ❌ No user content
// ✅ Read-only
// ✅ Searchable
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct SalesPlaybookView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var expandedSections: Set<String> = []
    
    var body: some View {
        NavigationView {
            List {
                // Search results or full content
                if searchText.isEmpty {
                    fullPlaybookContent
                } else {
                    filteredPlaybookContent
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Sales Playbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search sections")
        }
    }
    
    // MARK: - Full Playbook Content
    
    private var fullPlaybookContent: some View {
        Group {
            // All sections
            ForEach(SalesPlaybookContent.allSections) { section in
                PlaybookSectionView(
                    section: section,
                    isExpanded: expandedSections.contains(section.id)
                ) {
                    toggleSection(section.id)
                }
            }
            
            // Objections section
            objectionsSection
        }
    }
    
    // MARK: - Filtered Content
    
    private var filteredPlaybookContent: some View {
        let filteredSections = SalesPlaybookContent.allSections.filter { section in
            section.title.localizedCaseInsensitiveContains(searchText) ||
            section.content.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        
        let filteredObjections = SalesPlaybookContent.objections.filter { objection in
            objection.objection.localizedCaseInsensitiveContains(searchText) ||
            objection.response.localizedCaseInsensitiveContains(searchText)
        }
        
        return Group {
            if filteredSections.isEmpty && filteredObjections.isEmpty {
                Section {
                    Text("No results for \"\(searchText)\"")
                        .foregroundColor(OKColor.textSecondary)
                }
            } else {
                ForEach(filteredSections) { section in
                    PlaybookSectionView(section: section, isExpanded: true) {}
                }
                
                if !filteredObjections.isEmpty {
                    Section {
                        ForEach(filteredObjections) { objection in
                            ObjectionRow(objection: objection)
                        }
                    } header: {
                        Label("Objection Handling", systemImage: "bubble.left.and.bubble.right")
                    }
                }
            }
        }
    }
    
    // MARK: - Objections Section
    
    private var objectionsSection: some View {
        Section {
            ForEach(SalesPlaybookContent.objections) { objection in
                ObjectionRow(objection: objection)
            }
        } header: {
            Label("Objection Handling", systemImage: "bubble.left.and.bubble.right")
        } footer: {
            Text("Common objections and factual responses.")
        }
    }
    
    // MARK: - Actions
    
    private func toggleSection(_ id: String) {
        if expandedSections.contains(id) {
            expandedSections.remove(id)
        } else {
            expandedSections.insert(id)
        }
    }
}

// MARK: - Playbook Section View

private struct PlaybookSectionView: View {
    let section: PlaybookSection
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Section {
            DisclosureGroup(isExpanded: .constant(isExpanded)) {
                ForEach(Array(section.content.enumerated()), id: \.offset) { index, item in
                    ContentRow(text: item)
                }
            } label: {
                Button(action: onToggle) {
                    Label(section.title, systemImage: section.icon)
                        .font(.headline)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Content Row

private struct ContentRow: View {
    let text: String
    
    var body: some View {
        if text.contains("**") {
            // Parse bold text
            formattedText
        } else {
            Text(text)
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
                .padding(.vertical, 4)
        }
    }
    
    private var formattedText: some View {
        let parts = text.components(separatedBy: "**")
        
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if index % 2 == 1 {
                    // Bold part
                    Text(part)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else if !part.isEmpty {
                    Text(part)
                        .font(.subheadline)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Objection Row

private struct ObjectionRow: View {
    let objection: PlaybookObjection
    
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Response:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(OKColor.actionPrimary)
                
                Text(objection.response)
                    .font(.subheadline)
                    .foregroundColor(OKColor.textSecondary)
            }
            .padding(.vertical, 4)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Objection:")
                    .font(.caption)
                    .foregroundColor(OKColor.riskWarning)
                
                Text(objection.objection)
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SalesPlaybookView()
}
