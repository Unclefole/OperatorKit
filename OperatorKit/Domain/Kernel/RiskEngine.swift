import Foundation

// ============================================================================
// RISK ENGINE — PHASE 1 CAPABILITY KERNEL
//
// Purpose: Quantify blast radius BEFORE approval.
// Deterministic rules ONLY. No ML.
//
// INVARIANT: Scoring must be explainable
// INVARIANT: Opaque scoring is forbidden
// INVARIANT: Every score has documented reasons
//
// Risk Dimensions:
// - Financial Impact
// - External Exposure
// - Data Sensitivity
// - System Mutation
// - Reversibility
// - Scope
// ============================================================================

// MARK: - Risk Assessment

public struct RiskAssessment: Codable, Equatable {
    public let score: Int           // 0-100
    public let tier: RiskTier
    public let reasons: [RiskReason]
    public let dimensions: RiskDimensions
    public let assessedAt: Date
    
    public init(
        score: Int,
        tier: RiskTier,
        reasons: [RiskReason],
        dimensions: RiskDimensions,
        assessedAt: Date = Date()
    ) {
        self.score = score
        self.tier = tier
        self.reasons = reasons
        self.dimensions = dimensions
        self.assessedAt = assessedAt
    }
}

// MARK: - Risk Reason

public struct RiskReason: Codable, Equatable, Identifiable {
    public let id: UUID
    public let dimension: RiskDimensionType
    public let description: String
    public let scoreContribution: Int
    
    public init(
        id: UUID = UUID(),
        dimension: RiskDimensionType,
        description: String,
        scoreContribution: Int
    ) {
        self.id = id
        self.dimension = dimension
        self.description = description
        self.scoreContribution = scoreContribution
    }
}

// MARK: - Risk Dimension Type

public enum RiskDimensionType: String, Codable, CaseIterable {
    case financialImpact = "financial_impact"
    case externalExposure = "external_exposure"
    case dataSensitivity = "data_sensitivity"
    case systemMutation = "system_mutation"
    case reversibility = "reversibility"
    case scope = "scope"
}

// MARK: - Risk Dimensions

public struct RiskDimensions: Codable, Equatable {
    public let financialImpact: Int       // 0-100
    public let externalExposure: Int      // 0-100
    public let dataSensitivity: Int       // 0-100
    public let systemMutation: Int        // 0-100
    public let reversibility: Int         // 0-100
    public let scope: Int                 // 0-100
    
    public init(
        financialImpact: Int = 0,
        externalExposure: Int = 0,
        dataSensitivity: Int = 0,
        systemMutation: Int = 0,
        reversibility: Int = 0,
        scope: Int = 0
    ) {
        self.financialImpact = financialImpact
        self.externalExposure = externalExposure
        self.dataSensitivity = dataSensitivity
        self.systemMutation = systemMutation
        self.reversibility = reversibility
        self.scope = scope
    }
}

// MARK: - Risk Engine

/// Deterministic risk scoring engine.
/// No ML. No heuristics. Rules only.
public final class RiskEngine {
    
    public static let shared = RiskEngine()
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Weights for each dimension (must sum to 100)
    private let weights = RiskWeights(
        financialImpact: 20,
        externalExposure: 25,
        dataSensitivity: 20,
        systemMutation: 15,
        reversibility: 15,
        scope: 5
    )
    
    // MARK: - Public API
    
    /// Assess risk for a given action context
    public func assess(context: RiskContext) -> RiskAssessment {
        var reasons: [RiskReason] = []
        var dimensions = RiskDimensions()
        
        // 1. Financial Impact
        let financialScore = assessFinancialImpact(context: context, reasons: &reasons)
        dimensions = RiskDimensions(
            financialImpact: financialScore,
            externalExposure: dimensions.externalExposure,
            dataSensitivity: dimensions.dataSensitivity,
            systemMutation: dimensions.systemMutation,
            reversibility: dimensions.reversibility,
            scope: dimensions.scope
        )
        
        // 2. External Exposure
        let externalScore = assessExternalExposure(context: context, reasons: &reasons)
        dimensions = RiskDimensions(
            financialImpact: dimensions.financialImpact,
            externalExposure: externalScore,
            dataSensitivity: dimensions.dataSensitivity,
            systemMutation: dimensions.systemMutation,
            reversibility: dimensions.reversibility,
            scope: dimensions.scope
        )
        
        // 3. Data Sensitivity
        let dataScore = assessDataSensitivity(context: context, reasons: &reasons)
        dimensions = RiskDimensions(
            financialImpact: dimensions.financialImpact,
            externalExposure: dimensions.externalExposure,
            dataSensitivity: dataScore,
            systemMutation: dimensions.systemMutation,
            reversibility: dimensions.reversibility,
            scope: dimensions.scope
        )
        
        // 4. System Mutation
        let mutationScore = assessSystemMutation(context: context, reasons: &reasons)
        dimensions = RiskDimensions(
            financialImpact: dimensions.financialImpact,
            externalExposure: dimensions.externalExposure,
            dataSensitivity: dimensions.dataSensitivity,
            systemMutation: mutationScore,
            reversibility: dimensions.reversibility,
            scope: dimensions.scope
        )
        
        // 5. Reversibility
        let reversibilityScore = assessReversibility(context: context, reasons: &reasons)
        dimensions = RiskDimensions(
            financialImpact: dimensions.financialImpact,
            externalExposure: dimensions.externalExposure,
            dataSensitivity: dimensions.dataSensitivity,
            systemMutation: dimensions.systemMutation,
            reversibility: reversibilityScore,
            scope: dimensions.scope
        )
        
        // 6. Scope
        let scopeScore = assessScope(context: context, reasons: &reasons)
        dimensions = RiskDimensions(
            financialImpact: dimensions.financialImpact,
            externalExposure: dimensions.externalExposure,
            dataSensitivity: dimensions.dataSensitivity,
            systemMutation: dimensions.systemMutation,
            reversibility: dimensions.reversibility,
            scope: scopeScore
        )
        
        // Calculate weighted total
        let totalScore = calculateWeightedScore(dimensions: dimensions)
        let tier = RiskTier.from(score: totalScore)
        
        return RiskAssessment(
            score: totalScore,
            tier: tier,
            reasons: reasons,
            dimensions: dimensions
        )
    }
    
    // MARK: - Dimension Assessors
    
    private func assessFinancialImpact(context: RiskContext, reasons: inout [RiskReason]) -> Int {
        var score = 0
        
        // Payment or financial transaction
        if context.involvesPayment {
            score += 80
            reasons.append(RiskReason(
                dimension: .financialImpact,
                description: "Action involves financial transaction",
                scoreContribution: 80
            ))
        }
        
        // Subscription or recurring charge
        if context.involvesSubscription {
            score += 60
            reasons.append(RiskReason(
                dimension: .financialImpact,
                description: "Action involves subscription or recurring charge",
                scoreContribution: 60
            ))
        }
        
        // Resource consumption (API costs, storage)
        if context.consumesResources {
            score += 20
            reasons.append(RiskReason(
                dimension: .financialImpact,
                description: "Action consumes billable resources",
                scoreContribution: 20
            ))
        }
        
        return min(100, score)
    }
    
    private func assessExternalExposure(context: RiskContext, reasons: inout [RiskReason]) -> Int {
        var score = 0
        
        // External communication (email, message)
        if context.sendsExternalCommunication {
            score += 40
            reasons.append(RiskReason(
                dimension: .externalExposure,
                description: "Action sends external communication",
                scoreContribution: 40
            ))
        }
        
        // Multiple external recipients
        if context.externalRecipientCount > 1 {
            let additionalScore = min(30, context.externalRecipientCount * 10)
            score += additionalScore
            reasons.append(RiskReason(
                dimension: .externalExposure,
                description: "Action has \(context.externalRecipientCount) external recipients",
                scoreContribution: additionalScore
            ))
        }
        
        // Public visibility
        if context.hasPublicVisibility {
            score += 50
            reasons.append(RiskReason(
                dimension: .externalExposure,
                description: "Action has public visibility",
                scoreContribution: 50
            ))
        }
        
        // Third-party API call
        if context.involvesThirdPartyAPI {
            score += 25
            reasons.append(RiskReason(
                dimension: .externalExposure,
                description: "Action calls third-party API",
                scoreContribution: 25
            ))
        }
        
        return min(100, score)
    }
    
    private func assessDataSensitivity(context: RiskContext, reasons: inout [RiskReason]) -> Int {
        var score = 0
        
        // PII (Personal Identifiable Information)
        if context.involvesPII {
            score += 50
            reasons.append(RiskReason(
                dimension: .dataSensitivity,
                description: "Action involves PII",
                scoreContribution: 50
            ))
        }
        
        // Credentials or secrets
        if context.involvesCredentials {
            score += 80
            reasons.append(RiskReason(
                dimension: .dataSensitivity,
                description: "Action involves credentials or secrets",
                scoreContribution: 80
            ))
        }
        
        // Health information
        if context.involvesHealthData {
            score += 70
            reasons.append(RiskReason(
                dimension: .dataSensitivity,
                description: "Action involves health data (HIPAA)",
                scoreContribution: 70
            ))
        }
        
        // Financial information
        if context.involvesFinancialData {
            score += 60
            reasons.append(RiskReason(
                dimension: .dataSensitivity,
                description: "Action involves financial data",
                scoreContribution: 60
            ))
        }
        
        return min(100, score)
    }
    
    private func assessSystemMutation(context: RiskContext, reasons: inout [RiskReason]) -> Int {
        var score = 0
        
        // Database write
        if context.writeToDatabase {
            score += 40
            reasons.append(RiskReason(
                dimension: .systemMutation,
                description: "Action writes to database",
                scoreContribution: 40
            ))
        }
        
        // File system write
        if context.writeToFileSystem {
            score += 30
            reasons.append(RiskReason(
                dimension: .systemMutation,
                description: "Action writes to file system",
                scoreContribution: 30
            ))
        }
        
        // Delete operation
        if context.isDeleteOperation {
            score += 50
            reasons.append(RiskReason(
                dimension: .systemMutation,
                description: "Action performs delete operation",
                scoreContribution: 50
            ))
        }
        
        // Configuration change
        if context.changesConfiguration {
            score += 45
            reasons.append(RiskReason(
                dimension: .systemMutation,
                description: "Action changes system configuration",
                scoreContribution: 45
            ))
        }
        
        return min(100, score)
    }
    
    private func assessReversibility(context: RiskContext, reasons: inout [RiskReason]) -> Int {
        var score = 0
        
        switch context.reversibility {
        case .reversible:
            // No penalty
            break
            
        case .partiallyReversible:
            score += 30
            reasons.append(RiskReason(
                dimension: .reversibility,
                description: "Action is only partially reversible",
                scoreContribution: 30
            ))
            
        case .irreversible:
            score += 60
            reasons.append(RiskReason(
                dimension: .reversibility,
                description: "Action is IRREVERSIBLE",
                scoreContribution: 60
            ))
        }
        
        // No rollback mechanism
        if !context.hasRollbackMechanism && context.reversibility != .reversible {
            score += 20
            reasons.append(RiskReason(
                dimension: .reversibility,
                description: "No automated rollback mechanism available",
                scoreContribution: 20
            ))
        }
        
        return min(100, score)
    }
    
    private func assessScope(context: RiskContext, reasons: inout [RiskReason]) -> Int {
        var score = 0
        
        // Affects multiple entities
        if context.affectedEntityCount > 1 {
            let scopeScore = min(50, context.affectedEntityCount * 5)
            score += scopeScore
            reasons.append(RiskReason(
                dimension: .scope,
                description: "Action affects \(context.affectedEntityCount) entities",
                scoreContribution: scopeScore
            ))
        }
        
        // Batch operation
        if context.isBatchOperation {
            score += 30
            reasons.append(RiskReason(
                dimension: .scope,
                description: "Action is a batch operation",
                scoreContribution: 30
            ))
        }
        
        // Cross-system
        if context.crossesSystemBoundary {
            score += 25
            reasons.append(RiskReason(
                dimension: .scope,
                description: "Action crosses system boundary",
                scoreContribution: 25
            ))
        }
        
        return min(100, score)
    }
    
    // MARK: - Score Calculation
    
    private func calculateWeightedScore(dimensions: RiskDimensions) -> Int {
        let weighted = (
            (dimensions.financialImpact * weights.financialImpact) +
            (dimensions.externalExposure * weights.externalExposure) +
            (dimensions.dataSensitivity * weights.dataSensitivity) +
            (dimensions.systemMutation * weights.systemMutation) +
            (dimensions.reversibility * weights.reversibility) +
            (dimensions.scope * weights.scope)
        ) / 100
        
        return max(0, min(100, weighted))
    }
}

// MARK: - Risk Context

/// Input context for risk assessment.
/// All fields are explicit and auditable.
public struct RiskContext {
    // Financial
    public let involvesPayment: Bool
    public let involvesSubscription: Bool
    public let consumesResources: Bool
    
    // External Exposure
    public let sendsExternalCommunication: Bool
    public let externalRecipientCount: Int
    public let hasPublicVisibility: Bool
    public let involvesThirdPartyAPI: Bool
    
    // Data Sensitivity
    public let involvesPII: Bool
    public let involvesCredentials: Bool
    public let involvesHealthData: Bool
    public let involvesFinancialData: Bool
    
    // System Mutation
    public let writeToDatabase: Bool
    public let writeToFileSystem: Bool
    public let isDeleteOperation: Bool
    public let changesConfiguration: Bool
    
    // Reversibility
    public let reversibility: ReversibilityClass
    public let hasRollbackMechanism: Bool
    
    // Scope
    public let affectedEntityCount: Int
    public let isBatchOperation: Bool
    public let crossesSystemBoundary: Bool
    
    public init(
        involvesPayment: Bool = false,
        involvesSubscription: Bool = false,
        consumesResources: Bool = false,
        sendsExternalCommunication: Bool = false,
        externalRecipientCount: Int = 0,
        hasPublicVisibility: Bool = false,
        involvesThirdPartyAPI: Bool = false,
        involvesPII: Bool = false,
        involvesCredentials: Bool = false,
        involvesHealthData: Bool = false,
        involvesFinancialData: Bool = false,
        writeToDatabase: Bool = false,
        writeToFileSystem: Bool = false,
        isDeleteOperation: Bool = false,
        changesConfiguration: Bool = false,
        reversibility: ReversibilityClass = .reversible,
        hasRollbackMechanism: Bool = true,
        affectedEntityCount: Int = 1,
        isBatchOperation: Bool = false,
        crossesSystemBoundary: Bool = false
    ) {
        self.involvesPayment = involvesPayment
        self.involvesSubscription = involvesSubscription
        self.consumesResources = consumesResources
        self.sendsExternalCommunication = sendsExternalCommunication
        self.externalRecipientCount = externalRecipientCount
        self.hasPublicVisibility = hasPublicVisibility
        self.involvesThirdPartyAPI = involvesThirdPartyAPI
        self.involvesPII = involvesPII
        self.involvesCredentials = involvesCredentials
        self.involvesHealthData = involvesHealthData
        self.involvesFinancialData = involvesFinancialData
        self.writeToDatabase = writeToDatabase
        self.writeToFileSystem = writeToFileSystem
        self.isDeleteOperation = isDeleteOperation
        self.changesConfiguration = changesConfiguration
        self.reversibility = reversibility
        self.hasRollbackMechanism = hasRollbackMechanism
        self.affectedEntityCount = affectedEntityCount
        self.isBatchOperation = isBatchOperation
        self.crossesSystemBoundary = crossesSystemBoundary
    }
}

// MARK: - Risk Context Builder

public final class RiskContextBuilder {
    private var context = RiskContext()
    
    public init() {}
    
    public func setFinancial(payment: Bool = false, subscription: Bool = false, resources: Bool = false) -> RiskContextBuilder {
        context = RiskContext(
            involvesPayment: payment,
            involvesSubscription: subscription,
            consumesResources: resources,
            sendsExternalCommunication: context.sendsExternalCommunication,
            externalRecipientCount: context.externalRecipientCount,
            hasPublicVisibility: context.hasPublicVisibility,
            involvesThirdPartyAPI: context.involvesThirdPartyAPI,
            involvesPII: context.involvesPII,
            involvesCredentials: context.involvesCredentials,
            involvesHealthData: context.involvesHealthData,
            involvesFinancialData: context.involvesFinancialData,
            writeToDatabase: context.writeToDatabase,
            writeToFileSystem: context.writeToFileSystem,
            isDeleteOperation: context.isDeleteOperation,
            changesConfiguration: context.changesConfiguration,
            reversibility: context.reversibility,
            hasRollbackMechanism: context.hasRollbackMechanism,
            affectedEntityCount: context.affectedEntityCount,
            isBatchOperation: context.isBatchOperation,
            crossesSystemBoundary: context.crossesSystemBoundary
        )
        return self
    }
    
    public func setExternalExposure(sends: Bool = false, recipientCount: Int = 0, public_: Bool = false, thirdParty: Bool = false) -> RiskContextBuilder {
        context = RiskContext(
            involvesPayment: context.involvesPayment,
            involvesSubscription: context.involvesSubscription,
            consumesResources: context.consumesResources,
            sendsExternalCommunication: sends,
            externalRecipientCount: recipientCount,
            hasPublicVisibility: public_,
            involvesThirdPartyAPI: thirdParty,
            involvesPII: context.involvesPII,
            involvesCredentials: context.involvesCredentials,
            involvesHealthData: context.involvesHealthData,
            involvesFinancialData: context.involvesFinancialData,
            writeToDatabase: context.writeToDatabase,
            writeToFileSystem: context.writeToFileSystem,
            isDeleteOperation: context.isDeleteOperation,
            changesConfiguration: context.changesConfiguration,
            reversibility: context.reversibility,
            hasRollbackMechanism: context.hasRollbackMechanism,
            affectedEntityCount: context.affectedEntityCount,
            isBatchOperation: context.isBatchOperation,
            crossesSystemBoundary: context.crossesSystemBoundary
        )
        return self
    }
    
    public func setDataSensitivity(pii: Bool = false, credentials: Bool = false, health: Bool = false, financial: Bool = false) -> RiskContextBuilder {
        context = RiskContext(
            involvesPayment: context.involvesPayment,
            involvesSubscription: context.involvesSubscription,
            consumesResources: context.consumesResources,
            sendsExternalCommunication: context.sendsExternalCommunication,
            externalRecipientCount: context.externalRecipientCount,
            hasPublicVisibility: context.hasPublicVisibility,
            involvesThirdPartyAPI: context.involvesThirdPartyAPI,
            involvesPII: pii,
            involvesCredentials: credentials,
            involvesHealthData: health,
            involvesFinancialData: financial,
            writeToDatabase: context.writeToDatabase,
            writeToFileSystem: context.writeToFileSystem,
            isDeleteOperation: context.isDeleteOperation,
            changesConfiguration: context.changesConfiguration,
            reversibility: context.reversibility,
            hasRollbackMechanism: context.hasRollbackMechanism,
            affectedEntityCount: context.affectedEntityCount,
            isBatchOperation: context.isBatchOperation,
            crossesSystemBoundary: context.crossesSystemBoundary
        )
        return self
    }
    
    public func setMutation(database: Bool = false, fileSystem: Bool = false, delete: Bool = false, config: Bool = false) -> RiskContextBuilder {
        context = RiskContext(
            involvesPayment: context.involvesPayment,
            involvesSubscription: context.involvesSubscription,
            consumesResources: context.consumesResources,
            sendsExternalCommunication: context.sendsExternalCommunication,
            externalRecipientCount: context.externalRecipientCount,
            hasPublicVisibility: context.hasPublicVisibility,
            involvesThirdPartyAPI: context.involvesThirdPartyAPI,
            involvesPII: context.involvesPII,
            involvesCredentials: context.involvesCredentials,
            involvesHealthData: context.involvesHealthData,
            involvesFinancialData: context.involvesFinancialData,
            writeToDatabase: database,
            writeToFileSystem: fileSystem,
            isDeleteOperation: delete,
            changesConfiguration: config,
            reversibility: context.reversibility,
            hasRollbackMechanism: context.hasRollbackMechanism,
            affectedEntityCount: context.affectedEntityCount,
            isBatchOperation: context.isBatchOperation,
            crossesSystemBoundary: context.crossesSystemBoundary
        )
        return self
    }
    
    public func setReversibility(_ reversibility: ReversibilityClass, hasRollback: Bool = true) -> RiskContextBuilder {
        context = RiskContext(
            involvesPayment: context.involvesPayment,
            involvesSubscription: context.involvesSubscription,
            consumesResources: context.consumesResources,
            sendsExternalCommunication: context.sendsExternalCommunication,
            externalRecipientCount: context.externalRecipientCount,
            hasPublicVisibility: context.hasPublicVisibility,
            involvesThirdPartyAPI: context.involvesThirdPartyAPI,
            involvesPII: context.involvesPII,
            involvesCredentials: context.involvesCredentials,
            involvesHealthData: context.involvesHealthData,
            involvesFinancialData: context.involvesFinancialData,
            writeToDatabase: context.writeToDatabase,
            writeToFileSystem: context.writeToFileSystem,
            isDeleteOperation: context.isDeleteOperation,
            changesConfiguration: context.changesConfiguration,
            reversibility: reversibility,
            hasRollbackMechanism: hasRollback,
            affectedEntityCount: context.affectedEntityCount,
            isBatchOperation: context.isBatchOperation,
            crossesSystemBoundary: context.crossesSystemBoundary
        )
        return self
    }
    
    public func setScope(entityCount: Int = 1, batch: Bool = false, crossSystem: Bool = false) -> RiskContextBuilder {
        context = RiskContext(
            involvesPayment: context.involvesPayment,
            involvesSubscription: context.involvesSubscription,
            consumesResources: context.consumesResources,
            sendsExternalCommunication: context.sendsExternalCommunication,
            externalRecipientCount: context.externalRecipientCount,
            hasPublicVisibility: context.hasPublicVisibility,
            involvesThirdPartyAPI: context.involvesThirdPartyAPI,
            involvesPII: context.involvesPII,
            involvesCredentials: context.involvesCredentials,
            involvesHealthData: context.involvesHealthData,
            involvesFinancialData: context.involvesFinancialData,
            writeToDatabase: context.writeToDatabase,
            writeToFileSystem: context.writeToFileSystem,
            isDeleteOperation: context.isDeleteOperation,
            changesConfiguration: context.changesConfiguration,
            reversibility: context.reversibility,
            hasRollbackMechanism: context.hasRollbackMechanism,
            affectedEntityCount: entityCount,
            isBatchOperation: batch,
            crossesSystemBoundary: crossSystem
        )
        return self
    }
    
    public func build() -> RiskContext {
        return context
    }
}

// MARK: - Risk Weights

private struct RiskWeights {
    let financialImpact: Int
    let externalExposure: Int
    let dataSensitivity: Int
    let systemMutation: Int
    let reversibility: Int
    let scope: Int
}
