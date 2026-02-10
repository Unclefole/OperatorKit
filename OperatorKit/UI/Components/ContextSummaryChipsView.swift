import SwiftUI

/// Shows a summary of selected context items as chips (Phase 5C)
/// Reflects AppState.selectedContext only — no new data access
struct ContextSummaryChipsView: View {
    @EnvironmentObject var appState: AppState
    let compact: Bool
    
    init(compact: Bool = false) {
        self.compact = compact
    }
    
    /// Counts from selected context
    private var calendarCount: Int {
        appState.selectedContext?.calendarItems.count ?? 0
    }
    
    private var emailCount: Int {
        appState.selectedContext?.emailItems.count ?? 0
    }
    
    private var fileCount: Int {
        appState.selectedContext?.fileItems.count ?? 0
    }
    
    private var totalCount: Int {
        calendarCount + emailCount + fileCount
    }
    
    private var hasContext: Bool {
        totalCount > 0
    }
    
    var body: some View {
        if compact {
            compactView
        } else {
            standardView
        }
    }
    
    // MARK: - Standard View
    private var standardView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(OKColor.textSecondary)
                
                Text("Context Included")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(OKColor.textSecondary)
                
                Spacer()
                
                if hasContext {
                    Text("\(totalCount) item\(totalCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
            
            // Chips
            if hasContext {
                HStack(spacing: 8) {
                    if calendarCount > 0 {
                        contextChip(
                            icon: "calendar",
                            label: "Calendar",
                            count: calendarCount,
                            color: OKColor.riskCritical
                        )
                    }
                    
                    if emailCount > 0 {
                        contextChip(
                            icon: "envelope.fill",
                            label: "Email",
                            count: emailCount,
                            color: OKColor.actionPrimary
                        )
                    }
                    
                    if fileCount > 0 {
                        contextChip(
                            icon: "doc.fill",
                            label: "Files",
                            count: fileCount,
                            color: OKColor.riskWarning
                        )
                    }
                    
                    Spacer()
                }
            } else {
                noContextView
            }
        }
        .padding(12)
        .background(OKColor.textMuted.opacity(0.05))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
    
    // MARK: - Compact View (inline)
    private var compactView: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(OKColor.textSecondary)
            
            if hasContext {
                if calendarCount > 0 {
                    compactChip(icon: "calendar", count: calendarCount, color: OKColor.riskCritical)
                }
                if emailCount > 0 {
                    compactChip(icon: "envelope.fill", count: emailCount, color: OKColor.actionPrimary)
                }
                if fileCount > 0 {
                    compactChip(icon: "doc.fill", count: fileCount, color: OKColor.riskWarning)
                }
            } else {
                Text("No context")
                    .font(.caption2)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
    
    // MARK: - Context Chip
    private func contextChip(icon: String, label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            
            Text("\(label): \(count)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(14)
    }
    
    // MARK: - Compact Chip
    private func compactChip(icon: String, count: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - No Context View
    private var noContextView: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundColor(OKColor.textSecondary)
            
            Text("No context selected")
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Accessibility
    private var accessibilityDescription: String {
        if !hasContext {
            return "No context selected"
        }
        
        var parts: [String] = []
        if calendarCount > 0 {
            parts.append("\(calendarCount) calendar event\(calendarCount == 1 ? "" : "s")")
        }
        if emailCount > 0 {
            parts.append("\(emailCount) email\(emailCount == 1 ? "" : "s")")
        }
        if fileCount > 0 {
            parts.append("\(fileCount) file\(fileCount == 1 ? "" : "s")")
        }
        
        return "Context included: \(parts.joined(separator: ", "))"
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ContextSummaryChipsView()
            .environmentObject(AppState())
        
        ContextSummaryChipsView(compact: true)
            .environmentObject(AppState())
    }
    .padding()
}
