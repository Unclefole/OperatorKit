import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FallbackView: View {
    @EnvironmentObject var appState: AppState
    
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
            Color(UIColor.systemGroupedBackground)
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
            Button(action: {
                appState.navigateBack()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text(isBlocked ? "More Information Needed" : "Review Recommended")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: {
                appState.returnHome()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Warning Card
    private var warningCard: some View {
        VStack(spacing: 16) {
            // Warning Icon
            ZStack {
                Circle()
                    .fill((isBlocked ? Color.red : Color.orange).opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: isBlocked ? "xmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(isBlocked ? .red : .orange)
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
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Intent Card
    private func intentCard(_ intent: IntentRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Request")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("\"\(intent.rawText)\"")
                .font(.body)
                .foregroundColor(.primary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.05))
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
                            .foregroundColor(.gray)
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
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            // Threshold markers
                            HStack(spacing: 0) {
                                Color.clear
                                    .frame(width: geometry.size.width * 0.35)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(width: 2, height: 12)
                                Spacer()
                            }
                            
                            HStack(spacing: 0) {
                                Color.clear
                                    .frame(width: geometry.size.width * 0.65)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.4))
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
                            .foregroundColor(.gray)
                        Spacer()
                        Text("Needs review")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("High")
                            .font(.caption2)
                            .foregroundColor(.gray)
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
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
    
    private var confidenceColor: Color {
        if currentConfidence >= 0.65 {
            return .green
        } else if currentConfidence >= 0.35 {
            return .orange
        } else {
            return .red
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
                            .foregroundColor(.gray)
                        
                        Text(citation.label)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                    iconColor: .blue,
                    title: "Add more context",
                    description: "Select meetings, emails, or files to improve the draft",
                    isPrimary: true,
                    action: {
                        appState.navigateTo(.contextPicker)
                    }
                )
                
                // Rewrite Intent Option
                FallbackOptionButton(
                    icon: "pencil.line",
                    iconColor: .purple,
                    title: "Clarify your request",
                    description: "Reword what you're trying to accomplish",
                    isPrimary: false,
                    action: {
                        // Go back to intent input
                        appState.navigateTo(.intentInput)
                    }
                )
                
                // Proceed Anyway (only if not blocked)
                if canProceedAnyway {
                    FallbackOptionButton(
                        icon: "arrow.right.circle",
                        iconColor: .orange,
                        title: "Continue with this draft",
                        description: "Review and edit before any action is taken",
                        isPrimary: false,
                        action: {
                            // Proceed to approval
                            appState.navigateTo(.approval)
                        }
                    )
                }
                
                // Cancel Option
                FallbackOptionButton(
                    icon: "xmark.circle",
                    iconColor: .gray,
                    title: "Start over",
                    description: "Return home and begin a new request",
                    isPrimary: false,
                    action: {
                        appState.returnHome()
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
            case .high: return .red
            case .medium: return .orange
            case .low: return .yellow
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
                .foregroundColor(.gray)
            
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
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .padding(16)
            .background(isPrimary ? Color.blue.opacity(0.05) : Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            .overlay(
                isPrimary ?
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                : nil
            )
        }
    }
}

#Preview {
    FallbackView()
        .environmentObject(AppState())
}
