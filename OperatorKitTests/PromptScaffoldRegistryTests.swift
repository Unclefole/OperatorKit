import XCTest
@testable import OperatorKit

/// Tests for prompt scaffold registry (Phase 9B)
/// Ensures registry contains NO prompt text, only version metadata
final class PromptScaffoldRegistryTests: XCTestCase {
    
    // MARK: - Version Tests
    
    func testSchemaVersionIsPositive() {
        XCTAssertGreaterThan(PromptScaffoldRegistry.schemaVersion, 0)
    }
    
    func testHashingVersionIsNotEmpty() {
        XCTAssertFalse(PromptScaffoldRegistry.hashingVersion.isEmpty)
        XCTAssertTrue(PromptScaffoldRegistry.hashingVersion.contains("sha256"))
    }
    
    func testValidateReturnsEmpty() {
        let errors = PromptScaffoldRegistry.validate()
        XCTAssertTrue(errors.isEmpty, "Registry should be valid: \(errors)")
    }
    
    // MARK: - Output Schema Tests
    
    func testAllowedOutputSchemasNotEmpty() {
        XCTAssertFalse(PromptScaffoldRegistry.allowedOutputSchemas.isEmpty)
    }
    
    func testOutputSchemaVersionsArePositive() {
        for schema in PromptScaffoldRegistry.allowedOutputSchemas {
            XCTAssertGreaterThan(schema.version, 0, "Schema \(schema.id) should have version > 0")
        }
    }
    
    func testOutputSchemaIdsAreUnique() {
        let ids = PromptScaffoldRegistry.allowedOutputSchemas.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "Output schema IDs should be unique")
    }
    
    func testIsOutputSchemaAllowed() {
        XCTAssertTrue(PromptScaffoldRegistry.isOutputSchemaAllowed("email"))
        XCTAssertTrue(PromptScaffoldRegistry.isOutputSchemaAllowed("summary"))
        XCTAssertFalse(PromptScaffoldRegistry.isOutputSchemaAllowed("nonexistent"))
    }
    
    func testOutputSchemaLookup() {
        let emailSchema = PromptScaffoldRegistry.outputSchema(for: "email")
        XCTAssertNotNil(emailSchema)
        XCTAssertEqual(emailSchema?.id, "email")
        
        let nonexistent = PromptScaffoldRegistry.outputSchema(for: "nonexistent")
        XCTAssertNil(nonexistent)
    }
    
    // MARK: - No Prompt Text Tests
    
    func testRegistryContainsNoPromptText() {
        // Export metadata and verify no prompt text
        let metadata = PromptScaffoldRegistry.exportMetadata()
        
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(metadata),
           let json = String(data: data, encoding: .utf8) {
            // Should NOT contain prompt-related content
            XCTAssertFalse(json.contains("You are an AI assistant"))
            XCTAssertFalse(json.contains("system message"))
            XCTAssertFalse(json.contains("user message"))
            XCTAssertFalse(json.contains("instructions"))
            XCTAssertFalse(json.contains("prompt:"))
            XCTAssertFalse(json.contains("template:"))
            
            // Should only contain metadata
            XCTAssertTrue(json.contains("schemaVersion"))
            XCTAssertTrue(json.contains("hashingVersion"))
            XCTAssertTrue(json.contains("outputSchemaCount"))
        }
    }
    
    func testOutputSchemaDescriptionsAreGeneric() {
        for schema in PromptScaffoldRegistry.allowedOutputSchemas {
            // Descriptions should be generic, not actual prompt content
            XCTAssertFalse(schema.description.contains("You are"))
            XCTAssertFalse(schema.description.contains("Generate"))
            XCTAssertFalse(schema.description.contains("Please"))
            XCTAssertTrue(schema.description.count < 100, "Description should be short metadata")
        }
    }
    
    // MARK: - Export Tests
    
    func testExportMetadataContainsExpectedFields() {
        let metadata = PromptScaffoldRegistry.exportMetadata()
        
        XCTAssertEqual(metadata.schemaVersion, PromptScaffoldRegistry.schemaVersion)
        XCTAssertEqual(metadata.hashingVersion, PromptScaffoldRegistry.hashingVersion)
        XCTAssertEqual(metadata.outputSchemaCount, PromptScaffoldRegistry.allowedOutputSchemas.count)
        XCTAssertEqual(metadata.outputSchemaIds.count, PromptScaffoldRegistry.allowedOutputSchemas.count)
    }
    
    func testExportMetadataToJSON() throws {
        let json = try PromptScaffoldRegistry.exportMetadataJSON()
        XCTAssertFalse(json.isEmpty)
        
        // Should be valid JSON
        let decoded = try JSONDecoder().decode(
            PromptScaffoldRegistry.ExportableMetadata.self,
            from: json
        )
        XCTAssertEqual(decoded.schemaVersion, PromptScaffoldRegistry.schemaVersion)
    }
    
    // MARK: - Validation Tests
    
    func testValidationErrors() {
        // Test that validation error descriptions are meaningful
        let errors: [PromptScaffoldRegistry.ValidationError] = [
            .schemaVersionInvalid,
            .hashingVersionEmpty,
            .noOutputSchemas,
            .duplicateOutputSchema("test"),
            .outputSchemaVersionInvalid("test")
        ]
        
        for error in errors {
            XCTAssertFalse(error.description.isEmpty)
        }
    }
}
