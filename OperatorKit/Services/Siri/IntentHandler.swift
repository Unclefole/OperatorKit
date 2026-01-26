import Foundation

/// Legacy Intent Handler (for older Siri Intents if needed)
/// INVARIANT: Siri is router only - NEVER executes logic
/// INVARIANT: All intent handling routes to UI, never processes data
///
/// Note: OperatorKit uses App Intents (iOS 16+) as the primary Siri integration.
/// This file exists for backward compatibility and should route to App Intents.
final class IntentHandler {
    
    static let shared = IntentHandler()
    
    private init() {}
    
    /// Handle a legacy Siri intent by routing to the app
    /// INVARIANT: Never executes logic, only routes
    /// INVARIANT: Never accesses calendar, mail, or files
    @MainActor
    func handleLegacyIntent(text: String) async {
        log("IntentHandler: Routing legacy intent to SiriRoutingBridge")
        
        // Route through the modern bridge
        await SiriRoutingBridge.shared.routeIntent(
            text: text,
            source: .siriGeneral
        )
        
        // INVARIANT: No further processing allowed
    }
}

// MARK: - Invariant Documentation

/*
 SIRI ROUTING INVARIANTS:
 
 1. NEVER execute DraftGenerator
    - Siri cannot generate drafts
    - Only user can trigger draft generation after review
 
 2. NEVER execute Planner
    - Siri cannot create execution plans
    - Plans are created after user selects context
 
 3. NEVER execute ExecutionEngine
    - Siri cannot execute any actions
    - Only user can approve and execute
 
 4. NEVER access Calendar
    - Siri cannot read calendar events
    - User must select context explicitly
 
 5. NEVER access Mail
    - Siri cannot read email threads
    - User must select context explicitly
 
 6. NEVER access Files
    - Siri cannot read documents
    - User must select context explicitly
 
 7. ONLY allowed action: Route to UI
    - Set prefill text
    - Navigate to IntentInputView
    - User reviews and continues
 
 8. MUST show Siri banner
    - User must acknowledge Siri launch
    - Cannot auto-advance past IntentInputView
 
 These invariants ensure that Siri remains a ROUTER ONLY
 and never takes autonomous action on behalf of the user.
*/
