import Foundation

// ============================================================================
// USAGE MESSAGES (Phase 10F)
//
// Centralized, user-facing messages for rate shaping and usage discipline.
// All messages follow these principles:
//
// ✅ Honest and factual
// ✅ Non-punitive
// ✅ No moralizing or threats
// ✅ Clear distinction between limits and safety rules
// ✅ Helpful suggestions
//
// See: docs/SAFETY_CONTRACT.md (Section 15)
// ============================================================================

// MARK: - Usage Messages

/// User-facing messages for usage discipline
public enum UsageMessages {
    
    // MARK: - Rate Shaping
    
    /// Message when user should wait briefly
    public static func waitBriefly(seconds: Int) -> String {
        if seconds <= 5 {
            return "Please wait a moment."
        } else if seconds <= 30 {
            return "Please wait about \(seconds) seconds."
        } else {
            let minutes = (seconds + 59) / 60
            return "Please wait about \(minutes) \(minutes == 1 ? "minute" : "minutes")."
        }
    }
    
    /// Message for burst detection
    public static let burstDetected = """
        You've been running several actions quickly. \
        Taking a short break can help ensure consistent results.
        """
    
    /// Message for heavy usage
    public static let heavyUsage = """
        Your usage is elevated. Everything is working normally, \
        but you may want to pace yourself.
        """
    
    // MARK: - Limits
    
    /// Message when approaching weekly limit
    public static func approachingLimit(remaining: Int) -> String {
        "You have \(remaining) executions left this week."
    }
    
    /// Message when weekly limit reached (Free tier)
    public static let limitReached = """
        You've reached your weekly execution limit. \
        Your limit resets next week, or you can upgrade for unlimited usage.
        """
    
    /// Message explaining limits (for Free users)
    public static let limitsExplanation = """
        Free accounts have a weekly limit to ensure fair access for everyone. \
        Upgrade to Pro or Team for unlimited executions.
        """
    
    // MARK: - Abuse Detection (Non-Punitive)
    
    /// Message for repeated intent (hash match)
    public static let repeatedRequest = """
        You've made this request several times recently. \
        If the results weren't what you expected, try rephrasing your request.
        """
    
    /// Message for rapid-fire detection
    public static let rapidFire = """
        You're running actions very quickly. \
        Consider reviewing each result before starting the next action.
        """
    
    // MARK: - Cost Visibility
    
    /// Explanation of usage units
    public static let usageUnitsExplanation = """
        Usage units are an approximate measure of computational work. \
        They're for your reference only and don't reflect actual costs.
        """
    
    /// Message for elevated usage level
    public static func usageLevel(_ level: UsageLevel) -> String {
        switch level {
        case .minimal:
            return "Your usage is minimal."
        case .moderate:
            return "Your usage is moderate."
        case .significant:
            return "Your usage is significant."
        case .heavy:
            return "Your usage is heavy."
        }
    }
    
    // MARK: - Team-Specific
    
    /// Message for team artifact limit
    public static let teamArtifactLimit = """
        You've reached the daily limit for team artifacts. \
        Try again tomorrow.
        """
    
    /// Message explaining team sharing
    public static let teamSharingExplanation = """
        Teams share governance artifacts only. \
        Your drafts, memory, and execution history are never shared.
        """
    
    // MARK: - Upgrade Prompts (Non-Pushy)
    
    /// Gentle upgrade prompt
    public static let upgradePrompt = """
        Consider upgrading for unlimited executions and additional features.
        """
    
    /// Team upgrade prompt
    public static let teamUpgradePrompt = """
        Team tier lets you share policy templates and quality metrics with your organization.
        """
    
    // MARK: - Safety vs Limits Distinction
    
    /// Explains the difference between limits and safety rules
    public static let safetyVsLimits = """
        Rate limits are about fair usage and preventing accidents. \
        Safety rules (like approval before actions) are about keeping you in control.
        """
    
    /// Clarifies that limits don't affect safety
    public static let limitsDoNotAffectSafety = """
        Hitting your usage limit doesn't affect safety. \
        All approvals and confirmations work the same regardless of your tier.
        """
}

// MARK: - Message Builder

/// Builds contextual messages
public struct UsageMessageBuilder {
    
    /// Builds a rate shaping message
    public static func rateShaping(result: RateShapeResult) -> String? {
        guard let suggestedWait = result.suggestedWaitSeconds else {
            return nil
        }
        
        if result.intensityLevel == .heavy {
            return "\(UsageMessages.burstDetected) \(UsageMessages.waitBriefly(seconds: suggestedWait))"
        } else {
            return UsageMessages.waitBriefly(seconds: suggestedWait)
        }
    }
    
    /// Builds a limit message
    public static func limitStatus(tier: SubscriptionTier, remaining: Int?) -> String {
        if let remaining = remaining {
            if remaining <= 0 {
                return UsageMessages.limitReached
            } else if remaining <= 5 {
                return UsageMessages.approachingLimit(remaining: remaining)
            }
        }
        return "" // No message needed
    }
    
    /// Builds an abuse detection message
    public static func abuseDetection(result: AbuseCheckResult) -> String? {
        guard result.abuseDetected else { return nil }
        
        switch result.abuseType {
        case .intentRepetition:
            return UsageMessages.repeatedRequest
        case .rapidFire, .burstPattern:
            return UsageMessages.rapidFire
        case .unusualTiming:
            return result.message
        case .none:
            return nil
        }
    }
}

// MARK: - Callout Types

/// Types of usage callouts (for UI styling)
public enum UsageCalloutType {
    case info       // Blue, informational
    case warning    // Orange, attention needed
    case limit      // Red, limit reached
    case success    // Green, good to go
    
    public var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .limit: return "xmark.circle"
        case .success: return "checkmark.circle"
        }
    }
    
    public var color: String {
        switch self {
        case .info: return "blue"
        case .warning: return "orange"
        case .limit: return "red"
        case .success: return "green"
        }
    }
}

// MARK: - Usage Callout

/// A callout to display to the user
public struct UsageCallout {
    public let type: UsageCalloutType
    public let message: String
    public let dismissable: Bool
    
    public init(type: UsageCalloutType, message: String, dismissable: Bool = true) {
        self.type = type
        self.message = message
        self.dismissable = dismissable
    }
    
    /// Creates callout from rate shape result
    public static func fromRateShape(_ result: RateShapeResult) -> UsageCallout? {
        guard let message = result.message else { return nil }
        
        let type: UsageCalloutType
        switch result.intensityLevel {
        case .heavy:
            type = result.shouldProceed ? .warning : .limit
        case .elevated:
            type = .warning
        default:
            type = .info
        }
        
        return UsageCallout(type: type, message: message, dismissable: result.shouldProceed)
    }
    
    /// Creates callout from abuse check result
    public static func fromAbuseCheck(_ result: AbuseCheckResult) -> UsageCallout? {
        guard result.abuseDetected, let message = result.message else { return nil }
        
        return UsageCallout(
            type: result.shouldBlock ? .limit : .warning,
            message: message,
            dismissable: !result.shouldBlock
        )
    }
}
