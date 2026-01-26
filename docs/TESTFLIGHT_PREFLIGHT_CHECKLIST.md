# TestFlight Preflight Checklist

This checklist must be completed before every TestFlight build submission. It ensures the build is safe, functional, and won't confuse testers or trigger App Review concerns.

---

## Pre-Build Verification

### 1. Code Freeze Verification
- [ ] All feature work for this build is merged
- [ ] No work-in-progress branches contain DEBUG-only code that might leak
- [ ] Version number incremented in Xcode project settings
- [ ] Build number incremented

### 2. Configuration Check
- [ ] Scheme set to **Release** (not Debug)
- [ ] `#if DEBUG` blocks verified to exclude:
  - [ ] Synthetic demo data
  - [ ] Fault injection backend
  - [ ] Eval harness UI
  - [ ] Verbose console logging
- [ ] `ReleaseMode.current` returns `.testFlight` in TestFlight builds

### 3. Privacy Compliance
- [ ] Info.plist privacy strings match `PrivacyStrings.swift` exactly
- [ ] No unexpected permission keys added
- [ ] `UIBackgroundModes` remains absent
- [ ] App Tracking Transparency NOT required (no tracking)

---

## Build Validation

### 4. Clean Build
```bash
# From project root
xcodebuild clean
xcodebuild -scheme OperatorKit -configuration Release -destination 'generic/platform=iOS'
```
- [ ] Build succeeds with zero errors
- [ ] Build succeeds with zero warnings (or only expected warnings)

### 5. Archive Validation
- [ ] Archive created successfully in Xcode Organizer
- [ ] "Validate App" passes in Organizer
- [ ] No missing entitlements errors
- [ ] No provisioning profile issues

### 6. Automated Tests
```bash
xcodebuild test -scheme OperatorKit -destination 'platform=iOS Simulator,name=iPhone 15'
```
- [ ] All unit tests pass
- [ ] `InfoPlistRegressionTests` pass
- [ ] `InvariantTests` pass
- [ ] No test failures related to DEBUG-only code

---

## Functional Validation (Manual)

### 7. Critical Path Test
Perform on a physical device with the TestFlight build:

| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Launch app | Onboarding appears | [ ] |
| 2 | Complete onboarding | Home screen appears | [ ] |
| 3 | Enter "Draft an email about my meeting" | Text accepted | [ ] |
| 4 | Tap Continue | Context Picker appears | [ ] |
| 5 | Grant calendar permission | Events displayed | [ ] |
| 6 | Select 1 event, tap Continue | Plan Preview appears | [ ] |
| 7 | Tap "Generate Draft" | Draft Output appears | [ ] |
| 8 | Tap "Continue to Approval" | Approval screen appears | [ ] |
| 9 | Acknowledge side effects | Approve button enabled | [ ] |
| 10 | Tap "Approve & Execute" | Execution completes | [ ] |
| 11 | Tap "Open Email Composer" | Mail app opens | [ ] |
| 12 | Cancel email, return to app | App still functional | [ ] |
| 13 | Navigate to Memory | Execution recorded | [ ] |

### 8. Siri Route Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | "Hey Siri, ask OperatorKit to draft an email" | App opens | [ ] |
| 2 | Verify banner | "Siri Started This Request" visible | [ ] |
| 3 | Verify checkbox | Must acknowledge before Continue | [ ] |
| 4 | Complete flow | Normal approval required | [ ] |

### 9. Two-Key Confirmation Test (Reminder)
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Enable "Create Reminder" in Approval | Toggle enabled | [ ] |
| 2 | Tap "Continue to Confirm" | Confirmation modal appears | [ ] |
| 3 | Verify details shown | Title, notes, due date visible | [ ] |
| 4 | Tap "Confirm Create" | Reminder created | [ ] |
| 5 | Open Reminders app | Reminder exists with correct details | [ ] |

### 10. Permission Denial Test
| Step | Action | Expected Result | ✓ |
|------|--------|-----------------|---|
| 1 | Deny calendar permission | "Calendar access is currently off" shown | [ ] |
| 2 | Tap "Open Settings" | Settings app opens | [ ] |
| 3 | Return to app | Permission state refreshed | [ ] |

---

## TestFlight-Specific Checks

### 11. TestFlight Metadata
- [ ] "What to Test" section written (see template below)
- [ ] Beta App Description updated if needed
- [ ] Contact information current
- [ ] Beta App Review Information complete (if first build)

### 12. Tester Communication
- [ ] Release notes written for this build
- [ ] Known issues documented (if any)
- [ ] Test instructions clear for non-technical testers

---

## "What to Test" Template

Copy this into TestFlight's "What to Test" field:

```
OperatorKit [VERSION] - What to Test

CRITICAL FLOWS:
1. Complete an email draft flow (Home → Intent → Context → Plan → Draft → Approval → Execute)
2. Test Siri: "Hey Siri, ask OperatorKit to draft an email"
3. Create a reminder (requires two confirmations)
4. Verify Memory shows your completed actions

PRIVACY VERIFICATION:
- Calendar permission is only requested when you open Context Picker
- No background activity should occur
- All processing is on-device

KNOWN LIMITATIONS:
- Apple on-device model requires iOS 18.1+ and compatible hardware
- Fallback to template-based generation is expected on most devices

PLEASE REPORT:
- Any unexpected permission prompts
- Any crashes or freezes
- Any confusing UI or unclear instructions
- Any actions that happen without your explicit approval
```

---

## Post-Upload Verification

### 13. TestFlight Processing
- [ ] Build uploaded successfully to App Store Connect
- [ ] Build passes App Store Connect processing
- [ ] Build appears in TestFlight within 24 hours
- [ ] No "Missing Compliance" issues (encryption)

### 14. First Tester Verification
- [ ] Install on a test device via TestFlight
- [ ] Verify app launches correctly
- [ ] Verify `ReleaseMode.current == .testFlight`
- [ ] Complete one full flow successfully

---

## Emergency Rollback Plan

If critical issues are discovered:

1. **Disable build in TestFlight** (App Store Connect → TestFlight → Builds → Expire Build)
2. **Document the issue** in internal tracker
3. **Fix and re-test** using this checklist
4. **Upload new build** with incremented build number
5. **Notify testers** of the new build

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Developer | | | |
| QA | | | |
| Release Manager | | | |

---

*Phase 7B — TestFlight Preflight Checklist*
