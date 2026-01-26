import SwiftUI

/// Consistent header component for all flow screens (Phase 5C)
/// Displays current step, progress, and optional subtitle
struct FlowStepHeaderView: View {
    let step: FlowStep
    let subtitle: String?
    
    init(step: FlowStep, subtitle: String? = nil) {
        self.step = step
        self.subtitle = subtitle
    }
    
    /// All flow steps in order
    enum FlowStep: Int, CaseIterable {
        case request = 1
        case context = 2
        case plan = 3
        case draft = 4
        case approval = 5
        case complete = 6
        
        var title: String {
            switch self {
            case .request: return "Request"
            case .context: return "Context"
            case .plan: return "Plan"
            case .draft: return "Draft"
            case .approval: return "Approval"
            case .complete: return "Complete"
            }
        }
        
        var icon: String {
            switch self {
            case .request: return "text.bubble"
            case .context: return "doc.text.magnifyingglass"
            case .plan: return "list.bullet.clipboard"
            case .draft: return "doc.text"
            case .approval: return "checkmark.shield"
            case .complete: return "checkmark.circle"
            }
        }
        
        static var totalSteps: Int { 6 }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress indicator
            progressIndicator
            
            // Step title
            HStack(spacing: 8) {
                Image(systemName: step.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text(step.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Step counter
                Text("Step \(step.rawValue) of \(FlowStep.totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(step.title), step \(step.rawValue) of \(FlowStep.totalSteps)")
            
            // Optional subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 3)
                    .cornerRadius(1.5)
                
                // Progress fill
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: progressWidth(in: geometry.size.width), height: 3)
                    .cornerRadius(1.5)
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let progress = CGFloat(step.rawValue) / CGFloat(FlowStep.totalSteps)
        return totalWidth * progress
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        FlowStepHeaderView(step: .request, subtitle: "Tell OperatorKit what you need")
        FlowStepHeaderView(step: .context, subtitle: "Select the information to include")
        FlowStepHeaderView(step: .plan)
        FlowStepHeaderView(step: .draft)
        FlowStepHeaderView(step: .approval)
        FlowStepHeaderView(step: .complete)
    }
    .background(Color.gray.opacity(0.1))
}
