import Foundation

// ============================================================================
// DOC INTEGRITY (Phase 10I, Hardened Phase 10J)
//
// Verifies that all required documentation files exist and are non-empty.
// Used by tests to ensure docs are not accidentally overwritten or deleted.
// Fail-closed for missing or empty documents.
//
// CONSTRAINTS:
// ✅ Read-only checks
// ✅ No file modification
// ✅ Test-time validation
// ✅ Fail-closed for missing/empty
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

// MARK: - Doc Integrity

public enum DocIntegrity {
    
    // MARK: - Required Documents
    
    /// Documents required since Phase 7B
    public static let requiredDocs: [RequiredDoc] = [
        RequiredDoc(
            name: "SAFETY_CONTRACT.md",
            path: "docs/SAFETY_CONTRACT.md",
            sincePhase: "7B",
            description: "Core safety guarantees and invariants",
            requiredSections: safetyContractSections
        ),
        RequiredDoc(
            name: "CLAIM_REGISTRY.md",
            path: "docs/CLAIM_REGISTRY.md",
            sincePhase: "7B",
            description: "Registry of all user-facing claims",
            requiredSections: claimRegistrySections
        ),
        RequiredDoc(
            name: "APP_REVIEW_PACKET.md",
            path: "docs/APP_REVIEW_PACKET.md",
            sincePhase: "7B",
            description: "Information packet for Apple App Review",
            requiredSections: appReviewPacketSections
        ),
        RequiredDoc(
            name: "RELEASE_APPROVAL.md",
            path: "docs/RELEASE_APPROVAL.md",
            sincePhase: "7B",
            description: "Release approval process and checklist",
            requiredSections: releaseApprovalSections
        ),
        RequiredDoc(
            name: "TESTFLIGHT_PREFLIGHT_CHECKLIST.md",
            path: "docs/TESTFLIGHT_PREFLIGHT_CHECKLIST.md",
            sincePhase: "7B",
            description: "Pre-TestFlight validation checklist",
            requiredSections: preflightChecklistSections
        ),
        RequiredDoc(
            name: "APP_STORE_SUBMISSION_CHECKLIST.md",
            path: "docs/APP_STORE_SUBMISSION_CHECKLIST.md",
            sincePhase: "10H",
            description: "App Store submission requirements",
            requiredSections: submissionChecklistSections
        )
    ]
    
    // MARK: - Required Sections Per Document
    
    /// Required sections in SAFETY_CONTRACT.md
    public static let safetyContractSections: [String] = [
        "APPROVAL REQUIREMENT",
        "NO BACKGROUND EXECUTION",
        "NO SILENT WRITES",
        "LOCAL-FIRST DATA",
        "PERMISSION AWARENESS",
        "MODEL FALLBACK",
        "MONETIZATION ENFORCEMENT",
        "LOCAL-ONLY CONVERSION TRACKING",
        "ONBOARDING METADATA-ONLY",
        "SUPPORT USER-INITIATED"
    ]
    
    /// Required sections in CLAIM_REGISTRY.md
    public static let claimRegistrySections: [String] = [
        "CLAIM-",
        "Validation Rules",
        "Change Log"
    ]
    
    /// Required sections in APP_REVIEW_PACKET.md
    public static let appReviewPacketSections: [String] = [
        "Safety Architecture",
        "Approval Flow",
        "Data Handling",
        "Monetization",
        "Contact"
    ]
    
    /// Required sections in RELEASE_APPROVAL.md
    public static let releaseApprovalSections: [String] = [
        "Pre-Release",
        "Checklist"
    ]
    
    /// Required sections in TESTFLIGHT_PREFLIGHT_CHECKLIST.md
    public static let preflightChecklistSections: [String] = [
        "Build",
        "Test"
    ]
    
    /// Required sections in APP_STORE_SUBMISSION_CHECKLIST.md (Phase 7B structure)
    public static let submissionChecklistSections: [String] = [
        "Pre-Submission",
        "App Store Connect",
        "Subscription Checklist",
        "Review Notes",
        "Post-Submission"
    ]
    
    // MARK: - Validation
    
    /// Validates all required documents exist
    public static func validateDocumentsExist(projectRoot: String) -> DocIntegrityResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        for doc in requiredDocs {
            let fullPath = (projectRoot as NSString).appendingPathComponent(doc.path)
            let fileManager = FileManager.default
            
            if !fileManager.fileExists(atPath: fullPath) {
                errors.append("Missing required document: \(doc.name) (since Phase \(doc.sincePhase))")
            } else {
                // Check if non-empty
                if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                   let size = attrs[.size] as? Int,
                   size == 0 {
                    errors.append("Document is empty: \(doc.name)")
                }
                
                // Check size (warning if suspiciously small)
                if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                   let size = attrs[.size] as? Int,
                   size < 100 {
                    warnings.append("Document may be incomplete: \(doc.name) (\(size) bytes)")
                }
            }
        }
        
        return DocIntegrityResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    /// Validates document content contains required sections
    public static func validateDocumentContent(
        _ content: String,
        docName: String,
        requiredSections: [String]
    ) -> [String] {
        var missing: [String] = []
        
        for section in requiredSections {
            if !content.contains(section) {
                missing.append("Missing section '\(section)' in \(docName)")
            }
        }
        
        return missing
    }
    
    /// Full validation including content checks
    public static func runFullValidation(projectRoot: String) -> DocIntegrityResult {
        var allErrors: [String] = []
        var allWarnings: [String] = []
        
        // Check existence
        let existenceResult = validateDocumentsExist(projectRoot: projectRoot)
        allErrors.append(contentsOf: existenceResult.errors)
        allWarnings.append(contentsOf: existenceResult.warnings)
        
        // Check SAFETY_CONTRACT.md content
        let safetyPath = (projectRoot as NSString).appendingPathComponent("docs/SAFETY_CONTRACT.md")
        if let content = try? String(contentsOfFile: safetyPath, encoding: .utf8) {
            let sectionErrors = validateDocumentContent(
                content,
                docName: "SAFETY_CONTRACT.md",
                requiredSections: safetyContractSections
            )
            allErrors.append(contentsOf: sectionErrors)
        }
        
        // Check CLAIM_REGISTRY.md content
        let claimPath = (projectRoot as NSString).appendingPathComponent("docs/CLAIM_REGISTRY.md")
        if let content = try? String(contentsOfFile: claimPath, encoding: .utf8) {
            let sectionErrors = validateDocumentContent(
                content,
                docName: "CLAIM_REGISTRY.md",
                requiredSections: claimRegistrySections
            )
            allErrors.append(contentsOf: sectionErrors)
        }
        
        // Check APP_STORE_SUBMISSION_CHECKLIST.md content
        let checklistPath = (projectRoot as NSString).appendingPathComponent("docs/APP_STORE_SUBMISSION_CHECKLIST.md")
        if let content = try? String(contentsOfFile: checklistPath, encoding: .utf8) {
            let sectionErrors = validateDocumentContent(
                content,
                docName: "APP_STORE_SUBMISSION_CHECKLIST.md",
                requiredSections: submissionChecklistSections
            )
            allErrors.append(contentsOf: sectionErrors)
        }
        
        return DocIntegrityResult(
            isValid: allErrors.isEmpty,
            errors: allErrors,
            warnings: allWarnings
        )
    }
}

    // MARK: - Hardened Validation (Phase 10J)
    
    /// Hardened validation with detailed section checking
    public static func runHardenedValidation(projectRoot: String) -> DocIntegrityResult {
        var allErrors: [String] = []
        var allWarnings: [String] = []
        var sectionResults: [String: SectionValidationResult] = [:]
        
        for doc in requiredDocs {
            let fullPath = (projectRoot as NSString).appendingPathComponent(doc.path)
            let fileManager = FileManager.default
            
            // Check existence (fail-closed)
            guard fileManager.fileExists(atPath: fullPath) else {
                allErrors.append("FAIL-CLOSED: Missing required document: \(doc.name)")
                sectionResults[doc.name] = SectionValidationResult(
                    docName: doc.name,
                    status: .missing,
                    presentSections: [],
                    missingSections: doc.requiredSections
                )
                continue
            }
            
            // Check non-empty (fail-closed)
            guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8),
                  !content.isEmpty else {
                allErrors.append("FAIL-CLOSED: Document is empty: \(doc.name)")
                sectionResults[doc.name] = SectionValidationResult(
                    docName: doc.name,
                    status: .empty,
                    presentSections: [],
                    missingSections: doc.requiredSections
                )
                continue
            }
            
            // Check minimum size
            if content.count < 100 {
                allWarnings.append("Document may be incomplete: \(doc.name) (\(content.count) chars)")
            }
            
            // Check required sections
            var presentSections: [String] = []
            var missingSections: [String] = []
            
            for section in doc.requiredSections {
                if content.contains(section) {
                    presentSections.append(section)
                } else {
                    missingSections.append(section)
                    allErrors.append("Missing section '\(section)' in \(doc.name)")
                }
            }
            
            let status: SectionValidationStatus = missingSections.isEmpty ? .valid : .incomplete
            sectionResults[doc.name] = SectionValidationResult(
                docName: doc.name,
                status: status,
                presentSections: presentSections,
                missingSections: missingSections
            )
        }
        
        return DocIntegrityResult(
            isValid: allErrors.isEmpty,
            errors: allErrors,
            warnings: allWarnings,
            sectionResults: sectionResults
        )
    }
}

// MARK: - Required Doc

public struct RequiredDoc {
    public let name: String
    public let path: String
    public let sincePhase: String
    public let description: String
    public let requiredSections: [String]
    
    public init(name: String, path: String, sincePhase: String, description: String, requiredSections: [String] = []) {
        self.name = name
        self.path = path
        self.sincePhase = sincePhase
        self.description = description
        self.requiredSections = requiredSections
    }
}

// MARK: - Result

public struct DocIntegrityResult {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    public let sectionResults: [String: SectionValidationResult]
    
    public init(isValid: Bool, errors: [String], warnings: [String], sectionResults: [String: SectionValidationResult] = [:]) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
        self.sectionResults = sectionResults
    }
    
    public var summary: String {
        if isValid && warnings.isEmpty {
            return "All documents valid"
        } else if isValid {
            return "Valid with \(warnings.count) warning(s)"
        } else {
            return "\(errors.count) error(s), \(warnings.count) warning(s)"
        }
    }
    
    /// For export in submission packet
    public var missingDocNames: [String] {
        sectionResults.filter { $0.value.status == .missing }.map { $0.key }
    }
}

// MARK: - Section Validation

public struct SectionValidationResult {
    public let docName: String
    public let status: SectionValidationStatus
    public let presentSections: [String]
    public let missingSections: [String]
}

public enum SectionValidationStatus: String {
    case valid = "valid"
    case incomplete = "incomplete"
    case empty = "empty"
    case missing = "missing"
}
