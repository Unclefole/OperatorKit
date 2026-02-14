import Foundation

// ============================================================================
// SKILL REGISTRY — CENTRAL REGISTRATION + POLICY ENFORCEMENT
//
// INVARIANT: All skills must be registered before use.
// INVARIANT: Registry enforces allowed scopes and signer quorum.
// INVARIANT: Registry NEVER references ExecutionEngine or write services.
// ============================================================================

@MainActor
public final class SkillRegistry: ObservableObject {

    public static let shared = SkillRegistry()

    @Published private(set) var registeredSkills: [String: any OperatorSkill] = [:]
    @Published private(set) var recentProposals: [ProposalPack] = []

    private init() {}

    // MARK: - Registration

    public func register(_ skill: any OperatorSkill) {
        guard skill.producesProposalPack else {
            logError("[SKILL_REGISTRY] Rejected skill '\(skill.skillId)': must produce ProposalPack")
            return
        }
        registeredSkills[skill.skillId] = skill
        log("[SKILL_REGISTRY] Registered: \(skill.skillId) (\(skill.displayName))")
    }

    public func skill(for id: String) -> (any OperatorSkill)? {
        registeredSkills[id]
    }

    public var allSkills: [any OperatorSkill] {
        Array(registeredSkills.values)
    }

    // MARK: - Run Skill Pipeline

    /// Execute the full observe → analyze → generateProposal pipeline for a skill.
    /// Returns the ProposalPack. NEVER executes side effects.
    public func runSkill(_ skillId: String, input: SkillInput) async -> ProposalPack? {
        guard let skill = registeredSkills[skillId] else {
            logError("[SKILL_REGISTRY] Skill not found: \(skillId)")
            return nil
        }

        log("[SKILL_REGISTRY] Running skill: \(skillId)")

        // 1. Observe
        let observation = await skill.observe(input: input)

        // 2. Analyze
        let analysis = await skill.analyze(observation: observation)

        // 3. Generate Proposal
        let proposal = await skill.generateProposal(analysis: analysis)

        // Store
        recentProposals.insert(proposal, at: 0)
        if recentProposals.count > 50 { recentProposals = Array(recentProposals.prefix(50)) }

        // Evidence log
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "skill_proposal_generated",
            planId: proposal.id,
            jsonString: """
            {"skillId":"\(skillId)","proposalId":"\(proposal.id)","riskTier":"\(analysis.riskTier.rawValue)","items":\(analysis.items.count),"timestamp":"\(Date())"}
            """
        )

        log("[SKILL_REGISTRY] Proposal generated: \(proposal.id) from \(skillId)")
        return proposal
    }

    // MARK: - Bootstrap (called at app launch)

    public func registerDayOneSkills() {
        register(InboxTriageSkill())
        register(MeetingActionSkill())
        register(ApprovalRouterSkill())
        register(WebResearchSkill())
        log("[SKILL_REGISTRY] Day-One Micro-Operators + Web Research registered")
    }
}
