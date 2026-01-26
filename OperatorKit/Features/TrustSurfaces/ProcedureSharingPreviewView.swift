import SwiftUI

// ============================================================================
// PROCEDURE SHARING PREVIEW VIEW (Phase 13A)
//
// Preview-only display of example procedures.
// Clearly labeled as synthetic, logic-only templates.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No actual sharing
// ❌ No export
// ❌ No import
// ❌ No write operations
// ✅ UI preview only
// ✅ Synthetic data only
// ✅ Feature-flagged
// ============================================================================

public struct ProcedureSharingPreviewView: View {
    
    // MARK: - Body
    
    public var body: some View {
        if TrustSurfacesFeatureFlag.Components.procedureSharingPreviewEnabled {
            previewContent
        } else {
            featureDisabledView
        }
    }
    
    // MARK: - Preview Content
    
    private var previewContent: some View {
        List {
            headerSection
            whatIsProcedureSection
            exampleProceduresSection
            whatIsNotSharedSection
            footerSection
        }
        .navigationTitle("Procedure Sharing")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    Text("Procedure Sharing Preview")
                        .font(.headline)
                }
                
                Label {
                    Text("This is a preview only. No sharing is enabled.")
                        .font(.caption)
                } icon: {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.orange)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - What Is A Procedure Section
    
    private var whatIsProcedureSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("A **Procedure** is a template or policy configuration that defines how OperatorKit processes certain request types.")
                    .font(.subheadline)
                
                Text("Procedures are **logic-only**. They contain rules, not content.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("What is a Procedure?")
        }
    }
    
    // MARK: - Example Procedures Section
    
    private var exampleProceduresSection: some View {
        Section {
            ForEach(SyntheticProcedureExamples.all, id: \.id) { example in
                ProcedureExampleRow(example: example)
            }
        } header: {
            Text("Example Procedures (Synthetic)")
        } footer: {
            Text("These are synthetic examples for illustration only. They do not represent actual user procedures.")
        }
    }
    
    // MARK: - What Is Not Shared Section
    
    private var whatIsNotSharedSection: some View {
        Section {
            NotSharedRow(item: "Drafted outcomes", icon: "doc.text")
            NotSharedRow(item: "Email content", icon: "envelope")
            NotSharedRow(item: "Calendar events", icon: "calendar")
            NotSharedRow(item: "Reminders", icon: "checklist")
            NotSharedRow(item: "User memory", icon: "brain")
            NotSharedRow(item: "Execution history", icon: "clock.arrow.circlepath")
        } header: {
            Text("What is NEVER Shared")
        } footer: {
            Text("Procedure sharing is metadata-only. User content is never shared.")
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Preview Only")
                        .font(.caption)
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
                
                Text("Procedure sharing is a Team tier feature. This preview shows the concept. Sharing, export, and import are not enabled.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Feature Disabled View
    
    private var featureDisabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("Procedure Sharing Preview")
                .font(.headline)
            
            Text("This feature is not enabled.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Init
    
    public init() {}
}

// MARK: - Procedure Example Row

private struct ProcedureExampleRow: View {
    let example: SyntheticProcedureExample
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: example.icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(example.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("[SYNTHETIC]")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Text(example.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Not Shared Row

private struct NotSharedRow: View {
    let item: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.red)
                .frame(width: 24)
            
            Text(item)
                .font(.subheadline)
            
            Spacer()
            
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        }
    }
}

// MARK: - Synthetic Procedure Examples

private struct SyntheticProcedureExample: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
}

private enum SyntheticProcedureExamples {
    static let all: [SyntheticProcedureExample] = [
        SyntheticProcedureExample(
            id: "SYNTHETIC_PROC_001",
            name: "TEST_Conservative_Limits",
            description: "Example procedure with conservative execution limits. [SYNTHETIC DATA]",
            icon: "slider.horizontal.3"
        ),
        SyntheticProcedureExample(
            id: "SYNTHETIC_PROC_002",
            name: "TEST_Standard_Policy",
            description: "Example standard policy template for teams. [SYNTHETIC DATA]",
            icon: "doc.badge.gearshape"
        ),
        SyntheticProcedureExample(
            id: "SYNTHETIC_PROC_003",
            name: "TEST_Approval_Required",
            description: "Example procedure requiring two-key approval. [SYNTHETIC DATA]",
            icon: "hand.raised"
        )
    ]
}

// MARK: - Preview

#if DEBUG
struct ProcedureSharingPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProcedureSharingPreviewView()
        }
    }
}
#endif
