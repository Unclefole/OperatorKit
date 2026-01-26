import Foundation

// ============================================================================
// KNOWN LIMITATIONS (Phase 10Q)
//
// Static, explicit list of what OperatorKit does NOT do.
// Reduces App Review confusion, support tickets, and misinterpretation.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No excuses
// ❌ No roadmap promises
// ❌ No AI anthropomorphism
// ✅ Factual only
// ✅ Plain language
// ✅ App Store safe
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Known Limitation

public struct KnownLimitation: Identifiable, Codable, Equatable {
    
    public let id: String
    public let category: LimitationCategory
    public let statement: String
    public let explanation: String
    public let icon: String
    
    public init(
        id: String,
        category: LimitationCategory,
        statement: String,
        explanation: String,
        icon: String
    ) {
        self.id = id
        self.category = category
        self.statement = statement
        self.explanation = explanation
        self.icon = icon
    }
}

// MARK: - Limitation Category

public enum LimitationCategory: String, Codable, CaseIterable {
    case execution = "execution"
    case automation = "automation"
    case data = "data"
    case networking = "networking"
    case permissions = "permissions"
    
    public var displayName: String {
        switch self {
        case .execution: return "Execution"
        case .automation: return "Automation"
        case .data: return "Data"
        case .networking: return "Networking"
        case .permissions: return "Permissions"
        }
    }
    
    public var icon: String {
        switch self {
        case .execution: return "play.slash"
        case .automation: return "clock.badge.xmark"
        case .data: return "externaldrive.badge.xmark"
        case .networking: return "wifi.slash"
        case .permissions: return "lock.slash"
        }
    }
}

// MARK: - Known Limitations Registry

public enum KnownLimitations {
    
    /// All known limitations
    public static let all: [KnownLimitation] = [
        // Execution
        KnownLimitation(
            id: "no-background-execution",
            category: .execution,
            statement: "OperatorKit does not run in the background",
            explanation: "All operations require the app to be open and active.",
            icon: "moon.zzz"
        ),
        KnownLimitation(
            id: "no-auto-execution",
            category: .execution,
            statement: "OperatorKit does not execute actions without approval",
            explanation: "Every action requires explicit user approval before execution.",
            icon: "hand.raised"
        ),
        KnownLimitation(
            id: "no-scheduled-execution",
            category: .execution,
            statement: "OperatorKit does not schedule future actions",
            explanation: "Actions are executed immediately after approval, not scheduled.",
            icon: "calendar.badge.minus"
        ),
        
        // Automation
        KnownLimitation(
            id: "no-inbox-monitoring",
            category: .automation,
            statement: "OperatorKit does not monitor your inbox",
            explanation: "Email content is only accessed when you explicitly select it.",
            icon: "envelope.badge.shield.half.filled"
        ),
        KnownLimitation(
            id: "no-auto-reply",
            category: .automation,
            statement: "OperatorKit does not send replies automatically",
            explanation: "All emails are drafted and require your approval to send.",
            icon: "arrowshape.turn.up.left.circle"
        ),
        KnownLimitation(
            id: "no-trigger-automation",
            category: .automation,
            statement: "OperatorKit does not respond to triggers or events",
            explanation: "Operations only start when you initiate them.",
            icon: "bolt.slash"
        ),
        
        // Data
        KnownLimitation(
            id: "no-cloud-storage",
            category: .data,
            statement: "OperatorKit does not store your content in the cloud",
            explanation: "All drafts and context remain on your device unless you choose to sync.",
            icon: "icloud.slash"
        ),
        KnownLimitation(
            id: "no-learning",
            category: .data,
            statement: "OperatorKit does not learn from your data",
            explanation: "Your content is not used to train or improve models.",
            icon: "brain.head.profile"
        ),
        KnownLimitation(
            id: "no-analytics",
            category: .data,
            statement: "OperatorKit does not collect usage analytics",
            explanation: "No tracking, no telemetry, no behavioral data collection.",
            icon: "chart.bar.xaxis"
        ),
        
        // Networking
        KnownLimitation(
            id: "no-silent-network",
            category: .networking,
            statement: "OperatorKit does not make network requests without disclosure",
            explanation: "Network access is explicit and only for optional sync features.",
            icon: "network.slash"
        ),
        
        // Permissions
        KnownLimitation(
            id: "explicit-context-selection",
            category: .permissions,
            statement: "OperatorKit requires explicit user selection of context",
            explanation: "You choose what information to provide for each request.",
            icon: "hand.tap"
        ),
        KnownLimitation(
            id: "no-continuous-access",
            category: .permissions,
            statement: "OperatorKit does not maintain continuous access to your data",
            explanation: "Access is granted per-request and only for the data you select.",
            icon: "key.slash"
        )
    ]
    
    /// Limitations grouped by category
    public static var byCategory: [LimitationCategory: [KnownLimitation]] {
        Dictionary(grouping: all, by: { $0.category })
    }
    
    /// Validates limitations contain no banned words
    public static func validateNoBannedWords() -> [String] {
        let bannedWords = [
            "AI agent", "autonomous", "learns you", "personalizes automatically",
            "secure", "encrypted", "protected", "safe",
            "coming soon", "planned", "roadmap", "future"
        ]
        
        var violations: [String] = []
        
        for limitation in all {
            let combined = "\(limitation.statement) \(limitation.explanation)".lowercased()
            for word in bannedWords {
                if combined.contains(word.lowercased()) {
                    violations.append("Limitation '\(limitation.id)' contains banned phrase: \(word)")
                }
            }
        }
        
        return violations
    }
    
    /// Validates limitations are factual (no excuses, no promises)
    public static func validateFactualOnly() -> [String] {
        let excusePatterns = [
            "we're working on", "will be", "planned for", "coming in",
            "sorry", "unfortunately", "we apologize", "we hope"
        ]
        
        var violations: [String] = []
        
        for limitation in all {
            let combined = "\(limitation.statement) \(limitation.explanation)".lowercased()
            for pattern in excusePatterns {
                if combined.contains(pattern.lowercased()) {
                    violations.append("Limitation '\(limitation.id)' contains non-factual phrase: \(pattern)")
                }
            }
        }
        
        return violations
    }
}
