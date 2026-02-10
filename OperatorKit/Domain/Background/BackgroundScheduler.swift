import Foundation
import BackgroundTasks

// ============================================================================
// BACKGROUND SCHEDULER — BGProcessingTask Integration
//
// INVARIANT: Background execution NEVER reaches ExecutionEngine or Services.
// INVARIANT: Background execution NEVER issues AuthorizationTokens.
// INVARIANT: Only intelligence preparation + audit mirroring.
// ============================================================================

public enum BackgroundScheduler {

    public static let proposalTaskIdentifier = "com.operatorkit.bg.prepare-proposals"
    public static let mirrorTaskIdentifier = "com.operatorkit.bg.mirror-attestation"
    public static let scoutTaskIdentifier = "com.operatorkit.bg.scout"

    // MARK: - Registration (call at app launch)

    public static func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: proposalTaskIdentifier,
            using: nil
        ) { task in
            guard let bgTask = task as? BGProcessingTask else { return }
            handleProposalTask(bgTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: mirrorTaskIdentifier,
            using: nil
        ) { task in
            guard let bgTask = task as? BGProcessingTask else { return }
            handleMirrorTask(bgTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: scoutTaskIdentifier,
            using: nil
        ) { task in
            guard let bgTask = task as? BGProcessingTask else { return }
            handleScoutTask(bgTask)
        }

        log("[BG_SCHEDULER] Background tasks registered (including scout)")
    }

    // MARK: - Scheduling

    public static func scheduleProposalPreparation() {
        let request = BGProcessingTaskRequest(identifier: proposalTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min

        do {
            try BGTaskScheduler.shared.submit(request)
            log("[BG_SCHEDULER] Proposal preparation scheduled")
        } catch {
            logError("[BG_SCHEDULER] Failed to schedule proposal task: \(error)")
        }
    }

    public static func scheduleMirrorAttestation() {
        let request = BGProcessingTaskRequest(identifier: mirrorTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour

        do {
            try BGTaskScheduler.shared.submit(request)
            log("[BG_SCHEDULER] Mirror attestation scheduled")
        } catch {
            logError("[BG_SCHEDULER] Failed to schedule mirror task: \(error)")
        }
    }

    public static func scheduleScoutRun() {
        let request = BGProcessingTaskRequest(identifier: scoutTaskIdentifier)
        request.requiresNetworkConnectivity = false // Scout is read-only
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60 * 60) // 2 hours

        do {
            try BGTaskScheduler.shared.submit(request)
            log("[BG_SCHEDULER] Scout run scheduled")
        } catch {
            logError("[BG_SCHEDULER] Failed to schedule scout task: \(error)")
        }
    }

    // MARK: - Handlers

    private static func handleScoutTask(_ task: BGProcessingTask) {
        // Re-schedule next run
        scheduleScoutRun()

        let workTask = Task { @MainActor in
            guard EnterpriseFeatureFlags.scoutModeEnabled else {
                log("[BG_SCHEDULER] Scout mode disabled — skipping")
                task.setTaskCompleted(success: true)
                return
            }

            let pack = await ScoutEngine.shared.run()
            FindingPackStore.shared.save(pack)

            // Slack delivery if dual-gate enabled
            if EnterpriseFeatureFlags.slackDeliveryPermitted {
                await SlackNotifier.shared.sendFindingPack(pack)
            }

            // Local notification
            NotificationBridge.shared.scheduleGeneric(
                title: "Scout Findings",
                body: pack.summary
            )

            log("[BG_SCHEDULER] Scout task completed: \(pack.findings.count) findings")
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private static func handleProposalTask(_ task: BGProcessingTask) {
        // Schedule the next occurrence
        scheduleProposalPreparation()

        let workTask = Task { @MainActor in
            let processed = await BackgroundTaskQueue.shared.processAllPending()
            log("[BG_SCHEDULER] Proposal task completed: \(processed) task(s) processed")
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private static func handleMirrorTask(_ task: BGProcessingTask) {
        scheduleMirrorAttestation()

        let workTask = Task { @MainActor in
            _ = await EvidenceMirror.shared.createAttestation()
            log("[BG_SCHEDULER] Mirror attestation task completed")
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
