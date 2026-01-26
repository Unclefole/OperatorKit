# OperatorKit Safety Contract

**Version:** 1.0  
**Effective Date:** Phase 7C  
**Classification:** IMMUTABLE without explicit approval process

---

## Purpose

This document defines the non-negotiable safety guarantees of OperatorKit. Any change to these guarantees requires following the Change Control Process defined below.

**This contract exists to prevent accidental erosion of user trust.**

---

## Guarantee Classifications

### 🔴 IMMUTABLE
Cannot be changed without a complete architectural redesign and new App Store submission with updated privacy disclosures.

### 🟡 MAJOR VERSION ONLY
Can only be changed with a major version bump (e.g., 1.x → 2.0) and requires full documentation update, user notification, and App Review disclosure.

### 🟢 EXPERIMENTAL
May be modified for DEBUG builds only. Must never ship to production.

---

## Non-Negotiable Guarantees

### 1. NO AUTONOMOUS ACTIONS 🔴 IMMUTABLE

**Definition:** OperatorKit never takes action without explicit user approval.

| Aspect | Guarantee |
|--------|-----------|
| Execution | Requires `ApprovalGate.canExecute() == true` |
| Write operations | Require two-key confirmation |
| Siri | Routes only, cannot execute |
| Background | No background execution of user actions |

**Code Locations:**
- `Domain/Approval/ApprovalGate.swift`
- `Services/Siri/SiriRoutingBridge.swift`
- `Domain/Execution/ExecutionEngine.swift`

**Tests:**
- `InvariantTests.testApprovalGateBlocksUnauthorizedExecution`
- `InvariantTests.testSiriIntentCannotExecute`

**Docs:**
- `EXECUTION_GUARANTEES.md` § Approval-Required Execution
- `APP_REVIEW_PACKET.md` § Safety Gates Table

---

### 2. NO NETWORK TRANSMISSION 🔴 IMMUTABLE

**Definition:** OperatorKit never sends data over the network.

| Aspect | Guarantee |
|--------|-----------|
| User data | Never transmitted |
| Analytics | Not collected |
| Crash reports | Not sent externally |
| Model inference | On-device only |

**Code Locations:**
- `Safety/CompileTimeGuards.swift` — `#error` for network frameworks
- `Models/ModelRouter.swift` — on-device backends only

**Tests:**
- `InvariantTests.testNoNetworkFrameworksLinked`
- `InfoPlistRegressionTests.testNoBackgroundModesEnabled`

**Docs:**
- `EXECUTION_GUARANTEES.md` § What "On-Device" Means
- `PrivacyStrings.swift` § General.noNetworkStatement

---

### 3. NO BACKGROUND DATA ACCESS 🔴 IMMUTABLE

**Definition:** OperatorKit never accesses user data in the background.

| Aspect | Guarantee |
|--------|-----------|
| Calendar | Read only in ContextPicker, user-initiated |
| Reminders | Write only with two-key confirmation |
| Background modes | None enabled (UIBackgroundModes absent) |
| Background refresh | Not implemented |

**Code Locations:**
- `Info.plist` — no `UIBackgroundModes` key
- `Services/Calendar/CalendarService.swift`
- `Services/Reminders/ReminderService.swift`

**Tests:**
- `InfoPlistRegressionTests.testNoBackgroundModesEnabled`
- `InvariantTests.testNoBackgroundTaskUsage`

**Docs:**
- `APP_REVIEW_PACKET.md` § Rejection-Proof FAQ
- `DataUseDisclosureView.swift` § When Access Happens

---

### 4. DRAFT-FIRST EXECUTION 🔴 IMMUTABLE

**Definition:** Every action produces a draft for user review before execution.

| Aspect | Guarantee |
|--------|-----------|
| Email | Draft shown, user sends via Mail app |
| Reminder | Details shown in confirmation modal |
| Calendar | Event details shown before create/update |

**Code Locations:**
- `Domain/Drafts/DraftGenerator.swift`
- `UI/DraftOutput/DraftOutputView.swift`

**Tests:**
- `InvariantTests.testDraftFirstExecution`

**Docs:**
- `EXECUTION_GUARANTEES.md` § Draft-First Execution

---

### 5. TWO-KEY CONFIRMATION FOR WRITES 🔴 IMMUTABLE

**Definition:** All write operations require a second explicit confirmation.

| Aspect | Guarantee |
|--------|-----------|
| Reminder creation | `ConfirmWriteView` required |
| Calendar create/update | `ConfirmCalendarWriteView` required |
| Confirmation window | 60 seconds max |
| `secondConfirmationGranted` | Must be `true` before write |

**Code Locations:**
- `Domain/Approval/SideEffectContract.swift`
- `UI/Approval/ConfirmWriteView.swift`
- `UI/Approval/ConfirmCalendarWriteView.swift`

**Tests:**
- `InvariantTests.testTwoKeyConfirmationRequired`

**Docs:**
- `EXECUTION_GUARANTEES.md` § Two-Key Confirmation for Writes

---

### 6. SIRI ROUTES ONLY 🔴 IMMUTABLE

**Definition:** Siri can open the app and prefill text, but cannot execute actions or access data.

| Aspect | Guarantee |
|--------|-----------|
| Intent return | `.result()` with no side effects |
| Data access | None |
| Execution | None |
| Approval bypass | Impossible |

**Code Locations:**
- `Services/Siri/OperatorKitIntents.swift`
- `Services/Siri/SiriRoutingBridge.swift`

**Tests:**
- `InvariantTests.testSiriIntentCannotExecute`
- `InvariantTests.testSiriRoutingBridgeOnlyMutatesNavigationState`

**Docs:**
- `APP_REVIEW_PACKET.md` § Siri Access Details
- `ReviewerHelpView.swift` § Siri section

---

### 7. USER-SELECTED CONTEXT ONLY 🔴 IMMUTABLE

**Definition:** OperatorKit only accesses data the user explicitly selects.

| Aspect | Guarantee |
|--------|-----------|
| Calendar events | User must tap to select |
| Context packet | `wasExplicitlySelected == true` |
| Bulk reads | Not allowed |
| Automatic selection | Not implemented |

**Code Locations:**
- `Domain/Context/ContextPacket.swift`
- `Domain/Context/ContextAssembler.swift`
- `Services/Calendar/CalendarService.swift`

**Tests:**
- `InvariantTests.testContextRequiresExplicitSelection`

**Docs:**
- `DataUseDisclosureView.swift` § When Access Happens

---

### 8. AUDIT TRAIL IMMUTABILITY 🟡 MAJOR VERSION ONLY

**Definition:** Audit fields in PersistedMemoryItem cannot be modified after finalization.

| Aspect | Guarantee |
|--------|-----------|
| Timestamps | Set once, never modified |
| IDs | Set once, never modified |
| Status | Forward-only transitions |
| Post-save mutation | Blocked by AuditImmutabilityGuard |

**Code Locations:**
- `Safety/AuditImmutabilityGuard.swift`
- `Domain/Memory/PersistedMemoryItem.swift`

**Tests:**
- `PreflightValidationTests.testAuditImmutabilityGuardTracksFinalization`

**Docs:**
- `EXECUTION_GUARANTEES.md` § Audit Trail

---

### 9. DETERMINISTIC FALLBACK AVAILABLE 🟡 MAJOR VERSION ONLY

**Definition:** A deterministic, template-based model is always available as fallback.

| Aspect | Guarantee |
|--------|-----------|
| `DeterministicTemplateModel` | Always compiled in |
| Fallback trigger | Apple model unavailable OR timeout OR error |
| Confidence | Reflects fallback state |
| User informed | Fallback badge shown |

**Code Locations:**
- `Models/DeterministicTemplateModel.swift`
- `Models/ModelRouter.swift`

**Tests:**
- `InvariantTests.testDeterministicFallbackAlwaysAvailable`

**Docs:**
- `EXECUTION_GUARANTEES.md` § What "Fallback" Means

---

### 10. DEBUG-ONLY FEATURES 🟢 EXPERIMENTAL

**Definition:** Certain features are available only in DEBUG builds.

| Feature | Classification |
|---------|----------------|
| Synthetic demo data | DEBUG only |
| Eval harness | DEBUG only |
| Fault injection | DEBUG only |
| Verbose logging | DEBUG only |
| Model diagnostics | DEBUG only |

**Code Locations:**
- `#if DEBUG` guards throughout codebase
- `Safety/ReleaseConfig.swift`

**Tests:**
- `InvariantTests.testFaultInjectionNotAvailableInRelease`

---

### 11. LOCAL QUALITY FEEDBACK 🟡 MAJOR VERSION ONLY

**Definition:** User feedback about draft quality is stored locally and never transmitted.

| Aspect | Guarantee |
|--------|-----------|
| Storage | Local-only (UserDefaults/SwiftData) |
| Transmission | Never sent externally |
| Content | Metadata and tags only, no raw user content |
| User control | Can view, export, and delete at any time |
| Initiation | User-initiated only, never prompted |

**Code Locations:**
- `Domain/Quality/QualityFeedback.swift`
- `Domain/Quality/QualityFeedbackStore.swift`
- `Domain/Quality/QualityCalibration.swift`

**Tests:**
- `QualityFeedbackTests.testFeedbackCannotStoreEmailAddressInNote`
- `QualityFeedbackTests.testExportDoesNotContainRawContent`
- `QualityFeedbackTests.testNoNetworkImportsInQualityModule`

**Docs:**
- `APP_REVIEW_PACKET.md` § Local Quality Feedback

---

### 12. GOLDEN CASES (LOCAL EVAL) 🟡 MAJOR VERSION ONLY

**Definition:** Users can pin memory items as "golden cases" for local quality evaluation.

| Aspect | Guarantee |
|--------|-----------|
| Storage | Metadata-only snapshots, no raw content |
| Transmission | Never sent externally |
| Trigger | Manual trigger only, no scheduled runs |
| User control | Can view, rename, delete at any time |
| Content access | None - audit-based comparison only |

**Code Locations:**
- `Domain/Eval/GoldenCase.swift`
- `Domain/Eval/GoldenCaseStore.swift`
- `Domain/Eval/LocalEvalRunner.swift`
- `Domain/Eval/DriftSummary.swift`

**Tests:**
- `GoldenCaseTests.testSnapshotStoresNoRawContent`
- `GoldenCaseTests.testGoldenCaseExportExcludesContent`
- `LocalEvalRunnerTests.testEvalRunExportExcludesContent`
- `LocalEvalRunnerTests.testNoNetworkImportsInEvalModule`

**Docs:**
- `APP_REVIEW_PACKET.md` § Local Quality Evaluation

---

## Change Control Process

### What Constitutes a Breaking Safety Change?

1. **Any modification** to IMMUTABLE guarantees
2. **Addition** of network capabilities
3. **Addition** of background modes
4. **Removal** of approval or two-key gates
5. **Addition** of autonomous execution paths
6. **Modification** of Siri to execute actions

### Required Steps Before Any Change

| Step | Responsible | Artifact |
|------|-------------|----------|
| 1. Design Note | Engineer | Written rationale explaining why change is necessary |
| 2. Reviewer Impact Analysis | Engineer | How this affects App Store Review |
| 3. Documentation Update | Engineer | Updated EXECUTION_GUARANTEES.md, APP_REVIEW_PACKET.md |
| 4. Test Updates | Engineer | New/updated tests covering the change |
| 5. Approval Sign-Off | Principal Engineer | Signed acknowledgment with date |

### Approval Sign-Off Template

```
SAFETY CONTRACT CHANGE APPROVAL

Change Description: ____________________________________________
Guarantee Affected: ____________________________________________
Classification: [ ] IMMUTABLE [ ] MAJOR VERSION ONLY [ ] EXPERIMENTAL

Design Note Attached: [ ] Yes
Reviewer Impact Analysis: [ ] Complete
Documentation Updated: [ ] Yes
Tests Updated: [ ] Yes

Approver: _______________________
Date: _______________________
Notes: _______________________
```

---

## Guarantee → Code → Test → Doc Mapping

| # | Guarantee | Code Location | Test | Doc |
|---|-----------|---------------|------|-----|
| 1 | No autonomous actions | `ApprovalGate.swift` | `testApprovalGateBlocksUnauthorizedExecution` | EXECUTION_GUARANTEES.md |
| 2 | No network | `CompileTimeGuards.swift` | `testNoNetworkFrameworksLinked` | PrivacyStrings.swift |
| 3 | No background access | `Info.plist` | `testNoBackgroundModesEnabled` | APP_REVIEW_PACKET.md |
| 4 | Draft-first | `DraftGenerator.swift` | `testDraftFirstExecution` | EXECUTION_GUARANTEES.md |
| 5 | Two-key writes | `SideEffectContract.swift` | `testTwoKeyConfirmationRequired` | EXECUTION_GUARANTEES.md |
| 6 | Siri routes only | `OperatorKitIntents.swift` | `testSiriIntentCannotExecute` | APP_REVIEW_PACKET.md |
| 7 | User-selected context | `ContextAssembler.swift` | `testContextRequiresExplicitSelection` | DataUseDisclosureView.swift |
| 8 | Audit immutability | `AuditImmutabilityGuard.swift` | `testAuditImmutabilityGuardTracksFinalization` | EXECUTION_GUARANTEES.md |
| 9 | Deterministic fallback | `DeterministicTemplateModel.swift` | `testDeterministicFallbackAlwaysAvailable` | EXECUTION_GUARANTEES.md |
| 10 | DEBUG-only features | `ReleaseConfig.swift` | `testFaultInjectionNotAvailableInRelease` | — |
| 11 | Local quality feedback | `QualityFeedbackStore.swift` | `testExportDoesNotContainRawContent` | APP_REVIEW_PACKET.md |
| 12 | Golden cases (local eval) | `GoldenCaseStore.swift` | `testSnapshotStoresNoRawContent` | APP_REVIEW_PACKET.md |

---

## Enforcement

This contract is enforced by:

1. **Compile-time guards** — `CompileTimeGuards.swift`
2. **Runtime assertions** — DEBUG builds only
3. **Unit tests** — `InvariantTests.swift`, `InfoPlistRegressionTests.swift`
4. **Preflight validation** — `PreflightValidator.swift`
5. **Regression sentinel** — `RegressionSentinel.swift`
6. **Code review** — Reference this document in PRs

---

---

## Informational Note: Quality Record Integrity (Phase 9C)

OperatorKit quality records include **tamper-evident integrity checks**:

| Aspect | Description |
|--------|-------------|
| **What it is** | SHA-256 hashes of quality metadata for consistency verification |
| **What it is NOT** | Security, encryption, or protection |
| **Scope** | Quality exports and metadata only |
| **Content** | Never includes user content, drafts, or personal data |
| **Behavior** | Advisory and informational only — no blocking or enforcement |

### Important Clarifications

- ❌ This is NOT a security feature
- ❌ Does NOT protect data or provide encryption
- ❌ Does NOT block exports or user actions
- ✅ Allows verification that records haven't been accidentally modified
- ✅ Supports external audit workflows
- ✅ All integrity checks are local and offline

The integrity system exists to support quality governance workflows, not to make security claims.

---

---

### 13. OPT-IN CLOUD SYNC 🟡 MAJOR VERSION ONLY

**Definition:** Optional cloud sync for metadata-only packets, OFF by default.

| Aspect | Guarantee |
|--------|-----------|
| Default state | OFF — user must explicitly enable |
| What syncs | Metadata-only packets (quality, diagnostics, policy exports) |
| What NEVER syncs | Drafts, memory items, user inputs, prompts, context |
| Initiation | Manual only — explicit "Upload Now" button |
| Background sync | Not implemented |
| Isolation | Network code ONLY in Sync module |

**Code Locations:**
- `Sync/NetworkAllowance.swift` — governed exception
- `Sync/SupabaseClient.swift` — isolated network client
- `Sync/SyncPacketValidator.swift` — content-free enforcer
- `Sync/SyncQueue.swift` — manual upload only

**Tests:**
- `SyncInvariantTests.testSyncIsOffByDefault`
- `SyncInvariantTests.testValidatorBlocksForbiddenKeys`
- `SyncInvariantTests.testURLSessionOnlyInSyncModule`
- `SyncInvariantTests.testSyncFilesNoBackgroundTasks`

**Docs:**
- `APP_REVIEW_PACKET.md` § Cloud Sync section

**Important:** This is a GOVERNED EXCEPTION to Guarantee #2 (No Network Transmission):
- Network code is isolated to the Sync module ONLY
- All other modules remain network-free
- Sync is optional, off by default, and user-initiated
- Only metadata packets can be synced, never user content

---

### 14. TEAM GOVERNANCE SHARING 🟡 MAJOR VERSION ONLY

**Definition:** Teams can share governance artifacts (metadata only), never user content.

| Aspect | Guarantee |
|--------|-----------|
| What teams CAN share | Policy templates, diagnostics, quality summaries, evidence refs |
| What teams CANNOT share | Drafts, memory items, context, user inputs, execution state |
| Role enforcement | UI display only, NOT execution enforcement |
| Default state | Team features OFF by default |
| Initiation | Manual upload only |

**Code Locations:**
- `Team/TeamAccount.swift` — team identity
- `Team/TeamArtifacts.swift` — shareable artifact types
- `Team/TeamArtifactValidator.swift` — content-free enforcer

**Tests:**
- `TeamInvariantTests.testExecutionEngineDoesNotImportTeam`
- `TeamInvariantTests.testValidatorBlocksForbiddenKeys`
- `TeamInvariantTests.testShareableArtifactTypesAreLimited`
- `TeamInvariantTests.testTeamRoleHasNoExecutionMethods`

**Docs:**
- `APP_REVIEW_PACKET.md` § Team Governance section

**Important:**
- Team roles are for UI display and member management only
- No role-based execution enforcement
- No shared execution or approval bypassing
- No admin-controlled killswitches

---

### 15. ABUSE RESISTANCE & USAGE DISCIPLINE 🟢 SAFE TO CHANGE

**Definition:** Rate shaping and usage visibility at UI level only.

| Aspect | Guarantee |
|--------|-----------|
| Rate shaping | UI-level only, does NOT affect execution |
| Cost visibility | Informational only, no actual pricing |
| Abuse detection | Hash-based only, no content inspection |
| Tier boundaries | UI enforcement only |
| Messages | Non-punitive, no moralizing |

**Code Locations:**
- `Safety/RateShaping.swift` — UI-level rate limits
- `Safety/CostVisibility.swift` — usage units (not currency)
- `Safety/AbuseGuardrails.swift` — hash-based detection
- `Safety/TierBoundaries.swift` — tier feature matrix

**Tests:**
- `AbuseResistanceInvariantTests.testExecutionEngineDoesNotImportAbuseModules`
- `AbuseResistanceInvariantTests.testRateShaperDoesNotBlockExecution`
- `AbuseResistanceInvariantTests.testAbuseDetectorUsesHashesOnly`
- `AbuseResistanceInvariantTests.testUsageMessagesAreNonPunitive`

**Docs:**
- `APP_REVIEW_PACKET.md` § Usage Discipline section

**Important:**
- Rate shaping suggests, does not block execution
- Abuse detection uses hashes, never inspects content
- Cost indicators show units, never actual prices
- All enforcement is at UI boundary, never in execution modules

---

### 16. MONETIZATION ENFORCEMENT 🟢 SAFE TO CHANGE

**Definition:** Subscription quotas enforced at UI boundaries only.

| Aspect | Guarantee |
|--------|-----------|
| Enforcement location | UI boundary only |
| Core modules | ExecutionEngine/ApprovalGate/ModelRouter untouched |
| Blocking behavior | Shows paywall, never silent |
| Existing content | Never blocked from viewing |
| Content storage | None (counters + metadata only) |

**Code Locations:**
- `Monetization/QuotaEnforcer.swift` — quota checks
- `Monetization/PaywallGate.swift` — UI gating
- `Monetization/TierMatrix.swift` — feature matrix

**Tests:**
- `MonetizationEnforcementInvariantTests.testExecutionEngineDoesNotImportMonetization`
- `MonetizationEnforcementInvariantTests.testFreeTierOverQuotaBlocks`
- `MonetizationEnforcementInvariantTests.testBlockedResultShowsPaywall`
- `MonetizationEnforcementInvariantTests.testMessagesAreAppStoreSafe`

**Docs:**
- `APP_REVIEW_PACKET.md` § Monetization Enforcement section

**Important:**
- Quotas are checked BEFORE intent processing in UI layer
- Users can always view existing drafts regardless of quota
- Paywall always shows, never silent blocking
- No StoreKit imports in execution modules

---

### 17. LOCAL-ONLY CONVERSION TRACKING 🟢 SAFE TO CHANGE

**Definition:** Conversion events tracked locally without analytics SDKs.

| Aspect | Guarantee |
|--------|-----------|
| Storage location | Local UserDefaults only |
| Analytics SDKs | None imported |
| User identifiers | Not stored |
| Receipt data | Not stored |
| Export | User-initiated only |

**Code Locations:**
- `Monetization/ConversionLedger.swift` — local counters
- `ConversionExportPacket` — export format

**Tests:**
- `CommercialReadinessTests.testNoAnalyticsSDKImports`
- `CommercialReadinessTests.testConversionLedgerNoForbiddenKeys`

**Docs:**
- `APP_REVIEW_PACKET.md` § Commercial Readiness section

**Important:**
- ConversionLedger stores event counts and timestamps only
- No Firebase, Amplitude, Mixpanel, or other analytics SDKs
- No user identifiers or receipt data
- Export is always user-initiated via share sheet

---

### 18. ONBOARDING METADATA-ONLY 🟢 SAFE TO CHANGE

**Definition:** Onboarding stores completion state only, no user content.

| Aspect | Guarantee |
|--------|-----------|
| Storage | Completion flag and timestamp only |
| User content | Not stored |
| User preferences | Not stored |
| Sample intents | Static, not personalized |

**Code Locations:**
- `UI/Onboarding/OnboardingStateStore.swift` — state management
- `UI/Onboarding/OnboardingView.swift` — presentation

**Tests:**
- `LaunchKitInvariantTests.testOnboardingNoForbiddenKeys`

**Docs:**
- `APP_REVIEW_PACKET.md` § Onboarding section

---

### 19. SUPPORT USER-INITIATED 🟢 SAFE TO CHANGE

**Definition:** Support contact requires explicit user action.

| Aspect | Guarantee |
|--------|-----------|
| Email | Uses MFMailComposeViewController |
| Auto-send | Never |
| Refunds | Links to Apple, no promises |

**Code Locations:**
- `UI/Support/HelpCenterView.swift` — help center UI
- `SupportCopy.swift` — templates

**Tests:**
- `LaunchKitInvariantTests.testSupportNoAutoSend`

**Docs:**
- `APP_REVIEW_PACKET.md` § Support section

---

## Version History

| Version | Date | Changes | Approver |
|---------|------|---------|----------|
| 1.0 | Phase 7C | Initial contract | — |
| 1.1 | Phase 9C | Added informational integrity note | — |
| 1.2 | Phase 10D | Added opt-in cloud sync guarantee | — |
| 1.3 | Phase 10E | Added team governance sharing guarantee | — |
| 1.4 | Phase 10F | Added abuse resistance guarantee | — |
| 1.5 | Phase 10G | Added monetization enforcement guarantee | — |
| 1.6 | Phase 10H | Added local-only conversion tracking guarantee | — |
| 1.7 | Phase 10I | Added onboarding and support guarantees | — |

---

*This document is referenced by core safety-critical files. See header comments in: ApprovalGate.swift, SiriRoutingBridge.swift, ExecutionEngine.swift, CalendarService.swift, ReminderService.swift*
