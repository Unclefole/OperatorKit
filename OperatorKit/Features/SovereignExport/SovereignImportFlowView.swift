import SwiftUI
import UniformTypeIdentifiers

// ============================================================================
// SOVEREIGN IMPORT FLOW VIEW (Phase 13C)
//
// Step-by-step import flow with passphrase entry.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No automatic operations
// ❌ No overwrite without confirmation
// ✅ User confirmation required
// ✅ Validation before apply
// ============================================================================

struct SovereignImportFlowView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var step: ImportStep = .selectFile
    @State private var encryptedData: Data? = nil
    @State private var passphrase: String = ""
    @State private var decryptedBundle: SovereignExportBundle? = nil
    @State private var importSummary: ImportSummary? = nil
    @State private var applyReport: ApplyReport? = nil
    @State private var errorMessage: String? = nil
    @State private var showingFilePicker = false
    
    private enum ImportStep {
        case selectFile
        case passphrase
        case decrypting
        case preview
        case applying
        case complete
        case error
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack {
                switch step {
                case .selectFile:
                    selectFileStep
                case .passphrase:
                    passphraseStep
                case .decrypting:
                    decryptingStep
                case .preview:
                    previewStep
                case .applying:
                    applyingStep
                case .complete:
                    completeStep
                case .error:
                    errorStep
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }
    
    // MARK: - Select File Step
    
    private var selectFileStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(OKColor.actionPrimary)
            
            Text("Select Export File")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Choose a previously exported .oksov file")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
            
            Spacer()
            
            Button(action: { showingFilePicker = true }) {
                Text("Select File")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(OKColor.actionPrimary)
                    .foregroundColor(OKColor.textPrimary)
                    .cornerRadius(12)
            }
            .padding()
        }
        .padding()
    }
    
    // MARK: - Passphrase Step
    
    private var passphraseStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(OKColor.riskExtreme)
            
            Text("Enter Passphrase")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Enter the passphrase used when exporting")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
            
            SecureField("Passphrase", text: $passphrase)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)
                .padding()
            
            Spacer()
            
            Button(action: performDecrypt) {
                Text("Decrypt")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(passphrase.isEmpty ? OKColor.textMuted : OKColor.riskExtreme)
                    .foregroundColor(OKColor.textPrimary)
                    .cornerRadius(12)
            }
            .disabled(passphrase.isEmpty)
            .padding()
        }
        .padding()
    }
    
    // MARK: - Decrypting Step
    
    private var decryptingStep: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Decrypting...")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
    }
    
    // MARK: - Preview Step
    
    private var previewStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(OKColor.riskNominal)
            
            Text("Import Preview")
                .font(.title2)
                .fontWeight(.bold)
            
            if let summary = importSummary {
                VStack(alignment: .leading, spacing: 8) {
                    PreviewRow(label: "Procedures", value: "\(summary.procedureCount)")
                    PreviewRow(label: "Custom Policy", value: summary.hasCustomPolicy ? "Yes" : "No")
                    PreviewRow(label: "Tier", value: summary.tier.capitalized)
                    PreviewRow(label: "Export Date", value: summary.exportDate)
                    PreviewRow(label: "App Version", value: summary.appVersion)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Text("Review the contents above. Tap Import to apply.")
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
            
            Spacer()
            
            Button(action: performApply) {
                Text("Import Configuration")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(OKColor.riskNominal)
                    .foregroundColor(OKColor.textPrimary)
                    .cornerRadius(12)
            }
            .padding()
        }
        .padding()
    }
    
    // MARK: - Applying Step
    
    private var applyingStep: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Applying...")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
    }
    
    // MARK: - Complete Step
    
    private var completeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(OKColor.riskNominal)
            
            Text("Import Complete")
                .font(.title2)
                .fontWeight(.bold)
            
            if let report = applyReport {
                VStack(alignment: .leading, spacing: 8) {
                    PreviewRow(label: "Procedures Imported", value: "\(report.proceduresImported)")
                    PreviewRow(label: "Procedures Skipped", value: "\(report.proceduresSkipped)")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(OKColor.actionPrimary)
                    .foregroundColor(OKColor.textPrimary)
                    .cornerRadius(12)
            }
            .padding()
        }
        .padding()
    }
    
    // MARK: - Error Step
    
    private var errorStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(OKColor.riskCritical)
            
            Text("Import Failed")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(errorMessage ?? "Invalid passphrase or corrupted file")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button(action: { step = .selectFile; errorMessage = nil }) {
                Text("Try Again")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(OKColor.actionPrimary)
                    .foregroundColor(OKColor.textPrimary)
                    .cornerRadius(12)
            }
            .padding()
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                errorMessage = "No file selected"
                step = .error
                return
            }
            
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access file"
                step = .error
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                encryptedData = try Data(contentsOf: url)
                step = .passphrase
            } catch {
                errorMessage = "Failed to read file"
                step = .error
            }
            
        case .failure:
            errorMessage = "File selection failed"
            step = .error
        }
    }
    
    private func performDecrypt() {
        guard let data = encryptedData else {
            errorMessage = "No file data"
            step = .error
            return
        }
        
        step = .decrypting
        
        Task { @MainActor in
            let result = SovereignExportCrypto.decrypt(
                encryptedData: data,
                passphrase: passphrase
            )
            
            passphrase = "" // Clear from memory
            
            switch result {
            case .success(let bundle):
                decryptedBundle = bundle
                
                // Get summary
                let applyResult = SovereignExportService.shared.applyBundle(bundle, confirmed: false)
                if case .requiresConfirmation(let summary) = applyResult {
                    importSummary = summary
                }
                
                step = .preview
                
            case .failure(let error):
                errorMessage = error
                step = .error
            }
        }
    }
    
    private func performApply() {
        guard let bundle = decryptedBundle else {
            errorMessage = "No bundle to apply"
            step = .error
            return
        }
        
        step = .applying
        
        Task { @MainActor in
            let result = SovereignExportService.shared.applyBundle(bundle, confirmed: true)
            
            switch result {
            case .success(let report):
                applyReport = report
                step = .complete
                
            case .failure(let error):
                errorMessage = error
                step = .error
                
            case .requiresConfirmation:
                // Should not happen with confirmed: true
                break
            }
        }
    }
}

// MARK: - Preview Row

private struct PreviewRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}
