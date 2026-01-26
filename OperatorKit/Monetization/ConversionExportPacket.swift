import Foundation

// ============================================================================
// CONVERSION EXPORT PACKET (Phase 10L, Updated Phase 10N, Phase 10O)
//
// Exportable conversion funnel data. Metadata-only, no user content.
// Phase 10N: Added satisfaction aggregates.
// Phase 10O: Added activation outcome summary.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content
// ❌ No user identifiers
// ❌ No receipts or transaction data
// ❌ No forbidden keys
// ✅ Numeric aggregates only
// ✅ Variant and schema metadata
// ✅ User-initiated export only
// ✅ Satisfaction aggregates (Phase 10N)
// ✅ Outcome aggregates (Phase 10O)
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

// MARK: - Conversion Export Packet

public struct ConversionExportPacket: Codable {
    
    // MARK: - Metadata
    
    public let schemaVersion: Int
    public let exportedAt: String
    public let appVersion: String
    public let buildNumber: String
    
    // MARK: - Variant
    
    public let currentVariantId: String
    public let variantSchemaVersion: Int
    
    // MARK: - Funnel Data
    
    public let funnelSummary: FunnelSummary
    
    // MARK: - Computed Rates
    
    public let computedRates: ComputedRates
    
    // MARK: - Satisfaction (Phase 10N)
    
    public let satisfactionSummary: SatisfactionExportSummary?
    
    // MARK: - Outcome (Phase 10O)
    
    public let outcomeSummary: ActivationOutcomeSummary?
    
    public static let currentSchemaVersion = 3  // Bumped for Phase 10O
    
    // MARK: - Initialization
    
    @MainActor
    public init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        let summary = ConversionFunnelManager.shared.currentFunnelSummary()
        let satisfaction = SatisfactionSignalStore.shared.currentSummary()
        let outcome = ActivationOutcomeSummary()
        
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = formatter.string(from: Date())
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        self.currentVariantId = PricingVariantStore.shared.currentVariant.id
        self.variantSchemaVersion = PricingVariant.schemaVersion
        self.funnelSummary = summary
        self.computedRates = ComputedRates(from: summary)
        self.satisfactionSummary = SatisfactionExportSummary(from: satisfaction)
        self.outcomeSummary = outcome
    }
    
    // MARK: - Export
    
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    
    public var exportFilename: String {
        "OperatorKit_Conversion_\(exportedAt).json"
    }
    
    // MARK: - Validation
    
    public func validateNoForbiddenKeys() throws -> [String] {
        let jsonData = try exportJSON()
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }
        
        return Self.findForbiddenKeys(in: json, path: "")
    }
    
    private static let forbiddenKeys: [String] = [
        "body", "subject", "content", "draft", "prompt",
        "context", "note", "email", "attendees", "title",
        "description", "message", "text", "recipient", "sender",
        "userId", "deviceId", "receipt", "transaction"
    ]
    
    private static func findForbiddenKeys(in dict: [String: Any], path: String) -> [String] {
        var violations: [String] = []
        
        for (key, value) in dict {
            let fullPath = path.isEmpty ? key : "\(path).\(key)"
            
            if forbiddenKeys.contains(key.lowercased()) {
                violations.append("Forbidden key: \(fullPath)")
            }
            
            if let nested = value as? [String: Any] {
                violations.append(contentsOf: findForbiddenKeys(in: nested, path: fullPath))
            }
        }
        
        return violations
    }
}

// MARK: - Computed Rates

public struct ComputedRates: Codable {
    public let pricingViewRate: Double?
    public let upgradeTapRate: Double?
    public let purchaseStartRate: Double?
    public let purchaseSuccessRate: Double?
    public let overallConversionRate: Double?
    public let restoreSuccessRate: Double?
    
    public init(from summary: FunnelSummary) {
        self.pricingViewRate = summary.pricingViewRate
        self.upgradeTapRate = summary.upgradeTapRate
        self.purchaseStartRate = summary.purchaseStartRate
        self.purchaseSuccessRate = summary.purchaseSuccessRate
        self.overallConversionRate = summary.overallConversionRate
        self.restoreSuccessRate = summary.restoreSuccessRate
    }
}

// MARK: - Satisfaction Export Summary (Phase 10N)

public struct SatisfactionExportSummary: Codable {
    /// Total responses
    public let totalResponses: Int
    
    /// Overall average (1-5)
    public let overallAverage: Double
    
    /// Average by question ID
    public let averageByQuestion: [String: Double]
    
    /// Schema version
    public let schemaVersion: Int
    
    public init(from summary: SatisfactionSummary) {
        self.totalResponses = summary.totalResponses
        self.overallAverage = summary.overallAverage
        self.averageByQuestion = summary.averageByQuestion
        self.schemaVersion = summary.schemaVersion
    }
}
