import SwiftUI

// ============================================================================
// DIAGNOSTICS VIEW (Phase 10B)
//
// Read-only view for operator-visible diagnostics.
// No buttons except "Export Diagnostics".
// Copy is factual and calm — no "AI", no "smart", no anthropomorphic language.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking
// ❌ No user content display
// ❌ No behavior-affecting controls
// ✅ Read-only
// ✅ Export only via ShareSheet
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    @State private var executionSnapshot: ExecutionDiagnosticsSnapshot = .empty
    @State private var usageSnapshot: UsageDiagnosticsSnapshot = .empty
    @State private var isLoading: Bool = true
    @State private var exportURL: URL?
    @State private var showingShareSheet: Bool = false
    @State private var showingExportError: Bool = false
    @State private var showingPricing: Bool = false  // Phase 10I
    
    var body: some View {
        NavigationView {
            List {
                // Execution Summary
                executionSummarySection
                
                // Usage & Limits
                usageLimitsSection
                
                // Fallback & Reliability
                reliabilitySection
                
                // System Guarantees
                systemGuaranteesSection
                
                // Monetization (Phase 10H)
                monetizationSection
                
                // Export
                exportSection
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadDiagnostics()
            }
            .refreshable {
                loadDiagnostics()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Export Error", isPresented: $showingExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Could not export diagnostics. Please try again.")
            }
        }
    }
    
    // MARK: - Execution Summary Section
    
    private var executionSummarySection: some View {
        Section {
            // Executions this week
            DiagnosticsRow(
                title: "Executions This Week",
                value: "\(executionSnapshot.executionsLast7Days)",
                icon: "arrow.right.circle",
                iconColor: .blue
            )
            
            // Executions today
            DiagnosticsRow(
                title: "Executions Today",
                value: "\(executionSnapshot.executionsToday)",
                icon: "sun.max",
                iconColor: .orange
            )
            
            // Last execution
            DiagnosticsRow(
                title: "Last Execution",
                value: executionSnapshot.formattedLastExecution,
                icon: "clock",
                iconColor: .gray
            )
            
            // Last outcome
            HStack(spacing: 12) {
                Image(systemName: executionSnapshot.lastExecutionOutcome.systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(outcomeColor(executionSnapshot.lastExecutionOutcome))
                    .frame(width: 24)
                
                Text("Last Outcome")
                    .font(.subheadline)
                
                Spacer()
                
                Text(executionSnapshot.lastExecutionOutcome.displayText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Execution Summary")
        } footer: {
            Text("Execution counts reset weekly.")
        }
    }
    
    // MARK: - Usage & Limits Section
    
    private var usageLimitsSection: some View {
        Section {
            // Subscription tier
            HStack(spacing: 12) {
                Image(systemName: usageSnapshot.subscriptionTier == .pro ? "star.fill" : "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(usageSnapshot.subscriptionTier == .pro ? .blue : .gray)
                    .frame(width: 24)
                
                Text("Plan")
                    .font(.subheadline)
                
                Spacer()
                
                SubscriptionTierBadge(tier: usageSnapshot.subscriptionTier)
            }
            .padding(.vertical, 4)
            
            // Execution limit
            if let limit = usageSnapshot.weeklyExecutionLimit,
               let remaining = usageSnapshot.executionsRemainingThisWindow {
                let used = limit - remaining
                DiagnosticsRow(
                    title: "Weekly Executions",
                    value: "\(used)/\(limit)",
                    icon: "number",
                    iconColor: remaining == 0 ? .red : (remaining <= 2 ? .orange : .green)
                )
            } else {
                DiagnosticsRow(
                    title: "Weekly Executions",
                    value: "Unlimited",
                    icon: "infinity",
                    iconColor: .green
                )
            }
            
            // Memory usage
            if let limit = usageSnapshot.memoryLimit {
                DiagnosticsRow(
                    title: "Saved Items",
                    value: "\(usageSnapshot.memoryItemCount)/\(limit)",
                    icon: "folder",
                    iconColor: usageSnapshot.isMemoryLimitReached ? .red : (usageSnapshot.isMemoryLimitApproaching ? .orange : .green)
                )
            } else {
                DiagnosticsRow(
                    title: "Saved Items",
                    value: "\(usageSnapshot.memoryItemCount)",
                    icon: "folder",
                    iconColor: .green
                )
            }
            
            // Reset time
            if let resetTime = usageSnapshot.formattedResetTime {
                DiagnosticsRow(
                    title: "Limits Reset",
                    value: resetTime,
                    icon: "arrow.clockwise",
                    iconColor: .blue
                )
            }
        } header: {
            Text("Usage & Limits")
        }
    }
    
    // MARK: - Reliability Section
    
    private var reliabilitySection: some View {
        Section {
            // Fallback status
            DiagnosticsRow(
                title: "Fallback Used Recently",
                value: executionSnapshot.fallbackUsedRecently ? "Yes" : "No",
                icon: executionSnapshot.fallbackUsedRecently ? "arrow.uturn.down.circle" : "checkmark.circle",
                iconColor: executionSnapshot.fallbackUsedRecently ? .orange : .green
            )
            
            // Last failure (if any)
            if let failure = executionSnapshot.lastFailureCategory {
                DiagnosticsRow(
                    title: "Last Issue",
                    value: failure.displayText,
                    icon: "exclamationmark.triangle",
                    iconColor: .orange
                )
            }
        } header: {
            Text("Reliability")
        } footer: {
            Text("Fallback ensures reliable operation when advanced features are unavailable.")
        }
    }
    
    // MARK: - System Guarantees Section
    
    private var systemGuaranteesSection: some View {
        Section {
            // On-device processing
            GuaranteeRow(
                title: "On-Device Processing",
                subtitle: "All operations run locally",
                icon: "cpu",
                status: .active
            )
            
            // No network transmission
            GuaranteeRow(
                title: "No Network Transmission",
                subtitle: "Data never leaves your device",
                icon: "wifi.slash",
                status: .active
            )
            
            // No background access
            GuaranteeRow(
                title: "No Background Access",
                subtitle: "Only runs when you use it",
                icon: "moon.zzz",
                status: .active
            )
            
            // Approval required
            GuaranteeRow(
                title: "Approval Required",
                subtitle: "Nothing happens without your action",
                icon: "checkmark.shield",
                status: .active
            )
        } header: {
            Text("System Guarantees")
        } footer: {
            Text("These guarantees are enforced by the app's architecture and cannot be disabled.")
        }
    }
    
    // MARK: - Monetization Section (Phase 10H)
    
    @StateObject private var conversionLedger = ConversionLedger.shared
    
    private var monetizationSection: some View {
        Section {
            // Current tier
            DiagnosticsRow(
                title: "Current Tier",
                value: EntitlementManager.shared.currentTier.displayName,
                icon: tierIcon,
                iconColor: tierColor
            )
            
            // Paywall shown count
            DiagnosticsRow(
                title: "Paywall Shown",
                value: "\(conversionLedger.summary.paywallShownCount)",
                icon: "rectangle.portrait.on.rectangle.portrait",
                iconColor: .purple
            )
            
            // Upgrade tap count
            DiagnosticsRow(
                title: "Upgrade Tapped",
                value: "\(conversionLedger.summary.upgradeTapCount)",
                icon: "hand.tap",
                iconColor: .blue
            )
            
            // Purchase success count
            DiagnosticsRow(
                title: "Purchases Completed",
                value: "\(conversionLedger.summary.purchaseSuccessCount)",
                icon: "checkmark.circle",
                iconColor: .green
            )
            
            // Conversion rate
            DiagnosticsRow(
                title: "Conversion Rate",
                value: conversionLedger.summary.formattedConversionRate,
                icon: "percent",
                iconColor: .orange
            )
            
            // See plans link (Phase 10I)
            if EntitlementManager.shared.currentTier == .free {
                Button {
                    showingPricing = true
                    ConversionLedger.shared.recordEvent(.upgradeTapped)
                } label: {
                    HStack {
                        Image(systemName: "star")
                            .foregroundColor(.blue)
                        Text("See Plans")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
            }
        } header: {
            Text("Monetization")
        } footer: {
            Text("Local counters only. No data is transmitted.")
        }
        .sheet(isPresented: $showingPricing) {
            PricingView()
        }
    }
    
    private var tierIcon: String {
        switch EntitlementManager.shared.currentTier {
        case .free: return "person.circle"
        case .pro: return "star.circle"
        case .team: return "person.3.fill"
        }
    }
    
    private var tierColor: Color {
        switch EntitlementManager.shared.currentTier {
        case .free: return .gray
        case .pro: return .blue
        case .team: return .orange
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section {
            Button {
                exportDiagnostics()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                    Text("Export Diagnostics")
                    Spacer()
                }
            }
        } footer: {
            Text("Exports a JSON file with diagnostic information. No user content is included.")
        }
    }
    
    // MARK: - Actions
    
    private func loadDiagnostics() {
        isLoading = true
        
        // Capture snapshots
        executionSnapshot = appState.currentExecutionDiagnostics()
        usageSnapshot = appState.currentUsageDiagnostics()
        
        isLoading = false
    }
    
    private func exportDiagnostics() {
        let builder = DiagnosticsExportBuilder()
        let packet = builder.buildPacket()
        
        do {
            let url = try packet.exportToFile()
            exportURL = url
            showingShareSheet = true
        } catch {
            showingExportError = true
        }
    }
    
    // MARK: - Helpers
    
    private func outcomeColor(_ outcome: ExecutionOutcome) -> Color {
        switch outcome.colorName {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        default: return .gray
        }
    }
}

// MARK: - Diagnostics Row

private struct DiagnosticsRow: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Guarantee Row

private struct GuaranteeRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let status: Status
    
    enum Status {
        case active
        case inactive
        
        var color: Color {
            switch self {
            case .active: return .green
            case .inactive: return .gray
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(status.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(status.color)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle). Active.")
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    DiagnosticsView()
        .environmentObject(AppState())
}
