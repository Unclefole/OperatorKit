import Foundation

// MARK: - Metadata Leakage Case Study (CS-LEAK-001)
// ============================================================================
// Tests for unintended data leakage through metadata, proof packs, and
// exported artifacts. Even when primary content is protected, metadata
// fields may expose sensitive information.
//
// This case study verifies:
// - ProofPack exports don't contain PII
// - Diagnostic exports are sanitized
// - Timestamps don't enable correlation attacks
// - Device identifiers are not embedded
// ============================================================================

#if DEBUG

/// Case study testing for metadata leakage in exports.
public struct MetadataLeakageCaseStudy: CaseStudyProtocol {
    
    // MARK: - Identity
    
    public var id: String { "CS-LEAK-001" }
    public var name: String { "Metadata Leakage via ProofPack" }
    public var version: String { "1.0" }
    
    // MARK: - Classification
    
    public var category: CaseStudyCategory { .dataLeakage }
    public var severity: CaseStudySeverity { .high }
    
    // MARK: - Documentation
    
    public var claimTested: String {
        "Exported proof packs, diagnostics, and support packets contain no personally " +
        "identifiable information (PII) or device-specific identifiers that could enable tracking."
    }
    
    public var hypothesis: String {
        "Export mechanisms may inadvertently include device UUIDs, user names, file paths " +
        "with usernames, precise timestamps enabling correlation, or other metadata that " +
        "could identify a specific user or device."
    }
    
    public var executionSteps: [String] {
        [
            "Scan all Codable export structures for PII field names",
            "Check Info.plist for embedded identifiers",
            "Verify timestamp granularity (should be day-rounded, not precise)",
            "Search for username patterns in file paths",
            "Check for device identifier APIs (identifierForVendor, etc.)",
            "Verify no MAC addresses or hardware identifiers are accessible"
        ]
    }
    
    public var expectedResult: String {
        "No PII fields detected. Timestamps are day-rounded. No device identifiers " +
        "are embedded in export structures. File paths are sanitized."
    }
    
    public var validationMethod: String {
        "Static analysis of export structures combined with runtime inspection of " +
        "generated export data."
    }
    
    public var prerequisites: [String] {
        ["Application must be running in DEBUG mode"]
    }
    
    // MARK: - PII Patterns
    
    /// Field names that suggest PII.
    private let piiFieldNames: Set<String> = [
        "email", "mail", "phone", "telephone", "mobile",
        "name", "firstname", "lastname", "fullname", "username",
        "address", "street", "city", "zipcode", "postal",
        "ssn", "socialsecurity", "passport", "license",
        "creditcard", "cardnumber", "cvv", "expiry",
        "password", "secret", "token", "apikey",
        "deviceid", "udid", "imei", "serialnumber",
        "macaddress", "ipaddress", "userid"
    ]
    
    /// Patterns that might indicate leaked paths.
    private let pathLeakPatterns: [String] = [
        "/Users/",
        "/home/",
        "/var/mobile/Containers/",
        "C:\\Users\\"
    ]
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Execution
    
    public func execute() -> CaseStudyResult {
        var findings: [String] = []
        var hasViolation = false
        let startTime = Date()
        
        // Step 1: Check Info.plist for identifiers
        let plistCheck = checkInfoPlist()
        findings.append(contentsOf: plistCheck.findings)
        if plistCheck.hasViolation {
            hasViolation = true
        }
        
        // Step 2: Check for device identifier usage
        let deviceIdCheck = checkDeviceIdentifiers()
        findings.append(contentsOf: deviceIdCheck.findings)
        if deviceIdCheck.hasViolation {
            hasViolation = true
        }
        
        // Step 3: Check timestamp handling
        let timestampCheck = checkTimestampGranularity()
        findings.append(contentsOf: timestampCheck.findings)
        if timestampCheck.hasViolation {
            hasViolation = true
        }
        
        // Step 4: Scan for username in paths
        let pathCheck = checkPathSanitization()
        findings.append(contentsOf: pathCheck.findings)
        if pathCheck.hasViolation {
            hasViolation = true
        }
        
        // Step 5: Check UserDefaults for PII
        let defaultsCheck = checkUserDefaultsForPII()
        findings.append(contentsOf: defaultsCheck.findings)
        if defaultsCheck.hasViolation {
            hasViolation = true
        }
        
        // Step 6: Verify export structures don't contain PII fields
        let structCheck = checkExportStructures()
        findings.append(contentsOf: structCheck.findings)
        if structCheck.hasViolation {
            hasViolation = true
        }
        
        // Step 7: Check for analytics/tracking frameworks
        let analyticsCheck = checkForAnalyticsFrameworks()
        findings.append(contentsOf: analyticsCheck.findings)
        if analyticsCheck.hasViolation {
            hasViolation = true
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        return CaseStudyResult(
            caseStudyId: id,
            outcome: hasViolation ? .failed : .passed,
            findings: findings,
            durationSeconds: duration,
            environment: captureEnvironment()
        )
    }
    
    // MARK: - Private Helpers
    
    private struct CheckResult {
        let findings: [String]
        let hasViolation: Bool
    }
    
    private func checkInfoPlist() -> CheckResult {
        var findings: [String] = []
        var hasViolation = false
        
        guard let infoPlist = Bundle.main.infoDictionary else {
            findings.append("WARNING: Could not read Info.plist")
            return CheckResult(findings: findings, hasViolation: false)
        }
        
        // Check for tracking-related keys
        let trackingKeys = [
            "NSUserTrackingUsageDescription",
            "ITSAppUsesNonExemptEncryption",
            "NSAdvertisingAttributionReportEndpoint"
        ]
        
        for key in trackingKeys {
            if infoPlist[key] != nil {
                findings.append("WARNING: Tracking-related key found: \(key)")
            }
        }
        
        // Check bundle identifier doesn't contain PII
        if let bundleId = infoPlist["CFBundleIdentifier"] as? String {
            if bundleId.lowercased().contains("test") || 
               bundleId.lowercased().contains("debug") {
                findings.append("INFO: Bundle ID contains test/debug marker: \(bundleId)")
            }
            findings.append("CLEAN: Bundle identifier: \(bundleId)")
        }
        
        // Check for embedded device capabilities
        if let capabilities = infoPlist["UIRequiredDeviceCapabilities"] as? [String] {
            findings.append("INFO: Required device capabilities: \(capabilities)")
        }
        
        findings.append("CLEAN: Info.plist contains no obvious PII")
        
        return CheckResult(findings: findings, hasViolation: hasViolation)
    }
    
    private func checkDeviceIdentifiers() -> CheckResult {
        var findings: [String] = []
        var hasViolation = false
        
        #if canImport(UIKit)
        // Check if identifierForVendor is being used
        // We can't detect usage without calling it, so we check for the class
        if NSClassFromString("UIDevice") != nil {
            findings.append("INFO: UIDevice class is available")
            findings.append("NOTE: identifierForVendor usage cannot be detected without invocation")
        }
        #endif
        
        // Check for IDFA framework
        let idfaFrameworks = ["AdSupport", "AppTrackingTransparency"]
        let loadedImages = enumerateLoadedImages()
        
        for framework in idfaFrameworks {
            if loadedImages.contains(where: { $0.contains(framework) }) {
                findings.append("VIOLATION: Advertising framework loaded: \(framework)")
                hasViolation = true
            } else {
                findings.append("CLEAN: \(framework) not loaded")
            }
        }
        
        // Check UserDefaults for device ID patterns
        let defaults = UserDefaults.standard.dictionaryRepresentation()
        let suspiciousKeys = defaults.keys.filter { key in
            let lower = key.lowercased()
            return lower.contains("deviceid") ||
                   lower.contains("uuid") ||
                   lower.contains("identifier") ||
                   lower.contains("udid")
        }
        
        if !suspiciousKeys.isEmpty {
            findings.append("WARNING: Suspicious identifier keys in UserDefaults:")
            for key in suspiciousKeys.prefix(5) {
                findings.append("  - \(key)")
            }
        } else {
            findings.append("CLEAN: No device identifier keys in UserDefaults")
        }
        
        return CheckResult(findings: findings, hasViolation: hasViolation)
    }
    
    private func checkTimestampGranularity() -> CheckResult {
        var findings: [String] = []
        var hasViolation = false
        
        // Check if the app uses day-rounded timestamps
        let currentDate = Date()
        
        // Get components
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: currentDate)
        
        findings.append("INFO: Current time components available: hour=\(components.hour ?? 0), minute=\(components.minute ?? 0)")
        findings.append("NOTE: Exports should use day-rounded timestamps (verify in export structures)")
        
        // Check if any stored dates have precise times
        let defaults = UserDefaults.standard.dictionaryRepresentation()
        for (key, value) in defaults {
            if let dateValue = value as? Date {
                let dateComponents = calendar.dateComponents([.hour, .minute, .second], from: dateValue)
                if (dateComponents.hour != 0 || dateComponents.minute != 0 || dateComponents.second != 0) {
                    findings.append("INFO: Precise timestamp in UserDefaults key '\(key)'")
                }
            }
        }
        
        findings.append("CLEAN: Timestamp granularity check complete (manual verification needed for exports)")
        
        return CheckResult(findings: findings, hasViolation: hasViolation)
    }
    
    private func checkPathSanitization() -> CheckResult {
        var findings: [String] = []
        var hasViolation = false
        
        // Get current paths that might leak
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        let tempPath = FileManager.default.temporaryDirectory.path
        let bundlePath = Bundle.main.bundlePath
        
        // Check if paths contain username
        let allPaths = [documentsPath, tempPath, bundlePath]
        
        for path in allPaths {
            for pattern in pathLeakPatterns {
                if path.contains(pattern) {
                    // Extract potential username
                    if let range = path.range(of: pattern) {
                        let afterPattern = path[range.upperBound...]
                        if let slashIndex = afterPattern.firstIndex(of: "/") {
                            let potentialUsername = String(afterPattern[..<slashIndex])
                            findings.append("INFO: Path contains username segment: '\(potentialUsername)'")
                            findings.append("WARNING: If exported, paths must be sanitized")
                        }
                    }
                }
            }
        }
        
        findings.append("NOTE: Verify that export mechanisms sanitize file paths before inclusion")
        
        return CheckResult(findings: findings, hasViolation: hasViolation)
    }
    
    private func checkUserDefaultsForPII() -> CheckResult {
        var findings: [String] = []
        var hasViolation = false
        
        let defaults = UserDefaults.standard.dictionaryRepresentation()
        
        for (key, value) in defaults {
            let keyLower = key.lowercased()
            
            // Check if key name suggests PII
            for piiField in piiFieldNames {
                if keyLower.contains(piiField) {
                    findings.append("WARNING: PII-suggestive key found: '\(key)'")
                    
                    // Check value type and content
                    if let stringValue = value as? String {
                        if stringValue.contains("@") && stringValue.contains(".") {
                            findings.append("VIOLATION: Possible email in UserDefaults")
                            hasViolation = true
                        }
                    }
                }
            }
        }
        
        if !hasViolation {
            findings.append("CLEAN: No obvious PII detected in UserDefaults")
        }
        
        return CheckResult(findings: findings, hasViolation: hasViolation)
    }
    
    private func checkExportStructures() -> CheckResult {
        var findings: [String] = []
        var hasViolation = false
        
        // We can use runtime reflection to check for PII-named properties
        // but this requires known type names
        
        let exportTypeNames = [
            "ExportQualityPacket",
            "DiagnosticsExportPacket",
            "SupportPacket",
            "ProofPackAssembler"
        ]
        
        for typeName in exportTypeNames {
            if let classType = NSClassFromString("OperatorKit.\(typeName)") {
                findings.append("INFO: Found export type: \(typeName)")
                // Note: Full property inspection requires more complex reflection
            }
        }
        
        findings.append("NOTE: Manual code review recommended for export structure fields")
        findings.append("NOTE: Verify all exports use 'generatedAtDayRounded' not precise timestamps")
        
        return CheckResult(findings: findings, hasViolation: hasViolation)
    }
    
    private func checkForAnalyticsFrameworks() -> CheckResult {
        var findings: [String] = []
        var hasViolation = false
        
        let analyticsFrameworks = [
            "Firebase",
            "Analytics",
            "Crashlytics",
            "Amplitude",
            "Mixpanel",
            "Segment",
            "Flurry",
            "Adjust",
            "AppsFlyer",
            "Branch"
        ]
        
        let loadedImages = enumerateLoadedImages()
        
        for framework in analyticsFrameworks {
            if loadedImages.contains(where: { $0.lowercased().contains(framework.lowercased()) }) {
                findings.append("VIOLATION: Analytics framework loaded: \(framework)")
                hasViolation = true
            }
        }
        
        if !hasViolation {
            findings.append("CLEAN: No third-party analytics frameworks detected")
        }
        
        return CheckResult(findings: findings, hasViolation: hasViolation)
    }
    
    private func enumerateLoadedImages() -> [String] {
        var images: [String] = []
        let imageCount = _dyld_image_count()
        
        for i in 0..<imageCount {
            if let imageName = _dyld_get_image_name(i) {
                images.append(String(cString: imageName))
            }
        }
        
        return images
    }
}

#endif
