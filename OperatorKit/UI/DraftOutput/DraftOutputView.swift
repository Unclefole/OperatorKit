import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DraftOutputView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState
    @State private var selectedTab: Int = 0
    @State private var isEditing: Bool = false
    @State private var editedBody: String = ""
    @State private var showingCitations: Bool = false
    
    var body: some View {
        ZStack {
            // Background
            OKColor.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Flow Step Header (Phase 5C)
                FlowStepHeaderView(
                    step: .draft,
                    subtitle: "Review the generated draft"
                )
                
                // Status Strip (Phase 5C)
                FlowStatusStripView(onRecoveryAction: handleRecoveryAction)
                
                // Header
                headerView
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Context Summary Chips (Phase 5C)
                        ContextSummaryChipsView()
                        
                        // Confidence Badge
                        if let draft = appState.currentDraft {
                            confidenceBadge(draft)
                        }
                        
                        // Safety Notes
                        if let draft = appState.currentDraft, !draft.safetyNotes.isEmpty {
                            safetyNotesCard(draft)
                        }
                        
                        // Tab Selector
                        tabSelector
                        
                        // Draft Content
                        if let draft = appState.currentDraft {
                            switch selectedTab {
                            case 0:
                                draftCard(draft)
                            case 1:
                                actionItemsCard(draft)
                            case 2:
                                citationsCard(draft)
                            default:
                                draftCard(draft)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 160)
                }
                
                Spacer()
            }
            
            // Bottom Actions
            VStack {
                Spacer()
                bottomActions
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let draft = appState.currentDraft {
                editedBody = draft.content.body
            }
        }
    }
    
    // MARK: - Recovery Action Handler (Phase 5C)
    private func handleRecoveryAction(_ action: OperatorKitUserFacingError.RecoveryAction) {
        switch action {
        case .goHome:
            nav.goHome()
        case .retryCurrentStep:
            appState.clearError()
        case .addMoreContext:
            nav.navigate(to: .context)
        case .editRequest:
            nav.navigate(to: .intent)
        default:
            appState.clearError()
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { nav.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(OKColor.actionPrimary)
            }

            Spacer()

            OperatorKitLogoView(size: .small, showText: false)

            Spacer()

            Button(action: { nav.goHome() }) {
                Image(systemName: "house")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(OKColor.textMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(OKColor.backgroundPrimary)
    }
    
    // MARK: - Confidence Badge
    private func confidenceBadge(_ draft: Draft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Confidence Icon
                ZStack {
                    Circle()
                        .fill(confidenceColor(draft.confidenceLevel).opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: draft.confidenceLevel.icon)
                        .font(.system(size: 20))
                        .foregroundColor(confidenceColor(draft.confidenceLevel))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(confidenceLabel(draft.confidenceLevel))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(confidenceColor(draft.confidenceLevel))
                    
                    Text(confidenceDescription(draft.confidenceLevel))
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            
            // Fallback indicator (non-alarmist)
            if let metadata = draft.modelMetadata, metadata.backend == .deterministic, metadata.fallbackReason != nil {
                fallbackIndicator
            }
        }
        .padding(16)
        .background(confidenceColor(draft.confidenceLevel).opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(confidenceColor(draft.confidenceLevel).opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Fallback Indicator (Non-alarmist)
    private var fallbackIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "cpu")
                .font(.system(size: 12))
                .foregroundColor(OKColor.textSecondary)
            
            Text("Deterministic fallback used")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(OKColor.textSecondary)
            
            Spacer()
            
            Text("A simpler on-device method was used to ensure reliability.")
                .font(.caption2)
                .foregroundColor(OKColor.textMuted)
                .lineLimit(1)
        }
        .padding(10)
        .background(OKColor.textMuted.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func confidenceColor(_ level: DraftOutput.ConfidenceLevel) -> Color {
        switch level {
        case .high: return OKColor.riskNominal
        case .medium: return OKColor.actionPrimary
        case .low: return OKColor.riskWarning
        case .veryLow: return OKColor.riskCritical
        }
    }
    
    private func confidenceDescription(_ level: DraftOutput.ConfidenceLevel) -> String {
        switch level {
        case .high: return "This draft was generated with strong alignment to your selected context."
        case .medium: return "The request is clear, but some details may require your judgment."
        case .low: return "The request is clear, but some details may require your judgment."
        case .veryLow: return "OperatorKit could not generate a reliable draft from the provided context."
        }
    }
    
    private func confidenceLabel(_ level: DraftOutput.ConfidenceLevel) -> String {
        switch level {
        case .high: return "High confidence"
        case .medium: return "Needs review"
        case .low: return "Needs review"
        case .veryLow: return "Insufficient confidence"
        }
    }
    
    // MARK: - Safety Notes Card
    private func safetyNotesCard(_ draft: Draft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(OKColor.actionPrimary)
                
                Text("Before You Continue")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(draft.safetyNotes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 12))
                            .foregroundColor(OKColor.actionPrimary)
                            .padding(.top, 2)
                        
                        Text(note)
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(OKColor.actionPrimary.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        let tabs = ["Draft", "Actions", "Sources"]
        
        return HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text(tab)
                                .font(.subheadline)
                                .fontWeight(selectedTab == index ? .semibold : .regular)
                            
                            // Badge for citations count
                            if index == 2, let draft = appState.currentDraft, !draft.citations.isEmpty {
                                Text("\(draft.citations.count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(OKColor.textPrimary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(selectedTab == index ? OKColor.actionPrimary : OKColor.textMuted)
                                    .cornerRadius(8)
                            }
                        }
                        .foregroundColor(selectedTab == index ? .primary : OKColor.textMuted)
                        
                        Rectangle()
                            .fill(selectedTab == index ? OKColor.actionPrimary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Draft Card
    private func draftCard(_ draft: Draft) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: draft.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(OKColor.actionPrimary)
                
                Text(draft.type.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    isEditing.toggle()
                }) {
                    Text(isEditing ? "Done" : "Edit")
                        .font(.subheadline)
                        .foregroundColor(OKColor.actionPrimary)
                }
            }
            
            Divider()
            
            // Email metadata (if email)
            if draft.type == .email {
                VStack(spacing: 8) {
                    HStack {
                        Text("To:")
                            .font(.subheadline)
                            .foregroundColor(OKColor.textMuted)
                            .frame(width: 60, alignment: .leading)
                        Text(draft.content.recipient ?? "[Add recipient]")
                            .font(.subheadline)
                        Spacer()
                    }
                    HStack {
                        Text("Subject:")
                            .font(.subheadline)
                            .foregroundColor(OKColor.textMuted)
                            .frame(width: 60, alignment: .leading)
                        Text(draft.content.subject ?? "[Add subject]")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                
                Divider()
            }
            
            // Content
            if isEditing {
                TextEditor(text: $editedBody)
                    .font(.body)
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
                    .background(OKColor.textMuted.opacity(0.05))
                    .cornerRadius(8)
            } else {
                Text(draft.content.body)
                    .font(.body)
                    .foregroundColor(OKColor.textPrimary)
            }
        }
        .padding(20)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(16)
        .shadow(color: OKColor.shadow.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Action Items Card
    private func actionItemsCard(_ draft: Draft) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checklist")
                    .font(.system(size: 18))
                    .foregroundColor(OKColor.riskNominal)
                
                Text("Action Items")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(draft.actionItems.count) items")
                    .font(.caption)
                    .foregroundColor(OKColor.textMuted)
            }
            
            Divider()
            
            if draft.actionItems.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(OKColor.textMuted)
                    Text("No action items extracted")
                        .font(.body)
                        .foregroundColor(OKColor.textMuted)
                }
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(draft.actionItems, id: \.self) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "circle")
                                .font(.system(size: 18))
                                .foregroundColor(OKColor.textMuted)
                            
                            Text(item)
                                .font(.body)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(16)
        .shadow(color: OKColor.shadow.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Citations Card
    private func citationsCard(_ draft: Draft) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "link")
                    .font(.system(size: 18))
                    .foregroundColor(OKColor.riskExtreme)
                
                Text("Sources Used")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !draft.citations.isEmpty {
                    Text(draft.citations.summary)
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                }
            }
            
            Divider()
            
            if draft.citations.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(OKColor.textMuted)
                    Text("No sources cited")
                        .font(.body)
                        .foregroundColor(OKColor.textMuted)
                    Text("Add context to improve draft quality")
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(draft.citations) { citation in
                        citationRow(citation)
                    }
                }
            }
        }
        .padding(20)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(16)
        .shadow(color: OKColor.shadow.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    private func citationRow(_ citation: Citation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: citation.sourceType.icon)
                .font(.system(size: 18))
                .foregroundColor(citationColor(citation.sourceType))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(citation.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(citation.truncatedSnippet)
                    .font(.caption)
                    .foregroundColor(OKColor.textMuted)
                    .lineLimit(2)
                
                Text(citation.formattedTimestamp)
                    .font(.caption2)
                    .foregroundColor(OKColor.textMuted.opacity(0.8))
            }
            
            Spacer()
        }
        .padding(12)
        .background(OKColor.textMuted.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func citationColor(_ type: Citation.SourceType) -> Color {
        switch type {
        case .calendarEvent: return OKColor.riskCritical
        case .emailThread: return OKColor.actionPrimary
        case .file: return OKColor.riskWarning
        case .note: return OKColor.riskWarning
        }
    }
    
    // MARK: - Bottom Actions
    private var bottomActions: some View {
        VStack(spacing: 12) {
            // Fallback warning if needed
            if let draft = appState.currentDraft {
                if draft.requiresFallbackConfirmation {
                    fallbackWarning(draft)
                } else if draft.isBlocked {
                    blockedWarning(draft)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    nav.goBack()
                }) {
                    Text("Back")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(OKColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(OKColor.backgroundPrimary)
                        .cornerRadius(12)
                        .shadow(color: OKColor.shadow.opacity(0.04), radius: 4, x: 0, y: 2)
                }
                
                Button(action: {
                    proceedToApproval()
                }) {
                    Text(proceedButtonText)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(OKColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(proceedButtonEnabled ? OKColor.actionPrimary : OKColor.textMuted.opacity(0.4))
                        .cornerRadius(12)
                }
                .disabled(!proceedButtonEnabled)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            OKColor.textPrimary
                .shadow(color: OKColor.shadow.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
    
    private func fallbackWarning(_ draft: Draft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(OKColor.riskWarning)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Needs review")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("The request is clear, but some details may require your judgment.")
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                }
                
                Spacer()
            }
            
            // Helper text for Proceed Anyway
            Text("You are choosing to continue with a draft that may need adjustment.")
                .font(.caption2)
                .foregroundColor(OKColor.textSecondary)
                .padding(.leading, 36)
        }
        .padding(12)
        .background(OKColor.riskWarning.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func blockedWarning(_ draft: Draft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(OKColor.riskWarning)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Insufficient confidence")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(OKColor.textPrimary)
                    
                    Text("OperatorKit could not generate a reliable draft from the provided context.")
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                }
                
                Spacer()
            }
            
            // Recovery options
            HStack(spacing: 12) {
                Button(action: { nav.navigate(to: .intent) }) {
                    Text("Edit request")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(OKColor.actionPrimary)
                }
                
                Text("or")
                    .font(.caption)
                    .foregroundColor(OKColor.textMuted)
                
                Button(action: { nav.navigate(to: .context) }) {
                    Text("Add more context")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(OKColor.actionPrimary)
                }
                
                Spacer()
            }
            .padding(.leading, 36)
        }
        .padding(12)
        .background(OKColor.riskWarning.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var proceedButtonText: String {
        guard let draft = appState.currentDraft else { return "Continue" }
        
        if draft.isBlocked {
            return "Cancel"
        } else if draft.requiresFallbackConfirmation {
            return "Proceed anyway"
        } else {
            return "Continue to Approval"
        }
    }
    
    private var proceedButtonEnabled: Bool {
        guard let draft = appState.currentDraft else { return false }
        return !draft.isBlocked
    }
    
    private func proceedToApproval() {
        guard let draft = appState.currentDraft else { return }
        
        // Check if routing to fallback
        if draft.requiresFallbackConfirmation {
            // Route to fallback for confirmation
            nav.navigate(to: .fallback)
        } else {
            // Direct to approval
            nav.navigate(to: .approval)
        }
    }
}

#Preview {
    DraftOutputView()
        .environmentObject(AppState())
}
