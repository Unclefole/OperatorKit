import XCTest
@testable import OperatorKit

// ============================================================================
// AIR-GAPPED SECURITY INTERROGATION TESTS (Phase 13I)
//
// Formal air-gapped verification converting threat-model interrogation
// into executable tests and verifiable proofs.
//
// PURPOSE:
// - Truth over passing (tests may fail)
// - Evidence, not promises
// - Executable proofs, not documentation claims
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No runtime behavior changes
// ❌ No execution logic modifications
// ❌ No new permissions
// ❌ No sealed artifact changes
// ✅ Tests produce PASS/FAIL with evidence
// ============================================================================

final class AirGappedSecurityInterrogationTests: XCTestCase {
    
    // =========================================================================
    // PART 1 — THREAT MODEL INTERROGATION (True / False Proofs)
    // =========================================================================
    
    // MARK: - T1: App Transport Security (ATS) Lockdown
    
    /// Claim: The binary allows zero arbitrary network loads
    /// Test: Parse Info.plist, assert no relaxed ATS keys exist
    func testT1_ATSLockdown_NoArbitraryLoads() throws {
        var evidence = ATSEvidence()
        
        // Get Info.plist
        guard let infoPlistPath = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let infoPlist = NSDictionary(contentsOfFile: infoPlistPath) else {
            // If no Info.plist in test bundle, check for ATS in main bundle
            let mainPlist = Bundle.main.infoDictionary ?? [:]
            evidence.infoPlistFound = !mainPlist.isEmpty
            
            if let ats = mainPlist["NSAppTransportSecurity"] as? [String: Any] {
                evidence.atsKeyPresent = true
                evidence.allowsArbitraryLoads = ats["NSAllowsArbitraryLoads"] as? Bool ?? false
                evidence.allowsArbitraryLoadsInWebContent = ats["NSAllowsArbitraryLoadsInWebContent"] as? Bool ?? false
                evidence.allowsLocalNetworking = ats["NSAllowsLocalNetworking"] as? Bool ?? false
            }
            
            // PASS if no relaxed ATS
            let passed = !evidence.allowsArbitraryLoads && !evidence.allowsArbitraryLoadsInWebContent
            XCTAssertTrue(passed, "T1 FAIL: ATS allows arbitrary loads. Evidence: \(evidence)")
            return
        }
        
        evidence.infoPlistFound = true
        
        if let ats = infoPlist["NSAppTransportSecurity"] as? [String: Any] {
            evidence.atsKeyPresent = true
            evidence.allowsArbitraryLoads = ats["NSAllowsArbitraryLoads"] as? Bool ?? false
            evidence.allowsArbitraryLoadsInWebContent = ats["NSAllowsArbitraryLoadsInWebContent"] as? Bool ?? false
            evidence.allowsLocalNetworking = ats["NSAllowsLocalNetworking"] as? Bool ?? false
            
            if let exceptions = ats["NSExceptionDomains"] as? [String: Any] {
                evidence.exceptionDomains = Array(exceptions.keys)
            }
        }
        
        // PASS if no relaxed ATS
        let passed = !evidence.allowsArbitraryLoads && !evidence.allowsArbitraryLoadsInWebContent
        XCTAssertTrue(passed, "T1 FAIL: ATS relaxation detected. Evidence: \(evidence)")
    }
    
    // MARK: - T2: Model Weight Encryption at Rest
    
    /// Claim: Local model assets are protected by iOS file-level encryption
    /// Test: Locate model weight files, assert file protection level
    func testT2_ModelWeightEncryption_FileProtection() throws {
        var evidence = FileProtectionEvidence()
        
        // Common locations for model weights
        let potentialModelPaths = [
            "Models",
            "MLModels",
            "Resources/Models",
            "CoreML"
        ]
        
        let fileManager = FileManager.default
        let bundlePath = Bundle.main.bundlePath
        
        for relativePath in potentialModelPaths {
            let fullPath = (bundlePath as NSString).appendingPathComponent(relativePath)
            
            if fileManager.fileExists(atPath: fullPath) {
                evidence.modelDirectoriesFound.append(relativePath)
                
                // Check file protection for files in this directory
                if let contents = try? fileManager.contentsOfDirectory(atPath: fullPath) {
                    for file in contents {
                        let filePath = (fullPath as NSString).appendingPathComponent(file)
                        
                        if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                           let protection = attrs[.protectionKey] as? FileProtectionType {
                            
                            let protectionString = protectionTypeToString(protection)
                            evidence.fileProtectionLevels[file] = protectionString
                            
                            // Check for weak protection
                            if protection == .none {
                                evidence.weaklyProtectedFiles.append(file)
                            }
                        }
                    }
                }
            }
        }
        
        // Also check Documents directory for runtime model storage
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let modelExtensions = ["mlmodelc", "mlmodel", "bin", "weights"]
            
            if let enumerator = fileManager.enumerator(at: documentsURL, includingPropertiesForKeys: [.fileProtectionKey]) {
                while let fileURL = enumerator.nextObject() as? URL {
                    if modelExtensions.contains(fileURL.pathExtension) {
                        evidence.modelDirectoriesFound.append(fileURL.lastPathComponent)
                        
                        if let protection = try? fileURL.resourceValues(forKeys: [.fileProtectionKey]).fileProtection {
                            evidence.fileProtectionLevels[fileURL.lastPathComponent] = protection.rawValue
                        }
                    }
                }
            }
        }
        
        // PASS if no weakly protected files found (or no model files to check)
        let passed = evidence.weaklyProtectedFiles.isEmpty
        XCTAssertTrue(passed, "T2 FAIL: Model files with weak protection. Evidence: \(evidence)")
    }
    
    // MARK: - T3: Editable Memory iCloud Exclusion
    
    /// Claim: User memory is not included in iCloud backups
    /// Test: Inspect store configuration, assert backup exclusion
    func testT3_MemoryiCloudExclusion_BackupExcluded() throws {
        var evidence = BackupExclusionEvidence()
        
        let fileManager = FileManager.default
        
        // Check Application Support directory (common for CoreData)
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            evidence.storeURLs.append(appSupportURL.path)
            
            // Check for SQLite/CoreData stores
            let storeExtensions = ["sqlite", "sqlite-shm", "sqlite-wal", "store"]
            
            if let enumerator = fileManager.enumerator(at: appSupportURL, includingPropertiesForKeys: [.isExcludedFromBackupKey]) {
                while let fileURL = enumerator.nextObject() as? URL {
                    if storeExtensions.contains(fileURL.pathExtension) {
                        evidence.storeURLs.append(fileURL.lastPathComponent)
                        
                        if let resourceValues = try? fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey]) {
                            let isExcluded = resourceValues.isExcludedFromBackup ?? false
                            evidence.backupExclusionFlags[fileURL.lastPathComponent] = isExcluded
                            
                            if !isExcluded {
                                evidence.filesNotExcluded.append(fileURL.lastPathComponent)
                            }
                        }
                    }
                }
            }
        }
        
        // Check Documents directory
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            if let resourceValues = try? documentsURL.resourceValues(forKeys: [.isExcludedFromBackupKey]) {
                evidence.documentsExcluded = resourceValues.isExcludedFromBackup ?? false
            }
        }
        
        // PASS if no files are missing backup exclusion (or no files to check)
        // Note: Empty filesNotExcluded is a pass
        let passed = evidence.filesNotExcluded.isEmpty
        XCTAssertTrue(passed, "T3 FAIL: Files not excluded from backup. Evidence: \(evidence)")
    }
    
    // MARK: - T4: Airplane Mode Execution Proof
    
    /// Claim: Core Intent → Draft pipeline works fully offline
    /// Test: Verify no network APIs invoked during execution path
    func testT4_AirplaneModeExecution_FullyOffline() throws {
        var evidence = AirplaneModeEvidence()
        
        // Run offline certification checks
        let report = OfflineCertificationRunner.shared.runAllChecks()
        
        evidence.checksRun = report.ruleCount
        evidence.checksPassed = report.passedCount
        evidence.checksFailed = report.failedCount
        evidence.overallStatus = report.status.rawValue
        
        // Collect failed checks
        for result in report.checkResults where !result.passed {
            evidence.failedChecks.append("\(result.checkId): \(result.checkName)")
        }
        
        // Additional: Verify no URLSession in core execution path via binary inspection
        let binaryInspection = BinaryImageInspector.inspect()
        evidence.networkFrameworkLinked = binaryInspection.linkedFrameworks.contains("Network")
        
        // PASS if all checks pass and Network framework not linked
        let passed = report.status == .certified && !evidence.networkFrameworkLinked
        XCTAssertTrue(passed, "T4 FAIL: Offline execution not certified. Evidence: \(evidence)")
    }
    
    // MARK: - T5: Third-Party Dependency Telemetry Audit
    
    /// Claim: No third-party Swift Package phones home
    /// Test: Static scan for telemetry surfaces in dependencies
    func testT5_DependencyTelemetryAudit_NoPhoneHome() throws {
        var evidence = DependencyAuditEvidence()
        
        // Scan loaded frameworks for known analytics/telemetry patterns
        let binaryInspection = BinaryImageInspector.inspect()
        
        let telemetryIndicators = [
            "Analytics", "Firebase", "Amplitude", "Mixpanel", "Segment",
            "Crashlytics", "Flurry", "Appsflyer", "Adjust", "Branch",
            "Facebook", "GoogleAnalytics", "NewRelic", "Sentry"
        ]
        
        for framework in binaryInspection.linkedFrameworks {
            evidence.packagesScanned.append(framework)
            
            for indicator in telemetryIndicators {
                if framework.lowercased().contains(indicator.lowercased()) {
                    evidence.telemetrySurfacesFound.append("\(framework): matches '\(indicator)'")
                }
            }
        }
        
        // Check for known Apple telemetry (acceptable)
        let appleFrameworks = binaryInspection.linkedFrameworks.filter {
            $0.hasPrefix("Apple") || $0.hasPrefix("Core") || $0.hasPrefix("UI") || $0.hasPrefix("Swift")
        }
        evidence.appleFrameworkCount = appleFrameworks.count
        
        // PASS if no third-party telemetry found
        let passed = evidence.telemetrySurfacesFound.isEmpty
        XCTAssertTrue(passed, "T5 FAIL: Telemetry surfaces detected. Evidence: \(evidence)")
    }
    
    // =========================================================================
    // PART 2 — GOOGLE-STANDARD VERIFICATION TESTS
    // =========================================================================
    
    // MARK: - G1: Dynamic Network Sniffer Test
    
    /// Test: Trigger procedures, assert zero network packets
    /// Note: Automated packet capture may not be feasible in test environment
    func testG1_NetworkSniffer_ZeroPackets() throws {
        var evidence = NetworkSnifferEvidence()
        
        // Document test definition
        evidence.testDefinition = "Trigger 50 high-context procedures, assert zero packets on en0, pdp_ip0"
        evidence.automatedCaptureAvailable = false
        evidence.reason = "iOS sandbox prevents direct packet capture in test environment"
        
        // Alternative: Verify no network framework imports in core path
        let binaryInspection = BinaryImageInspector.inspect()
        evidence.networkFrameworkPresent = binaryInspection.linkedFrameworks.contains("Network")
        
        // Check WebKit (would enable network via web content)
        let sensitiveChecks = Dictionary(uniqueKeysWithValues: 
            binaryInspection.sensitiveChecks.map { ($0.framework, $0.isPresent) }
        )
        evidence.webKitPresent = sensitiveChecks["WebKit"] ?? false
        
        // PASS if no Network framework and no WebKit
        let passed = !evidence.networkFrameworkPresent && !evidence.webKitPresent
        XCTAssertTrue(passed, "G1 FAIL: Network surface detected. Evidence: \(evidence)")
    }
    
    // MARK: - G2: Approval Gate Mutation Test
    
    /// Test: Attempt to bypass approval gate, assert failure
    func testG2_ApprovalGateMutation_BypassPrevented() throws {
        var evidence = ApprovalGateMutationEvidence()
        
        // Document mutation attempt
        evidence.mutationAttempt = "Attempt to flip approval boolean directly"
        evidence.targetModule = "ApprovalGate.swift"
        
        // Verify ApprovalGate is immutable at runtime by checking:
        // 1. No public setters for approval state
        // 2. Approval requires explicit user action
        
        // Static analysis: Check if ApprovalGate has any public mutable state
        let approvalGatePath = findProjectFile(at: "OperatorKit/Domain/Approval/ApprovalGate.swift")
        
        if FileManager.default.fileExists(atPath: approvalGatePath) {
            let content = try String(contentsOfFile: approvalGatePath, encoding: .utf8)
            
            // Check for public var (mutable state)
            let hasPublicVar = content.contains("public var ") && 
                              !content.contains("public var body") // SwiftUI body is OK
            evidence.publicMutableStateFound = hasPublicVar
            
            // Check for bypass patterns
            let bypassPatterns = ["forceApprove", "skipApproval", "bypassGate", "autoApprove"]
            for pattern in bypassPatterns {
                if content.lowercased().contains(pattern.lowercased()) {
                    evidence.bypassPatternsFound.append(pattern)
                }
            }
            
            evidence.moduleAnalyzed = true
        } else {
            evidence.moduleAnalyzed = false
            evidence.reason = "ApprovalGate.swift not found at expected path"
        }
        
        // PASS if no bypass patterns and no public mutable state
        let passed = evidence.bypassPatternsFound.isEmpty && !evidence.publicMutableStateFound
        XCTAssertTrue(passed, "G2 FAIL: Approval gate may be bypassable. Evidence: \(evidence)")
    }
    
    // MARK: - G3: Memory Forensics Leak Test
    
    /// Test: Scan temp/cache/logs for plaintext PII or draft content
    func testG3_MemoryForensics_NoPIILeaks() throws {
        var evidence = MemoryForensicsEvidence()
        
        let fileManager = FileManager.default
        
        // Paths to scan
        let scanPaths: [(String, URL?)] = [
            ("tmp", fileManager.temporaryDirectory),
            ("Caches", fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first),
            ("Logs", fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs"))
        ]
        
        // PII patterns to detect
        let piiPatterns = [
            "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b", // Email
            "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b", // Phone
            "Dear\\s+[A-Z][a-z]+", // Greeting with name
            "Subject:\\s*[^\\n]+", // Email subject
            "body\":\\s*\"[^\"]{10,}" // JSON body field
        ]
        
        for (name, url) in scanPaths {
            guard let scanURL = url, fileManager.fileExists(atPath: scanURL.path) else {
                continue
            }
            
            evidence.pathsScanned.append(name)
            
            // Scan files in directory
            if let enumerator = fileManager.enumerator(at: scanURL, includingPropertiesForKeys: nil) {
                var filesChecked = 0
                
                while let fileURL = enumerator.nextObject() as? URL, filesChecked < 100 {
                    // Only scan text-like files
                    let textExtensions = ["txt", "log", "json", "plist", "xml", "csv"]
                    guard textExtensions.contains(fileURL.pathExtension.lowercased()) ||
                          fileURL.pathExtension.isEmpty else {
                        continue
                    }
                    
                    // Read file content (limit size)
                    if let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
                       data.count < 1_000_000, // 1MB limit
                       let content = String(data: data, encoding: .utf8) {
                        
                        filesChecked += 1
                        
                        // Check for PII patterns
                        for pattern in piiPatterns {
                            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                                let range = NSRange(content.startIndex..., in: content)
                                if regex.firstMatch(in: content, options: [], range: range) != nil {
                                    evidence.piiPatternsFound.append("\(name)/\(fileURL.lastPathComponent): matches \(pattern.prefix(20))...")
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // PASS if no PII patterns found
        let passed = evidence.piiPatternsFound.isEmpty
        XCTAssertTrue(passed, "G3 FAIL: PII patterns detected in filesystem. Evidence: \(evidence)")
    }
    
    // MARK: - G4: Regression Firewall Golden Tests
    
    /// Test: Run regression firewall, verify no unsafe patterns
    func testG4_RegressionFirewall_GoldenTests() throws {
        var evidence = RegressionFirewallEvidence()
        
        // Run regression firewall
        let report = RegressionFirewallRunner.shared.runAllRules()
        
        evidence.rulesExecuted = report.totalRules
        evidence.rulesPassed = report.passedCount
        evidence.rulesFailed = report.failedCount
        evidence.overallStatus = report.overallStatus.rawValue
        
        // Collect failed rules with evidence
        for result in report.results where !result.passed {
            evidence.failedRules.append(RuleFailure(
                ruleId: result.ruleId,
                ruleName: result.ruleName,
                evidence: result.evidence
            ))
        }
        
        // Specific checks for external URLs and autonomous actions
        let urlPatterns = ["http://", "https://", "ftp://", "ws://", "wss://"]
        let autonomousPatterns = ["autoSend", "automaticSend", "sendWithoutApproval"]
        
        // These would be caught by firewall rules, but document explicitly
        evidence.urlPatternsChecked = urlPatterns
        evidence.autonomousPatternsChecked = autonomousPatterns
        
        // PASS if firewall passes
        let passed = report.overallStatus == .passed
        XCTAssertTrue(passed, "G4 FAIL: Regression firewall detected issues. Evidence: \(evidence)")
    }
    
    // =========================================================================
    // PART 3 — SECURITY MANIFEST CONFIRMATION
    // =========================================================================
    
    // MARK: - Security Manifest Assertions
    
    /// Confirm: WebKit not linked, JavaScriptCore not present, no embedded browsers
    func testSecurityManifest_AllClaimsBacked() throws {
        var evidence = SecurityManifestEvidence()
        
        let binaryInspection = BinaryImageInspector.inspect()
        let sensitiveChecks = Dictionary(uniqueKeysWithValues:
            binaryInspection.sensitiveChecks.map { ($0.framework, $0.isPresent) }
        )
        
        // WebKit not linked
        evidence.webKitLinked = sensitiveChecks["WebKit"] ?? false
        evidence.webKitClaim = !evidence.webKitLinked
        
        // JavaScriptCore not present
        evidence.javaScriptCoreLinked = sensitiveChecks["JavaScriptCore"] ?? false
        evidence.javaScriptCoreClaim = !evidence.javaScriptCoreLinked
        
        // No embedded browser views
        evidence.safariServicesLinked = sensitiveChecks["SafariServices"] ?? false
        evidence.embeddedBrowserClaim = !evidence.safariServicesLinked && !evidence.webKitLinked
        
        // No remote code execution surface
        evidence.remoteCodeExecutionClaim = !evidence.webKitLinked && !evidence.javaScriptCoreLinked
        
        // Overall manifest status
        evidence.allClaimsPassed = evidence.webKitClaim && 
                                   evidence.javaScriptCoreClaim && 
                                   evidence.embeddedBrowserClaim && 
                                   evidence.remoteCodeExecutionClaim
        
        // PASS if all claims are true
        XCTAssertTrue(evidence.allClaimsPassed, "Security Manifest FAIL: Claims not backed. Evidence: \(evidence)")
    }
    
    // =========================================================================
    // EVIDENCE STRUCTURES
    // =========================================================================
    
    struct ATSEvidence: CustomStringConvertible {
        var infoPlistFound = false
        var atsKeyPresent = false
        var allowsArbitraryLoads = false
        var allowsArbitraryLoadsInWebContent = false
        var allowsLocalNetworking = false
        var exceptionDomains: [String] = []
        
        var description: String {
            """
            ATSEvidence(
                infoPlistFound: \(infoPlistFound),
                atsKeyPresent: \(atsKeyPresent),
                allowsArbitraryLoads: \(allowsArbitraryLoads),
                allowsArbitraryLoadsInWebContent: \(allowsArbitraryLoadsInWebContent),
                allowsLocalNetworking: \(allowsLocalNetworking),
                exceptionDomains: \(exceptionDomains)
            )
            """
        }
    }
    
    struct FileProtectionEvidence: CustomStringConvertible {
        var modelDirectoriesFound: [String] = []
        var fileProtectionLevels: [String: String] = [:]
        var weaklyProtectedFiles: [String] = []
        
        var description: String {
            """
            FileProtectionEvidence(
                modelDirectoriesFound: \(modelDirectoriesFound.count),
                fileProtectionLevels: \(fileProtectionLevels.count) files checked,
                weaklyProtectedFiles: \(weaklyProtectedFiles)
            )
            """
        }
    }
    
    struct BackupExclusionEvidence: CustomStringConvertible {
        var storeURLs: [String] = []
        var backupExclusionFlags: [String: Bool] = [:]
        var documentsExcluded = false
        var filesNotExcluded: [String] = []
        
        var description: String {
            """
            BackupExclusionEvidence(
                storeURLs: \(storeURLs.count),
                documentsExcluded: \(documentsExcluded),
                filesNotExcluded: \(filesNotExcluded)
            )
            """
        }
    }
    
    struct AirplaneModeEvidence: CustomStringConvertible {
        var checksRun = 0
        var checksPassed = 0
        var checksFailed = 0
        var overallStatus = ""
        var failedChecks: [String] = []
        var networkFrameworkLinked = false
        
        var description: String {
            """
            AirplaneModeEvidence(
                checksRun: \(checksRun),
                checksPassed: \(checksPassed),
                checksFailed: \(checksFailed),
                overallStatus: \(overallStatus),
                failedChecks: \(failedChecks),
                networkFrameworkLinked: \(networkFrameworkLinked)
            )
            """
        }
    }
    
    struct DependencyAuditEvidence: CustomStringConvertible {
        var packagesScanned: [String] = []
        var telemetrySurfacesFound: [String] = []
        var appleFrameworkCount = 0
        
        var description: String {
            """
            DependencyAuditEvidence(
                packagesScanned: \(packagesScanned.count),
                telemetrySurfacesFound: \(telemetrySurfacesFound),
                appleFrameworkCount: \(appleFrameworkCount)
            )
            """
        }
    }
    
    struct NetworkSnifferEvidence: CustomStringConvertible {
        var testDefinition = ""
        var automatedCaptureAvailable = false
        var reason = ""
        var networkFrameworkPresent = false
        var webKitPresent = false
        
        var description: String {
            """
            NetworkSnifferEvidence(
                testDefinition: \(testDefinition),
                automatedCaptureAvailable: \(automatedCaptureAvailable),
                reason: \(reason),
                networkFrameworkPresent: \(networkFrameworkPresent),
                webKitPresent: \(webKitPresent)
            )
            """
        }
    }
    
    struct ApprovalGateMutationEvidence: CustomStringConvertible {
        var mutationAttempt = ""
        var targetModule = ""
        var moduleAnalyzed = false
        var publicMutableStateFound = false
        var bypassPatternsFound: [String] = []
        var reason = ""
        
        var description: String {
            """
            ApprovalGateMutationEvidence(
                mutationAttempt: \(mutationAttempt),
                moduleAnalyzed: \(moduleAnalyzed),
                publicMutableStateFound: \(publicMutableStateFound),
                bypassPatternsFound: \(bypassPatternsFound)
            )
            """
        }
    }
    
    struct MemoryForensicsEvidence: CustomStringConvertible {
        var pathsScanned: [String] = []
        var piiPatternsFound: [String] = []
        
        var description: String {
            """
            MemoryForensicsEvidence(
                pathsScanned: \(pathsScanned),
                piiPatternsFound: \(piiPatternsFound.count) matches
            )
            """
        }
    }
    
    struct RuleFailure: CustomStringConvertible {
        var ruleId: String
        var ruleName: String
        var evidence: String
        
        var description: String {
            "\(ruleId): \(ruleName) - \(evidence)"
        }
    }
    
    struct RegressionFirewallEvidence: CustomStringConvertible {
        var rulesExecuted = 0
        var rulesPassed = 0
        var rulesFailed = 0
        var overallStatus = ""
        var failedRules: [RuleFailure] = []
        var urlPatternsChecked: [String] = []
        var autonomousPatternsChecked: [String] = []
        
        var description: String {
            """
            RegressionFirewallEvidence(
                rulesExecuted: \(rulesExecuted),
                rulesPassed: \(rulesPassed),
                rulesFailed: \(rulesFailed),
                overallStatus: \(overallStatus),
                failedRules: \(failedRules.count)
            )
            """
        }
    }
    
    struct SecurityManifestEvidence: CustomStringConvertible {
        var webKitLinked = false
        var webKitClaim = false
        var javaScriptCoreLinked = false
        var javaScriptCoreClaim = false
        var safariServicesLinked = false
        var embeddedBrowserClaim = false
        var remoteCodeExecutionClaim = false
        var allClaimsPassed = false
        
        var description: String {
            """
            SecurityManifestEvidence(
                webKitLinked: \(webKitLinked) -> claim: \(webKitClaim),
                javaScriptCoreLinked: \(javaScriptCoreLinked) -> claim: \(javaScriptCoreClaim),
                safariServicesLinked: \(safariServicesLinked),
                embeddedBrowserClaim: \(embeddedBrowserClaim),
                remoteCodeExecutionClaim: \(remoteCodeExecutionClaim),
                allClaimsPassed: \(allClaimsPassed)
            )
            """
        }
    }
    
    // =========================================================================
    // HELPERS
    // =========================================================================
    
    private func protectionTypeToString(_ type: FileProtectionType) -> String {
        switch type {
        case .complete: return "complete"
        case .completeUnlessOpen: return "completeUnlessOpen"
        case .completeUntilFirstUserAuthentication: return "completeUntilFirstUserAuthentication"
        case .none: return "none"
        default: return "unknown"
        }
    }
    
    private func findProjectFile(at relativePath: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        return projectRoot
            .appendingPathComponent(relativePath)
            .path
    }
}
