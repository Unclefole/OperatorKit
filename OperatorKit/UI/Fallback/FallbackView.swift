import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FallbackView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState

    /// Current draft confidence (from appState)
    private var currentConfidence: Double {
        appState.currentDraft?.confidence ?? 0.0
    }
    
    /// Whether this is a blocked state (confidence < 0.35)
    private var isBlocked: Bool {
        currentConfidence < DraftOutput.minimumExecutionConfidence
    }
    
    /// Whether user can proceed anyway (confidence >= 0.35 but < 0.65)
    private var canProceedAnyway: Bool {
        currentConfidence >= DraftOutput.minimumExecutionConfidence
    }
    
    var body: some View {
        ZStack {
            // Background
            OKColor.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Warning Header
                        warningCard
                        
                        // Intent Display
                        if let intent = appState.selectedIntent {
                            intentCard(intent)
                        }
                        
                        // Confidence Section
                        confidenceSection
                        
                        // Citations (if available)
                        if let draft = appState.currentDraft, !draft.citations.isEmpty {
                            citationsSection(draft)
                        }
                        
                        // Options Section
                        optionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
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
    
    // MARK: - Warning Card
    private var warningCard: some View {
        VStack(spacing: 16) {
            // Warning Icon
            ZStack {
                Circle()
                    .fill((isBlocked ? OKColor.riskCritical : OKColor.riskWarning).opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: isBlocked ? "xmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(isBlocked ? OKColor.riskCritical : OKColor.riskWarning)
            }
            
            // Message
            VStack(spacing: 8) {
                Text(isBlocked ? "Insufficient confidence" : "Needs review")
                    .font(.title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(isBlocked
                    ? "OperatorKit could not generate a reliable draft from the provided context."
                    : "The request is clear, but some details may require your judgment."
                )
                    .font(.body)
                    .foregroundColor(OKColor.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(16)
        .shadow(color: OKColor.shadow.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Intent Card
    private func intentCard(_ intent: IntentRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Request")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("\"\(intent.rawText)\"")
                .font(.body)
                .foregroundColor(OKColor.textPrimary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(OKColor.textMuted.opacity(0.05))
                .cornerRadius(12)
        }
    }
    
    // MARK: - Confidence Section
    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why This Happened")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Confidence Bar
                VStack(spacing: 8) {
                    HStack {
                        Text("Confidence Level")
                            .font(.subheadline)
                            .foregroundColor(OKColor.textMuted)
                        Spacer()
                        Text("\(Int(currentConfidence * 100))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(confidenceColor)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(OKColor.textMuted.opacity(0.2))
                                .frame(height: 8)
                            
                            // Threshold markers
                            HStack(spacing: 0) {
                                Color.clear
                                    .frame(width: geometry.size.width * 0.35)
                                Rectangle()
                                    .fill(OKColor.textMuted.opacity(0.4))
                                    .frame(width: 2, height: 12)
                                Spacer()
                            }
                            
                            HStack(spacing: 0) {
                                Color.clear
                                    .frame(width: geometry.size.width * 0.65)
                                Rectangle()
                                    .fill(OKColor.textMuted.opacity(0.4))
                                    .frame(width: 2, height: 12)
                                Spacer()
                            }
                            
                            // Confidence level
                            RoundedRectangle(cornerRadius: 4)
                                .fill(confidenceColor)
                                .frame(width: geometry.size.width * currentConfidence, height: 8)
                        }
                    }
                    .frame(height: 12)
                    
                    // Threshold labels
                    HStack {
                        Text("Insufficient")
                            .font(.caption2)
                            .foregroundColor(OKColor.textMuted)
                        Spacer()
                        Text("Needs review")
                            .font(.caption2)
                            .foregroundColor(OKColor.textMuted)
                        Spacer()
                        Text("High")
                            .font(.caption2)
                            .foregroundColor(OKColor.textMuted)
                    }
                }
                
                Divider()
                
                // Issues List
                VStack(alignment: .leading, spacing: 8) {
                    Text("What's missing:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // Dynamic issues based on context
                    if appState.selectedContext?.isEmpty ?? true {
                        IssueRow(text: "No context selected — select meetings, emails, or files", severity: .high)
                    }
                    
                    if appState.selectedContext?.calendarItems.isEmpty ?? true {
                        IssueRow(text: "No meeting selected — helps identify attendees and topics", severity: .medium)
                    }
                    
                    if currentConfidence < 0.5 {
                        IssueRow(text: "Request is broad — try being more specific", severity: .medium)
                    }
                    
                    if let draft = appState.currentDraft, draft.type == .email && draft.content.recipient == nil {
                        IssueRow(text: "No recipient identified — add context with attendee info", severity: .high)
                    }
                }
            }
            .padding(16)
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
    
    private var confidenceColor: Color {
        if currentConfidence >= 0.65 {
            return OKColor.riskNominal
        } else if currentConfidence >= 0.35 {
            return OKColor.riskWarning
        } else {
            return OKColor.riskCritical
        }
    }
    
    // MARK: - Citations Section
    private func citationsSection(_ draft: Draft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Context")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(draft.citations) { citation in
                    HStack(spacing: 12) {
                        Image(systemName: citation.sourceType.icon)
                            .font(.system(size: 16))
                            .foregroundColor(OKColor.textMuted)
                        
                        Text(citation.label)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(OKColor.riskNominal)
                    }
                    .padding(12)
                    .background(OKColor.textMuted.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            .padding(16)
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
    
    // MARK: - Options Section
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Options")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Add Context Option (Primary)
                FallbackOptionButton(
                    icon: "folder.badge.plus",
                    iconColor: OKColor.actionPrimary,
                    title: "Add more context",
                    description: "Select meetings, emails, or files to improve the draft",
                    isPrimary: true,
                    action: {
                        nav.navigate(to: .context)
                    }
                )

                // Rewrite Intent Option
                FallbackOptionButton(
                    icon: "pencil.line",
                    iconColor: OKColor.riskExtreme,
                    title: "Clarify your request",
                    description: "Reword what you're trying to accomplish",
                    isPrimary: false,
                    action: {
                        // Go back to intent input
                        nav.navigate(to: .intent)
                    }
                )

                // Proceed Anyway (only if not blocked)
                if canProceedAnyway {
                    FallbackOptionButton(
                        icon: "arrow.right.circle",
                        iconColor: OKColor.riskWarning,
                        title: "Continue with this draft",
                        description: "Review and edit before any action is taken",
                        isPrimary: false,
                        action: {
                            // Proceed to approval
                            nav.navigate(to: .approval)
                        }
                    )
                }

                // Cancel Option
                FallbackOptionButton(
                    icon: "xmark.circle",
                    iconColor: OKColor.textMuted,
                    title: "Start over",
                    description: "Return home and begin a new request",
                    isPrimary: false,
                    action: {
                        nav.goHome()
                    }
                )
            }
        }
    }
}

// MARK: - Issue Row
struct IssueRow: View {
    let text: String
    let severity: IssueSeverity
    
    enum IssueSeverity {
        case high, medium, low
        
        var color: Color {
            switch self {
            case .high: return OKColor.riskCritical
            case .medium: return OKColor.riskWarning
            case .low: return OKColor.riskWarning
            }
        }
        
        var icon: String {
            switch self {
            case .high: return "exclamationmark.circle.fill"
            case .medium: return "exclamationmark.triangle.fill"
            case .low: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: severity.icon)
                .font(.system(size: 14))
                .foregroundColor(severity.color)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(OKColor.textMuted)
            
            Spacer()
        }
    }
}

// MARK: - Fallback Option Button
struct FallbackOptionButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isPrimary: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(isPrimary ? .semibold : .medium)
                        .foregroundColor(OKColor.textPrimary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OKColor.textMuted.opacity(0.4))
            }
            .padding(16)
            .background(isPrimary ? OKColor.actionPrimary.opacity(0.05) : OKColor.textPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
            .overlay(
                isPrimary ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(OKColor.actionPrimary.opacity(0.2), lineWidth: 1)
                : nil
            )
        }
    }
}

#Preview {
    FallbackView()
        .environmentObject(AppState())
        .environmentObject(AppNavigationState())
}
