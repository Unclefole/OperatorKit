# OperatorKit App Review Packet

This document is prepared for Apple App Review. It provides complete transparency about what OperatorKit does, what data it accesses, and how it protects user privacy.

---

## App Summary

OperatorKit is an on-device task assistant that helps users draft emails, create reminders, and manage calendar events. All processing happens locally on the device. The app generates drafts for user review—no action is taken without explicit user approval. Users control which data is accessed, and all writes require a second confirmation step.

---

## Data Access Table

| Data Type | Access Trigger | Scope Limits | Stored Locally? | Sent Externally? |
|-----------|----------------|--------------|-----------------|------------------|
| **Calendar Events** | User opens Context Picker and grants permission | ±7 days from today, max 50 events | Event metadata saved in Memory (SwiftData) if user completes flow | **No** |
| **Reminders** | User approves reminder creation and confirms details | One reminder per action | Reminder ID saved in Memory if created | **No** |
| **Email (Mail)** | User approves email draft and taps "Open Composer" | Pre-filled subject/body only | Draft content saved in Memory | **No** — User manually sends via Mail app |
| **Siri Voice Input** | User invokes Siri with "Ask OperatorKit..." | Spoken text only | Pre-fill text not stored separately | **No** |

### Calendar Access Details
- Permission requested: `NSCalendarsUsageDescription`
- Read scope: Events from 7 days ago to 7 days ahead
- Maximum events displayed: 50
- User must explicitly tap each event to select
- Only selected events are used as context
- Write operations (create/update) require two-key confirmation

### Reminders Access Details
- Permission requested: `NSRemindersUsageDescription`
- Read scope: None (OperatorKit does not read existing reminders)
- Write scope: Creates new reminders only
- Every write requires: approval + second confirmation
- No bulk operations (one reminder per action)

### Siri Access Details
- Permission requested: `NSSiriUsageDescription`
- Siri's role: Voice entry point only
- Siri can: Open app, pre-fill request text
- Siri cannot: Execute actions, access data, bypass approval
- After Siri opens app: User must review and explicitly continue

---

## Safety Gates Table

| Safety Gate | Description | Enforcement Location |
|-------------|-------------|---------------------|
| **Draft-First** | Every action produces a draft for review before execution | `DraftGenerator.swift`, `DraftOutputView.swift` |
| **Approval Required** | No execution without explicit user approval tap | `ApprovalGate.swift`, `ApprovalView.swift` |
| **Two-Key Writes** | Reminder/Calendar writes require a second confirmation | `ConfirmWriteView.swift`, `ConfirmCalendarWriteView.swift` |
| **Siri Routes Only** | Siri opens app but cannot execute | `OperatorKitIntents.swift`, `SiriRoutingBridge.swift` |
| **No Background Access** | No background modes enabled | `Info.plist` — UIBackgroundModes intentionally absent |
| **User-Selected Context** | Only explicitly selected items are accessed | `ContextAssembler.swift`, `CalendarService.swift` |
| **On-Device Processing** | All text generation is local | `ModelRouter.swift`, no network imports |
| **60-Second Confirmation Window** | Two-key confirmations expire after 60 seconds | `SideEffectContract.swift` |

---

## Info.plist Privacy Strings Checklist

| Key | Value | Matches PrivacyStrings? |
|-----|-------|------------------------|
| `NSCalendarsUsageDescription` | "OperatorKit uses calendar access to show your events so you can select which ones to include as context for your requests. Events are only read when you explicitly select them." | ✓ Yes |
| `NSRemindersUsageDescription` | "OperatorKit uses reminders access to create reminders on your behalf when you explicitly request and confirm them. Reminders are only created after you review and approve the details." | ✓ Yes |
| `NSSiriUsageDescription` | "OperatorKit uses Siri to let you start requests by voice. Siri only opens the app and pre-fills your request—it cannot execute actions or access your data. You always review and approve before anything happens." | ✓ Yes |
| `UIBackgroundModes` | **Not present** (intentional) | ✓ Correct |

---

## 2-Minute Test Plan for Reviewers

### Test 1: Siri Route (30 seconds)
1. Say: "Hey Siri, ask OperatorKit to draft a follow-up email"
2. **Verify**: App opens with text pre-filled
3. **Verify**: A banner says "Siri Started This Request"
4. **Verify**: User must acknowledge before continuing
5. **Expected**: No action is taken until user taps Continue

### Test 2: Calendar Read (30 seconds)
1. Open app → Tap input card → Enter "Summarize my meetings"
2. Tap Continue → Reach Context Picker
3. Tap "Allow" when calendar permission appears
4. **Verify**: Events from ±7 days are shown
5. Select 1-2 events → Tap Continue
6. **Expected**: Only selected events appear in plan/draft

### Test 3: Reminder Write (30 seconds)
1. Complete flow to Approval screen with reminder side effect
2. Enable "Create Reminder" toggle
3. Tap "Approve & Execute"
4. **Verify**: Confirmation modal appears showing exact reminder details
5. Tap "Confirm Create"
6. **Verify**: Reminder appears in Reminders app
7. **Expected**: Two distinct confirmation steps required

### Test 4: Email Draft (20 seconds)
1. Complete flow to Execution Complete screen
2. Tap "Open Email Composer"
3. **Verify**: Mail composer opens with pre-filled content
4. **Verify**: User must manually tap Send
5. **Expected**: App cannot send email automatically

### Test 5: Memory Audit Trail (10 seconds)
1. Go to Memory tab
2. Select any completed operation
3. **Verify**: Trust Summary shows approval status, model used, timestamps
4. **Expected**: Complete audit trail of what was done

---

## Rejection-Proof FAQ

### Q: Does OperatorKit send email automatically?
**A: No.** OperatorKit opens the system Mail composer with pre-filled content. The user must manually tap Send in the Mail app. OperatorKit cannot send emails.

### Q: Does OperatorKit read calendar events in the background?
**A: No.** Calendar access only occurs when the user opens the Context Picker screen and explicitly selects events. There are no background modes enabled. `UIBackgroundModes` is intentionally absent from Info.plist.

### Q: Does OperatorKit upload data to servers?
**A: No.** All processing happens on-device. OperatorKit does not import networking frameworks and does not make HTTP requests. There is no analytics, telemetry, or cloud sync.

### Q: Does OperatorKit auto-create reminders or calendar events?
**A: No.** Creating or modifying reminders/calendar events requires:
1. User approval (Approval screen)
2. Second confirmation (separate confirmation modal)
The confirmation modal shows exact details and has a 60-second expiration window.

### Q: Is Siri used to execute actions?
**A: No.** Siri is a router only. When a user invokes OperatorKit via Siri:
1. Siri opens the app
2. Siri pre-fills the spoken request
3. User sees a banner indicating Siri started the request
4. User must acknowledge and tap Continue
5. All subsequent approvals are still required

Siri cannot bypass the approval flow, access user data, or execute any actions.

### Q: What happens if the on-device model is unavailable?
**A: Fallback to deterministic templates.** If Apple's on-device model (iOS 18.1+) is unavailable, OperatorKit uses a rule-based template system that runs entirely on-device. The user is informed when fallback occurs. All safety gates remain in effect.

### Q: Does the app work offline?
**A: Yes.** OperatorKit is fully functional offline because all processing is on-device. The only exception is if the user tries to send an email (which requires the Mail app's network access, not OperatorKit's).

---

## Audit Trail Immutability

OperatorKit maintains an immutable audit trail:

- **Append-only**: New entries added during execution only
- **Never overwritten**: Timestamps and IDs set once
- **Finalized after save**: No modifications after completion

This ensures the recorded history is trustworthy and cannot be altered retroactively.

---

## Compile-Time Safety Verification

OperatorKit includes compile-time guards that fail the build if prohibited frameworks are imported:

- ❌ No networking libraries (Alamofire, Moya, etc.)
- ❌ No analytics (Firebase, Amplitude, Mixpanel, etc.)
- ❌ No crash reporting to external servers (Crashlytics, Sentry, etc.)
- ❌ No advertising SDKs

If the app builds successfully, these guards have passed.

---

## Local Quality Feedback (Phase 8A)

OperatorKit includes an optional quality feedback feature:

- **User-initiated only**: Users can optionally rate drafts as helpful/not helpful
- **Stored locally**: Feedback is stored in UserDefaults on the device
- **No transmission**: Feedback is never sent to external servers
- **User control**: Users can view, export, and delete their feedback at any time
- **Metadata only**: Feedback contains ratings and predefined tags, never raw content

### What Feedback Contains

| Field | Description |
|-------|-------------|
| Rating | helpful / not helpful / mixed |
| Issue tags | Predefined list (e.g., "wrong tone", "too long") |
| Model metadata | Backend used, confidence level |
| Timestamp | When feedback was submitted |

### What Feedback Does NOT Contain

- Email content
- Calendar event details
- User's personal information
- Raw context from selected items

### User Controls

- **View**: Privacy Controls → Quality & Trust
- **Export**: Export as JSON (metadata only)
- **Delete**: Delete individual entries or all feedback

---

## Local Quality Evaluation (Phase 8B)

OperatorKit includes optional local QA tools:

- **Golden cases**: Users can "pin" memory items as reference cases for evaluation
- **Manual trigger only**: Evaluation runs only when user taps "Run Eval"
- **Metadata only**: Snapshots contain counts and flags, never raw content
- **Drift detection**: Compares current behavior against pinned baselines
- **User control**: Users can rename, export, and delete golden cases anytime

### What Golden Case Snapshots Contain

| Field | Description |
|-------|-------------|
| Intent/Output type | Category labels (e.g., "email", "summary") |
| Context counts | Number of items per type (e.g., "Calendar: 2") |
| Confidence band | low / medium / high |
| Backend used | Which model backend was used |
| Flags | timeout, validation pass, citation validity |
| Latency | Processing time in milliseconds |

### What Golden Cases Do NOT Contain

- Email content or subject lines
- Calendar event titles or participants
- Draft body text
- User's personal information
- Any raw context data

### Pass/Fail Rules (Deterministic)

| Condition | Result |
|-----------|--------|
| Timeout occurred | Fail |
| Validation failed | Fail |
| Citation validity failed | Fail |
| Latency > threshold | Fail |
| Fallback drift detected | Fail |
| All checks pass | Pass |

### User Controls

- **Pin**: Memory detail → "Pin as Golden Case" (with disclosure)
- **View**: Quality & Trust → Golden Cases list
- **Run**: Quality & Trust → "Run Golden Case Eval"
- **Report**: Quality & Trust → "View Quality Report"
- **Export**: Export as JSON (metadata only)
- **Delete**: Remove individual cases or all

---

## Evidence Packet Export (Phase 9D)

OperatorKit can export a comprehensive evidence packet for external review:

### How to Export

1. Open Settings → External Review Readiness
2. Tap "Export Evidence Packet"
3. Use the share sheet to save or send the JSON file

### What the Evidence Packet Contains

| Section | Contents |
|---------|----------|
| **App Identity** | Version, build number, release mode |
| **Safety Contract** | Hash verification status, last update reason |
| **Claim Registry** | List of all claims with their IDs |
| **Invariant Checks** | Pass/fail status for all runtime checks |
| **Preflight Summary** | Build validation results |
| **Quality Metrics** | Golden case count, pass rates, drift levels |
| **Integrity Status** | SHA-256 verification of quality records |
| **Reviewer Test Plan** | 2-minute verification steps |
| **FAQ** | Common reviewer questions and answers |
| **Disclaimers** | Scope and limitations of the export |

### What the Evidence Packet Does NOT Contain

- Email content or subject lines
- Calendar event titles or attendees
- Reminder text or notes
- Any user-generated content
- Personal data of any kind

### Export Constraints

| Rule | Description |
|------|-------------|
| Manual only | User must tap to export |
| No auto-export | No scheduled or background exports |
| No upload | Export stays local unless user shares |
| Metadata only | Never contains user content |

---

## Subscription & In-App Purchase (Phase 10A)

OperatorKit offers an optional subscription (OperatorKit Pro):

### Free Tier

| Feature | Limit |
|---------|-------|
| Executions | 5 per week |
| Saved items | 10 maximum |
| All safety features | Fully available |
| All privacy features | Fully available |

### Pro Tier

| Feature | Limit |
|---------|-------|
| Executions | Unlimited |
| Saved items | Unlimited |
| All safety features | Fully available |
| All privacy features | Fully available |

### What Subscription Does NOT Affect

| Aspect | Behavior |
|--------|----------|
| Execution logic | Identical for Free and Pro |
| Approval gates | Unchanged |
| Two-key confirmations | Unchanged |
| Draft-first workflow | Unchanged |
| Model routing | Unchanged |
| Privacy guarantees | Unchanged |

### Technical Implementation

| Component | Description |
|-----------|-------------|
| Payment processing | Apple StoreKit 2 only |
| Entitlement verification | On-device, local |
| Server validation | None (no server) |
| Account required | No |
| Network required for purchase | Yes (Apple's servers) |
| Network required for app use | No |

### Claims Enforced

- CLAIM-013: "Payments processed by Apple via StoreKit"
- CLAIM-014: "No accounts required"
- CLAIM-015: "Subscription status checked on-device"
- CLAIM-016: "Monetization does not affect execution"

### Where Limits Are Enforced

Limits are checked at the **UI boundary only**:

- `IntentInputView.swift` — before starting a new request
- `PrivacyControlsView.swift` — subscription status display

Limits are **NOT enforced in**:

- `ExecutionEngine.swift` — no monetization code
- `ApprovalGate.swift` — no monetization code
- `ModelRouter.swift` — no monetization code

### Test Plan for Subscription

1. **Verify Free tier limit**: Start app → Make 5 requests → Sixth request shows "limit reached" message
2. **Verify paywall**: When limit reached → "Upgrade to Pro" button visible → Opens paywall
3. **Verify Pro removes limits**: Subscribe → Limits removed → Execution unchanged

---

## Quality Record Integrity (Phase 9C)

OperatorKit includes integrity verification for quality records:

### What Integrity Checks Do

- **Compute checksums**: SHA-256 hashes of quality metadata (not user content)
- **Detect modifications**: Flag if quality records have been altered
- **Support auditing**: Enable verification that quality data is consistent

### What Integrity Checks Do NOT Do

| Misconception | Reality |
|---------------|---------|
| "Provides security" | ❌ No — integrity ≠ security |
| "Encrypts data" | ❌ No — hashing, not encryption |
| "Protects user content" | ❌ No — never touches user content |
| "Blocks operations" | ❌ No — purely informational |
| "Requires network" | ❌ No — all checks are local |

### User-Visible Indicators

The Release Readiness view displays integrity status:

- **"Integrity: Verified"** — Record matches expected checksum
- **"Integrity: Mismatch"** — Record differs from expected (informational only)
- **"Integrity: Not Available"** — No checksum computed

These are **informational displays only** — they do not block any user action or app functionality.

---

## Operator Diagnostics (Phase 10B)

OperatorKit provides local diagnostics for operator visibility:

### What Diagnostics Show

| Category | Information Displayed |
|----------|----------------------|
| **Execution Summary** | Executions this week, executions today, last outcome |
| **Usage & Limits** | Current tier, remaining executions, saved items count |
| **Reliability** | Whether fallback was used recently, last issue category |
| **System Guarantees** | Static display of immutable guarantees |

### What Diagnostics Do NOT Include

- Email content, subjects, or recipients
- Calendar event titles or attendees
- Reminder text or notes
- Any user-generated content
- Device identifiers (only generic model: "iPhone")
- User account information

### How Diagnostics Work

| Aspect | Behavior |
|--------|----------|
| Generation | On-device only, snapshot-based |
| Monitoring | None — captured on-demand only |
| Export | Manual via ShareSheet, user-initiated |
| Transmission | None — stays on device unless user shares |
| Side Effects | None — read-only, does not modify state |

### Diagnostics Export

Users can export diagnostics as a JSON file:

1. Open Privacy Controls → Diagnostics
2. Tap "Export Diagnostics"
3. Use ShareSheet to save or share

The export includes:
- App version and build number
- iOS version (generic)
- Execution and usage statistics
- Invariant check status
- No user content

### Claims Enforced

- CLAIM-017: "Operator-visible diagnostics are generated on-device"
- CLAIM-018: "No analytics or telemetry is collected"

---

## Execution Policies (Phase 10C)

OperatorKit allows users to define execution policies that constrain what the app can do:

### What Policies Control

| Capability | Description | Default |
|------------|-------------|---------|
| **Email Drafts** | Allow drafting and presenting emails | Allowed |
| **Calendar Writes** | Allow creating/updating calendar events | Allowed |
| **Task Creation** | Allow creating reminders and tasks | Allowed |
| **Memory Saves** | Allow saving items to memory | Allowed |
| **Daily Limit** | Maximum executions per day | No limit |
| **Explicit Confirmation** | Require confirmation for all actions | Required |

### How Policies Work

| Aspect | Behavior |
|--------|----------|
| Storage | Local-only, UserDefaults |
| Enforcement | UI entry points only |
| Modification | Explicit user action required |
| Default | Conservative (confirmation required) |
| Override | Never automatic |

### What Policies Do NOT Affect

- **ExecutionEngine**: Not modified, no policy references
- **ApprovalGate**: Not modified, no policy references
- **ModelRouter**: Not modified, no policy references
- **Safety guarantees**: All remain in effect regardless of policy

### Where Policies Are Enforced

Policies are checked at the **UI boundary only**:

- `IntentInputView.swift` — before starting execution
- `PolicyEditorView.swift` — for user configuration

Policies are **NOT enforced in**:

- `ExecutionEngine.swift` — no policy code
- `ApprovalGate.swift` — no policy code
- `ModelRouter.swift` — no policy code

### Test Plan for Policies

1. **Verify policy blocks capability**: Disable "Email Drafts" in policy → Try to draft email → Shows "Blocked by Policy" callout
2. **Verify policy editor**: Open Privacy Controls → Execution Policy → Edit Policy → Toggle capabilities → Save
3. **Verify fail-closed**: Default policy requires explicit confirmation

### Claims Enforced

- CLAIM-019: "Operator-defined execution policies"
- CLAIM-020: "Fail-closed enforcement"
- CLAIM-021: "No autonomous policy override"

---

## Cloud Sync (Phase 10D)

OperatorKit includes an **optional** cloud sync feature for backing up metadata-only packets. This feature is:

### Key Facts

| Aspect | Detail |
|--------|--------|
| **Default State** | OFF — user must explicitly enable |
| **Authentication** | Email OTP via Supabase |
| **Upload Trigger** | Manual only — explicit "Upload Now" button |
| **Background Sync** | Not implemented |

### What CAN Sync (Metadata Only)

| Packet Type | Contents |
|-------------|----------|
| Quality Exports | Metrics, scores, timestamps |
| Diagnostics Exports | Execution stats, usage stats |
| Policy Exports | Policy settings |
| Release Acknowledgements | Release sign-offs |
| Evidence Packets | Audit metadata |

### What NEVER Syncs

| Data Type | Reason |
|-----------|--------|
| **Drafts** | Contains user-authored content |
| **Memory Items** | Contains user preferences |
| **User Inputs** | Contains prompts and requests |
| **Calendar Content** | Contains personal events |
| **Email Content** | Contains personal communications |
| **Context Packets** | Contains selected data |

### Payload Validation

Before any upload, the `SyncPacketValidator` enforces:

1. **Forbidden Keys Check**: Rejects any payload containing:
   - body, subject, email, recipient, attendees
   - title, description, prompt, context, draft
   - content, message, text, note, name, address

2. **Size Limit**: Maximum 200KB per packet

3. **Required Metadata**: Must include schemaVersion and exportedAt

4. **Fail Closed**: If uncertain, block upload and show reason

### Network Isolation

Network code is **strictly isolated** to the `Sync/` module:

- `Sync/SupabaseClient.swift` — ONLY file using URLSession
- All other modules remain network-free
- Enforced by `SyncInvariantTests`

### Test Plan for Cloud Sync

1. **Verify OFF by default**: Fresh install → Settings → Sync toggle should be OFF
2. **Verify manual upload**: Enable sync → Sign in → Stage packet → Upload only happens on "Upload Now" tap
3. **Verify content blocking**: Try to sync packet with "body" key → Should be rejected
4. **Verify isolation**: ExecutionEngine, ApprovalGate, ModelRouter have no network code

### Claims Enforced

- CLAIM-022: "Optional cloud sync is OFF by default"
- CLAIM-023: "Uploads metadata-only packets"
- CLAIM-024: "Manual upload only"
- CLAIM-025: "No drafts/content uploaded"

---

## Team Governance (Phase 10E)

OperatorKit includes a **Team tier** for organizations that want to share governance artifacts:

### What Teams CAN Share

| Artifact Type | Contents | Shared? |
|---------------|----------|---------|
| **Policy Templates** | Capability settings | ✅ Yes |
| **Diagnostics Snapshots** | Aggregate stats | ✅ Yes |
| **Quality Summaries** | Pass rates, drift | ✅ Yes |
| **Evidence References** | Hash + timestamp | ✅ Yes |
| **Release Acknowledgements** | Sign-off metadata | ✅ Yes |

### What Teams CANNOT Share

| Data Type | Reason | Shared? |
|-----------|--------|---------|
| **Drafts** | User content | ❌ Never |
| **Memory Items** | User preferences | ❌ Never |
| **Context Packets** | User-selected data | ❌ Never |
| **User Inputs** | Prompts, requests | ❌ Never |
| **Execution State** | Active work | ❌ Never |

### Team Roles

| Role | Permissions | Affects Execution? |
|------|-------------|-------------------|
| **Owner** | Full team management | ❌ No |
| **Admin** | Manage members, artifacts | ❌ No |
| **Member** | View, upload artifacts | ❌ No |

**Important:** Roles are for team management UI only. No role can affect what a user can execute locally.

### Safety Guarantees

| Guarantee | Status |
|-----------|--------|
| No shared drafts | ✅ Enforced |
| No shared execution | ✅ Enforced |
| No shared memory | ✅ Enforced |
| No admin killswitches | ✅ Enforced |
| No cross-user control | ✅ Enforced |
| Metadata-only artifacts | ✅ Enforced |

### Subscription

Team features require a **Team tier subscription**:

| Tier | Team Features? | Price |
|------|---------------|-------|
| Free | ❌ No | Free |
| Pro | ❌ No | $X/month |
| Team | ✅ Yes | $Y/month |

### Test Plan for Teams

1. **Verify no shared drafts**: Create draft → Switch users → Verify draft not visible
2. **Verify role display-only**: Change role → Verify execution unaffected
3. **Verify artifact validation**: Upload artifact with "body" key → Should be rejected
4. **Verify subscription required**: Free user → Team features should be locked

### Claims Enforced

- CLAIM-026: "Teams share governance, not work"
- CLAIM-027: "Team roles are display only"
- CLAIM-028: "No shared execution or memory"
- CLAIM-029: "Team tier requires subscription"

---

## Usage Discipline (Phase 10F)

OperatorKit includes usage discipline features that are informational and non-punitive:

### Rate Shaping (UI-Level Only)

| Feature | Behavior | Affects Execution? |
|---------|----------|-------------------|
| **Burst Detection** | Suggests slowing down | ❌ No |
| **Cooldown Messages** | Shows wait time | ❌ No |
| **Intensity Indicator** | Shows usage level | ❌ No |

**Important:** Rate shaping provides suggestions at the UI layer. It does NOT modify `ExecutionEngine`, `ApprovalGate`, or `ModelRouter`.

### Cost Visibility

| Metric | Displayed As | Contains Pricing? |
|--------|-------------|------------------|
| **Usage Units** | Abstract units | ❌ No |
| **Intensity Level** | Low/Normal/Elevated/Heavy | ❌ No |
| **Daily/Weekly Totals** | Unit counts | ❌ No |

Cost visibility shows approximate usage without actual pricing information.

### Abuse Detection (Metadata-Only)

| Method | Inspects Content? | Stores Content? |
|--------|------------------|-----------------|
| **Intent Hashing** | ❌ No (SHA256 hash) | ❌ No |
| **Timing Patterns** | ❌ No | ❌ No |
| **Count Tracking** | ❌ No | ❌ No |

Abuse detection uses one-way hashes and timing patterns. **Content is never inspected or stored.**

### User Messaging Principles

| Principle | Status |
|-----------|--------|
| Non-punitive language | ✅ Enforced |
| No moralizing | ✅ Enforced |
| No threats | ✅ Enforced |
| Factual and helpful | ✅ Enforced |

All user-facing messages are reviewed for tone and helpfulness.

### Never Features (Structurally Impossible)

| Feature | Available in Any Tier? |
|---------|----------------------|
| Shared execution | ❌ Never |
| Cross-user approval | ❌ Never |
| Remote killswitch | ❌ Never |
| Admin execution control | ❌ Never |

These features are architecturally impossible in OperatorKit.

### Test Plan for Usage Discipline

1. **Verify rate shaping is UI-only**: Trigger rate shaping → Verify execution still proceeds
2. **Verify hash-based detection**: Submit same intent multiple times → Verify content not stored
3. **Verify cost units**: Check cost display → Verify no currency symbols
4. **Verify messages**: Review all messages → Verify non-punitive tone

### Claims Enforced

- CLAIM-030: "Rate shaping is UI-level only"
- CLAIM-031: "Abuse detection is metadata-only"
- CLAIM-032: "Cost indicators are informational only"
- CLAIM-033: "Usage messages are non-punitive"
- CLAIM-034: "No cross-user execution paths"

---

## Monetization Enforcement (Phase 10G)

OperatorKit enforces subscription quotas at UI boundaries only, preserving all safety guarantees.

### Tier Comparison

| Feature | Free | Pro | Team |
|---------|------|-----|------|
| **Weekly Executions** | 25 | Unlimited | Unlimited |
| **Memory Items** | 10 | Unlimited | Unlimited |
| **Cloud Sync** | ❌ | ✅ | ✅ |
| **Team Features** | ❌ | ❌ | ✅ |
| **Local Execution** | ✅ | ✅ | ✅ |
| **Approval Required** | ✅ | ✅ | ✅ |
| **Privacy Guarantees** | ✅ | ✅ | ✅ |

### Enforcement Location

| Component | Monetization Check? |
|-----------|-------------------|
| **IntentInputView** | ✅ Before processing |
| **Memory Save UI** | ✅ Before saving |
| **ExecutionEngine** | ❌ Never |
| **ApprovalGate** | ❌ Never |
| **ModelRouter** | ❌ Never |

**Important:** Monetization enforcement happens ONLY at UI boundaries. Core execution modules have no monetization imports.

### Paywall Behavior

| Scenario | Behavior |
|----------|----------|
| Quota exceeded | Shows paywall sheet |
| Approaching limit | Shows warning, allows action |
| Under limit | Allows action silently |
| Viewing existing content | Always allowed |

The paywall always:
- Shows clear message about what limit was reached
- Offers "Upgrade" button
- Offers "Restore Purchases" button
- Allows "Continue with Free (Read Only)" where appropriate

### Data Handling

| Data Type | Storage Location |
|-----------|-----------------|
| Usage counters | Local only |
| Quota timestamps | Local only |
| Payment info | Apple (never OperatorKit) |
| Content | Never stored by monetization |

### Why We Charge

> OperatorKit runs entirely on your device. There are no ads, no tracking, and no data collection. Your subscription supports ongoing development.

### Test Plan for Monetization

1. **Free tier blocking**: Exceed quota → Verify paywall shows
2. **Pro tier bypass**: Subscribe to Pro → Verify unlimited access
3. **Restore purchases**: Sign out/in → Verify restore works
4. **Existing content access**: Exceed quota → Verify can still view drafts

### Claims Enforced

- CLAIM-035: "Monetization enforcement is UI-only"
- CLAIM-036: "Paywall shows, never silent block"
- CLAIM-037: "Free tier is functional"
- CLAIM-038: "No data leaves device for monetization"

---

## Commercial Readiness (Phase 10H)

OperatorKit is designed for Day One commercial sale with transparent pricing and no tracking.

### Pricing Screen

| Element | Location |
|---------|----------|
| Plan cards | Free / Pro / Team comparison |
| Feature bullets | What you get per tier |
| Privacy promise | No ads, no tracking, on-device |
| Subscription disclosure | Required Apple text |
| Restore purchases | Always visible |
| Manage subscription | Links to App Store |

### Conversion Tracking

| What We Track | What We Don't Track |
|---------------|---------------------|
| Event counts (local) | User identifiers |
| Timestamps (local) | Receipt data |
| Conversion rates | User content |
| | Server-side analytics |

**Important:** All conversion data is stored locally in UserDefaults. No analytics SDKs are used.

### Pricing Copy Principles

| Principle | Example |
|-----------|---------|
| **Factual** | "25 executions per week" not "generous limit" |
| **No hype** | "Unlimited" not "unlimited power" |
| **No AI anthropomorphism** | "processes requests" not "AI decides" |
| **No security claims** | Unless cryptographically proven |

### Required Disclosures

The following Apple-required disclosures are included:

1. **Auto-renewal terms** in paywall footer
2. **Cancellation instructions** (24 hours before renewal)
3. **Manage subscription link** (opens App Store)
4. **Restore purchases button** (always visible)
5. **Terms of Service** link
6. **Privacy Policy** link

### Test Plan for Commercial

1. **Pricing screen accessible**: Settings → Pricing
2. **All tiers displayed**: Free, Pro, Team with accurate features
3. **Purchase flow works**: Select product → Apple payment → Success
4. **Restore works**: Sign out → Sign in → Restore → Access restored
5. **Paywall dismissable**: "Not Now" always available

### Claims Enforced

- CLAIM-039: "No tracking analytics"
- CLAIM-040: "Local-only conversion counters"
- CLAIM-041: "App Store-safe pricing copy"

---

## Onboarding & Support (Phase 10I)

### First-Run Onboarding

OperatorKit includes a first-run onboarding flow that explains the safety model.

| Screen | Content |
|--------|---------|
| 1. What It Does | Feature bullets (email, calendar, reminders) |
| 2. Safety Model | Draft-first, approval required, no autonomous actions |
| 3. Data Access | Permission truth table (requested only when needed) |
| 4. Choose Plan | Free/Pro/Team comparison with link to pricing |
| 5. Quick Start | Sample requests (static, not personalized) |

**User Controls:**
- Skip button always available
- Can re-run from Settings
- No forced purchases
- Sample intents are illustrative, not synthetic user data

### Help Center

| Feature | Behavior |
|---------|----------|
| FAQ | Static answers to common questions |
| Troubleshooting | Step-by-step guides for permissions, Siri, restore |
| Contact Support | Opens Mail composer, does NOT auto-send |
| Refund Instructions | Links to Apple's Report a Problem page |

**Important:** Contact Support uses `MFMailComposeViewController` which requires the user to manually tap Send. No automatic emails are sent.

### Onboarding State Storage

| What We Store | What We Don't Store |
|---------------|---------------------|
| Completion flag | User preferences |
| Completion timestamp | User content |
| Schema version | Identifiers |

### Claims Enforced

- CLAIM-042: "User-initiated support contact"
- CLAIM-043: "Onboarding contains no user content"
- CLAIM-044: "Document integrity maintained"

---

## Submission Packet Export (Phase 10J)

OperatorKit includes a developer tool for generating App Store submission assets.

### Submission Packet Contents

| Section | Data Type | User Content? |
|---------|-----------|---------------|
| App metadata | Version, build, mode | No |
| Safety contract | Hash, status, counts | No |
| Doc integrity | Counts, missing list | No |
| Claim registry | Claim IDs only | No |
| Monetization | Tier names, flags | No |
| Policy summary | Flags only | No |

### Forbidden Keys

The following keys are **never** included in exports:

- body, subject, content, draft
- prompt, context, note, email
- attendees, title, description
- message, text, recipient, sender

### Copy Templates

| Template | Purpose | Validated? |
|----------|---------|------------|
| Review Notes | Notes for App Review | ✅ Banned words checked |
| What's New | Release notes | ✅ Banned words checked |
| Privacy Disclosure | Privacy explanation | ✅ Banned words checked |
| Monetization Disclosure | Subscription explanation | ✅ Banned words checked |

### Screenshot Checklist

| Shot | Caption Template |
|------|------------------|
| Onboarding | "Your on-device productivity assistant" |
| Intent Input | "Type any request in plain language" |
| Draft Review | "Review every action before it runs" |
| Approval | "You're always in control" |
| Memory | "Remember your preferences" |
| Quality & Trust | "Verify what runs on your device" |
| Pricing | "Start free, upgrade anytime" |
| Help Center | "Help when you need it" |

All captions are validated to contain no user content, email addresses, or specific names.

### Claims Enforced

- CLAIM-045: "Submission packet metadata-only"
- CLAIM-046: "Copy templates App Store safe"

---

## Risk Scanner & Store Listing Lockdown (Phase 10K)

### Review Risk Scanner

OperatorKit includes a deterministic risk scanner that checks all submission copy for App Store guideline violations.

**Detected Patterns:**

| Category | Examples | Severity |
|----------|----------|----------|
| Anthropomorphic | "AI thinks", "AI learns", "AI decides" | Fail |
| Security Claims | "secure", "encrypted" (unproven) | Fail |
| Background Implication | "monitors", "tracks", "runs in background" | Fail |
| Data Sharing | "syncs automatically", "sends your data" | Warn/Fail |
| Personalization | "learns your", "personalizes automatically" | Warn |

**Scanner Properties:**
- Pure function (no side effects)
- Deterministic output
- Metadata-only analysis
- Exportable risk report (JSON)

### Store Listing Lockdown

Store listing copy is hash-locked to prevent accidental drift.

| Field | Max Length | Locked? |
|-------|------------|---------|
| Title | 30 chars | ✅ Hash-locked |
| Subtitle | 30 chars | ✅ Hash-locked |
| Description | 4000 chars | ✅ Hash-locked |
| Keywords | 100 chars | ✅ Hash-locked |
| Promotional | 170 chars | ✅ Hash-locked |

**Lockdown Mechanism:**
- SHA256 hash of concatenated content
- Tests fail if copy drifts
- Update requires new hash + reason
- Change history tracked by phase

### Reviewer Quick Path

2-minute guide for App Store reviewers:

1. First Launch → Onboarding (5 screens)
2. Type a Request → "Draft an email..."
3. Review Draft → Edit/Cancel options
4. Approval Gate → Run/Edit/Cancel dialog
5. Settings → Pricing → Restore Purchases
6. Settings → Help Center → FAQ
7. Settings → Privacy → Guarantees

**What Reviewers Should NOT See:**
- No automatic email sending
- No background processing
- No network prompts on launch
- No forced paywall
- No data collection popups

---

## Local Conversion Summary (Phase 10L)

OperatorKit includes local-only conversion tracking for pricing optimization.

### What Is Tracked (Locally)

| Step | Description | Storage |
|------|-------------|---------|
| Onboarding Shown | First onboarding view | UserDefaults |
| Pricing Viewed | Pricing screen opened | UserDefaults |
| Upgrade Tapped | User tapped upgrade | UserDefaults |
| Purchase Started | Purchase flow began | UserDefaults |
| Purchase Success | Purchase completed | UserDefaults |
| Restore Tapped | Restore button tapped | UserDefaults |
| Restore Success | Restore completed | UserDefaults |

### What Is NOT Tracked

| Category | Guarantee |
|----------|-----------|
| User identifiers | ❌ Never stored |
| Device identifiers | ❌ Never stored |
| Receipt data | ❌ Never stored |
| User content | ❌ Never stored |
| Analytics SDK data | ❌ No SDKs used |

### Pricing Variants

| Variant | Focus | Stored |
|---------|-------|--------|
| A (Default) | Balanced messaging | UserDefaults |
| B | Value-focused copy | UserDefaults |
| C | Privacy-focused copy | UserDefaults |

**Important:**
- Variant selection is stored locally only
- No A/B testing service is used
- No network communication for variants
- User can manually change variant in Settings

### Export Capabilities

- Export contains aggregate counts only
- No user content in exports
- Forbidden-key validated
- User-initiated via ShareSheet

---

## Enterprise Readiness Export (Phase 10M)

OperatorKit includes an enterprise readiness export for B2B procurement.

### What Is Exported

| Section | Contents | Format |
|---------|----------|--------|
| Safety Contract | Hash + validation status | String + Bool |
| Doc Integrity | Present/missing counts | Int |
| Claim Registry | Claim IDs + counts | [String] + Int |
| Review Risk | Status + finding counts | String + Int |
| Quality | Gate status + scores | String + Int |
| Team Governance | Feature flags | Bool |

### What Is NOT Exported

| Category | Guarantee |
|----------|-----------|
| User content | ❌ Never exported |
| Raw doc text | ❌ Never exported |
| Store listing copy | ❌ Never exported |
| User identifiers | ❌ Never exported |
| Device identifiers | ❌ Never exported |

### Policy Templates

| Template | Description | Safety Guards |
|----------|-------------|---------------|
| Conservative | Most restrictive | 25/day limit, no calendar/tasks |
| Standard | Balanced | 100/day limit, explicit confirmation |
| Privacy First | Maximum privacy | Local-only processing |
| Read Only | No writes | Email drafts only |

**Important:**
- All templates require explicit confirmation
- Templates are local-only, never synced
- Apply requires user confirmation
- Does NOT affect execution engine

### Team Trial Request

- Opens mailto: with generic template
- No device/user identifiers in email
- User controls when to send
- No auto-send capability

---

## Activation Playbook (Phase 10N)

Post-purchase activation guidance to help new subscribers get value.

### What It Does

| Feature | Description | User Control |
|---------|-------------|--------------|
| First 3 Wins | Static sample intents | User chooses to try |
| Prefill | Populates intent text | User still selects context |
| Progress | Tracks completed steps | Local-only |

### What It Does NOT Do

| Restriction | Guarantee |
|-------------|-----------|
| Auto-execute | ❌ Never |
| Auto-select context | ❌ Never |
| Force completion | ❌ Always skippable |
| Store user content | ❌ Never |

### Sample Intents

Sample intents are static strings with no personalization:
- "Draft a friendly follow-up email about our meeting"
- "Remind me to review the project proposal tomorrow at 10am"
- "Schedule a team sync meeting for next Monday at 2pm"

---

## Team Trial (Phase 10N)

Process-only team trial for governance feature exploration.

### What It Does

| Feature | Description | Safety |
|---------|-------------|--------|
| 14-day trial | Local-only duration | No execution changes |
| Governance access | Policy templates, diagnostics | UI features only |
| Acknowledgement | Required before start | Terms displayed |

### What It Does NOT Do

| Restriction | Guarantee |
|-------------|-----------|
| Change execution safety | ❌ Never |
| Bypass approvals | ❌ Never |
| Enable shared drafts | ❌ Never |
| Silently change tiers | ❌ Never |

### Trial Terms

Users must acknowledge:
- This is a process-only trial
- Execution safety guarantees remain unchanged
- No shared drafts or user content
- Team features are governance-only
- Trial is local to this device

---

## Satisfaction Signal (Phase 10N)

Local-only post-purchase satisfaction tracking.

### What Is Collected

| Data | Format | Storage |
|------|--------|---------|
| 3 questions | 1-5 rating | UserDefaults |
| Aggregates | Counts + averages | Local-only |

### What Is NOT Collected

| Data | Guarantee |
|------|-----------|
| Free text | ❌ Not collected |
| Personal info | ❌ Not collected |
| User identifiers | ❌ Not collected |

### When Shown

- After Activation Playbook completion, OR
- After 3 successful executions
- Always skippable
- Foreground UI only (no background prompts)

---

## Outcome Templates (Phase 10O)

Static outcome template library for activation and retention.

### What It Does

| Feature | Description | User Control |
|---------|-------------|--------------|
| Template Library | 12+ static outcome templates | User chooses |
| Pre-fill Intent | Populates intent text | User still selects context |
| Aggregate Tracking | Counts shown/used/completed | Local-only, no identifiers |

### What It Does NOT Do

| Restriction | Guarantee |
|-------------|-----------|
| Auto-execute | ❌ Never |
| Auto-select context | ❌ Never |
| Store user content | ❌ Never |
| Track identifiers | ❌ Never |

### Template Categories

- Email: Follow-up, introduction
- Tasks: Deadline reminders, project tasks
- Calendar: Recurring meetings, focus time
- Summary: Meeting notes, weekly review
- Planning: Daily plan, project outline
- Communication: Status updates, requests

---

## Pilot Mode (Phase 10O)

Enterprise pilot evaluation framework.

### What It Does

| Feature | Description | User Control |
|---------|-------------|--------------|
| 7-Day Checklist | Static evaluation steps | Read-only |
| Export Links | Access to all export artifacts | User-initiated |
| Email Templates | Pilot kickoff, security review | User sends via mail app |

### What It Does NOT Do

| Restriction | Guarantee |
|-------------|-----------|
| Change execution | ❌ Never |
| Auto-send emails | ❌ Never |
| Track progress server-side | ❌ Never |
| Require purchase | ❌ Never |

### Pilot Checklist

| Day | Task |
|-----|------|
| 1 | Setup & Review |
| 2 | Basic Workflows |
| 3 | Context Testing |
| 4 | Team Scenarios |
| 5 | Quality Review |
| 6 | Export & Document |
| 7 | Stakeholder Report |

---

## Pilot Share Pack (Phase 10O)

Single metadata-only export artifact aggregating all pilot artifacts.

### What Is Included

| Section | Data | Content |
|---------|------|---------|
| Enterprise Readiness | Summary | Status, score, flags |
| Quality | Summary | Gate status, coverage |
| Diagnostics | Summary | Counts, rates |
| Policy | Summary | Capability flags |
| Team | Summary | Tier, trial status |
| Conversion | Summary | Variant, purchase count |

### What Is NOT Included

| Data | Guarantee |
|------|-----------|
| User content | ❌ Never |
| Device identifiers | ❌ Never |
| User identifiers | ❌ Never |
| Raw documents | ❌ Never |

### Soft-Fail Behavior

The pack builder tracks which sections were available vs unavailable. Export succeeds even if some sections cannot be built. This ensures enterprises can always get a pilot artifact regardless of app state.

---

## Audit Trail (Phase 10P)

Zero-content audit trail for customer proof and reproducibility.

### What Is Stored

| Field | Type | Example |
|-------|------|---------|
| Event ID | UUID | Auto-generated |
| Created At | Day-rounded | "2026-01-26" |
| Kind | Enum | execution_succeeded |
| Intent Type | String | "email_draft" |
| Output Type | String | "draft" |
| Result | Enum | success/failure |
| Failure Category | Enum (optional) | timeout |
| Backend Used | String | "apple_on_device" |
| Policy Decision | Enum (optional) | allowed |
| Tier At Time | String | "pro" |

### What Is NOT Stored

| Data | Guarantee |
|------|-----------|
| Draft content | ❌ Never |
| Email bodies/subjects | ❌ Never |
| Event titles/attendees | ❌ Never |
| Prompt text | ❌ Never |
| Raw timestamps | ❌ Never (day-rounded only) |
| Free-text notes | ❌ Never |

### Ring Buffer

- Maximum 500 events
- Oldest events automatically removed
- User can purge all events

---

## Customer Proof Dashboard (Phase 10P)

Customer-facing trust proof dashboard.

### Sections Displayed

| Section | Content | Interactive |
|---------|---------|-------------|
| Safety Contract | Hash match status | Read-only |
| Quality Gate | Status + coverage | Read-only |
| Policy Summary | Capability flags | Read-only |
| Audit Trail | Counts + last 7 days | Read-only |
| Export | Repro Bundle button | User-initiated |
| Data Management | Purge controls | User-initiated |

### What It Does NOT Do

| Restriction | Guarantee |
|-------------|-----------|
| Change behavior | ❌ Never |
| Background monitoring | ❌ Never |
| Auto-export | ❌ Never |
| Display user content | ❌ Never |

---

## Repro Bundle Export (Phase 10P)

Single artifact containing all diagnostic/quality/audit data.

### What Is Included

| Section | Content |
|---------|---------|
| `diagnosticsSummary` | Execution counts, rates |
| `qualitySummary` | Gate status, coverage |
| `policySummary` | Capability flags |
| `pilotSummary` | Trial/tier status |
| `auditTrailSummary` | Counts + recent 20 events |

### What Is NOT Included

| Data | Guarantee |
|------|-----------|
| User content | ❌ Never |
| Draft text | ❌ Never |
| Prompt text | ❌ Never |
| Raw timestamps | ❌ Never |

### Soft-Fail Behavior

The builder tracks which sections were available vs unavailable. Export succeeds even if some sections cannot be built.

---

## First Week Guidance (Phase 10Q)

Lightweight, UI-only helper for first-week users.

### What It Does

| Feature | Description | User Control |
|---------|-------------|--------------|
| First Week Detection | Tracks days since install | Read-only |
| Gentle Tips | Shows helpful guidance | Dismissible |
| Core Principles | Explains draft-first workflow | Read-only |

### What It Does NOT Do

| Restriction | Guarantee |
|-------------|-----------|
| Block execution | ❌ Never |
| Restrict features | ❌ Never |
| Track behavior | ❌ Never |
| Send analytics | ❌ Never |

---

## Known Limitations (Phase 10Q)

Static, explicit list of what OperatorKit does NOT do.

### Categories Covered

| Category | Examples |
|----------|----------|
| Execution | No background execution, no scheduled actions |
| Automation | No inbox monitoring, no auto-reply |
| Data | No cloud storage, no learning, no analytics |
| Networking | No silent network requests |
| Permissions | Explicit context selection required |

### Language Guarantees

- Factual statements only
- No excuses or apologies
- No roadmap promises
- No AI anthropomorphism

---

## Support Packet (Phase 10Q)

Metadata-only export for support escalation.

### What Is Included

| Data | Content |
|------|---------|
| App Info | Version, build, release mode |
| Account State | Tier, trial status, first week |
| Policy State | Capability flags |
| Quality State | Gate status, coverage |
| Audit Summary | Event counts only |
| Diagnostics Summary | Execution counts only |

### What Is NOT Included

| Data | Guarantee |
|------|-----------|
| User content | ❌ Never |
| Draft text | ❌ Never |
| Email bodies | ❌ Never |
| Raw errors | ❌ Never |

---

## Safe Reset Controls (Phase 10Q)

User-initiated reset actions with confirmation.

### Available Resets

| Action | Description | Confirmation |
|--------|-------------|--------------|
| Clear Audit Trail | Removes audit events | Required |
| Clear Diagnostics | Clears snapshots | Required |
| Reset Onboarding | Shows onboarding again | Required |
| Reset First Week | Resets guidance state | Required |
| Clear Counters | Clears monetization counters | Required |

### Safety Guarantees

- No effect on execution safety
- No data leaves device
- No background effects
- Confirmation always required

---

## Launch Checklist (Phase 10Q)

Advisory validator for launch readiness.

### Check Categories

| Category | Checks |
|----------|--------|
| Documentation | Required docs present |
| Safety | Contract valid, copy validated |
| Quality | Gate status, coverage |
| Store Listing | Hash locked |
| Submission | Risk scanner status |

### Important Notes

- Advisory only
- Does NOT block app usage
- Used for internal readiness
- Export via ShareSheet only

---

## Referral System (Phase 11A)

Local-only referral code system for user acquisition.

### What Is Stored

| Data | Storage | Content |
|------|---------|---------|
| Referral Code | Local | Format: OK-XXXX-XXXX |
| Share Count | Local | Number only |
| Copy Count | Local | Number only |
| Invite Opens | Local | Number only |

### What Is NOT Stored

| Data | Guarantee |
|------|-----------|
| User identity | ❌ Never |
| Recipient info | ❌ Never |
| Message content | ❌ Never |
| Email addresses | ❌ Never |

### How It Works

1. Code is generated locally (not tied to identity)
2. User shares via Copy/Share/Mail/Message
3. Counts are tracked locally only
4. No server validation required

---

## Buyer Proof Packet (Phase 11A)

Single exportable artifact for procurement trust verification.

### What Is Included

| Section | Content |
|---------|---------|
| Safety Contract | Hash match status |
| Claim Registry | IDs only |
| Quality Gate | Status + coverage |
| Diagnostics | Counts only |
| Policy | Capability flags |
| Team Readiness | Tier/trial status |
| Launch Checklist | Pass/warn/fail counts |

### What Is NOT Included

| Data | Guarantee |
|------|-----------|
| User content | ❌ Never |
| Draft text | ❌ Never |
| Personal info | ❌ Never |

### Soft-Fail Behavior

Missing sections are marked unavailable. Export always succeeds.

---

## Outbound Templates (Phase 11A)

Static email templates for sales outreach.

### Template Categories

| Category | Purpose |
|----------|---------|
| Pilot | Propose pilot evaluations |
| Procurement | Introduce to procurement |
| Security | Provide security info |
| Pricing | Share pricing details |
| Follow-up | Post-demo communication |

### Safety Guarantees

| Check | Status |
|-------|--------|
| No auto-send | ✅ User initiates |
| Placeholder-based | ✅ No pre-filled data |
| No banned words | ✅ Validated |
| No promises | ✅ Validated |
| No injected emails | ✅ Validated |

---

## Pricing Package Registry (Phase 11B, Updated 11C)

Single source of truth for pricing packages with App Store-safe copy.

### Tiers (Phase 11C Update)

| Tier | Pricing | Limit | What's Included |
|------|---------|-------|-----------------|
| Free | $0 | 25 Drafted Outcomes / week | Draft generation, approval flow, on-device processing |
| Pro | $19/mo, $149/yr | Unlimited | Everything in Free + unlimited outcomes, optional sync |
| Lifetime Sovereign | $249 one-time | Unlimited | All Pro features, no subscription |
| Team | $49/user/mo (min 3 seats) | Unlimited | Everything in Pro + procedure sharing, monthly audit export |

### Phase 11C Key Updates

| Update | Description |
|--------|-------------|
| "Drafted Outcomes" | Free tier uses "25 Drafted Outcomes / week" (not "executions") |
| Lifetime Sovereign | One-time $249 purchase option for Pro features |
| Team Minimum Seats | Team requires minimum 3 seats |
| Procedure Sharing | Team shares procedures/templates, NOT user drafts or data |
| Monthly Audit Export | Team tier includes monthly audit export (copy only) |

### Copy Safety

| Check | Status |
|-------|--------|
| No banned words | ✅ Validated |
| No anthropomorphic AI | ✅ Validated |
| No security claims | ✅ Validated |
| StoreKit disclosures | ✅ Present |
| Drafted Outcomes language | ✅ Validated (11C) |
| Team min seats = 3 | ✅ Validated (11C) |
| Lifetime price consistent | ✅ Validated (11C) |

---

## Sales Playbook (Phase 11B)

In-app founder sales playbook. Read-only, generic, factual.

### Sections

| Section | Content |
|---------|---------|
| Who It's For | Target user personas |
| Demo Script | 2-minute walkthrough |
| Outbound Motions | 3 sales motions |
| Objection Handling | 5 common objections |
| Close Paths | Pro vs Team paths |
| What to Export | Trust artifacts |

### Copy Safety

| Check | Status |
|-------|--------|
| No promises | ✅ Validated |
| No banned words | ✅ Validated |
| Factual only | ✅ Confirmed |

---

## Pipeline Tracker (Phase 11B)

Zero-content local pipeline tracking.

### What Is Stored

| Data | Storage | Content |
|------|---------|---------|
| Item ID | Local | UUID only |
| Stage | Local | Enum only |
| Channel | Local | Enum only |
| Created Date | Local | Day-rounded |
| Updated Date | Local | Day-rounded |

### What Is NOT Stored

| Data | Guarantee |
|------|-----------|
| Company name | ❌ Never |
| Person name | ❌ Never |
| Email | ❌ Never |
| Phone | ❌ Never |
| Notes | ❌ Never |
| Domain | ❌ Never |
| Free text | ❌ Never |

### Data Retention

- 90-day automatic purge
- User-initiated purge available
- Export is counts-only

---

## Sales Kit Export (Phase 11B)

Single exportable artifact combining all sales metadata.

### Included Sections

| Section | Content |
|---------|---------|
| Pricing Snapshot | Tier counts only |
| Pricing Validation | Status + findings |
| Playbook Metadata | Section IDs only |
| Pipeline Summary | Counts only |
| Buyer Proof Status | Available/unavailable counts |
| Enterprise Readiness | Status flags |

### Safety Guarantees

| Check | Status |
|-------|--------|
| No forbidden keys | ✅ Validated |
| Soft-fail sections | ✅ Implemented |
| Round-trip encode | ✅ Tested |
| User-initiated only | ✅ ShareSheet |

---

## Adversarial Review Readiness (Phase 12A)

OperatorKit has undergone formal adversarial review simulation to proactively identify and address potential rejection vectors.

### Simulation Completed

| Adversary Profile | Simulation Status | Outcome |
|-------------------|-------------------|---------|
| Apple App Store Review | ✅ Completed | All 8 rejection vectors refuted |
| Enterprise Security Audit | ✅ Completed | All 8 audit questions answered |
| Competitive Skeptic Review | ✅ Completed | All 5 skeptic claims addressed |

### Documentation Reference

Full adversarial review dossier: `docs/ADVERSARIAL_REVIEW.md`

### Key Findings

- **21 potential rejection/audit claims** were simulated
- **21 of 21** were refuted using existing artifacts
- **0 behavior changes** were required
- **0 new code** was added to address concerns

### Artifacts Used for Defense

| Artifact | Purpose |
|----------|---------|
| `SAFETY_CONTRACT.md` | Guarantee definitions and enforcement locations |
| `CLAIM_REGISTRY.md` | Traceable claims with code/test references |
| `EnterpriseReadinessPacket` | Exportable enterprise audit evidence |
| `BuyerProofPacket` | Exportable procurement trust verification |
| `AppReviewRiskScanner.swift` | Self-audit for misleading language |
| 12 Invariant Test Suites | Automated constraint enforcement |

### Residual Risks Acknowledged

5 non-fatal risks documented transparently in `ADVERSARIAL_REVIEW.md`:
1. Apple Foundation Models availability (fallback available)
2. StoreKit edge cases (restore path documented)
3. Team governance complexity (small team scope)
4. Export packet size growth (under 100KB, soft-fail)
5. Regulatory uncertainty (human-in-loop compliant)

---

## Contact for Review Questions

If you have questions during review, please contact us through App Store Connect. We will respond promptly with any clarification or demonstration needed.

---

*Prepared for Apple App Review — Phase 12A*
