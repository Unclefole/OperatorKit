import SwiftUI

// ============================================================================
// BUILD SEALS VIEW (Phase 13J)
//
// Read-only display of build-time proof seals.
// User-initiated export only.
//
// CONSTRAINTS:
// ❌ No networking
// ❌ No state mutation
// ❌ No user content
// ✅ Read-only display
// ✅ User-initiated export via ShareSheet
// ============================================================================

public struct BuildSealsView: View {
    @State private var packet: BuildSealsPacket?
    @State private var isLoading = true
    @State private var exportJSON: String?
    
    public init() {}
    
    public var body: some View {
        Group {
            if !BuildSealsFeatureFlag.isEnabled {
                disabledView
            } else if isLoading {
                loadingView
            } else if let packet = packet {
                contentView(packet)
            } else {
                errorView
            }
        }
        .navigationTitle("Build Seals")
        .onAppear(perform: loadSeals)
    }
    
    // MARK: - Views
    
    private var disabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Build Seals Disabled")
                .font(.headline)
            
            Text("This feature is currently disabled.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading build seals...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Unable to Load Seals")
                .font(.headline)
            
            Text("Build seals could not be loaded from bundle resources.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private func contentView(_ packet: BuildSealsPacket) -> some View {
        List {
            // Header Section
            Section {
                HStack {
                    statusIcon(for: packet.overallStatus)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Build Seals Status")
                            .font(.headline)
                        
                        Text(packet.overallStatus.rawValue)
                            .font(.subheadline)
                            .foregroundColor(statusColor(for: packet.overallStatus))
                    }
                    
                    Spacer()
                }
            } header: {
                Text("Overview")
            } footer: {
                Text("Build seals are cryptographic proofs generated at build time. They verify source integrity without runtime enforcement.")
            }
            
            // Entitlements Seal
            if let entitlements = packet.entitlements {
                Section {
                    sealRow(label: "Hash", value: formatHash(entitlements.entitlementsHash))
                    sealRow(label: "Entitlement Count", value: "\(entitlements.entitlementCount)")
                    sealRow(label: "Sandbox", value: entitlements.sandboxEnabled ? "Enabled" : "Disabled")
                    sealRow(label: "Network Requested", value: entitlements.networkClientRequested ? "Yes" : "No")
                } header: {
                    Label("Entitlements Seal", systemImage: "signature")
                } footer: {
                    Text("SHA256 of the app's code signing entitlements plist.")
                }
            } else {
                Section {
                    Text("Not available")
                        .foregroundColor(.secondary)
                } header: {
                    Label("Entitlements Seal", systemImage: "signature")
                }
            }
            
            // Dependency Seal
            if let dependencies = packet.dependencies {
                Section {
                    sealRow(label: "Hash", value: formatHash(dependencies.dependencyHash))
                    sealRow(label: "Direct Dependencies", value: "\(dependencies.dependencyCount)")
                    sealRow(label: "Transitive", value: "\(dependencies.transitiveDependencyCount)")
                    sealRow(label: "Lockfile", value: dependencies.lockfilePresent ? "Present" : "Missing")
                } header: {
                    Label("Dependency Seal", systemImage: "shippingbox")
                } footer: {
                    Text("SHA256 of the normalized SPM dependency list from Package.resolved.")
                }
            } else {
                Section {
                    Text("Not available")
                        .foregroundColor(.secondary)
                } header: {
                    Label("Dependency Seal", systemImage: "shippingbox")
                }
            }
            
            // Symbol Seal
            if let symbols = packet.symbols {
                Section {
                    sealRow(label: "Hash", value: formatHash(symbols.symbolListHash))
                    sealRow(label: "Symbols Scanned", value: "\(symbols.totalSymbolsScanned)")
                    
                    HStack {
                        Text("Forbidden Symbols")
                        Spacer()
                        Text("\(symbols.forbiddenSymbolCount)")
                            .foregroundColor(symbols.forbiddenSymbolCount == 0 ? .green : .red)
                    }
                    
                    HStack {
                        Text("Forbidden Frameworks")
                        Spacer()
                        Image(systemName: symbols.forbiddenFrameworkPresent ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(symbols.forbiddenFrameworkPresent ? .red : .green)
                    }
                    
                    // Framework Checks
                    ForEach(symbols.frameworkChecks, id: \.framework) { check in
                        HStack {
                            Text(check.framework)
                                .font(.caption)
                            Spacer()
                            Image(systemName: check.detected ? "xmark.circle" : "checkmark.circle")
                                .foregroundColor(check.detected ? .red : .green)
                                .font(.caption)
                        }
                    }
                } header: {
                    Label("Symbol Seal", systemImage: "function")
                } footer: {
                    Text("Verification that no forbidden network/web symbols are linked in the binary.")
                }
            } else {
                Section {
                    Text("Not available")
                        .foregroundColor(.secondary)
                } header: {
                    Label("Symbol Seal", systemImage: "function")
                }
            }
            
            // Export Section
            Section {
                if let json = exportJSON {
                    ShareLink(
                        item: json,
                        subject: Text("Build Seals Export"),
                        message: Text("OperatorKit Build Seals Proof Packet")
                    ) {
                        Label("Export Build Seals", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button(action: prepareExport) {
                        Label("Prepare Export", systemImage: "doc.badge.gearshape")
                    }
                }
            } header: {
                Text("Export")
            } footer: {
                Text("Export contains metadata only: hashes, counts, and booleans. No user data.")
            }
            
            // Metadata Section
            Section {
                sealRow(label: "App Version", value: packet.appVersion)
                sealRow(label: "Build Number", value: packet.buildNumber)
                sealRow(label: "Schema Version", value: "\(packet.schemaVersion)")
                sealRow(label: "Generated", value: packet.generatedAtDayRounded)
            } header: {
                Text("Metadata")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func sealRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
    
    private func formatHash(_ hash: String) -> String {
        // Show first 8 and last 8 characters
        if hash.count >= 16 {
            let start = hash.prefix(8)
            let end = hash.suffix(8)
            return "\(start)...\(end)"
        }
        return hash
    }
    
    private func statusIcon(for status: BuildSealsStatus) -> some View {
        let (icon, color): (String, Color) = {
            switch status {
            case .verified: return ("checkmark.seal.fill", .green)
            case .partial: return ("exclamationmark.triangle.fill", .orange)
            case .missing: return ("questionmark.circle.fill", .gray)
            case .failed: return ("xmark.seal.fill", .red)
            }
        }()
        
        return Image(systemName: icon)
            .font(.system(size: 32))
            .foregroundColor(color)
    }
    
    private func statusColor(for status: BuildSealsStatus) -> Color {
        switch status {
        case .verified: return .green
        case .partial: return .orange
        case .missing: return .gray
        case .failed: return .red
        }
    }
    
    // MARK: - Actions
    
    private func loadSeals() {
        isLoading = true
        
        // Load on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedPacket = BuildSealsLoader.loadAllSeals()
            
            DispatchQueue.main.async {
                self.packet = loadedPacket
                self.isLoading = false
            }
        }
    }
    
    private func prepareExport() {
        guard let packet = packet else { return }
        exportJSON = packet.toJSON()
    }
}

// MARK: - Preview

#if DEBUG
struct BuildSealsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BuildSealsView()
        }
    }
}
#endif
