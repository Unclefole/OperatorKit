import Foundation
import AppIntents

// ============================================================================
// INTENT DONATION MANAGER
//
// ARCHITECTURAL INVARIANT:
// ─────────────────────────
// Donations are made ONLY after:
// ✅ User explicitly approved the action
// ✅ ApprovalGate passed
// ✅ Execution completed successfully
//
// NEVER donate:
// ❌ Drafts (not yet approved)
// ❌ Synthetic intents (not user-initiated)
// ❌ Failed executions
// ❌ Low-confidence workflows
//
// PURPOSE:
// Donations train iOS to suggest OperatorKit at relevant moments.
// Quality > Quantity. Only donate high-signal completions.
// ============================================================================

/// Manages safe donation of completed intents to iOS
/// INVARIANT: Only donates after successful, user-approved execution
@MainActor
final class IntentDonationManager {

    static let shared = IntentDonationManager()

    private init() {}

    // MARK: - Donation Types

    /// Types of workflows eligible for donation
    enum DonationType: String {
        case draftEmail = "draft_email"
        case summarizeMeeting = "summarize_meeting"
        case createReminder = "create_reminder"
        case reviewDocument = "review_document"

        var isHighPriority: Bool {
            switch self {
            case .draftEmail, .summarizeMeeting:
                return true
            case .createReminder, .reviewDocument:
                return false
            }
        }
    }

    // MARK: - Donation Gate

    /// Validates that donation is safe and appropriate
    /// INVARIANT: All checks must pass before donation
    private func canDonate(
        wasApproved: Bool,
        wasSuccessful: Bool,
        confidence: Double,
        wasSynthetic: Bool
    ) -> Bool {
        // INVARIANT: Must have user approval
        guard wasApproved else {
            log("IntentDonation: Blocked - not approved")
            return false
        }

        // INVARIANT: Must have completed successfully
        guard wasSuccessful else {
            log("IntentDonation: Blocked - execution failed")
            return false
        }

        // INVARIANT: Must have high confidence
        guard confidence >= 0.65 else {
            log("IntentDonation: Blocked - low confidence (\(confidence))")
            return false
        }

        // INVARIANT: Must not be synthetic
        guard !wasSynthetic else {
            log("IntentDonation: Blocked - synthetic intent")
            return false
        }

        return true
    }

    // MARK: - Safe Donation Methods

    /// Donate a completed email workflow
    /// Call ONLY after ApprovalGate passed and execution succeeded
    func donateEmailCompletion(
        topic: String?,
        wasApproved: Bool,
        wasSuccessful: Bool,
        confidence: Double
    ) {
        guard canDonate(
            wasApproved: wasApproved,
            wasSuccessful: wasSuccessful,
            confidence: confidence,
            wasSynthetic: false
        ) else { return }

        let intent = HandleEmailIntent()
        intent.emailTopic = topic

        Task {
            do {
                try await intent.donate()
                log("IntentDonation: Email workflow donated successfully")
            } catch {
                log("IntentDonation: Email donation failed - \(error.localizedDescription)")
            }
        }
    }

    /// Donate a completed meeting workflow
    /// Call ONLY after ApprovalGate passed and execution succeeded
    func donateMeetingCompletion(
        topic: String?,
        wasApproved: Bool,
        wasSuccessful: Bool,
        confidence: Double
    ) {
        guard canDonate(
            wasApproved: wasApproved,
            wasSuccessful: wasSuccessful,
            confidence: confidence,
            wasSynthetic: false
        ) else { return }

        let intent = HandleMeetingIntent()
        intent.meetingTopic = topic

        Task {
            do {
                try await intent.donate()
                log("IntentDonation: Meeting workflow donated successfully")
            } catch {
                log("IntentDonation: Meeting donation failed - \(error.localizedDescription)")
            }
        }
    }

    /// Donate a general completed workflow
    /// Call ONLY after ApprovalGate passed and execution succeeded
    func donateGeneralCompletion(
        requestText: String,
        wasApproved: Bool,
        wasSuccessful: Bool,
        confidence: Double
    ) {
        guard canDonate(
            wasApproved: wasApproved,
            wasSuccessful: wasSuccessful,
            confidence: confidence,
            wasSynthetic: false
        ) else { return }

        let intent = HandleIntentIntent()
        intent.intentText = requestText

        Task {
            do {
                try await intent.donate()
                log("IntentDonation: General workflow donated successfully")
            } catch {
                log("IntentDonation: General donation failed - \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Convenience Method

    /// Donate based on intent type after successful execution
    /// INVARIANT: Only call after ApprovalGate.canExecute() returned true AND execution succeeded
    func donateCompletedWorkflow(
        intentType: IntentRequest.IntentType,
        requestText: String,
        confidence: Double
    ) {
        // All donations require approval (implicit from call site)
        let wasApproved = true
        let wasSuccessful = true

        switch intentType {
        case .draftEmail:
            donateEmailCompletion(
                topic: requestText,
                wasApproved: wasApproved,
                wasSuccessful: wasSuccessful,
                confidence: confidence
            )

        case .summarizeMeeting:
            donateMeetingCompletion(
                topic: requestText,
                wasApproved: wasApproved,
                wasSuccessful: wasSuccessful,
                confidence: confidence
            )

        case .extractActionItems, .reviewDocument, .createReminder, .researchBrief:
            donateGeneralCompletion(
                requestText: requestText,
                wasApproved: wasApproved,
                wasSuccessful: wasSuccessful,
                confidence: confidence
            )

        case .unknown:
            // Never donate unknown intents
            log("IntentDonation: Skipped - unknown intent type")
        }
    }
}
