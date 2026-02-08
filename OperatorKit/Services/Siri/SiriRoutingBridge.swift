import Foundation
import SwiftUI

// ============================================================================
// SAFETY CONTRACT REFERENCE
// This file enforces: Guarantee #6 (Siri Routes Only)
// See: docs/SAFETY_CONTRACT.md
// Changes to Siri routing require Safety Contract Change Approval
// ============================================================================

/// Bridge between Siri App Intents and OperatorKit UI
/// INVARIANT: This bridge ONLY routes - it never executes logic
/// INVARIANT: No data access, no draft generation, no side effects
/// INVARIANT: Only mutates siriPrefillText and navigates to intentInput
@MainActor
final class SiriRoutingBridge: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SiriRoutingBridge()
    
    // MARK: - Published State (Read-only externally)
    
    /// Whether the current session was launched from Siri
    @Published private(set) var isLaunchedFromSiri: Bool = false
    
    /// The source of the Siri route
    @Published private(set) var routeSource: SiriRouteSource?
    
    /// Timestamp of when Siri routing occurred
    @Published private(set) var routeTimestamp: Date?
    
    /// The prefilled intent text from Siri
    @Published private(set) var prefilledIntentText: String?
    
    // MARK: - App State Reference

    /// Weak reference to app state to avoid retain cycles
    private weak var appState: AppState?

    /// Weak reference to navigation state for new navigation system
    private weak var nav: AppNavigationState?

    // MARK: - Initialization

    private init() {}

    /// Configure the bridge with app state and navigation
    /// Call this from OperatorKitApp on launch
    func configure(appState: AppState, nav: AppNavigationState? = nil) {
        self.appState = appState
        self.nav = nav
    }
    
    // MARK: - Routing (ONLY ALLOWED MUTATION)
    
    /// Route an intent from Siri to the app
    /// INVARIANT: This is the ONLY entry point for Siri
    /// INVARIANT: Only sets siriPrefillText and navigates to intentInput
    /// INVARIANT: Never calls DraftGenerator, Planner, or ExecutionEngine
    func routeIntent(text: String, source: SiriRouteSource) async {
        guard let appState = appState else {
            logError("SiriRoutingBridge: AppState not configured")
            return
        }
        
        log("SiriRoutingBridge: Routing from \(source.displayName) with text: \(text.prefix(50))...")
        
        // INVARIANT CHECK: Ensure we're not in the middle of an execution
        #if DEBUG
        if appState.approvalGranted {
            assertionFailure("INVARIANT VIOLATION: Siri attempted to route during active execution")
        }
        #endif
        
        // Set routing state
        isLaunchedFromSiri = true
        routeSource = source
        routeTimestamp = Date()
        prefilledIntentText = text
        
        // ALLOWED MUTATIONS ONLY:
        // 1. Set the draft intent text for prefill
        appState.siriPrefillText = text
        appState.siriRouteSource = source
        
        // 2. Navigate to intent input (user must review and continue)
        appState.navigateFromSiri()
        
        // INVARIANT: Log for audit
        log("SiriRoutingBridge: Route complete - awaiting user review")
    }
    
    /// Clear Siri routing state
    /// Call when user completes or cancels the flow
    func clearRouteState() {
        isLaunchedFromSiri = false
        routeSource = nil
        routeTimestamp = nil
        prefilledIntentText = nil
        
        if let appState = appState {
            appState.clearSiriState()
        }
        
        log("SiriRoutingBridge: Route state cleared")
    }
    
    // MARK: - Validation
    
    /// Validate that Siri routing respects all invariants
    /// Call this in DEBUG to verify no invariant violations
    #if DEBUG
    func validateInvariants() {
        guard let appState = appState else { return }
        
        // Siri must never have caused draft generation
        if isLaunchedFromSiri && appState.currentDraft != nil {
            // Only valid if user explicitly triggered draft generation
            // Check that user advanced past intent input
            if appState.currentFlow == .intentInput {
                assertionFailure("INVARIANT VIOLATION: Draft exists while still in Siri-launched intent input")
            }
        }
        
        // Siri must never have set approval
        if isLaunchedFromSiri, let timestamp = routeTimestamp {
            let timeSinceRoute = Date().timeIntervalSince(timestamp)
            if timeSinceRoute < 1.0 && appState.approvalGranted {
                assertionFailure("INVARIANT VIOLATION: Approval granted too quickly after Siri route")
            }
        }
    }
    #endif
}
