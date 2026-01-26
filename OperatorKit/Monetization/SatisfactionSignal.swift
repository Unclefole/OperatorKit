import Foundation

// ============================================================================
// SATISFACTION SIGNAL (Phase 10N)
//
// Local-only post-purchase satisfaction tracking.
// Aggregates only, no free text.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No free text storage
// ❌ No user identifiers
// ❌ No networking
// ❌ No background prompts
// ✅ Counts + averages only
// ✅ Skippable
// ✅ Foreground UI only
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Satisfaction Question

public struct SatisfactionQuestion: Identifiable, Codable {
    public let id: String
    public let questionText: String
    public let minLabel: String
    public let maxLabel: String
    
    public init(id: String, questionText: String, minLabel: String, maxLabel: String) {
        self.id = id
        self.questionText = questionText
        self.minLabel = minLabel
        self.maxLabel = maxLabel
    }
}

// MARK: - Satisfaction Questions

public enum SatisfactionQuestions {
    
    /// Schema version
    public static let schemaVersion = 1
    
    /// The 3 satisfaction questions
    public static let questions: [SatisfactionQuestion] = [
        SatisfactionQuestion(
            id: "ease-of-use",
            questionText: "How easy was it to get started?",
            minLabel: "Very difficult",
            maxLabel: "Very easy"
        ),
        SatisfactionQuestion(
            id: "value-clarity",
            questionText: "How clear is the value you're getting?",
            minLabel: "Not clear",
            maxLabel: "Very clear"
        ),
        SatisfactionQuestion(
            id: "recommend",
            questionText: "How likely are you to recommend?",
            minLabel: "Not likely",
            maxLabel: "Very likely"
        )
    ]
}

// MARK: - Satisfaction Response

public struct SatisfactionResponse: Codable {
    public let questionId: String
    public let rating: Int  // 1-5
    public let respondedAt: Date
    
    public init(questionId: String, rating: Int, respondedAt: Date = Date()) {
        self.questionId = questionId
        self.rating = min(5, max(1, rating))
        self.respondedAt = respondedAt
    }
}

// MARK: - Satisfaction Summary

public struct SatisfactionSummary: Codable {
    /// Total responses collected
    public let totalResponses: Int
    
    /// Average rating per question (ID -> average)
    public let averageByQuestion: [String: Double]
    
    /// Overall average rating
    public let overallAverage: Double
    
    /// Response counts per question
    public let countByQuestion: [String: Int]
    
    /// Schema version
    public let schemaVersion: Int
    
    /// When summary was captured
    public let capturedAt: String
    
    public static let currentSchemaVersion = 1
}

// MARK: - Satisfaction Signal Store

@MainActor
public final class SatisfactionSignalStore: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = SatisfactionSignalStore()
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let responsesKey = "com.operatorkit.satisfaction.responses"
    private let promptShownKey = "com.operatorkit.satisfaction.prompt_shown"
    private let schemaVersionKey = "com.operatorkit.satisfaction.schema_version"
    
    // MARK: - State
    
    @Published public private(set) var responses: [SatisfactionResponse]
    @Published public private(set) var hasShownPrompt: Bool
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasShownPrompt = defaults.bool(forKey: promptShownKey)
        
        if let data = defaults.data(forKey: responsesKey),
           let saved = try? JSONDecoder().decode([SatisfactionResponse].self, from: data) {
            self.responses = saved
        } else {
            self.responses = []
        }
    }
    
    // MARK: - Recording
    
    /// Records a satisfaction response
    public func recordResponse(questionId: String, rating: Int) {
        let response = SatisfactionResponse(questionId: questionId, rating: rating)
        responses.append(response)
        saveResponses()
        
        logDebug("Satisfaction response recorded: \(questionId) = \(rating)", category: .monetization)
    }
    
    /// Records all responses at once
    public func recordResponses(_ newResponses: [SatisfactionResponse]) {
        responses.append(contentsOf: newResponses)
        saveResponses()
    }
    
    /// Marks prompt as shown
    public func markPromptShown() {
        hasShownPrompt = true
        defaults.set(true, forKey: promptShownKey)
    }
    
    // MARK: - Summary
    
    /// Gets current summary (aggregates only)
    public func currentSummary() -> SatisfactionSummary {
        var countByQuestion: [String: Int] = [:]
        var sumByQuestion: [String: Int] = [:]
        
        for response in responses {
            countByQuestion[response.questionId, default: 0] += 1
            sumByQuestion[response.questionId, default: 0] += response.rating
        }
        
        var averageByQuestion: [String: Double] = [:]
        for (questionId, count) in countByQuestion {
            if count > 0 {
                averageByQuestion[questionId] = Double(sumByQuestion[questionId] ?? 0) / Double(count)
            }
        }
        
        let totalSum = responses.reduce(0) { $0 + $1.rating }
        let overallAverage = responses.isEmpty ? 0 : Double(totalSum) / Double(responses.count)
        
        return SatisfactionSummary(
            totalResponses: responses.count,
            averageByQuestion: averageByQuestion,
            overallAverage: overallAverage,
            countByQuestion: countByQuestion,
            schemaVersion: SatisfactionSummary.currentSchemaVersion,
            capturedAt: dayRoundedDate()
        )
    }
    
    /// Whether we should show the satisfaction prompt
    /// Only triggers on foreground UI flows, not background
    public func shouldShowPrompt(playbookCompleted: Bool, successfulExecutions: Int) -> Bool {
        guard !hasShownPrompt else { return false }
        
        // Show after playbook completion OR after 3 successful executions
        return playbookCompleted || successfulExecutions >= 3
    }
    
    // MARK: - Reset
    
    /// Resets all satisfaction data (for testing)
    public func reset() {
        responses = []
        hasShownPrompt = false
        defaults.removeObject(forKey: responsesKey)
        defaults.removeObject(forKey: promptShownKey)
    }
    
    // MARK: - Private
    
    private func saveResponses() {
        if let data = try? JSONEncoder().encode(responses) {
            defaults.set(data, forKey: responsesKey)
        }
        defaults.set(SatisfactionSummary.currentSchemaVersion, forKey: schemaVersionKey)
    }
    
    private func dayRoundedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}

// MARK: - Forbidden Keys Validation

extension SatisfactionSummary {
    
    /// Forbidden keys that must never appear in exports
    public static let forbiddenKeys: [String] = [
        "body", "subject", "content", "draft", "prompt",
        "context", "note", "email", "attendees", "title",
        "description", "message", "text", "recipient", "sender",
        "freeText", "comment", "feedback"
    ]
    
    /// Validates summary contains no forbidden keys
    public func validateNoForbiddenKeys() throws -> [String] {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(self)
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }
        
        return Self.findForbiddenKeys(in: json, path: "")
    }
    
    private static func findForbiddenKeys(in dict: [String: Any], path: String) -> [String] {
        var violations: [String] = []
        
        for (key, value) in dict {
            let fullPath = path.isEmpty ? key : "\(path).\(key)"
            
            if forbiddenKeys.contains(key.lowercased()) {
                violations.append("Forbidden key: \(fullPath)")
            }
            
            if let nested = value as? [String: Any] {
                violations.append(contentsOf: findForbiddenKeys(in: nested, path: fullPath))
            }
        }
        
        return violations
    }
}
