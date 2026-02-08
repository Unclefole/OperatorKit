import Foundation

// ============================================================================
// SALES PLAYBOOK CONTENT (Phase 11B)
//
// Static, local sales playbook for founders.
// Generic, factual, no promises.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No promises ("guaranteed", "will replace", etc.)
// ❌ No hype
// ❌ No anthropomorphic language
// ✅ Generic content
// ✅ Factual statements
// ✅ Actionable guidance
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Playbook Section

public struct PlaybookSection: Identifiable, Codable {
    public let id: String
    public let title: String
    public let icon: String
    public let content: [String]
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
}

// MARK: - Playbook Objection

public struct PlaybookObjection: Identifiable, Codable {
    public let id: String
    public let objection: String
    public let response: String
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
}

// MARK: - Sales Playbook Content

public enum SalesPlaybookContent {
    
    public static let schemaVersion = 2  // Bumped for Phase 11C
    
    // MARK: - Who It's For
    
    public static let whoItsFor = PlaybookSection(
        id: "who-its-for",
        title: "Who It's For",
        icon: "person.2",
        content: [
            "Executive assistants managing calendars and communications",
            "Founders handling their own inbox and scheduling",
            "Operations teams drafting repetitive communications",
            "Anyone who drafts emails, tasks, or calendar events repeatedly"
        ],
        schemaVersion: PlaybookSection.currentSchemaVersion
    )
    
    // MARK: - Demo Script
    
    public static let demoScript = PlaybookSection(
        id: "demo-script",
        title: "2-Minute Demo Script",
        icon: "play.rectangle",
        content: [
            "1. Open OperatorKit and show the intent input",
            "2. Type a sample request (e.g., 'Schedule a meeting with Sarah next Tuesday')",
            "3. Show the draft preview - emphasize nothing runs yet",
            "4. Walk through the approval flow - highlight the explicit confirmation",
            "5. Show the audit trail in Customer Proof view",
            "6. Export the Buyer Proof Packet to demonstrate trust",
            "Key message: You see everything before it runs. Nothing is automatic."
        ],
        schemaVersion: PlaybookSection.currentSchemaVersion
    )
    
    // MARK: - Outbound Motions
    
    public static let outboundMotions = PlaybookSection(
        id: "outbound-motions",
        title: "3 Outbound Motions",
        icon: "paperplane",
        content: [
            "**Warm Intro**: Ask mutual connection to introduce. Lead with 'draft-first' and 'approval required' differentiators.",
            "**Cold Outbound**: Use procurement intro template. Focus on on-device processing and audit trail. Attach Buyer Proof Packet.",
            "**Pilot Follow-up**: After demo, send pilot proposal template. Include 7-day timeline and specific use cases discussed."
        ],
        schemaVersion: PlaybookSection.currentSchemaVersion
    )
    
    // MARK: - Objection Handling
    
    public static let objections: [PlaybookObjection] = [
        PlaybookObjection(
            id: "objection-ai-trust",
            objection: "We don't trust AI to handle our communications",
            response: "OperatorKit shows you a draft before anything runs. You approve every action. Nothing sends automatically.",
            schemaVersion: PlaybookObjection.currentSchemaVersion
        ),
        PlaybookObjection(
            id: "objection-data-privacy",
            objection: "Where does our data go?",
            response: "Processing happens on your device by default. Sync is optional and user-initiated. Export your data anytime.",
            schemaVersion: PlaybookObjection.currentSchemaVersion
        ),
        PlaybookObjection(
            id: "objection-price",
            objection: "Why is this a subscription?",
            response: "On-device product with no ads, no tracking. The subscription supports ongoing development and support.",
            schemaVersion: PlaybookObjection.currentSchemaVersion
        ),
        PlaybookObjection(
            id: "objection-existing-tools",
            objection: "We already have tools for this",
            response: "OperatorKit focuses on draft-first workflow with explicit approval. Compare the audit trail and control.",
            schemaVersion: PlaybookObjection.currentSchemaVersion
        ),
        PlaybookObjection(
            id: "objection-security-review",
            objection: "We need a security review first",
            response: "Export the Enterprise Readiness Packet. It includes safety contract, quality metrics, and policy configuration.",
            schemaVersion: PlaybookObjection.currentSchemaVersion
        )
    ]
    
    // MARK: - Close Paths
    
    public static let closePaths = PlaybookSection(
        id: "close-paths",
        title: "Close Paths",
        icon: "checkmark.seal",
        content: [
            "**Pro Self-Serve**: Direct to App Store. Best for individuals. Send pricing link.",
            "**Team Pilot**: Use pilot proposal template. 7-day trial, 3-5 users. Define success criteria upfront.",
            "**Enterprise**: Request security review. Provide Enterprise Readiness export. Schedule procurement call."
        ],
        schemaVersion: PlaybookSection.currentSchemaVersion
    )
    
    // MARK: - What to Export
    
    public static let whatToExport = PlaybookSection(
        id: "what-to-export",
        title: "What to Export",
        icon: "square.and.arrow.up",
        content: [
            "**Buyer Proof Packet**: Trust verification for prospects. Safety, quality, policy summaries.",
            "**Enterprise Readiness**: For procurement and security teams. Includes claim registry and compliance info.",
            "**Support Packet**: For troubleshooting. Diagnostics, quality gate, policy config.",
            "**Sales Kit Packet**: Combined artifact for outreach. All of the above in one export."
        ],
        schemaVersion: PlaybookSection.currentSchemaVersion
    )
    
    // MARK: - Team Procedure Sharing (Phase 11C)
    
    public static let teamProcedureSharing = PlaybookSection(
        id: "team-procedure-sharing",
        title: "Team = Procedure Sharing",
        icon: "doc.on.doc",
        content: [
            "Team tier is about sharing procedures, not user data.",
            "**What Team shares**: Policy templates, procedure definitions, quality summaries, diagnostics snapshots.",
            "**What Team does NOT share**: Drafts, calendar events, emails, personal memory, user content.",
            "**Minimum 3 seats**: Team requires 3+ users for governance value.",
            "**Monthly audit export**: Teams can export monthly audit summaries for compliance.",
            "Key message: 'Share how you work, not what you work on.'"
        ],
        schemaVersion: PlaybookSection.currentSchemaVersion
    )
    
    // MARK: - Lifetime Sovereign (Phase 11C)
    
    public static let lifetimeSovereign = PlaybookSection(
        id: "lifetime-sovereign",
        title: "Lifetime Sovereign Option",
        icon: "crown",
        content: [
            "One-time purchase alternative to Pro subscription.",
            "**Why Lifetime**: Some users prefer ownership over subscription models.",
            "**What it includes**: All Pro features, unlimited drafted outcomes, optional sync.",
            "**What it does NOT include**: Team governance, procedure sharing.",
            "**Pricing**: $249 one-time (no recurring charges).",
            "Key message: 'Own your workflow tool. No subscription fatigue.'"
        ],
        schemaVersion: PlaybookSection.currentSchemaVersion
    )
    
    // MARK: - All Sections
    
    public static let allSections: [PlaybookSection] = [
        whoItsFor,
        demoScript,
        outboundMotions,
        closePaths,
        whatToExport,
        teamProcedureSharing,
        lifetimeSovereign
    ]
    
    // MARK: - Validation
    
    /// Banned words that should not appear in playbook
    public static let bannedWords: [String] = [
        "guaranteed", "promise", "ensure", "will replace",
        "always works", "never fails", "perfect", "100%",
        "AI thinks", "AI learns", "AI decides",
        "secure", "encrypted", "protected"
    ]
    
    /// Validates playbook content contains no banned words
    public static func validateNoBannedWords() -> [String] {
        var violations: [String] = []
        
        for section in allSections {
            let combined = section.content.joined(separator: " ").lowercased()
            for word in bannedWords {
                if combined.contains(word.lowercased()) {
                    violations.append("Section '\(section.id)' contains banned word: \(word)")
                }
            }
        }
        
        for objection in objections {
            let combined = "\(objection.objection) \(objection.response)".lowercased()
            for word in bannedWords {
                if combined.contains(word.lowercased()) {
                    violations.append("Objection '\(objection.id)' contains banned word: \(word)")
                }
            }
        }
        
        return violations
    }
    
    /// Validates playbook contains no promises
    public static func validateNoPromises() -> [String] {
        let promisePatterns = [
            "we guarantee", "we promise", "you will always",
            "will definitely", "will certainly"
        ]
        
        var violations: [String] = []
        
        for section in allSections {
            let combined = section.content.joined(separator: " ").lowercased()
            for pattern in promisePatterns {
                if combined.contains(pattern.lowercased()) {
                    violations.append("Section '\(section.id)' contains promise: \(pattern)")
                }
            }
        }
        
        return violations
    }
}

// MARK: - Playbook Metadata (for export)

public struct SalesPlaybookMetadata: Codable {
    public let schemaVersion: Int
    public let sectionCount: Int
    public let objectionCount: Int
    public let sectionIds: [String]
    public let capturedAtDayRounded: String
    
    public init() {
        self.schemaVersion = SalesPlaybookContent.schemaVersion
        self.sectionCount = SalesPlaybookContent.allSections.count
        self.objectionCount = SalesPlaybookContent.objections.count
        self.sectionIds = SalesPlaybookContent.allSections.map { $0.id }
        self.capturedAtDayRounded = Self.dayRoundedNow()
    }
    
    private static func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
