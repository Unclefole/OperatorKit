import SwiftUI

// ============================================================================
// SUPPORT EXPORT VIEW (Phase 10Q)
//
// Export support packet for escalation.
// Metadata only. User-initiated via ShareSheet.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No auto-export
// ✅ Metadata only
// ✅ User-initiated
// ✅ ShareSheet export
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct SupportExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var packet: SupportPacket?
    @State private var isLoading = true
    
    @State private var showingExport = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    
    var body: some View {
        NavigationView {
            List {
                // Preview Section
                if isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Building support packet...")
                                .foregroundColor(.secondary)
                        }
                    }
                } else if let packet = packet {
                    // App Info
                    Section {
                        InfoRow(label: "App Version", value: packet.appVersion)
                        InfoRow(label: "Build", value: packet.buildNumber)
                        InfoRow(label: "Release Mode", value: packet.releaseMode)
                        InfoRow(label: "iOS Version", value: packet.iosVersion)
                    } header: {
                        Text("App Info")
                    }
                    
                    // Account State
                    Section {
                        InfoRow(label: "Tier", value: packet.currentTier)
                        InfoRow(label: "Active Trial", value: packet.hasActiveTrial ? "Yes" : "No")
                        InfoRow(label: "First Week", value: packet.isFirstWeek ? "Yes" : "No")
                        InfoRow(label: "Days Since Install", value: "\(packet.daysSinceInstall)")
                    } header: {
                        Text("Account State")
                    }
                    
                    // Quality State
                    Section {
                        InfoRow(label: "Quality Gate", value: packet.qualityGateStatus)
                        if let coverage = packet.coverageScore {
                            InfoRow(label: "Coverage", value: "\(coverage)%")
                        }
                        InfoRow(label: "Invariants", value: packet.invariantsPassing ? "Passing" : "Failing")
                    } header: {
                        Text("Quality")
                    }
                    
                    // Audit Summary
                    Section {
                        InfoRow(label: "Total Events", value: "\(packet.auditEventCount)")
                        InfoRow(label: "Last 7 Days", value: "\(packet.auditEventsLast7Days)")
                    } header: {
                        Text("Audit Trail")
                    }
                    
                    // Diagnostics Summary
                    Section {
                        InfoRow(label: "Total Executions", value: "\(packet.totalExecutions)")
                        InfoRow(label: "Successes", value: "\(packet.successCount)")
                        InfoRow(label: "Failures", value: "\(packet.failureCount)")
                    } header: {
                        Text("Diagnostics")
                    }
                }
                
                // Export Section
                Section {
                    Button {
                        exportPacket()
                    } label: {
                        Label("Export Support Packet", systemImage: "square.and.arrow.up")
                    }
                    .disabled(packet == nil)
                } header: {
                    Text("Export")
                } footer: {
                    Text("This export contains metadata only. No drafts, emails, or user content is included.")
                }
            }
            .navigationTitle("Support Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await buildPacket()
            }
            .sheet(isPresented: $showingExport) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Export Error", isPresented: .constant(exportError != nil)) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
    }
    
    // MARK: - Actions
    
    private func buildPacket() async {
        isLoading = true
        
        let builder = await SupportPacketBuilder.shared
        packet = await builder.build()
        
        isLoading = false
    }
    
    private func exportPacket() {
        guard let packet = packet else { return }
        
        Task { @MainActor in
            do {
                let jsonData = try packet.toJSONData()
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(packet.filename)
                try jsonData.write(to: tempURL)
                
                exportURL = tempURL
                showingExport = true
            } catch {
                exportError = error.localizedDescription
            }
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    SupportExportView()
}
