# OperatorKit Execution Guarantees

This document defines the non-negotiable execution guarantees of OperatorKit. It is intended for:

- Future engineers maintaining this codebase
- Security reviewers auditing the application
- Apple App Review teams evaluating compliance
- Anyone needing to understand OperatorKit's architectural commitments

---

## Core Invariants

OperatorKit is built on a set of invariants that must never be violated. These are enforced at compile time, runtime, and through architectural design.

### 1. Draft-First Execution

**Guarantee:** Every action produces a draft for user review before execution.

**Implementation:**
- `DraftGenerator` always produces a `Draft` object
- No execution path bypasses the draft review screen
- The draft contains exactly what will be executed
- Users can edit drafts before approval

**Why:** Users must see and understand what will happen before it happens.

### 2. Approval-Required Execution

**Guarantee:** No action is executed without explicit user approval.

**Implementation:**
- `ApprovalGate.canExecute()` must return `true` before any execution
- `approvalGranted` flag in `AppState` must be set by user action
- Debug assertions crash the app if approval is bypassed
- Navigation cannot skip the approval screen

**Why:** Users must consciously choose to execute every action.

### 3. Two-Key Confirmation for Writes

**Guarantee:** Actions that create or modify external data require a second confirmation.

**Implementation:**
- `SideEffect.requiresTwoKeyConfirmation` identifies write operations
- `ConfirmWriteView` / `ConfirmCalendarWriteView` must be presented
- `secondConfirmationGranted` must be `true` with a valid timestamp
- Confirmation expires after 60 seconds
- Debug assertions block writes without two-key confirmation

**Why:** Destructive or persistent actions deserve extra deliberation.

### 4. User-Selected Context Only

**Guarantee:** OperatorKit only accesses data the user explicitly selects.

**Implementation:**
- `ContextPacket.wasExplicitlySelected` must be `true`
- `CalendarService` only returns events the user tapped
- No bulk reads or background fetches
- Citations reference only selected context items

**Why:** Users control what information OperatorKit can see.

### 5. Siri Routes Only

**Guarantee:** Siri can open the app and prefill text, but cannot execute actions.

**Implementation:**
- `OperatorKitIntents.swift` returns `.result()` with no side effects
- `SiriRoutingBridge` only sets `siriPrefillText` and navigates to `intentInput`
- No execution code in any App Intent
- User must review and tap Continue after Siri route

**Why:** Voice entry is convenient, but execution requires visual confirmation.

---

## Explicit Non-Goals

OperatorKit intentionally does NOT do the following:

### No Background Agents
- No background app refresh
- No background fetch
- No background processing
- No scheduled tasks
- No push notification handling that executes logic

### No Autonomous Actions
- No actions without user approval
- No inferred actions based on context
- No "smart" suggestions that execute automatically
- No time-based triggers
- No location-based triggers

### No Network Communication
- No API calls
- No analytics
- No telemetry
- No crash reporting to external servers
- No cloud sync
- No remote configuration

### No Hidden Side Effects
- Every side effect is shown in ApprovalView
- No silent writes to calendars, reminders, or files
- No silent email sending
- No silent data modification

---

## What "On-Device" Means

When OperatorKit says "on-device," it means:

### Processing
- All text generation happens locally using:
  - Apple's on-device Foundation Models (when available)
  - Core ML models bundled with the app (when available)
  - Deterministic template-based generation (always available)
- No data leaves the device for processing
- No API calls to language model services

### Storage
- All memory items stored in local SwiftData
- All audit trails stored locally
- No cloud backup of sensitive data
- No sync to external services

### What On-Device Does NOT Mean
- It does not mean "private from the user" — users can see all stored data
- It does not mean "deleted on uninstall" — standard iOS data persistence applies
- It does not mean "encrypted at rest" — relies on iOS Data Protection

---

## What "Fallback" Means

OperatorKit uses a model routing system with fallback:

### Primary Models (When Available)
1. **Apple On-Device Model** — Uses Apple's Foundation Models framework (iOS 18.1+)
2. **Core ML Model** — Uses bundled .mlmodelc files

### Fallback Model (Always Available)
3. **Deterministic Template Model** — Rule-based text generation

### When Fallback Occurs
- Primary model not available on device/OS
- Primary model returns error
- Primary model times out (latency budget exceeded)
- Output validation fails

### Fallback Guarantees
- Fallback is logged in audit trail (`usedFallback`, `fallbackReason`)
- User is informed when fallback occurs
- Confidence score reflects fallback (typically lower)
- No functional difference in user control — approval still required

### Why Fallback Exists
- Ensures app works on all supported devices
- Provides reliability when ML infrastructure fails
- Maintains user trust — app always produces output

---

## How Audit Trail Works

Every execution creates an audit trail entry:

### What Is Recorded
- **Request:** Original intent text, timestamp
- **Context:** Summary of selected items (not raw data)
- **Plan:** Steps that were planned
- **Draft:** Generated content, confidence score
- **Model:** Backend used, latency, fallback reason if any
- **Approval:** Timestamp, acknowledged side effects
- **Execution:** Status, executed side effects, results
- **Writes:** Confirmation timestamps, created identifiers

### Where It Is Stored
- `PersistedMemoryItem` in local SwiftData
- Accessible via Memory view
- Not transmitted externally

### Retention
- Stored until user deletes
- No automatic expiration
- User can delete individual items

### Immutability (Phase 7A)
Audit fields are subject to strict immutability rules:

1. **Append-Only**: New entries can be added during execution, but not after completion
2. **Never Overwritten**: Timestamps and IDs are set once and cannot be changed
3. **Never Editable After Save**: Once saved to SwiftData, the item is finalized

Enforcement:
- `AuditImmutabilityGuard` tracks finalized items
- DEBUG assertions prevent modification after finalization
- `ImmutableAfterFinalization` property wrapper locks fields

### Purpose
- User transparency
- Debugging
- Security audit
- Compliance demonstration

---

## Runtime Enforcement

OperatorKit enforces invariants at runtime:

### Debug Assertions
In DEBUG builds, the following trigger `assertionFailure`:
- Execution without `approvalGranted == true`
- Context access without `wasExplicitlySelected == true`
- Write without `secondConfirmationGranted == true`
- Calendar update without user-selected event identifier
- Skipping steps in the flow

### Production Behavior
In RELEASE builds:
- Assertions are disabled (standard Swift behavior)
- Guards prevent invalid states from proceeding
- Invalid operations return errors, not crashes

---

## Compile-Time Enforcement

OperatorKit uses compile-time guards:

### Framework Restrictions
- No import of networking frameworks (URLSession is system, but not used)
- No import of background task frameworks
- Apple on-device model is compile-guarded (`#if canImport`)

### Configuration Restrictions
- No background modes in entitlements
- Deployment target iOS 17+ enforced
- Siri entitlement present (for routing only)

---

## Code Locations

| Invariant | Primary Enforcement Location |
|-----------|------------------------------|
| Draft-first | `DraftGenerator.swift`, `PlanPreviewView.swift` |
| Approval-required | `ApprovalGate.swift`, `AppState.swift` |
| Two-key writes | `SideEffectContract.swift`, `ConfirmWriteView.swift` |
| User-selected context | `ContextAssembler.swift`, `CalendarService.swift` |
| Siri routes only | `OperatorKitIntents.swift`, `SiriRoutingBridge.swift` |
| On-device processing | `ModelRouter.swift`, `DeterministicTemplateModel.swift` |
| Audit trail | `ExecutionResult.swift`, `PersistedMemoryItem.swift` |

---

## Modification Policy

Before modifying any code related to these guarantees:

1. **Read this document** — Understand why the guarantee exists
2. **Consult the team** — Changes to invariants require review
3. **Update this document** — If a guarantee changes, document it
4. **Add tests** — Invariant changes require test coverage
5. **Consider App Store impact** — Privacy claims must remain accurate

---

## Contact

For questions about these guarantees:
- Review the codebase inline documentation
- Check `InvariantTests.swift` for test coverage
- Consult the original architecture decisions

---

*Last updated: Phase 6A — App Store Preparation*
