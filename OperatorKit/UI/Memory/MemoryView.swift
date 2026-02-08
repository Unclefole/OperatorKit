import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct MemoryView: View {
    /// When true, this view is the root of a tab (not pushed via Route).
    /// Back button hides; Home button switches to the Home tab.
    var isTabRoot: Bool = false

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState
    @StateObject private var memoryStore = MemoryStore.shared
    @State private var searchText: String = ""
    @State private var selectedFilter: FilterOption = .all
    @State private var selectedItem: PersistedMemoryItem?
    @State private var showingDetail: Bool = false
    @State private var showingDeleteConfirmation: Bool = false
    @State private var itemToDelete: PersistedMemoryItem?
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case recent = "Recent"
        case drafts = "Drafts"
        case sent = "Sent"
    }
    
    private var filteredItems: [PersistedMemoryItem] {
        var items = memoryStore.items
        
        // Apply search
        if !searchText.isEmpty {
            items = memoryStore.search(query: searchText)
        }
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .recent:
            items = Array(items.prefix(5))
        case .drafts:
            items = items.filter { $0.type == .draftedEmail || $0.type == .summary || $0.type == .actionItems }
        case .sent:
            items = items.filter { $0.type == .sentEmail }
        }
        
        return items
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Search Bar
                searchBar
                
                // Filter Tabs
                filterTabs
                
                // Memory List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredItems, id: \.id) { item in
                            MemoryItemRow(item: item, onTap: {
                                selectedItem = item
                                showingDetail = true
                            }, onDelete: {
                                itemToDelete = item
                                showingDeleteConfirmation = true
                            })
                        }
                        
                        if filteredItems.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingDetail) {
            if let item = selectedItem {
                MemoryDetailView(item: item)
            }
        }
        .alert("Delete Item", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    memoryStore.remove(item)
                }
                itemToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this item? This action cannot be undone.")
        }
    }
    
    // MARK: - Header
    // ARCHITECTURE: Context-aware navigation header.
    // When isTabRoot == true  → back button hidden (nothing to pop), home switches tab.
    // When isTabRoot == false → pushed via Route, back pops, home resets path.
    private var headerView: some View {
        HStack {
            if isTabRoot {
                // Tab root: no back destination — use invisible spacer to keep layout balanced
                Color.clear
                    .frame(width: 24, height: 24)
            } else {
                Button(action: { nav.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            OperatorKitLogoView(size: .small, showText: false)

            Spacer()

            Button(action: {
                if isTabRoot {
                    nav.goHomeTab()
                } else {
                    nav.goHome()
                }
            }) {
                Image(systemName: "house")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            TextField("Search memory...", text: $searchText)
                .font(.body)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    // MARK: - Filter Tabs
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    Button(action: {
                        selectedFilter = option
                    }) {
                        Text(option.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedFilter == option ? .semibold : .regular)
                            .foregroundColor(selectedFilter == option ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedFilter == option ? Color.blue : Color.white)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))

            Text("No items found")
                .font(.headline)
                .foregroundColor(.gray)

            Text("Your drafts and completed operations will appear here.\nAll data is stored securely on your device.")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
                .multilineTextAlignment(.center)

            // CTA — route user to create their first request
            Button(action: {
                nav.goHome()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Create a new request")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(OKColors.intelligenceStart)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(OKColors.intelligenceStart.opacity(0.08))
                )
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Memory Item Row
struct MemoryItemRow: View {
    let item: PersistedMemoryItem
    let onTap: () -> Void
    let onDelete: () -> Void
    
    private var icon: String {
        switch item.type {
        case .draftedEmail: return "envelope.badge.fill"
        case .sentEmail: return "envelope.fill"
        case .summary: return "doc.text.fill"
        case .actionItems: return "checkmark.square.fill"
        case .reminder, .createdReminder: return "bell.fill"
        case .documentReview: return "doc.text.magnifyingglass"
        case .calendarEvent, .createdCalendarEvent, .updatedCalendarEvent: return "calendar"
        }
    }
    
    private var iconColor: Color {
        switch item.type {
        case .draftedEmail, .sentEmail: return .blue
        case .summary, .documentReview: return .orange
        case .actionItems: return .green
        case .reminder, .createdReminder: return .purple
        case .calendarEvent, .createdCalendarEvent, .updatedCalendarEvent: return .red
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(item.preview)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(item.type.rawValue)
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text(item.formattedDate)
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        // Confidence indicator
                        if let confidence = item.draftConfidence {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("\(Int(confidence * 100))%")
                                .font(.caption2)
                                .foregroundColor(confidence >= 0.8 ? .green : .orange)
                        }
                    }
                }
                
                Spacer()
                
                // Attachments indicator
                if !item.attachments.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 12))
                        Text("\(item.attachments.count)")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Memory Detail View
struct MemoryDetailView: View {
    let item: PersistedMemoryItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.type.rawValue)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(item.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(item.formattedDate)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Divider()
                    
                    // Trust Summary Section (Phase 5A)
                    trustSummarySection
                    
                    // Audit Trail Section
                    if item.intentSummary != nil || item.contextSummary != nil {
                        auditTrailSection
                    }
                    
                    // Draft Content
                    if item.draftBody != nil {
                        draftContentSection
                    }
                    
                    // Execution Details
                    if item.executionStatus != nil {
                        executionSection
                    }
                    
                    // Side Effects
                    if !item.executedSideEffects.isEmpty {
                        sideEffectsSection
                    }
                    
                    // Reminder Write Info (Phase 3B)
                    if item.reminderWasCreated {
                        reminderWriteSection
                    }
                    
                    // Calendar Write Info (Phase 3C)
                    if item.calendarWasWritten {
                        calendarWriteSection
                    }
                    
                    // Attachments
                    if !item.attachments.isEmpty {
                        attachmentsSection
                    }
                    
                    // Quality Feedback Section (Phase 8A)
                    feedbackSection
                    
                    // Golden Case Section (Phase 8B)
                    goldenCaseSection
                }
                .padding(20)
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPinDisclosure) {
                PinAsGoldenCaseSheet(item: item, onPin: {
                    showPinDisclosure = false
                })
            }
        }
    }
    
    // MARK: - Golden Case Section (Phase 8B)
    
    @StateObject private var goldenCaseStore = GoldenCaseStore.shared
    @State private var showPinDisclosure = false
    
    private var goldenCaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            Label("Quality Evaluation", systemImage: "star.square")
                .font(.headline)
                .foregroundColor(.purple)
            
            if goldenCaseStore.isPinned(memoryItemId: item.id) {
                // Already pinned
                if let goldenCase = goldenCaseStore.getCase(forMemoryItemId: item.id) {
                    pinnedGoldenCaseCard(goldenCase)
                }
            } else {
                // Not pinned - show pin button
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pin this as a Golden Case to use for local quality evaluation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        showPinDisclosure = true
                    } label: {
                        HStack {
                            Image(systemName: "pin")
                            Text("Pin as Golden Case")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(8)
                    }
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(10)
            }
        }
    }
    
    private func pinnedGoldenCaseCard(_ goldenCase: GoldenCase) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "pin.fill")
                    .foregroundColor(.purple)
                Text("Pinned as Golden Case")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            Text(goldenCase.title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Pinned \(goldenCase.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Button(role: .destructive) {
                _ = goldenCaseStore.deleteCase(id: goldenCase.id)
            } label: {
                HStack {
                    Image(systemName: "pin.slash")
                    Text("Remove Pin")
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Feedback Section (Phase 8A)
    
    @StateObject private var feedbackStore = QualityFeedbackStore.shared
    
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            Label("Your Feedback", systemImage: "star.bubble")
                .font(.headline)
                .foregroundColor(.blue)
            
            if let existingFeedback = feedbackStore.getFeedback(for: item.id) {
                // Show existing feedback
                existingFeedbackCard(existingFeedback)
            } else {
                // Show feedback entry
                FeedbackEntryView(
                    memoryItemId: item.id,
                    modelBackend: item.modelBackendUsed,
                    confidence: item.confidenceAtDraft,
                    usedFallback: item.usedFallback,
                    timeoutOccurred: item.timeoutOccurred,
                    validationPass: item.validationPass,
                    citationValidityPass: item.citationValidityPass
                )
            }
        }
    }
    
    private func existingFeedbackCard(_ feedback: QualityFeedbackEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Rating
            HStack {
                Image(systemName: feedback.rating.systemImage)
                    .foregroundColor(feedback.rating == .helpful ? .green : .orange)
                Text("You rated this: \(feedback.rating.displayName)")
                    .font(.subheadline)
                Spacer()
            }
            
            // Tags
            if !feedback.issueTags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(feedback.issueTags, id: \.self) { tag in
                        Text(tag.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(12)
                    }
                }
            }
            
            // Date
            Text("Submitted \(feedback.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Delete button
            Button(role: .destructive) {
                _ = feedbackStore.deleteFeedback(id: feedback.id)
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Feedback")
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
    
    // MARK: - Trust Summary Section (Phase 5A)
    private var trustSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Trust Summary", systemImage: "shield.checkered")
                .font(.headline)
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                // Draft-first indicator
                TrustSummaryRow(
                    label: "Draft-first",
                    isConfirmed: true,
                    confirmedText: "Yes",
                    notConfirmedText: "No"
                )
                
                // User approved indicator
                TrustSummaryRow(
                    label: "User approved",
                    isConfirmed: item.approvalTimestamp != nil,
                    confirmedText: "Yes",
                    notConfirmedText: "Pending"
                )
                
                // Write confirmed indicator
                let wasWriteConfirmed = item.reminderWasCreated || item.calendarWasWritten
                TrustSummaryRow(
                    label: "Write confirmed",
                    isConfirmed: wasWriteConfirmed,
                    confirmedText: "Yes",
                    notConfirmedText: "N/A"
                )
                
                // On-device only indicator
                TrustSummaryRow(
                    label: "On-device only",
                    isConfirmed: true,
                    confirmedText: "Yes",
                    notConfirmedText: "No"
                )
                
                // Fallback indicator
                TrustSummaryRow(
                    label: "Fallback used",
                    isConfirmed: !item.usedFallback,
                    confirmedText: "No",
                    notConfirmedText: "Yes"
                )
                
                // Confidence level
                if let confidence = item.confidenceAtDraft {
                    HStack {
                        Text("Confidence level")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(confidenceLevelText(confidence))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(confidenceColor(confidence))
                    }
                }
                
                // Model backend
                if let backend = item.modelBackendUsed {
                    HStack {
                        Text("Model used")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(backend)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color.green.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private func confidenceLevelText(_ confidence: Double) -> String {
        if confidence >= 0.65 { return "High confidence" }
        if confidence >= 0.35 { return "Needs review" }
        return "Insufficient"
    }
    
    // MARK: - Audit Trail Section
    private var auditTrailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Audit Trail", systemImage: "clock.badge.checkmark")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                if let intent = item.intentSummary {
                    AuditRow(label: "Request", value: intent)
                }
                
                if let context = item.contextSummary {
                    AuditRow(label: "Context", value: context)
                }
                
                if let approvalTime = item.approvalTimestamp {
                    AuditRow(label: "Approved", value: formatDate(approvalTime))
                }
                
                if let execTime = item.executionTimestamp {
                    AuditRow(label: "Executed", value: formatDate(execTime))
                }
            }
            .padding(16)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            
            // Model & Confidence Section (Phase 2C)
            if item.modelBackendUsed != nil || item.confidenceAtDraft != nil || item.citationsCount != nil {
                modelMetadataSection
            }
        }
    }
    
    // MARK: - Model Metadata Section (Phase 2C + Phase 4A)
    private var modelMetadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Draft Intelligence", systemImage: "cpu")
                .font(.headline)
                .foregroundColor(.purple)
            
            VStack(spacing: 8) {
                // Model backend
                if let backend = item.modelBackendUsed {
                    AuditRow(label: "Model", value: backend)
                }
                
                // Model ID and Version (Phase 4A)
                if let modelId = item.modelId {
                    AuditRow(label: "Model ID", value: modelId)
                }
                if let modelVersion = item.modelVersion {
                    AuditRow(label: "Version", value: modelVersion)
                }
                
                // Generation latency (Phase 4A)
                if let latencyMs = item.generationLatencyMs, latencyMs > 0 {
                    let latencyText = latencyMs < 1000 ? "\(latencyMs)ms" : String(format: "%.1fs", Double(latencyMs) / 1000.0)
                    AuditRow(label: "Latency", value: latencyText)
                }
                
                // Confidence at draft
                if let confidence = item.confidenceAtDraft {
                    HStack {
                        Text("Confidence:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 4) {
                            Text("\(Int(confidence * 100))%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Image(systemName: confidenceIcon(confidence))
                                .font(.system(size: 12))
                        }
                        .foregroundColor(confidenceColor(confidence))
                        
                        Spacer()
                    }
                }
                
                // Citations count
                if let count = item.citationsCount, count > 0 {
                    AuditRow(label: "Citations", value: "\(count) source\(count == 1 ? "" : "s") used")
                }
                
                // Fallback indicator (Phase 4A) - Non-alarmist
                if item.usedFallback {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("Deterministic fallback used")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    Text("A simpler on-device method was used to ensure reliability.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.leading, 18)
                    
                    if let reason = item.fallbackReason, !reason.isEmpty {
                        Text("Reason: \(reason)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.leading, 18)
                    }
                }
                
                // Safety notes
                if let notes = item.safetyNotesAtDraft, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Safety Notes:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        ForEach(notes, id: \.self) { note in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                                    .padding(.top, 2)
                                
                                Text(note)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.purple.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private func confidenceIcon(_ confidence: Double) -> String {
        if confidence >= 0.85 { return "checkmark.shield.fill" }
        if confidence >= 0.65 { return "shield.fill" }
        if confidence >= 0.35 { return "exclamationmark.shield.fill" }
        return "xmark.shield.fill"
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.85 { return .green }
        if confidence >= 0.65 { return .blue }
        if confidence >= 0.35 { return .orange }
        return .red
    }
    
    // MARK: - Draft Content Section
    private var draftContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Draft Content", systemImage: "doc.text")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                if let recipient = item.draftRecipient {
                    HStack {
                        Text("To:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(recipient)
                            .font(.subheadline)
                    }
                }
                
                if let subject = item.draftSubject {
                    HStack {
                        Text("Subject:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(subject)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                Divider()
                
                if let body = item.draftBody {
                    Text(body)
                        .font(.body)
                }
                
                if let signature = item.draftSignature {
                    Text(signature)
                        .font(.body)
                        .foregroundColor(.gray)
                }
                
                if let confidence = item.draftConfidence {
                    HStack {
                        Text("Confidence:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(Int(confidence * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(confidence >= 0.8 ? .green : .orange)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(16)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Execution Section
    private var executionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Execution Result", systemImage: "checkmark.shield")
                .font(.headline)
            
            HStack(spacing: 12) {
                // Status badge
                if let status = item.executionStatus {
                    Text(statusText(for: status))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor(for: status))
                        .cornerRadius(12)
                }
                
                if let message = item.executionMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    // MARK: - Side Effects Section
    private var sideEffectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Side Effects", systemImage: "bolt.fill")
                .font(.headline)
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                ForEach(item.executedSideEffects) { effect in
                    HStack(spacing: 12) {
                        Image(systemName: effect.wasExecuted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(effect.wasExecuted ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(effect.description)
                                .font(.subheadline)
                            
                            if let message = effect.resultMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Reminder Write Section (Phase 3B)
    private var reminderWriteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Reminder Created", systemImage: "bell.badge.fill")
                .font(.headline)
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                // Confirmation badge
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                    
                    Text("Reminder saved to Reminders app")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                Divider()
                
                // Reminder identifier
                if let identifier = item.reminderIdentifier {
                    AuditRow(label: "Identifier", value: String(identifier.prefix(20)) + "...")
                }
                
                // Confirmation timestamp
                if let confirmedAt = item.formattedReminderWriteConfirmedAt {
                    AuditRow(label: "Confirmed", value: confirmedAt)
                }
                
                // Reminder payload details
                if let payload = item.reminderPayload {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reminder Details:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(payload.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let notes = payload.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        if let dueDate = payload.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                Text(dueDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                        
                        if let priority = payload.priority, priority != .none {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark")
                                    .font(.caption)
                                Text("Priority: \(priority.displayName)")
                                    .font(.caption)
                            }
                            .foregroundColor(priorityColor(priority))
                        }
                    }
                }
                
                // Two-key confirmation note
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 10))
                    Text("Created with two-key confirmation")
                        .font(.caption2)
                }
                .foregroundColor(.purple)
                .padding(.top, 8)
            }
            .padding(16)
            .background(Color.green.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private func priorityColor(_ priority: ReminderPayload.Priority) -> Color {
        switch priority {
        case .none: return .gray
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    // MARK: - Calendar Write Section (Phase 3C)
    private var calendarWriteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                item.calendarOperationRaw == "updated" ? "Calendar Event Updated" : "Calendar Event Created",
                systemImage: item.calendarOperationRaw == "updated" ? "calendar.badge.clock" : "calendar.badge.plus"
            )
            .font(.headline)
            .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                // Confirmation badge
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    Text(item.calendarOperationRaw == "updated" 
                         ? "Calendar event updated in Calendar app" 
                         : "Calendar event saved to Calendar app")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                Divider()
                
                // Calendar event identifier
                if let identifier = item.calendarEventIdentifier {
                    AuditRow(label: "Event ID", value: String(identifier.prefix(20)) + "...")
                }
                
                // Operation type
                if let operation = item.calendarOperationRaw {
                    AuditRow(label: "Operation", value: operation.capitalized)
                }
                
                // Confirmation timestamp
                if let confirmedAt = item.calendarWriteConfirmedAt {
                    AuditRow(label: "Confirmed", value: formatDate(confirmedAt))
                }
                
                // Diff summary (for updates)
                if let diffSummary = item.calendarDiffSummary, !diffSummary.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Changes Made:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(diffSummary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                
                // Two-key confirmation note
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 10))
                    Text("Created with two-key confirmation")
                        .font(.caption2)
                }
                .foregroundColor(.purple)
                .padding(.top, 8)
            }
            .padding(16)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Attachments Section
    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Attachments", systemImage: "paperclip")
                .font(.headline)
            
            ForEach(item.attachments, id: \.self) { attachment in
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.blue)
                    Text(attachment)
                        .font(.subheadline)
                    Spacer()
                }
                .padding(12)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func statusText(for status: PersistedMemoryItem.ExecutionStatus) -> String {
        switch status {
        case .success: return "Success"
        case .partialSuccess: return "Partial"
        case .failed: return "Failed"
        case .savedDraftOnly: return "Draft Saved"
        }
    }
    
    private func statusColor(for status: PersistedMemoryItem.ExecutionStatus) -> Color {
        switch status {
        case .success, .savedDraftOnly: return .green
        case .partialSuccess: return .orange
        case .failed: return .red
        }
    }
}

// MARK: - Audit Row
struct AuditRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 70, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Trust Summary Row (Phase 5A)
struct TrustSummaryRow: View {
    let label: String
    let isConfirmed: Bool
    let confirmedText: String
    let notConfirmedText: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: isConfirmed ? "checkmark.circle.fill" : "minus.circle")
                    .font(.system(size: 14))
                    .foregroundColor(isConfirmed ? .green : .gray)
                
                Text(isConfirmed ? confirmedText : notConfirmedText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isConfirmed ? .green : .gray)
            }
        }
    }
}

#Preview {
    MemoryView()
        .environmentObject(AppState())
}
