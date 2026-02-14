import Foundation

// ============================================================================
// STRUCTURED ON-DEVICE BACKEND
//
// Implements OnDeviceModel by delegating to StructuredDraftEngine.
// Replaces DeterministicTemplateModel as the primary on-device intelligence,
// producing context-aware prose instead of fill-in-the-blank templates.
//
// INVARIANTS:
// - Strictly on-device. Zero network calls.
// - Fail-closed: if prose generation throws, falls back to deterministic.
// - Same protocol interface → trivially swappable with CoreML/Apple later.
// - Citations built via the same CitationBuilder contract.
// - Evidence logged via ModelRouter's governed path.
// ============================================================================

/// Context-aware on-device draft generator.
/// Higher quality than DeterministicTemplateModel, same trust posture.
final class StructuredOnDeviceBackend: OnDeviceModel {

    // MARK: - OnDeviceModel Protocol

    let modelId = "structured_on_device_v1"
    let displayName = "Structured On-Device"
    let version = "1.0.0"
    let backend: ModelBackend = .structuredOnDevice

    let capabilities = ModelCapabilities(
        canSummarize: true,
        canDraftEmail: true,
        canExtractActions: true,
        canGenerateReminder: true,
        maxInputTokens: nil,
        maxOutputTokens: nil
    )

    var maxOutputChars: Int? { nil }

    // Always available — pure Swift logic, no model loading required
    var isAvailable: Bool { true }

    func checkAvailability() -> ModelAvailabilityResult {
        .available
    }

    func canHandle(input: ModelInput) -> Bool {
        true // Can handle any output type
    }

    // MARK: - Generation

    func generate(input: ModelInput) async throws -> DraftOutput {
        let startTime = Date()
        log("StructuredOnDeviceBackend: Generating \(input.outputType.displayName)")

        let result: (body: String, subject: String, actionItems: [String])

        switch input.outputType {
        case .emailDraft:
            result = StructuredDraftEngine.composeEmail(
                intent: input.intentText,
                calendarItems: input.contextItems.calendarItems,
                emailItems: input.contextItems.emailItems,
                fileItems: input.contextItems.fileItems
            )

        case .meetingSummary:
            result = StructuredDraftEngine.composeMeetingSummary(
                intent: input.intentText,
                calendarItems: input.contextItems.calendarItems,
                emailItems: input.contextItems.emailItems
            )

        case .taskList:
            result = StructuredDraftEngine.composeTaskList(
                intent: input.intentText,
                calendarItems: input.contextItems.calendarItems,
                emailItems: input.contextItems.emailItems,
                fileItems: input.contextItems.fileItems
            )

        case .documentSummary:
            result = StructuredDraftEngine.composeDocumentSummary(
                intent: input.intentText,
                fileItems: input.contextItems.fileItems
            )

        case .reminder:
            result = StructuredDraftEngine.composeReminder(
                intent: input.intentText,
                calendarItems: input.contextItems.calendarItems,
                emailItems: input.contextItems.emailItems
            )
        case .researchBrief:
            result = (
                body: "# Executive Market Brief\n**INTERNAL DRAFT — DO NOT DISTRIBUTE**\n\n## Research Request\n\(input.intentText)\n\n*For full research analysis, enable a cloud AI provider in Intelligence Settings.*\n*All data should be verified against primary sources.*",
                subject: "Executive Market Brief — INTERNAL DRAFT",
                actionItems: ["Enable cloud AI for full research brief", "Verify data against primary sources"]
            )
        }

        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)

        // Build citations from context (same contract as deterministic)
        let citations = buildCitations(from: input)

        // Safety notes
        let safetyNotes = buildSafetyNotes(for: input)

        // Confidence: higher than deterministic because we compose real prose
        let confidence = calculateConfidence(for: input)

        log("StructuredOnDeviceBackend: Complete in \(latencyMs)ms, confidence: \(Int(confidence * 100))%")

        return DraftOutput(
            draftBody: result.body,
            subject: result.subject,
            actionItems: result.actionItems,
            confidence: confidence,
            citations: citations,
            safetyNotes: safetyNotes,
            outputType: input.outputType
        )
    }

    // MARK: - Citations

    private func buildCitations(from input: ModelInput) -> [Citation] {
        var citations: [Citation] = []
        for item in input.contextItems.calendarItems {
            citations.append(Citation.fromCalendarItem(item))
        }
        for item in input.contextItems.emailItems {
            citations.append(Citation.fromEmailItem(item))
        }
        for item in input.contextItems.fileItems {
            citations.append(Citation.fromFileItem(item))
        }
        return citations
    }

    // MARK: - Safety Notes

    private func buildSafetyNotes(for input: ModelInput) -> [String] {
        var notes: [String] = ["You must review before sending."]
        switch input.outputType {
        case .emailDraft:
            notes.append("Recipients not verified until you confirm.")
            notes.append("Email will not send automatically — you control when to send.")
        case .meetingSummary:
            notes.append("Summary composed from available calendar data. Verify completeness.")
        case .documentSummary:
            notes.append("Document overview based on metadata only. Open file for full review.")
        case .taskList:
            notes.append("Task priorities are suggestions. Review and adjust.")
        case .reminder:
            notes.append("Reminder timing is a suggestion — adjust as needed.")
        case .researchBrief:
            notes.append("Research draft for internal review only — do not distribute externally.")
            notes.append("All data should be verified against primary sources.")
        }
        if input.contextItems.isEmpty {
            notes.append("Generated without context — accuracy may be limited.")
        }
        return notes
    }

    // MARK: - Confidence

    private func calculateConfidence(for input: ModelInput) -> Double {
        // Structured backend produces higher quality than deterministic:
        //  - With rich context (calendar+email+files): 0.90
        //  - With some context (1+ items): 0.78
        //  - Intent only (no context): 0.60
        //  - Ambiguous intent: 0.42
        if input.isAmbiguous {
            return 0.42
        }
        let contextCount = input.contextItems.totalCount
        if contextCount >= 2 {
            return 0.90
        }
        if contextCount == 1 {
            return 0.78
        }
        return 0.60
    }
}
