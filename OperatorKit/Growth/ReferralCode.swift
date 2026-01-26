import Foundation

// ============================================================================
// REFERRAL CODE (Phase 11A)
//
// Local, deterministic referral code generation.
// NOT tied to user identity. Stored locally only.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user identity
// ❌ No networking
// ❌ No tracking of recipients
// ✅ Local-only generation
// ✅ Deterministic format
// ✅ Shareable without identity leakage
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Referral Code

public struct ReferralCode: Codable, Equatable {
    
    /// The code value (format: OK-XXXX-XXXX)
    public let code: String
    
    /// When the code was generated
    public let generatedAt: Date
    
    /// Day-rounded generation date
    public let generatedAtDayRounded: String
    
    /// Schema version
    public let schemaVersion: Int
    
    public static let currentSchemaVersion = 1
    
    // MARK: - Code Format
    
    /// Code prefix
    public static let prefix = "OK"
    
    /// Characters used in code generation (no ambiguous chars)
    private static let codeCharacters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    
    // MARK: - Initialization
    
    public init(code: String? = nil, generatedAt: Date = Date()) {
        self.code = code ?? Self.generateCode()
        self.generatedAt = generatedAt
        self.generatedAtDayRounded = Self.dayRounded(generatedAt)
        self.schemaVersion = Self.currentSchemaVersion
    }
    
    // MARK: - Code Generation
    
    /// Generates a new referral code
    private static func generateCode() -> String {
        let segment1 = randomSegment(length: 4)
        let segment2 = randomSegment(length: 4)
        return "\(prefix)-\(segment1)-\(segment2)"
    }
    
    private static func randomSegment(length: Int) -> String {
        String((0..<length).map { _ in
            codeCharacters.randomElement()!
        })
    }
    
    private static func dayRounded(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
    
    // MARK: - Validation
    
    /// Validates code format
    public static func isValidFormat(_ code: String) -> Bool {
        let pattern = "^OK-[A-Z2-9]{4}-[A-Z2-9]{4}$"
        return code.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Validates this code contains no identifiers
    public func validateNoIdentifiers() -> [String] {
        var violations: [String] = []
        
        // Check code doesn't contain patterns that look like identifiers
        let identifierPatterns = [
            "userId", "deviceId", "email", "name", "phone"
        ]
        
        let lowered = code.lowercased()
        for pattern in identifierPatterns {
            if lowered.contains(pattern.lowercased()) {
                violations.append("Code contains identifier pattern: \(pattern)")
            }
        }
        
        return violations
    }
}

// MARK: - Referral Code Store

@MainActor
public final class ReferralCodeStore: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = ReferralCodeStore()
    
    // MARK: - Storage
    
    private let defaults: UserDefaults
    private let storageKey = "com.operatorkit.referral.code"
    
    // MARK: - State
    
    @Published public private(set) var currentCode: ReferralCode?
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadCode()
    }
    
    // MARK: - Public API
    
    /// Gets or generates the referral code
    public func getOrGenerateCode() -> ReferralCode {
        if let existing = currentCode {
            return existing
        }
        
        let newCode = ReferralCode()
        currentCode = newCode
        saveCode(newCode)
        return newCode
    }
    
    /// Regenerates the code (user-initiated only)
    public func regenerateCode() -> ReferralCode {
        let newCode = ReferralCode()
        currentCode = newCode
        saveCode(newCode)
        
        logDebug("Referral code regenerated", category: .monetization)
        return newCode
    }
    
    // MARK: - Reset (for testing)
    
    public func reset() {
        currentCode = nil
        defaults.removeObject(forKey: storageKey)
    }
    
    // MARK: - Private
    
    private func loadCode() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(ReferralCode.self, from: data) else {
            return
        }
        currentCode = decoded
    }
    
    private func saveCode(_ code: ReferralCode) {
        if let encoded = try? JSONEncoder().encode(code) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
}
