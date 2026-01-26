import Foundation

// MARK: - Evaluation Case
//
// Defines a test case for model evaluation.
// INVARIANT: Context items are SYNTHETIC (not from user data)
// INVARIANT: No network calls
// INVARIANT: Local-only evaluation

/// A single evaluation case for testing model generation
struct EvalCase: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let intentText: String
    let contextItems: [SyntheticContextItem]
    let expectedOutputType: ModelInput.OutputType
    let expectedBehavior: ExpectedBehavior
    
    /// What we expect the model to do
    enum ExpectedBehavior: Equatable {
        case generateDraft               // Should produce a valid draft
        case routeToFallback             // Should trigger fallback due to low confidence
        case requireProceedAnyway        // Should require "Proceed Anyway" (0.35-0.65 confidence)
        case blockExecution              // Should block execution entirely (<0.35 confidence)
    }
}

/// Synthetic context item for testing (NOT from EventKit or real user data)
struct SyntheticContextItem: Identifiable, Equatable {
    let id: String
    let type: ContextType
    let title: String
    let snippet: String
    let metadata: [String: String]
    
    enum ContextType: String, Equatable {
        case calendarEvent = "calendar"
        case email = "email"
        case document = "document"
        case reminder = "reminder"
    }
    
    /// Convert to ModelInput.ContextItems format
    var asModelContextItem: ModelInput.ContextItems.Item {
        ModelInput.ContextItems.Item(
            id: id,
            type: type.rawValue,
            title: title,
            snippet: snippet,
            startDate: metadata["startDate"].flatMap { ISO8601DateFormatter().date(from: $0) },
            endDate: metadata["endDate"].flatMap { ISO8601DateFormatter().date(from: $0) }
        )
    }
}

// MARK: - Built-in Eval Cases

extension EvalCase {
    
    /// All built-in evaluation cases for model testing
    /// INVARIANT: All context is synthetic - NO real user data
    static let builtInCases: [EvalCase] = [
        // CASE 1: Meeting summary with full context
        meetingSummaryWithContext,
        // CASE 2: Meeting follow-up email
        meetingFollowUpEmail,
        // CASE 3: Email reply draft with thread context
        emailReplyWithThread,
        // CASE 4: Email reply - minimal context
        emailReplyMinimalContext,
        // CASE 5: Document summary with file context
        documentSummaryWithFile,
        // CASE 6: Action items extraction
        actionItemsExtraction,
        // CASE 7: Ambiguous intent - low confidence expected
        ambiguousIntent,
        // CASE 8: No context - should trigger proceed anyway
        noContextIntent,
        // CASE 9-12: Fault injection cases (Phase 4C)
        faultInjectionMalformed,
        faultInjectionInvalidCitations,
        faultInjectionTimeout,
        faultInjectionMissingSafety
    ]
    
    #if DEBUG
    /// Fault injection test cases - only available in DEBUG builds
    static let faultInjectionCases: [EvalCase] = [
        faultInjectionMalformed,
        faultInjectionInvalidCitations,
        faultInjectionTimeout,
        faultInjectionMissingSafety
    ]
    #endif
    
    // MARK: - Meeting Cases
    
    static let meetingSummaryWithContext = EvalCase(
        id: "eval_meeting_summary_1",
        name: "Meeting Summary (Full Context)",
        description: "Generate summary from meeting with attendees and agenda",
        intentText: "Summarize the Q4 planning meeting and list action items",
        contextItems: [
            SyntheticContextItem(
                id: "ctx_meeting_1",
                type: .calendarEvent,
                title: "Q4 Planning Meeting",
                snippet: "Discuss Q4 roadmap priorities. Attendees: Alice, Bob, Carol",
                metadata: [
                    "startDate": "2026-01-20T14:00:00Z",
                    "endDate": "2026-01-20T15:00:00Z",
                    "attendees": "alice@example.com,bob@example.com,carol@example.com"
                ]
            ),
            SyntheticContextItem(
                id: "ctx_notes_1",
                type: .document,
                title: "Meeting Agenda",
                snippet: "1. Review Q3 metrics\n2. Set Q4 OKRs\n3. Assign ownership",
                metadata: [:]
            )
        ],
        expectedOutputType: .meetingSummary,
        expectedBehavior: .generateDraft
    )
    
    static let meetingFollowUpEmail = EvalCase(
        id: "eval_meeting_followup_1",
        name: "Meeting Follow-up Email",
        description: "Draft follow-up email after team meeting",
        intentText: "Draft a follow-up email to the team summarizing what we discussed",
        contextItems: [
            SyntheticContextItem(
                id: "ctx_meeting_2",
                type: .calendarEvent,
                title: "Team Sync",
                snippet: "Weekly team sync to review progress",
                metadata: [
                    "startDate": "2026-01-22T10:00:00Z",
                    "endDate": "2026-01-22T10:30:00Z"
                ]
            )
        ],
        expectedOutputType: .emailDraft,
        expectedBehavior: .generateDraft
    )
    
    // MARK: - Email Cases
    
    static let emailReplyWithThread = EvalCase(
        id: "eval_email_reply_1",
        name: "Email Reply (Thread Context)",
        description: "Draft reply to an email with full thread context",
        intentText: "Reply to Sarah's email about the project deadline",
        contextItems: [
            SyntheticContextItem(
                id: "ctx_email_1",
                type: .email,
                title: "Re: Project Deadline",
                snippet: "Hi, can we move the deadline to next Friday? The team needs more time for testing.",
                metadata: [
                    "from": "sarah@example.com",
                    "date": "2026-01-21T09:15:00Z"
                ]
            )
        ],
        expectedOutputType: .emailDraft,
        expectedBehavior: .generateDraft
    )
    
    static let emailReplyMinimalContext = EvalCase(
        id: "eval_email_reply_2",
        name: "Email Reply (Minimal Context)",
        description: "Draft reply with limited context - should have lower confidence",
        intentText: "Reply to the email",
        contextItems: [
            SyntheticContextItem(
                id: "ctx_email_2",
                type: .email,
                title: "Quick question",
                snippet: "Hey, what do you think?",
                metadata: [:]
            )
        ],
        expectedOutputType: .emailDraft,
        expectedBehavior: .requireProceedAnyway  // Low context = ~0.55 confidence
    )
    
    // MARK: - Document Cases
    
    static let documentSummaryWithFile = EvalCase(
        id: "eval_doc_summary_1",
        name: "Document Summary",
        description: "Summarize a document with clear structure",
        intentText: "Summarize this product requirements document",
        contextItems: [
            SyntheticContextItem(
                id: "ctx_doc_1",
                type: .document,
                title: "Product Requirements - OperatorKit v2",
                snippet: "## Overview\nOperatorKit is an iOS app that...\n\n## Features\n1. Draft generation\n2. Calendar integration\n3. Email composition",
                metadata: [
                    "fileType": "markdown",
                    "wordCount": "2500"
                ]
            )
        ],
        expectedOutputType: .documentSummary,
        expectedBehavior: .generateDraft
    )
    
    static let actionItemsExtraction = EvalCase(
        id: "eval_action_items_1",
        name: "Action Items Extraction",
        description: "Extract action items from meeting notes",
        intentText: "Extract all action items from the meeting notes",
        contextItems: [
            SyntheticContextItem(
                id: "ctx_notes_2",
                type: .document,
                title: "Sprint Planning Notes",
                snippet: "Action items:\n- Alice to review PR #123\n- Bob to update docs\n- Carol to schedule demo",
                metadata: [:]
            )
        ],
        expectedOutputType: .taskList,
        expectedBehavior: .generateDraft
    )
    
    // MARK: - Low Confidence Cases
    
    static let ambiguousIntent = EvalCase(
        id: "eval_ambiguous_1",
        name: "Ambiguous Intent (Low Confidence)",
        description: "Vague intent with no context - should trigger fallback",
        intentText: "do the thing",
        contextItems: [],
        expectedOutputType: .emailDraft,  // Defaulted but unclear
        expectedBehavior: .blockExecution  // <0.35 confidence expected
    )
    
    static let noContextIntent = EvalCase(
        id: "eval_no_context_1",
        name: "No Context (Medium Confidence)",
        description: "Clear intent but no context - should require proceed anyway",
        intentText: "Draft an email about the project update",
        contextItems: [],
        expectedOutputType: .emailDraft,
        expectedBehavior: .requireProceedAnyway  // ~0.55 confidence (intent only)
    )
    
    // MARK: - Fault Injection Cases (Phase 4C)
    
    /// Tests validator catches malformed output (empty body)
    static let faultInjectionMalformed = EvalCase(
        id: "eval_fault_malformed_1",
        name: "Fault Injection: Malformed Output",
        description: "Tests that validator catches empty body and triggers fallback",
        intentText: "Test malformed output handling",
        contextItems: [
            SyntheticContextItem(
                id: "ctx_test_1",
                type: .document,
                title: "Test Document",
                snippet: "Test content for malformed output test",
                metadata: [:]
            )
        ],
        expectedOutputType: .emailDraft,
        expectedBehavior: .routeToFallback  // Validator should catch and force fallback
    )
    
    /// Tests validator catches invalid citations
    static let faultInjectionInvalidCitations = EvalCase(
        id: "eval_fault_citations_1",
        name: "Fault Injection: Invalid Citations",
        description: "Tests that validator catches citations with fabricated IDs",
        intentText: "Test invalid citation handling",
        contextItems: [
            SyntheticContextItem(
                id: "ctx_real_1",
                type: .calendarEvent,
                title: "Real Meeting",
                snippet: "This is the only real context item",
                metadata: [:]
            )
        ],
        expectedOutputType: .meetingSummary,
        expectedBehavior: .routeToFallback  // Validator should catch invalid citations
    )
    
    /// Tests timeout triggers fallback
    static let faultInjectionTimeout = EvalCase(
        id: "eval_fault_timeout_1",
        name: "Fault Injection: Timeout",
        description: "Tests that latency timeout triggers fallback",
        intentText: "Test timeout handling",
        contextItems: [
            SyntheticContextItem(
                id: "ctx_timeout_1",
                type: .document,
                title: "Test Doc",
                snippet: "Content for timeout test",
                metadata: [:]
            )
        ],
        expectedOutputType: .documentSummary,
        expectedBehavior: .routeToFallback  // Timeout should trigger fallback
    )
    
    /// Tests validator catches missing safety notes
    static let faultInjectionMissingSafety = EvalCase(
        id: "eval_fault_safety_1",
        name: "Fault Injection: Missing Safety Notes",
        description: "Tests that validator catches output without safety notes",
        intentText: "Test safety note validation",
        contextItems: [
            SyntheticContextItem(
                id: "ctx_safety_1",
                type: .email,
                title: "Test Email",
                snippet: "Content for safety validation test",
                metadata: [:]
            )
        ],
        expectedOutputType: .emailDraft,
        expectedBehavior: .routeToFallback  // Missing safety should trigger correction/fallback
    )
}
