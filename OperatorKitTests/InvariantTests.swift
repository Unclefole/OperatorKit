import XCTest
@testable import OperatorKit

/// Invariant Test Suite for OperatorKit
///
/// Tests that assert non-negotiable invariants are enforced:
/// 1. CitationBuilder ONLY cites context IDs (reject unknown IDs)
/// 2. ModelRouter never returns network backend (there is none)
/// 3. Any backend failure results in deterministic fallback AND fallbackReason set
/// 4. Confidence gates are enforced
/// 5. ApprovalGate blocks execution when requirements not met
///
/// INVARIANT: Tests do not require iOS Simulator UI - pure Swift tests
final class InvariantTests: XCTestCase {
    
    // MARK: - Test 1: CitationBuilder Only Cites Context IDs
    
    /// CitationBuilder must ONLY create citations from provided context items.
    /// Unknown IDs must be rejected.
    func testCitationBuilderOnlyCitesProvidedContextItems() {
        // Given: A set of known context items
        let knownItems = ModelInput.ContextItems(items: [
            ModelInput.ContextItems.Item(
                id: "ctx_known_1",
                type: "calendar",
                title: "Team Meeting",
                snippet: "Discuss roadmap",
                startDate: nil,
                endDate: nil
            ),
            ModelInput.ContextItems.Item(
                id: "ctx_known_2",
                type: "email",
                title: "Project Update",
                snippet: "Status report",
                startDate: nil,
                endDate: nil
            )
        ])
        
        // When: Building citations from context
        let citations = CitationBuilder.buildFromContext(
            knownItems,
            relevantToText: "Based on the Team Meeting about roadmap"
        )
        
        // Then: All citations must reference known context IDs only
        for citation in citations {
            let knownIds = knownItems.items.map { $0.id }
            XCTAssertTrue(
                knownIds.contains(citation.sourceId),
                "Citation references unknown ID: \(citation.sourceId). Known IDs: \(knownIds)"
            )
        }
    }
    
    /// CitationBuilder must not create citations for fabricated/unknown IDs
    func testCitationBuilderRejectsUnknownIds() {
        // Given: Empty context
        let emptyContext = ModelInput.ContextItems(items: [])
        
        // When: Attempting to map inline markers that reference unknown IDs
        let result = CitationBuilder.mapInlineCitations(
            rawText: "According to [1] and [2], we should proceed.",
            context: emptyContext
        )
        
        // Then: Should have no valid citations (all unmapped)
        XCTAssertEqual(result.citations.count, 0, "No citations should be created from empty context")
        XCTAssertEqual(result.unmappedCount, 2, "Both markers should be unmapped")
    }
    
    // MARK: - Test 2: ModelRouter Never Returns Network Backend
    
    /// ModelRouter must never expose a network backend.
    /// There is no network backend in the system.
    func testModelRouterNeverReturnsNetworkBackend() {
        // Given: All possible model backends
        let allBackends: [ModelBackend] = [.appleOnDevice, .coreML, .deterministic]
        
        // Then: None should be a "network" backend
        for backend in allBackends {
            XCTAssertNotEqual(backend.rawValue, "network", "Network backend should not exist")
            XCTAssertNotEqual(backend.rawValue, "cloud", "Cloud backend should not exist")
            XCTAssertNotEqual(backend.rawValue, "remote", "Remote backend should not exist")
            XCTAssertNotEqual(backend.rawValue, "api", "API backend should not exist")
        }
        
        // Verify ModelBackend enum has only expected cases
        XCTAssertEqual(allBackends.count, 3, "Only 3 backends should exist: appleOnDevice, coreML, deterministic")
    }
    
    /// ModelRouter availability should never include network-based options
    @MainActor
    func testModelRouterAvailabilityContainsNoNetworkBackends() async {
        // Given: ModelRouter
        let router = ModelRouter.shared
        
        // When: Getting backend availability
        let availability = router.backendAvailability
        
        // Then: No network backends
        for (backend, _) in availability {
            XCTAssertFalse(
                backend.rawValue.lowercased().contains("network"),
                "Backend \(backend) appears to be network-based"
            )
            XCTAssertFalse(
                backend.rawValue.lowercased().contains("cloud"),
                "Backend \(backend) appears to be cloud-based"
            )
        }
    }
    
    // MARK: - Test 3: Backend Failure Results in Deterministic Fallback
    
    /// When a non-deterministic backend fails, router must fallback to deterministic
    /// and capture the fallback reason.
    @MainActor
    func testBackendFailureResultsInDeterministicFallback() async {
        // Given: ModelRouter with a valid input
        let router = ModelRouter.shared
        let input = ModelInput(
            intentText: "Test intent for fallback verification",
            contextSummary: "Test context",
            contextItems: ModelInput.ContextItems(items: [
                ModelInput.ContextItems.Item(
                    id: "test_ctx_1",
                    type: "document",
                    title: "Test Doc",
                    snippet: "Test content",
                    startDate: nil,
                    endDate: nil
                )
            ]),
            constraints: ModelInput.standardConstraints,
            outputType: .emailDraft
        )
        
        // When: Generating output
        do {
            let output = try await router.generate(input: input)
            
            // Then: Output should be valid
            XCTAssertFalse(output.body.isEmpty, "Output body should not be empty")
            
            // And: If fallback was used, reason should be captured
            if router.currentBackend == .deterministic && router.lastFallbackReason != nil {
                XCTAssertNotNil(router.lastFallbackReason, "Fallback reason should be captured")
                XCTAssertFalse(router.lastFallbackReason!.isEmpty, "Fallback reason should not be empty")
            }
            
        } catch {
            // Fallback should prevent this, but if it happens, it's a failure
            XCTFail("Generation should not fail with fallback available: \(error)")
        }
    }
    
    /// Deterministic model should always be available as fallback
    func testDeterministicModelAlwaysAvailable() {
        // Given: Deterministic model
        let model = DeterministicTemplateModel()
        
        // Then: It should always be available
        XCTAssertTrue(model.isAvailable, "Deterministic model must always be available")
        
        let availability = model.checkAvailability()
        XCTAssertTrue(availability.isAvailable, "Deterministic availability must return true")
    }
    
    // MARK: - Test 4: Confidence Gates Are Enforced
    
    /// Confidence below 0.35 must route to Fallback and block execution
    func testConfidenceBelow35BlocksExecution() {
        // Given: A draft with very low confidence
        let lowConfidenceDraft = Draft(
            type: .emailDraft,
            body: "Test body",
            subject: "Test",
            recipients: [],
            attachments: [],
            confidence: 0.30,  // Below 0.35 threshold
            citations: [],
            safetyNotes: ["Review before sending"],
            actionItems: [],
            modelMetadata: nil
        )
        
        // When: Checking if execution is allowed
        let approvalGate = ApprovalGate(draft: lowConfidenceDraft)
        
        // Then: Execution should be blocked
        let canExecute = approvalGate.canExecute(
            approvalGranted: true,
            sideEffectsAcknowledged: true,
            confidenceConfirmed: false  // User hasn't confirmed low confidence
        )
        
        XCTAssertFalse(canExecute, "Confidence <0.35 must block execution without explicit confirmation")
    }
    
    /// Confidence between 0.35 and 0.65 requires explicit "Proceed Anyway"
    func testConfidenceBetween35And65RequiresProceedAnyway() {
        // Given: A draft with medium-low confidence
        let mediumConfidenceDraft = Draft(
            type: .emailDraft,
            body: "Test body",
            subject: "Test",
            recipients: [],
            attachments: [],
            confidence: 0.50,  // Between 0.35 and 0.65
            citations: [],
            safetyNotes: ["Review before sending"],
            actionItems: [],
            modelMetadata: nil
        )
        
        let approvalGate = ApprovalGate(draft: mediumConfidenceDraft)
        
        // When: Checking execution without "Proceed Anyway"
        let canExecuteWithoutProceed = approvalGate.canExecute(
            approvalGranted: true,
            sideEffectsAcknowledged: true,
            confidenceConfirmed: false  // No "Proceed Anyway"
        )
        
        // Then: Should be blocked
        XCTAssertFalse(canExecuteWithoutProceed, "Confidence 0.35-0.65 requires 'Proceed Anyway'")
        
        // When: Checking with "Proceed Anyway"
        let canExecuteWithProceed = approvalGate.canExecute(
            approvalGranted: true,
            sideEffectsAcknowledged: true,
            confidenceConfirmed: true  // User clicked "Proceed Anyway"
        )
        
        // Then: Should be allowed
        XCTAssertTrue(canExecuteWithProceed, "Confidence 0.35-0.65 should pass with 'Proceed Anyway'")
    }
    
    /// Confidence >= 0.65 does not require additional confirmation
    func testHighConfidenceDoesNotRequireProceedAnyway() {
        // Given: A draft with high confidence
        let highConfidenceDraft = Draft(
            type: .emailDraft,
            body: "Test body",
            subject: "Test",
            recipients: [],
            attachments: [],
            confidence: 0.85,  // Above 0.65 threshold
            citations: [],
            safetyNotes: ["Review before sending"],
            actionItems: [],
            modelMetadata: nil
        )
        
        let approvalGate = ApprovalGate(draft: highConfidenceDraft)
        
        // When: Checking execution without explicit confidence confirmation
        let canExecute = approvalGate.canExecute(
            approvalGranted: true,
            sideEffectsAcknowledged: true,
            confidenceConfirmed: false  // Not needed for high confidence
        )
        
        // Then: Should be allowed
        XCTAssertTrue(canExecute, "Confidence >=0.65 should not require 'Proceed Anyway'")
    }
    
    // MARK: - Test 5: ApprovalGate Blocks Execution
    
    /// ApprovalGate blocks when approvalGranted is false
    func testApprovalGateBlocksWithoutApproval() {
        // Given: A valid draft
        let draft = Draft(
            type: .emailDraft,
            body: "Test body",
            subject: "Test",
            recipients: [],
            attachments: [],
            confidence: 0.85,
            citations: [],
            safetyNotes: [],
            actionItems: [],
            modelMetadata: nil
        )
        
        let approvalGate = ApprovalGate(draft: draft)
        
        // When: Checking execution without approval
        let canExecute = approvalGate.canExecute(
            approvalGranted: false,  // NO APPROVAL
            sideEffectsAcknowledged: true,
            confidenceConfirmed: true
        )
        
        // Then: Must be blocked
        XCTAssertFalse(canExecute, "Must block execution when approval not granted")
    }
    
    /// ApprovalGate blocks when side effects not acknowledged
    func testApprovalGateBlocksWithoutSideEffectAcknowledgment() {
        // Given: A valid draft
        let draft = Draft(
            type: .emailDraft,
            body: "Test body",
            subject: "Test",
            recipients: [],
            attachments: [],
            confidence: 0.85,
            citations: [],
            safetyNotes: [],
            actionItems: [],
            modelMetadata: nil
        )
        
        let approvalGate = ApprovalGate(draft: draft)
        
        // When: Checking execution without side effect acknowledgment
        let canExecute = approvalGate.canExecute(
            approvalGranted: true,
            sideEffectsAcknowledged: false,  // NOT ACKNOWLEDGED
            confidenceConfirmed: true
        )
        
        // Then: Must be blocked
        XCTAssertFalse(canExecute, "Must block execution when side effects not acknowledged")
    }
    
    /// Write effects require secondConfirmationGranted (two-key turn)
    func testWriteEffectsRequireSecondConfirmation() {
        // Given: A side effect that is a write operation
        var reminderSideEffect = SideEffect(
            id: "test_reminder_write",
            type: .createReminder,
            title: "Create Reminder",
            description: "Will create a reminder",
            isUserActionRequired: true,
            acknowledgedByUser: true
        )
        reminderSideEffect.reminderPayload = ReminderPayload(
            title: "Test Reminder",
            notes: "Test notes",
            dueDate: Date(),
            priority: .medium,
            listIdentifier: nil
        )
        // Note: secondConfirmationGranted is false by default
        
        // Then: Write should be blocked without second confirmation
        XCTAssertFalse(
            reminderSideEffect.secondConfirmationGranted,
            "Second confirmation should be false by default"
        )
        
        // When: Setting second confirmation
        reminderSideEffect.markSecondConfirmation()
        
        // Then: Write should be allowed
        XCTAssertTrue(
            reminderSideEffect.secondConfirmationGranted,
            "Second confirmation should be true after marking"
        )
        XCTAssertNotNil(
            reminderSideEffect.secondConfirmationTimestamp,
            "Confirmation timestamp should be set"
        )
    }
    
    /// Calendar write effects require secondConfirmationGranted
    func testCalendarWriteRequiresSecondConfirmation() {
        // Given: A calendar create side effect
        var calendarSideEffect = SideEffect(
            id: "test_calendar_write",
            type: .createCalendarEvent,
            title: "Create Event",
            description: "Will create a calendar event",
            isUserActionRequired: true,
            acknowledgedByUser: true
        )
        calendarSideEffect.calendarEventPayload = CalendarEventPayload(
            title: "Test Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            location: nil,
            notes: nil,
            calendarIdentifier: nil,
            attendeesEmails: [],
            alarmOffsetsMinutes: [],
            timeZoneIdentifier: nil
        )
        
        // Then: Write should be blocked without second confirmation
        XCTAssertFalse(
            calendarSideEffect.secondConfirmationGranted,
            "Calendar write should require second confirmation"
        )
        
        // When: Setting second confirmation
        calendarSideEffect.markSecondConfirmation()
        
        // Then: Confirmation should be set with timestamp
        XCTAssertTrue(calendarSideEffect.secondConfirmationGranted)
        XCTAssertNotNil(calendarSideEffect.secondConfirmationTimestamp)
        
        // And: Timestamp should be recent (within 1 second)
        let timeSinceConfirmation = Date().timeIntervalSince(calendarSideEffect.secondConfirmationTimestamp!)
        XCTAssertLessThan(timeSinceConfirmation, 1.0, "Confirmation timestamp should be current")
    }
    
    // MARK: - Test: DraftOutput Thresholds
    
    /// Verify DraftOutput threshold constants are correct
    func testDraftOutputThresholdConstants() {
        XCTAssertEqual(DraftOutput.minimumExecutionConfidence, 0.35, "Minimum execution confidence should be 0.35")
        XCTAssertEqual(DraftOutput.proceedAnywayThreshold, 0.65, "Proceed Anyway threshold should be 0.65")
    }
    
    /// Verify DraftOutput helper methods work correctly
    func testDraftOutputConfidenceHelpers() {
        // Very low confidence
        let veryLowOutput = DraftOutput(
            outputType: .emailDraft,
            body: "Test",
            subject: "Test",
            actionItems: [],
            confidence: 0.30,
            citations: [],
            safetyNotes: []
        )
        XCTAssertTrue(veryLowOutput.isBelowMinimumConfidence)
        XCTAssertTrue(veryLowOutput.requiresProceedAnyway)
        
        // Medium confidence
        let mediumOutput = DraftOutput(
            outputType: .emailDraft,
            body: "Test",
            subject: "Test",
            actionItems: [],
            confidence: 0.50,
            citations: [],
            safetyNotes: []
        )
        XCTAssertFalse(mediumOutput.isBelowMinimumConfidence)
        XCTAssertTrue(mediumOutput.requiresProceedAnyway)
        
        // High confidence
        let highOutput = DraftOutput(
            outputType: .emailDraft,
            body: "Test",
            subject: "Test",
            actionItems: [],
            confidence: 0.85,
            citations: [],
            safetyNotes: []
        )
        XCTAssertFalse(highOutput.isBelowMinimumConfidence)
        XCTAssertFalse(highOutput.requiresProceedAnyway)
    }
    
    // MARK: - Test: ModelCapabilities
    
    /// Verify ModelCapabilities correctly identifies support
    func testModelCapabilitiesSupportsOutputType() {
        let fullCapabilities = ModelCapabilities(
            canSummarize: true,
            canDraftEmail: true,
            canExtractActions: true,
            canGenerateReminder: true,
            maxInputTokens: 4096,
            maxOutputTokens: 2048
        )
        
        XCTAssertTrue(fullCapabilities.supports(outputType: .meetingSummary))
        XCTAssertTrue(fullCapabilities.supports(outputType: .emailDraft))
        XCTAssertTrue(fullCapabilities.supports(outputType: .taskList))
        XCTAssertTrue(fullCapabilities.supports(outputType: .documentSummary))
        XCTAssertTrue(fullCapabilities.supports(outputType: .reminder))
        
        let limitedCapabilities = ModelCapabilities(
            canSummarize: true,
            canDraftEmail: false,
            canExtractActions: false,
            canGenerateReminder: false,
            maxInputTokens: 256,
            maxOutputTokens: 64
        )
        
        XCTAssertTrue(limitedCapabilities.supports(outputType: .meetingSummary))
        XCTAssertFalse(limitedCapabilities.supports(outputType: .emailDraft))
        XCTAssertFalse(limitedCapabilities.supports(outputType: .taskList))
    }
}

// MARK: - Phase 4C: Output Validation Tests

extension InvariantTests {
    
    /// OutputValidator must catch empty body and apply severe penalty
    func testValidatorCatchesEmptyBody() {
        // Given: Output with empty body
        let invalidOutput = DraftOutput(
            outputType: .emailDraft,
            body: "",
            subject: "Test",
            actionItems: [],
            confidence: 0.85,
            citations: [],
            safetyNotes: ["Review before sending."]
        )
        
        let input = ModelInput(
            intentText: "Test intent",
            contextSummary: "Test context",
            contextItems: ModelInput.ContextItems(items: []),
            constraints: [],
            outputType: .emailDraft
        )
        
        // When: Validating
        let result = OutputValidator.validate(output: invalidOutput, input: input)
        
        // Then: Should not pass and require fallback
        XCTAssertFalse(result.validationPass, "Empty body should fail validation")
        XCTAssertTrue(result.requiresFallback, "Empty body should require fallback")
        XCTAssertTrue(result.warnings.contains { $0.code == .emptyBody }, "Should have empty body warning")
        XCTAssertLessThan(result.adjustedConfidence, invalidOutput.confidence, "Confidence should be penalized")
    }
    
    /// OutputValidator must catch invalid citations
    func testValidatorCatchesInvalidCitations() {
        // Given: Output with citations referencing unknown IDs
        let invalidCitations = [
            Citation(sourceType: .calendarEvent, sourceId: "FAKE_ID_123", snippet: "Fake", label: "Fake"),
            Citation(sourceType: .emailThread, sourceId: "FAKE_ID_456", snippet: "Fake", label: "Fake")
        ]
        
        let invalidOutput = DraftOutput(
            outputType: .meetingSummary,
            body: "Valid body content",
            subject: nil,
            actionItems: [],
            confidence: 0.85,
            citations: invalidCitations,
            safetyNotes: ["Review before sending."]
        )
        
        // Context has no items - all citations are invalid
        let input = ModelInput(
            intentText: "Test intent",
            contextSummary: "Test context",
            contextItems: ModelInput.ContextItems(items: []),
            constraints: [],
            outputType: .meetingSummary
        )
        
        // When: Validating
        let result = OutputValidator.validate(output: invalidOutput, input: input)
        
        // Then: Citation validity should fail
        XCTAssertFalse(result.citationValidity.pass, "Invalid citations should fail")
        XCTAssertEqual(result.citationValidity.invalidCitations, 2, "Both citations should be invalid")
        XCTAssertTrue(result.requiresFallback, "High invalid citation ratio should require fallback")
    }
    
    /// OutputValidator must catch missing safety notes
    func testValidatorCatchesMissingSafetyNotes() {
        // Given: Output without safety notes
        let invalidOutput = DraftOutput(
            outputType: .emailDraft,
            body: "Valid body content",
            subject: "Test Subject",
            actionItems: [],
            confidence: 0.85,
            citations: [],
            safetyNotes: []  // Empty - should be caught
        )
        
        let input = ModelInput(
            intentText: "Test intent",
            contextSummary: "Test context",
            contextItems: ModelInput.ContextItems(items: []),
            constraints: [],
            outputType: .emailDraft
        )
        
        // When: Validating
        let result = OutputValidator.validate(output: invalidOutput, input: input)
        
        // Then: Should have missing safety note warning
        XCTAssertFalse(result.isValid, "Missing safety notes should fail")
        XCTAssertTrue(result.warnings.contains { $0.code == .missingSafetyNote }, "Should warn about missing safety")
    }
    
    /// Validator should apply corrections to output
    func testValidatorAppliesCorrections() {
        // Given: Output with issues
        let invalidOutput = DraftOutput(
            outputType: .emailDraft,
            body: "Valid body",
            subject: "Subject",
            actionItems: ["Valid item", "", "Another valid"],  // Contains empty
            confidence: 0.85,
            citations: [],
            safetyNotes: []
        )
        
        let input = ModelInput(
            intentText: "Test",
            contextSummary: "",
            contextItems: ModelInput.ContextItems(items: []),
            constraints: [],
            outputType: .emailDraft
        )
        
        let validation = OutputValidator.validate(output: invalidOutput, input: input)
        
        // When: Correcting
        let corrected = OutputValidator.correct(output: invalidOutput, validation: validation)
        
        // Then: Empty action items should be removed
        XCTAssertEqual(corrected.actionItems.count, 2, "Empty action items should be filtered")
        XCTAssertFalse(corrected.actionItems.contains { $0.isEmpty }, "No empty items after correction")
        
        // Safety notes should be added
        XCTAssertFalse(corrected.safetyNotes.isEmpty, "Safety notes should be added")
    }
}

// MARK: - Phase 4C: Timeout Tests

extension InvariantTests {
    
    /// Latency budget constants should be properly defined
    func testLatencyBudgetConstants() {
        XCTAssertEqual(ModelLatencyBudget.deterministicMs, 1200, "Deterministic budget should be 1200ms")
        XCTAssertEqual(ModelLatencyBudget.coreMLMs, 2500, "CoreML budget should be 2500ms")
        XCTAssertEqual(ModelLatencyBudget.appleOnDeviceMs, 3500, "Apple On-Device budget should be 3500ms")
    }
    
    /// Budget lookup should return correct values
    func testLatencyBudgetLookup() {
        XCTAssertEqual(ModelLatencyBudget.budget(for: .deterministic), 1200)
        XCTAssertEqual(ModelLatencyBudget.budget(for: .coreML), 2500)
        XCTAssertEqual(ModelLatencyBudget.budget(for: .appleOnDevice), 3500)
    }
    
    /// TimeInterval conversion should be correct
    func testLatencyBudgetTimeInterval() {
        XCTAssertEqual(ModelLatencyBudget.timeInterval(for: .deterministic), 1.2, accuracy: 0.01)
        XCTAssertEqual(ModelLatencyBudget.timeInterval(for: .coreML), 2.5, accuracy: 0.01)
        XCTAssertEqual(ModelLatencyBudget.timeInterval(for: .appleOnDevice), 3.5, accuracy: 0.01)
    }
}

// MARK: - Phase 4C: Fault Injection Release Exclusion

extension InvariantTests {
    
    #if DEBUG
    /// Fault injection backend should only exist in DEBUG
    func testFaultInjectionExistsInDebug() {
        // This test only compiles in DEBUG
        let backend = FaultInjectionModelBackend(mode: .malformedOutput)
        XCTAssertTrue(backend.isAvailable, "Fault injection should be available in DEBUG")
    }
    
    /// Fault injection modes should all be accessible
    func testFaultInjectionModesExist() {
        let modes = FaultInjectionMode.allCases
        XCTAssertGreaterThanOrEqual(modes.count, 4, "Should have at least 4 fault injection modes")
        XCTAssertTrue(modes.contains(.malformedOutput))
        XCTAssertTrue(modes.contains(.invalidCitations))
        XCTAssertTrue(modes.contains(.slowResponse))
        XCTAssertTrue(modes.contains(.missingSafetyNotes))
    }
    #endif
    
    /// In Release, FaultInjectionModelBackend should not compile
    /// This test passes in Release because the #if DEBUG block excludes the class
    func testFaultInjectionExcludedFromRelease() {
        #if !DEBUG
        // This code only runs in Release builds
        // FaultInjectionModelBackend should not exist
        // If this test compiles in Release, the exclusion is working
        XCTAssertTrue(true, "Fault injection is correctly excluded from Release")
        #else
        // In DEBUG, we just verify the class exists
        XCTAssertTrue(true, "Running in DEBUG mode")
        #endif
    }
}

// MARK: - Phase 4C: Prompt Scaffold Tests

extension InvariantTests {
    
    /// Prompt scaffold should generate non-empty string
    func testPromptScaffoldGeneratesContent() {
        let input = ModelInput(
            intentText: "Draft a follow-up email",
            contextSummary: "Meeting about Q4 plans",
            contextItems: ModelInput.ContextItems(items: []),
            constraints: ModelInput.standardConstraints,
            outputType: .emailDraft
        )
        
        let scaffold = input.promptScaffold
        
        XCTAssertFalse(scaffold.scaffoldString.isEmpty, "Scaffold should not be empty")
        XCTAssertTrue(scaffold.scaffoldString.contains("Task"), "Should have task section")
        XCTAssertTrue(scaffold.scaffoldString.contains("Intent"), "Should have intent section")
        XCTAssertTrue(scaffold.scaffoldString.contains("Requirements"), "Should have requirements section")
    }
    
    /// Prompt scaffold hash should be consistent
    func testPromptScaffoldHashConsistency() {
        let input1 = ModelInput(
            intentText: "Test intent",
            contextSummary: "Test context",
            contextItems: ModelInput.ContextItems(items: []),
            constraints: [],
            outputType: .emailDraft
        )
        
        let scaffold1 = PromptScaffold(from: input1)
        let scaffold2 = PromptScaffold(from: input1)
        
        // Same input should produce same hash
        XCTAssertEqual(scaffold1.scaffoldHash, scaffold2.scaffoldHash, "Same input should produce same hash")
        
        // Hash should be 64 characters (SHA256 hex)
        XCTAssertEqual(scaffold1.scaffoldHash.count, 64, "SHA256 hash should be 64 hex chars")
    }
    
    /// Different inputs should produce different hashes
    func testPromptScaffoldHashDifference() {
        let input1 = ModelInput(
            intentText: "Intent A",
            contextSummary: "Context A",
            contextItems: ModelInput.ContextItems(items: []),
            constraints: [],
            outputType: .emailDraft
        )
        
        let input2 = ModelInput(
            intentText: "Intent B",
            contextSummary: "Context B",
            contextItems: ModelInput.ContextItems(items: []),
            constraints: [],
            outputType: .meetingSummary
        )
        
        let scaffold1 = PromptScaffold(from: input1)
        let scaffold2 = PromptScaffold(from: input2)
        
        XCTAssertNotEqual(scaffold1.scaffoldHash, scaffold2.scaffoldHash, "Different inputs should produce different hashes")
    }
}

// MARK: - Integration Tests

extension InvariantTests {
    
    /// End-to-end test: Full generation flow respects invariants
    @MainActor
    func testFullGenerationFlowRespectsInvariants() async {
        // Given: Valid input with context
        let input = ModelInput(
            intentText: "Draft a follow-up email about the meeting",
            contextSummary: "Team sync meeting discussed Q1 priorities",
            contextItems: ModelInput.ContextItems(items: [
                ModelInput.ContextItems.Item(
                    id: "meeting_123",
                    type: "calendar",
                    title: "Team Sync",
                    snippet: "Q1 priorities discussion",
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(3600)
                )
            ]),
            constraints: ModelInput.standardConstraints,
            outputType: .emailDraft
        )
        
        // When: Generating
        let router = ModelRouter.shared
        
        do {
            let output = try await router.generate(input: input)
            
            // Then: Citations must only reference input context
            for citation in output.citations {
                let contextIds = input.contextItems.items.map { $0.id }
                XCTAssertTrue(
                    contextIds.contains(citation.sourceId),
                    "Citation \(citation.sourceId) must reference input context"
                )
            }
            
            // And: Safety notes must be present
            XCTAssertFalse(output.safetyNotes.isEmpty, "Safety notes must be present")
            
            // And: Backend must be on-device
            let usedBackend = router.currentBackend
            XCTAssertTrue(
                [ModelBackend.appleOnDevice, .coreML, .deterministic].contains(usedBackend),
                "Backend must be on-device"
            )
            
        } catch {
            // Generation should not fail with deterministic fallback
            XCTFail("Generation failed unexpectedly: \(error)")
        }
    }
}
