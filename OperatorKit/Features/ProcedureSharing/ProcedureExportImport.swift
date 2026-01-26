import Foundation

// ============================================================================
// PROCEDURE EXPORT / IMPORT (Phase 13B)
//
// Local-only export and import of procedure templates.
// Produces/consumes local files only. No network paths.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking
// ❌ No background operations
// ❌ No cloud storage
// ❌ No encryption keys transmitted
// ✅ Local file only
// ✅ Logic-only payload
// ✅ User confirmation required for import
// ✅ Validation against forbidden keys
// ============================================================================

// MARK: - Procedure Export

public enum ProcedureExporter {
    
    /// Export a procedure to local data
    public static func export(_ procedure: ProcedureTemplate) -> ExportResult {
        guard ProcedureSharingFeatureFlag.isEnabled else {
            return .failure("Procedure sharing is not enabled")
        }
        
        // Validate before export
        let validation = ProcedureTemplateValidator.validate(procedure)
        guard validation.isValid else {
            return .failure("Validation failed: \(validation.errors.joined(separator: ", "))")
        }
        
        // Create export packet
        let packet = ProcedureExportPacket(
            procedure: procedure,
            exportedAtDayRounded: currentDayRounded(),
            exportVersion: ProcedureExportPacket.currentVersion
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(packet)
            
            return .success(ProcedureExportData(
                data: data,
                filename: "procedure_\(procedure.id.uuidString.prefix(8)).json",
                procedureId: procedure.id
            ))
        } catch {
            return .failure("Export encoding failed: \(error.localizedDescription)")
        }
    }
    
    /// Export multiple procedures
    public static func exportMultiple(_ procedures: [ProcedureTemplate]) -> MultiExportResult {
        guard ProcedureSharingFeatureFlag.isEnabled else {
            return .failure("Procedure sharing is not enabled")
        }
        
        // Validate all
        for procedure in procedures {
            let validation = ProcedureTemplateValidator.validate(procedure)
            guard validation.isValid else {
                return .failure("Procedure '\(procedure.name)' failed validation")
            }
        }
        
        let packet = ProcedureBundleExportPacket(
            procedures: procedures,
            exportedAtDayRounded: currentDayRounded(),
            exportVersion: ProcedureBundleExportPacket.currentVersion
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(packet)
            
            return .success(ProcedureExportData(
                data: data,
                filename: "procedures_bundle_\(currentDayRounded()).json",
                procedureId: nil
            ))
        } catch {
            return .failure("Export encoding failed: \(error.localizedDescription)")
        }
    }
    
    private static func currentDayRounded() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
    
    // MARK: - Result Types
    
    public enum ExportResult {
        case success(ProcedureExportData)
        case failure(String)
    }
    
    public enum MultiExportResult {
        case success(ProcedureExportData)
        case failure(String)
    }
}

// MARK: - Procedure Import

public enum ProcedureImporter {
    
    /// Import a procedure from data (requires user confirmation)
    public static func importFromData(_ data: Data, confirmed: Bool) -> ImportResult {
        guard ProcedureSharingFeatureFlag.isEnabled else {
            return .failure("Procedure sharing is not enabled")
        }
        
        guard confirmed else {
            return .requiresConfirmation
        }
        
        // Try single procedure first
        if let packet = try? JSONDecoder().decode(ProcedureExportPacket.self, from: data) {
            return validateAndReturn(packet.procedure)
        }
        
        // Try bundle
        if let bundle = try? JSONDecoder().decode(ProcedureBundleExportPacket.self, from: data) {
            return validateAndReturnMultiple(bundle.procedures)
        }
        
        return .failure("Invalid procedure data format")
    }
    
    private static func validateAndReturn(_ procedure: ProcedureTemplate) -> ImportResult {
        // Strict validation against forbidden keys
        let validation = ProcedureTemplateValidator.validate(procedure)
        
        guard validation.isValid else {
            return .rejectedForbiddenKeys(validation.errors)
        }
        
        // Additional import-specific checks
        if containsForbiddenContent(procedure) {
            return .rejectedForbiddenKeys(["Procedure contains forbidden content patterns"])
        }
        
        return .success([procedure])
    }
    
    private static func validateAndReturnMultiple(_ procedures: [ProcedureTemplate]) -> ImportResult {
        var validated: [ProcedureTemplate] = []
        
        for procedure in procedures {
            let validation = ProcedureTemplateValidator.validate(procedure)
            guard validation.isValid else {
                return .rejectedForbiddenKeys(validation.errors)
            }
            
            if containsForbiddenContent(procedure) {
                return .rejectedForbiddenKeys(["Procedure '\(procedure.name)' contains forbidden content"])
            }
            
            validated.append(procedure)
        }
        
        return .success(validated)
    }
    
    private static func containsForbiddenContent(_ procedure: ProcedureTemplate) -> Bool {
        let allText = [
            procedure.name,
            procedure.intentSkeleton.intentType,
            procedure.intentSkeleton.promptScaffold
        ].joined(separator: " ")
        
        let lowercased = allText.lowercased()
        
        for pattern in ProcedureTemplateValidator.forbiddenPatterns {
            if lowercased.contains(pattern.lowercased()) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Result Types
    
    public enum ImportResult {
        case success([ProcedureTemplate])
        case requiresConfirmation
        case rejectedForbiddenKeys([String])
        case failure(String)
    }
}

// MARK: - Export Data

public struct ProcedureExportData {
    public let data: Data
    public let filename: String
    public let procedureId: UUID?
}

// MARK: - Export Packets

public struct ProcedureExportPacket: Codable {
    public let procedure: ProcedureTemplate
    public let exportedAtDayRounded: String
    public let exportVersion: Int
    
    public static let currentVersion = 1
}

public struct ProcedureBundleExportPacket: Codable {
    public let procedures: [ProcedureTemplate]
    public let exportedAtDayRounded: String
    public let exportVersion: Int
    
    public static let currentVersion = 1
}
