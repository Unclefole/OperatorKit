import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PlanPreviewView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState
    @State private var isGenerating: Bool = false  // Phase 5B: Loading state
    @State private var generationTask: Task<Void, Never>? = nil  // Phase 5B: Cancellable task
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Flow Step Header (Phase 5C)
                FlowStepHeaderView(
                    step: .plan,
                    subtitle: "Review the execution plan"
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
                        
                        // Plan Steps Card
                        if let plan = appState.executionPlan {
                            planStepsCard(plan)
                            
                            // Permissions Required
                            if plan.requiresAdditionalPermissions {
                                permissionsCard(plan)
                            }
                            
                            // Context Summary (original)
                            contextChips(plan.context)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
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
    }
    
    // MARK: - Recovery Action Handler (Phase 5C)
    private func handleRecoveryAction(_ action: OperatorKitUserFacingError.RecoveryAction) {
        switch action {
        case .goHome:
            nav.goHome()
        case .retryCurrentStep:
            appState.clearError()
            // Re-generate
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
    
    // MARK: - Plan Steps Card
    private func planStepsCard(_ plan: ExecutionPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Execution Plan")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Confidence Badge
                Text("\(Int(plan.overallConfidence * 100))% confident")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(plan.isHighConfidence ? .green : .orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        (plan.isHighConfidence ? Color.green : Color.orange)
                            .opacity(0.15)
                    )
                    .cornerRadius(12)
            }
            
            VStack(spacing: 0) {
                ForEach(Array(plan.steps.enumerated()), id: \.element.id) { index, step in
                    PlanStepRow(step: step, isLast: index == plan.steps.count - 1)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Permissions Card
    private func permissionsCard(_ plan: ExecutionPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                
                Text("Permissions Required")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 8) {
                ForEach(plan.requiredPermissions, id: \.self) { permission in
                    HStack(spacing: 12) {
                        Image(systemName: permissionIcon(for: permission))
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        
                        Text(permission.rawValue)
                            .font(.body)
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
    }
    
    // MARK: - Context Chips
    private func contextChips(_ context: ContextPacket) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Using Context")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            FlowLayout(spacing: 8) {
                ForEach(context.calendarItems) { item in
                    ContextDisplayChip(title: item.title, icon: "calendar")
                }
                ForEach(context.emailItems) { item in
                    ContextDisplayChip(title: item.subject, icon: "envelope.fill")
                }
                ForEach(context.fileItems) { item in
                    ContextDisplayChip(title: item.name, icon: "doc.fill")
                }
            }
        }
    }
    
    // MARK: - Bottom Actions
    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button(action: {
                nav.goBack()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                    Text("Edit")
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
            
            if isGenerating {
                // Cancel button (Phase 5B)
                Button(action: {
                    cancelGeneration()
                }) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Generating... Tap to Cancel")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .cornerRadius(12)
                }
            } else {
                Button(action: {
                    generateDraft()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text("Generate Draft")
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            Color(UIColor.systemGroupedBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
    
    // MARK: - Cancel Generation (Phase 5B)
    private func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        appState.setIdle()
        // Don't navigate away - stay on plan preview
    }
    
    // MARK: - Helpers
    private func permissionIcon(for permission: PlanStep.PermissionType) -> String {
        switch permission {
        case .calendar: return "calendar"
        case .email: return "envelope.fill"
        case .files: return "doc.fill"
        case .reminders: return "bell.fill"
        case .contacts: return "person.fill"
        }
    }
    
    private func generateDraft() {
        // Prevent double-tap (Phase 5B)
        guard !isGenerating else { return }
        guard let plan = appState.executionPlan else { return }
        
        isGenerating = true
        appState.setWorking(.generatingDraft)
        
        // Use async generation with ModelRouter
        generationTask = Task {
            do {
                // Check for cancellation
                try Task.checkCancellation()
                
                let draft = try await DraftGenerator.shared.generate(from: plan)
                
                // Check for cancellation again
                try Task.checkCancellation()
                
                await MainActor.run {
                    isGenerating = false
                    appState.setIdle()
                    appState.currentDraft = draft
                    
                    // Route based on confidence
                    if draft.isBlocked {
                        // Confidence < 0.35: Block and require revision
                        nav.navigate(to: .fallback)
                    } else if draft.requiresFallbackConfirmation {
                        // Confidence < 0.65: Show draft but require confirmation
                        nav.navigate(to: .draft)
                    } else {
                        // Confidence >= 0.65: Direct to draft output
                        nav.navigate(to: .draft)
                    }
                }
            } catch is CancellationError {
                // User cancelled - already handled in cancelGeneration()
                await MainActor.run {
                    isGenerating = false
                    appState.setIdle()
                }
            } catch {
                // On error, use legacy sync method and route to fallback
                logError("Draft generation failed: \(error)")
                
                await MainActor.run {
                    isGenerating = false
                    appState.setFailed(error: .operationFailed(context: "draft generation"))
                    
                    let legacyDraft = DraftGenerator.shared.createDraft(plan: plan)
                    appState.currentDraft = legacyDraft
                    
                    if legacyDraft.isBlocked {
                        nav.navigate(to: .fallback)
                    } else {
                        nav.navigate(to: .draft)
                    }
                }
            }
        }
    }
}

// MARK: - Plan Step Row
struct PlanStepRow: View {
    let step: PlanStep
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step Number
            VStack {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 28, height: 28)
                    
                    Text("\(step.stepNumber)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(minHeight: 40)
                }
            }
            
            // Step Content
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.body)
                    .fontWeight(.semibold)
                
                Text(step.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 16)
            
            Spacer()
        }
    }
}

// MARK: - Context Display Chip
struct ContextDisplayChip: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            
            Text(title)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .foregroundColor(.primary)
        .cornerRadius(16)
    }
}

// MARK: - FlowLayout is now in Components/FlowLayout.swift

#Preview {
    PlanPreviewView()
        .environmentObject(AppState())
}
