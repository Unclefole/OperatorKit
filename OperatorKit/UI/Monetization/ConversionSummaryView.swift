import SwiftUI

// ============================================================================
// CONVERSION SUMMARY VIEW (Phase 10L)
//
// Read-only display of conversion funnel data.
// No execution triggers, no user content.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No behavior toggles
// ❌ No user content display
// ❌ No execution triggers
// ✅ Read-only status display
// ✅ Export via ShareSheet only
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct ConversionSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var variantStore = PricingVariantStore.shared
    @StateObject private var funnelManager = ConversionFunnelManager.shared
    
    @State private var summary: FunnelSummary?
    @State private var showingExport = false
    @State private var exportURL: URL?
    @State private var showingVariantPicker = false
    
    var body: some View {
        NavigationView {
            List {
                // Current Variant
                variantSection
                
                // Funnel Counts
                funnelCountsSection
                
                // Growth & Acquisition (Phase 11A)
                growthSection
                
                // Conversion Rates
                conversionRatesSection
                
                // Export
                exportSection
                
                // Disclaimer
                disclaimerSection
            }
            .scrollContentBackground(.hidden)
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Conversion Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                loadSummary()
            }
            .sheet(isPresented: $showingExport) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingVariantPicker) {
                VariantPickerSheet(currentVariant: variantStore.currentVariant) { selected in
                    variantStore.setVariant(selected)
                    loadSummary()
                }
            }
        }
    }
    
    // MARK: - Variant Section
    
    private var variantSection: some View {
        Section {
            HStack {
                Label("Current Variant", systemImage: "a.square")
                Spacer()
                Text(variantStore.currentVariant.displayName)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            Button {
                showingVariantPicker = true
            } label: {
                HStack {
                    Label("Change Variant", systemImage: "slider.horizontal.3")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(OKColor.textMuted)
                }
            }
        } header: {
            Text("Pricing Variant")
        } footer: {
            Text("Copy variant is stored locally. No network communication.")
        }
    }
    
    // MARK: - Funnel Counts Section
    
    private var funnelCountsSection: some View {
        Section {
            if let summary = summary {
                FunnelRow(
                    step: "Onboarding Shown",
                    count: summary.onboardingShownCount,
                    icon: "1.circle"
                )
                
                FunnelRow(
                    step: "Pricing Viewed",
                    count: summary.pricingViewedCount,
                    icon: "2.circle"
                )
                
                FunnelRow(
                    step: "Upgrade Tapped",
                    count: summary.upgradeTappedCount,
                    icon: "3.circle"
                )
                
                FunnelRow(
                    step: "Purchase Started",
                    count: summary.purchaseStartedCount,
                    icon: "4.circle"
                )
                
                FunnelRow(
                    step: "Purchase Success",
                    count: summary.purchaseSuccessCount,
                    icon: "5.circle",
                    highlight: true
                )
                
                FunnelRow(
                    step: "Restore Tapped",
                    count: summary.restoreTappedCount,
                    icon: "arrow.clockwise"
                )
                
                FunnelRow(
                    step: "Restore Success",
                    count: summary.restoreSuccessCount,
                    icon: "checkmark.circle"
                )
            } else {
                Text("Loading...")
                    .foregroundColor(OKColor.textSecondary)
            }
        } header: {
            Text("Funnel Counts")
        }
    }
    
    // MARK: - Growth Section (Phase 11A)
    
    private var growthSection: some View {
        Section {
            if let summary = summary {
                FunnelRow(
                    step: "Referral Viewed",
                    count: summary.referralViewedCount,
                    icon: "person.2"
                )
                
                FunnelRow(
                    step: "Referral Shared",
                    count: summary.referralSharedCount,
                    icon: "square.and.arrow.up"
                )
                
                FunnelRow(
                    step: "Buyer Proof Exported",
                    count: summary.buyerProofExportedCount,
                    icon: "checkmark.seal"
                )
                
                FunnelRow(
                    step: "Template Copied",
                    count: summary.outboundTemplateCopiedCount,
                    icon: "doc.on.doc"
                )
                
                FunnelRow(
                    step: "Outbound Mail Opened",
                    count: summary.outboundMailOpenedCount,
                    icon: "envelope"
                )
                
                // Summary row
                HStack {
                    Label("Total Growth Actions", systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundColor(OKColor.riskNominal)
                    Spacer()
                    Text("\(summary.totalGrowthActions)")
                        .fontWeight(.bold)
                        .foregroundColor(OKColor.riskNominal)
                }
            }
        } header: {
            Label("Growth & Acquisition", systemImage: "arrow.up.right")
        } footer: {
            Text("Actions taken to grow adoption and close sales.")
        }
    }
    
    // MARK: - Conversion Rates Section
    
    private var conversionRatesSection: some View {
        Section {
            if let summary = summary {
                RateRow(
                    label: "Pricing View Rate",
                    rate: summary.pricingViewRate,
                    description: "Views / Onboarding"
                )
                
                RateRow(
                    label: "Upgrade Tap Rate",
                    rate: summary.upgradeTapRate,
                    description: "Taps / Views"
                )
                
                RateRow(
                    label: "Purchase Start Rate",
                    rate: summary.purchaseStartRate,
                    description: "Starts / Taps"
                )
                
                RateRow(
                    label: "Purchase Success Rate",
                    rate: summary.purchaseSuccessRate,
                    description: "Success / Starts"
                )
                
                RateRow(
                    label: "Overall Conversion",
                    rate: summary.overallConversionRate,
                    description: "Success / Views",
                    highlight: true
                )
            }
        } header: {
            Text("Conversion Rates")
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section {
            Button {
                exportSummary()
            } label: {
                Label("Export Conversion Data (JSON)", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("Export")
        } footer: {
            Text("Export contains aggregate counts only. No user data.")
        }
    }
    
    // MARK: - Disclaimer Section
    
    private var disclaimerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Local-Only Data", systemImage: "iphone")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("All conversion data is stored locally on this device. No analytics services, no identifiers, no network transmission.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadSummary() {
        summary = funnelManager.currentFunnelSummary()
    }
    
    private func exportSummary() {
        Task { @MainActor in
            do {
                let packet = ConversionExportPacket()
                let jsonData = try packet.exportJSON()
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(packet.exportFilename)
                try jsonData.write(to: tempURL)
                exportURL = tempURL
                showingExport = true
            } catch {
                // Handle silently
            }
        }
    }
}

// MARK: - Funnel Row

private struct FunnelRow: View {
    let step: String
    let count: Int
    let icon: String
    var highlight: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(highlight ? OKColor.riskNominal : OKColor.actionPrimary)
                .frame(width: 24)
            
            Text(step)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(count)")
                .fontWeight(highlight ? .bold : .regular)
                .foregroundColor(highlight ? OKColor.riskNominal : .primary)
        }
    }
}

// MARK: - Rate Row

private struct RateRow: View {
    let label: String
    let rate: Double?
    let description: String
    var highlight: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            Spacer()
            
            Text(formattedRate)
                .font(.subheadline)
                .fontWeight(highlight ? .bold : .regular)
                .foregroundColor(rateColor)
        }
    }
    
    private var formattedRate: String {
        guard let rate = rate else { return "N/A" }
        return String(format: "%.1f%%", rate * 100)
    }
    
    private var rateColor: Color {
        guard let rate = rate else { return .secondary }
        if highlight {
            return rate > 0.1 ? OKColor.riskNominal : (rate > 0.05 ? OKColor.riskWarning : OKColor.riskCritical)
        }
        return .primary
    }
}

// MARK: - Variant Picker Sheet

private struct VariantPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let currentVariant: PricingVariant
    let onSelect: (PricingVariant) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(PricingVariant.allCases, id: \.self) { variant in
                    Button {
                        onSelect(variant)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(variant.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(OKColor.textPrimary)
                                
                                Text(variantDescription(for: variant))
                                    .font(.caption)
                                    .foregroundColor(OKColor.textSecondary)
                            }
                            
                            Spacer()
                            
                            if variant == currentVariant {
                                Image(systemName: "checkmark")
                                    .foregroundColor(OKColor.actionPrimary)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(OKColor.backgroundPrimary)
            .navigationTitle("Select Variant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func variantDescription(for variant: PricingVariant) -> String {
        switch variant {
        case .variantA: return "Balanced messaging"
        case .variantB: return "Value-focused copy"
        case .variantC: return "Privacy-focused copy"
        }
    }
}

// MARK: - Preview

#Preview {
    ConversionSummaryView()
}
