import Foundation
import os.log

// MARK: - Release Logger (Phase 7B)
//
// Provides structured logging that is:
// - Strictly local (no external transmission)
// - DEBUG-gated (verbose output only in DEBUG)
// - Privacy-safe (no PII in logs)
// - Useful for debugging without compromising user privacy
//
// INVARIANT: No log data is ever transmitted externally

/// Log categories for structured logging
public enum LogCategory: String {
    case flow = "Flow"
    case permission = "Permission"
    case model = "Model"
    case execution = "Execution"
    case audit = "Audit"
    case siri = "Siri"
    case preflight = "Preflight"
    case error = "Error"
    case monetization = "Monetization"  // Phase 10A
    case diagnostics = "Diagnostics"    // Phase 10I
    case policy = "Policy"              // Policy logging
    case safety = "Safety"              // Safety contract logging
    case team = "Team"                  // Team-related logging
    case lifecycle = "Lifecycle"        // App lifecycle events
    case storageFailure = "StorageFailure" // Critical storage errors
}

/// Log levels
public enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

/// Privacy-safe, local-only logger
public final class ReleaseLogger {
    
    public static let shared = ReleaseLogger()
    
    /// Subsystem for os_log
    private let subsystem = "com.operatorkit.app"
    
    /// Cached loggers by category
    private var loggers: [LogCategory: OSLog] = [:]
    
    /// Minimum log level (DEBUG: all, RELEASE: warning+)
    private let minimumLevel: LogLevel
    
    /// Whether verbose logging is enabled
    private let verboseEnabled: Bool
    
    private init() {
        #if DEBUG
        self.minimumLevel = .debug
        self.verboseEnabled = true
        #else
        self.minimumLevel = .warning
        self.verboseEnabled = false
        #endif
    }
    
    // MARK: - Logging Methods
    
    /// Log a debug message (DEBUG builds only)
    public func debug(_ message: String, category: LogCategory = .flow, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// Log an info message
    public func info(_ message: String, category: LogCategory = .flow, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    public func warning(_ message: String, category: LogCategory = .flow, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// Log an error message
    public func error(_ message: String, category: LogCategory = .error, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging
    
    private func log(level: LogLevel, message: String, category: LogCategory, file: String, function: String, line: Int) {
        // Skip if below minimum level
        guard level >= minimumLevel else { return }
        
        // Get or create logger for category
        let logger = getLogger(for: category)
        
        // Build log message
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        
        #if DEBUG
        // Verbose format in DEBUG
        let fullMessage = "\(level.emoji) [\(category.rawValue)] \(fileName):\(line) \(function) - \(message)"
        print(fullMessage)
        #endif
        
        // Also log to os_log (visible in Console.app)
        os_log("%{public}@", log: logger, type: level.osLogType, message)
    }
    
    private func getLogger(for category: LogCategory) -> OSLog {
        if let existing = loggers[category] {
            return existing
        }
        
        let logger = OSLog(subsystem: subsystem, category: category.rawValue)
        loggers[category] = logger
        return logger
    }
    
    // MARK: - Structured Logging
    
    /// Log a flow step transition
    public func flowStep(from: String, to: String) {
        debug("Flow: \(from) → \(to)", category: .flow)
    }
    
    /// Log a permission request
    public func permissionRequest(_ permission: String, granted: Bool) {
        info("Permission \(permission): \(granted ? "granted" : "denied")", category: .permission)
    }
    
    /// Log model generation
    public func modelGeneration(backend: String, latencyMs: Int, confidence: Double) {
        debug("Model: \(backend), latency: \(latencyMs)ms, confidence: \(String(format: "%.2f", confidence))", category: .model)
    }
    
    /// Log execution step
    public func executionStep(_ step: String, success: Bool) {
        info("Execution: \(step) - \(success ? "success" : "failed")", category: .execution)
    }
    
    /// Log audit event
    public func auditEvent(_ event: String, itemId: String) {
        debug("Audit: \(event) for \(itemId.prefix(8))...", category: .audit)
    }
    
    /// Log Siri route
    public func siriRoute(intentText: String) {
        // Privacy: Only log that Siri routed, not the content
        info("Siri: Routed to app with intent (\(intentText.count) chars)", category: .siri)
    }
    
    /// Log preflight check
    public func preflightCheck(_ name: String, passed: Bool) {
        let level: LogLevel = passed ? .debug : .warning
        log(level: level, message: "Preflight: \(name) - \(passed ? "passed" : "FAILED")", category: .preflight, file: #file, function: #function, line: #line)
    }
}

// MARK: - Convenience Global Functions

/// Log a debug message (DEBUG builds only)
public func logDebug(_ message: String, category: LogCategory = .flow) {
    #if DEBUG
    ReleaseLogger.shared.debug(message, category: category)
    #endif
}

/// Log an info message
public func logInfo(_ message: String, category: LogCategory = .flow) {
    ReleaseLogger.shared.info(message, category: category)
}

/// Log a warning message
public func logWarning(_ message: String, category: LogCategory = .flow) {
    ReleaseLogger.shared.warning(message, category: category)
}

/// Log an error message
public func logError(_ message: String, category: LogCategory = .error) {
    ReleaseLogger.shared.error(message, category: category)
}

// MARK: - Privacy Guarantees

/*
 LOGGING PRIVACY GUARANTEES
 ==========================
 
 1. NO EXTERNAL TRANSMISSION
    - All logs stay on-device
    - No crash reporting to external servers
    - No analytics transmission
    - os_log is local system logging only
 
 2. NO PII IN LOGS
    - Never log: email addresses, names, calendar event details
    - Only log: counts, durations, success/failure states
    - Use prefix() to truncate IDs
 
 3. DEBUG-GATED VERBOSE OUTPUT
    - Detailed logs only in DEBUG builds
    - RELEASE builds log warnings and errors only
    - Console.app access requires physical device access
 
 4. STRUCTURED FOR DEBUGGING
    - Categories help filter relevant logs
    - Consistent format for easy parsing
    - File/line info in DEBUG for quick navigation
 
 */
