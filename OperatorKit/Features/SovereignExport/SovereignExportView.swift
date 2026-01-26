import SwiftUI
import UniformTypeIdentifiers

// ============================================================================
// SOVEREIGN EXPORT VIEW (Phase 13C)
//
// Main UI for Sovereign Export/Import.
// User-initiated only, no background operations.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No automatic operations
// ❌ No networking
// ✅ User-initiated only
// ✅ Explicit confirmation required
// ✅ Feature-flagged
// ============================================================================

public struct SovereignExportView: View {
    
    // MARK: - State
    
    @State private var showingExportFlow = false
    @State private var showingImportFlow = false
    @State private var alertMessage: String? = nil
    @State private var showingAlert = false
    
    // MARK: - Body
    
    public var body: some View {
        if SovereignExportFeatureFlag.isEnabled {
            mainContent
        } else {
            featureDisabledView
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        List {
            headerSection
            whatIsExportedSection
            whatIsNotExportedSection
            exportSection
            importSection
            securitySection
        }
        .navigationTitle("Sovereign Export")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExportFlow) {
            SovereignExportFlowView()
        }
        .sheet(isPresented: $showingImportFlow) {
            SovereignImportFlowView()
        }
        .alert("Sovereign Export", isPresented: $showingAlert) {
            Button("OK") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lock.doc.fill")
                        .font(.title)
                        .foregroundColor(.purple)
                    
                    Text("Your Data, Your Control")
                        .font(.headline)
                }
                
                Text("Export your configuration as an encrypted, portable file that you own completely.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - What Is Exported Section
    
    private var whatIsExportedSection: some View {
        Section {
            ExportItemRow(item: "Procedure templates", icon: "doc.on.doc", included: true)
            ExportItemRow(item: "Policy configuration", icon: "gearshape", included: true)
            ExportItemRow(item: "Subscription tier", icon: "star", included: true)
            ExportItemRow(item: "Usage counts (aggregates)", icon: "number", included: true)
        } header: {
            Text("What Is Exported")
        } footer: {
            Text("Logic and metadata only. All content is encrypted.")
        }
    }
    
    // MARK: - What Is Not Exported Section
    
    private var whatIsNotExportedSection: some View {
        Section {
            ExportItemRow(item: "Drafted emails", icon: "envelope", included: false)
            ExportItemRow(item: "Calendar events", icon: "calendar", included: false)
            ExportItemRow(item: "Reminders", icon: "checklist", included: false)
            ExportItemRow(item: "Memory or context", icon: "brain", included: false)
            ExportItemRow(item: "Personal data", icon: "person", included: false)
        } header: {
            Text("What Is NEVER Exported")
        } footer: {
            Text("User content never leaves your device, even in encrypted exports.")
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section {
            Button(action: { showingExportFlow = true }) {
                Label("Export Configuration", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("Export")
        } footer: {
            Text("Creates an encrypted file you can save anywhere. Requires a passphrase.")
        }
    }
    
    // MARK: - Import Section
    
    private var importSection: some View {
        Section {
            Button(action: { showingImportFlow = true }) {
                Label("Import Configuration", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Import")
        } footer: {
            Text("Restore from a previously exported file. Requires the original passphrase.")
        }
    }
    
    // MARK: - Security Section
    
    private var securitySection: some View {
        Section {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                
                Text("Encryption")
                
                Spacer()
                
                Text("AES-256-GCM")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.orange)
                
                Text("Key Storage")
                
                Spacer()
                
                Text("None (ephemeral)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "network.slash")
                    .foregroundColor(.blue)
                
                Text("Network Access")
                
                Spacer()
                
                Text("None")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Security")
        } footer: {
            Text("Your passphrase is never stored. Files are encrypted locally before saving.")
        }
    }
    
    // MARK: - Feature Disabled View
    
    private var featureDisabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("Sovereign Export")
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

// MARK: - Export Item Row

private struct ExportItemRow: View {
    let item: String
    let icon: String
    let included: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(included ? .green : .red)
                .frame(width: 24)
            
            Text(item)
                .font(.subheadline)
            
            Spacer()
            
            Image(systemName: included ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(included ? .green : .red)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SovereignExportView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SovereignExportView()
        }
    }
}
#endif
