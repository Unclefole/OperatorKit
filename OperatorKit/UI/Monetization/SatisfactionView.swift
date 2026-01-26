import SwiftUI

// ============================================================================
// SATISFACTION VIEW (Phase 10N)
//
// Post-purchase satisfaction survey.
// 3 questions, 1-5 rating, always skippable.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No free text collection
// ❌ No auto-prompts
// ❌ No forced completion
// ✅ 1-5 ratings only
// ✅ Always skippable
// ✅ Foreground UI only
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct SatisfactionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var satisfactionStore = SatisfactionSignalStore.shared
    
    @State private var ratings: [String: Int] = [:]
    @State private var currentQuestionIndex = 0
    @State private var showingThankYou = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if showingThankYou {
                    thankYouContent
                } else {
                    questionContent
                }
            }
            .padding()
            .navigationTitle("Quick Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        satisfactionStore.markPromptShown()
                        dismiss()
                    }
                }
            }
            .onAppear {
                satisfactionStore.markPromptShown()
            }
        }
    }
    
    // MARK: - Question Content
    
    private var questionContent: some View {
        VStack(spacing: 32) {
            // Progress
            HStack {
                ForEach(0..<SatisfactionQuestions.questions.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentQuestionIndex ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            Spacer()
            
            // Question
            if let question = currentQuestion {
                VStack(spacing: 20) {
                    Text(question.questionText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    // Rating Selector
                    RatingSelector(
                        rating: ratings[question.id] ?? 0,
                        minLabel: question.minLabel,
                        maxLabel: question.maxLabel,
                        onRatingChanged: { rating in
                            ratings[question.id] = rating
                        }
                    )
                }
            }
            
            Spacer()
            
            // Navigation
            HStack {
                if currentQuestionIndex > 0 {
                    Button {
                        withAnimation {
                            currentQuestionIndex -= 1
                        }
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentQuestionIndex < SatisfactionQuestions.questions.count - 1 {
                    Button {
                        withAnimation {
                            currentQuestionIndex += 1
                        }
                    } label: {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentRating == 0)
                } else {
                    Button {
                        submitResponses()
                    } label: {
                        Text("Submit")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentRating == 0)
                }
            }
            
            // Skip hint
            Text("You can skip anytime")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Thank You Content
    
    private var thankYouContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Thank You!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your feedback helps us improve.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Helpers
    
    private var currentQuestion: SatisfactionQuestion? {
        guard currentQuestionIndex < SatisfactionQuestions.questions.count else { return nil }
        return SatisfactionQuestions.questions[currentQuestionIndex]
    }
    
    private var currentRating: Int {
        guard let question = currentQuestion else { return 0 }
        return ratings[question.id] ?? 0
    }
    
    private func submitResponses() {
        let responses = ratings.map { questionId, rating in
            SatisfactionResponse(questionId: questionId, rating: rating)
        }
        satisfactionStore.recordResponses(responses)
        
        withAnimation {
            showingThankYou = true
        }
    }
}

// MARK: - Rating Selector

private struct RatingSelector: View {
    let rating: Int
    let minLabel: String
    let maxLabel: String
    let onRatingChanged: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        onRatingChanged(value)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(rating >= value ? Color.blue : Color.gray.opacity(0.2))
                                .frame(width: 50, height: 50)
                            
                            Text("\(value)")
                                .font(.headline)
                                .foregroundColor(rating >= value ? .white : .primary)
                        }
                    }
                }
            }
            
            HStack {
                Text(minLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(maxLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Preview

#Preview {
    SatisfactionView()
}
