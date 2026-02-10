import SwiftUI

// ============================================================================
// PIN AS GOLDEN CASE SHEET (Phase 8B)
//
// Consent-gated disclosure before pinning a memory item as a golden case.
// INVARIANT: Requires explicit user confirmation
// INVARIANT: Explains what is stored (metadata only)
// INVARIANT: User can delete at any time
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

struct PinAsGoldenCaseSheet: View {
    let item: PersistedMemoryItem
    let onPin: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var goldenCaseStore = GoldenCaseStore.shared
    
    @State private var customTitle: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection
                    
                    // Disclosure
                    disclosureSection
                    
                    // What's stored
                    whatIsStoredSection
                    
                    // Custom title
                    titleSection
                    
                    // Action buttons
                    actionButtons
                }
                .padding(20)
            }
            .navigationTitle("Pin as Golden Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Generate default title
                let snapshot = GoldenCaseSnapshot.from(memoryItem: item)
                customTitle = "\(item.type.rawValue) - \(snapshot.contextCounts.summary)"
                if customTitle.count > GoldenCase.maxTitleLength {
                    customTitle = String(customTitle.prefix(GoldenCase.maxTitleLength))
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "pin.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(OKColor.riskExtreme)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pin as Golden Case")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("For local quality evaluation")
                        .font(.subheadline)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Disclosure Section
    
    private var disclosureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(OKColor.actionPrimary)
                Text("What This Does")
                    .font(.headline)
            }
            
            Text("This saves a small, local-only metadata snapshot for evaluation. The snapshot is used to track quality over time and detect drift.")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
            
            // Key points
            VStack(alignment: .leading, spacing: 8) {
                disclosurePoint(icon: "checkmark.shield", text: "No content is stored", color: OKColor.riskNominal)
                disclosurePoint(icon: "iphone", text: "Stays on your device", color: OKColor.riskNominal)
                disclosurePoint(icon: "trash", text: "You can delete anytime", color: OKColor.riskNominal)
                disclosurePoint(icon: "xmark.icloud", text: "Never transmitted", color: OKColor.riskNominal)
            }
            .padding(12)
            .background(OKColor.riskNominal.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private func disclosurePoint(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(text)
                .font(.caption)
        }
    }
    
    // MARK: - What's Stored Section
    
    private var whatIsStoredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundColor(OKColor.textSecondary)
                Text("What's Stored")
                    .font(.headline)
            }
            
            let snapshot = GoldenCaseSnapshot.from(memoryItem: item)
            
            VStack(alignment: .leading, spacing: 6) {
                metadataRow("Intent type", snapshot.intentType)
                metadataRow("Output type", snapshot.outputType)
                metadataRow("Context counts", snapshot.contextCounts.summary)
                metadataRow("Confidence band", snapshot.confidenceBand)
                metadataRow("Backend used", snapshot.backendUsed)
                metadataRow("Used fallback", snapshot.usedFallback ? "Yes" : "No")
                metadataRow("Citations count", "\(snapshot.citationsCount)")
                if let latency = snapshot.latencyMs {
                    metadataRow("Latency", "\(latency)ms")
                }
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(10)
            
            Text("No email content, calendar details, or personal information is stored.")
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
    }
    
    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title")
                .font(.headline)
            
            TextField("Golden case title", text: $customTitle)
                .textFieldStyle(.roundedBorder)
                .onChange(of: customTitle) { _, newValue in
                    if newValue.count > GoldenCase.maxTitleLength {
                        customTitle = String(newValue.prefix(GoldenCase.maxTitleLength))
                    }
                }
            
            Text("\(customTitle.count)/\(GoldenCase.maxTitleLength) characters")
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                pinGoldenCase()
            } label: {
                HStack {
                    Image(systemName: "pin.fill")
                    Text("Pin as Golden Case")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(OKColor.riskExtreme)
                .foregroundColor(OKColor.textPrimary)
                .cornerRadius(12)
            }
            
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.subheadline)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
    }
    
    // MARK: - Pin Logic
    
    private func pinGoldenCase() {
        let goldenCase = goldenCaseStore.createGoldenCase(
            from: item,
            title: customTitle.isEmpty ? nil : customTitle
        )
        
        let result = goldenCaseStore.addCase(goldenCase)
        
        switch result {
        case .success:
            onPin()
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    // This would need a mock PersistedMemoryItem
    Text("Preview not available")
}
