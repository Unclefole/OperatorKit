# Reviewer Simulation Checklist

This document simulates an Apple App Review session for OperatorKit. It is intended for:

- Internal QA before submission
- Future maintainers understanding the review process
- Anticipating and addressing reviewer concerns

**This document is NOT shown in-app. It is for internal confidence.**

---

## Pre-Review Setup

### Device Requirements
- iPhone running iOS 17.0 or later
- Calendar app with at least 2 events in the next 7 days
- Reminders app configured
- Mail app configured with an account
- Siri enabled

### App State
- Fresh install (no previous data)
- Or: Reset app via Settings > OperatorKit > Reset

---

## Test Session A: First Launch Flow

### Step 1: App Launch
**Action:** Open OperatorKit for the first time

**Expected UI:**
- Onboarding screen appears
- Clean, professional design
- No immediate permission prompts
- "Get Started" button visible

**What Reviewer Might Look For:**
- Privacy policy mention
- Data handling explanation
- No aggressive onboarding

**Clarification:**
OperatorKit shows a privacy-focused onboarding that explains data stays on-device before asking for any permissions.

---

### Step 2: Home Screen
**Action:** Complete onboarding, reach home screen

**Expected UI:**
- Input card prompting "What would you like to do?"
- Recent operations section (empty on first launch)
- Settings/Privacy gear icon
- No automatic data access

**What Reviewer Might Look For:**
- Is the app doing anything in the background?
- Are there network indicators?
- Is data being loaded without permission?

**Clarification:**
At this point, OperatorKit has not accessed any user data. The home screen is static until the user initiates an action.

---

## Test Session B: Siri Route

### Step 3: Siri Invocation
**Action:** Say "Hey Siri, ask OperatorKit to draft an email about the project"

**Expected UI:**
- Siri acknowledges and opens OperatorKit
- Intent Input screen appears with text pre-filled
- Yellow/orange banner: "Siri Started This Request"
- Checkbox: "I've reviewed this request"
- Continue button disabled until checkbox is tapped

**What Reviewer Might Look For:**
- Did Siri execute any action?
- Was data accessed automatically?
- Can the user proceed without acknowledging?

**Clarification:**
Siri ONLY opens the app and pre-fills text. No data was accessed. No action was taken. The user must explicitly acknowledge the Siri-originated request before continuing.

---

### Step 4: Siri Acknowledgment
**Action:** Tap the acknowledgment checkbox, then tap Continue

**Expected UI:**
- Context Picker screen appears
- Calendar permission prompt (if not previously granted)
- No data loaded yet (if permission not granted)

**What Reviewer Might Look For:**
- Was the permission prompt expected?
- Is the explanation clear?
- Can the user skip this?

**Clarification:**
The permission prompt only appears when the user navigates to Context Picker. It is not shown at app launch or triggered by Siri.

---

## Test Session C: Calendar Access

### Step 5: Grant Calendar Permission
**Action:** Tap "Allow" on the calendar permission prompt

**Expected UI:**
- Calendar events from ±7 days appear
- Events show title, time, location
- Each event has a selection checkbox
- "Continue" button shows count of selected items

**What Reviewer Might Look For:**
- How many events are loaded?
- Is all calendar data being read?
- Can the user see what's being accessed?

**Clarification:**
OperatorKit loads a maximum of 50 events from 7 days before to 7 days after today. Only event metadata (title, time, participants, location) is read—not notes or attachments. Events are displayed for user selection; nothing is accessed until the user explicitly selects items.

---

### Step 6: Select Events
**Action:** Tap to select 2 calendar events, then tap Continue

**Expected UI:**
- Plan Preview screen appears
- Selected events shown in context summary
- Execution plan with numbered steps
- "Generate Draft" button

**What Reviewer Might Look For:**
- Did only the selected events carry forward?
- Is it clear what data is being used?

**Clarification:**
Only the 2 explicitly selected events are included in the context. Other events were displayed for selection but are not used.

---

## Test Session D: Draft Generation

### Step 7: Generate Draft
**Action:** Tap "Generate Draft"

**Expected UI:**
- Loading indicator briefly
- Draft Output screen appears
- Confidence badge (e.g., "High confidence")
- Draft content in a card
- Safety notes section
- Citations showing source events

**What Reviewer Might Look For:**
- Where did this content come from?
- Is it clear this is AI-generated?
- Are there safety warnings?

**Clarification:**
The draft was generated entirely on-device using the selected calendar events as context. The citations section shows exactly which events were used. Safety notes always include "You must review before sending."

---

## Test Session E: Approval Flow

### Step 8: Continue to Approval
**Action:** Tap "Continue to Approval"

**Expected UI:**
- Approval screen appears
- Warning banner: "Review Before Continuing"
- Draft preview card
- Side effects section showing what will happen
- Each side effect has an acknowledgment toggle
- "Approve & Execute" button (disabled until all acknowledged)

**What Reviewer Might Look For:**
- Can the user execute without reviewing?
- Are all actions clearly disclosed?
- Is there a way to bypass approval?

**Clarification:**
The Approve button is disabled until every enabled side effect is acknowledged. There is no way to execute without explicit approval.

---

### Step 9: Acknowledge Side Effects
**Action:** Tap to acknowledge each side effect toggle

**Expected UI:**
- Each toggle shows a checkmark when acknowledged
- "Approve & Execute" button becomes enabled
- Button may show "Continue to Confirm" if a write is enabled

**What Reviewer Might Look For:**
- Is it clear what each action does?
- Is "Open Email Composer (you send manually)" honest?

**Clarification:**
The side effect descriptions are accurate. "Open Email Composer" means exactly that—OperatorKit opens the Mail composer but cannot send the email.

---

## Test Session F: Two-Key Confirmation (Reminder)

### Step 10: Enable Reminder Write
**Action:** Enable "Create Reminder" option, acknowledge it, tap "Continue to Confirm"

**Expected UI:**
- Confirmation modal appears
- Shows exact reminder details: title, notes, due date, list
- "Safety Guarantees" section explaining what OperatorKit will/won't do
- "Cancel" and "Confirm Create" buttons
- 60-second timer (optional display)

**What Reviewer Might Look For:**
- Is this a genuine second confirmation?
- Can the user see exactly what will be created?
- Can this be bypassed?

**Clarification:**
This is a mandatory second confirmation for write operations. The user sees the exact reminder details before confirming. There is no way to create a reminder without this step.

---

### Step 11: Confirm Reminder Creation
**Action:** Tap "Confirm Create"

**Expected UI:**
- Execution Progress screen
- Checkmarks appear as steps complete
- "Reminder created" confirmation
- Execution Complete screen

**What Reviewer Might Look For:**
- Did it actually create a reminder?
- Can this be verified?

**Clarification:**
Open the Reminders app to verify the reminder was created with the exact details shown in the confirmation modal.

---

## Test Session G: Email Draft

### Step 12: Open Email Composer
**Action:** On Execution Complete screen, tap "Open Email Composer"

**Expected UI:**
- System Mail composer opens
- Subject pre-filled
- Body pre-filled with draft content
- Send button visible (in Mail app, not OperatorKit)

**What Reviewer Might Look For:**
- Did OperatorKit send the email?
- Can OperatorKit send without user action?

**Clarification:**
OperatorKit opened the composer. The email is NOT sent. The user must tap Send in the Mail app to send. OperatorKit cannot send emails.

---

### Step 13: Cancel Email
**Action:** Tap Cancel in Mail composer, return to OperatorKit

**Expected UI:**
- Back in Execution Complete screen
- Option to "View in Memory"

---

## Test Session H: Memory Audit

### Step 14: View Memory
**Action:** Tap "View in Memory" or navigate to Memory tab

**Expected UI:**
- Memory list shows the completed operation
- Tap to view details
- Trust Summary at top: draft-first ✓, user approved ✓, etc.
- Full audit trail: timestamps, model used, confidence, citations

**What Reviewer Might Look For:**
- Is the history accurate?
- Can this be edited?
- Is sensitive data exposed?

**Clarification:**
The audit trail is immutable after save. It shows what happened, when, and what data was used. It cannot be modified retroactively.

---

## Test Session I: Privacy Controls

### Step 15: Review Privacy Controls
**Action:** Navigate to Privacy Controls (gear icon)

**Expected UI:**
- Permission status for Calendar, Reminders, Mail
- Data Usage section explaining no cloud upload, no tracking
- "Full Data Use Disclosure" link
- "Reviewer Help" link

**What Reviewer Might Look For:**
- Do the explanations match actual behavior?
- Are permissions accurately reflected?

**Clarification:**
All permission states are read from the system and displayed accurately. The explanations match the actual app behavior.

---

## What NOT to Look For

The following behaviors do NOT exist in OperatorKit:

| Behavior | Status |
|----------|--------|
| Background sync | Does not exist |
| Push notifications | Not implemented |
| Network requests | Not possible (no entitlement) |
| Automatic email sending | Architecturally impossible |
| Background calendar reads | Does not exist |
| Autonomous actions | Blocked by approval gate |
| Data upload | No network capability |
| Analytics collection | Not present |
| Crash reporting to servers | Not implemented |
| Advertising | Not present |

---

## Common Misinterpretations

### "The app has Siri integration—does it execute via Siri?"
**No.** Siri opens the app and pre-fills text. All execution requires in-app approval.

### "The app can create reminders—can it do so automatically?"
**No.** Reminders require: user approval + second confirmation. Both are explicit taps.

### "The app reads calendar—does it sync or upload?"
**No.** Calendar data is read locally, displayed for selection, and never transmitted.

### "The app generates text—is this cloud AI?"
**No.** All generation is on-device using Apple frameworks or deterministic templates.

### "The app has a memory feature—is this learning about the user?"
**No.** Memory is a local audit trail of user actions. It is not used for training or personalization.

---

## Checklist Summary

| Test | Expected Result | Verified |
|------|-----------------|----------|
| Siri route opens app without executing | ✓ | [ ] |
| Calendar permission requested only when needed | ✓ | [ ] |
| Only selected events used as context | ✓ | [ ] |
| Draft generation is on-device | ✓ | [ ] |
| Approval required before execution | ✓ | [ ] |
| Reminder write requires two-key confirmation | ✓ | [ ] |
| Email composer opens (user must send) | ✓ | [ ] |
| Memory shows accurate audit trail | ✓ | [ ] |
| No background activity visible | ✓ | [ ] |
| No network indicators | ✓ | [ ] |

---

*Internal document for QA and future maintainers — Phase 7A*
