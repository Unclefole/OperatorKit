# CLAIM REGISTRY

> **Purpose**: Catalog of all externally visible claims made by OperatorKit.
> Each claim must be traceable to enforcing code, tests, and documentation.

---

## Schema Version: 25

## Last Updated: Phase 12D

---

## Claims Inventory

### CLAIM-001: Core Verification Mode Is Air-Gapped

**Claim Text**: "OperatorKit Core Verification Mode is fully air-gapped. Sync is an explicit, user-initiated, OFF-by-default exception."

**Variations**:
- "All core processing happens on your device"
- "Your data stays on your device unless you explicitly enable Sync"
- "Local-only processing for verification, drafts, and execution"

**Scoped Claim Boundary**:
- **Air-Gapped (ALWAYS)**: ExecutionEngine, ApprovalGate, ModelRouter, DraftGenerator, ContextAssembler, MemoryStore, QualityFeedback, GoldenCases, Diagnostics, Policies
- **Exception (OPT-IN ONLY)**: Sync module (`/Sync/`) — OFF by default, user-initiated, metadata-only

**Why This Scoping**:
The Sync module is a documented exception because:
1. It is OFF by default (`SyncFeatureFlag.defaultToggleState = false`)
2. It requires explicit user action to enable AND sign in
3. It uploads metadata-only packets (content blocked by validator)
4. It is isolated to the `/Sync/` directory
5. Core execution paths have ZERO network code

**Enforcing Code**:
- `Safety/CompileTimeGuards.swift` — prevents network imports OUTSIDE Sync module
- `Safety/InvariantCheckRunner.swift` — runtime check for network symbols
- `Safety/ReleaseConfig.swift` — `networkEntitlementsEnabled = false`
- `Sync/NetworkAllowance.swift` — documents the sole exception
- `Sync/SupabaseClient.swift` — AIR-GAP EXCEPTION marker
- `Sync/TeamSupabaseClient.swift` — AIR-GAP EXCEPTION marker

**Tests**:
- `InvariantTests.testNoNetworkFrameworksLinked` (outside Sync)
- `SyncInvariantTests.testSyncIsOffByDefault`
- `SyncInvariantTests.testSyncUnreachableWhenDisabled`
- `AirGappedSecurityInterrogationTests.testCoreModulesHaveNoURLSession`

**Docs**:
- `PrivacyStrings.swift` — `General.onDeviceStatement`
- `DataUseDisclosureView.swift` — "Processed Locally" section
- `EXECUTION_GUARANTEES.md` — "On-Device Definition"
- `APP_REVIEW_PACKET.md` — Data access table
- `SAFETY_CONTRACT.md` — Section 13 (Sync Exception)

---

### CLAIM-002: No Background Processing

**Claim Text**: "No background processing"

**Variations**:
- "No background modes"
- "OperatorKit only runs when you're using it"
- "No hidden activity"

**Enforcing Code**:
- `Safety/CompileTimeGuards.swift` — compile-time check for background mode absence
- `Safety/InvariantCheckRunner.swift` — runtime background mode check
- `Safety/ReleaseConfig.swift` — `backgroundModesEnabled = false`

**Tests**:
- `InvariantTests.testNoBackgroundModes`
- `InfoPlistRegressionTests.testNoBackgroundModes`
- `RegressionTests.testNoBackgroundModes`

**Docs**:
- `EXECUTION_GUARANTEES.md` — "Explicit Non-Goals"
- `APP_REVIEW_PACKET.md` — Safety gates table
- `SAFETY_CONTRACT.md` — Guarantee #2

---

### CLAIM-003: No Autonomous Actions

**Claim Text**: "No autonomous actions"

**Variations**:
- "OperatorKit never acts without your approval"
- "You are always in control"
- "Nothing happens without your explicit action"

**Enforcing Code**:
- `Domain/Approval/ApprovalGate.swift` — blocks execution without approval
- `Domain/Execution/ExecutionEngine.swift` — checks `approvalGranted` before any action
- `Services/Siri/SiriRoutingBridge.swift` — routes only, never executes

**Tests**:
- `InvariantTests.testApprovalGateBlocksWithoutApproval`
- `InvariantTests.testSiriRoutingNeverExecutes`
- `RegressionTests.testSiriNeverCallsExecutionLogic`

**Docs**:
- `SAFETY_CONTRACT.md` — Guarantee #1
- `EXECUTION_GUARANTEES.md` — "Core Invariants"
- `APP_REVIEW_PACKET.md` — "What OperatorKit Does Not Do"

---

### CLAIM-004: Draft-First Execution

**Claim Text**: "Draft-first execution"

**Variations**:
- "Every action starts as a draft you can review"
- "See what will happen before it happens"
- "Preview before execute"

**Enforcing Code**:
- `Domain/Drafts/DraftGenerator.swift` — generates draft before any execution
- `Domain/Execution/ExecutionEngine.swift` — requires draft in execution context
- `UI/DraftOutput/DraftOutputView.swift` — displays draft for review

**Tests**:
- `InvariantTests.testDraftRequiredBeforeExecution`

**Docs**:
- `SAFETY_CONTRACT.md` — Guarantee #4
- `EXECUTION_GUARANTEES.md` — "Draft-First Definition"
- `ReviewerHelpView.swift` — 2-minute test plan

---

### CLAIM-005: User-Selected Context Only

**Claim Text**: "User-selected context only"

**Variations**:
- "OperatorKit only accesses data you explicitly select"
- "No automatic data collection"
- "You choose what to include"

**Enforcing Code**:
- `Domain/Context/ContextAssembler.swift` — only processes selected items
- `Services/Calendar/CalendarService.swift` — tracks user-selected events
- `Services/Reminders/ReminderService.swift` — no bulk access

**Tests**:
- `InvariantTests.testContextAssemblerOnlyProcessesSelectedItems`
- `RegressionTests.testCalendarUpdateOnlyAllowedForSelectedEvents`

**Docs**:
- `SAFETY_CONTRACT.md` — Guarantee #6
- `EXECUTION_GUARANTEES.md` — "User-Selected Context"
- `DataUseDisclosureView.swift` — "When Access Happens"

---

### CLAIM-006: No Analytics or Tracking

**Claim Text**: "No analytics or tracking"

**Variations**:
- "No telemetry"
- "No usage data collected"
- "Your activity is never logged to external servers"

**Enforcing Code**:
- `Safety/CompileTimeGuards.swift` — prevents analytics framework imports
- `Safety/ReleaseConfig.swift` — `analyticsEnabled = false`, `telemetryEnabled = false`
- `Safety/InvariantCheckRunner.swift` — checks for analytics symbols

**Tests**:
- `InvariantTests.testNoAnalyticsFrameworksLinked`
- `RegressionTests.testNoAnalyticsOrTelemetryEnabled`

**Docs**:
- `EXECUTION_GUARANTEES.md` — "Explicit Non-Goals"
- `PrivacyStrings.swift` — `General.noTelemetry`
- `APP_REVIEW_PACKET.md` — Data access table

---

### CLAIM-007: Two-Key Write Confirmation

**Claim Text**: "Two-key confirmation for writes"

**Variations**:
- "Writes require a second confirmation"
- "Extra protection for calendar and reminder writes"
- "Two-step verification for data changes"

**Enforcing Code**:
- `Domain/Approval/SideEffectContract.swift` — `secondConfirmationGranted` property
- `UI/Approval/ConfirmWriteView.swift` — second confirmation UI
- `UI/Approval/ConfirmCalendarWriteView.swift` — calendar-specific confirmation
- `Services/Calendar/CalendarService.swift` — checks `secondConfirmationGranted`
- `Services/Reminders/ReminderService.swift` — checks confirmation

**Tests**:
- `InvariantTests.testTwoKeyConfirmationRequired`
- `RegressionTests.testWritePathsBypassTwoKeyConfirmation`

**Docs**:
- `SAFETY_CONTRACT.md` — Guarantee #5
- `EXECUTION_GUARANTEES.md` — "Two-Key Confirmation"
- `APP_REVIEW_PACKET.md` — Safety gates table

---

### CLAIM-008: Siri Routes Only

**Claim Text**: "Siri routes only"

**Variations**:
- "Siri only launches the app, never executes"
- "Voice commands are routing, not execution"
- "Siri is a shortcut, not a brain"

**Enforcing Code**:
- `Services/Siri/SiriRoutingBridge.swift` — only sets state, never executes
- `Services/Siri/OperatorKitIntents.swift` — returns immediately, no side effects
- `UI/IntentInput/IntentInputView.swift` — shows Siri banner, requires manual continuation

**Tests**:
- `InvariantTests.testSiriRoutingNeverExecutes`
- `RegressionTests.testSiriNeverCallsExecutionLogic`

**Docs**:
- `SAFETY_CONTRACT.md` — Guarantee #8
- `EXECUTION_GUARANTEES.md` — "Siri as Router"
- `APP_REVIEW_PACKET.md` — Siri section

---

### CLAIM-009: Local Quality Feedback

**Claim Text**: "Feedback is stored locally and never transmitted"

**Variations**:
- "Your ratings stay on your device"
- "Feedback is local-only"
- "No feedback data is sent externally"

**Enforcing Code**:
- `Domain/Quality/QualityFeedbackStore.swift` — UserDefaults storage only
- `Domain/Quality/QualityFeedback.swift` — `validateNoRawContent()` check

**Tests**:
- `QualityFeedbackTests.testNoNetworkImportsInQualityModule`
- `QualityFeedbackTests.testExportDoesNotContainRawContent`

**Docs**:
- `SAFETY_CONTRACT.md` — Guarantee #11
- `APP_REVIEW_PACKET.md` — Local Quality Feedback section
- `QualityAndTrustView.swift` — explanation copy

---

### CLAIM-010: Golden Cases Store Metadata Only

**Claim Text**: "Golden cases store metadata only, not content"

**Variations**:
- "Quality evaluation uses metadata snapshots"
- "No content is stored in golden cases"
- "Evaluation data is content-free"

**Enforcing Code**:
- `Domain/Eval/GoldenCase.swift` — `GoldenCaseSnapshot` contains only metadata
- `Domain/Eval/GoldenCaseStore.swift` — stores snapshots, not content
- `Domain/Eval/LocalEvalRunner.swift` — audit-based comparison only

**Tests**:
- `GoldenCaseTests.testSnapshotStoresNoRawContent`
- `GoldenCaseTests.testGoldenCaseExportExcludesContent`
- `LocalEvalRunnerTests.testEvalRunExportExcludesContent`

**Docs**:
- `SAFETY_CONTRACT.md` — Guarantee #12
- `APP_REVIEW_PACKET.md` — Local Quality Evaluation section

---

### CLAIM-011: Deterministic Fallback Always Available

**Claim Text**: "A reliable on-device fallback is always available"

**Variations**:
- "If advanced models fail, a simple method is used"
- "Fallback ensures reliability"
- "You'll always get a result"

**Enforcing Code**:
- `Models/DeterministicTemplateModel.swift` — always available
- `Models/ModelRouter.swift` — falls back to deterministic on any failure
- `Safety/ReleaseConfig.swift` — `deterministicFallbackRequired = true`

**Tests**:
- `InvariantTests.testDeterministicFallbackAlwaysAvailable`
- `InvariantTests.testModelRouterFallsBackOnFailure`

**Docs**:
- `SAFETY_CONTRACT.md` — Guarantee #9
- `EXECUTION_GUARANTEES.md` — "Fallback Definition"
- `PrivacyControlsView.swift` — fallback explanation

---

### CLAIM-012: Tamper-Evident Quality Records

**Claim Text**: "Quality records are tamper-evident via local integrity checks."

**Variations**:
- "Quality records include integrity verification"
- "Exports are verifiable for consistency"
- "Integrity checks detect record modifications"

**Important Clarifications**:
- This is integrity, NOT security
- Integrity checks are advisory and informational only
- No blocking, gating, or enforcement
- No security claims ("secure", "protected", "encrypted")

**Enforcing Code**:
- `Domain/Eval/IntegritySeal.swift` — IntegritySeal, IntegrityStatus, IntegrityVerifier
- `Domain/Eval/ExportQualityPacket.swift` — integritySeal property
- `Safety/RegressionSentinel.swift` — QualitySnapshotSummary

**Tests**:
- `IntegritySealTests.testSealContainsNoForbiddenKeys`
- `IntegritySealTests.testHashChangesWhenMetadataChanges`
- `IntegritySealTests.testHashDoesNotIncludeContent`
- `IntegritySealTests.testVerifierDetectsMismatch`
- `IntegritySealTests.testExportSucceedsWhenSealUnavailable`
- `IntegritySealTests.testNoExecutionModuleImportsIntegrityCode`

**Docs**:
- `SAFETY_CONTRACT.md` — Integrity note (informational)
- `APP_REVIEW_PACKET.md` — Integrity ≠ security clarification
- `PHASE_BOUNDARIES.md` — Phase 9C scope

---

### CLAIM-013: Payments Processed by Apple

**Claim Text**: "Payments processed by Apple via StoreKit"

**Variations**:
- "Payments through Apple"
- "OperatorKit never sees your payment information"
- "Subscriptions managed via App Store"

**Enforcing Code**:
- `Monetization/EntitlementManager.swift` — uses StoreKit 2 only
- `Monetization/PurchaseController.swift` — StoreKit-only purchase flow
- `Monetization/StoreKitProducts.swift` — product definitions

**Tests**:
- `MonetizationInvariantTests.testProductIDsFollowAppleConvention`
- `MonetizationInvariantTests.testSubscriptionProductsDefined`

**Docs**:
- `UI/Monetization/UpgradeView.swift` — PrivacyNoteView
- `UI/Monetization/SubscriptionStatusView.swift` — payment info row
- `APP_REVIEW_PACKET.md` — Subscription section

---

### CLAIM-014: No Accounts Required

**Claim Text**: "No accounts required"

**Variations**:
- "No sign-in needed"
- "No account creation"
- "Works without registration"

**Enforcing Code**:
- `Monetization/EntitlementManager.swift` — no account/login code
- `App/AppState.swift` — no auth state

**Tests**:
- `MonetizationInvariantTests.testExecutionEngineNoEntitlementReferences`

**Docs**:
- `APP_REVIEW_PACKET.md` — "No accounts" statement

---

### CLAIM-015: Subscription Status Checked On-Device

**Claim Text**: "Subscription status checked on-device"

**Variations**:
- "Local entitlement verification"
- "No server receipt validation"
- "StoreKit-based entitlement checks"

**Enforcing Code**:
- `Monetization/EntitlementManager.swift` — `checkCurrentEntitlements()` uses StoreKit 2 local APIs
- `Monetization/SubscriptionState.swift` — local status caching

**Tests**:
- `MonetizationInvariantTests.testSubscriptionStatusIsContentFree`
- `MonetizationInvariantTests.testSubscriptionStatusRoundTrip`

**Docs**:
- `Monetization/EntitlementManager.swift` — header comments
- `APP_REVIEW_PACKET.md` — Local verification note

---

### CLAIM-016: Monetization Does Not Affect Execution

**Claim Text**: "Subscription status does not affect how execution works"

**Variations**:
- "Free and Pro have identical execution behavior"
- "Limits are on availability, not correctness"
- "No execution path changes based on tier"

**Important Clarifications**:
- Quotas affect how many times you can execute, not how each execution behaves
- ApprovalGate, ExecutionEngine, and ModelRouter are unchanged by monetization
- Safety guarantees are identical for Free and Pro

**Enforcing Code**:
- `Domain/Execution/ExecutionEngine.swift` — DOES NOT import StoreKit or reference monetization
- `Domain/Approval/ApprovalGate.swift` — DOES NOT reference tier or entitlements
- `Models/ModelRouter.swift` — DOES NOT reference subscription status

**Tests**:
- `MonetizationInvariantTests.testExecutionEngineDoesNotImportStoreKit`
- `MonetizationInvariantTests.testApprovalGateDoesNotImportStoreKit`
- `MonetizationInvariantTests.testModelRouterDoesNotImportStoreKit`
- `MonetizationInvariantTests.testExecutionEngineNoEntitlementReferences`
- `MonetizationInvariantTests.testApprovalGateNoEntitlementReferences`

**Docs**:
- `SAFETY_CONTRACT.md` — unchanged
- `APP_REVIEW_PACKET.md` — "No behavior change" section

---

### CLAIM-017: Diagnostics Generated On-Device

**Claim Text**: "Operator-visible diagnostics are generated on-device"

**Variations**:
- "Diagnostics are local-only"
- "No diagnostic data is transmitted"
- "Diagnostics for operator visibility only"

**Enforcing Code**:
- `Diagnostics/ExecutionDiagnostics.swift` — local snapshot collection
- `Diagnostics/UsageDiagnostics.swift` — local usage stats
- `Diagnostics/DiagnosticsExportPacket.swift` — user-initiated export only

**Tests**:
- `DiagnosticsInvariantTests.testDiagnosticsFilesNoNetworkImports`
- `DiagnosticsInvariantTests.testExecutionDiagnosticsContainsNoForbiddenKeys`
- `DiagnosticsInvariantTests.testUsageDiagnosticsContainsNoForbiddenKeys`
- `DiagnosticsInvariantTests.testDiagnosticsCollectionDoesNotIncrementCounters`

**Docs**:
- `APP_REVIEW_PACKET.md` — Diagnostics section
- `UI/Diagnostics/DiagnosticsView.swift` — read-only UI

---

### CLAIM-018: No Analytics or Telemetry Collected

**Claim Text**: "No analytics or telemetry is collected"

**Variations**:
- "No usage tracking"
- "No behavioral analytics"
- "Diagnostics are user-visible only, not collected"

**Important Clarifications**:
- Diagnostics are snapshots, not continuous monitoring
- Export is manual and user-initiated only
- No background data collection
- No identifiers beyond app version/build

**Enforcing Code**:
- `Diagnostics/ExecutionDiagnostics.swift` — no analytics imports
- `Diagnostics/UsageDiagnostics.swift` — no telemetry code
- `Diagnostics/DiagnosticsExportPacket.swift` — user-initiated export only

**Tests**:
- `DiagnosticsInvariantTests.testDiagnosticsFilesNoAnalyticsImports`
- `DiagnosticsInvariantTests.testExportPacketContainsNoForbiddenKeys`
- `DiagnosticsInvariantTests.testUsageDiagnosticsCollectionDoesNotModifyState`

**Docs**:
- `SAFETY_CONTRACT.md` — Guarantee #2 (No Network Transmission)
- `APP_REVIEW_PACKET.md` — "No Analytics or Tracking" section

---

### CLAIM-019: Operator-Defined Execution Policies

**Claim Text**: "Operator-defined execution policies"

**Variations**:
- "User-controlled execution constraints"
- "Configurable capability restrictions"
- "Policy-based execution limits"

**Important Clarifications**:
- Policies are user-authored, not automatic
- Enforced at UI entry points ONLY
- Does not modify ExecutionEngine, ApprovalGate, or ModelRouter
- Content-free (no user data in policies)

**Enforcing Code**:
- `Policies/OperatorPolicy.swift` — policy model
- `Policies/OperatorPolicyStore.swift` — local storage
- `Policies/PolicyEvaluator.swift` — read-only evaluation
- `UI/IntentInput/IntentInputView.swift` — UI enforcement

**Tests**:
- `PolicyInvariantTests.testPolicyContainsNoForbiddenKeys`
- `PolicyInvariantTests.testExecutionEngineDoesNotReferencePolicy`
- `PolicyInvariantTests.testApprovalGateDoesNotReferencePolicy`
- `PolicyInvariantTests.testPolicyEvaluatorIsPure`

**Docs**:
- `APP_REVIEW_PACKET.md` — Execution Policies section
- `UI/Policy/PolicyEditorView.swift` — user interface

---

### CLAIM-020: Fail-Closed Policy Enforcement

**Claim Text**: "Fail-closed enforcement"

**Variations**:
- "Deny if uncertain"
- "Conservative by default"
- "Safe failure mode"

**Important Clarifications**:
- If policy state is uncertain, action is denied
- Default policy requires explicit confirmation
- No automatic override of user restrictions

**Enforcing Code**:
- `Policies/PolicyEvaluator.swift` — fail-closed logic
- `Policies/OperatorPolicy.swift` — conservative defaults

**Tests**:
- `PolicyInvariantTests.testDefaultPolicyIsConservative`
- `PolicyInvariantTests.testRestrictivePolicyBlocksEverything`

**Docs**:
- `APP_REVIEW_PACKET.md` — Policy enforcement section

---

### CLAIM-021: No Autonomous Policy Override

**Claim Text**: "No autonomous override"

**Variations**:
- "Policies cannot be bypassed automatically"
- "User restrictions are respected"
- "No silent policy changes"

**Important Clarifications**:
- Only user can modify policy
- No background policy updates
- No automatic capability unlocking

**Enforcing Code**:
- `Policies/OperatorPolicyStore.swift` — explicit save required
- `UI/Policy/PolicyEditorView.swift` — manual save button

**Tests**:
- `PolicyInvariantTests.testPolicyFilesNoNetworkImports`
- `PolicyInvariantTests.testModelRouterDoesNotReferencePolicy`

**Docs**:
- `APP_REVIEW_PACKET.md` — No autonomous actions

---

### CLAIM-022: Optional Cloud Sync Is OFF by Default

**Claim Text**: "Optional cloud sync is OFF by default"

**Variations**:
- "Sync is opt-in"
- "No automatic cloud features"
- "User must enable sync"

**Important Clarifications**:
- Sync toggle defaults to OFF
- No network activity until user enables AND signs in
- Can be completely removed via compile flag

**Enforcing Code**:
- `Sync/NetworkAllowance.swift` — SyncFeatureFlag.defaultToggleState = false
- `Sync/SyncQueue.swift` — no background uploads
- `UI/Sync/SyncSettingsView.swift` — explicit toggle

**Tests**:
- `SyncInvariantTests.testSyncIsOffByDefault`
- `SyncInvariantTests.testSyncQueueDoesNotUploadOnInit`
- `SyncInvariantTests.testSupabaseClientDoesNotRequestOnInit`

**Docs**:
- `APP_REVIEW_PACKET.md` — Cloud Sync section
- `SAFETY_CONTRACT.md` — Section 13

---

### CLAIM-023: Uploads Metadata-Only Packets

**Claim Text**: "Uploads metadata-only packets"

**Variations**:
- "No user content uploaded"
- "Only metadata synced"
- "Content-free sync"

**Important Clarifications**:
- Packet validator rejects forbidden content keys
- Only approved packet types can sync
- Size limits enforced

**Enforcing Code**:
- `Sync/SyncPacketValidator.swift` — forbidden key detection
- `Sync/NetworkAllowance.swift` — SyncSafetyConfig.forbiddenContentKeys

**Tests**:
- `SyncInvariantTests.testValidatorBlocksForbiddenKeys`
- `SyncInvariantTests.testDiagnosticsExportPacketContentFree`
- `SyncInvariantTests.testPolicyExportPacketContentFree`

**Docs**:
- `APP_REVIEW_PACKET.md` — What syncs section

---

### CLAIM-024: Manual Upload Only

**Claim Text**: "Manual upload only"

**Variations**:
- "User-initiated sync"
- "No background uploads"
- "No automatic sync"

**Important Clarifications**:
- Upload requires explicit button tap
- No background task registration
- No scheduled uploads

**Enforcing Code**:
- `Sync/SyncQueue.swift` — uploadStagedPacketsNow() is only upload path
- `UI/Sync/SyncSettingsView.swift` — explicit "Upload Now" button

**Tests**:
- `SyncInvariantTests.testSyncFilesNoBackgroundTasks`
- `SyncInvariantTests.testSyncQueueDoesNotUploadOnInit`

**Docs**:
- `APP_REVIEW_PACKET.md` — Manual upload section

---

### CLAIM-025: No Drafts or Content Uploaded

**Claim Text**: "No drafts/content uploaded"

**Variations**:
- "Drafts never synced"
- "User content stays local"
- "No personal data uploaded"

**Important Clarifications**:
- Drafts, memory items, prompts, context never syncable
- Validator blocks any payload with content keys
- Fail closed if uncertain

**Enforcing Code**:
- `Sync/SyncPacketValidator.swift` — findForbiddenKeys()
- `Sync/NetworkAllowance.swift` — SyncSafetyConfig.forbiddenContentKeys

**Tests**:
- `SyncInvariantTests.testValidatorBlocksForbiddenKeys`
- `SyncInvariantTests.testForbiddenContentKeysComprehensive`
- `SyncInvariantTests.testSyncablePacketTypesAreLimited`

**Docs**:
- `APP_REVIEW_PACKET.md` — What never syncs section

---

### CLAIM-026: Teams Share Governance, Not Work

**Claim Text**: "Teams share governance, not work"

**Variations**:
- "Metadata-only team sharing"
- "No shared drafts or content"
- "Governance artifacts only"

**Important Clarifications**:
- Teams share policy templates, diagnostics, quality summaries
- Teams do NOT share drafts, memory, execution state
- Role changes do not affect execution

**Enforcing Code**:
- `Team/TeamArtifacts.swift` — metadata-only artifact types
- `Team/TeamArtifactValidator.swift` — content-free enforcer

**Tests**:
- `TeamInvariantTests.testShareableArtifactTypesAreLimited`
- `TeamInvariantTests.testValidatorBlocksForbiddenKeys`

**Docs**:
- `APP_REVIEW_PACKET.md` — Team Governance section

---

### CLAIM-027: Team Roles Are Display Only

**Claim Text**: "Team roles are display only"

**Variations**:
- "No role-based execution enforcement"
- "Roles for member management"
- "No admin execution control"

**Important Clarifications**:
- Roles (owner, admin, member) are for team management UI
- Roles do NOT affect what users can execute locally
- No remote killswitches or admin overrides

**Enforcing Code**:
- `Team/TeamAccount.swift` — TeamRole enum is display-only
- `Team/TeamStore.swift` — role changes only affect UI

**Tests**:
- `TeamInvariantTests.testTeamRoleHasNoExecutionMethods`
- `TeamInvariantTests.testExecutionEngineDoesNotImportTeam`

**Docs**:
- `SAFETY_CONTRACT.md` — Section 14

---

### CLAIM-028: No Shared Execution or Memory

**Claim Text**: "No shared execution or memory"

**Variations**:
- "No cross-user execution"
- "No shared inboxes"
- "No shared context"

**Important Clarifications**:
- Each user's execution is independent
- Memory items are never shared
- Context packets are never shared
- Drafts are never shared

**Enforcing Code**:
- `Team/TeamArtifacts.swift` — no draft/memory/context types
- `Team/TeamArtifactValidator.swift` — blocks content keys

**Tests**:
- `TeamInvariantTests.testTeamFilesNoExecutionImports`
- `TeamInvariantTests.testDiagnosticsSnapshotContainsNoForbiddenKeys`

**Docs**:
- `APP_REVIEW_PACKET.md` — What teams cannot share

---

### CLAIM-029: Team Tier Requires Subscription

**Claim Text**: "Team tier requires subscription"

**Variations**:
- "Paid team features"
- "Team tier entitlement"

**Important Clarifications**:
- Team features require Team subscription
- Free and Pro tiers do not have team features
- Enforced at UI boundary only, not execution

**Enforcing Code**:
- `Monetization/SubscriptionState.swift` — .team tier
- `Monetization/StoreKitProducts.swift` — team product IDs

**Tests**:
- `TeamInvariantTests.testOnlyTeamTierHasTeamFeatures`

**Docs**:
- `APP_REVIEW_PACKET.md` — Team subscription

---

### CLAIM-030: Rate Shaping Is UI-Level Only

**Claim Text**: "Rate shaping is UI-level only"

**Variations**:
- "Rate limits don't block execution"
- "UI-only enforcement"
- "Suggestions, not blocks"

**Important Clarifications**:
- Rate shaping provides feedback to users at the UI layer
- It does NOT modify ExecutionEngine, ApprovalGate, or ModelRouter
- Users can still proceed even with rate shaping messages

**Enforcing Code**:
- `Safety/RateShaping.swift` — RateShaper is UI-only
- `Safety/TierBoundaries.swift` — boundaries are informational

**Tests**:
- `AbuseResistanceInvariantTests.testRateShaperDoesNotBlockExecution`
- `AbuseResistanceInvariantTests.testExecutionEngineDoesNotImportAbuseModules`

**Docs**:
- `APP_REVIEW_PACKET.md` — Usage Discipline section

---

### CLAIM-031: Abuse Detection Is Metadata-Only

**Claim Text**: "Abuse detection is metadata-only"

**Variations**:
- "Hash-based, no content inspection"
- "Pattern detection only"
- "No content storage"

**Important Clarifications**:
- Abuse detection uses SHA256 hashes of intents, not content
- Content is immediately discarded after hashing
- Only timing patterns and hash counts are stored

**Enforcing Code**:
- `Safety/AbuseGuardrails.swift` — hash-based detection
- `AbuseDetector.computeIntentHash()` — one-way hashing

**Tests**:
- `AbuseResistanceInvariantTests.testAbuseDetectorUsesHashesOnly`
- `AbuseResistanceInvariantTests.testAbuseSummaryContainsNoContentKeys`

**Docs**:
- `SAFETY_CONTRACT.md` — Section 15

---

### CLAIM-032: Cost Indicators Are Informational Only

**Claim Text**: "Cost indicators are informational only"

**Variations**:
- "Usage units, not prices"
- "No actual cost tracking"
- "For user reference only"

**Important Clarifications**:
- CostIndicator shows abstract "usage units", not currency
- No actual pricing information is shown or stored
- Indicators do not affect execution or approval

**Enforcing Code**:
- `Safety/CostVisibility.swift` — UsageUnits (not currency)
- `CostIndicator` — informational tracking

**Tests**:
- `AbuseResistanceInvariantTests.testCostIndicatorIsInformationalOnly`
- `AbuseResistanceInvariantTests.testUsageUnitsContainsNoPricing`

**Docs**:
- `APP_REVIEW_PACKET.md` — Usage visibility

---

### CLAIM-033: Usage Messages Are Non-Punitive

**Claim Text**: "Usage messages are non-punitive"

**Variations**:
- "No moralizing"
- "No threats"
- "Honest and factual"

**Important Clarifications**:
- All user-facing messages are factual and helpful
- No blame language, no threats, no moralizing
- Clear distinction between limits and safety rules

**Enforcing Code**:
- `Safety/UsageMessages.swift` — centralized messages
- All messages reviewed for tone

**Tests**:
- `AbuseResistanceInvariantTests.testUsageMessagesAreNonPunitive`
- `AbuseResistanceInvariantTests.testUsageMessagesDontMoralize`

**Docs**:
- `APP_REVIEW_PACKET.md` — User communication

---

### CLAIM-034: No Cross-User Execution Paths

**Claim Text**: "No cross-user execution paths"

**Variations**:
- "No shared execution"
- "Isolated execution per user"
- "No admin execution control"

**Important Clarifications**:
- Each user has completely isolated execution
- Team tiers cannot execute on behalf of other users
- No remote killswitch or admin override

**Enforcing Code**:
- `Safety/TierBoundaries.swift` — TierFeatureMatrix.neverFeatures
- Structural isolation in ExecutionEngine

**Tests**:
- `AbuseResistanceInvariantTests.testCrossUserIsolationIsStructural`
- `AbuseResistanceInvariantTests.testSharedExecutionNeverAvailable`
- `AbuseResistanceInvariantTests.testRemoteKillswitchNeverAvailable`

**Docs**:
- `SAFETY_CONTRACT.md` — Never Features

---

### CLAIM-035: Monetization Enforcement Is UI-Only

**Claim Text**: "Monetization enforcement is UI-only"

**Variations**:
- "Quotas enforced at UI boundary"
- "Core execution unaffected by monetization"
- "No StoreKit in execution modules"

**Important Clarifications**:
- QuotaEnforcer checks happen BEFORE intent processing in UI layer
- ExecutionEngine, ApprovalGate, ModelRouter have no monetization imports
- Users can always view existing content regardless of quota

**Enforcing Code**:
- `Monetization/QuotaEnforcer.swift` — UI-level quota checks
- `Monetization/PaywallGate.swift` — UI gating component

**Tests**:
- `MonetizationEnforcementInvariantTests.testExecutionEngineDoesNotImportMonetization`
- `MonetizationEnforcementInvariantTests.testApprovalGateDoesNotImportMonetization`
- `MonetizationEnforcementInvariantTests.testNoStoreKitInExecutionDomain`

**Docs**:
- `APP_REVIEW_PACKET.md` — Monetization Enforcement section

---

### CLAIM-036: Paywall Shows, Never Silent Block

**Claim Text**: "Paywall shows, never silent block"

**Variations**:
- "Clear upgrade prompt"
- "No hidden blocking"
- "Transparent quota enforcement"

**Important Clarifications**:
- When quota is exceeded, a clear paywall sheet is presented
- Message explains what limit was reached
- Restore Purchases option always available
- User can dismiss and continue with read-only access

**Enforcing Code**:
- `Monetization/PaywallGate.swift` — PaywallSheet
- `QuotaCheckResult.showPaywall` — always true when blocked

**Tests**:
- `MonetizationEnforcementInvariantTests.testBlockedResultShowsPaywall`
- `MonetizationEnforcementInvariantTests.testApproachingLimitDoesNotBlock`

**Docs**:
- `APP_REVIEW_PACKET.md` — Paywall behavior

---

### CLAIM-037: Free Tier Is Functional

**Claim Text**: "Free tier is functional"

**Variations**:
- "Free tier works"
- "Limited but complete"
- "No crippled functionality"

**Important Clarifications**:
- Free tier has all core features: local execution, approval, diagnostics
- Limits are on quantity (executions/week, memory items), not capability
- Safety guarantees identical across all tiers

**Enforcing Code**:
- `Monetization/TierMatrix.swift` — TierFeatures for free
- `Monetization/TierQuotas.swift` — free tier limits

**Tests**:
- `MonetizationEnforcementInvariantTests.testTierMatrixConsistency`
- `MonetizationEnforcementInvariantTests.testTierFeaturesCorrectlyAssigned`

**Docs**:
- `APP_REVIEW_PACKET.md` — Tier comparison

---

### CLAIM-038: No Data Leaves Device for Monetization

**Claim Text**: "No data leaves device for monetization"

**Variations**:
- "Local-only quota tracking"
- "No server-side metering"
- "Privacy preserved"

**Important Clarifications**:
- Quota counters are stored locally only
- No server-side usage tracking
- StoreKit handles payments, not OperatorKit
- Only metadata (counters, timestamps) stored

**Enforcing Code**:
- `Monetization/QuotaEnforcer.swift` — local counters
- `Monetization/UsageLedger.swift` — local storage

**Tests**:
- `MonetizationEnforcementInvariantTests.testMonetizationNoURLSession`
- `MonetizationEnforcementInvariantTests.testQuotaCheckResultNoContentKeys`

**Docs**:
- `APP_REVIEW_PACKET.md` — Data handling

---

### CLAIM-039: No Tracking Analytics

**Claim Text**: "No tracking analytics"

**Variations**:
- "No analytics SDKs"
- "No user tracking"
- "Local counters only"

**Important Clarifications**:
- ConversionLedger stores event counts locally only
- No analytics SDKs (Firebase, Amplitude, etc.) are imported
- No user identifiers are stored or transmitted
- Export is user-initiated only

**Enforcing Code**:
- `Monetization/ConversionLedger.swift` — local-only counters
- No analytics imports anywhere in codebase

**Tests**:
- `CommercialReadinessTests.testNoAnalyticsSDKImports`
- `CommercialReadinessTests.testConversionLedgerNoForbiddenKeys`

**Docs**:
- `APP_REVIEW_PACKET.md` — Privacy section

---

### CLAIM-040: Local-Only Conversion Counters

**Claim Text**: "Local-only conversion counters"

**Variations**:
- "No server-side analytics"
- "Counters stored on device"
- "User-initiated export only"

**Important Clarifications**:
- ConversionLedger stores counts and timestamps only
- No user content, identifiers, or receipt data
- Data stored in UserDefaults
- Export via DiagnosticsExportPacket is user-initiated

**Enforcing Code**:
- `Monetization/ConversionLedger.swift` — ConversionData struct
- `ConversionExportPacket` — export format

**Tests**:
- `CommercialReadinessTests.testConversionLedgerNoForbiddenKeys`
- `CommercialReadinessTests.testConversionExportNoContent`

**Docs**:
- `APP_STORE_SUBMISSION_CHECKLIST.md` — Privacy section

---

### CLAIM-041: App Store-Safe Pricing Copy

**Claim Text**: "App Store-safe pricing copy"

**Variations**:
- "No hype language"
- "Factual feature descriptions"
- "Required disclosures included"

**Important Clarifications**:
- PricingCopy.swift is single source of truth
- No banned words (AI decides, guaranteed, 100%, etc.)
- Subscription disclosure meets Apple requirements
- No anthropomorphic AI language

**Enforcing Code**:
- `Resources/StoreMetadata/PricingCopy.swift` — centralized copy
- `PricingCopy.validate()` — banned word checker

**Tests**:
- `CommercialReadinessTests.testPricingCopyNoBannedWords`
- `CommercialReadinessTests.testPricingCopyLengthLimits`

**Docs**:
- `APP_STORE_SUBMISSION_CHECKLIST.md` — Metadata section

---

### CLAIM-042: User-Initiated Support Contact

**Claim Text**: "User-initiated support contact"

**Variations**:
- "No auto-send emails"
- "Contact is user-initiated"
- "Mail composer requires user action"

**Important Clarifications**:
- HelpCenterView opens Mail composer, doesn't auto-send
- User must manually tap Send in Mail app
- No automatic data collection or transmission

**Enforcing Code**:
- `UI/Support/HelpCenterView.swift` — uses MFMailComposeViewController
- `SupportCopy.swift` — email templates (pre-filled, not sent)

**Tests**:
- `LaunchKitInvariantTests.testSupportNoAutoSend`

**Docs**:
- `APP_REVIEW_PACKET.md` — Support section

---

### CLAIM-043: Onboarding Contains No User Content

**Claim Text**: "Onboarding stores no user content"

**Variations**:
- "Onboarding is metadata-only"
- "No user data in onboarding state"

**Important Clarifications**:
- OnboardingStateStore stores only completion flag and timestamp
- No user content, identifiers, or preferences
- Sample intents are static, not personalized

**Enforcing Code**:
- `UI/Onboarding/OnboardingStateStore.swift` — OnboardingState struct
- No user content fields in state

**Tests**:
- `LaunchKitInvariantTests.testOnboardingNoForbiddenKeys`

**Docs**:
- `SAFETY_CONTRACT.md` — Onboarding section

---

### CLAIM-044: Document Integrity Maintained

**Claim Text**: "Documentation integrity maintained"

**Variations**:
- "Required docs exist"
- "Docs not overwritten"

**Important Clarifications**:
- DocIntegrity validates all required docs exist
- Checks for required sections in key documents
- Test-time validation prevents accidental deletion

**Enforcing Code**:
- `Safety/DocIntegrity.swift` — validation logic

**Tests**:
- `LaunchKitInvariantTests.testAllRequiredDocsExist`

**Docs**:
- This registry

---

### CLAIM-045: Submission Packet Metadata-Only

**Claim Text**: "Submission packet contains metadata only"

**Variations**:
- "No user content in exports"
- "Export is content-free"
- "Forbidden-key validated"

**Important Clarifications**:
- AppStoreSubmissionPacket contains only metadata
- Validated against forbidden keys (body, subject, content, etc.)
- No user content, drafts, or prompts included
- Export is user-initiated via ShareSheet

**Enforcing Code**:
- `Domain/Review/AppStoreSubmissionPacket.swift` — packet structure
- `AppStoreSubmissionPacket.validateNoForbiddenKeys()` — validation

**Tests**:
- `AppStoreReadinessInvariantTests.testSubmissionPacketNoForbiddenKeys`

**Docs**:
- `APP_REVIEW_PACKET.md` — Submission Packet section

---

### CLAIM-046: Copy Templates App Store Safe

**Claim Text**: "Copy templates contain no banned language"

**Variations**:
- "No hype language in copy"
- "Factual submission copy"
- "Length-validated templates"

**Important Clarifications**:
- SubmissionCopy templates are validated against banned words
- No "learns", "thinks", "decides", "tracks", "secure", "encrypted"
- Length limits enforced for App Store requirements
- Templates only — user must review before submission

**Enforcing Code**:
- `Resources/StoreMetadata/SubmissionCopy.swift` — templates
- `SubmissionCopy.validate()` — banned word checker

**Tests**:
- `AppStoreReadinessInvariantTests.testReviewNotesNoBannedWords`
- `AppStoreReadinessInvariantTests.testCopyLengthLimits`

**Docs**:
- `APP_STORE_SUBMISSION_CHECKLIST.md` — Copy section

---

### CLAIM-047: Clipboard Access Is User-Initiated Only

**Claim Text**: "Clipboard access is used only for user-initiated copy actions; no automatic reads occur."

**Variations**:
- "Copy to clipboard requires button tap"
- "No background clipboard access"
- "No clipboard snooping"

**Important Clarifications**:
- UIPasteboard.general.string is ONLY set (write), never read
- All clipboard writes are triggered by explicit user button taps
- Copy actions are in: ReferralView (copy code), AppStoreReadinessView (copy content), OutboundKitView (copy template)
- No background or automatic clipboard operations

**Enforcing Code**:
- `UI/Growth/ReferralView.swift` — `copyCode()` triggered by button
- `UI/Settings/AppStoreReadinessView.swift` — toolbar copy button
- `UI/Growth/OutboundKitView.swift` — `copyTemplate()` triggered by button

**Tests**:
- `ClipboardInvariantTests.testNoBackgroundClipboardReads`
- `ClipboardInvariantTests.testClipboardWritesAreUserInitiated`

**Docs**:
- This registry

---

### CLAIM-048: Proof Exports Are Deterministic

**Claim Text**: "Proof exports are deterministic given identical inputs on the same day."

**Variations**:
- "Same inputs produce same proofs"
- "Reproducible verification"

**Important Clarifications**:
- Timestamps are day-rounded (`generatedAtDayRounded`)
- Array ordering is stable (sorted before hashing)
- No random seeds in proof hash inputs
- UUID() used for IDs only, not in hash computation
- Locale-independent formatting for all proof fields

**Conditional Scope**:
- DETERMINISTIC: Within same calendar day, same inputs → same hash
- NOT DETERMINISTIC: Across days (timestamp changes), or if underlying data changes

**Enforcing Code**:
- All export packets use `generatedAtDayRounded`
- `ExportQualityPacket.swift`, `DiagnosticsExportPacket.swift`, etc.

**Tests**:
- `DeterminismInvariantTests.testProofHashIsStableWithinDay`
- `DeterminismInvariantTests.testArrayOrderingIsStable`
- `DeterminismInvariantTests.testNoUUIDInProofHashInputs`
- `DeterminismInvariantTests.testLocaleIndependentFormatting`

**Docs**:
- `PROOF_PACK_SPEC.md` — Determinism section

---

---

## Conditional Claims Documentation

The following claims have a CONDITIONAL status in the security interrogation, with documented scoping:

### Air-Gap Conditional Claims

| Claim | Status | Why Conditional | Falsification Check |
|-------|--------|-----------------|---------------------|
| App does not open sockets (4) | CONDITIONAL | URLSession internally uses sockets in Sync module | `SyncIsolationTests.testCoreModulesHaveNoURLSessionImports` |
| App functional with network disabled (7) | CONDITIONAL | Core features: TRUE. Sync features: graceful failure | Airplane mode test in Runbook |
| Binary does not link CFNetwork (17) | CONDITIONAL | URLSession may implicitly link it; build guardrails check | Build phase guardrail script |
| Identical behavior in airplane mode (18) | CONDITIONAL | Core features: TRUE. Sync features: graceful failure | Airplane mode test in Runbook |

### Data Handling Conditional Claims

| Claim | Status | Why Conditional | Falsification Check |
|-------|--------|-----------------|---------------------|
| No filenames or emails in exports (24) | CONDITIONAL | Email blocked; some paths may leak usernames | `MetadataLeakageCaseStudy` |
| No iCloud backup of user data (34) | CONDITIONAL | AuditVaultStore mentions iCloud; needs verification | Manual audit of backup settings |

### Determinism Conditional Claims

| Claim | Status | Why Conditional | Falsification Check |
|-------|--------|-----------------|---------------------|
| Identical sessions produce identical ProofPacks (45) | CONDITIONAL | True if timestamps are same day | `DeterminismInvariantTests.testProofGenerationIsIdempotent` |
| No uncontrolled random seeds (46) | CONDITIONAL | 57 UUID() calls; used for IDs, not proof content | Code review of hash inputs |
| Simulator vs device identical proofs (52) | CONDITIONAL | Day-rounded timestamps help; device-specific data may differ | Cross-platform test |
| Async operations sequenced deterministically (59) | CONDITIONAL | @MainActor used but not universally | Async ordering tests |

### User Control Conditional Claims

| Claim | Status | Why Conditional | Falsification Check |
|-------|--------|-----------------|---------------------|
| User can inspect before sharing (64) | CONDITIONAL | Export previews exist in some views | UI audit |
| Calibration cannot be skipped (72) | CONDITIONAL | DEBUG builds may have bypasses | `#if DEBUG` audit |
| No hidden developer overrides (77) | CONDITIONAL | DEBUG-only features exist but are properly gated | `ReleaseConfig` inspection |

### Architecture Conditional Claims

| Claim | Status | Why Conditional | Falsification Check |
|-------|--------|-----------------|---------------------|
| ApprovalGate cannot be invoked indirectly (82) | CONDITIONAL | 34 references; most are proper invocations | Code review of call sites |

---

## Validation Rules

1. **Every claim must have**:
   - At least one enforcing code location
   - At least one test reference
   - At least one documentation reference

2. **No orphan claims**: If a claim is removed from the registry, all references must be updated.

3. **No undocumented claims**: Any user-visible claim must be in this registry.

4. **Claims must be verifiable**: Each claim must be testable via code or documentation.

5. **Evidence packet inclusion**: All claims should be verifiable via the External Review Evidence Packet (Phase 9D).

---

## Evidence Packet Proof Paths (Phase 9D)

Claims are verifiable through the External Review Evidence Packet:

| Claim | Proof Path in Evidence Packet |
|-------|-------------------------------|
| CLAIM-001 | `invariantCheckSummary.status`, `preflightSummary.status` |
| CLAIM-002 | `invariantCheckSummary.checkNames` (No Background Modes) |
| CLAIM-003 | `invariantCheckSummary.checkNames` (Release Safety Config) |
| CLAIM-004 | `preflightSummary.categories` (Configuration) |
| CLAIM-005 | `invariantCheckSummary.checkNames` (Two-Key) |
| CLAIM-006 | `invariantCheckSummary.checkNames` (No Analytics) |
| CLAIM-007 | `invariantCheckSummary.checkNames` (Two-Key Confirmation) |
| CLAIM-008 | `preflightSummary.categories` (Privacy) |
| CLAIM-009 | `qualityPacket.qualityFeedbackStatus` |
| CLAIM-010 | `qualityPacket.goldenCaseCount` |
| CLAIM-011 | `invariantCheckSummary.checkNames` (Deterministic Model) |
| CLAIM-012 | `integritySealStatus.status` |

Export via: Settings → External Review Readiness → Export Evidence Packet

---

## Change Log

| Date | Claim | Change | Author |
|------|-------|--------|--------|
| Phase 8C | All | Initial registry creation | System |
| Phase 9C | CLAIM-012 | Added tamper-evident quality records claim | System |
| Phase 10A | CLAIM-013-016 | Added monetization claims (payments, accounts, entitlements, no behavior change) | System |
| Phase 10B | CLAIM-017-018 | Added diagnostics claims (on-device generation, no analytics) | System |
| Phase 10C | CLAIM-019-021 | Added policy claims (operator-defined, fail-closed, no override) | System |
| Phase 10D | CLAIM-022-025 | Added sync claims (opt-in, metadata-only, manual, no content) | System |
| Phase 10E | CLAIM-026-029 | Added team claims (governance sharing, display-only roles, no shared execution, subscription) | System |
| Phase 10F | CLAIM-030-034 | Added abuse resistance claims (UI-only rate shaping, hash-based detection, non-punitive messages, no cross-user execution) | System |
| Phase 10G | CLAIM-035-038 | Added monetization enforcement claims (UI-only enforcement, paywall shows, free tier functional, no data leaves device) | System |
| Phase 10H | CLAIM-039-041 | Added commercial readiness claims (no tracking analytics, local-only counters, App Store-safe copy) | System |
| Phase 10I | CLAIM-042-044 | Added launch kit claims (user-initiated support, onboarding no content, doc integrity) | System |
| Phase 10J | CLAIM-045-046 | Added submission packet claims (metadata-only export, App Store-safe copy) | System |
| Phase 10K | — | Added governance tooling (Risk Scanner, Store Listing Lockdown) - no new claims, tooling only | System |
| Phase 10L | — | Added pricing variants and conversion funnel (local-only) - no new claims, conversion tooling only | System |
| Phase 10M | — | Added enterprise readiness packet and team sales kit (B2B tooling) - no new claims, procurement tooling only | System |
| Phase 10N | — | Added activation playbook, team trial, satisfaction signal (retention tooling) - no new claims, local-only | System |
| Phase 10O | — | Added outcome templates, pilot mode, pilot share pack (enterprise tooling) - no new claims, local-only | System |
| Phase 10P | — | Added audit trail, customer proof dashboard, repro bundle (support tooling) - no new claims, metadata-only | System |
| Phase 10Q | — | Added launch hardening: first-week state, known limitations, support packet, launch checklist (operational tooling) - no new claims, UI-only | System |
| Phase 11A | — | Added growth engine: referral codes, buyer proof packet, outbound templates, funnel extension (distribution tooling) - no new claims, local-only | System |
| Phase 11B | — | Added pricing package registry, sales playbook, pipeline tracker, sales kit export (commercial tooling) - no new claims, metadata-only | System |
| Phase 11C | CLAIM-11C-01 | Lifetime purchase option is local entitlement only | User |
| Phase 11C | CLAIM-11C-02 | Team minimum seats is 3 | System |
| Phase 11C | CLAIM-11C-03 | Team features share procedures not user content | User |
| Phase 11C | CLAIM-11C-04 | Free tier limited to 25 Drafted Outcomes per week | User |
| Phase 12A | CLAIM-12A-01 | App Store rejection vectors simulated and refuted | System |
| Phase 12A | CLAIM-12A-02 | Enterprise audit simulation completed | System |
| Phase 12A | CLAIM-12A-03 | Competitive skepticism addressed via architecture proof | System |
| Phase 12C | CLAIM-12C-01 | Terminology canonicalized in TERMINOLOGY_CANON.md | System |
| Phase 12C | CLAIM-12C-02 | Reviewer misinterpretations locked in INTERPRETATION_LOCKS.md | System |
| Phase 12D | CLAIM-12D-01 | Release Candidate declared and sealed | System |
| Phase 12D | CLAIM-12D-02 | Test scope frozen with synthetic data only | System |
| Phase 12D | CLAIM-12D-03 | All sealed artifacts hash-locked | System |

---

*This registry is enforced by `ClaimRegistryTests.swift`, `MonetizationInvariantTests.swift`, `DiagnosticsInvariantTests.swift`, `PolicyInvariantTests.swift`, `SyncInvariantTests.swift`, `TeamInvariantTests.swift`, `AbuseResistanceInvariantTests.swift`, `MonetizationEnforcementInvariantTests.swift`, `CommercialReadinessTests.swift`, `LaunchKitInvariantTests.swift`, `AppStoreReadinessInvariantTests.swift`, `AppReviewRiskScannerTests.swift`, `StoreListingLockdownTests.swift`, `PricingVariantTests.swift`, `ConversionFunnelTests.swift`, `MonetizationExecutionFirewallTests.swift`, `EnterpriseReadinessPacketTests.swift`, `TeamSalesKitTests.swift`, `PolicyTemplateTests.swift`, `EnterpriseSalesKitFirewallTests.swift`, `ActivationPlaybookTests.swift`, `TeamTrialTests.swift`, `ProcurementEmailTemplateTests.swift`, `SatisfactionSignalTests.swift`, `ActivationTrialSatisfactionFirewallTests.swift`, `OutcomeTemplateTests.swift`, `OutcomeLedgerTests.swift`, `PilotSharePackTests.swift`, `OutcomePilotFirewallTests.swift`, `AuditTrailTests.swift`, `ReproBundleTests.swift`, `AuditReproFirewallTests.swift`, `LaunchHardeningInvariantTests.swift`, `GrowthEngineInvariantTests.swift`, `SalesPackagingAndPlaybookTests.swift`, `PricingPackaging11CTests.swift`, `AdversarialReadinessTests.swift`, `ExternalReviewDryRunTests.swift`, `TerminologyCanonTests.swift`, `InterpretationLockTests.swift`, and `ReleaseCandidateSealTests.swift`*
