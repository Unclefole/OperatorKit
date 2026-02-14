import Foundation

// ============================================================================
// SCOUT ENGINE — Read-Only Autonomous Analysis
//
// INVARIANT: ScoutEngine performs READ-ONLY operations. Zero side effects.
// INVARIANT: No imports of ExecutionEngine, ServiceAccessToken, or write Services.
// INVARIANT: No calls to CapabilityKernel.issueToken or issueHardenedToken.
// INVARIANT: Produces FindingPack from read-only signals only.
// ============================================================================

@MainActor
public final class ScoutEngine: ObservableObject {

    public static let shared = ScoutEngine()

    @Published private(set) var lastRunAt: Date?
    @Published private(set) var lastFindingPack: FindingPack?
    @Published private(set) var isRunning = false

    private init() {}

    // MARK: - Configuration

    public struct ScoutConfig {
        public let scope: ScoutScope
        public let maxFindings: Int
        public let policyDenialThreshold: Int     // N denials triggers finding
        public let policyDenialWindow: TimeInterval // M seconds
        public let includeProposalRequest: Bool    // If true, generate BG queue proposal request

        public init(
            scope: ScoutScope = .full,
            maxFindings: Int = 20,
            policyDenialThreshold: Int = 5,
            policyDenialWindow: TimeInterval = 3600,
            includeProposalRequest: Bool = false
        ) {
            self.scope = scope
            self.maxFindings = maxFindings
            self.policyDenialThreshold = policyDenialThreshold
            self.policyDenialWindow = policyDenialWindow
            self.includeProposalRequest = includeProposalRequest
        }

        public static let `default` = ScoutConfig()
    }

    // MARK: - Run

    public func run(config: ScoutConfig = .default) async -> FindingPack {
        isRunning = true
        defer { isRunning = false }

        let runId = UUID()
        var findings: [Finding] = []
        var evidenceRefs: [EvidenceRef] = []
        var actions: [RecommendedAction] = []

        log("[SCOUT] Run started: scope=\(config.scope.rawValue), runId=\(runId)")

        // ── Heuristic 1: Integrity Check ────────────────────
        if config.scope == .full || config.scope == .security {
            let (f, refs, acts) = checkIntegrity()
            findings.append(contentsOf: f)
            evidenceRefs.append(contentsOf: refs)
            actions.append(contentsOf: acts)
        }

        // ── Heuristic 2: Policy Denial Spike ────────────────
        if config.scope == .full || config.scope == .operations {
            let (f, refs, acts) = checkPolicyDenials(threshold: config.policyDenialThreshold, window: config.policyDenialWindow)
            findings.append(contentsOf: f)
            evidenceRefs.append(contentsOf: refs)
            actions.append(contentsOf: acts)
        }

        // ── Heuristic 3: Key Lifecycle ──────────────────────
        if config.scope == .full || config.scope == .security {
            let (f, refs, acts) = checkKeyLifecycle()
            findings.append(contentsOf: f)
            evidenceRefs.append(contentsOf: refs)
            actions.append(contentsOf: acts)
        }

        // ── Heuristic 4: Device Trust State ─────────────────
        if config.scope == .full || config.scope == .security {
            let (f, refs, acts) = checkDeviceTrust()
            findings.append(contentsOf: f)
            evidenceRefs.append(contentsOf: refs)
            actions.append(contentsOf: acts)
        }

        // ── Heuristic 5: Budget/Cloud Status ────────────────
        if config.scope == .full || config.scope == .operations {
            let (f, refs, acts) = checkBudgetAndCloud()
            findings.append(contentsOf: f)
            evidenceRefs.append(contentsOf: refs)
            actions.append(contentsOf: acts)
        }

        // ── Heuristic 6: Audit Chain / Mirror ───────────────
        if config.scope == .full || config.scope == .compliance {
            let (f, refs, acts) = checkAuditChain()
            findings.append(contentsOf: f)
            evidenceRefs.append(contentsOf: refs)
            actions.append(contentsOf: acts)
        }

        // ── Heuristic 7: Network Policy Status ──────────────
        if config.scope == .full || config.scope == .security {
            let (f, refs, acts) = checkNetworkPolicy()
            findings.append(contentsOf: f)
            evidenceRefs.append(contentsOf: refs)
            actions.append(contentsOf: acts)
        }

        // Trim to max
        let trimmed = Array(findings.prefix(config.maxFindings))

        // Compute overall severity
        let overallSeverity = trimmed.map(\.category).reduce(FindingSeverity.nominal) { current, _ in
            if trimmed.contains(where: { isCritical($0) }) { return .critical }
            if trimmed.contains(where: { isWarning($0) }) { return .warning }
            return trimmed.isEmpty ? .nominal : .info
        }

        let summary = buildSummary(findings: trimmed, severity: overallSeverity)

        let pack = FindingPack(
            scoutRunId: runId,
            scope: config.scope,
            severity: overallSeverity,
            summary: summary,
            findings: trimmed,
            evidenceRefs: evidenceRefs,
            recommendedActions: actions
        )

        lastRunAt = Date()
        lastFindingPack = pack

        // Evidence log (read-safe — logGenericArtifact is append-only)
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "scout_run_completed",
            planId: runId,
            jsonString: """
            {"runId":"\(runId)","scope":"\(config.scope.rawValue)","findingCount":\(trimmed.count),"severity":"\(overallSeverity.rawValue)","timestamp":"\(Date())"}
            """
        )

        log("[SCOUT] Run completed: \(trimmed.count) findings, severity=\(overallSeverity.rawValue)")
        return pack
    }

    // =========================================================================
    // HEURISTICS (Read-Only)
    // =========================================================================

    private typealias HeuristicResult = ([Finding], [EvidenceRef], [RecommendedAction])

    // ── 1. Integrity ────────────────────────────────────────

    private func checkIntegrity() -> HeuristicResult {
        var findings: [Finding] = []
        var refs: [EvidenceRef] = []
        var actions: [RecommendedAction] = []

        let guard_ = KernelIntegrityGuard.shared

        if guard_.isLocked {
            findings.append(Finding(
                title: "System in LOCKDOWN",
                detail: "KernelIntegrityGuard reports LOCKDOWN posture. All execution blocked.",
                category: .integrityWarning,
                confidence: 1.0,
                impactedAssets: ["execution_pipeline", "capability_kernel"],
                signals: ["KernelIntegrityGuard.isLocked == true"]
            ))
            actions.append(RecommendedAction(
                label: "Review Integrity Incident",
                nextStep: "Navigate to System Integrity to diagnose and recover",
                requiresHumanApproval: true,
                deepLinks: [ScoutDeepLink(label: "Open Integrity", route: "operatorkit://integrity")]
            ))
        } else if guard_.systemPosture == .degraded {
            findings.append(Finding(
                title: "System in DEGRADED posture",
                detail: "One or more integrity checks show warnings. Review recommended.",
                category: .integrityWarning,
                confidence: 0.8,
                impactedAssets: ["KernelIntegrityGuard"],
                signals: ["systemPosture == degraded"]
            ))
        }

        if let report = guard_.lastReport, !report.overallPassed {
            for check in report.failedChecks {
                refs.append(EvidenceRef(type: "integrity_check", refId: check.name))
            }
        }

        return (findings, refs, actions)
    }

    // ── 2. Policy Denials ───────────────────────────────────

    private func checkPolicyDenials(threshold: Int, window: TimeInterval) -> HeuristicResult {
        var findings: [Finding] = []
        var refs: [EvidenceRef] = []
        var actions: [RecommendedAction] = []

        // Query recent evidence for violation entries
        let windowStart = Date().addingTimeInterval(-window)
        if let entries = try? EvidenceEngine.shared.queryByDateRange(from: windowStart, to: Date()) {
            let violations = entries.filter { $0.type == .violation }

            if violations.count >= threshold {
                findings.append(Finding(
                    title: "Policy denial spike detected",
                    detail: "\(violations.count) policy violations in the last \(Int(window / 60)) minutes. Threshold: \(threshold).",
                    category: .policyDenialSpike,
                    confidence: 0.9,
                    impactedAssets: ["policy_engine", "execution_pipeline"],
                    signals: violations.prefix(5).map { "violation_\($0.id)" }
                ))
                for v in violations.prefix(5) {
                    refs.append(EvidenceRef(type: "evidence_entry", refId: v.id.uuidString, timestamp: v.createdAt))
                }
                actions.append(RecommendedAction(
                    label: "Review Recent Denials",
                    nextStep: "Check audit trail for repeated unauthorized attempts",
                    deepLinks: [ScoutDeepLink(label: "Open Audit", route: "operatorkit://audit-status")]
                ))
            }
        }

        return (findings, refs, actions)
    }

    // ── 3. Key Lifecycle ────────────────────────────────────

    private func checkKeyLifecycle() -> HeuristicResult {
        var findings: [Finding] = []
        var refs: [EvidenceRef] = []
        var actions: [RecommendedAction] = []

        let epochMgr = TrustEpochManager.shared
        let epoch = epochMgr.trustEpoch
        let keyVersion = epochMgr.activeKeyVersion

        if !epochMgr.revokedKeyVersions.isEmpty {
            findings.append(Finding(
                title: "Revoked key versions present",
                detail: "Key versions \(epochMgr.revokedKeyVersions) have been revoked. Current: v\(keyVersion), epoch: \(epoch).",
                category: .keyLifecycle,
                confidence: 0.7,
                impactedAssets: ["TrustEpochManager"],
                signals: ["revokedVersions=\(epochMgr.revokedKeyVersions)", "epoch=\(epoch)"]
            ))
            refs.append(EvidenceRef(type: "trust_epoch", refId: "epoch_\(epoch)"))

            if EnterpriseFeatureFlags.orgCoSignEnabled {
                actions.append(RecommendedAction(
                    label: "Confirm org co-signer alignment",
                    nextStep: "Ensure org authority is aware of key rotation",
                    requiresHumanApproval: true
                ))
            }
        }

        return (findings, refs, actions)
    }

    // ── 4. Device Trust ─────────────────────────────────────

    private func checkDeviceTrust() -> HeuristicResult {
        var findings: [Finding] = []
        var refs: [EvidenceRef] = []
        var actions: [RecommendedAction] = []

        let registry = TrustedDeviceRegistry.shared
        let revokedDevices = registry.devices.filter { $0.trustState == .revoked }
        let suspendedDevices = registry.devices.filter { $0.trustState == .suspended }

        if !revokedDevices.isEmpty {
            findings.append(Finding(
                title: "\(revokedDevices.count) device(s) revoked",
                detail: "Revoked devices: \(revokedDevices.map { $0.displayName }.joined(separator: ", "))",
                category: .deviceTrust,
                confidence: 1.0,
                impactedAssets: revokedDevices.map { $0.displayName },
                signals: revokedDevices.map { "revoked:\($0.devicePublicKeyFingerprint.prefix(12))" }
            ))
            for d in revokedDevices {
                refs.append(EvidenceRef(type: "device_revocation", refId: d.devicePublicKeyFingerprint.prefix(16).description))
            }
        }

        if !suspendedDevices.isEmpty {
            findings.append(Finding(
                title: "\(suspendedDevices.count) device(s) suspended",
                detail: "Suspended devices may need admin review.",
                category: .deviceTrust,
                confidence: 0.8,
                impactedAssets: suspendedDevices.map { $0.displayName }
            ))
            actions.append(RecommendedAction(
                label: "Review Trust Registry",
                nextStep: "Reinstate or revoke suspended devices",
                deepLinks: [ScoutDeepLink(label: "Open Trust Registry", route: "operatorkit://trust-registry")]
            ))
        }

        if !registry.isCurrentDeviceTrusted {
            findings.append(Finding(
                title: "Current device NOT trusted",
                detail: "This device is not in the trusted registry. All execution is blocked.",
                category: .deviceTrust,
                confidence: 1.0,
                impactedAssets: ["CurrentDevice"],
                signals: ["isCurrentDeviceTrusted=false"]
            ))
        }

        return (findings, refs, actions)
    }

    // ── 5. Budget & Cloud ───────────────────────────────────

    private func checkBudgetAndCloud() -> HeuristicResult {
        var findings: [Finding] = []
        let refs: [EvidenceRef] = []
        let actions: [RecommendedAction] = []

        if EnterpriseFeatureFlags.cloudKillSwitch {
            findings.append(Finding(
                title: "Cloud kill switch ACTIVE",
                detail: "All outbound cloud model calls are blocked by admin kill switch.",
                category: .budgetThrottling,
                confidence: 1.0,
                impactedAssets: ["ModelRouter", "OpenAIClient", "AnthropicClient"],
                signals: ["cloudKillSwitch=true"]
            ))
        }

        if IntelligenceFeatureFlags.cloudModelsEnabled && !EnterpriseFeatureFlags.cloudKillSwitch {
            findings.append(Finding(
                title: "Cloud models enabled",
                detail: "Cloud AI calls are active. Ensure budget governor is configured.",
                category: .budgetThrottling,
                confidence: 0.6,
                signals: ["cloudModelsEnabled=true"]
            ))
        }

        return (findings, refs, actions)
    }

    // ── 6. Audit Chain ──────────────────────────────────────

    private func checkAuditChain() -> HeuristicResult {
        var findings: [Finding] = []
        var refs: [EvidenceRef] = []
        var actions: [RecommendedAction] = []

        // Check chain integrity (read-only)
        if let report = try? EvidenceEngine.shared.verifyChainIntegrity() {
            let violationCount = report.violations.count
            if !report.overallValid {
                findings.append(Finding(
                    title: "Evidence chain integrity FAILED",
                    detail: "Hash chain verification detected \(violationCount) violation(s) across \(report.totalEntries) entries.",
                    category: .auditDivergence,
                    confidence: 1.0,
                    impactedAssets: ["EvidenceEngine"],
                    signals: ["violations=\(violationCount)", "totalEntries=\(report.totalEntries)"]
                ))
                refs.append(EvidenceRef(type: "chain_integrity", refId: "report"))
                actions.append(RecommendedAction(
                    label: "Export Audit Chain for Forensics",
                    nextStep: "Export evidence and compare with mirror",
                    deepLinks: [ScoutDeepLink(label: "Open Audit Status", route: "operatorkit://audit-status")]
                ))
            } else {
                findings.append(Finding(
                    title: "Evidence chain integrity OK",
                    detail: "\(report.totalEntries) entries, chain verified.",
                    category: .systemHealth,
                    confidence: 1.0,
                    signals: ["totalEntries=\(report.totalEntries)"]
                ))
            }
        }

        // Mirror sync status (read-only)
        let mirrorClient = EvidenceMirrorClient.shared
        if mirrorClient.syncStatus == .divergent {
            findings.append(Finding(
                title: "Audit mirror DIVERGENCE detected",
                detail: "Local evidence chain differs from remote mirror.",
                category: .auditDivergence,
                confidence: 1.0,
                impactedAssets: ["EvidenceMirror"],
                signals: ["syncStatus=divergent"]
            ))
        }

        return (findings, refs, actions)
    }

    // ── 7. Network Policy ───────────────────────────────────

    private func checkNetworkPolicy() -> HeuristicResult {
        var findings: [Finding] = []

        let mode = NetworkPolicyEnforcer.shared.mode
        findings.append(Finding(
            title: "Network policy: \(mode.rawValue)",
            detail: "Current egress mode is \(mode.rawValue).",
            category: .systemHealth,
            confidence: 1.0,
            signals: ["networkMode=\(mode.rawValue)"]
        ))

        return (findings, [], [])
    }

    // =========================================================================
    // HELPERS
    // =========================================================================

    private func isCritical(_ f: Finding) -> Bool {
        f.category == .integrityWarning || f.category == .auditDivergence
    }

    private func isWarning(_ f: Finding) -> Bool {
        f.category == .policyDenialSpike || f.category == .deviceTrust || f.category == .keyLifecycle
    }

    private func buildSummary(findings: [Finding], severity: FindingSeverity) -> String {
        let critCount = findings.filter { isCritical($0) }.count
        let warnCount = findings.filter { isWarning($0) }.count
        let infoCount = findings.count - critCount - warnCount

        if findings.isEmpty {
            return "Scout scan complete. System nominal — no findings."
        }
        return "Scout scan: \(findings.count) finding(s) — \(critCount) critical, \(warnCount) warning, \(infoCount) info."
    }
}
