import SwiftUI

// ============================================================================
// OUTCOME TEMPLATES VIEW (Phase 10O)
//
// Browsable list of outcome templates by category.
// "Use Template" pre-fills intent text only.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No auto-execution
// ❌ No auto-context selection
// ❌ No forced interaction
// ✅ Pre-fills intent text
// ✅ User selects context
// ✅ User approves execution
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct OutcomeTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var outcomeLedger = OutcomeLedger.shared
    
    @State private var selectedCategory: OutcomeCategory?
    
    /// Callback when user wants to use a template
    var onUseTemplate: ((OutcomeTemplate) -> Void)?
    
    var body: some View {
        NavigationView {
            List {
                // Categories
                ForEach(OutcomeCategory.allCases, id: \.self) { category in
                    Section {
                        ForEach(OutcomeTemplates.templates(for: category)) { template in
                            OutcomeTemplateRow(
                                template: template,
                                onUse: {
                                    outcomeLedger.recordUsed(templateId: template.id)
                                    onUseTemplate?(template)
                                    dismiss()
                                }
                            )
                        }
                    } header: {
                        HStack {
                            Image(systemName: category.icon)
                            Text(category.displayName)
                        }
                    }
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                outcomeLedger.recordShown()
            }
        }
    }
}

// MARK: - Outcome Template Row

private struct OutcomeTemplateRow: View {
    let template: OutcomeTemplate
    let onUse: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(template.templateTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            Text(template.sampleIntent)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if !template.suggestedContextTypeIds.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "doc.badge.plus")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Works with: \(template.suggestedContextTypeIds.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Button {
                onUse()
            } label: {
                HStack {
                    Image(systemName: "arrow.right.circle")
                    Text("Use Template")
                }
                .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    OutcomeTemplatesView()
}
