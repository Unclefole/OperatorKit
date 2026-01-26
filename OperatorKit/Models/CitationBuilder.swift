import Foundation

/// Builds citations ONLY from user-selected context items
/// INVARIANT: Citations must originate from ContextPacket - never from model hallucinations
/// INVARIANT: If citation mapping fails, strip markers and downgrade confidence
final class CitationBuilder {
    
    /// Build citations from context packet
    /// Creates one citation per selected context item that's relevant to the output
    static func buildFromContext(_ context: ContextItems, relevantToText text: String) -> [Citation] {
        var citations: [Citation] = []
        
        // Calendar items
        for (index, item) in context.calendarItems.enumerated() {
            let snippet = buildCalendarSnippet(item)
            let isRelevant = textContainsRelevantContent(text, for: snippet, itemTitle: item.title)
            
            if isRelevant {
                citations.append(Citation(
                    sourceType: .calendarEvent,
                    sourceId: item.eventIdentifier ?? item.id.uuidString,
                    snippet: snippet,
                    label: "Meeting: \(item.title)",
                    relevanceScore: calculateRelevance(text: text, snippet: snippet),
                    index: index
                ))
            }
        }
        
        // Email items
        for (index, item) in context.emailItems.enumerated() {
            let snippet = buildEmailSnippet(item)
            let isRelevant = textContainsRelevantContent(text, for: snippet, itemTitle: item.subject)
            
            if isRelevant {
                citations.append(Citation(
                    sourceType: .emailThread,
                    sourceId: item.messageIdentifier ?? item.id.uuidString,
                    snippet: snippet,
                    label: "Email: \(item.subject)",
                    relevanceScore: calculateRelevance(text: text, snippet: snippet),
                    index: index
                ))
            }
        }
        
        // File items
        for (index, item) in context.fileItems.enumerated() {
            let snippet = buildFileSnippet(item)
            let isRelevant = textContainsRelevantContent(text, for: snippet, itemTitle: item.name)
            
            if isRelevant {
                citations.append(Citation(
                    sourceType: .file,
                    sourceId: item.fileURL?.absoluteString ?? item.id.uuidString,
                    snippet: snippet,
                    label: "File: \(item.name)",
                    relevanceScore: calculateRelevance(text: text, snippet: snippet),
                    index: index
                ))
            }
        }
        
        return citations
    }
    
    /// Map inline citation markers from model output to real context items
    /// Returns (mappedCitations, unmappedMarkers, shouldDowngradeConfidence)
    static func mapInlineCitations(
        markers: [String],
        context: ContextItems,
        outputText: String
    ) -> (citations: [Citation], unmappedCount: Int, shouldDowngrade: Bool) {
        var mappedCitations: [Citation] = []
        var unmappedCount = 0
        
        for marker in markers {
            if let citation = tryMapMarkerToContext(marker, context: context) {
                mappedCitations.append(citation)
            } else {
                unmappedCount += 1
                log("CitationBuilder: Could not map marker '\(marker)' to context")
            }
        }
        
        // If more than 30% of markers couldn't be mapped, downgrade confidence
        let unmappedRatio = markers.isEmpty ? 0 : Double(unmappedCount) / Double(markers.count)
        let shouldDowngrade = unmappedRatio > 0.3
        
        if shouldDowngrade {
            logWarning("CitationBuilder: \(unmappedCount)/\(markers.count) citation markers unmapped - confidence downgrade triggered")
        }
        
        return (mappedCitations, unmappedCount, shouldDowngrade)
    }
    
    /// Strip inline citation markers from text
    /// Use when markers cannot be mapped to context
    static func stripCitationMarkers(from text: String) -> String {
        // Common citation marker patterns
        var result = text
        
        // [1], [2], etc.
        result = result.replacingOccurrences(
            of: "\\[\\d+\\]",
            with: "",
            options: .regularExpression
        )
        
        // [ref:xxx]
        result = result.replacingOccurrences(
            of: "\\[ref:[^\\]]+\\]",
            with: "",
            options: .regularExpression
        )
        
        // Clean up double spaces
        result = result.replacingOccurrences(
            of: "  +",
            with: " ",
            options: .regularExpression
        )
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Private Helpers
    
    private static func buildCalendarSnippet(_ item: CalendarContextItem) -> String {
        var parts: [String] = []
        parts.append(item.title)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        parts.append(formatter.string(from: item.date))
        
        if !item.attendees.isEmpty {
            let attendeeNames = item.attendees.prefix(3).joined(separator: ", ")
            parts.append("with \(attendeeNames)")
        }
        
        return parts.joined(separator: " • ").prefix(200).description
    }
    
    private static func buildEmailSnippet(_ item: EmailContextItem) -> String {
        var parts: [String] = []
        parts.append("From: \(item.sender)")
        parts.append(item.subject)
        
        if let preview = item.preview {
            parts.append(preview.prefix(100).description)
        }
        
        return parts.joined(separator: " • ").prefix(200).description
    }
    
    private static func buildFileSnippet(_ item: FileContextItem) -> String {
        var parts: [String] = []
        parts.append(item.name)
        parts.append(item.type)
        
        if let modified = item.lastModified {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            parts.append("Modified: \(formatter.string(from: modified))")
        }
        
        return parts.joined(separator: " • ").prefix(200).description
    }
    
    private static func textContainsRelevantContent(
        _ text: String,
        for snippet: String,
        itemTitle: String
    ) -> Bool {
        let lowercaseText = text.lowercased()
        let lowercaseTitle = itemTitle.lowercased()
        
        // Check if title or key words from snippet appear in text
        if lowercaseText.contains(lowercaseTitle) {
            return true
        }
        
        // Check for significant words from snippet
        let words = snippet.lowercased().components(separatedBy: .whitespaces)
        let significantWords = words.filter { $0.count > 4 }
        let matchCount = significantWords.filter { lowercaseText.contains($0) }.count
        
        return matchCount >= 2 || (significantWords.count <= 2 && matchCount >= 1)
    }
    
    private static func calculateRelevance(text: String, snippet: String) -> Double {
        let lowercaseText = text.lowercased()
        let words = snippet.lowercased().components(separatedBy: .whitespaces)
        let significantWords = words.filter { $0.count > 3 }
        
        guard !significantWords.isEmpty else { return 0.5 }
        
        let matchCount = significantWords.filter { lowercaseText.contains($0) }.count
        return Double(matchCount) / Double(significantWords.count)
    }
    
    private static func tryMapMarkerToContext(_ marker: String, context: ContextItems) -> Citation? {
        // Try to extract index from marker like "[1]"
        if let indexMatch = marker.firstMatch(of: /\[(\d+)\]/) {
            let index = Int(indexMatch.1) ?? 0
            
            // Map index to context items (1-indexed)
            let totalItems = context.calendarItems.count + context.emailItems.count + context.fileItems.count
            guard index > 0 && index <= totalItems else { return nil }
            
            let adjustedIndex = index - 1
            
            if adjustedIndex < context.calendarItems.count {
                let item = context.calendarItems[adjustedIndex]
                return Citation(
                    sourceType: .calendarEvent,
                    sourceId: item.eventIdentifier ?? item.id.uuidString,
                    snippet: buildCalendarSnippet(item),
                    label: "Meeting: \(item.title)",
                    relevanceScore: 0.8,
                    index: adjustedIndex
                )
            }
            
            let emailIndex = adjustedIndex - context.calendarItems.count
            if emailIndex >= 0 && emailIndex < context.emailItems.count {
                let item = context.emailItems[emailIndex]
                return Citation(
                    sourceType: .emailThread,
                    sourceId: item.messageIdentifier ?? item.id.uuidString,
                    snippet: buildEmailSnippet(item),
                    label: "Email: \(item.subject)",
                    relevanceScore: 0.8,
                    index: emailIndex
                )
            }
            
            let fileIndex = emailIndex - context.emailItems.count
            if fileIndex >= 0 && fileIndex < context.fileItems.count {
                let item = context.fileItems[fileIndex]
                return Citation(
                    sourceType: .file,
                    sourceId: item.fileURL?.absoluteString ?? item.id.uuidString,
                    snippet: buildFileSnippet(item),
                    label: "File: \(item.name)",
                    relevanceScore: 0.8,
                    index: fileIndex
                )
            }
        }
        
        return nil
    }
}
