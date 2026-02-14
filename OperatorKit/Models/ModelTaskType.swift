import Foundation

// ============================================================================
// MODEL TASK TYPE — TYPED TASK CLASSIFICATION
//
// Each task type defines quality, latency, and budget requirements.
// ModelRoutingPolicy uses these to select the cheapest sufficient provider.
//
// INVARIANT: Tasks are NON-ACTIONING — analysis/draft/proposal only.
// INVARIANT: No task type implies execution authority.
// ============================================================================

// MARK: - Quality Tier

public enum ModelQualityTier: String, Codable, Comparable, Sendable {
    case low    = "low"      // Templates, simple classification
    case medium = "medium"   // Structured prose, basic summarization
    case high   = "high"     // Complex drafting, nuanced analysis

    private var order: Int {
        switch self {
        case .low:    return 0
        case .medium: return 1
        case .high:   return 2
        }
    }

    public static func < (lhs: ModelQualityTier, rhs: ModelQualityTier) -> Bool {
        lhs.order < rhs.order
    }
}

// MARK: - Cost Tier

public enum ModelCostTier: String, Codable, Comparable, Sendable {
    case free      = "free"       // On-device only
    case cheap     = "cheap"      // Small cloud models (gpt-4o-mini, haiku)
    case standard  = "standard"   // Mid-tier (sonnet, gpt-4o)
    case expensive = "expensive"  // Large frontier models

    private var order: Int {
        switch self {
        case .free:      return 0
        case .cheap:     return 1
        case .standard:  return 2
        case .expensive: return 3
        }
    }

    public static func < (lhs: ModelCostTier, rhs: ModelCostTier) -> Bool {
        lhs.order < rhs.order
    }
}

// MARK: - Sensitivity Level

public enum ModelSensitivityLevel: String, Codable, Sendable {
    case localOnly      = "local_only"      // Must stay on device
    case cloudAllowed   = "cloud_allowed"   // Cloud permitted if needed
    case cloudPreferred = "cloud_preferred" // Prefer cloud for quality
}

// MARK: - Model Task Type

public enum ModelTaskType: String, Codable, CaseIterable, Sendable {
    case intentClassification     = "intent_classification"
    case planSynthesis            = "plan_synthesis"
    case draftEmail               = "draft_email"
    case summarizeMeeting         = "summarize_meeting"
    case extractActionItems       = "extract_action_items"
    case complianceRewrite        = "compliance_rewrite"
    case supportReply             = "support_reply"
    case marketingCampaignCopy    = "marketing_campaign_copy"
    case scoutAnalysis            = "scout_analysis"
    case proposalGeneration       = "proposal_generation"
    case extractInformation       = "extract_information"
    case webDocumentAnalysis      = "web_document_analysis"
    case researchBrief            = "research_brief"

    // MARK: - Requirements

    /// Minimum quality needed for acceptable output
    public var minQualityTier: ModelQualityTier {
        switch self {
        case .intentClassification:   return .low
        case .extractActionItems:     return .low
        case .scoutAnalysis:          return .low
        case .planSynthesis:          return .medium
        case .summarizeMeeting:       return .medium
        case .supportReply:           return .medium
        case .proposalGeneration:     return .medium
        case .draftEmail:             return .medium
        case .complianceRewrite:      return .high
        case .marketingCampaignCopy:  return .high
        case .extractInformation:     return .medium
        case .webDocumentAnalysis:    return .high
        case .researchBrief:          return .high
        }
    }

    /// Maximum acceptable latency in milliseconds
    public var maxLatencyMs: Int {
        switch self {
        case .intentClassification:   return 500
        case .extractActionItems:     return 2000
        case .scoutAnalysis:          return 3000
        case .planSynthesis:          return 3000
        case .summarizeMeeting:       return 5000
        case .supportReply:           return 5000
        case .proposalGeneration:     return 5000
        case .draftEmail:             return 8000
        case .complianceRewrite:      return 10000
        case .marketingCampaignCopy:  return 10000
        case .extractInformation:     return 8000
        case .webDocumentAnalysis:    return 15000
        case .researchBrief:          return 30000  // Research briefs need time
        }
    }

    /// Soft token limit for output
    public var maxTokensSoft: Int {
        switch self {
        case .intentClassification:   return 50
        case .extractActionItems:     return 500
        case .scoutAnalysis:          return 800
        case .planSynthesis:          return 1000
        case .summarizeMeeting:       return 1500
        case .supportReply:           return 800
        case .proposalGeneration:     return 2000
        case .draftEmail:             return 1500
        case .complianceRewrite:      return 2000
        case .marketingCampaignCopy:  return 3000
        case .extractInformation:     return 1500
        case .webDocumentAnalysis:    return 3000
        case .researchBrief:          return 4000   // Needs substantial output
        }
    }

    /// Default per-call budget in cents (USD)
    public var defaultBudgetCents: Int {
        switch self {
        case .intentClassification:   return 1    // $0.01
        case .extractActionItems:     return 3    // $0.03
        case .scoutAnalysis:          return 2    // $0.02
        case .planSynthesis:          return 5    // $0.05
        case .summarizeMeeting:       return 5    // $0.05
        case .supportReply:           return 5    // $0.05
        case .proposalGeneration:     return 8    // $0.08
        case .draftEmail:             return 5    // $0.05
        case .complianceRewrite:      return 15   // $0.15
        case .marketingCampaignCopy:  return 20   // $0.20
        case .extractInformation:     return 10   // $0.10
        case .webDocumentAnalysis:    return 25   // $0.25
        case .researchBrief:          return 30   // $0.30
        }
    }

    /// Whether this task requires JSON-structured output
    public var requiresJSON: Bool {
        switch self {
        case .intentClassification, .extractActionItems, .planSynthesis, .scoutAnalysis, .extractInformation:
            return true
        default:
            return false
        }
    }

    /// Default sensitivity level
    public var defaultSensitivity: ModelSensitivityLevel {
        switch self {
        case .intentClassification, .scoutAnalysis:
            return .localOnly
        case .extractActionItems, .planSynthesis, .summarizeMeeting, .proposalGeneration:
            return .cloudAllowed
        case .draftEmail, .supportReply, .complianceRewrite, .marketingCampaignCopy:
            return .cloudAllowed
        case .extractInformation:
            return .cloudAllowed
        case .webDocumentAnalysis:
            return .cloudPreferred
        case .researchBrief:
            return .cloudPreferred
        }
    }

    public var displayName: String {
        switch self {
        case .intentClassification:   return "Intent Classification"
        case .planSynthesis:          return "Plan Synthesis"
        case .draftEmail:             return "Draft Email"
        case .summarizeMeeting:       return "Summarize Meeting"
        case .extractActionItems:     return "Extract Action Items"
        case .complianceRewrite:      return "Compliance Rewrite"
        case .supportReply:           return "Support Reply"
        case .marketingCampaignCopy:  return "Marketing Campaign Copy"
        case .scoutAnalysis:          return "Scout Analysis"
        case .proposalGeneration:     return "Proposal Generation"
        case .extractInformation:     return "Extract Information"
        case .webDocumentAnalysis:    return "Web Document Analysis"
        case .researchBrief:          return "Research Brief"
        }
    }
}
