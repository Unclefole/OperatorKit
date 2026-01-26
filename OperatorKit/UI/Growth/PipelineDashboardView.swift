import SwiftUI

// ============================================================================
// PIPELINE DASHBOARD VIEW (Phase 11B)
//
// Zero-content pipeline tracking UI.
// Stage counts. Minimal controls. No text entry.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No text entry
// ❌ No prospect info display
// ✅ Counts only
// ✅ Stage transitions
// ✅ Export via ShareSheet
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct PipelineDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = PipelineStore.shared
    
    @State private var selectedItem: PipelineItem?
    @State private var showingStageSelector = false
    @State private var showingChannelSelector = false
    @State private var showingExport = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationView {
            List {
                // Overview
                overviewSection
                
                // Stage Counts
                stageCountsSection
                
                // Channel Breakdown
                channelBreakdownSection
                
                // Actions
                actionsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Pipeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingStageSelector) {
                if let item = selectedItem {
                    StageSelectorSheet(item: item) { newStage in
                        store.moveItem(item.id, to: newStage)
                        selectedItem = nil
                    }
                }
            }
            .sheet(isPresented: $showingChannelSelector) {
                ChannelSelectorSheet { channel in
                    _ = store.addItem(channel: channel)
                }
            }
            .sheet(isPresented: $showingExport) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(store.items.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Open")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(store.openItems.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Won")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(store.closedWonItems.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Overview")
        } footer: {
            Text("No prospect names or details stored. Counts only.")
        }
    }
    
    // MARK: - Stage Counts Section
    
    private var stageCountsSection: some View {
        Section {
            ForEach(PipelineStage.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { stage in
                StageRow(
                    stage: stage,
                    count: store.count(at: stage),
                    items: store.items(at: stage)
                ) { item in
                    selectedItem = item
                    showingStageSelector = true
                }
            }
        } header: {
            Text("By Stage")
        }
    }
    
    // MARK: - Channel Breakdown Section
    
    private var channelBreakdownSection: some View {
        Section {
            ForEach(PipelineChannel.allCases, id: \.self) { channel in
                ChannelRow(
                    channel: channel,
                    count: store.count(from: channel)
                )
            }
        } header: {
            Text("By Channel")
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        Section {
            // Add New Opportunity
            Button {
                showingChannelSelector = true
            } label: {
                Label("New Opportunity", systemImage: "plus.circle")
            }
            
            // Export Summary
            Button {
                exportSummary()
            } label: {
                Label("Export Summary", systemImage: "square.and.arrow.up")
            }
            
            // Purge Old Items
            Button(role: .destructive) {
                store.purgeOldItems()
            } label: {
                Label("Purge Items Older Than 90 Days", systemImage: "trash")
            }
        } header: {
            Text("Actions")
        }
    }
    
    // MARK: - Export
    
    private func exportSummary() {
        let summary = store.currentSummary()
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(summary)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let filename = "OperatorKit_Pipeline_\(formatter.string(from: Date())).json"
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)
            
            exportURL = tempURL
            showingExport = true
        } catch {
            logDebug("Pipeline export failed: \(error)", category: .monetization)
        }
    }
}

// MARK: - Stage Row

private struct StageRow: View {
    let stage: PipelineStage
    let count: Int
    let items: [PipelineItem]
    let onItemTap: (PipelineItem) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if items.isEmpty {
                Text("No items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(items) { item in
                    Button {
                        onItemTap(item)
                    } label: {
                        HStack {
                            Image(systemName: item.channel.icon)
                                .foregroundColor(.secondary)
                            
                            Text("Item from \(item.createdAtDayRounded)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: stage.icon)
                    .foregroundColor(stage.isOpen ? .blue : (stage == .closedWon ? .green : .red))
                    .frame(width: 24)
                
                Text(stage.displayName)
                
                Spacer()
                
                Text("\(count)")
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Channel Row

private struct ChannelRow: View {
    let channel: PipelineChannel
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: channel.icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(channel.displayName)
            
            Spacer()
            
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Stage Selector Sheet

private struct StageSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let item: PipelineItem
    let onSelect: (PipelineStage) -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Current: \(item.stage.displayName)")
                        .foregroundColor(.secondary)
                } header: {
                    Text("Move Opportunity")
                }
                
                Section {
                    ForEach(item.stage.nextStages, id: \.self) { stage in
                        Button {
                            onSelect(stage)
                            dismiss()
                        } label: {
                            Label(stage.displayName, systemImage: stage.icon)
                        }
                    }
                } header: {
                    Text("Move To")
                }
                
                if item.stage.nextStages.isEmpty {
                    Section {
                        Text("This opportunity is closed and cannot be moved.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Move Stage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Channel Selector Sheet

private struct ChannelSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let onCreate: (PipelineChannel) -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(PipelineChannel.allCases, id: \.self) { channel in
                        Button {
                            onCreate(channel)
                            dismiss()
                        } label: {
                            Label(channel.displayName, systemImage: channel.icon)
                        }
                    }
                } header: {
                    Text("Select Channel")
                } footer: {
                    Text("Creates a new opportunity at 'Lead Contacted' stage.")
                }
            }
            .navigationTitle("New Opportunity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PipelineDashboardView()
}
