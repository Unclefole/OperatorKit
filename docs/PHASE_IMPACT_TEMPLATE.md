# PHASE IMPACT DECLARATION TEMPLATE

> **Purpose**: Every new phase must declare its impact on safety, permissions, and execution.
> This template creates intentional friction to prevent silent scope creep.

---

## Template Version: 1

---

## Phase: [PHASE NUMBER] — [PHASE NAME]

### Date: [YYYY-MM-DD]

### Author: [NAME]

---

## 1. Impact Assessment

Complete the following checklist. For each "YES", provide justification and required approvals.

### 1.1 Execution Flow

| Question | Yes/No | Justification |
|----------|--------|---------------|
| Does this phase touch execution logic? | | |
| Does this phase modify `ExecutionEngine`? | | |
| Does this phase modify `ApprovalGate`? | | |
| Does this phase add new side effect types? | | |

**If YES to any**: Requires safety review and `SAFETY_CONTRACT.md` update.

---

### 1.2 Permissions

| Question | Yes/No | Justification |
|----------|--------|---------------|
| Does this phase request new permissions? | | |
| Does this phase modify `PermissionManager`? | | |
| Does this phase add new Info.plist keys? | | |
| Does this phase modify entitlements? | | |

**If YES to any**: Requires privacy review and `PrivacyStrings.swift` update.

---

### 1.3 Background Behavior

| Question | Yes/No | Justification |
|----------|--------|---------------|
| Does this phase add background modes? | | |
| Does this phase add scheduled tasks? | | |
| Does this phase add push notifications? | | |
| Does this phase run code when app is not active? | | |

**If YES to any**: STOP. This violates SAFETY_CONTRACT.md Guarantee #2.

---

### 1.4 Networking

| Question | Yes/No | Justification |
|----------|--------|---------------|
| Does this phase add network calls? | | |
| Does this phase import networking frameworks? | | |
| Does this phase send data externally? | | |
| Does this phase receive data externally? | | |

**If YES to any**: STOP. This violates SAFETY_CONTRACT.md Guarantee #2 and Claim #001.

---

### 1.5 Safety Guarantees

| Question | Yes/No | Justification |
|----------|--------|---------------|
| Does this phase modify SAFETY_CONTRACT.md? | | |
| Does this phase weaken any guarantee? | | |
| Does this phase add new guarantees? | | |
| Does this phase change guarantee classifications? | | |

**If YES to any**: Requires explicit approval and documented justification.

---

### 1.6 User-Facing Claims

| Question | Yes/No | Justification |
|----------|--------|---------------|
| Does this phase add new user-visible claims? | | |
| Does this phase modify existing claims? | | |
| Does this phase affect CLAIM_REGISTRY.md? | | |

**If YES to any**: Update CLAIM_REGISTRY.md before implementation.

---

## 2. Scope Boundaries

### 2.1 What This Phase WILL Do

- [ ] Item 1
- [ ] Item 2
- [ ] Item 3

### 2.2 What This Phase WILL NOT Do

- [ ] Item 1
- [ ] Item 2
- [ ] Item 3

### 2.3 Deferred to Future Phases

- [ ] Item 1 (→ Phase X)
- [ ] Item 2 (→ Phase X)

---

## 3. Required Approvals

Based on the impact assessment above, check required approvals:

- [ ] **No special approvals needed** (advisory/documentation only)
- [ ] Safety review required
- [ ] Privacy review required
- [ ] Architecture review required
- [ ] Documentation review required
- [ ] Test coverage review required

---

## 4. Pre-Implementation Checklist

- [ ] Impact assessment complete
- [ ] Scope boundaries defined
- [ ] Required approvals obtained
- [ ] SAFETY_CONTRACT.md reviewed
- [ ] CLAIM_REGISTRY.md reviewed
- [ ] PHASE_BOUNDARIES.md reviewed
- [ ] Tests planned

---

## 5. Post-Implementation Checklist

- [ ] All tests pass
- [ ] Preflight validation passes
- [ ] Safety contract unchanged (or intentionally updated)
- [ ] Quality gate status documented
- [ ] Documentation updated
- [ ] Claim registry updated (if applicable)

---

## 6. Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Author | | | |
| Safety Review | | | |
| Privacy Review | | | |

---

*This template is referenced by PHASE_BOUNDARIES.md and RELEASE_APPROVAL.md*
