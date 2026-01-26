import SwiftUI
import UniformTypeIdentifiers

// ============================================================================
// SOVEREIGN EXPORT FLOW VIEW (Phase 13C)
//
// Step-by-step export flow with passphrase entry.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No plaintext on disk
// ❌ No automatic operations
// ✅ User confirmation required
// ✅ Encrypted output only
// ============================================================================

struct SovereignExportFlowView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var step: ExportStep = .warning
    @State private var passphrase: String = ""
    @State private var confirmPassphrase: String = ""
    @State private var encryptedBundle: EncryptedBundle? = nil
    @State private var errorMessage: String? = nil
    @State private var showingFileSaver = false
    
    private enum ExportStep {
        case warning
        case passphrase
        case encrypting
        case ready
        case error
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack {
                switch step {
                case .warning:
                    warningStep
                case .passphrase:
                    passphraseStep
                case .encrypting:
                    encryptingStep
                case .ready:
                    readyStep
                case .error:
                    errorStep
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $showingFileSaver,
                document: encryptedBundle.map { SovereignExportDocument(bundle: $0) },
                contentType: .data,
                defaultFilename: encryptedBundle?.filename ?? "export.oksov"
            ) { result in
                switch result {
                case .success:
                    dismiss()
                case .failure:
                    errorMessage = "Failed to save file"
                    step = .error
                }
            }
        }
    }
    
    // MARK: - Warning Step
    
    private var warningStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Important")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                WarningRow(text: "This export contains logic only, not user data")
                WarningRow(text: "You must remember your passphrase")
                WarningRow(text: "Lost passphrases cannot be recovered")
                WarningRow(text: "The file is safe to store anywhere")
            }
            .padding()
            
            Spacer()
            
            Button(action: { step = .passphrase }) {
                Text("I Understand, Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
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
                .foregroundColor(.purple)
            
            Text("Create Passphrase")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                SecureField("Passphrase", text: $passphrase)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                
                SecureField("Confirm Passphrase", text: $confirmPassphrase)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                
                if !passphrase.isEmpty && passphrase != confirmPassphrase {
                    Text("Passphrases do not match")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                if passphrase.count > 0 && passphrase.count < 8 {
                    Text("Passphrase must be at least 8 characters")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            
            Spacer()
            
            Button(action: performExport) {
                Text("Encrypt & Export")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canExport ? Color.purple : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(!canExport)
            .padding()
        }
        .padding()
    }
    
    private var canExport: Bool {
        passphrase.count >= 8 && passphrase == confirmPassphrase
    }
    
    // MARK: - Encrypting Step
    
    private var encryptingStep: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Encrypting...")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your configuration is being encrypted locally.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Ready Step
    
    private var readyStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("Export Ready")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your encrypted export is ready to save.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: { showingFileSaver = true }) {
                Text("Save File")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
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
                .foregroundColor(.red)
            
            Text("Export Failed")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(errorMessage ?? "An unknown error occurred")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("Close")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func performExport() {
        step = .encrypting
        
        Task { @MainActor in
            // Build bundle
            let buildResult = SovereignExportService.shared.buildBundle()
            
            switch buildResult {
            case .success(let bundle):
                // Encrypt
                let encryptResult = SovereignExportCrypto.encrypt(
                    bundle: bundle,
                    passphrase: passphrase
                )
                
                switch encryptResult {
                case .success(let encrypted):
                    encryptedBundle = encrypted
                    passphrase = "" // Clear passphrase from memory
                    confirmPassphrase = ""
                    step = .ready
                    
                case .failure(let error):
                    errorMessage = error
                    step = .error
                }
                
            case .failure(let error):
                errorMessage = error
                step = .error
            }
        }
    }
}

// MARK: - Warning Row

private struct WarningRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .padding(.top, 6)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Export Document

struct SovereignExportDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.data]
    
    let data: Data
    let filename: String
    
    init(bundle: EncryptedBundle) {
        self.data = bundle.data
        self.filename = bundle.filename
    }
    
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
        self.filename = "export.oksov"
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
