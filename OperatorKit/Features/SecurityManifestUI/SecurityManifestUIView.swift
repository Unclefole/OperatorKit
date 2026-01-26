import SwiftUI

// ============================================================================
// SECURITY MANIFEST UI VIEW (Phase L1)
//
// User-facing read-only view displaying OperatorKit's security posture.
// Every claim is backed by existing proof artifacts — no marketing.
//
// PROOF SOURCES:
// - Binary Proof (BinaryImageInspector)
// - Build Seals (BuildSealsLoader)
// - Offline Certification (OfflineCertificationRunner)
// - ProofPack (ProofPackAssembler)
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No buttons (except navigation back)
// ❌ No toggles
// ❌ No refresh actions
// ❌ No networking
// ❌ No enforcement logic
// ✅ Read-only display only
// ✅ Feature-flagged
// ============================================================================

public struct SecurityManifestUIView: View {
    
    // MARK: - State
    
    @State private var manifestItems: [SecurityManifestItem] = []
    @State private var isLoading = true
    
    // MARK: - Body
    
    public init() {}
    
    public var body: some View {
        Group {
            if !SecurityManifestUIFeatureFlag.isEnabled {
                disabledView
            } else if isLoading {
                loadingView
            } else {
                contentView
            }
        }
        .navigationTitle("Security Manifest")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadManifest)
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        List {
            // Header Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "shield.checkered")
                            .font(.title)
                            .foregroundColor(.green)
                        
                        Text("Security Posture")
                            .font(.headline)
                    }
                    
                    Text("Each item below is backed by verifiable proof. No marketing claims.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            // Security Claims Section
            Section {
                ForEach(manifestItems) { item in
                    SecurityManifestRow(item: item)
                }
            } header: {
                Text("Verified Claims")
            } footer: {
                Text("All claims are derived from existing proof artifacts generated at build time or verified at runtime.")
            }
            
            // Proof Sources Section
            Section {
                proofSourceRow(
                    label: "Binary Proof",
                    description: "Mach-O framework inspection",
                    icon: "cpu"
                )
                
                proofSourceRow(
                    label: "Build Seals",
                    description: "Entitlements, dependencies, symbols",
                    icon: "checkmark.seal"
                )
                
                proofSourceRow(
                    label: "Offline Certification",
                    description: "Zero-network verification",
                    icon: "airplane"
                )
                
                proofSourceRow(
                    label: "Proof Pack",
                    description: "Unified trust evidence",
                    icon: "shippingbox"
                )
            } header: {
                Text("Proof Sources")
            } footer: {
                Text("These are the artifacts that back each claim above.")
            }
            
            // Footer Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This manifest is read-only.")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text("It reflects the current state of proof artifacts. No actions can be taken from this screen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading security manifest...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Disabled View
    
    private var disabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Security Manifest Disabled")
                .font(.headline)
            
            Text("This feature is currently disabled.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func proofSourceRow(label: String, description: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Load Manifest
    
    private func loadManifest() {
        isLoading = true
        
        // Load on background to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let items = SecurityManifestUIAssembler.assemble()
            
            DispatchQueue.main.async {
                self.manifestItems = items
                self.isLoading = false
            }
        }
    }
}

// MARK: - Security Manifest Item

/// A single verifiable security claim
public struct SecurityManifestItem: Identifiable {
    public let id = UUID()
    
    /// Display label for the claim
    public let label: String
    
    /// Whether the claim is verified/passing
    public let isVerified: Bool
    
    /// Short factual description (no marketing)
    public let description: String
    
    /// Source of the proof (e.g., "Binary Proof", "Build Seals")
    public let proofSource: String
    
    public init(label: String, isVerified: Bool, description: String, proofSource: String) {
        self.label = label
        self.isVerified = isVerified
        self.description = description
        self.proofSource = proofSource
    }
}

// MARK: - Security Manifest Row

private struct SecurityManifestRow: View {
    let item: SecurityManifestItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            Image(systemName: item.isVerified ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(item.isVerified ? .green : .red)
                .font(.title3)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Source: \(item.proofSource)")
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Security Manifest Assembler

/// Assembles manifest items from existing proof artifacts
/// This is read-only aggregation — no new computation, no enforcement
public enum SecurityManifestUIAssembler {
    
    /// Assemble all security manifest items from existing proofs
    public static func assemble() -> [SecurityManifestItem] {
        var items: [SecurityManifestItem] = []
        
        // 1. WebKit: Not linked (from Binary Proof)
        let binaryResult = BinaryImageInspector.inspect()
        let webKitCheck = binaryResult.sensitiveChecks.first { $0.framework == "WebKit" }
        let webKitPresent = webKitCheck?.isPresent ?? false
        
        items.append(SecurityManifestItem(
            label: "WebKit",
            isVerified: !webKitPresent,
            description: webKitPresent ? "WebKit framework detected" : "Not linked in binary",
            proofSource: "Binary Proof"
        ))
        
        // 2. JavaScript: Not present (from Binary Proof)
        let jsCheck = binaryResult.sensitiveChecks.first { $0.framework == "JavaScriptCore" }
        let jsPresent = jsCheck?.isPresent ?? false
        
        items.append(SecurityManifestItem(
            label: "JavaScript",
            isVerified: !jsPresent,
            description: jsPresent ? "JavaScriptCore detected" : "Not present in binary",
            proofSource: "Binary Proof"
        ))
        
        // 3. Network Entitlements (from Build Seals)
        let buildSeals = BuildSealsLoader.loadAllSeals()
        let networkRequested = buildSeals.entitlements?.networkClientRequested ?? false
        
        items.append(SecurityManifestItem(
            label: "Network Entitlements",
            isVerified: !networkRequested,
            description: networkRequested ? "Network client entitlement requested" : "No network entitlements",
            proofSource: "Entitlements Seal"
        ))
        
        // 4. Offline Execution (from Offline Certification)
        let offlineReport = OfflineCertificationRunner.shared.runAllChecks()
        let offlineCertified = offlineReport.failedCount == 0
        
        items.append(SecurityManifestItem(
            label: "Offline Execution",
            isVerified: offlineCertified,
            description: offlineCertified ? "Certified for offline operation" : "Some offline checks failed",
            proofSource: "Offline Certification"
        ))
        
        // 5. Build Integrity (from Build Seals)
        let buildVerified = buildSeals.overallStatus == .verified
        
        items.append(SecurityManifestItem(
            label: "Build Integrity",
            isVerified: buildVerified,
            description: buildVerified ? "Build seals verified" : "Build seals: \(buildSeals.overallStatus.rawValue)",
            proofSource: "Build Seals"
        ))
        
        // 6. Proof Exportable (from ProofPack availability)
        let proofPackEnabled = ProofPackFeatureFlag.isEnabled
        
        items.append(SecurityManifestItem(
            label: "Proof Exportable",
            isVerified: proofPackEnabled,
            description: proofPackEnabled ? "Trust evidence can be exported" : "Proof export disabled",
            proofSource: "ProofPack"
        ))
        
        // 7. Forbidden Symbols (from Build Seals / Symbol Seal)
        let forbiddenSymbols = buildSeals.symbols?.forbiddenSymbolCount ?? 0
        let noForbidden = forbiddenSymbols == 0
        
        items.append(SecurityManifestItem(
            label: "Forbidden Symbols",
            isVerified: noForbidden,
            description: noForbidden ? "No forbidden networking symbols" : "\(forbiddenSymbols) forbidden symbols detected",
            proofSource: "Symbol Seal"
        ))
        
        // 8. Safari Services (from Binary Proof)
        let safariCheck = binaryResult.sensitiveChecks.first { $0.framework == "SafariServices" }
        let safariPresent = safariCheck?.isPresent ?? false
        
        items.append(SecurityManifestItem(
            label: "Safari Services",
            isVerified: !safariPresent,
            description: safariPresent ? "SafariServices detected" : "Not linked",
            proofSource: "Binary Proof"
        ))
        
        return items
    }
}

// MARK: - Preview

#if DEBUG
struct SecurityManifestUIView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SecurityManifestUIView()
        }
    }
}
#endif
