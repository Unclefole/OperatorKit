import Foundation

// ============================================================================
// SYNTHETIC FIXTURES (Phase 12D)
//
// Central synthetic data generators for testing.
// All data is deterministic, labeled, and contains NO real user content.
//
// ⚠️ THIS FILE CONTAINS SYNTHETIC TEST DATA ONLY
// ⚠️ NO REAL USER CONTENT, NAMES, EMAILS, OR DATES
// ⚠️ ALL VALUES ARE LABELED AS SYNTHETIC
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No real user content
// ❌ No real names, emails, addresses
// ❌ No real dates tied to humans
// ❌ No resemblance to production data
// ✅ Deterministic and reproducible
// ✅ Clearly labeled as synthetic
// ============================================================================

// MARK: - Synthetic Data Marker

/// Marker indicating synthetic test data
public enum SyntheticDataMarker {
    public static let prefix = "[SYNTHETIC]"
    public static let suffix = "[/SYNTHETIC]"
    
    public static func wrap(_ value: String) -> String {
        "\(prefix) \(value) \(suffix)"
    }
    
    public static func isSynthetic(_ value: String) -> Bool {
        value.contains(prefix) || value.contains("SYNTHETIC") || value.contains("TEST_")
    }
}

// MARK: - Deterministic Seed

/// Fixed seed for deterministic generation
public enum SyntheticSeed {
    public static let primary: UInt64 = 12345678901234567890
    public static let secondary: UInt64 = 98765432109876543210
    
    /// Deterministic UUID based on seed
    public static func uuid(index: Int) -> UUID {
        // Fixed UUIDs for testing - no randomness
        let fixedUUIDs = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
            UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
        ]
        return fixedUUIDs[index % fixedUUIDs.count]
    }
    
    /// Deterministic date (always same)
    public static func date(dayOffset: Int = 0) -> String {
        // Fixed synthetic date - not tied to any real event
        "2099-01-\(String(format: "%02d", (dayOffset % 28) + 1))"
    }
}

// MARK: - Synthetic Drafted Outcomes

public enum SyntheticDraftedOutcome {
    
    /// Synthetic intent types (labeled)
    public static let intentTypes = [
        "TEST_INTENT_TYPE_ALPHA",
        "TEST_INTENT_TYPE_BETA",
        "TEST_INTENT_TYPE_GAMMA"
    ]
    
    /// Synthetic output types (labeled)
    public static let outputTypes = [
        "TEST_OUTPUT_EMAIL_DRAFT",
        "TEST_OUTPUT_CALENDAR_EVENT",
        "TEST_OUTPUT_REMINDER"
    ]
    
    /// Synthetic draft status
    public enum Status: String, CaseIterable {
        case pending = "TEST_STATUS_PENDING"
        case approved = "TEST_STATUS_APPROVED"
        case rejected = "TEST_STATUS_REJECTED"
        case expired = "TEST_STATUS_EXPIRED"
    }
    
    /// Generate a synthetic drafted outcome record
    public static func fixture(index: Int) -> SyntheticDraftedOutcomeRecord {
        SyntheticDraftedOutcomeRecord(
            id: SyntheticSeed.uuid(index: index),
            intentType: intentTypes[index % intentTypes.count],
            outputType: outputTypes[index % outputTypes.count],
            status: Status.allCases[index % Status.allCases.count].rawValue,
            createdAtDayRounded: SyntheticSeed.date(dayOffset: index),
            schemaVersion: 1
        )
    }
}

public struct SyntheticDraftedOutcomeRecord: Codable {
    public let id: UUID
    public let intentType: String
    public let outputType: String
    public let status: String
    public let createdAtDayRounded: String
    public let schemaVersion: Int
    
    // Explicitly NO content fields:
    // ❌ body, subject, title, description, message, text
    // ❌ email, recipient, attendees, notes
}

// MARK: - Synthetic Policy Decisions

public enum SyntheticPolicyDecision {
    
    public enum Decision: String, CaseIterable {
        case allowed = "TEST_POLICY_ALLOWED"
        case blocked = "TEST_POLICY_BLOCKED"
        case limitReached = "TEST_POLICY_LIMIT_REACHED"
    }
    
    public enum Reason: String, CaseIterable {
        case withinLimits = "TEST_REASON_WITHIN_LIMITS"
        case quotaExceeded = "TEST_REASON_QUOTA_EXCEEDED"
        case policyDisabled = "TEST_REASON_POLICY_DISABLED"
        case tierRestriction = "TEST_REASON_TIER_RESTRICTION"
    }
    
    public static func fixture(index: Int) -> SyntheticPolicyDecisionRecord {
        SyntheticPolicyDecisionRecord(
            id: SyntheticSeed.uuid(index: index),
            decision: Decision.allCases[index % Decision.allCases.count].rawValue,
            reason: Reason.allCases[index % Reason.allCases.count].rawValue,
            evaluatedAtDayRounded: SyntheticSeed.date(dayOffset: index),
            schemaVersion: 1
        )
    }
}

public struct SyntheticPolicyDecisionRecord: Codable {
    public let id: UUID
    public let decision: String
    public let reason: String
    public let evaluatedAtDayRounded: String
    public let schemaVersion: Int
}

// MARK: - Synthetic Audit Trail Events

public enum SyntheticAuditEvent {
    
    public enum Kind: String, CaseIterable {
        case draftCreated = "TEST_AUDIT_DRAFT_CREATED"
        case approvalGranted = "TEST_AUDIT_APPROVAL_GRANTED"
        case executionCompleted = "TEST_AUDIT_EXECUTION_COMPLETED"
        case executionFailed = "TEST_AUDIT_EXECUTION_FAILED"
    }
    
    public enum Result: String, CaseIterable {
        case success = "TEST_RESULT_SUCCESS"
        case failure = "TEST_RESULT_FAILURE"
        case cancelled = "TEST_RESULT_CANCELLED"
    }
    
    public static func fixture(index: Int) -> SyntheticAuditEventRecord {
        SyntheticAuditEventRecord(
            id: SyntheticSeed.uuid(index: index),
            kind: Kind.allCases[index % Kind.allCases.count].rawValue,
            result: Result.allCases[index % Result.allCases.count].rawValue,
            createdAtDayRounded: SyntheticSeed.date(dayOffset: index),
            backendUsed: "TEST_BACKEND_ONDEVICE",
            tierAtTime: "TEST_TIER_FREE",
            schemaVersion: 1
        )
    }
}

public struct SyntheticAuditEventRecord: Codable {
    public let id: UUID
    public let kind: String
    public let result: String
    public let createdAtDayRounded: String
    public let backendUsed: String
    public let tierAtTime: String
    public let schemaVersion: Int
    
    // Explicitly NO content fields
}

// MARK: - Synthetic Pricing States

public enum SyntheticPricingState {
    
    public enum Tier: String, CaseIterable {
        case free = "TEST_TIER_FREE"
        case pro = "TEST_TIER_PRO"
        case team = "TEST_TIER_TEAM"
        case lifetimeSovereign = "TEST_TIER_LIFETIME_SOVEREIGN"
    }
    
    public static func fixture(tier: Tier) -> SyntheticPricingStateRecord {
        SyntheticPricingStateRecord(
            tier: tier.rawValue,
            weeklyLimit: tier == .free ? 25 : nil,
            isLifetime: tier == .lifetimeSovereign,
            teamSeats: tier == .team ? 3 : nil,
            schemaVersion: 1
        )
    }
}

public struct SyntheticPricingStateRecord: Codable {
    public let tier: String
    public let weeklyLimit: Int?
    public let isLifetime: Bool
    public let teamSeats: Int?
    public let schemaVersion: Int
}

// MARK: - Synthetic Team/Trial States

public enum SyntheticTeamState {
    
    public enum Role: String, CaseIterable {
        case owner = "TEST_ROLE_OWNER"
        case admin = "TEST_ROLE_ADMIN"
        case member = "TEST_ROLE_MEMBER"
    }
    
    public enum TrialStatus: String, CaseIterable {
        case notStarted = "TEST_TRIAL_NOT_STARTED"
        case active = "TEST_TRIAL_ACTIVE"
        case expired = "TEST_TRIAL_EXPIRED"
    }
    
    public static func fixture(index: Int) -> SyntheticTeamStateRecord {
        SyntheticTeamStateRecord(
            teamId: SyntheticSeed.uuid(index: index),
            role: Role.allCases[index % Role.allCases.count].rawValue,
            trialStatus: TrialStatus.allCases[index % TrialStatus.allCases.count].rawValue,
            trialDaysRemaining: index % 7,
            seatCount: (index % 5) + 3,
            schemaVersion: 1
        )
    }
}

public struct SyntheticTeamStateRecord: Codable {
    public let teamId: UUID
    public let role: String
    public let trialStatus: String
    public let trialDaysRemaining: Int
    public let seatCount: Int
    public let schemaVersion: Int
    
    // Explicitly NO identity fields:
    // ❌ teamName, memberName, memberEmail
}

// MARK: - Fixture Collections

public enum SyntheticFixtures {
    
    /// Generate a batch of drafted outcome fixtures
    public static func draftedOutcomes(count: Int) -> [SyntheticDraftedOutcomeRecord] {
        (0..<count).map { SyntheticDraftedOutcome.fixture(index: $0) }
    }
    
    /// Generate a batch of policy decision fixtures
    public static func policyDecisions(count: Int) -> [SyntheticPolicyDecisionRecord] {
        (0..<count).map { SyntheticPolicyDecision.fixture(index: $0) }
    }
    
    /// Generate a batch of audit event fixtures
    public static func auditEvents(count: Int) -> [SyntheticAuditEventRecord] {
        (0..<count).map { SyntheticAuditEvent.fixture(index: $0) }
    }
    
    /// Generate pricing state fixtures for all tiers
    public static func pricingStates() -> [SyntheticPricingStateRecord] {
        SyntheticPricingState.Tier.allCases.map { SyntheticPricingState.fixture(tier: $0) }
    }
    
    /// Generate a batch of team state fixtures
    public static func teamStates(count: Int) -> [SyntheticTeamStateRecord] {
        (0..<count).map { SyntheticTeamState.fixture(index: $0) }
    }
    
    /// Forbidden patterns that must never appear in synthetic data
    public static let forbiddenPatterns: [String] = [
        // Real names
        "@gmail.com", "@yahoo.com", "@outlook.com", "@icloud.com",
        "John", "Jane", "Smith", "Johnson",
        
        // Real content markers
        "Dear ", "Hi ", "Hello ", "Meeting with",
        "Call ", "Lunch ", "Dinner ",
        
        // Real dates
        "2024-", "2025-", "2026-01-", "January", "February",
        
        // PII patterns
        "555-", "(555)", "+1",
        
        // Real addresses
        "Street", "Avenue", "Road", "Lane"
    ]
    
    /// Validate that a string contains no forbidden patterns
    public static func validateNoForbiddenPatterns(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        for pattern in forbiddenPatterns {
            if lowercased.contains(pattern.lowercased()) {
                return false
            }
        }
        return true
    }
}
