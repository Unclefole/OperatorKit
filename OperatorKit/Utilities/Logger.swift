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

    // MARK: - Security Logging (Phase: Input Validation)

    /// Log when an intent is blocked due to validation failure
    /// - Parameter reasons: Array of reasons why the intent was blocked
    func logIntentBlocked(reasons: [InputValidationReason]) {
        let reasonStrings = reasons.map { $0.rawValue }
        warning("Intent blocked: \(reasonStrings.joined(separator: ", "))")
    }
}

// MARK: - Input Validation Types

/// Result of validating user input before processing
enum InputValidationResult: Equatable {
    case valid
    case invalid([InputValidationReason])

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var reasons: [InputValidationReason] {
        if case .invalid(let reasons) = self { return reasons }
        return []
    }
}

/// Reasons why input validation failed
enum InputValidationReason: String, CaseIterable {
    case emptyRequest = "empty_request"
    case requestTooBroad = "request_too_broad"
    case noContextSelected = "no_context_selected"
    case noMeetingSelected = "no_meeting_selected"

    /// User-facing description of the issue
    var userDescription: String {
        switch self {
        case .emptyRequest:
            return "Please enter a request"
        case .requestTooBroad:
            return "Request is too broad — try being more specific"
        case .noContextSelected:
            return "No context selected — select meetings, emails, or files"
        case .noMeetingSelected:
            return "No meeting selected — helps identify attendees and topics"
        }
    }

    /// Severity for FallbackView display
    var severity: IssueRow.IssueSeverity {
        switch self {
        case .emptyRequest, .noContextSelected:
            return .high
        case .requestTooBroad, .noMeetingSelected:
            return .medium
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

/// Log when an intent is blocked due to validation failure (convenience)
func logIntentBlocked(reasons: [InputValidationReason]) {
    AppLogger.shared.logIntentBlocked(reasons: reasons)
}
