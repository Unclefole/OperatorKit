import Foundation

// ============================================================================
// BUILD SEALS MODELS (Phase 13J)
//
// Data models for build-time proof seals: Entitlements, Dependencies, Symbols.
// All outputs are metadata-only (hashes, counts, booleans).
//
// CONSTRAINTS:
// ❌ No user content
// ❌ No paths (sanitized identifiers only)
// ✅ SHA256 hashes
// ✅ Counts and booleans
// ============================================================================

// MARK: - Schema Version

public enum BuildSealsSchemaVersion {
    public static let current = 1
}

// MARK: - Forbidden Keys

public enum BuildSealsForbiddenKeys {
    public static let all: Set<String> = [
        "body", "subject", "content", "draft", "prompt", "context",
        "message", "text", "recipient", "sender", "title", "description",
        "attendees", "email", "phone", "address", "name", "note", "notes",
        "userData", "personalData", "identifier", "deviceId", "userId",
        "path", "fullPath", "absolutePath", "homeDirectory", "userDirectory",
        "secret", "password", "token", "apiKey", "privateKey"
    ]
    
    public static func validate(_ json: String) -> [String] {
        var violations: [String] = []
        let lowercased = json.lowercased()
        
        for key in all {
            // Check for key as JSON field
            if lowercased.contains("\"\(key)\"") {
                violations.append("Contains forbidden key: \(key)")
            }
        }
        
        // Check for paths
        if lowercased.contains("/users/") || lowercased.contains("/home/") {
            violations.append("Contains filesystem path")
        }
        
        return violations
    }
}

// MARK: - Entitlements Seal

/// Seal for app entitlements (code signing proof)
public struct EntitlementsSeal: Codable, Equatable {
    /// SHA256 hash of the entitlements plist
    public let entitlementsHash: String
    
    /// Count of entitlement keys
    public let entitlementCount: Int
    
    /// Whether sandbox is enabled
    public let sandboxEnabled: Bool
    
    /// Whether network client is requested
    public let networkClientRequested: Bool
    
    /// Schema version
    public let schemaVersion: Int
    
    /// Generation timestamp (day-rounded)
    public let generatedAtDayRounded: String
    
    public init(
        entitlementsHash: String,
        entitlementCount: Int,
        sandboxEnabled: Bool,
        networkClientRequested: Bool,
        schemaVersion: Int = BuildSealsSchemaVersion.current,
        generatedAtDayRounded: String
    ) {
        self.entitlementsHash = entitlementsHash
        self.entitlementCount = entitlementCount
        self.sandboxEnabled = sandboxEnabled
        self.networkClientRequested = networkClientRequested
        self.schemaVersion = schemaVersion
        self.generatedAtDayRounded = generatedAtDayRounded
    }
    
    /// Validate seal contains no forbidden content
    public func validate() -> [String] {
        var violations: [String] = []
        
        // Hash should be hex only
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        if !entitlementsHash.unicodeScalars.allSatisfy({ hexCharacters.contains($0) }) {
            violations.append("entitlementsHash contains non-hex characters")
        }
        
        // Hash should be 64 characters (SHA256)
        if entitlementsHash.count != 64 {
            violations.append("entitlementsHash is not 64 characters")
        }
        
        return violations
    }
}

// MARK: - Dependency Seal

/// Seal for SPM dependencies (lockfile fingerprint)
public struct DependencySeal: Codable, Equatable {
    /// SHA256 hash of the normalized dependency list
    public let dependencyHash: String
    
    /// Count of direct dependencies
    public let dependencyCount: Int
    
    /// Count of transitive dependencies
    public let transitiveDependencyCount: Int
    
    /// Whether lockfile was found
    public let lockfilePresent: Bool
    
    /// Schema version
    public let schemaVersion: Int
    
    /// Generation timestamp (day-rounded)
    public let generatedAtDayRounded: String
    
    public init(
        dependencyHash: String,
        dependencyCount: Int,
        transitiveDependencyCount: Int,
        lockfilePresent: Bool,
        schemaVersion: Int = BuildSealsSchemaVersion.current,
        generatedAtDayRounded: String
    ) {
        self.dependencyHash = dependencyHash
        self.dependencyCount = dependencyCount
        self.transitiveDependencyCount = transitiveDependencyCount
        self.lockfilePresent = lockfilePresent
        self.schemaVersion = schemaVersion
        self.generatedAtDayRounded = generatedAtDayRounded
    }
    
    /// Validate seal contains no forbidden content
    public func validate() -> [String] {
        var violations: [String] = []
        
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        if !dependencyHash.unicodeScalars.allSatisfy({ hexCharacters.contains($0) }) {
            violations.append("dependencyHash contains non-hex characters")
        }
        
        if dependencyHash.count != 64 {
            violations.append("dependencyHash is not 64 characters")
        }
        
        return violations
    }
}

// MARK: - Symbol Seal

/// Seal for no-network symbol verification
public struct SymbolSeal: Codable, Equatable {
    /// SHA256 hash of the scanned symbol list (names only)
    public let symbolListHash: String
    
    /// Count of forbidden symbols detected
    public let forbiddenSymbolCount: Int
    
    /// Whether forbidden frameworks are present
    public let forbiddenFrameworkPresent: Bool
    
    /// Individual framework checks
    public let frameworkChecks: [SymbolFrameworkCheck]
    
    /// Total symbols scanned
    public let totalSymbolsScanned: Int
    
    /// Schema version
    public let schemaVersion: Int
    
    /// Generation timestamp (day-rounded)
    public let generatedAtDayRounded: String
    
    public init(
        symbolListHash: String,
        forbiddenSymbolCount: Int,
        forbiddenFrameworkPresent: Bool,
        frameworkChecks: [SymbolFrameworkCheck],
        totalSymbolsScanned: Int,
        schemaVersion: Int = BuildSealsSchemaVersion.current,
        generatedAtDayRounded: String
    ) {
        self.symbolListHash = symbolListHash
        self.forbiddenSymbolCount = forbiddenSymbolCount
        self.forbiddenFrameworkPresent = forbiddenFrameworkPresent
        self.frameworkChecks = frameworkChecks
        self.totalSymbolsScanned = totalSymbolsScanned
        self.schemaVersion = schemaVersion
        self.generatedAtDayRounded = generatedAtDayRounded
    }
    
    /// Validate seal contains no forbidden content
    public func validate() -> [String] {
        var violations: [String] = []
        
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        if !symbolListHash.unicodeScalars.allSatisfy({ hexCharacters.contains($0) }) {
            violations.append("symbolListHash contains non-hex characters")
        }
        
        if symbolListHash.count != 64 {
            violations.append("symbolListHash is not 64 characters")
        }
        
        return violations
    }
}

/// Individual framework check result
public struct SymbolFrameworkCheck: Codable, Equatable {
    /// Framework identifier (sanitized, no paths)
    public let framework: String
    
    /// Whether the framework was detected
    public let detected: Bool
    
    /// Severity if detected
    public let severity: String
    
    public init(framework: String, detected: Bool, severity: String) {
        self.framework = framework
        self.detected = detected
        self.severity = severity
    }
}

// MARK: - Combined Build Seals

/// Combined build seals packet
public struct BuildSealsPacket: Codable, Equatable {
    /// Entitlements seal
    public let entitlements: EntitlementsSeal?
    
    /// Dependency seal
    public let dependencies: DependencySeal?
    
    /// Symbol seal
    public let symbols: SymbolSeal?
    
    /// Overall status
    public let overallStatus: BuildSealsStatus
    
    /// Schema version
    public let schemaVersion: Int
    
    /// App version
    public let appVersion: String
    
    /// Build number
    public let buildNumber: String
    
    /// Generation timestamp (day-rounded)
    public let generatedAtDayRounded: String
    
    public init(
        entitlements: EntitlementsSeal?,
        dependencies: DependencySeal?,
        symbols: SymbolSeal?,
        overallStatus: BuildSealsStatus,
        schemaVersion: Int = BuildSealsSchemaVersion.current,
        appVersion: String,
        buildNumber: String,
        generatedAtDayRounded: String
    ) {
        self.entitlements = entitlements
        self.dependencies = dependencies
        self.symbols = symbols
        self.overallStatus = overallStatus
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.generatedAtDayRounded = generatedAtDayRounded
    }
    
    /// Validate packet contains no forbidden content
    public func validate() -> [String] {
        var violations: [String] = []
        
        if let e = entitlements {
            violations.append(contentsOf: e.validate().map { "entitlements: \($0)" })
        }
        
        if let d = dependencies {
            violations.append(contentsOf: d.validate().map { "dependencies: \($0)" })
        }
        
        if let s = symbols {
            violations.append(contentsOf: s.validate().map { "symbols: \($0)" })
        }
        
        // Validate JSON output
        if let json = toJSON() {
            violations.append(contentsOf: BuildSealsForbiddenKeys.validate(json))
        }
        
        return violations
    }
    
    /// Export as JSON
    public func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// Build seals overall status
public enum BuildSealsStatus: String, Codable, CaseIterable {
    case verified = "VERIFIED"
    case partial = "PARTIAL"
    case missing = "MISSING"
    case failed = "FAILED"
}

// MARK: - Summary for ProofPack

/// Summary of build seals for ProofPack integration
public struct BuildSealsSummary: Codable, Equatable {
    /// Entitlements hash (first 16 chars for brevity)
    public let entitlementsHashPrefix: String?
    
    /// Entitlement count
    public let entitlementCount: Int
    
    /// Dependency hash prefix
    public let dependencyHashPrefix: String?
    
    /// Dependency count
    public let dependencyCount: Int
    
    /// Symbol hash prefix
    public let symbolHashPrefix: String?
    
    /// Forbidden symbol count
    public let forbiddenSymbolCount: Int
    
    /// Forbidden framework present
    public let forbiddenFrameworkPresent: Bool
    
    /// Overall status
    public let overallStatus: String
    
    /// All seals present
    public let allSealsPresent: Bool
    
    public init(
        entitlementsHashPrefix: String?,
        entitlementCount: Int,
        dependencyHashPrefix: String?,
        dependencyCount: Int,
        symbolHashPrefix: String?,
        forbiddenSymbolCount: Int,
        forbiddenFrameworkPresent: Bool,
        overallStatus: String,
        allSealsPresent: Bool
    ) {
        self.entitlementsHashPrefix = entitlementsHashPrefix
        self.entitlementCount = entitlementCount
        self.dependencyHashPrefix = dependencyHashPrefix
        self.dependencyCount = dependencyCount
        self.symbolHashPrefix = symbolHashPrefix
        self.forbiddenSymbolCount = forbiddenSymbolCount
        self.forbiddenFrameworkPresent = forbiddenFrameworkPresent
        self.overallStatus = overallStatus
        self.allSealsPresent = allSealsPresent
    }
}
