import SwiftUI
import MessageUI
#if canImport(UIKit)
import UIKit
#endif

struct ExecutionProgressView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState
    @StateObject private var executionEngine = ExecutionEngine.shared
    @State private var showingResult: Bool = false
    @State private var showingMailComposer: Bool = false
    @State private var mailResult: MailComposeResult?
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Flow Step Header (Phase 5C)
                FlowStepHeaderView(
                    step: appState.executionResult != nil ? .complete : .approval,
                    subtitle: appState.executionResult != nil ? "Execution complete" : "Executing your request"
                )
                
                if let result = appState.executionResult {
                    // Show completion
                    completionView(result)
                } else {
                    // Show progress
                    progressView
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if appState.executionResult != nil {
                showingResult = true

                // EXECUTION FIX: Auto-present mail composer if ready
                // INVARIANT: Composer only pre-fills - user must manually tap Send
                // This provides a seamless UX: approval → composer appears automatically
                if executionEngine.canPresentMailComposer && !showingMailComposer {
                    // Short delay to let view settle before presenting sheet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingMailComposer = true
                    }
                }
            }
        }
        .mailComposerSheet(
            isPresented: $showingMailComposer,
            draft: executionEngine.pendingMailComposer
        ) { result in
            mailResult = result
            // Update the execution result message
            if result.isSuccess {
                log("Email action completed: \(result.displayMessage)")
            }
        }
    }
    
    // MARK: - Progress View
    private var progressView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Loading Indicator
            ProgressView()
                .scaleEffect(2)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            
            Text(progressTitle)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(progressSubtitle)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    /// Progress title based on flow status (Phase 5B)
    private var progressTitle: String {
        if let step = appState.flowStatus.workStep {
            switch step {
            case .executing: return "Executing..."
            case .savingToMemory: return "Saving..."
            default: return "Working..."
            }
        }
        return "Working..."
    }
    
    /// Progress subtitle based on flow status (Phase 5B)
    private var progressSubtitle: String {
        if let step = appState.flowStatus.workStep {
            return step.displayText
        }
        return "Completing your approved actions"
    }
    
    // MARK: - Completion View
    private func completionView(_ result: ExecutionResultModel) -> some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            ScrollView {
                VStack(spacing: 24) {
                    // Success Icon
                    successIcon(result)
                    
                    // Message
                    VStack(spacing: 8) {
                        Text(result.isSuccess ? "Complete" : "Could Not Complete")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(mailResult?.displayMessage ?? result.message)
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Email Composer Button (if pending)
                    if executionEngine.canPresentMailComposer {
                        emailComposerButton
                    }
                    
                    // Mail result (if sent)
                    if let mailResult = mailResult {
                        mailResultCard(mailResult)
                    }
                    
                    // Result Card
                    resultCard(result)
                    
                    // Executed Actions
                    executedActionsSection(result)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 120)
            }
            
            Spacer()
            
            // Bottom Actions
            bottomActions
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { nav.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }

            Spacer()

            OperatorKitLogoView(size: .small, showText: false)

            Spacer()

            Button(action: { nav.goHome() }) {
                Image(systemName: "house")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    // MARK: - Success Icon
    private func successIcon(_ result: ExecutionResultModel) -> some View {
        ZStack {
            Circle()
                .fill(result.isSuccess ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                .frame(width: 100, height: 100)
            
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(result.isSuccess ? .green : .red)
        }
    }
    
    // MARK: - Email Composer Button
    private var emailComposerButton: some View {
        VStack(spacing: 12) {
            Text("Your email is ready to send")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Button(action: {
                showingMailComposer = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open Email Composer")
                            .font(.body)
                            .fontWeight(.semibold)
                        
                        Text("You control when to send")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14))
                }
                .foregroundColor(.white)
                .padding(16)
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            Text("OperatorKit will never send emails automatically.\nYou must tap Send in the composer.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Mail Result Card
    private func mailResultCard(_ result: MailComposeResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(result.isSuccess ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayMessage)
                    .font(.body)
                    .fontWeight(.medium)
                
                switch result {
                case .sentByUser:
                    Text("Email was sent by you")
                        .font(.caption)
                        .foregroundColor(.gray)
                case .savedToDrafts:
                    Text("Email saved to your Drafts folder")
                        .font(.caption)
                        .foregroundColor(.gray)
                case .cancelled:
                    Text("You can still send later from OperatorKit")
                        .font(.caption)
                        .foregroundColor(.gray)
                case .failed:
                    Text("Please try again")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Result Card
    private func resultCard(_ result: ExecutionResultModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Status Badge
                Text(statusText(for: result.status))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor(for: result.status))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor(for: result.status).opacity(0.15))
                    .cornerRadius(12)
            }
            
            Divider()
            
            // Draft Type
            HStack {
                Text("Type:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(result.draft.type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            // Title
            HStack {
                Text("Title:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(result.draft.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            // Timestamp
            HStack {
                Text("Completed:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(formatDate(result.timestamp))
                    .font(.subheadline)
                Spacer()
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Executed Actions Section
    private func executedActionsSection(_ result: ExecutionResultModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What Happened")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 0) {
                ForEach(Array(result.executedSideEffects.enumerated()), id: \.element.id) { index, executed in
                    HStack(spacing: 12) {
                        Image(systemName: executed.wasExecuted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(executed.wasExecuted ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(executed.sideEffect.description)
                                .font(.body)
                            
                            if let message = executed.resultMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            // Show user action required indicator
                            if executed.sideEffect.type.requiresUserAction {
                                HStack(spacing: 4) {
                                    Image(systemName: "hand.tap.fill")
                                        .font(.system(size: 10))
                                    Text("Your action needed to complete")
                                        .font(.caption2)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    
                    if index < result.executedSideEffects.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
    
    // MARK: - Bottom Actions
    private var bottomActions: some View {
        VStack(spacing: 12) {
            Button(action: {
                // Navigate to memory but don't keep execution state active (Phase 5B)
                viewMemory()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                    Text("View in Memory")
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            
            Button(action: {
                // Reset and go home (Phase 5B)
                goHome()
            }) {
                Text("Back to Home")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            Color(UIColor.systemGroupedBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
    
    // MARK: - Navigation Actions (Phase 5B)
    
    /// View memory and clear execution state
    private func viewMemory() {
        // Clear execution state but keep the result for memory view
        appState.setCompleted()
        nav.navigate(to: .memory)
    }

    /// Go home and reset flow completely
    private func goHome() {
        nav.goHome()
    }
    
    // MARK: - Helpers
    private func statusText(for status: ExecutionResultModel.ExecutionStatus) -> String {
        switch status {
        case .success: return "Success"
        case .partialSuccess: return "Partial"
        case .failed: return "Failed"
        case .savedDraftOnly: return "Draft Saved"
        }
    }
    
    private func statusColor(for status: ExecutionResultModel.ExecutionStatus) -> Color {
        switch status {
        case .success, .savedDraftOnly: return .green
        case .partialSuccess: return .orange
        case .failed: return .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ExecutionProgressView()
        .environmentObject(AppState())
}
