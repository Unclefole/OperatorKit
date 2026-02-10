import Foundation

/// App-specific error types (internal)
enum OperatorKitError: Error, LocalizedError {
    
    // MARK: - Flow Errors
    case invalidFlowState(expected: String, actual: String)
    case missingRequiredData(field: String)
    case flowInterrupted(reason: String)
    
    // MARK: - Invariant Violations
    case invariantViolation(invariant: String)
    case approvalRequired
    case contextNotSelected
    case executionNotApproved
    
    // MARK: - Processing Errors
    case intentResolutionFailed(reason: String)
    case planGenerationFailed(reason: String)
    case draftGenerationFailed(reason: String)
    case executionFailed(reason: String)
    
    // MARK: - Data Errors
    case dataCorrupted(details: String)
    case storageFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFlowState(let expected, let actual):
            return "Invalid flow state. Expected: \(expected), Actual: \(actual)"
        case .missingRequiredData(let field):
            return "Missing required data: \(field)"
        case .flowInterrupted(let reason):
            return "Flow interrupted: \(reason)"
        case .invariantViolation(let invariant):
            return "INVARIANT VIOLATION: \(invariant)"
        case .approvalRequired:
            return "User approval is required before execution"
        case .contextNotSelected:
            return "Context must be explicitly selected by user"
        case .executionNotApproved:
            return "Cannot execute without explicit user approval"
        case .intentResolutionFailed(let reason):
            return "Failed to resolve intent: \(reason)"
        case .planGenerationFailed(let reason):
            return "Failed to generate plan: \(reason)"
        case .draftGenerationFailed(let reason):
            return "Failed to generate draft: \(reason)"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        case .dataCorrupted(let details):
            return "Data corrupted: \(details)"
        case .storageFailed(let reason):
            return "Storage operation failed: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidFlowState:
            return "Try starting over from the home screen"
        case .missingRequiredData:
            return "Please provide all required information"
        case .approvalRequired, .executionNotApproved:
            return "Please review and approve the draft before execution"
        case .contextNotSelected:
            return "Please select specific items to include as context"
        default:
            return "Please try again or contact support if the issue persists"
        }
    }
}

// MARK: - User-Facing Error (Phase 5B)

/// User-safe error type for UI display — never exposes technical details
struct OperatorKitUserFacingError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let recoveryActions: [RecoveryAction]
    
    /// Primary recovery action (first in list)
    var primaryRecovery: AppState.RecoveryAction {
        // Map to AppState.RecoveryAction
        switch recoveryActions.first ?? .goHome {
        case .retryCurrentStep: return .retryCurrentStep
        case .editRequest: return .editRequest
        case .addMoreContext: return .addMoreContext
        case .goHome: return .goHome
        case .openSettings: return .openSettings
        case .viewMemory: return .viewMemory
        }
    }
    
    /// Recovery actions specific to user-facing errors
    enum RecoveryAction: String, Equatable {
        case retryCurrentStep = "Try Again"
        case editRequest = "Edit Request"
        case addMoreContext = "Add More Context"
        case goHome = "Back to Home"
        case openSettings = "Open Settings"
        case viewMemory = "View Memory"
        
        var icon: String {
            switch self {
            case .retryCurrentStep: return "arrow.clockwise"
            case .editRequest: return "pencil"
            case .addMoreContext: return "plus.circle"
            case .goHome: return "house"
            case .openSettings: return "gear"
            case .viewMemory: return "clock.arrow.circlepath"
            }
        }
    }
    
    static func == (lhs: OperatorKitUserFacingError, rhs: OperatorKitUserFacingError) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Factory Methods for Known Error Types
    
    /// Permission is missing for required operation
    static func permissionMissing(for permission: String) -> OperatorKitUserFacingError {
        OperatorKitUserFacingError(
            title: "Permission Needed",
            message: "\(permission) access is currently off. Allow access in Settings to continue.",
            recoveryActions: [.openSettings, .goHome]
        )
    }
    
    /// Calendar write was blocked
    static func calendarWriteBlocked(reason: String) -> OperatorKitUserFacingError {
        OperatorKitUserFacingError(
            title: "Calendar Write Blocked",
            message: "The calendar event could not be created. \(reason)",
            recoveryActions: [.retryCurrentStep, .goHome]
        )
    }
    
    /// Reminder write was blocked
    static func reminderWriteBlocked(reason: String) -> OperatorKitUserFacingError {
        OperatorKitUserFacingError(
            title: "Reminder Write Blocked",
            message: "The reminder could not be created. \(reason)",
            recoveryActions: [.retryCurrentStep, .goHome]
        )
    }
    
    /// Model generation timed out
    static func modelTimeout() -> OperatorKitUserFacingError {
        OperatorKitUserFacingError(
            title: "Draft Generation Slow",
            message: "Creating your draft took longer than expected. A simpler method was used instead.",
            recoveryActions: [.retryCurrentStep, .addMoreContext]
        )
    }
    
    /// Output validation failed
    static func validationFailed(details: String) -> OperatorKitUserFacingError {
        OperatorKitUserFacingError(
            title: "Draft Needs Adjustment",
            message: "The generated draft needs review. \(details)",
            recoveryActions: [.editRequest, .addMoreContext]
        )
    }
    
    /// Citation validity failed
    static func citationInvalid() -> OperatorKitUserFacingError {
        OperatorKitUserFacingError(
            title: "Context Mismatch",
            message: "Some references couldn't be matched to your selected context. The draft may need review.",
            recoveryActions: [.addMoreContext, .retryCurrentStep]
        )
    }
    
    /// Two-key confirmation expired (>60s)
    static func twoKeyExpired() -> OperatorKitUserFacingError {
        OperatorKitUserFacingError(
            title: "Confirmation Expired",
            message: "Your confirmation has expired for security. Please confirm again to continue.",
            recoveryActions: [.retryCurrentStep]
        )
    }
    
    /// Generic operation failed
    static func operationFailed(context: String) -> OperatorKitUserFacingError {
        OperatorKitUserFacingError(
            title: "Something Went Wrong",
            message: "OperatorKit couldn't complete the \(context). Please try again.",
            recoveryActions: [.retryCurrentStep, .goHome]
        )
    }
    
    /// Low confidence - needs more context
    static func lowConfidence() -> OperatorKitUserFacingError {
        OperatorKitUserFacingError(
            title: "More Information Needed",
            message: "OperatorKit doesn't have enough context to create a reliable draft. Add more context or clarify your request.",
            recoveryActions: [.addMoreContext, .editRequest]
        )
    }
}

// MARK: - Error Callout View (Phase 5B)

import SwiftUI

/// Reusable error display component — inline callout style
struct ErrorCalloutView: View {
    let error: OperatorKitUserFacingError
    let onRecoveryAction: (OperatorKitUserFacingError.RecoveryAction) -> Void
    let onDismiss: (() -> Void)?
    
    init(
        error: OperatorKitUserFacingError,
        onRecoveryAction: @escaping (OperatorKitUserFacingError.RecoveryAction) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.onRecoveryAction = onRecoveryAction
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(OKColor.riskWarning)
                
                Text(error.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(OKColor.textMuted.opacity(0.5))
                    }
                }
            }
            
            // Message
            Text(error.message)
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Recovery Actions
            if !error.recoveryActions.isEmpty {
                HStack(spacing: 12) {
                    ForEach(error.recoveryActions.prefix(2), id: \.self) { action in
                        Button(action: {
                            onRecoveryAction(action)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: action.icon)
                                    .font(.system(size: 12))
                                Text(action.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(action == error.recoveryActions.first ? OKColor.textPrimary : OKColor.actionPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                action == error.recoveryActions.first
                                    ? OKColor.actionPrimary
                                    : OKColor.actionPrimary.opacity(0.1)
                            )
                            .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(OKColor.riskWarning.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(OKColor.riskWarning.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Modifier to show error callout when error exists
extension View {
    func errorCallout(
        error: Binding<OperatorKitUserFacingError?>,
        onRecoveryAction: @escaping (OperatorKitUserFacingError.RecoveryAction) -> Void
    ) -> some View {
        self.overlay(alignment: .top) {
            if let currentError = error.wrappedValue {
                ErrorCalloutView(
                    error: currentError,
                    onRecoveryAction: onRecoveryAction,
                    onDismiss: { error.wrappedValue = nil }
                )
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3), value: error.wrappedValue != nil)
            }
        }
    }
}

// MARK: - Invariant Assertions

/// Asserts an invariant and throws if violated
func assertInvariant(_ condition: Bool, _ invariant: String) throws {
    guard condition else {
        AppLogger.shared.logInvariantCheck(invariant, passed: false)
        throw OperatorKitError.invariantViolation(invariant: invariant)
    }
    AppLogger.shared.logInvariantCheck(invariant, passed: true)
}

/// Fatal assertion for critical invariants (DEBUG only)
func fatalInvariant(_ condition: Bool, _ invariant: String, file: StaticString = #file, line: UInt = #line) {
    #if DEBUG
    if !condition {
        AppLogger.shared.logInvariantCheck(invariant, passed: false)
        fatalError("INVARIANT VIOLATION: \(invariant)", file: file, line: line)
    }
    #endif
}
