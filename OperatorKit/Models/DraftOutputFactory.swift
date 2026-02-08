import Foundation

/// Factory for creating normalized DraftOutput from model generation
/// INVARIANT: Citations must originate ONLY from ContextPacket
/// INVARIANT: Safety notes ALWAYS include "Review before sending"
/// INVARIANT: If output violates contracts, downgrade confidence and potentially use fallback
final class DraftOutputFactory {
    
    // MARK: - Constants
    
    private static let requiredSafetyNote = "You must review this draft before sending."
    private static let emailRecipientWarning = "Recipients not verified until you confirm."
    
    // MARK: - Factory Methods
    
    /// Create DraftOutput from raw model output
    /// Merges model text with:
    /// - Citations from CitationBuilder (context-derived only)
    /// - Action items (rule-based extraction)
    /// - Safety notes (always required)
    static func create(
        from rawOutput: RawModelOutput,
        input: ModelInput,
        backend: ModelBackend
    ) -> DraftOutputResult {
        
        var confidence = rawOutput.rawConfidence ?? calculateBaseConfidence(input: input)
        var warnings: [String] = []
        
        // 1. Process citations
        let citationResult = processCitations(
            rawOutput: rawOutput,
            context: input.contextItems,
            outputText: rawOutput.text
        )
        
        if citationResult.shouldDowngradeConfidence {
            confidence *= 0.8  // 20% penalty for citation issues
            warnings.append("Citation mapping incomplete - confidence reduced")
        }
        
        let finalText = citationResult.cleanedText
        let citations = citationResult.citations
        
        // 2. Extract action items
        let actionItems = extractActionItems(
            from: finalText,
            suggestedItems: rawOutput.suggestedActionItems
        )
        
        // 3. Build safety notes (ALWAYS include review warning)
        let safetyNotes = buildSafetyNotes(
            for: input.outputType,
            existingWarnings: warnings
        )
        
        // 4. Determine subject
        let subject = extractSubject(from: finalText, outputType: input.outputType, input: input)
        
        // 5. Validate output format
        let validationResult = validateOutputFormat(
            text: finalText,
            outputType: input.outputType,
            backend: backend
        )
        
        if !validationResult.isValid {
            confidence *= 0.7  // 30% penalty for format violations
            warnings.append(contentsOf: validationResult.issues)
        }
        
        // 6. Apply confidence bounds
        confidence = min(1.0, max(0.0, confidence))
        
        // 7. Create DraftOutput
        let draftOutput = DraftOutput(
            draftBody: finalText,
            subject: subject,
            actionItems: actionItems,
            confidence: confidence,
            citations: citations,
            safetyNotes: safetyNotes,
            outputType: input.outputType
        )
        
        return DraftOutputResult(
            output: draftOutput,
            warnings: warnings,
            requiresFallback: confidence < DraftOutput.minimumExecutionConfidence
        )
    }
    
    /// Create DraftOutput directly from deterministic template (no normalization needed)
    static func createFromTemplate(
        body: String,
        subject: String?,
        actionItems: [String],
        confidence: Double,
        input: ModelInput
    ) -> DraftOutput {
        // Build citations from context
        let citations = CitationBuilder.buildFromContext(
            input.contextItems,
            relevantToText: body
        )
        
        // Build safety notes
        let safetyNotes = buildSafetyNotes(for: input.outputType)
        
        return DraftOutput(
            draftBody: body,
            subject: subject,
            actionItems: actionItems,
            confidence: confidence,
            citations: citations,
            safetyNotes: safetyNotes,
            outputType: input.outputType
        )
    }
    
    // MARK: - Citation Processing
    
    private struct CitationProcessingResult {
        let citations: [Citation]
        let cleanedText: String
        let shouldDowngradeConfidence: Bool
    }
    
    private static func processCitations(
        rawOutput: RawModelOutput,
        context: ModelInput.ContextItems,
        outputText: String
    ) -> CitationProcessingResult {
        
        // If model provided inline markers, try to map them
        if let markers = rawOutput.inlineCitationMarkers, !markers.isEmpty {
            let mappingResult = CitationBuilder.mapInlineCitations(
                markers: markers,
                context: context,
                outputText: outputText
            )
            
            // If mapping failed significantly, strip markers and rebuild from context
            if mappingResult.shouldDowngrade {
                let cleanedText = CitationBuilder.stripCitationMarkers(from: outputText)
                let freshCitations = CitationBuilder.buildFromContext(context, relevantToText: cleanedText)
                
                return CitationProcessingResult(
                    citations: freshCitations,
                    cleanedText: cleanedText,
                    shouldDowngradeConfidence: true
                )
            }
            
            return CitationProcessingResult(
                citations: mappingResult.citations,
                cleanedText: outputText,
                shouldDowngradeConfidence: false
            )
        }
        
        // No inline markers - build citations from context analysis
        let citations = CitationBuilder.buildFromContext(context, relevantToText: outputText)
        
        return CitationProcessingResult(
            citations: citations,
            cleanedText: outputText,
            shouldDowngradeConfidence: false
        )
    }
    
    // MARK: - Action Item Extraction
    
    private static func extractActionItems(
        from text: String,
        suggestedItems: [String]?
    ) -> [String] {
        var items: [String] = []
        
        // Use model suggestions if available
        if let suggested = suggestedItems, !suggested.isEmpty {
            items.append(contentsOf: suggested)
        }
        
        // Rule-based extraction as supplement/fallback
        let ruleBasedItems = extractActionItemsRuleBased(from: text)
        
        // Merge, avoiding duplicates
        for item in ruleBasedItems {
            let isDuplicate = items.contains { existing in
                existing.lowercased().contains(item.lowercased()) ||
                item.lowercased().contains(existing.lowercased())
            }
            if !isDuplicate {
                items.append(item)
            }
        }
        
        return Array(items.prefix(10))  // Cap at 10 items
    }
    
    private static func extractActionItemsRuleBased(from text: String) -> [String] {
        var items: [String] = []
        let lines = text.components(separatedBy: .newlines)
        
        // Pattern 1: Lines starting with action verbs
        let actionVerbs = ["follow up", "schedule", "send", "review", "prepare", "confirm", "update", "create", "complete", "share"]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
            
            // Check for bullet points or numbered items with action verbs
            if (trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") ||
                trimmed.first?.isNumber == true) {
                let content = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                
                for verb in actionVerbs {
                    if content.hasPrefix(verb) || content.contains("need to") || content.contains("should") {
                        items.append(String(line.trimmingCharacters(in: .whitespaces).dropFirst()).trimmingCharacters(in: .whitespaces))
                        break
                    }
                }
            }
        }
        
        // Pattern 2: Sentences with action indicators
        let actionIndicators = ["action required", "todo:", "action:", "next step", "follow-up"]
        for indicator in actionIndicators {
            if let range = text.lowercased().range(of: indicator) {
                let startIndex = text.index(range.upperBound, offsetBy: 0, limitedBy: text.endIndex) ?? text.endIndex
                let endIndex = text[startIndex...].firstIndex(of: ".") ?? text[startIndex...].firstIndex(of: "\n") ?? text.endIndex
                let item = String(text[startIndex..<endIndex]).trimmingCharacters(in: .whitespaces)
                if !item.isEmpty && item.count < 200 {
                    items.append(item)
                }
            }
        }
        
        return items
    }
    
    // MARK: - Safety Notes
    
    private static func buildSafetyNotes(
        for outputType: DraftOutput.OutputType,
        existingWarnings: [String] = []
    ) -> [String] {
        var notes: [String] = []
        
        // INVARIANT: Always include review warning
        notes.append(requiredSafetyNote)
        
        // Output-type specific warnings
        switch outputType {
        case .emailDraft:
            notes.append(emailRecipientWarning)
        case .meetingSummary:
            notes.append("Meeting details should be verified against your calendar.")
        case .documentSummary:
            notes.append("Summary may not capture all document details.")
        case .taskList:
            notes.append("Task priorities and deadlines need your confirmation.")
        case .reminder:
            notes.append("Reminder timing should be reviewed before saving.")
        }
        
        // Add any process warnings
        notes.append(contentsOf: existingWarnings)
        
        return notes
    }
    
    // MARK: - Subject Extraction
    
    private static func extractSubject(
        from text: String,
        outputType: DraftOutput.OutputType,
        input: ModelInput
    ) -> String? {
        switch outputType {
        case .emailDraft:
            // Try to extract from first line if it looks like a subject
            let lines = text.components(separatedBy: .newlines)
            if let firstLine = lines.first,
               firstLine.lowercased().hasPrefix("subject:") {
                return String(firstLine.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            }
            
            // Generate from intent
            return "Re: \(input.intentText.prefix(50))"
            
        case .meetingSummary:
            // Use meeting title from context if available
            if let meeting = input.contextItems.calendarItems.first {
                return "Summary: \(meeting.title)"
            }
            return "Meeting Summary"
            
        case .documentSummary:
            if let file = input.contextItems.fileItems.first {
                return "Summary: \(file.name)"
            }
            return "Document Summary"
            
        case .taskList:
            return "Action Items"
            
        case .reminder:
            if let meeting = input.contextItems.calendarItems.first {
                return "Reminder: \(meeting.title)"
            }
            return "Reminder"
        }
    }
    
    // MARK: - Output Validation
    
    private struct ValidationResult {
        let isValid: Bool
        let issues: [String]
    }
    
    private static func validateOutputFormat(
        text: String,
        outputType: DraftOutput.OutputType,
        backend: ModelBackend
    ) -> ValidationResult {
        var issues: [String] = []
        
        // Check minimum length
        if text.count < 20 {
            issues.append("Output too short (\(text.count) chars)")
        }
        
        // Check for incomplete sentences (ends mid-word)
        if text.last?.isLetter == true && !text.hasSuffix(".") && !text.hasSuffix("!") && !text.hasSuffix("?") {
            issues.append("Output appears truncated")
        }
        
        // Check for problematic patterns from ML models
        if backend.isMLBased {
            if text.contains("[INST]") || text.contains("<|") || text.contains("|>") {
                issues.append("Output contains prompt artifacts")
            }
            
            if text.lowercased().contains("as an ai") || text.lowercased().contains("i cannot") {
                issues.append("Output contains self-reference patterns")
            }
        }
        
        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }
    
    // MARK: - Confidence Calculation
    
    private static func calculateBaseConfidence(input: ModelInput) -> Double {
        let hasCalendar = !input.contextItems.calendarItems.isEmpty
        let hasEmail = !input.contextItems.emailItems.isEmpty
        let hasFile = !input.contextItems.fileItems.isEmpty
        let hasContext = hasCalendar || hasEmail || hasFile
        
        if hasContext {
            return 0.75  // Base confidence with context
        } else if !input.intentText.isEmpty {
            return 0.55  // Intent only
        } else {
            return 0.35  // Minimal input
        }
    }
}

// MARK: - Draft Output Result

/// Result of DraftOutputFactory.create()
struct DraftOutputResult {
    let output: DraftOutput
    let warnings: [String]
    let requiresFallback: Bool
}
