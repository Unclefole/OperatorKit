#if DEBUG
import Foundation

// MARK: - Fault Injection Model Backend
//
// DEBUG-ONLY backend for testing validation and timeout handling.
// MUST be excluded from Release builds.
// INVARIANT: Never used in normal user flow - only for eval testing.

/// Modes of fault injection for testing
enum FaultInjectionMode: String, CaseIterable {
    /// Generate output with empty body (should fail validation)
    case malformedOutput = "malformed_output"
    
    /// Generate output with citations referencing invalid IDs (should fail citation validation)
    case invalidCitations = "invalid_citations"
    
    /// Simulate slow response that exceeds latency budget (should trigger timeout)
    case slowResponse = "slow_response"
    
    /// Generate output with missing safety notes
    case missingSafetyNotes = "missing_safety_notes"
    
    /// Generate output with empty subject for email (should fail email validation)
    case emptyEmailSubject = "empty_email_subject"
    
    var displayName: String {
        switch self {
        case .malformedOutput: return "Malformed Output (Empty Body)"
        case .invalidCitations: return "Invalid Citations"
        case .slowResponse: return "Slow Response (Timeout)"
        case .missingSafetyNotes: return "Missing Safety Notes"
        case .emptyEmailSubject: return "Empty Email Subject"
        }
    }
    
    var description: String {
        switch self {
        case .malformedOutput:
            return "Produces output with empty body to test validation"
        case .invalidCitations:
            return "Produces citations with fabricated IDs to test citation validation"
        case .slowResponse:
            return "Adds delay exceeding latency budget to test timeout handling"
        case .missingSafetyNotes:
            return "Produces output without safety notes to test safety validation"
        case .emptyEmailSubject:
            return "Produces email draft without subject to test email validation"
        }
    }
}

/// DEBUG-only backend for fault injection testing
/// INVARIANT: This class cannot compile in Release builds
final class FaultInjectionModelBackend: OnDeviceModel {
    
    // MARK: - Properties
    
    let modelId = "fault_injection_test"
    let displayName = "Fault Injection (DEBUG)"
    let version = "1.0.0-debug"
    let backend: ModelBackend = .deterministic  // Treated as deterministic for routing
    
    let capabilities = ModelCapabilities(
        canSummarize: true,
        canDraftEmail: true,
        canExtractActions: true,
        canGenerateReminder: true,
        maxInputTokens: nil,
        maxOutputTokens: nil
    )
    
    var maxOutputChars: Int? { nil }
    
    /// Current injection mode
    var mode: FaultInjectionMode
    
    /// Delay for slow response mode (in seconds)
    var slowResponseDelay: TimeInterval = 5.0  // Exceeds all latency budgets
    
    // MARK: - Initialization
    
    init(mode: FaultInjectionMode) {
        self.mode = mode
    }
    
    // MARK: - OnDeviceModel Protocol
    
    var isAvailable: Bool { true }
    
    func checkAvailability() -> ModelAvailabilityResult {
        .available
    }
    
    func canHandle(input: ModelInput) -> Bool {
        true  // Can handle anything for testing
    }
    
    func generate(input: ModelInput) async throws -> DraftOutput {
        switch mode {
        case .malformedOutput:
            return generateMalformedOutput(input: input)
            
        case .invalidCitations:
            return generateInvalidCitations(input: input)
            
        case .slowResponse:
            return try await generateSlowResponse(input: input)
            
        case .missingSafetyNotes:
            return generateMissingSafetyNotes(input: input)
            
        case .emptyEmailSubject:
            return generateEmptyEmailSubject(input: input)
        }
    }
    
    // MARK: - Fault Generation Methods
    
    /// Generate output with empty body (validation should catch)
    private func generateMalformedOutput(input: ModelInput) -> DraftOutput {
        DraftOutput(
            draftBody: "",  // EMPTY - should fail validation
            subject: "Test Subject",
            actionItems: [],
            confidence: 0.85,
            citations: [],
            safetyNotes: ["Review before sending."],
            outputType: input.outputType
        )
    }
    
    /// Generate output with citations referencing invalid IDs
    private func generateInvalidCitations(input: ModelInput) -> DraftOutput {
        let invalidCitations = [
            Citation(
                sourceType: .calendarEvent,
                sourceId: "INVALID_ID_12345",  // Does not exist in context
                snippet: "This is a fabricated citation",
                label: "Fake Meeting"
            ),
            Citation(
                sourceType: .emailThread,
                sourceId: "INVALID_EMAIL_67890",  // Does not exist in context
                snippet: "Another fabricated citation",
                label: "Fake Email"
            ),
            Citation(
                sourceType: .file,
                sourceId: "INVALID_FILE_ABCDE",  // Does not exist in context
                snippet: "Third fabricated citation",
                label: "Fake Document"
            )
        ]
        
        return DraftOutput(
            draftBody: "This is a test draft with invalid citations.",
            subject: "Test Subject",
            actionItems: [],
            confidence: 0.90,
            citations: invalidCitations,  // All invalid
            safetyNotes: ["Review before sending."],
            outputType: input.outputType
        )
    }
    
    /// Generate output after long delay (timeout should trigger)
    private func generateSlowResponse(input: ModelInput) async throws -> DraftOutput {
        // Sleep for longer than any latency budget
        try await Task.sleep(nanoseconds: UInt64(slowResponseDelay * 1_000_000_000))
        
        // If we get here (shouldn't in timeout test), return valid output
        return DraftOutput(
            draftBody: "This response was delayed and should have timed out.",
            subject: "Slow Response Test",
            actionItems: [],
            confidence: 0.85,
            citations: [],
            safetyNotes: ["Review before sending."],
            outputType: input.outputType
        )
    }
    
    /// Generate output without safety notes (validation should catch)
    private func generateMissingSafetyNotes(input: ModelInput) -> DraftOutput {
        DraftOutput(
            draftBody: "This is a test draft without safety notes.",
            subject: "Test Subject",
            actionItems: [],
            confidence: 0.85,
            citations: [],
            safetyNotes: [],  // EMPTY - should fail safety validation
            outputType: input.outputType
        )
    }
    
    /// Generate email draft without subject (validation should catch)
    private func generateEmptyEmailSubject(input: ModelInput) -> DraftOutput {
        DraftOutput(
            draftBody: "This is a test email draft without a subject.",
            subject: "",  // EMPTY - should fail email validation
            actionItems: [],
            confidence: 0.85,
            citations: [],
            safetyNotes: ["Review before sending."],
            outputType: .emailDraft
        )
    }
}

// MARK: - Compile-Time Safety Check

/// This function exists only to produce a compile-time error in Release builds
/// if FaultInjectionModelBackend somehow gets included
private func _ensureDebugOnlyCompilation() {
    // This empty function body is intentional
    // The #if DEBUG wrapper ensures this entire file doesn't compile in Release
}
#endif
