import Foundation
import os.log

/// Centralized logging utility
final class AppLogger {
    
    static let shared = AppLogger()
    
    private let logger: Logger
    
    private init() {
        self.logger = Logger(subsystem: "com.operatorkit.app", category: "general")
    }
    
    // MARK: - Log Levels
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        logger.debug("[\(fileName):\(line)] \(function) - \(message)")
        #endif
    }
    
    func info(_ message: String) {
        logger.info("\(message)")
    }
    
    func warning(_ message: String) {
        logger.warning("⚠️ \(message)")
    }
    
    func error(_ message: String) {
        logger.error("❌ \(message)")
    }
    
    // MARK: - Domain-Specific Logging
    
    func logIntent(_ intent: IntentRequest) {
        info("Intent resolved: \(intent.intentType.rawValue) - \"\(intent.rawText.prefix(50))...\"")
    }
    
    func logApproval(granted: Bool) {
        if granted {
            info("✅ Approval granted by user")
        } else {
            warning("Approval denied or pending")
        }
    }
    
    func logExecution(result: ExecutionResultModel) {
        info("Execution complete: \(result.status.rawValue) - \(result.message)")
    }
    
    // MARK: - Invariant Logging
    
    func logInvariantCheck(_ invariant: String, passed: Bool) {
        if passed {
            debug("Invariant check passed: \(invariant)")
        } else {
            error("INVARIANT VIOLATION: \(invariant)")
        }
    }
}

// MARK: - Convenience Functions

func log(_ message: String) {
    AppLogger.shared.info(message)
}

func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.debug(message, file: file, function: function, line: line)
}

func logError(_ message: String) {
    AppLogger.shared.error(message)
}
