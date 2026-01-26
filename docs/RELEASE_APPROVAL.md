# Release Approval Ritual

**Purpose:** Ensure every release maintains safety guarantees and is reviewer-safe.

This is not bureaucracy—it's a lightweight checklist ritual that prevents regressions.

---

## Pre-Merge Checklist (Engineer)

Complete before merging any PR that touches safety-critical code:

| Item | Verified | Notes |
|------|----------|-------|
| Code compiles in DEBUG | ☐ | |
| Code compiles in RELEASE | ☐ | |
| All unit tests pass | ☐ | |
| `InvariantTests` pass | ☐ | |
| `RegressionTests` pass | ☐ | |
| `InfoPlistRegressionTests` pass | ☐ | |
| No new permissions added | ☐ | If added, Safety Contract approval required |
| No new entitlements added | ☐ | If added, Safety Contract approval required |
| No new network code | ☐ | Absolutely forbidden |
| No new background code | ☐ | Absolutely forbidden |
| Safety Contract unchanged | ☐ | Or explicitly approved |
| DEBUG-only code properly guarded | ☐ | `#if DEBUG` |

**Engineer Sign-Off:**
```
PR: #_____
Date: _____
Engineer: _____
☐ All items verified
```

---

## Pre-Archive Checklist (Release Owner)

Complete before creating an archive for TestFlight or App Store:

| Item | Verified | Notes |
|------|----------|-------|
| All PRs for this release merged | ☐ | |
| Version number updated | ☐ | |
| Build number incremented | ☐ | |
| Scheme set to Release | ☐ | |
| `PreflightValidator` passes | ☐ | Run: `PreflightValidator.shared.runAllChecks()` |
| `RegressionSentinel` all clear | ☐ | Run: `RegressionSentinel.shared.runAllChecks()` |
| `InvariantCheckRunner` passes | ☐ | Run: `InvariantCheckRunner.shared.runAllChecks()` |
| App Store metadata valid | ☐ | Run: `AppStoreMetadata.validate()` |
| TestFlight "What to Test" written | ☐ | Copy from template |
| Release notes written | ☐ | |

**Release Owner Sign-Off:**
```
Version: _____
Build: _____
Date: _____
Release Owner: _____
☐ All items verified
```

---

## Pre-Submission Checklist (Final)

Complete immediately before clicking "Submit for Review":

| Item | Verified | Notes |
|------|----------|-------|
| Archive validated in Xcode Organizer | ☐ | |
| No missing compliance issues | ☐ | |
| No provisioning profile issues | ☐ | |
| Privacy labels accurate | ☐ | Match actual data practices |
| App description accurate | ☐ | No overclaiming |
| Review notes complete | ☐ | Include test instructions |
| Contact info current | ☐ | |
| Safety Contract unchanged | ☐ | |
| `TESTFLIGHT_PREFLIGHT_CHECKLIST.md` complete | ☐ | If TestFlight |
| `APP_STORE_SUBMISSION_CHECKLIST.md` complete | ☐ | If App Store |

**Final Sign-Off:**
```
Version: _____
Submission Type: [ ] TestFlight [ ] App Store
Date: _____
Submitter: _____
☐ All items verified
☐ Ready for review
```

---

## Required Artifacts

Before any release, the following must exist and be valid:

| Artifact | Location | Validation |
|----------|----------|------------|
| Preflight PASS | `PreflightValidator.runAllChecks()` | All checks pass |
| Invariant PASS | `InvariantCheckRunner.runAllChecks()` | All checks pass |
| Regression PASS | `RegressionSentinel.runAllChecks()` | All checks pass |
| Metadata VALID | `AppStoreMetadata.validate()` | No issues |
| Safety Contract | `docs/SAFETY_CONTRACT.md` | Unchanged or approved |
| Release Notes | App Store Connect | Written |

### Optional Final Artifact (Phase 9D)

| Artifact | Location | Validation |
|----------|----------|------------|
| Evidence Packet | Settings → External Review Readiness → Export | Exports successfully |

**Export Evidence Packet** can be generated as an optional final artifact before submission:

1. Open the app in the release build
2. Navigate to Settings → External Review Readiness
3. Tap "Export Evidence Packet"
4. Save the JSON file for records

This provides a point-in-time snapshot of all quality and safety metrics.

---

## Safety Contract Change Approval

If any change to the Safety Contract is required:

1. **Document the change** in a design note
2. **Analyze reviewer impact** (will this cause rejection?)
3. **Update all affected documentation**
4. **Update all affected tests**
5. **Get Principal Engineer approval**

### Approval Form

```
═══════════════════════════════════════════════════════════
SAFETY CONTRACT CHANGE APPROVAL
═══════════════════════════════════════════════════════════

Change Request ID: SC-_____
Date: _____
Requestor: _____

CHANGE DESCRIPTION:
_______________________________________________
_______________________________________________

GUARANTEE(S) AFFECTED:
[ ] #1 No Autonomous Actions
[ ] #2 No Network Transmission
[ ] #3 No Background Data Access
[ ] #4 Draft-First Execution
[ ] #5 Two-Key Confirmation
[ ] #6 Siri Routes Only
[ ] #7 User-Selected Context
[ ] #8 Audit Immutability
[ ] #9 Deterministic Fallback
[ ] #10 DEBUG-Only Features

CLASSIFICATION:
[ ] IMMUTABLE (requires architectural redesign)
[ ] MAJOR VERSION ONLY (requires 2.0 bump)
[ ] EXPERIMENTAL (DEBUG only)

JUSTIFICATION:
_______________________________________________
_______________________________________________

REVIEWER IMPACT ANALYSIS:
[ ] No impact on App Review
[ ] May require updated Review Notes
[ ] Requires new privacy disclosure
[ ] May cause rejection (explain mitigation)

DOCUMENTATION UPDATES:
[ ] SAFETY_CONTRACT.md
[ ] EXECUTION_GUARANTEES.md
[ ] APP_REVIEW_PACKET.md
[ ] PrivacyStrings.swift
[ ] Other: _____________

TEST UPDATES:
[ ] InvariantTests.swift
[ ] RegressionTests.swift
[ ] InfoPlistRegressionTests.swift
[ ] Other: _____________

APPROVALS:
Engineer: _________________ Date: _____
Principal Engineer: _________________ Date: _____

NOTES:
_______________________________________________

═══════════════════════════════════════════════════════════
```

---

## Release Sign-Off Record

Keep a record of all releases:

| Version | Build | Date | Type | Approver | Notes |
|---------|-------|------|------|----------|-------|
| 1.0.0 | 1 | | App Store | | Initial release |

---

## Emergency Release Process

If a critical fix is needed:

1. **Create hotfix branch** from release tag
2. **Make minimal change** to fix the issue
3. **Run all checklists** (abbreviated if truly urgent)
4. **Get verbal approval** from Principal Engineer
5. **Submit with expedited review request**
6. **Document in release record** with explanation

---

*This document is part of the OperatorKit governance framework (Phase 9D)*
