import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WorkflowTemplatesView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""
    
    private var filteredTemplates: [WorkflowTemplate] {
        if searchText.isEmpty {
            return WorkflowTemplate.allTemplates
        }
        return WorkflowTemplate.allTemplates.filter {
            $0.name.lowercased().contains(searchText.lowercased()) ||
            $0.description.lowercased().contains(searchText.lowercased())
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Search Bar
                searchBar
                
                // Templates List
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(filteredTemplates) { template in
                            WorkflowTemplateCard(template: template) {
                                appState.selectedWorkflowTemplate = template
                                appState.navigateTo(.workflowDetail)
                            }
                        }
                        
                        // Manage Templates Button
                        manageTemplatesButton
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
            
            Text("Workflows")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            TextField("Search workflows...", text: $searchText)
                .font(.body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    // MARK: - Manage Templates Button
    private var manageTemplatesButton: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                
                Text("Manage Templates")
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - Workflow Template Card
struct WorkflowTemplateCard: View {
    let template: WorkflowTemplate
    let onTap: () -> Void
    
    private var iconBackgroundColor: Color {
        switch template.iconColor {
        case .blue: return .blue
        case .pink: return .pink
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBackgroundColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: template.icon)
                        .font(.system(size: 20))
                        .foregroundColor(iconBackgroundColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(template.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - Workflow Detail View
struct WorkflowDetailView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingEditSheet: Bool = false
    @State private var editingStep: WorkflowStep?
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        if let template = appState.selectedWorkflowTemplate {
                            // Instructions Section
                            instructionsSection(template)
                            
                            // Steps Section
                            stepsSection(template)
                            
                            // Settings Section
                            settingsSection(template)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
                
                Spacer()
            }
            
            // Bottom Button
            VStack {
                Spacer()
                runWorkflowButton
            }
            
            // Edit Step Sheet
            if showingEditSheet, let step = editingStep {
                EditStepSheet(
                    step: step,
                    isPresented: $showingEditSheet,
                    onSave: { _ in
                        showingEditSheet = false
                    }
                )
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
            
            Text(appState.selectedWorkflowTemplate?.name ?? "Workflow")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Instructions Section
    private func instructionsSection(_ template: WorkflowTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Instructions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {}) {
                    Text("Edit")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            Text(template.description)
                .font(.body)
                .foregroundColor(.gray)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
    
    // MARK: - Steps Section
    private func stepsSection(_ template: WorkflowTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Steps")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("Add Step")
                            .font(.subheadline)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            VStack(spacing: 0) {
                ForEach(Array(template.steps.enumerated()), id: \.element.id) { index, step in
                    WorkflowStepRow(step: step) {
                        editingStep = step
                        showingEditSheet = true
                    }
                    
                    if index < template.steps.count - 1 {
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
    
    // MARK: - Settings Section
    private func settingsSection(_ template: WorkflowTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 0) {
                // Confidence Required
                HStack {
                    Text("Confidence Required")
                        .font(.body)
                    
                    Spacer()
                    
                    Text(template.settings.confidenceRequired.rawValue)
                        .font(.body)
                        .foregroundColor(.gray)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.4))
                }
                .padding(16)
                
                Divider()
                    .padding(.leading, 16)
                
                // Verify Before Execution
                HStack {
                    Text("Verify before execution")
                        .font(.body)
                    
                    Spacer()
                    
                    Toggle("", isOn: .constant(template.settings.verifyBeforeExecution))
                        .labelsHidden()
                }
                .padding(16)
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
    
    // MARK: - Run Workflow Button
    private var runWorkflowButton: some View {
        Button(action: {
            // Start workflow
            if let template = appState.selectedWorkflowTemplate {
                let intent = IntentRequest(
                    rawText: "Run \(template.name) workflow",
                    intentType: .draftEmail
                )
                appState.selectedIntent = intent
                appState.navigateTo(.contextPicker)
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                Text("Run Workflow")
            }
            .font(.body)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.blue)
            .cornerRadius(14)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            Color(UIColor.systemGroupedBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
}

// MARK: - Workflow Step Row
struct WorkflowStepRow: View {
    let step: WorkflowStep
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 16) {
                // Step Number
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 28, height: 28)
                    
                    Text("\(step.stepNumber)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(step.instructions)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    if let attachment = step.attachmentName {
                        HStack(spacing: 4) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 10))
                            Text(attachment)
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .padding(16)
        }
    }
}

// MARK: - Edit Step Sheet
struct EditStepSheet: View {
    let step: WorkflowStep
    @Binding var isPresented: Bool
    let onSave: (WorkflowStep) -> Void
    
    @State private var editedName: String = ""
    @State private var editedInstructions: String = ""
    @State private var includeTimelineChanges: Bool = true
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Sheet
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
                    // Handle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)
                    
                    // Header
                    HStack {
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Cancel")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Text("Edit Step")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            // Save and close
                            var updated = step
                            updated.title = editedName
                            updated.instructions = editedInstructions
                            onSave(updated)
                        }) {
                            Text("Save")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Divider()
                    
                    // Form
                    VStack(spacing: 16) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Step Name")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            TextField("Step name", text: $editedName)
                                .font(.body)
                                .padding(12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Instructions")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            TextEditor(text: $editedInstructions)
                                .font(.body)
                                .frame(height: 100)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // Options
                        HStack {
                            Text("Include timeline changes")
                                .font(.body)
                            
                            Spacer()
                            
                            Toggle("", isOn: $includeTimelineChanges)
                                .labelsHidden()
                        }
                        .padding(12)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .background(Color.white)
                .cornerRadius(20, corners: [.topLeft, .topRight])
            }
        }
        .onAppear {
            editedName = step.title
            editedInstructions = step.instructions
        }
    }
}

// MARK: - Corner Radius Extension
#if canImport(UIKit)
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#endif

#Preview {
    WorkflowTemplatesView()
        .environmentObject(AppState())
}
