import Foundation

// ============================================================================
// TEAM ARTIFACT VALIDATOR (Phase 10E)
//
// Validates team artifacts before upload to ensure they are content-free.
// Extends SyncPacketValidator with team-specific rules.
//
// INVARIANT: Fail closed — if uncertain, block upload
// INVARIANT: No user content in team artifacts
//
// See: docs/SAFETY_CONTRACT.md (Section 14)
// ============================================================================

/// Validates team artifacts for upload safety
public final class TeamArtifactValidator {
    
    // MARK: - Singleton
    
    public static let shared = TeamArtifactValidator()
    
    private init() {}
    
    // MARK: - Validation
    
    /// Validates a team artifact
    /// INVARIANT: Fail closed — if uncertain, reject
    public func validate(
        jsonData: Data,
        artifactType: TeamSafetyConfig.TeamArtifactType
    ) -> TeamArtifactValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // 1. Use base sync validator rules
        let syncResult = SyncPacketValidator.shared.validate(
            jsonData: jsonData,
            packetType: mapToSyncPacketType(artifactType)
        )
        
        if !syncResult.isValid {
            errors.append(contentsOf: syncResult.errors)
        }
        warnings.append(contentsOf: syncResult.warnings)
        
        // 2. Parse JSON for additional team-specific checks
        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            errors.append("Invalid JSON format")
            return .invalid(errors: errors, warnings: warnings)
        }
        
        // 3. Check for team-specific forbidden keys
        let teamForbiddenKeys = findTeamForbiddenKeys(in: jsonDict)
        if !teamForbiddenKeys.isEmpty {
            for key in teamForbiddenKeys {
                errors.append("Team artifact contains forbidden key: \"\(key)\"")
            }
        }
        
        // 4. Validate artifact-type-specific rules
        let typeErrors = validateArtifactType(jsonDict, type: artifactType)
        errors.append(contentsOf: typeErrors)
        
        // 5. Check required fields
        if !containsKey("schemaVersion", in: jsonDict) {
            errors.append("Missing required field: schemaVersion")
        }
        if !containsKey("capturedAt", in: jsonDict) && !containsKey("createdAt", in: jsonDict) {
            errors.append("Missing required timestamp field")
        }
        
        if errors.isEmpty {
            return .valid()
        } else {
            return .invalid(errors: errors, warnings: warnings)
        }
    }
    
    /// Validates a typed team artifact
    public func validate<T: Codable>(
        _ artifact: T,
        as artifactType: TeamSafetyConfig.TeamArtifactType
    ) -> (result: TeamArtifactValidationResult, data: Data?) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        
        guard let data = try? encoder.encode(artifact) else {
            return (.invalid(errors: ["Failed to encode artifact"]), nil)
        }
        
        let result = validate(jsonData: data, artifactType: artifactType)
        return (result, result.isValid ? data : nil)
    }
    
    // MARK: - Type-Specific Validation
    
    private func validateArtifactType(
        _ dict: [String: Any],
        type: TeamSafetyConfig.TeamArtifactType
    ) -> [String] {
        var errors: [String] = []
        
        switch type {
        case .policyTemplate:
            // Must have policy settings
            if dict["allowEmailDrafts"] == nil {
                errors.append("Policy template missing: allowEmailDrafts")
            }
            
        case .diagnosticsSnapshot:
            // Must have aggregate stats
            if dict["totalExecutions"] == nil && dict["executionsToday"] == nil {
                errors.append("Diagnostics snapshot missing execution counts")
            }
            
        case .qualitySummary:
            // Must have quality metrics
            if dict["qualityScore"] == nil && dict["coverageScore"] == nil {
                errors.append("Quality summary missing quality metrics")
            }
            
        case .evidencePacketRef:
            // Must have hash
            if dict["packetHash"] == nil {
                errors.append("Evidence reference missing packetHash")
            }
            
        case .releaseAcknowledgement:
            // Must have release version
            if dict["releaseVersion"] == nil {
                errors.append("Release acknowledgement missing releaseVersion")
            }
            // Check notes length
            if let notes = dict["notes"] as? String,
               notes.count > TeamReleaseAcknowledgement.maxNotesLength {
                errors.append("Release notes exceed maximum length (\(TeamReleaseAcknowledgement.maxNotesLength) chars)")
            }
        }
        
        return errors
    }
    
    // MARK: - Helpers
    
    /// Additional forbidden keys for team artifacts
    private let teamForbiddenKeys = [
        "password",
        "secret",
        "token",
        "key",
        "credential",
        "apiKey",
        "api_key",
        "private",
        "ssn",
        "creditCard",
        "credit_card"
    ]
    
    private func findTeamForbiddenKeys(in dict: [String: Any], parentKey: String = "") -> [String] {
        var found: [String] = []
        
        for (key, value) in dict {
            let fullKey = parentKey.isEmpty ? key : "\(parentKey).\(key)"
            
            // Check team-specific forbidden keys
            if teamForbiddenKeys.contains(where: { key.lowercased().contains($0.lowercased()) }) {
                found.append(fullKey)
            }
            
            // Recursively check nested objects
            if let nested = value as? [String: Any] {
                found.append(contentsOf: findTeamForbiddenKeys(in: nested, parentKey: fullKey))
            }
            
            if let array = value as? [[String: Any]] {
                for (index, item) in array.enumerated() {
                    found.append(contentsOf: findTeamForbiddenKeys(in: item, parentKey: "\(fullKey)[\(index)]"))
                }
            }
        }
        
        return found
    }
    
    private func containsKey(_ key: String, in dict: [String: Any]) -> Bool {
        if dict[key] != nil { return true }
        for value in dict.values {
            if let nested = value as? [String: Any] {
                if containsKey(key, in: nested) { return true }
            }
        }
        return false
    }
    
    private func mapToSyncPacketType(
        _ teamType: TeamSafetyConfig.TeamArtifactType
    ) -> SyncSafetyConfig.SyncablePacketType {
        switch teamType {
        case .policyTemplate:
            return .policyExport
        case .diagnosticsSnapshot:
            return .diagnosticsExport
        case .qualitySummary:
            return .qualityExport
        case .evidencePacketRef:
            return .evidencePacket
        case .releaseAcknowledgement:
            return .releaseAcknowledgement
        }
    }
}

// MARK: - Validation Result

/// Result of team artifact validation
public struct TeamArtifactValidationResult {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    
    public static func valid() -> TeamArtifactValidationResult {
        TeamArtifactValidationResult(isValid: true, errors: [], warnings: [])
    }
    
    public static func invalid(errors: [String], warnings: [String] = []) -> TeamArtifactValidationResult {
        TeamArtifactValidationResult(isValid: false, errors: errors, warnings: warnings)
    }
}

// MARK: - Convenience Validators

extension TeamArtifactValidator {
    
    /// Validates a TeamPolicyTemplate
    public func validatePolicyTemplate(
        _ template: TeamPolicyTemplate
    ) -> (TeamArtifactValidationResult, Data?) {
        validate(template, as: .policyTemplate)
    }
    
    /// Validates a TeamDiagnosticsSnapshot
    public func validateDiagnosticsSnapshot(
        _ snapshot: TeamDiagnosticsSnapshot
    ) -> (TeamArtifactValidationResult, Data?) {
        validate(snapshot, as: .diagnosticsSnapshot)
    }
    
    /// Validates a TeamQualitySummary
    public func validateQualitySummary(
        _ summary: TeamQualitySummary
    ) -> (TeamArtifactValidationResult, Data?) {
        validate(summary, as: .qualitySummary)
    }
    
    /// Validates a TeamEvidencePacketRef
    public func validateEvidenceRef(
        _ ref: TeamEvidencePacketRef
    ) -> (TeamArtifactValidationResult, Data?) {
        validate(ref, as: .evidencePacketRef)
    }
    
    /// Validates a TeamReleaseAcknowledgement
    public func validateReleaseAck(
        _ ack: TeamReleaseAcknowledgement
    ) -> (TeamArtifactValidationResult, Data?) {
        validate(ack, as: .releaseAcknowledgement)
    }
}
