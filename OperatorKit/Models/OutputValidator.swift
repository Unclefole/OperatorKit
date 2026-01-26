import Foundation

// MARK: - Output Validator
//
// Hard gate validation for DraftOutput before it reaches the user.
// INVARIANT: All outputs must pass validation or be penalized/rejected.
// INVARIANT: Citations must validate against ContextPacket IDs.
// INVARIANT: Safety notes must be present.

// MARK: - Validation Constants

enum OutputValidationConstants {
    /// Confidence penalty for minor validation failures
    static let minorPenalty: Double = 0.10
    
    /// Confidence penalty for moderate validation failures
    static let moderatePenalty: Double = 0.20
    
    /// Confidence penalty for severe validation failures
    static let severePenalty: Double = 0.35
    
    /// Maximum allowed ratio of invalid citations before severe penalty
    static let maxInvalidCitationRatio: Double = 0.30
    
    /// Required safety note patterns (at least one must be present)
    static let requiredSafetyNotePatterns: [String] = [
        "review",
        "verify",
        "check",
        "confirm",
        "before sending",
        "not verified"
    ]
    
    /// Standard fallback safety note if none present
    static let fallbackSafetyNote = "Review this draft carefully before proceeding."
}

// MARK: - Validation Result

/// Result of output validation
struct OutputValidationResult: Equatable {
    let isValid: Bool
    let originalConfidence: Double
    let adjustedConfidence: Double
    let warnings: [ValidationWarning]
    let citationValidity: CitationValidityResult
    let requiresFallback: Bool
    let validationPass: Bool
    
    /// Summary for audit trail
    var summary: String {
        if isValid {
            return "Validation passed"
        } else {
            let warningTexts = warnings.map { $0.message }
            return "Validation warnings: \(warningTexts.joined(separator: "; "))"
        }
    }
}

/// Individual validation warning
struct ValidationWarning: Equatable, Codable {
    let code: WarningCode
    let message: String
    let severity: Severity
    let confidencePenalty: Double
    
    enum WarningCode: String, Codable {
        case emptyBody = "EMPTY_BODY"
        case emptySubject = "EMPTY_SUBJECT"
        case emptyActionItem = "EMPTY_ACTION_ITEM"
        case invalidCitation = "INVALID_CITATION"
        case missingSafetyNote = "MISSING_SAFETY_NOTE"
        case highInvalidCitationRatio = "HIGH_INVALID_CITATION_RATIO"
    }
    
    enum Severity: String, Codable {
        case minor
        case moderate
        case severe
    }
}

/// Result of citation validation
struct CitationValidityResult: Equatable {
    let totalCitations: Int
    let validCitations: Int
    let invalidCitations: Int
    let invalidRatio: Double
    let pass: Bool
    let invalidIds: [String]
    
    static let empty = CitationValidityResult(
        totalCitations: 0,
        validCitations: 0,
        invalidCitations: 0,
        invalidRatio: 0,
        pass: true,
        invalidIds: []
    )
}

// MARK: - Output Validator

/// Validates DraftOutput for quality and invariant compliance
struct OutputValidator {
    
    // MARK: - Main Validation
    
    /// Validate a DraftOutput against the original input
    /// - Parameters:
    ///   - output: The DraftOutput to validate
    ///   - input: The original ModelInput for citation validation
    /// - Returns: Validation result with adjusted confidence
    static func validate(
        output: DraftOutput,
        input: ModelInput
    ) -> OutputValidationResult {
        var warnings: [ValidationWarning] = []
        var totalPenalty: Double = 0
        
        // 1. Validate body (severe if empty)
        if let bodyWarning = validateBody(output) {
            warnings.append(bodyWarning)
            totalPenalty += bodyWarning.confidencePenalty
        }
        
        // 2. Validate subject for email drafts (moderate if empty)
        if let subjectWarning = validateSubject(output) {
            warnings.append(subjectWarning)
            totalPenalty += subjectWarning.confidencePenalty
        }
        
        // 3. Validate action items (minor for empty strings)
        warnings.append(contentsOf: validateActionItems(output))
        totalPenalty += warnings.filter { $0.code == .emptyActionItem }.reduce(0) { $0 + $1.confidencePenalty }
        
        // 4. Validate citations against context IDs
        let citationResult = validateCitations(output, input: input)
        if !citationResult.pass {
            let citationWarning = ValidationWarning(
                code: .highInvalidCitationRatio,
                message: "Invalid citation ratio \(Int(citationResult.invalidRatio * 100))% exceeds 30%",
                severity: .severe,
                confidencePenalty: OutputValidationConstants.severePenalty
            )
            warnings.append(citationWarning)
            totalPenalty += citationWarning.confidencePenalty
        }
        for invalidId in citationResult.invalidIds {
            warnings.append(ValidationWarning(
                code: .invalidCitation,
                message: "Citation references unknown ID: \(invalidId)",
                severity: .minor,
                confidencePenalty: OutputValidationConstants.minorPenalty / Double(max(1, citationResult.invalidIds.count))
            ))
        }
        
        // 5. Validate safety notes (moderate if missing)
        if let safetyWarning = validateSafetyNotes(output) {
            warnings.append(safetyWarning)
            totalPenalty += safetyWarning.confidencePenalty
        }
        
        // Calculate adjusted confidence
        let adjustedConfidence = max(0, output.confidence - totalPenalty)
        
        // Determine if fallback is required
        let hasSevereIssue = warnings.contains { $0.severity == .severe }
        let requiresFallback = hasSevereIssue || adjustedConfidence < DraftOutput.minimumExecutionConfidence
        
        // Validation passes if no severe warnings
        let validationPass = !hasSevereIssue && !warnings.contains { $0.code == .emptyBody }
        
        return OutputValidationResult(
            isValid: warnings.isEmpty,
            originalConfidence: output.confidence,
            adjustedConfidence: adjustedConfidence,
            warnings: warnings,
            citationValidity: citationResult,
            requiresFallback: requiresFallback,
            validationPass: validationPass
        )
    }
    
    // MARK: - Individual Validators
    
    /// Validate body is non-empty
    private static func validateBody(_ output: DraftOutput) -> ValidationWarning? {
        if output.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ValidationWarning(
                code: .emptyBody,
                message: "Draft body is empty",
                severity: .severe,
                confidencePenalty: OutputValidationConstants.severePenalty
            )
        }
        return nil
    }
    
    /// Validate subject is non-empty for email drafts
    private static func validateSubject(_ output: DraftOutput) -> ValidationWarning? {
        guard output.outputType == .emailDraft else { return nil }
        
        if output.subject == nil || output.subject!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ValidationWarning(
                code: .emptySubject,
                message: "Email draft subject is empty",
                severity: .moderate,
                confidencePenalty: OutputValidationConstants.moderatePenalty
            )
        }
        return nil
    }
    
    /// Validate action items don't contain empty strings
    private static func validateActionItems(_ output: DraftOutput) -> [ValidationWarning] {
        var warnings: [ValidationWarning] = []
        
        for (index, item) in output.actionItems.enumerated() {
            if item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                warnings.append(ValidationWarning(
                    code: .emptyActionItem,
                    message: "Action item \(index + 1) is empty",
                    severity: .minor,
                    confidencePenalty: OutputValidationConstants.minorPenalty
                ))
            }
        }
        
        return warnings
    }
    
    /// Validate all citations reference valid context IDs
    private static func validateCitations(
        _ output: DraftOutput,
        input: ModelInput
    ) -> CitationValidityResult {
        let totalCitations = output.citations.count
        
        guard totalCitations > 0 else {
            return .empty
        }
        
        let validContextIds = Set(input.contextItems.items.map { $0.id })
        var invalidIds: [String] = []
        
        for citation in output.citations {
            if !validContextIds.contains(citation.sourceId) {
                invalidIds.append(citation.sourceId)
            }
        }
        
        let invalidCount = invalidIds.count
        let validCount = totalCitations - invalidCount
        let invalidRatio = Double(invalidCount) / Double(totalCitations)
        
        return CitationValidityResult(
            totalCitations: totalCitations,
            validCitations: validCount,
            invalidCitations: invalidCount,
            invalidRatio: invalidRatio,
            pass: invalidRatio <= OutputValidationConstants.maxInvalidCitationRatio,
            invalidIds: invalidIds
        )
    }
    
    /// Validate at least one standard safety note is present
    private static func validateSafetyNotes(_ output: DraftOutput) -> ValidationWarning? {
        let notes = output.safetyNotes
        
        // Check if any required pattern is present
        let hasRequiredNote = notes.contains { note in
            let lowercased = note.lowercased()
            return OutputValidationConstants.requiredSafetyNotePatterns.contains { pattern in
                lowercased.contains(pattern)
            }
        }
        
        if !hasRequiredNote {
            return ValidationWarning(
                code: .missingSafetyNote,
                message: "No standard safety warning present",
                severity: .moderate,
                confidencePenalty: OutputValidationConstants.moderatePenalty
            )
        }
        
        return nil
    }
    
    // MARK: - Correction Helpers
    
    /// Apply validation corrections to output
    /// Returns corrected output with warnings injected into safetyNotes
    static func correct(
        output: DraftOutput,
        validation: OutputValidationResult
    ) -> DraftOutput {
        var correctedNotes = output.safetyNotes
        
        // Add validation warnings to safety notes
        for warning in validation.warnings where warning.severity != .minor {
            let warningNote = "⚠️ \(warning.message)"
            if !correctedNotes.contains(warningNote) {
                correctedNotes.append(warningNote)
            }
        }
        
        // Add fallback safety note if missing
        if validation.warnings.contains(where: { $0.code == .missingSafetyNote }) {
            if !correctedNotes.contains(OutputValidationConstants.fallbackSafetyNote) {
                correctedNotes.insert(OutputValidationConstants.fallbackSafetyNote, at: 0)
            }
        }
        
        return DraftOutput(
            outputType: output.outputType,
            body: output.body,
            subject: output.subject,
            actionItems: output.actionItems.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            confidence: validation.adjustedConfidence,
            citations: output.citations.filter { citation in
                !validation.citationValidity.invalidIds.contains(citation.sourceId)
            },
            safetyNotes: correctedNotes
        )
    }
}
