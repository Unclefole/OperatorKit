import Foundation

// ============================================================================
// PROMPT SCAFFOLD REGISTRY (Phase 9B)
//
// Central registry for prompt scaffold versioning and output schemas.
// IMPORTANT: This file contains NO prompt text, only version metadata.
//
// INVARIANT: No prompt text storage
// INVARIANT: No content storage
// INVARIANT: Version metadata only
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Central registry for prompt scaffold versioning
/// NOTE: Contains NO prompt text - only version metadata
public struct PromptScaffoldRegistry {
    
    // MARK: - Version
    
    /// Current scaffold schema version
    public static let schemaVersion: Int = 1
    
    /// Hash computation method version
    public static let hashingVersion: String = "sha256-v1"
    
    /// Last schema update reason (NO prompt text here)
    public static let lastUpdateReason: String = "Phase 9B - Initial registry creation"
    
    /// Last update date
    public static let lastUpdateDate: Date = {
        let components = DateComponents(year: 2026, month: 1, day: 24)
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    // MARK: - Allowed Output Schemas
    
    /// Registry of allowed output schemas (names only, no prompt content)
    public static let allowedOutputSchemas: [OutputSchema] = [
        OutputSchema(id: "email", version: 1, description: "Email draft output"),
        OutputSchema(id: "summary", version: 1, description: "Meeting/content summary output"),
        OutputSchema(id: "action_items", version: 1, description: "Action items extraction output"),
        OutputSchema(id: "plan", version: 1, description: "Planning/reminder output"),
        OutputSchema(id: "confirmation", version: 1, description: "Action confirmation output"),
    ]
    
    /// Output schema definition (NO content, only metadata)
    public struct OutputSchema: Codable, Identifiable, Equatable {
        public let id: String
        public let version: Int
        public let description: String
    }
    
    // MARK: - Validation
    
    /// Validation errors found in registry
    public enum ValidationError: Error, Equatable, CustomStringConvertible {
        case schemaVersionInvalid
        case hashingVersionEmpty
        case noOutputSchemas
        case duplicateOutputSchema(String)
        case outputSchemaVersionInvalid(String)
        
        public var description: String {
            switch self {
            case .schemaVersionInvalid:
                return "Schema version must be > 0"
            case .hashingVersionEmpty:
                return "Hashing version must not be empty"
            case .noOutputSchemas:
                return "At least one output schema must be defined"
            case .duplicateOutputSchema(let id):
                return "Duplicate output schema: \(id)"
            case .outputSchemaVersionInvalid(let id):
                return "Output schema version must be > 0: \(id)"
            }
        }
    }
    
    /// Validates the registry configuration
    /// Returns empty array if valid, otherwise returns list of errors
    public static func validate() -> [ValidationError] {
        var errors: [ValidationError] = []
        
        if schemaVersion <= 0 {
            errors.append(.schemaVersionInvalid)
        }
        
        if hashingVersion.isEmpty {
            errors.append(.hashingVersionEmpty)
        }
        
        if allowedOutputSchemas.isEmpty {
            errors.append(.noOutputSchemas)
        }
        
        // Check for duplicates
        var seenIds: Set<String> = []
        for schema in allowedOutputSchemas {
            if seenIds.contains(schema.id) {
                errors.append(.duplicateOutputSchema(schema.id))
            }
            seenIds.insert(schema.id)
            
            if schema.version <= 0 {
                errors.append(.outputSchemaVersionInvalid(schema.id))
            }
        }
        
        return errors
    }
    
    /// Checks if an output schema ID is allowed
    public static func isOutputSchemaAllowed(_ id: String) -> Bool {
        allowedOutputSchemas.contains { $0.id == id }
    }
    
    /// Gets an output schema by ID
    public static func outputSchema(for id: String) -> OutputSchema? {
        allowedOutputSchemas.first { $0.id == id }
    }
    
    // MARK: - Export (Metadata Only)
    
    /// Exportable registry metadata (NO prompt text)
    public struct ExportableMetadata: Codable {
        public let schemaVersion: Int
        public let hashingVersion: String
        public let lastUpdateReason: String
        public let outputSchemaCount: Int
        public let outputSchemaIds: [String]
        public let exportedAt: Date
    }
    
    /// Exports registry metadata (NO prompt text)
    public static func exportMetadata() -> ExportableMetadata {
        ExportableMetadata(
            schemaVersion: schemaVersion,
            hashingVersion: hashingVersion,
            lastUpdateReason: lastUpdateReason,
            outputSchemaCount: allowedOutputSchemas.count,
            outputSchemaIds: allowedOutputSchemas.map { $0.id },
            exportedAt: Date()
        )
    }
    
    /// Exports metadata as JSON
    public static func exportMetadataJSON() throws -> Data {
        let metadata = exportMetadata()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(metadata)
    }
}

// MARK: - Integration with QualitySignature

extension QualitySignature {
    /// Creates a signature including prompt scaffold version
    public static func captureWithScaffold() -> QualitySignature {
        QualitySignature(
            appVersion: nil,
            buildNumber: nil,
            releaseMode: nil,
            safetyContractHash: nil,
            qualityGateConfigVersion: QualityGateThresholds.configVersion,
            promptScaffoldVersion: PromptScaffoldRegistry.schemaVersion,
            promptScaffoldHash: nil, // Computed hash not stored
            backendAvailability: nil,
            deterministicModelVersion: DeterministicTemplateModel.modelVersion
        )
    }
}
