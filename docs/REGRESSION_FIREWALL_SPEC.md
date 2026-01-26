# REGRESSION FIREWALL SPECIFICATION

**Document Purpose**: Canonical specification for Regression Firewall verification system.

**Phase**: 13D  
**Classification**: Trust Infrastructure  
**Status**: Implemented

---

## Definition

The **Regression Firewall** is an on-device verification system that allows users and auditors to cryptographically confirm that safety guarantees remain intact.

**This is Trust-by-Construction made inspectable.**

---

## Purpose

Give users and auditors confidence that:

1. No update introduced network calls to execution paths
2. Approval Gate cannot be bypassed
3. No regression enabled autonomous actions
4. Execution remains draft-first and user-approved

---

## Design Principles

| Principle | Implementation |
|-----------|----------------|
| Read-only | No state mutation during verification |
| Deterministic | Same inputs always produce same results |
| On-device | No network calls, no telemetry |
| Reproducible | Any user can run verification |
| Fail-loud | Failures are clearly surfaced |

---

## Rule Categories

### Networking (NET-*)

| Rule | Description |
|------|-------------|
| NET-001 | No URLSession in core modules |
| NET-002 | Sync confined to Sync module |
| NET-003 | No telemetry or analytics |

### Background Execution (BG-*)

| Rule | Description |
|------|-------------|
| BG-001 | No BGTaskScheduler usage |
| BG-002 | No background fetch |

### Autonomous Actions (AUTO-*)

| Rule | Description |
|------|-------------|
| AUTO-001 | No auto-send capability |
| AUTO-002 | No timer-based execution |

### Approval Gate (APPROVAL-*)

| Rule | Description |
|------|-------------|
| APPROVAL-001 | Approval Gate cannot be bypassed |
| APPROVAL-002 | Draft-first workflow enforced |

### Forbidden APIs (FORBIDDEN-*)

| Rule | Description |
|------|-------------|
| FORBIDDEN-001 | No direct mail sending |
| FORBIDDEN-002 | No silent calendar writes |

### Data Protection (DATA-*)

| Rule | Description |
|------|-------------|
| DATA-001 | No user content in exports |
| DATA-002 | Memory is local-only |

---

## Verification Process

1. User opens Regression Firewall Dashboard
2. Runner executes all rules sequentially
3. Each rule returns pass/fail + evidence
4. Report is displayed (read-only)
5. No state is mutated
6. No data leaves device

---

## Failure Semantics

If any rule fails:

| Action | Status |
|--------|--------|
| Surface RED / FAILED | ✅ Yes |
| Attempt repair | ❌ No |
| Auto-disable features | ❌ No |
| Log to server | ❌ No |

**User must update or reinstall the app.**

---

## Evidence Surface

The dashboard displays:

| Item | Source |
|------|--------|
| Overall status | PASSED / FAILED |
| Rule count | Total rules executed |
| Passed count | Rules that passed |
| Failed count | Rules that failed |
| Last verified | Timestamp of verification |
| Per-rule evidence | Text explanation |

---

## Non-Guarantees

The Regression Firewall is **NOT**:

- A runtime monitor
- A telemetry system
- A logging framework
- An auto-repair system
- A security scanner

It is a **verification surface** only.

---

## Feature Flag

| Flag | Value |
|------|-------|
| Name | `RegressionFirewallFeatureFlag.isEnabled` |
| DEBUG default | true |
| RELEASE default | true (transparency) |

---

## Constraints (Absolute)

| Constraint | Enforced |
|------------|----------|
| No networking | ✅ Verified by tests |
| No telemetry | ✅ No analytics imports |
| No state mutation | ✅ Pure verification functions |
| No auto-repair | ✅ No mutation code |
| Deterministic | ✅ Same results on each run |
| On-device only | ✅ No network calls |

---

## Document Metadata

| Field | Value |
|-------|-------|
| Created | Phase 13D |
| Classification | Trust Infrastructure |
| Runtime Behavior Changed | No |
| Execution Modified | No |
| Telemetry Added | No |

---

*Trust-by-Construction, made inspectable.*
