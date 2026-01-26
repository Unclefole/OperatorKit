import Foundation

// ============================================================================
// REFERRAL LEDGER (Phase 11A)
//
// Local-only tracking of referral actions.
// Counts only. No identities. No recipient info. No message content.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user identities
// ❌ No recipient info
// ❌ No message content
// ❌ No networking
// ✅ Counts only
// ✅ Day-rounded timestamps
// ✅ Local-only storage
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Referral Action

public enum ReferralAction: String, Codable, CaseIterable {
    case viewed = "viewed"
    case shareTapped = "share_tapped"
    case copyTapped = "copy_tapped"
    case inviteEmailOpened = "invite_email_opened"
    case inviteMessageOpened = "invite_message_opened"
    
    public var displayName: String {
        switch self {
        case .viewed: return "Viewed"
        case .shareTapped: return "Share Tapped"
        case .copyTapped: return "Copy Tapped"
        case .inviteEmailOpened: return "Email Opened"
        case .inviteMessageOpened: return "Message Opened"
        }
    }
}

// MARK: - Referral Ledger Entry

public struct ReferralLedgerEntry: Codable, Equatable {
    public let action: ReferralAction
    public let count: Int
    public let lastOccurredDayRounded: String
    
    public init(action: ReferralAction, count: Int, lastOccurredDayRounded: String) {
        self.action = action
        self.count = count
        self.lastOccurredDayRounded = lastOccurredDayRounded
    }
}

// MARK: - Referral Ledger Summary

public struct ReferralLedgerSummary: Codable, Equatable {
    public let totalShares: Int
    public let totalCopies: Int
    public let totalEmailInvites: Int
    public let totalMessageInvites: Int
    public let totalViews: Int
    public let lastActivityDayRounded: String?
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    public var totalActions: Int {
        totalShares + totalCopies + totalEmailInvites + totalMessageInvites
    }
}

// MARK: - Referral Ledger Store

@MainActor
public final class ReferralLedger: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = ReferralLedger()
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let storageKeyPrefix = "com.operatorkit.referral.ledger"
    
    // MARK: - State
    
    @Published public private(set) var shareTappedCount: Int = 0
    @Published public private(set) var copyTappedCount: Int = 0
    @Published public private(set) var inviteEmailOpenedCount: Int = 0
    @Published public private(set) var inviteMessageOpenedCount: Int = 0
    @Published public private(set) var viewedCount: Int = 0
    @Published public private(set) var lastActivityDayRounded: String?
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadCounts()
    }
    
    // MARK: - Recording
    
    public func recordAction(_ action: ReferralAction) {
        let today = dayRoundedNow()
        
        switch action {
        case .viewed:
            viewedCount += 1
            defaults.set(viewedCount, forKey: key(for: .viewed))
        case .shareTapped:
            shareTappedCount += 1
            defaults.set(shareTappedCount, forKey: key(for: .shareTapped))
        case .copyTapped:
            copyTappedCount += 1
            defaults.set(copyTappedCount, forKey: key(for: .copyTapped))
        case .inviteEmailOpened:
            inviteEmailOpenedCount += 1
            defaults.set(inviteEmailOpenedCount, forKey: key(for: .inviteEmailOpened))
        case .inviteMessageOpened:
            inviteMessageOpenedCount += 1
            defaults.set(inviteMessageOpenedCount, forKey: key(for: .inviteMessageOpened))
        }
        
        lastActivityDayRounded = today
        defaults.set(today, forKey: "\(storageKeyPrefix).last_activity")
        
        logDebug("Referral action recorded: \(action.rawValue)", category: .monetization)
    }
    
    // MARK: - Summary
    
    public func currentSummary() -> ReferralLedgerSummary {
        ReferralLedgerSummary(
            totalShares: shareTappedCount,
            totalCopies: copyTappedCount,
            totalEmailInvites: inviteEmailOpenedCount,
            totalMessageInvites: inviteMessageOpenedCount,
            totalViews: viewedCount,
            lastActivityDayRounded: lastActivityDayRounded,
            schemaVersion: ReferralLedgerSummary.currentSchemaVersion
        )
    }
    
    // MARK: - Reset
    
    public func reset() {
        shareTappedCount = 0
        copyTappedCount = 0
        inviteEmailOpenedCount = 0
        inviteMessageOpenedCount = 0
        viewedCount = 0
        lastActivityDayRounded = nil
        
        for action in ReferralAction.allCases {
            defaults.removeObject(forKey: key(for: action))
        }
        defaults.removeObject(forKey: "\(storageKeyPrefix).last_activity")
    }
    
    // MARK: - Private
    
    private func loadCounts() {
        viewedCount = defaults.integer(forKey: key(for: .viewed))
        shareTappedCount = defaults.integer(forKey: key(for: .shareTapped))
        copyTappedCount = defaults.integer(forKey: key(for: .copyTapped))
        inviteEmailOpenedCount = defaults.integer(forKey: key(for: .inviteEmailOpened))
        inviteMessageOpenedCount = defaults.integer(forKey: key(for: .inviteMessageOpened))
        lastActivityDayRounded = defaults.string(forKey: "\(storageKeyPrefix).last_activity")
    }
    
    private func key(for action: ReferralAction) -> String {
        "\(storageKeyPrefix).\(action.rawValue)"
    }
    
    private func dayRoundedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
