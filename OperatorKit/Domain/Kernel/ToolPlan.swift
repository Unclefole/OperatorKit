import Foundation
import CryptoKit

// ============================================================================
// TOOL PLAN — PHASE 1 CAPABILITY KERNEL
//
// INVARIANT: Every action originates from a signed ToolPlan
// INVARIANT: No ToolPlan → No execution
// INVARIANT: Signature must be tamper-evident (HMAC-SHA256)
//
// This is the foundational artifact for the Capability Kernel.
// ============================================================================

// MARK: - Tool Plan

/// A signed, immutable plan for execution.
/// No side effect can occur without a valid ToolPlan.
public struct ToolPlan: Identifiable, Codable, Equatable {
    
    // MARK: - Identity
    
    public let id: UUID
    public let createdAt: Date
    
    // MARK: - Intent
    
    public let intent: ToolPlanIntent
    public let originatingAction: String
    
    // MARK: - Risk Assessment
    
    public let riskScore: Int  // 0-100
    public let riskTier: RiskTier
    public let riskReasons: [String]
    
    // MARK: - Reversibility
    
    public let reversibility: ReversibilityClass
    public let reversibilityReason: String
    
    // MARK: - Approval Requirements
    
    public let requiredApprovals: ApprovalRequirement
    
    // MARK: - Probes
    
    public let probes: [ProbeDefinition]
    
    // MARK: - Execution Steps
    
    public let executionSteps: [ExecutionStepDefinition]
    
    // MARK: - Signature (Tamper-Evident)
    
    public let signature: String
    public let signatureTimestamp: Date
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        intent: ToolPlanIntent,
        originatingAction: String,
        riskScore: Int,
        riskTier: RiskTier,
        riskReasons: [String],
        reversibility: ReversibilityClass,
        reversibilityReason: String,
        requiredApprovals: ApprovalRequirement,
        probes: [ProbeDefinition],
        executionSteps: [ExecutionStepDefinition]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.intent = intent
        self.originatingAction = originatingAction
        self.riskScore = riskScore
        self.riskTier = riskTier
        self.riskReasons = riskReasons
        self.reversibility = reversibility
        self.reversibilityReason = reversibilityReason
        self.requiredApprovals = requiredApprovals
        self.probes = probes
        self.executionSteps = executionSteps
        
        // Generate signature at creation time
        self.signatureTimestamp = Date()
        self.signature = ToolPlanSigner.sign(
            id: id,
            intent: intent,
            riskScore: riskScore,
            reversibility: reversibility,
            timestamp: self.signatureTimestamp
        )
    }
    
    // MARK: - Validation
    
    /// Verify the signature is valid and plan hasn't been tampered with
    public func verifySignature() -> Bool {
        let expectedSignature = ToolPlanSigner.sign(
            id: id,
            intent: intent,
            riskScore: riskScore,
            reversibility: reversibility,
            timestamp: signatureTimestamp
        )
        return signature == expectedSignature
    }
}

// MARK: - Tool Plan Intent

public struct ToolPlanIntent: Codable, Equatable {
    public let type: IntentType
    public let summary: String
    public let targetDescription: String
    
    public init(type: IntentType, summary: String, targetDescription: String) {
        self.type = type
        self.summary = summary
        self.targetDescription = targetDescription
    }
}

public enum IntentType: String, Codable, CaseIterable {
    case sendEmail = "send_email"
    case createDraft = "create_draft"
    case createReminder = "create_reminder"
    case createCalendarEvent = "create_calendar_event"
    case updateCalendarEvent = "update_calendar_event"
    case deleteCalendarEvent = "delete_calendar_event"
    case readCalendar = "read_calendar"
    case readContacts = "read_contacts"
    case fileWrite = "file_write"
    case fileDelete = "file_delete"
    case externalAPICall = "external_api_call"
    case databaseMutation = "database_mutation"
    case systemConfiguration = "system_configuration"
    case unknown = "unknown"
}

// MARK: - Risk Tier

public enum RiskTier: String, Codable, CaseIterable {
    case low = "LOW"           // 0-20: Auto-approved
    case medium = "MEDIUM"     // 21-50: Preview required
    case high = "HIGH"         // 51-75: Biometric/explicit confirm
    case critical = "CRITICAL" // 76-100: Multi-signature + cooldown
    
    public static func from(score: Int) -> RiskTier {
        switch score {
        case 0...20: return .low
        case 21...50: return .medium
        case 51...75: return .high
        default: return .critical
        }
    }
}

// MARK: - Reversibility Class

public enum ReversibilityClass: String, Codable, CaseIterable {
    case reversible = "REVERSIBLE"
    case partiallyReversible = "PARTIALLY_REVERSIBLE"
    case irreversible = "IRREVERSIBLE"
    
    /// Risk score modifier for irreversibility
    public var riskModifier: Int {
        switch self {
        case .reversible: return 0
        case .partiallyReversible: return 15
        case .irreversible: return 30
        }
    }
}

// MARK: - Approval Requirement

public struct ApprovalRequirement: Codable, Equatable {
    public let approvalsNeeded: Int
    public let requiresBiometric: Bool
    public let cooldownSeconds: Int
    public let multiSignerCount: Int
    public let requiresPreview: Bool
    
    public init(
        approvalsNeeded: Int = 1,
        requiresBiometric: Bool = false,
        cooldownSeconds: Int = 0,
        multiSignerCount: Int = 1,
        requiresPreview: Bool = false
    ) {
        self.approvalsNeeded = approvalsNeeded
        self.requiresBiometric = requiresBiometric
        self.cooldownSeconds = cooldownSeconds
        self.multiSignerCount = multiSignerCount
        self.requiresPreview = requiresPreview
    }
    
    // MARK: - Factory Methods
    
    public static let autoApprove = ApprovalRequirement(
        approvalsNeeded: 0,
        requiresBiometric: false,
        cooldownSeconds: 0,
        multiSignerCount: 0,
        requiresPreview: false
    )
    
    public static let previewRequired = ApprovalRequirement(
        approvalsNeeded: 1,
        requiresBiometric: false,
        cooldownSeconds: 0,
        multiSignerCount: 1,
        requiresPreview: true
    )
    
    public static let biometricRequired = ApprovalRequirement(
        approvalsNeeded: 1,
        requiresBiometric: true,
        cooldownSeconds: 0,
        multiSignerCount: 1,
        requiresPreview: true
    )
    
    public static let criticalMultiSig = ApprovalRequirement(
        approvalsNeeded: 2,
        requiresBiometric: true,
        cooldownSeconds: 30,
        multiSignerCount: 2,
        requiresPreview: true
    )
}

// MARK: - Probe Definition

public struct ProbeDefinition: Identifiable, Codable, Equatable {
    public let id: UUID
    public let type: ProbeType
    public let description: String
    public let target: String
    public let isRequired: Bool
    
    public init(
        id: UUID = UUID(),
        type: ProbeType,
        description: String,
        target: String,
        isRequired: Bool = true
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.target = target
        self.isRequired = isRequired
    }
}

public enum ProbeType: String, Codable, CaseIterable {
    case permissionCheck = "permission_check"
    case objectExists = "object_exists"
    case endpointHealth = "endpoint_health"
    case quotaCheck = "quota_check"
    case connectionValid = "connection_valid"
    case resourceAvailable = "resource_available"
}

// MARK: - Execution Step Definition

public struct ExecutionStepDefinition: Identifiable, Codable, Equatable {
    public let id: UUID
    public let order: Int
    public let action: String
    public let description: String
    public let isMutation: Bool
    public let rollbackAction: String?
    
    public init(
        id: UUID = UUID(),
        order: Int,
        action: String,
        description: String,
        isMutation: Bool,
        rollbackAction: String? = nil
    ) {
        self.id = id
        self.order = order
        self.action = action
        self.description = description
        self.isMutation = isMutation
        self.rollbackAction = rollbackAction
    }
}

// MARK: - Tool Plan Signer (HMAC-SHA256)

public enum ToolPlanSigner {
    
    /// Signing key (in production, this would be securely stored)
    /// For v1, we use a static key. Phase 2+ would use Keychain.
    private static let signingKey: SymmetricKey = {
        let keyData = "OperatorKit-ToolPlan-Signing-Key-v1".data(using: .utf8)!
        return SymmetricKey(data: keyData)
    }()
    
    /// Generate HMAC-SHA256 signature for a ToolPlan
    public static func sign(
        id: UUID,
        intent: ToolPlanIntent,
        riskScore: Int,
        reversibility: ReversibilityClass,
        timestamp: Date
    ) -> String {
        let payload = "\(id.uuidString)|\(intent.type.rawValue)|\(riskScore)|\(reversibility.rawValue)|\(timestamp.timeIntervalSince1970)"
        
        let payloadData = payload.data(using: .utf8)!
        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: signingKey)
        
        return Data(signature).base64EncodedString()
    }
    
    /// Verify a signature matches expected
    public static func verify(
        signature: String,
        id: UUID,
        intent: ToolPlanIntent,
        riskScore: Int,
        reversibility: ReversibilityClass,
        timestamp: Date
    ) -> Bool {
        let expectedSignature = sign(
            id: id,
            intent: intent,
            riskScore: riskScore,
            reversibility: reversibility,
            timestamp: timestamp
        )
        return signature == expectedSignature
    }
}

// MARK: - Tool Plan Builder

public final class ToolPlanBuilder {
    private var intent: ToolPlanIntent?
    private var originatingAction: String = ""
    private var riskScore: Int = 0
    private var riskReasons: [String] = []
    private var reversibility: ReversibilityClass = .reversible
    private var reversibilityReason: String = ""
    private var probes: [ProbeDefinition] = []
    private var executionSteps: [ExecutionStepDefinition] = []
    
    public init() {}
    
    public func setIntent(_ intent: ToolPlanIntent) -> ToolPlanBuilder {
        self.intent = intent
        return self
    }
    
    public func setOriginatingAction(_ action: String) -> ToolPlanBuilder {
        self.originatingAction = action
        return self
    }
    
    public func setRisk(score: Int, reasons: [String]) -> ToolPlanBuilder {
        self.riskScore = max(0, min(100, score))
        self.riskReasons = reasons
        return self
    }
    
    public func setReversibility(_ reversibility: ReversibilityClass, reason: String) -> ToolPlanBuilder {
        self.reversibility = reversibility
        self.reversibilityReason = reason
        return self
    }
    
    public func addProbe(_ probe: ProbeDefinition) -> ToolPlanBuilder {
        self.probes.append(probe)
        return self
    }
    
    public func addExecutionStep(_ step: ExecutionStepDefinition) -> ToolPlanBuilder {
        self.executionSteps.append(step)
        return self
    }
    
    public func build() -> ToolPlan? {
        guard let intent = intent else { return nil }
        
        let finalRiskScore = riskScore + reversibility.riskModifier
        let clampedRiskScore = max(0, min(100, finalRiskScore))
        let riskTier = RiskTier.from(score: clampedRiskScore)
        
        return ToolPlan(
            intent: intent,
            originatingAction: originatingAction,
            riskScore: clampedRiskScore,
            riskTier: riskTier,
            riskReasons: riskReasons,
            reversibility: reversibility,
            reversibilityReason: reversibilityReason,
            requiredApprovals: ApprovalRequirement.previewRequired, // Will be set by PolicyEngine
            probes: probes,
            executionSteps: executionSteps
        )
    }
}
