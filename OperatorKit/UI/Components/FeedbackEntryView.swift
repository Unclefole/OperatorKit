import SwiftUI

// ============================================================================
// FEEDBACK ENTRY VIEW (Phase 8A)
//
// User-initiated feedback capture UI.
// INVARIANT: Never shown during Siri routing step
// INVARIANT: Never blocks user flow
// INVARIANT: Must be explicit user tap
// INVARIANT: Must be dismissible
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Compact feedback entry component
struct FeedbackEntryView: View {
    let memoryItemId: UUID
    let modelBackend: String?
    let confidence: Double?
    let usedFallback: Bool
    let timeoutOccurred: Bool
    let validationPass: Bool?
    let citationValidityPass: Bool?
    
    @StateObject private var feedbackStore = QualityFeedbackStore.shared
    @State private var selectedRating: QualityRating?
    @State private var selectedTags: Set<QualityIssueTag> = []
    @State private var noteText: String = ""
    @State private var showTagPicker: Bool = false
    @State private var feedbackSubmitted: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    private var existingFeedback: QualityFeedbackEntry? {
        feedbackStore.getFeedback(for: memoryItemId)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "star.bubble")
                    .foregroundColor(.secondary)
                Text("Rate This Draft")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                
                if existingFeedback != nil || feedbackSubmitted {
                    Text("Feedback saved")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            if existingFeedback != nil || feedbackSubmitted {
                // Show existing feedback summary
                existingFeedbackView
            } else {
                // Show rating buttons
                ratingButtons
                
                // Show tag picker if not helpful or mixed
                if showTagPicker {
                    tagPickerView
                    noteInputView
                    submitButton
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
    
    // MARK: - Rating Buttons
    
    private var ratingButtons: some View {
        HStack(spacing: 12) {
            ForEach(QualityRating.allCases, id: \.self) { rating in
                Button {
                    selectedRating = rating
                    if rating == .helpful {
                        submitFeedback()
                    } else {
                        showTagPicker = true
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: rating.systemImage)
                            .font(.title2)
                        Text(rating.displayName)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedRating == rating 
                            ? Color.blue.opacity(0.2) 
                            : Color(UIColor.tertiarySystemGroupedBackground)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Tag Picker
    
    private var tagPickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What could be better?")
                .font(.caption)
                .foregroundColor(.secondary)
            
            FeedbackFlowLayout(spacing: 8) {
                ForEach(QualityIssueTag.allCases) { tag in
                    Button {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    } label: {
                        Text(tag.displayName)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                selectedTags.contains(tag)
                                    ? Color.blue.opacity(0.2)
                                    : Color(UIColor.tertiarySystemGroupedBackground)
                            )
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Note Input
    
    private var noteInputView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Additional notes (optional)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("Brief feedback...", text: $noteText)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onChange(of: noteText) { _, newValue in
                    if newValue.count > QualityFeedbackEntry.maxNoteLength {
                        noteText = String(newValue.prefix(QualityFeedbackEntry.maxNoteLength))
                    }
                }
            
            Text("\(noteText.count)/\(QualityFeedbackEntry.maxNoteLength)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        Button {
            submitFeedback()
        } label: {
            Text("Submit Feedback")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .disabled(selectedRating == nil)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Existing Feedback View
    
    private var existingFeedbackView: some View {
        HStack {
            if let feedback = existingFeedback {
                Image(systemName: feedback.rating.systemImage)
                    .foregroundColor(feedback.rating == .helpful ? .green : .orange)
                Text("You rated this: \(feedback.rating.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if feedbackSubmitted {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
                Text("Thank you for your feedback")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Submit Logic
    
    private func submitFeedback() {
        guard let rating = selectedRating else { return }
        
        let entry = feedbackStore.createFeedbackEntry(
            for: memoryItemId,
            rating: rating,
            issueTags: Array(selectedTags),
            optionalNote: noteText.isEmpty ? nil : noteText,
            modelBackend: modelBackend,
            confidence: confidence,
            usedFallback: usedFallback,
            timeoutOccurred: timeoutOccurred,
            validationPass: validationPass,
            citationValidityPass: citationValidityPass
        )
        
        let result = feedbackStore.addFeedback(entry)
        
        switch result {
        case .success:
            feedbackSubmitted = true
            showTagPicker = false
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Flow Layout Helper

/// Simple flow layout for tag chips
private struct FeedbackFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.origin.x, y: bounds.minY + frame.origin.y), proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), frames)
    }
}
