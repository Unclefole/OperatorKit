import SwiftUI

// ============================================================================
// ACTIVATION PLAYBOOK VIEW (Phase 10N)
//
// Shows "First 3 Wins" steps with sample intents.
// User must still select context; nothing auto-runs.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No auto-execution
// ❌ No auto-context selection
// ❌ No forced interaction
// ✅ "Try this" prefills intent text
// ✅ User selects context
// ✅ Always skippable
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct ActivationPlaybookView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var activationStore = ActivationStateStore.shared
    
    /// Callback when user wants to try an intent
    var onTryIntent: ((String) -> Void)?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Progress
                    progressSection
                    
                    // Steps
                    stepsSection
                    
                    // Footer
                    footerSection
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Get Started")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        activationStore.markPlaybookShown()
                        dismiss()
                    }
                }
            }
            .onAppear {
                activationStore.markPlaybookShown()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Your First 3 Wins")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Try these quick tasks to see what you can do. Each one takes less than a minute.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(completedCount)/\(totalCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: activationStore.progress)
                .tint(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var completedCount: Int {
        ActivationPlaybook.steps.filter { activationStore.isStepCompleted($0.id) }.count
    }
    
    private var totalCount: Int {
        ActivationPlaybook.steps.count
    }
    
    // MARK: - Steps Section
    
    private var stepsSection: some View {
        VStack(spacing: 16) {
            ForEach(ActivationPlaybook.steps) { step in
                ActivationStepCard(
                    step: step,
                    isCompleted: activationStore.isStepCompleted(step.id),
                    onTry: {
                        onTryIntent?(step.sampleIntent)
                        activationStore.markStepCompleted(step.id)
                        dismiss()
                    }
                )
            }
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            if activationStore.isPlaybookCompleted {
                Label("All done! You're ready to go.", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            Button {
                dismiss()
            } label: {
                Text(activationStore.isPlaybookCompleted ? "Continue" : "Skip for Now")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Text("You can always try these later from Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 16)
    }
}

// MARK: - Activation Step Card

private struct ActivationStepCard: View {
    let step: ActivationStep
    let isCompleted: Bool
    let onTry: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Icon
                Image(systemName: step.icon)
                    .font(.title2)
                    .foregroundColor(isCompleted ? .green : .blue)
                    .frame(width: 44, height: 44)
                    .background(isCompleted ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Step \(step.stepNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Text(step.title)
                        .font(.headline)
                }
                
                Spacer()
            }
            
            Text(step.stepDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Sample Intent Preview
            VStack(alignment: .leading, spacing: 4) {
                Text("Sample:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\"\(step.sampleIntent)\"")
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.primary)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
            
            // Try Button
            Button {
                onTry()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text(isCompleted ? "Try Again" : "Try This")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isCompleted ? .gray : .blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCompleted ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Preview

#Preview {
    ActivationPlaybookView()
}
